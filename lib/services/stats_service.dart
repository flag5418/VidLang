import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vidlang/models/study_record.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/database_service.dart';

/// 首页统计信息
class HomeStats {
  /// 连续学习天数
  final int streakDays;

  /// 今日学习时长（秒）
  final int todayDuration;

  /// 今日收藏单词数
  final int wordCount;

  /// 今日学习资源数（不重复）
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
  /// 累计学习天数（study_record 所有日期去重）
  final int totalDays;

  /// 视频资源总数
  final int videoTotal;

  /// 音频资源总数
  final int audioTotal;

  /// 文章资源总数
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
  /// 文件夹内容类型
  final String folderType;

  /// 最近3个文件夹
  final List<VideoFolder> recentFolders;

  const RecentFolderGroup({
    required this.folderType,
    this.recentFolders = const [],
  });
}

/// 统计服务
///
/// 提供首页所需的聚合数据：
/// - 各类型最近文件夹
/// - 学习统计（连续天数、今日时长等）
class StatsService {
  StatsService._();

  /// 获取指定类型的最近文件夹（最多3个）
  static Future<List<VideoFolder>> getRecentFolders(String folderType, {int limit = 3}) async {
    final rows = await DatabaseService.findByCondition(
      () => VideoFolder(),
      where: "is_deleted = 0 AND parent_code IS NOT NULL AND parent_code != '' AND folder_type = ?",
      whereArgs: [folderType],
      orderBy: 'CASE WHEN last_play_date IS NULL THEN 1 ELSE 0 END, last_play_date DESC, created_at DESC',
      limit: limit,
    );

    // 确保最多返回 limit 个
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

    // 按日期去重
    final Set<String> uniqueDates = {};
    for (final r in allRecords) {
      uniqueDates.add(r.date.toIso8601String().substring(0, 10));
    }

    if (uniqueDates.isEmpty) return 0;

    final sortedDates = uniqueDates.toList()..sort((a, b) => b.compareTo(a));

    // 计算连续天数
    int streak = 1;
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);

    // 如果今天没有记录，从昨天开始算
    int startOffset = 0;
    if (sortedDates.first != todayStr) {
      // 检查昨天
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = yesterday.toIso8601String().substring(0, 10);
      if (sortedDates.first != yesterdayStr) {
        return 0; // 昨天也没学习
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
  static Future<int> getTodayDuration() async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);

    final records = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: "is_deleted = 0 AND date >= ? AND date < ?",
      whereArgs: [
        '${todayStr}T00:00:00',
        '${todayStr}T23:59:59',
      ],
    );

    int total = 0;
    for (final r in records) {
      total += r.duration;
    }
    return total;
  }

  /// 获取今日收藏单词数
  static Future<int> getWordCount() async {
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
  static Future<int> getResourceCount() async {
    final today = DateTime.now();
    final todayStr = DateTime(today.year, today.month, today.day).toIso8601String().substring(0, 10);

    final records = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: "is_deleted = 0 AND date >= ? AND date < ?",
      whereArgs: ['${todayStr}T00:00:00', '${todayStr}T23:59:59'],
    );

    final Set<String> unique = {};
    for (final r in records) {
      final key = '${r.resourceType}_${r.resourceCode}';
      unique.add(key);
    }
    return unique.length;
  }

  /// 获取「我的」页面汇总统计
  static Future<SummaryStats> getSummaryStats() async {
    final allRecords = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0',
    );

    // 总学习天数：所有 date 去重
    final Set<String> uniqueDates = {};
    for (final r in allRecords) {
      uniqueDates.add(r.date.toIso8601String().substring(0, 10));
    }
    final totalDays = uniqueDates.length;

    // 视频/音频/文章文件夹总数
    final counts = await Future.wait([
      DatabaseService.rawQuery("SELECT COUNT(*) AS cnt FROM video_folder WHERE folder_type = 'video' AND is_deleted = 0"),
      DatabaseService.rawQuery("SELECT COUNT(*) AS cnt FROM video_folder WHERE folder_type = 'music' AND is_deleted = 0"),
      DatabaseService.rawQuery("SELECT COUNT(*) AS cnt FROM video_folder WHERE folder_type = 'article' AND is_deleted = 0"),
    ]);

    final videoTotal = (counts[0].first['cnt'] as int?) ?? 0;
    final audioTotal = (counts[1].first['cnt'] as int?) ?? 0;
    final articleTotal = (counts[2].first['cnt'] as int?) ?? 0;

    return SummaryStats(
      totalDays: totalDays,
      videoTotal: videoTotal,
      audioTotal: audioTotal,
      articleTotal: articleTotal,
    );
  }

  /// 获取首页完整统计信息
  static Future<HomeStats> getHomeStats() async {
    final results = await Future.wait([
      calculateStreakDays(),
      getTodayDuration(),
      getWordCount(),
      getResourceCount(),
    ]);

    return HomeStats(
      streakDays: results[0],
      todayDuration: results[1],
      wordCount: results[2],
      resourceCount: results[3],
    );
  }

  // ─── 详情页数据模型 ───

  /// 获取学习统计详情总览
  static Future<DetailOverview> getDetailOverview() async {
    final allRecords = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0',
    );

    // 累计学习天数
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
    final summary = await getSummaryStats();
    final streakDays = await calculateStreakDays();
    final totalWordCount = await DatabaseService.count(
      () => WordBook(),
      where: 'is_deleted = 0',
    );

    final int totalResources = summary.videoTotal + summary.audioTotal + summary.articleTotal;

    // 综合评分计算
    final double dayScore = (totalDays / 30).clamp(0.0, 1.0) * 100;
    final double completionScore = totalResources > 0
        ? (learnedResources / totalResources).clamp(0.0, 1.0) * 100
        : 0.0;
    final double streakScore = (streakDays / 7).clamp(0.0, 1.0) * 100;
    final double wordScore = (totalWordCount / 100).clamp(0.0, 1.0) * 100;
    final double compositeScore = dayScore * 0.3 + completionScore * 0.3 + streakScore * 0.2 + wordScore * 0.2;

    return DetailOverview(
      totalDays: totalDays,
      totalDurationSeconds: totalDurationSeconds,
      learnedResources: learnedResources,
      compositeScore: compositeScore,
    );
  }

  /// 获取按类型拆分的学习详情
  static Future<List<TypeStats>> getDetailByType() async {
    final allRecords = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0',
    );

    // 获取各类总数
    final counts = await Future.wait([
      DatabaseService.rawQuery("SELECT COUNT(*) AS cnt FROM video_folder WHERE folder_type = 'video' AND is_deleted = 0"),
      DatabaseService.rawQuery("SELECT COUNT(*) AS cnt FROM video_folder WHERE folder_type = 'music' AND is_deleted = 0"),
      DatabaseService.rawQuery("SELECT COUNT(*) AS cnt FROM video_folder WHERE folder_type = 'article' AND is_deleted = 0"),
    ]);

    final videoTotal = (counts[0].first['cnt'] as int?) ?? 0;
    final audioTotal = (counts[1].first['cnt'] as int?) ?? 0;
    final articleTotal = (counts[2].first['cnt'] as int?) ?? 0;

    // 按类型聚合
    final Map<String, _TypeAggregation> agg = {
      'video': _TypeAggregation(),
      'music': _TypeAggregation(),
      'article': _TypeAggregation(),
    };

    for (final r in allRecords) {
      final t = agg[r.resourceType];
      if (t == null) continue;
      t.resources.add(r.resourceCode);
      t.totalDuration += r.duration;
      if (r.date.isAfter(t.lastStudy)) {
        t.lastStudy = r.date;
      }
    }

    return [
      TypeStats(
        type: 'video',
        icon: 'video_library',
        label: '视频',
        learned: agg['video']!.resources.length,
        total: videoTotal,
        totalDurationSeconds: agg['video']!.totalDuration,
        lastStudyTime: agg['video']!.lastStudy,
      ),
      TypeStats(
        type: 'audio',
        icon: 'music_note',
        label: '音频',
        learned: agg['music']!.resources.length,
        total: audioTotal,
        totalDurationSeconds: agg['music']!.totalDuration,
        lastStudyTime: agg['music']!.lastStudy,
      ),
      TypeStats(
        type: 'article',
        icon: 'article',
        label: '文章',
        learned: agg['article']!.resources.length,
        total: articleTotal,
        totalDurationSeconds: agg['article']!.totalDuration,
        lastStudyTime: agg['article']!.lastStudy,
      ),
    ];
  }

  /// 获取近 7 天每日学习时长
  static Future<List<DailyTrend>> getWeeklyTrend() async {
    final today = DateTime.now();
    final List<DailyTrend> result = [];

    final allRecords = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0',
    );

    // 按日期聚合
    final Map<String, int> dateMap = {};
    for (final r in allRecords) {
      final dateStr = r.date.toIso8601String().substring(0, 10);
      dateMap[dateStr] = (dateMap[dateStr] ?? 0) + r.duration;
    }

    for (int i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final dateStr = d.toIso8601String().substring(0, 10);
      final seconds = dateMap[dateStr] ?? 0;
      result.add(DailyTrend(
        date: dateStr,
        minutes: seconds ~/ 60,
      ));
    }

    return result;
  }
  /// 获取近 N 条学习记录对应的文件夹（去重，按最后播放/学习时间排序）
  /// 包含视频、音频（通过 last_play_date）和文章（通过 last_study_date）
  static Future<List<VideoFolder>> getRecentLearningFolders({int limit = 8}) async {
    // 使用 UNION 查询同时涵盖 video/music 和 article 文件夹
    const sql = '''
      SELECT vf.* FROM video_folder vf
      INNER JOIN (
        SELECT code, last_play_date AS last_activity FROM video_folder
        WHERE is_deleted = 0 AND parent_code IS NOT NULL AND parent_code != '' AND last_play_date IS NOT NULL
        UNION
        SELECT vf2.code, MAX(a.last_study_date) AS last_activity
        FROM video_folder vf2
        INNER JOIN article a ON a.folder_code = vf2.code AND a.is_deleted = 0
        WHERE vf2.is_deleted = 0 AND vf2.parent_code IS NOT NULL AND vf2.parent_code != '' AND a.last_study_date IS NOT NULL
        GROUP BY vf2.code
      ) activity ON vf.code = activity.code
      ORDER BY activity.last_activity DESC
      LIMIT ?
    ''';
    try {
      final rows = await DatabaseService.rawQuery(sql, [limit]);
      return rows.map((row) {
        final folder = VideoFolder();
        return folder.fromMap(row) as VideoFolder;
      }).toList();
    } catch (e) {
      debugPrint('[StatsService] getRecentLearningFolders failed: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════
  //  AI 学习建议
  // ════════════════════════════════════════════════

  /// 获取 AI 学习建议（本地规则兜底，后续可接入 AI）
  static Future<List<AiSuggestion>> getAiLearningSuggestions() async {
    try {
      final overview = await getDetailOverview();
      final streakDays = await calculateStreakDays();

      if (overview.totalDurationSeconds < 60 && overview.learnedResources < 1) {
        return _localRuleSuggestions(streakDays);
      }

      // TODO: 接入 ai-proxy Edge Function 获取个性化建议
      // 暂时使用本地规则
      return _localRuleSuggestions(streakDays);
    } catch (e) {
      debugPrint('[StatsService] AI suggestions failed: $e');
      return _localRuleSuggestions(0);
    }
  }

  static List<AiSuggestion> _localRuleSuggestions(int streakDays) {
    final suggestions = <AiSuggestion>[];

    if (streakDays >= 7) {
      suggestions.add(AiSuggestion(
        title: '保持节奏',
        description:
            '已连续学习 $streakDays 天！继续保持每天学习的习惯，效果会越来越明显。',
        icon: Icons.local_fire_department,
      ));
    } else if (streakDays >= 3) {
      suggestions.add(AiSuggestion(
        title: '再坚持一下',
        description:
            '连续 ${streakDays} 天了，再坚持 ${(7 - streakDays)} 天即可解锁「连续7天」成就！',
        actionText: '今日目标',
        icon: Icons.flag,
      ));
    } else {
      suggestions.add(AiSuggestion(
        title: '开始每日学习',
        description: '每天只需 15 分钟，坚持一周就能看到明显进步。',
        actionText: '开始学习',
        icon: Icons.play_circle_outline,
      ));
    }

    suggestions.add(AiSuggestion(
      title: '多样化学习',
      description:
          '尝试结合视频、音频和文章多种资源类型，全面提升听说读写能力。',
      icon: Icons.dashboard,
    ));

    suggestions.add(AiSuggestion(
      title: '定期复习',
      description: '使用生词本复习功能巩固已学单词，间隔重复记忆效果最佳。',
      icon: Icons.refresh,
    ));

    return suggestions;
  }

  static String _fmtDuration(int seconds) {
    if (seconds >= 3600) {
      return '${seconds ~/ 3600}h${(seconds % 3600) ~/ 60}m';
    }
    return '${(seconds ~/ 60)}m';
  }
}

// ─── 详情页数据类 ───

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

  const DailyTrend({
    required this.date,
    this.minutes = 0,
  });
}

/// 内部聚合辅助
class _TypeAggregation {
  final Set<String> resources = {};
  int totalDuration = 0;
  DateTime lastStudy = DateTime(2000);
}

/// AI 学习建议数据模型
class AiSuggestion {
  /// 建议标题
  final String title;

  /// 建议描述
  final String description;

  /// 建议图标
  final IconData icon;

  /// 操作按钮文字（可选）
  final String? actionText;

  const AiSuggestion({
    required this.title,
    required this.description,
    required this.icon,
    this.actionText,
  });
}
