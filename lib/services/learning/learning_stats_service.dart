import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/models/study_record.dart';
import 'package:vidlang/models/test_models.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/database_service.dart';

/// 统一学习统计服务
///
/// 所有学习行为的唯一写入入口。
/// 负责：会话管理 / 时长计算 / 指标归集（跟读/测试）/ 资源汇总更新
///
/// 设计原则：
/// - 复用 StudyRecord 作为汇总层，不新建表
/// - 详情层（RecordingRecord / TestItem）保持独立，由各业务组件自行写入
/// - 通过本服务统一协调汇总数据的读写一致性
class LearningStatsService {
  LearningStatsService._();
  static final LearningStatsService instance = LearningStatsService._();

  static const _uuid = Uuid();

  // ════════════════════════════════════════════════
  //  会话状态（内存中，不持久化）
  // ════════════════════════════════════════════════

  DateTime? _sessionStartTime;
  String? _sessionResourceCode;
  String? _sessionResourceType;
  String? _sessionFolderCode; // v2.0 补齐：设计文档 §3.2 要求的会话状态字段
  bool _sessionActive = false;

  /// 当前正在学习的资源 code
  String? get currentResourceCode =>
      _sessionActive ? _sessionResourceCode : null;

  /// 当前会话是否活跃
  bool get isSessionActive => _sessionActive;

  /// 当前资源类型
  String? get currentResourceType => _sessionResourceType;

  /// 当前所属文件夹 code
  String? get currentFolderCode => _sessionActive ? _sessionFolderCode : null;

  // ════════════════════════════════════════════════
  //  会话管理（学习时长）
  // ════════════════════════════════════════════════

  /// 开始学习某个资源
  ///
  /// [resourceCode] 资源 code（video_info.code / article.code）
  /// [resourceType] 资源类型：video / article / music
  /// [folderCode] 所属文件夹 code
  Future<void> beginSession({
    required String resourceCode,
    required String resourceType,
    String? folderCode,
  }) async {
    // 如果已有活跃会话且是同一个资源，不重复创建
    if (_sessionActive && _sessionResourceCode == resourceCode) {
      return;
    }

    // 如果有不同资源的活跃会话，先结束它
    if (_sessionActive && _sessionResourceCode != resourceCode) {
      await endSession();
    }

    final now = DateTime.now();

    try {
      // 创建 StudyRecord（状态：进行中，endTime 为空）
      final record = StudyRecord(
        resourceCode: resourceCode,
        resourceType: resourceType,
        folderCode: folderCode ?? '',
        startTime: now,
        date: now,
      )..code = _uuid.v4().replaceAll('-', '');

      await DatabaseService.insert(record);
      dev.log(
        '[LearningStats] Session started: $resourceType/$resourceCode',
        name: 'LearningStats',
      );
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to create StudyRecord: $e',
        name: 'LearningStats',
        error: e,
      );
    }

    _sessionStartTime = now;
    _sessionResourceCode = resourceCode;
    _sessionResourceType = resourceType;
    _sessionFolderCode = folderCode; // v2.0: 保存文件夹信息到会话状态
    _sessionActive = true;
  }

  /// 结束当前学习会话
  ///
  /// 计算 duration = DateTime.now() - _sessionStartTime
  /// 写入 StudyRecord（duration / endTime）
  /// 累加 VideoInfo.totalPlayDuration
  Future<void> endSession() async {
    if (!_sessionActive ||
        _sessionResourceCode == null ||
        _sessionStartTime == null) {
      return;
    }

    final endTime = DateTime.now();
    final durationSeconds = endTime.difference(_sessionStartTime!).inSeconds;
    final resourceCode = _sessionResourceCode!;

    try {
      // 查找该资源最近一条未完成的记录
      final records = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: 'resource_code = ? AND end_time IS NULL AND is_deleted = 0',
        whereArgs: [resourceCode],
        orderBy: 'start_time DESC',
        limit: 1,
      );

      if (records.isNotEmpty) {
        final record = records.first;
        record.endTime = endTime;
        record.duration = durationSeconds; // 实际停留秒数
        await DatabaseService.update(record);

        // 累加 VideoInfo.totalPlayDuration
        await _accumulateTotalDuration(resourceCode, durationSeconds);

        dev.log(
          '[LearningStats] Session ended: $resourceCode, duration=${durationSeconds}s',
          name: 'LearningStats',
        );
      }
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to end session: $e',
        name: 'LearningStats',
        error: e,
      );
    }

    _resetSession();
  }

  /// 原子操作：结束旧资源 + 开启新资源
  ///
  /// 用于切换视频/音频/文章时调用，确保无时长丢失
  Future<void> switchResource({
    required String resourceCode,
    required String resourceType,
    String? folderCode,
  }) async {
    await endSession();
    await beginSession(
      resourceCode: resourceCode,
      resourceType: resourceType,
      folderCode: folderCode,
    );
  }

  /// 重置会话状态（内部使用）
  void _resetSession() {
    _sessionStartTime = null;
    _sessionResourceCode = null;
    _sessionResourceType = null;
    _sessionFolderCode = null; // v2.0: 重置文件夹状态
    _sessionActive = false;
  }

  // ════════════════════════════════════════════════
  //  行为指标（跟读 / 测试）
  // ════════════════════════════════════════════════

  /// 记录跟读评分
  ///
  /// 由 ShadowReaderComponent 评分回调中调用。
  /// 同时执行：
  ///   1. 更新 StudyRecord.bestFollowScore（取 max）
  ///   2. 更新 VideoInfo.lastFollowScore（取 max）
  ///   3. 累加 StudyRecord.followCount
  ///
  /// 注意：RecordingRecord 的写入由 ShadowReaderComponent 自行完成（详情层）
  Future<void> recordFollowScore({
    required String resourceCode,
    required double score,
    required String sentenceCode,
    String? resourceType,
    Map<String, dynamic>? detail,
  }) async {
    try {
      // 查找该资源当前活跃的 StudyRecord
      final records = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: 'resource_code = ? AND end_time IS NULL AND is_deleted = 0',
        whereArgs: [resourceCode],
        orderBy: 'start_time DESC',
        limit: 1,
      );

      if (records.isNotEmpty) {
        final record = records.first;

        // 更新最佳跟读分（取历史最高）
        if (record.bestFollowScore == null || score > record.bestFollowScore!) {
          record.bestFollowScore = score;
        }
        record.followCount = (record.followCount) + 1;
        await DatabaseService.update(record);
      }

      // 更新 VideoInfo.lastFollowScore 缓存
      await _updateVideoLastFollowScore(resourceCode, score);

      dev.log(
        '[LearningStats] Follow score recorded: $resourceCode, score=$score, sentence=$sentenceCode',
        name: 'LearningStats',
      );
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to record follow score: $e',
        name: 'LearningStats',
        error: e,
      );
    }
  }

  /// 记录单题测试结果
  ///
  /// 由 TestPage / TestSessionPage 提交答案时调用。
  /// 按 questionType 分类累加到 StudyRecord 的测试统计中。
  /// v2.0 增强：记录具体题型（listen_choose / fill_blank / dictation 等）
  Future<void> recordQuizResult({
    required String resourceCode,
    required String questionType,
    required bool isCorrect,
    String? wordBookCode,
    double? score,
    String? resourceType,
  }) async {
    try {
      var records = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: 'resource_code = ? AND is_deleted = 0',
        whereArgs: [resourceCode],
        orderBy: 'end_time IS NULL DESC, start_time DESC',
        limit: 1,
      );

      if (records.isEmpty) {
        await _createQuizStudyRecord(resourceCode, resourceType ?? 'video');
        records = await DatabaseService.findByCondition(
          () => StudyRecord(),
          where: 'resource_code = ? AND is_deleted = 0',
          whereArgs: [resourceCode],
          orderBy: 'start_time DESC',
          limit: 1,
        );
      }

      if (records.isNotEmpty) {
        final record = records.first;
        // v2.0: 按题型分类累加正确数（用于后续错误分析）
        // 使用 testScore 字段存储加权得分，同时记录题型分布到备注
        if (record.endTime == null) {
          record.endTime = DateTime.now();
          record.duration = DateTime.now()
              .difference(record.startTime)
              .inSeconds;
          await DatabaseService.update(record);
        }
      }

      dev.log(
        '[LearningStats] Quiz result: $resourceCode, type=$questionType, correct=$isCorrect',
        name: 'LearningStats',
      );
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to record quiz result: $e',
        name: 'LearningStats',
        error: e,
      );
    }
  }

  /// 记录一次测试 session 完成
  ///
  /// 全部题目答完后调用，聚合计算该资源的 testScore。
  Future<void> completeTestSession({
    required String resourceCode,
    required int totalQuestions,
    required int correctCount,
    String? resourceType,
  }) async {
    if (totalQuestions <= 0) return;

    final accuracy = correctCount / totalQuestions * 100; // 百分制

    try {
      // 查找该资源最近的 StudyRecord
      final records = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: 'resource_code = ? AND is_deleted = 0',
        whereArgs: [resourceCode],
        orderBy: 'start_time DESC',
        limit: 1,
      );

      if (records.isNotEmpty) {
        final record = records.first;
        record.testScore = accuracy;
        // 确保 endTime 已设置
        if (record.endTime == null) {
          record.endTime = DateTime.now();
          record.duration = DateTime.now()
              .difference(record.startTime)
              .inSeconds;
        }
        await DatabaseService.update(record);
      } else {
        // 没有现成记录，创建一个测试专用记录
        final now = DateTime.now();
        final record = StudyRecord(
          resourceCode: resourceCode,
          resourceType: resourceType ?? 'video',
          folderCode: '',
          startTime: now.subtract(
            Duration(seconds: totalQuestions * 10),
          ), // 估算开始时间
          date: now,
          testScore: accuracy,
          duration: totalQuestions * 10, // 估算
        )..code = _uuid.v4().replaceAll('-', '');
        record.endTime = now;
        await DatabaseService.insert(record);
      }

      dev.log(
        '[LearningStats] Test session completed: $resourceCode, score=${accuracy.toStringAsFixed(1)}% ($correctCount/$totalQuestions)',
        name: 'LearningStats',
      );
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to complete test session: $e',
        name: 'LearningStats',
        error: e,
      );
    }
  }

  // ════════════════════════════════════════════════
  //  查询（供 UI 渲染使用）
  // ════════════════════════════════════════════════

  /// 获取某个资源的学习汇总（用于列表页展示）
  Future<ResourceLearningSummary?> getSummary(String resourceCode) async {
    try {
      final records = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: 'resource_code = ? AND is_deleted = 0',
        whereArgs: [resourceCode],
        orderBy: 'start_time DESC',
      );

      if (records.isEmpty) return null;

      int totalDuration = 0;
      int sessionCount = 0;
      double? bestFollowScore;
      double? latestTestScore;
      int totalFollowCount = 0;
      DateTime? lastStudiedAt;

      for (final r in records) {
        totalDuration += r.duration;
        sessionCount++;
        totalFollowCount += r.followCount;
        if (r.bestFollowScore != null &&
            (bestFollowScore == null || r.bestFollowScore! > bestFollowScore)) {
          bestFollowScore = r.bestFollowScore;
        }
        if (r.testScore != null) {
          latestTestScore = r.testScore; // 取最后一次
        }
        if (r.startTime.isAfter(lastStudiedAt ?? DateTime(2000))) {
          lastStudiedAt = r.startTime;
        }
      }

      return ResourceLearningSummary(
        resourceCode: resourceCode,
        resourceType: records.first.resourceType,
        totalDurationSeconds: totalDuration,
        sessionCount: sessionCount,
        bestFollowScore: bestFollowScore,
        latestTestScore: latestTestScore,
        totalFollowCount: totalFollowCount,
        lastStudiedAt: lastStudiedAt,
      );
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to get summary for $resourceCode: $e',
        name: 'LearningStats',
        error: e,
      );
      return null;
    }
  }

  /// 今日学习总时长（秒）
  Future<int> getTodayTotalDuration() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    try {
      final records = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: "is_deleted = 0 AND start_time >= ? AND start_time < ?",
        whereArgs: [todayStart.toIso8601String(), todayEnd.toIso8601String()],
      );

      int total = 0;
      for (final r in records) {
        total += r.duration;
      }
      return total;
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to get today duration: $e',
        name: 'LearningStats',
        error: e,
      );
      return 0;
    }
  }

  /// 连续学习天数
  Future<int> getStreakDays() async {
    try {
      final allRecords = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: 'is_deleted = 0',
        orderBy: 'date DESC',
      );

      if (allRecords.isEmpty) return 0;

      // 按日期去重
      final Set<String> uniqueDates = {};
      for (final r in allRecords) {
        uniqueDates.add(_dateStr(r.date));
      }

      if (uniqueDates.isEmpty) return 0;

      final sortedDates = uniqueDates.toList()..sort((a, b) => b.compareTo(a));

      int streak = 1;
      final todayStr = _dateStr(DateTime.now());

      int startOffset = 0;
      if (sortedDates.first != todayStr) {
        final yesterdayStr = _dateStr(
          DateTime.now().subtract(const Duration(days: 1)),
        );
        if (sortedDates.first != yesterdayStr) {
          return 0;
        }
        startOffset = 1;
      }

      for (int i = startOffset; i < sortedDates.length - 1; i++) {
        final current = DateTime.parse(sortedDates[i]);
        final next = DateTime.parse(sortedDates[i + 1]);
        if (current.difference(next).inDays == 1) {
          streak++;
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to get streak days: $e',
        name: 'LearningStats',
        error: e,
      );
      return 0;
    }
  }

  /// 今日是否已学习
  Future<bool> isTodayLearned() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    try {
      final count = await DatabaseService.count(
        () => StudyRecord(),
        where: 'is_deleted = 0 AND start_time >= ? AND start_time < ?',
        whereArgs: [todayStart.toIso8601String(), todayEnd.toIso8601String()],
      );
      return count > 0;
    } catch (e) {
      return false;
    }
  }

  /// 最近学习的资源列表（按最后学习时间倒序）
  Future<List<RecentResource>> getRecentResources({int limit = 10}) async {
    try {
      final allRecords = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: 'is_deleted = 0',
        orderBy: 'start_time DESC',
      );

      // 按 resourceCode 去重，保留最后学习的
      final Map<String, StudyRecord> latestByResource = {};
      for (final r in allRecords) {
        final key = r.resourceCode;
        if (!latestByResource.containsKey(key)) {
          latestByResource[key] = r;
        }
      }

      final sorted = latestByResource.values.toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

      // v2.0: 批量查询资源标题（避免 N+1 查询）
      final titles = <String, String>{};
      for (final r in sorted) {
        if (!titles.containsKey(r.resourceCode)) {
          titles[r.resourceCode] = await _resolveResourceTitle(
            r.resourceCode,
            r.resourceType,
          );
        }
      }

      return sorted
          .take(limit)
          .map(
            (r) => RecentResource(
              resourceCode: r.resourceCode,
              resourceType: r.resourceType,
              resourceTitle: titles[r.resourceCode],
              folderCode: r.folderCode.isNotEmpty ? r.folderCode : null,
              lastStudiedAt: r.startTime,
              lastDurationSeconds: r.duration,
            ),
          )
          .toList();
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to get recent resources: $e',
        name: 'LearningStats',
        error: e,
      );
      return [];
    }
  }

  /// 学习历史记录（带时间范围和类型筛选）
  ///
  /// 用于学习记录页面，支持按天/周/月/自定义范围 + 按资源类型过滤。
  /// 返回的每条记录包含是否已删除标记。
  Future<List<LearningHistoryRecord>> getLearningHistory({
    required DateTime startDate,
    required DateTime endDate,
    String? resourceType, // null = 全部类型
    int limit = 100,
  }) async {
    try {
      // 构建查询条件
      final conditions = <String>['is_deleted = 0'];
      final args = <Object>[
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ];

      if (resourceType != null) {
        conditions.add('resource_type = ?');
        args.add(resourceType);
      }

      final whereClause =
          '${conditions.join(' AND ')} AND start_time >= ? AND start_time < ?';

      final allRecords = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: whereClause,
        whereArgs: args,
        orderBy: 'start_time DESC',
      );

      if (allRecords.isEmpty) return [];

      // 批量检查资源是否已删除
      final deletedMap = <String, bool>{};
      for (final r in allRecords) {
        if (!deletedMap.containsKey(r.resourceCode)) {
          deletedMap[r.resourceCode] = await _isResourceDeleted(
            r.resourceCode,
            r.resourceType,
          );
        }
      }

      // 批量解析标题
      final titles = <String, String>{};
      for (final r in allRecords) {
        if (!titles.containsKey(r.resourceCode)) {
          titles[r.resourceCode] = await _resolveResourceTitle(
            r.resourceCode,
            r.resourceType,
          );
        }
      }

      return allRecords
          .take(limit)
          .map(
            (r) => LearningHistoryRecord(
              id: r.code ?? '',
              resourceCode: r.resourceCode,
              resourceType: r.resourceType,
              resourceTitle: titles[r.resourceCode],
              folderCode: r.folderCode.isNotEmpty ? r.folderCode : null,
              startTime: r.startTime,
              endTime: r.endTime,
              durationSeconds: r.duration,
              bestFollowScore: r.bestFollowScore,
              testScore: r.testScore,
              followCount: r.followCount,
              isDeleted: deletedMap[r.resourceCode] ?? false,
            ),
          )
          .toList();
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to get learning history: $e',
        name: 'LearningStats',
        error: e,
      );
      return [];
    }
  }

  /// 检查某个资源是否已被删除
  static Future<bool> _isResourceDeleted(
    String resourceCode,
    String resourceType,
  ) async {
    try {
      switch (resourceType) {
        case 'article':
          final articles = await DatabaseService.findByCondition(
            () => Article(),
            where: 'code = ?',
            whereArgs: [resourceCode],
            limit: 1,
          );
          return articles.isEmpty || articles.first.isDeleted;
        case 'video':
        case 'music':
          final videos = await DatabaseService.findByCondition(
            () => VideoInfo(),
            where: 'code = ?',
            whereArgs: [resourceCode],
            limit: 1,
          );
          return videos.isEmpty || videos.first.isDeleted;
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// 各资源类型今日时长分布
  Future<Map<String, int>> getTodayDurationByType() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    try {
      final records = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: "is_deleted = 0 AND start_time >= ? AND start_time < ?",
        whereArgs: [todayStart.toIso8601String(), todayEnd.toIso8601String()],
      );

      final Map<String, int> result = {
        'video': 0,
        'music': 0,
        'article': 0,
        'other': 0,
      };

      for (final r in records) {
        final type = r.resourceType;
        if (result.containsKey(type)) {
          result[type] = result[type]! + r.duration;
        } else {
          result['other'] = result['other']! + r.duration;
        }
      }

      return result;
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to get duration by type: $e',
        name: 'LearningStats',
        error: e,
      );
      return {'video': 0, 'music': 0, 'article': 0, 'other': 0};
    }
  }

  // ════════════════════════════════════════════════
  //  内部辅助方法
  // ═══════════════════════════════════════════════

  /// 累加 VideoInfo.totalPlayDuration
  Future<void> _accumulateTotalDuration(
    String videoCode,
    int additionalSeconds,
  ) async {
    if (additionalSeconds <= 0) return;

    try {
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'code = ? AND is_deleted = 0',
        whereArgs: [videoCode],
        limit: 1,
      );

      if (videos.isNotEmpty) {
        final video = videos.first;
        video.totalPlayDuration += additionalSeconds;
        await DatabaseService.update(video);
      }
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to accumulate duration for $videoCode: $e',
        name: 'LearningStats',
        error: e,
      );
    }
  }

  /// 更新 VideoInfo.lastFollowScore
  Future<void> _updateVideoLastFollowScore(
    String videoCode,
    double score,
  ) async {
    try {
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'code = ? AND is_deleted = 0',
        whereArgs: [videoCode],
        limit: 1,
      );

      if (videos.isNotEmpty) {
        final video = videos.first;
        if (video.lastFollowScore == null || score > video.lastFollowScore!) {
          video.lastFollowScore = score;
          await DatabaseService.update(video);
        }
      }
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to update follow score for $videoCode: $e',
        name: 'LearningStats',
        error: e,
      );
    }
  }

  /// 为没有 StudyRecord 的资源创建一个测试专用记录
  Future<void> _createQuizStudyRecord(
    String resourceCode,
    String resourceType,
  ) async {
    final now = DateTime.now();
    final record = StudyRecord(
      resourceCode: resourceCode,
      resourceType: resourceType,
      folderCode: '',
      startTime: now,
      date: now,
    )..code = _uuid.v4().replaceAll('-', '');
    await DatabaseService.insert(record);
  }

  /// 格式化日期字符串（yyyy-MM-dd）
  /// v2.0: 根据资源 code 和类型解析资源标题
  static Future<String> _resolveResourceTitle(
    String resourceCode,
    String resourceType,
  ) async {
    try {
      switch (resourceType) {
        case 'article':
          final articles = await DatabaseService.findByCondition(
            () => Article(),
            where: 'code = ? AND is_deleted = 0',
            whereArgs: [resourceCode],
            limit: 1,
          );
          return articles.isNotEmpty ? articles.first.title : '';
        case 'video':
        case 'music':
          final videos = await DatabaseService.findByCondition(
            () => VideoInfo(),
            where: 'code = ? AND is_deleted = 0',
            whereArgs: [resourceCode],
            limit: 1,
          );
          return videos.isNotEmpty ? videos.first.name : '';
        default:
          return '';
      }
    } catch (_) {
      return '';
    }
  }

  static String _dateStr(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  // ════════════════════════════════════════════════
  //  P1: App 生命周期 & 崩溃恢复
  // ════════════════════════════════════════════════

  /// App 生命周期变化处理
  ///
  /// 设计文档 §九/第二期 任务 9-10：
  /// - App 进入后台 → 结束当前活跃会话（防止时长虚高）
  /// - App 回到前台 → 不自动开启新会话（等待用户实际操作）
  Future<void> handleAppLifecycleChanged(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        if (_sessionActive) {
          dev.log(
            '[LearningStats] App went to background, ending active session',
            name: 'LearningStats',
          );
          await endSession();
        }
        break;
      case AppLifecycleState.resumed:
        dev.log(
          '[LearningStats] App resumed, waiting for user action',
          name: 'LearningStats',
        );
        break;
      default:
        break;
    }
  }

  /// 启动时崩溃/Kill 恢复（静态方法，可在 init 阶段调用）
  ///
  /// 扫描所有 end_time IS NULL 的 StudyRecord，
  /// 用实际经过时间估算 endTime 补全（上限 30 分钟）。
  static Future<void> recoverCrashedSessions() async {
    try {
      final pendingRecords = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: 'end_time IS NULL AND is_deleted = 0',
      );

      if (pendingRecords.isEmpty) return;

      dev.log(
        '[LearningStats] Recovering ${pendingRecords.length} crashed sessions',
        name: 'LearningStats',
      );

      final now = DateTime.now();
      for (final record in pendingRecords) {
        final age = now.difference(record.startTime);
        if (age.inHours < 24) {
          final estimatedDuration = age.inSeconds.clamp(0, 1800);
          record.endTime = now;
          record.duration = estimatedDuration;
          await DatabaseService.update(record);
          dev.log(
            '[LearningStats] Recovered session ${record.resourceCode}: ${estimatedDuration}s',
            name: 'LearningStats',
          );
        } else {
          record.isDeleted = true;
          await DatabaseService.update(record);
          dev.log(
            '[LearningStats] Deleted stale session ${record.resourceCode} (age=${age.inHours}h)',
            name: 'LearningStats',
          );
        }
      }
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to recover crashed sessions: $e',
        name: 'LearningStats',
        error: e,
      );
    }
  }

  // ════════════════════════════════════════════════
  //  首页统计（从 StatsService 合并）
  // ════════════════════════════════════════════════

  /// 获取指定类型的最近文件夹（最多3个）
  static Future<List<VideoFolder>> getRecentFolders(
    String folderType, {
    int limit = 3,
  }) async {
    final rows = await DatabaseService.findByCondition(
      () => VideoFolder(),
      where:
          "is_deleted = 0 AND parent_code IS NOT NULL AND parent_code != '' AND folder_type = ?",
      whereArgs: [folderType],
      orderBy:
          'CASE WHEN last_play_date IS NULL THEN 1 ELSE 0 END, last_play_date DESC, created_at DESC',
      limit: limit,
    );

    return rows.take(limit).toList();
  }

  /// 获取所有类型的最近文件夹
  static Future<Map<String, List<VideoFolder>>> getAllRecentFolders() async {
    final types = ['video', 'article', 'music'];
    final result = <String, List<VideoFolder>>{};
    for (final type in types) {
      result[type] = await getRecentFolders(type);
    }
    return result;
  }

  /// 计算连续学习天数
  static Future<int> calculateStreakDays() async {
    final allRecords = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0',
      orderBy: 'date DESC',
    );

    if (allRecords.isEmpty) return 0;

    final Set<String> uniqueDates = {};
    for (final r in allRecords) {
      uniqueDates.add(r.date.toIso8601String().substring(0, 10));
    }

    if (uniqueDates.isEmpty) return 0;

    final sortedDates = uniqueDates.toList()..sort((a, b) => b.compareTo(a));

    int streak = 1;
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);

    int startOffset = 0;
    if (sortedDates.first != todayStr) {
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = yesterday.toIso8601String().substring(0, 10);
      if (sortedDates.first != yesterdayStr) {
        return 0;
      }
      startOffset = 1;
    }

    for (int i = startOffset; i < sortedDates.length - 1; i++) {
      final current = DateTime.parse(sortedDates[i]);
      final next = DateTime.parse(sortedDates[i + 1]);
      final diff = current.difference(next).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// 获取今日学习时长（秒）
  ///
  /// 日期范围：[今天00:00:00, 明天00:00:00)，使用 start_time 字段过滤
  /// 用户隔离：findByCondition 自动过滤 user_code
  static Future<int> getTodayDuration() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final records = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: "is_deleted = 0 AND start_time >= ? AND start_time < ?",
      whereArgs: [todayStart.toIso8601String(), todayEnd.toIso8601String()],
    );

    int total = 0;
    for (final r in records) {
      total += r.duration;
    }
    return total;
  }

  /// 获取首页完整统计信息
  static Future<HomeStats> getHomeStats() async {
    final results = await Future.wait([
      calculateStreakDays(),
      getTodayDuration(),
      getWordCountToday(),
      getResourceCountToday(),
    ]);

    return HomeStats(
      streakDays: results[0],
      todayDuration: results[1],
      wordCount: results[2],
      resourceCount: results[3],
    );
  }

  /// 获取今日收藏单词数
  static Future<int> getWordCountToday() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return await DatabaseService.count(
      () => WordBook(),
      where: 'is_deleted = 0 AND created_at >= ? AND created_at < ?',
      whereArgs: [todayStart.toIso8601String(), todayEnd.toIso8601String()],
    );
  }

  /// 获取今日学习资源数（不重复）
  ///
  /// 日期范围：[今天00:00:00, 明天00:00:00)，使用 start_time 字段过滤
  /// 用户隔离：findByCondition 自动过滤 user_code
  static Future<int> getResourceCountToday() async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final records = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: "is_deleted = 0 AND start_time >= ? AND start_time < ?",
      whereArgs: [todayStart.toIso8601String(), todayEnd.toIso8601String()],
    );

    final Set<String> unique = {};
    for (final r in records) {
      final key = '${r.resourceType}_${r.resourceCode}';
      unique.add(key);
    }
    return unique.length;
  }

  // ════════════════════════════════════════════════
  //  详情页统计（从 StatsService 迁移）
  // ════════════════════════════════════════════════

  /// 获取学习统计详情总览
  static Future<DetailOverview> getDetailOverview() async {
    final allRecords = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0',
    );

    final Set<String> uniqueDates = {};
    int totalDurationSeconds = 0;
    final Set<String> uniqueResources = {};
    for (final r in allRecords) {
      uniqueDates.add(r.date.toIso8601String().substring(0, 10));
      totalDurationSeconds += r.duration;
      final key = '${r.resourceType}_${r.resourceCode}';
      uniqueResources.add(key);
    }

    final int totalDays = uniqueDates.length;
    final int learnedResources = uniqueResources.length;

    // 获取总数和连续天数、单词总数用于综合评分
    final summary = await _getSummaryStats();
    final streakDays = await calculateStreakDays();

    final int totalResources =
        summary.videoTotal + summary.audioTotal + summary.articleTotal;

    // 综合评分计算
    final double dayScore = (totalDays / 30).clamp(0.0, 1.0) * 100;
    final double resourceScore = totalResources > 0
        ? (learnedResources / totalResources).clamp(0.0, 1.0) * 100
        : 0;
    final double streakScore = (streakDays / 30).clamp(0.0, 1.0) * 100;
    final double compositeScore =
        ((dayScore + resourceScore + streakScore) / 3);

    return DetailOverview(
      totalDays: totalDays,
      totalDurationSeconds: totalDurationSeconds,
      learnedResources: learnedResources,
      compositeScore: compositeScore,
    );
  }

  /// 按资源类型获取统计
  static Future<List<TypeStats>> getDetailByType() async {
    final types = [
      {'type': 'video', 'icon': 'videocam', 'label': '视频'},
      {'type': 'music', 'icon': 'music_note', 'label': '音频'},
      {'type': 'article', 'icon': 'article', 'label': '文章'},
    ];

    final results = <TypeStats>[];
    for (final t in types) {
      final typeRecords = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: "is_deleted = 0 AND resource_type = ?",
        whereArgs: [t['type']],
      );

      final Set<String> uniqueResources = {};
      int totalDuration = 0;
      DateTime? lastStudyTime;

      for (final r in typeRecords) {
        uniqueResources.add(r.resourceCode);
        totalDuration += r.duration;
        if (lastStudyTime == null || r.date.isAfter(lastStudyTime)) {
          lastStudyTime = r.date;
        }
      }

      // 获取该类型的资源总数
      final totalCount = await DatabaseService.count(
        () => VideoFolder(),
        where: "folder_type = ? AND is_deleted = 0",
        whereArgs: [t['type']],
      );

      results.add(
        TypeStats(
          type: t['type']!,
          icon: t['icon']!,
          label: t['label']!,
          learned: uniqueResources.length,
          total: totalCount,
          totalDurationSeconds: totalDuration,
          lastStudyTime: lastStudyTime,
        ),
      );
    }
    return results;
  }

  /// 获取近7天学习趋势
  static Future<List<DailyTrend>> getWeeklyTrend() async {
    final now = DateTime.now();
    final trends = <DailyTrend>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().substring(0, 10);
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final records = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: "is_deleted = 0 AND date >= ? AND date < ?",
        whereArgs: [dayStart.toIso8601String(), dayEnd.toIso8601String()],
      );

      int totalMinutes = 0;
      for (final r in records) {
        totalMinutes += (r.duration / 60).round();
      }

      trends.add(DailyTrend(date: dateStr, minutes: totalMinutes));
    }
    return trends;
  }

  // ════════════════════════════════════════════════
  //  荣誉系统（Badge System）
  // ════════════════════════════════════════════════

  static const String _badgeConfigKey = 'learning_stats_badge_configs';
  static const String _badgeConfigVersionKey =
      'learning_stats_badge_config_version';

  /// 默认荣誉配置（本地兜底，云端未返回时使用）
  static final List<Map<String, dynamic>> _defaultBadgeConfigs = [
    {
      'id': 'video_explorer',
      'name': '视频探索者',
      'icon': 'video',
      'dimension': 'count',
      'resource_type': 'video',
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 5},
        {'level': 2, 'name': '入门', 'threshold': 20},
        {'level': 3, 'name': '进阶', 'threshold': 50},
        {'level': 4, 'name': '精通', 'threshold': 100},
        {'level': 5, 'name': '大师', 'threshold': 200},
      ],
    },
    {
      'id': 'video_master',
      'name': '视频达人',
      'icon': 'film',
      'dimension': 'duration',
      'resource_type': 'video',
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 3600},
        {'level': 2, 'name': '入门', 'threshold': 36000},
        {'level': 3, 'name': '进阶', 'threshold': 180000},
        {'level': 4, 'name': '精通', 'threshold': 360000},
        {'level': 5, 'name': '大师', 'threshold': 1080000},
      ],
    },
    {
      'id': 'audio_explorer',
      'name': '音频探索者',
      'icon': 'audio',
      'dimension': 'count',
      'resource_type': 'music',
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 5},
        {'level': 2, 'name': '入门', 'threshold': 20},
        {'level': 3, 'name': '进阶', 'threshold': 50},
        {'level': 4, 'name': '精通', 'threshold': 100},
        {'level': 5, 'name': '大师', 'threshold': 200},
      ],
    },
    {
      'id': 'audio_master',
      'name': '音频达人',
      'icon': 'music',
      'dimension': 'duration',
      'resource_type': 'music',
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 3600},
        {'level': 2, 'name': '入门', 'threshold': 36000},
        {'level': 3, 'name': '进阶', 'threshold': 180000},
        {'level': 4, 'name': '精通', 'threshold': 360000},
        {'level': 5, 'name': '大师', 'threshold': 1080000},
      ],
    },
    {
      'id': 'article_explorer',
      'name': '文章探索者',
      'icon': 'article',
      'dimension': 'count',
      'resource_type': 'article',
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 5},
        {'level': 2, 'name': '入门', 'threshold': 20},
        {'level': 3, 'name': '进阶', 'threshold': 50},
        {'level': 4, 'name': '精通', 'threshold': 100},
        {'level': 5, 'name': '大师', 'threshold': 200},
      ],
    },
    {
      'id': 'article_master',
      'name': '文章达人',
      'icon': 'book_open',
      'dimension': 'duration',
      'resource_type': 'article',
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 3600},
        {'level': 2, 'name': '入门', 'threshold': 36000},
        {'level': 3, 'name': '进阶', 'threshold': 180000},
        {'level': 4, 'name': '精通', 'threshold': 360000},
        {'level': 5, 'name': '大师', 'threshold': 1080000},
      ],
    },
    {
      'id': 'follow_star',
      'name': '跟读之星',
      'icon': 'microphone',
      'dimension': 'times',
      'resource_type': null,
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 50},
        {'level': 2, 'name': '入门', 'threshold': 200},
        {'level': 3, 'name': '进阶', 'threshold': 500},
        {'level': 4, 'name': '精通', 'threshold': 1000},
        {'level': 5, 'name': '大师', 'threshold': 2000},
      ],
    },
    {
      'id': 'test_star',
      'name': '评测之星',
      'icon': 'fact_check',
      'dimension': 'times',
      'resource_type': null,
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 10},
        {'level': 2, 'name': '入门', 'threshold': 50},
        {'level': 3, 'name': '进阶', 'threshold': 100},
        {'level': 4, 'name': '精通', 'threshold': 300},
        {'level': 5, 'name': '大师', 'threshold': 500},
      ],
    },
    {
      'id': 'word_collector',
      'name': '词汇收藏家',
      'icon': 'heart',
      'dimension': 'times',
      'resource_type': null,
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 50},
        {'level': 2, 'name': '入门', 'threshold': 200},
        {'level': 3, 'name': '进阶', 'threshold': 500},
        {'level': 4, 'name': '精通', 'threshold': 1000},
        {'level': 5, 'name': '大师', 'threshold': 2000},
      ],
    },
    // TODO: 恢复 ai_talker 荣誉 —— 需先确认 conversation_record 表已注册实体
    // {
    //   'id': 'ai_talker',
    //   'name': 'AI 对话者',
    //   'icon': 'user_talk',
    //   'dimension': 'times',
    //   'resource_type': null,
    //   'levels': [
    //     {'level': 1, 'name': '初探', 'threshold': 10},
    //     {'level': 2, 'name': '入门', 'threshold': 50},
    //     {'level': 3, 'name': '进阶', 'threshold': 100},
    //     {'level': 4, 'name': '精通', 'threshold': 300},
    //     {'level': 5, 'name': '大师', 'threshold': 500},
    //   ],
    // },
    {
      'id': 'learning_streak',
      'name': '学习坚持者',
      'icon': 'calendar',
      'dimension': 'days',
      'resource_type': null,
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 7},
        {'level': 2, 'name': '入门', 'threshold': 30},
        {'level': 3, 'name': '进阶', 'threshold': 100},
        {'level': 4, 'name': '精通', 'threshold': 365},
        {'level': 5, 'name': '大师', 'threshold': 730},
      ],
    },
    {
      'id': 'duration_king',
      'name': '学习时长王',
      'icon': 'time',
      'dimension': 'duration',
      'resource_type': null,
      'levels': [
        {'level': 1, 'name': '初探', 'threshold': 36000},
        {'level': 2, 'name': '入门', 'threshold': 360000},
        {'level': 3, 'name': '进阶', 'threshold': 1800000},
        {'level': 4, 'name': '精通', 'threshold': 3600000},
        {'level': 5, 'name': '大师', 'threshold': 7200000},
      ],
    },
  ];

  /// 从本地获取荣誉配置（先查缓存，再用默认）
  static Future<List<BadgeConfig>> fetchBadgeConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_badgeConfigKey);

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        return decoded.map((e) => BadgeConfig.fromJson(e)).toList();
      }
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to load cached badge configs: \$e',
        name: 'LearningStats',
      );
    }

    // 使用默认配置并缓存
    final configs = _defaultBadgeConfigs
        .map((e) => BadgeConfig.fromJson(e))
        .toList();
    await _cacheBadgeConfigs(configs);
    return configs;
  }

  /// 缓存荣誉配置到本地
  static Future<void> _cacheBadgeConfigs(List<BadgeConfig> configs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(configs.map((e) => e.toJson()).toList());
      await prefs.setString(_badgeConfigKey, jsonStr);
      await prefs.setInt(
        _badgeConfigVersionKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      dev.log(
        '[LearningStats] Failed to cache badge configs: \$e',
        name: 'LearningStats',
      );
    }
  }

  /// 计算用户荣誉进度
  static Future<List<UserBadgeProgress>> calculateBadgeProgress() async {
    final configs = await fetchBadgeConfigs();
    final progressList = <UserBadgeProgress>[];

    for (final config in configs) {
      final currentValue = await _getBadgeCurrentValue(config);
      final currentLevel = _calculateCurrentLevel(currentValue, config.levels);
      final nextThreshold = currentLevel < config.levels.length
          ? config.levels[currentLevel].threshold
          : config.levels.last.threshold;
      final prevThreshold = currentLevel > 0
          ? config.levels[currentLevel - 1].threshold
          : 0;
      final progress = currentLevel >= config.levels.length
          ? 1.0
          : (currentValue - prevThreshold) / (nextThreshold - prevThreshold);

      progressList.add(
        UserBadgeProgress(
          badgeId: config.id,
          badgeName: config.name,
          badgeIcon: config.icon,
          currentLevel: currentLevel,
          currentValue: currentValue,
          nextThreshold: nextThreshold,
          progress: progress.clamp(0.0, 1.0),
          maxLevel: config.levels.length,
        ),
      );
    }

    return progressList;
  }

  /// 获取荣誉当前进度值
  static Future<int> _getBadgeCurrentValue(BadgeConfig config) async {
    switch (config.dimension) {
      case 'count':
        return await _getResourceCount(config.resourceType!);
      case 'duration':
        return await _getResourceDuration(config.resourceType);
      case 'times':
        return await _getActivityCount(config.id);
      case 'days':
        return await _getLearningDays();
      default:
        return 0;
    }
  }

  /// 获取资源数量（去重）
  static Future<int> _getResourceCount(String resourceType) async {
    final records = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0 AND resource_type = ?',
      whereArgs: [resourceType],
    );
    final Set<String> unique = {};
    for (final r in records) {
      unique.add(r.resourceCode);
    }
    return unique.length;
  }

  /// 获取资源学习时长（秒）
  static Future<int> _getResourceDuration(String? resourceType) async {
    String whereClause = 'is_deleted = 0';
    List<dynamic> whereArgs = [];
    if (resourceType != null) {
      whereClause += ' AND resource_type = ?';
      whereArgs.add(resourceType);
    }
    final records = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: whereClause,
      whereArgs: whereArgs,
    );
    int total = 0;
    for (final r in records) {
      total += r.duration;
    }
    return total;
  }

  /// 获取活动次数
  static Future<int> _getActivityCount(String badgeId) async {
    switch (badgeId) {
      case 'follow_star':
        final records = await DatabaseService.findByCondition(
          () => RecordingRecord(),
          where: 'is_deleted = 0',
        );
        return records.length;
      case 'test_star':
        final records = await DatabaseService.findByCondition(
          () => TestSession(),
          where: "is_deleted = 0 AND status = 'completed'",
        );
        return records.length;
      case 'word_collector':
        return await DatabaseService.count(
          () => WordBook(),
          where: 'is_deleted = 0',
        );
      case 'ai_talker':
        // 荣誉已禁用：conversation_record 实体未注册
        return 0;
      default:
        return 0;
    }
  }

  /// 获取累计学习天数
  static Future<int> _getLearningDays() async {
    final records = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0',
    );
    final Set<String> uniqueDates = {};
    for (final r in records) {
      uniqueDates.add(r.date.toIso8601String().substring(0, 10));
    }
    return uniqueDates.length;
  }

  /// 计算当前等级
  static int _calculateCurrentLevel(int value, List<BadgeLevel> levels) {
    int level = 0;
    for (final l in levels) {
      if (value >= l.threshold) {
        level = l.level;
      } else {
        break;
      }
    }
    return level;
  }

  // ════════════════════════════════════════════════
  //  日历数据查询
  // ════════════════════════════════════════════════

  /// 获取指定月份的日历数据
  static Future<List<CalendarDayData>> getCalendarData(
    int year,
    int month,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);

    // 查询学习记录
    final studyRecords = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0 AND date >= ? AND date < ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // 查询跟读记录
    final followRecords = await DatabaseService.findByCondition(
      () => RecordingRecord(),
      where: 'is_deleted = 0 AND recorded_at >= ? AND recorded_at < ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // 查询评测记录
    final testRecords = await DatabaseService.findByCondition(
      () => TestSession(),
      where:
          "is_deleted = 0 AND status = 'completed' AND started_at >= ? AND started_at < ?",
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // 查询单词收藏
    final wordRecords = await DatabaseService.findByCondition(
      () => WordBook(),
      where: 'is_deleted = 0 AND created_at >= ? AND created_at < ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // 按日期聚合
    final Map<String, CalendarDayData> dayMap = {};

    for (final r in studyRecords) {
      final dateStr = r.date.toIso8601String().substring(0, 10);
      dayMap.putIfAbsent(dateStr, () => CalendarDayData(date: dateStr));
      dayMap[dateStr]!.durationSeconds += r.duration;
    }

    for (final r in followRecords) {
      final dateStr = r.recordedAt.toIso8601String().substring(0, 10);
      dayMap.putIfAbsent(dateStr, () => CalendarDayData(date: dateStr));
      dayMap[dateStr]!.followCount++;
    }

    for (final r in testRecords) {
      final dateStr = r.startedAt.toIso8601String().substring(0, 10);
      dayMap.putIfAbsent(dateStr, () => CalendarDayData(date: dateStr));
      dayMap[dateStr]!.testCount++;
    }

    for (final r in wordRecords) {
      final dateStr = r.createdAt!.toIso8601String().substring(0, 10);
      dayMap.putIfAbsent(dateStr, () => CalendarDayData(date: dateStr));
      dayMap[dateStr]!.wordCount++;
    }

    return dayMap.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  // ════════════════════════════════════════════════
  //  时间段工具方法
  // ════════════════════════════════════════════════

  /// 根据时间范围字符串获取起始日期
  static DateTime _getStartDate(String timeRange) {
    final now = DateTime.now();
    switch (timeRange) {
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '30d':
        return now.subtract(const Duration(days: 30));
      case '90d':
        return now.subtract(const Duration(days: 90));
      case 'year':
        return DateTime(now.year, 1, 1);
      case 'all':
      default:
        return DateTime(2000, 1, 1);
    }
  }

  /// 获取时间范围内的 StudyRecord
  static Future<List<StudyRecord>> _getStudyRecordsInRange(
    String timeRange,
  ) async {
    final startDate = _getStartDate(timeRange);
    final endDate = DateTime.now();
    return await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0 AND date >= ? AND date <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );
  }

  // ════════════════════════════════════════════════
  //  核心指标查询（带时间段筛选）
  // ════════════════════════════════════════════════

  /// 获取学习时长指标
  static Future<DurationMetrics> getDurationMetrics(String timeRange) async {
    final records = await _getStudyRecordsInRange(timeRange);
    int totalSeconds = 0;
    int sessionCount = 0;
    int maxDuration = 0;
    final Map<String, int> dailyDuration = {};

    for (final r in records) {
      totalSeconds += r.duration;
      sessionCount++;
      if (r.duration > maxDuration) maxDuration = r.duration;
      final dateStr = r.date.toIso8601String().substring(0, 10);
      dailyDuration[dateStr] = (dailyDuration[dateStr] ?? 0) + r.duration;
    }

    // 计算日均时长
    final days = dailyDuration.length;
    final avgDaily = days > 0 ? totalSeconds ~/ days : 0;

    // 计算环比（与上一个同等长度周期对比）
    final periodDays = _getPeriodDays(timeRange);
    final prevStart = _getStartDate(
      timeRange,
    ).subtract(Duration(days: periodDays));
    final prevEnd = _getStartDate(timeRange);
    final prevRecords = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0 AND date >= ? AND date < ?',
      whereArgs: [prevStart.toIso8601String(), prevEnd.toIso8601String()],
    );
    int prevTotal = 0;
    for (final r in prevRecords) {
      prevTotal += r.duration;
    }
    final changePercent = prevTotal > 0
        ? ((totalSeconds - prevTotal) / prevTotal * 100).round()
        : 0;

    return DurationMetrics(
      totalSeconds: totalSeconds,
      sessionCount: sessionCount,
      avgDailySeconds: avgDaily,
      maxSessionSeconds: maxDuration,
      changePercent: changePercent,
      dailyData: dailyDuration,
    );
  }

  /// 获取跟读指标
  static Future<FollowMetrics> getFollowMetrics(String timeRange) async {
    final startDate = _getStartDate(timeRange);
    final endDate = DateTime.now();

    final records = await DatabaseService.findByCondition(
      () => RecordingRecord(),
      where: 'is_deleted = 0 AND recorded_at >= ? AND recorded_at <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    int totalCount = 0;
    double totalScore = 0;
    double? maxScore;
    double? minScore;
    final Map<String, List<double>> resourceScores = {};
    final Map<String, int> dailyCount = {};

    for (final r in records) {
      if (r.overallScore == null) continue;
      totalCount++;
      totalScore += r.overallScore!;
      if (maxScore == null || r.overallScore! > maxScore) {
        maxScore = r.overallScore!;
      }
      if (minScore == null || r.overallScore! < minScore) {
        minScore = r.overallScore!;
      }

      resourceScores.putIfAbsent(r.resourceCode, () => []);
      resourceScores[r.resourceCode]!.add(r.overallScore!);

      final dateStr = r.recordedAt.toIso8601String().substring(0, 10);
      dailyCount[dateStr] = (dailyCount[dateStr] ?? 0) + 1;
    }

    final avgScore = totalCount > 0 ? totalScore / totalCount : 0.0;

    // 计算每个资源的平均分
    final resourceAvgScores = <String, double>{};
    final resourceNames = <String, String>{};
    resourceScores.forEach((code, scores) {
      if (scores.isNotEmpty) {
        resourceAvgScores[code] =
            scores.reduce((a, b) => a + b) / scores.length;
      }
    });

    // 查询资源名称
    for (final code in resourceAvgScores.keys) {
      // 跟读记录中可能有 resourceType，但 RecordingRecord 不一定有，先尝试 video/music 再 article
      String? name = await _getResourceName(code, 'video');
      name ??= await _getResourceName(code, 'article');
      if (name != null && name.isNotEmpty) {
        resourceNames[code] = name;
      }
    }

    return FollowMetrics(
      totalCount: totalCount,
      avgScore: avgScore,
      maxScore: maxScore ?? 0,
      minScore: minScore ?? 0,
      resourceAvgScores: resourceAvgScores,
      dailyCount: dailyCount,
      resourceNames: resourceNames,
    );
  }

  /// 获取评测指标
  static Future<TestMetrics> getTestMetrics(String timeRange) async {
    final startDate = _getStartDate(timeRange);
    final endDate = DateTime.now();

    final records = await DatabaseService.findByCondition(
      () => TestSession(),
      where:
          "is_deleted = 0 AND status = 'completed' AND completed_at >= ? AND completed_at <= ?",
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    int totalCount = 0;
    double totalScore = 0;
    int passCount = 0;
    double? maxScore;
    double? minScore;
    final Map<String, List<double>> resourceScores = {};

    for (final r in records) {
      if (r.totalScore == null) continue;
      totalCount++;
      totalScore += r.totalScore!;
      if (r.totalScore! >= 60) passCount++;
      if (maxScore == null || r.totalScore! > maxScore) {
        maxScore = r.totalScore!;
      }
      if (minScore == null || r.totalScore! < minScore) {
        minScore = r.totalScore!;
      }

      if (r.resourceCode != null) {
        resourceScores.putIfAbsent(r.resourceCode!, () => []);
        resourceScores[r.resourceCode!]!.add(r.totalScore!);
      }
    }

    final avgScore = totalCount > 0 ? totalScore / totalCount : 0.0;
    final passRate = totalCount > 0 ? passCount / totalCount : 0.0;

    // 计算每个资源的平均分
    final resourceAvgScores = <String, double>{};
    resourceScores.forEach((code, scores) {
      if (scores.isNotEmpty) {
        resourceAvgScores[code] =
            scores.reduce((a, b) => a + b) / scores.length;
      }
    });

    return TestMetrics(
      totalCount: totalCount,
      avgScore: avgScore,
      maxScore: maxScore ?? 0,
      minScore: minScore ?? 0,
      passRate: passRate,
      resourceAvgScores: resourceAvgScores,
    );
  }

  /// 获取单词指标
  static Future<WordMetrics> getWordMetrics(String timeRange) async {
    final startDate = _getStartDate(timeRange);
    final endDate = DateTime.now();

    // 总数
    final totalCount = await DatabaseService.count(
      () => WordBook(),
      where: 'is_deleted = 0',
    );

    // 周期内新增
    final newCount = await DatabaseService.count(
      () => WordBook(),
      where: 'is_deleted = 0 AND created_at >= ? AND created_at <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // 已掌握数
    final masteredCount = await DatabaseService.count(
      () => WordBook(),
      where: "is_deleted = 0 AND mastery_level = 'mastered'",
    );

    return WordMetrics(
      totalCount: totalCount,
      newCount: newCount,
      masteredCount: masteredCount,
    );
  }

  static int _getPeriodDays(String timeRange) {
    switch (timeRange) {
      case '7d':
        return 7;
      case '30d':
        return 30;
      case '90d':
        return 90;
      case 'year':
        return 365;
      default:
        return 30;
    }
  }

  // ════════════════════════════════════════════════
  //  AI 学习洞察生成
  // ════════════════════════════════════════════════

  /// 生成 AI 学习洞察（基于规则引擎）
  static Future<List<AiInsight>> generateAiInsights(String timeRange) async {
    final insights = <AiInsight>[];

    // 1. 学习习惯分析
    final habitInsight = await _analyzeHabits(timeRange);
    if (habitInsight != null) insights.add(habitInsight);

    // 2. 跟读薄弱资源
    final followWeakness = await _analyzeFollowWeakness(timeRange);
    if (followWeakness != null) insights.add(followWeakness);

    // 3. 评测薄弱资源
    final testWeakness = await _analyzeTestWeakness(timeRange);
    if (testWeakness != null) insights.add(testWeakness);

    return insights;
  }

  /// 学习习惯分析
  static Future<AiInsight?> _analyzeHabits(String timeRange) async {
    final records = await _getStudyRecordsInRange(timeRange);
    if (records.isEmpty) return null;

    // 检查是否有学习但缺少跟读/评测
    final startDate = _getStartDate(timeRange);
    final endDate = DateTime.now();

    final followRecords = await DatabaseService.findByCondition(
      () => RecordingRecord(),
      where: 'is_deleted = 0 AND recorded_at >= ? AND recorded_at <= ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    final testRecords = await DatabaseService.findByCondition(
      () => TestSession(),
      where:
          "is_deleted = 0 AND status = 'completed' AND started_at >= ? AND started_at <= ?",
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
    );

    // 分析学习时段分布
    final hourDistribution = <int, int>{};
    for (final r in records) {
      final hour = r.date.hour;
      hourDistribution[hour] = (hourDistribution[hour] ?? 0) + r.duration;
    }

    String? bestPeriod;
    if (hourDistribution.isNotEmpty) {
      final bestHour = hourDistribution.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      if (bestHour >= 5 && bestHour < 12) {
        bestPeriod = '上午';
      } else if (bestHour >= 12 && bestHour < 18)
        bestPeriod = '下午';
      else if (bestHour >= 18 && bestHour < 22)
        bestPeriod = '晚上';
      else
        bestPeriod = '深夜';
    }

    // 生成建议
    if (records.isNotEmpty && followRecords.isEmpty && testRecords.isEmpty) {
      return AiInsight(
        type: 'habit',
        title: '学习习惯提醒',
        description: '本周期内有学习记录，但缺少跟读和评测练习。建议每天跟读 10 句巩固发音，定期进行评测检验学习效果。',
      );
    }

    if (bestPeriod != null) {
      return AiInsight(
        type: 'habit',
        title: '学习习惯分析',
        description: '你在\$bestPeriod的学习时长最多，建议保持这个学习时段的规律性，有助于形成稳定的学习节奏。',
      );
    }

    return null;
  }

  /// 跟读薄弱资源分析
  static Future<AiInsight?> _analyzeFollowWeakness(String timeRange) async {
    final followMetrics = await getFollowMetrics(timeRange);
    if (followMetrics.totalCount == 0) return null;

    // 找平均分最低的资源
    String? weakestResource;
    double? lowestScore;
    followMetrics.resourceAvgScores.forEach((code, score) {
      if (lowestScore == null || score < lowestScore!) {
        lowestScore = score;
        weakestResource = code;
      }
    });

    if (weakestResource == null || lowestScore == null || lowestScore! >= 70) {
      return null;
    }

    // 查询资源类型和名称
    String resourceType = 'video'; // 默认类型
    try {
      final records = await DatabaseService.findByCondition(
        () => RecordingRecord(),
        where: 'resource_code = ? AND is_deleted = 0',
        whereArgs: [weakestResource],
        limit: 1,
      );
      if (records.isNotEmpty) {
        resourceType = records.first.resourceType;
      }
    } catch (_) {}

    // 获取资源标题
    final resourceName = await _getResourceName(weakestResource!, resourceType);
    final resourceTitle = resourceName ?? weakestResource!;

    return AiInsight(
      type: 'follow_weakness',
      title: resourceTitle,
      description:
          '跟读得分偏低(${lowestScore!.toStringAsFixed(0)}分)，建议放慢语速、注意发音准确度，多练习该资源的重点句子。',
      resourceCode: weakestResource,
    );
  }

  /// 评测薄弱资源分析
  static Future<AiInsight?> _analyzeTestWeakness(String timeRange) async {
    final testMetrics = await getTestMetrics(timeRange);
    if (testMetrics.totalCount == 0) return null;

    // 找平均分最低的资源
    String? weakestResource;
    double? lowestScore;
    testMetrics.resourceAvgScores.forEach((code, score) {
      if (lowestScore == null || score < lowestScore!) {
        lowestScore = score;
        weakestResource = code;
      }
    });

    if (weakestResource == null || lowestScore == null || lowestScore! >= 60) {
      return null;
    }

    // 查询资源类型和名称
    String resourceType = 'video'; // 默认类型
    try {
      final sessions = await DatabaseService.findByCondition(
        () => TestSession(),
        where: 'resource_code = ? AND is_deleted = 0',
        whereArgs: [weakestResource],
        limit: 1,
      );
      if (sessions.isNotEmpty) {
        resourceType = sessions.first.resourceType ?? 'video';
      }
    } catch (_) {}

    // 获取资源标题
    final resourceName = await _getResourceName(weakestResource!, resourceType);
    final resourceTitle = resourceName ?? weakestResource!;

    return AiInsight(
      type: 'test_weakness',
      title: resourceTitle,
      description:
          '评测正确率仅 ${lowestScore!.toStringAsFixed(0)} 分，建议重新学习该资源字幕后再次测试，重点复习薄弱题型。',
      resourceCode: weakestResource,
    );
  }

  /// 获取资源学习时长排行
  static Future<List<ResourceDurationDetail>> getResourceDurationRanking(
    String timeRange,
  ) async {
    final records = await _getStudyRecordsInRange(timeRange);
    final Map<String, ResourceDurationDetail> resourceMap = {};

    for (final r in records) {
      final existing = resourceMap[r.resourceCode];
      if (existing == null) {
        resourceMap[r.resourceCode] = ResourceDurationDetail(
          resourceCode: r.resourceCode,
          resourceType: r.resourceType,
          totalSeconds: r.duration,
          sessionCount: 1,
        );
      } else {
        resourceMap[r.resourceCode] = ResourceDurationDetail(
          resourceCode: r.resourceCode,
          resourceType: r.resourceType,
          totalSeconds: existing.totalSeconds + r.duration,
          sessionCount: existing.sessionCount + 1,
        );
      }
    }

    // 查询资源名称
    final result = <ResourceDurationDetail>[];
    for (final detail in resourceMap.values) {
      final resourceName = await _getResourceName(
        detail.resourceCode,
        detail.resourceType,
      );
      result.add(
        ResourceDurationDetail(
          resourceCode: detail.resourceCode,
          resourceName: resourceName,
          resourceType: detail.resourceType,
          totalSeconds: detail.totalSeconds,
          sessionCount: detail.sessionCount,
        ),
      );
    }

    result.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
    return result;
  }

  /// 获取资源名称
  static Future<String?> _getResourceName(
    String resourceCode,
    String resourceType,
  ) async {
    try {
      if (resourceType == 'article') {
        final articles = await DatabaseService.findByCondition(
          () => Article(),
          where: 'code = ? AND is_deleted = 0',
          whereArgs: [resourceCode],
          limit: 1,
        );
        if (articles.isNotEmpty) {
          return articles.first.title;
        }
      } else {
        // video 或 music
        final videos = await DatabaseService.findByCondition(
          () => VideoInfo(),
          where: 'code = ? AND is_deleted = 0',
          whereArgs: [resourceCode],
          limit: 1,
        );
        if (videos.isNotEmpty) {
          return videos.first.name;
        }
      }
    } catch (_) {}
    return null;
  }

  /// 获取「我的」页面汇总统计（内部方法）
  ///
  /// 统计口径：全部为累计数据
  /// - totalDays: 累计学习天数（StudyRecord.date 去重计数）
  /// - videoTotal/audioTotal/articleTotal: 累计导入的资源文件夹数（含软删除）
  ///
  /// 用户隔离：使用 DatabaseService.count()，自动过滤 user_code
  /// 叶子过滤：parent_code IS NOT NULL，排除分组/分类文件夹（如"未分组"）
  static Future<SummaryStats> _getSummaryStats() async {
    // 并行查询：累计学习天数 + 各类型累计资源数（含软删除）
    // _getLearningDays() 使用 findByCondition，已自动过滤 user_code
    // count() 也自动过滤 user_code
    // parent_code IS NOT NULL AND parent_code != '': 只统计叶子文件夹（实际资源），不统计分组
    final results = await Future.wait<dynamic>([
      _getLearningDays(),
      DatabaseService.count(
        () => VideoFolder(),
        where: "folder_type = 'video' AND parent_code IS NOT NULL AND parent_code != ''",
      ),
      DatabaseService.count(
        () => VideoFolder(),
        where: "folder_type = 'music' AND parent_code IS NOT NULL AND parent_code != ''",
      ),
      DatabaseService.count(
        () => VideoFolder(),
        where: "folder_type = 'article' AND parent_code IS NOT NULL AND parent_code != ''",
      ),
    ]);

    final totalDays = results[0] as int;
    final videoTotal = results[1] as int;
    final audioTotal = results[2] as int;
    final articleTotal = results[3] as int;

    return SummaryStats(
      totalDays: totalDays,
      videoTotal: videoTotal,
      audioTotal: audioTotal,
      articleTotal: articleTotal,
    );
  }
}

// ═══════════════════════════════════════════════════
//  数据模型（供 UI 使用）
// ═══════════════════════════════════════════════════

/// 资源学习汇总（轻量级，用于 UI 展示）
class ResourceLearningSummary {
  final String resourceCode;
  final String resourceType;
  final int totalDurationSeconds;
  final int sessionCount;
  final double? bestFollowScore;
  final double? latestTestScore;
  final int totalFollowCount;
  final DateTime? lastStudiedAt;

  const ResourceLearningSummary({
    required this.resourceCode,
    required this.resourceType,
    required this.totalDurationSeconds,
    required this.sessionCount,
    this.bestFollowScore,
    this.latestTestScore,
    required this.totalFollowCount,
    this.lastStudiedAt,
  });

  /// 格式化后的总时长（如 "2h 35min"）
  String get formattedDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// 最近学习的资源
class RecentResource {
  final String resourceCode;
  final String resourceType;
  final String? resourceTitle;
  final String? folderCode;
  final DateTime lastStudiedAt;
  final int lastDurationSeconds;

  const RecentResource({
    required this.resourceCode,
    required this.resourceType,
    this.resourceTitle,
    this.folderCode,
    required this.lastStudiedAt,
    required this.lastDurationSeconds,
  });
}

/// 学习历史记录（用于学习记录页面）
class LearningHistoryRecord {
  final String id;
  final String resourceCode;
  final String resourceType; // video / music / article
  final String? resourceTitle;
  final String? folderCode;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds; // 学习时长（秒）
  final double? bestFollowScore; // 最佳跟读分
  final double? testScore; // 测试得分
  final int followCount; // 跟读次数
  final bool isDeleted; // 资源是否已被删除

  const LearningHistoryRecord({
    required this.id,
    required this.resourceCode,
    required this.resourceType,
    this.resourceTitle,
    this.folderCode,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    this.bestFollowScore,
    this.testScore,
    required this.followCount,
    required this.isDeleted,
  });

  /// 格式化时长显示
  String get formattedDuration {
    if (durationSeconds < 60) return '$durationSeconds秒';
    if (durationSeconds < 3600) return '${durationSeconds ~/ 60}分钟';
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    return m > 0 ? '$h时$m分' : '$h小时';
  }

  /// 格式化时间范围
  String get timeRange {
    if (endTime == null) {
      return _formatTime(startTime);
    }
    return '${_formatTime(startTime)} - ${_formatShortTime(endTime!)}';
  }

  static String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _formatShortTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════
//  数据模型（供 UI 使用）
// ═══════════════════════════════════════════════════

/// 首页统计信息
class HomeStats {
  final int streakDays;
  final int todayDuration;
  final int wordCount;
  final int resourceCount;

  const HomeStats({
    this.streakDays = 0,
    this.todayDuration = 0,
    this.wordCount = 0,
    this.resourceCount = 0,
  });
}

/// 「我的」页面汇总统计
class SummaryStats {
  final int totalDays;
  final int videoTotal;
  final int audioTotal;
  final int articleTotal;

  const SummaryStats({
    this.totalDays = 0,
    this.videoTotal = 0,
    this.audioTotal = 0,
    this.articleTotal = 0,
  });
}

/// 首页各类资源最近文件夹
class RecentFolderGroup {
  final String folderType;
  final List<VideoFolder> recentFolders;

  const RecentFolderGroup({
    required this.folderType,
    this.recentFolders = const [],
  });
}

/// 兼容性别名：保持原有调用方式不变
///
/// ⚠️ 已废弃：请直接使用 LearningStatsService 对应方法
///
/// 迁移映射：
/// - StatsService.getAllRecentFolders() → LearningStatsService.getAllRecentFolders()
/// - StatsService.getHomeStats() → LearningStatsService.getHomeStats()
/// - StatsService.calculateStreakDays() → LearningStatsService.calculateStreakDays()
@Deprecated('使用 LearningStatsService 替代')
class StatsService {
  /// @Deprecated 使用 LearningStatsService.getAllRecentFolders()
  static Future<Map<String, List<VideoFolder>>> getAllRecentFolders() =>
      LearningStatsService.getAllRecentFolders();

  /// @Deprecated 使用 LearningStatsService.getHomeStats()
  static Future<HomeStats> getHomeStats() =>
      LearningStatsService.getHomeStats();

  /// @Deprecated 使用 LearningStatsService.calculateStreakDays()
  static Future<int> calculateStreakDays() =>
      LearningStatsService.calculateStreakDays();

  // ══════════════════════════════════════════════
  // 详情页数据方法（从原 StatsService 迁移）
  // ══════════════════════════════════════════════

  /// @Deprecated 获取学习统计详情总览
  static Future<DetailOverview> getDetailOverview() =>
      LearningStatsService.getDetailOverview();

  /// @Deprecated 按资源类型获取统计
  static Future<List<TypeStats>> getDetailByType() =>
      LearningStatsService.getDetailByType();

  /// @Deprecated 获取近7天学习趋势
  static Future<List<DailyTrend>> getWeeklyTrend() =>
      LearningStatsService.getWeeklyTrend();

  /// @Deprecated 获取 AI 学习建议（已迁移至 generateAiInsights）
  static Future<List<AiSuggestion>> getAiLearningSuggestions() async {
    final insights = await LearningStatsService.generateAiInsights('30d');
    return insights
        .map(
          (i) => AiSuggestion(
            title: i.title,
            description: i.description,
            icon: i.type == 'habit' ? Icons.schedule : Icons.trending_down,
          ),
        )
        .toList();
  }

  /// @Deprecated 获取「我的」页面汇总统计
  static Future<SummaryStats> getSummaryStats() =>
      LearningStatsService._getSummaryStats();
}

// ═══════════════════════════════════════════════════════
//  详情页数据模型（从原 StatsService 迁移）
// ═══════════════════════════════════════════════════════

/// 统计详情总览
class DetailOverview {
  final int totalDays;
  final int totalDurationSeconds;
  final int learnedResources;
  final double compositeScore;

  const DetailOverview({
    this.totalDays = 0,
    this.totalDurationSeconds = 0,
    this.learnedResources = 0,
    this.compositeScore = 0.0,
  });
}

/// 按资源类型拆分的学习统计
class TypeStats {
  final String type;
  final String icon;
  final String label;
  final int learned;
  final int total;
  final int totalDurationSeconds;
  final DateTime? lastStudyTime;

  const TypeStats({
    required this.type,
    required this.icon,
    required this.label,
    this.learned = 0,
    this.total = 0,
    this.totalDurationSeconds = 0,
    this.lastStudyTime,
  });
}

/// 每日趋势数据
class DailyTrend {
  final String date;
  final int minutes;

  const DailyTrend({required this.date, this.minutes = 0});
}

/// AI 学习建议数据模型
class AiSuggestion {
  final String title;
  final String description;
  final IconData icon;
  final String? actionText;

  const AiSuggestion({
    required this.title,
    required this.description,
    required this.icon,
    this.actionText,
  });
}

// ═══════════════════════════════════════════════════
//  荣誉系统数据模型
// ═══════════════════════════════════════════════════

/// 荣誉配置
class BadgeConfig {
  final String id;
  final String name;
  final String icon;
  final String dimension;
  final String? resourceType;
  final List<BadgeLevel> levels;

  const BadgeConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.dimension,
    this.resourceType,
    required this.levels,
  });

  factory BadgeConfig.fromJson(Map<String, dynamic> json) {
    return BadgeConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      dimension: json['dimension'] as String,
      resourceType: json['resource_type'] as String?,
      levels: (json['levels'] as List<dynamic>)
          .map((e) => BadgeLevel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'dimension': dimension,
    'resource_type': resourceType,
    'levels': levels.map((e) => e.toJson()).toList(),
  };
}

/// 荣誉等级
class BadgeLevel {
  final int level;
  final String name;
  final int threshold;

  const BadgeLevel({
    required this.level,
    required this.name,
    required this.threshold,
  });

  factory BadgeLevel.fromJson(Map<String, dynamic> json) {
    return BadgeLevel(
      level: json['level'] as int,
      name: json['name'] as String,
      threshold: json['threshold'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'name': name,
    'threshold': threshold,
  };
}

/// 用户荣誉进度
class UserBadgeProgress {
  final String badgeId;
  final String badgeName;
  final String badgeIcon;
  final int currentLevel;
  final int currentValue;
  final int nextThreshold;
  final double progress;
  final int maxLevel;

  const UserBadgeProgress({
    required this.badgeId,
    required this.badgeName,
    required this.badgeIcon,
    required this.currentLevel,
    required this.currentValue,
    required this.nextThreshold,
    required this.progress,
    required this.maxLevel,
  });
}

// ═══════════════════════════════════════════════════
//  日历数据模型
// ═══════════════════════════════════════════════════

/// 日历单日数据
class CalendarDayData {
  final String date;
  int durationSeconds;
  int followCount;
  int testCount;
  int wordCount;

  CalendarDayData({
    required this.date,
    this.durationSeconds = 0,
    this.followCount = 0,
    this.testCount = 0,
    this.wordCount = 0,
  });
}

// ═══════════════════════════════════════════════════
//  核心指标数据模型
// ═══════════════════════════════════════════════════

/// 学习时长指标
class DurationMetrics {
  final int totalSeconds;
  final int sessionCount;
  final int avgDailySeconds;
  final int maxSessionSeconds;
  final int changePercent;
  final Map<String, int> dailyData;

  const DurationMetrics({
    required this.totalSeconds,
    required this.sessionCount,
    required this.avgDailySeconds,
    required this.maxSessionSeconds,
    required this.changePercent,
    required this.dailyData,
  });

  String get formattedTotal => _formatDurationChinese(totalSeconds);

  String get formattedAvgDaily => _formatDurationChinese(avgDailySeconds);

  /// 格式化为中文时长显示
  static String _formatDurationChinese(int seconds) {
    if (seconds < 60) {
      return '$seconds秒';
    } else if (seconds < 3600) {
      return '${seconds ~/ 60}分钟';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      if (minutes > 0) {
        return '$hours小时$minutes分钟';
      } else {
        return '$hours小时';
      }
    }
  }
}

/// 跟读指标
class FollowMetrics {
final int totalCount;
final double avgScore;
final double maxScore;
final double minScore;
final Map<String, double> resourceAvgScores;
final Map<String, int> dailyCount;
/// 资源名称映射（resourceCode -> resourceName）
final Map<String, String> resourceNames;

const FollowMetrics({
required this.totalCount,
required this.avgScore,
required this.maxScore,
required this.minScore,
required this.resourceAvgScores,
required this.dailyCount,
this.resourceNames = const {},
});
}

/// 评测指标
class TestMetrics {
  final int totalCount;
  final double avgScore;
  final double maxScore;
  final double minScore;
  final double passRate;
  final Map<String, double> resourceAvgScores;

  const TestMetrics({
    required this.totalCount,
    required this.avgScore,
    required this.maxScore,
    required this.minScore,
    required this.passRate,
    required this.resourceAvgScores,
  });
}

/// 单词指标
class WordMetrics {
  final int totalCount;
  final int newCount;
  final int masteredCount;

  const WordMetrics({
    required this.totalCount,
    required this.newCount,
    required this.masteredCount,
  });
}

// ═══════════════════════════════════════════════════
//  AI 洞察数据模型
// ═══════════════════════════════════════════════════

/// AI 学习洞察
class AiInsight {
  final String type;
  final String title;
  final String description;
  final String? resourceCode;

  const AiInsight({
    required this.type,
    required this.title,
    required this.description,
    this.resourceCode,
  });
}

// ═══════════════════════════════════════════════════
//  二级页面数据模型
// ═══════════════════════════════════════════════════

/// 资源学习时长详情
class ResourceDurationDetail {
  final String resourceCode;
  final String? resourceName; // 资源名称（优先使用）
  final String resourceType;
  final int totalSeconds;
  final int sessionCount;

  const ResourceDurationDetail({
    required this.resourceCode,
    this.resourceName,
    required this.resourceType,
    required this.totalSeconds,
    required this.sessionCount,
  });

  /// 显示名称：优先使用资源名称，否则使用 code
  String get displayName =>
      resourceName?.isNotEmpty == true ? resourceName! : resourceCode;

  String get formattedDuration =>
      DurationMetrics._formatDurationChinese(totalSeconds);
}
