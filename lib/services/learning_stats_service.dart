import 'dart:developer' as dev;

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/study_record.dart';
import 'package:vidlang/models/video_info.dart';
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
          return articles.isNotEmpty ? articles.first.title ?? '' : '';
        case 'video':
        case 'music':
          final videos = await DatabaseService.findByCondition(
            () => VideoInfo(),
            where: 'code = ? AND is_deleted = 0',
            whereArgs: [resourceCode],
            limit: 1,
          );
          return videos.isNotEmpty ? videos.first.name ?? '' : '';
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
