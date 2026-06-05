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

  /// 已收藏单词数
  final int wordCount;

  /// 已学资源数（不重复）
  final int resourceCount;

  const HomeStats({
    this.streakDays = 0,
    this.todayDuration = 0,
    this.wordCount = 0,
    this.resourceCount = 0,
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
    final userCode = await DatabaseService.getCurrentUserCode();
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
    final userCode = await DatabaseService.getCurrentUserCode();
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

  /// 获取已收藏单词数
  static Future<int> getWordCount() async {
    return await DatabaseService.count(
      () => WordBook(),
      where: 'is_deleted = 0',
    );
  }

  /// 获取已学资源数（不重复）
  static Future<int> getResourceCount() async {
    final records = await DatabaseService.findByCondition(
      () => StudyRecord(),
      where: 'is_deleted = 0',
    );

    final Set<String> unique = {};
    for (final r in records) {
      final key = '${r.resourceType}_${r.resourceCode}';
      unique.add(key);
    }
    return unique.length;
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
}
