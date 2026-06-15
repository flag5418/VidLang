import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vidlang/models/test_models.dart';
import 'package:vidlang/services/database_service.dart';

// ─── 成长统计模型 ───

class DailyStats {
  final DateTime date;
  final int testCount;
  final double avgScore;
  final int totalMinutes;

  const DailyStats({
    required this.date,
    this.testCount = 0,
    this.avgScore = 0,
    this.totalMinutes = 0,
  });
}

class CategoryStats {
  final double listening;
  final double speaking;
  final double reading;
  final double writing;

  const CategoryStats({
    this.listening = 0,
    this.speaking = 0,
    this.reading = 0,
    this.writing = 0,
  });
}

class GrowthSummary {
  final int totalTests;
  final double overallAvgScore;
  final int totalStudyMinutes;
  final int currentStreak;
  final int bestStreak;
  final List<DailyStats> dailyStats;
  final CategoryStats categoryStats;
  final List<Map<String, dynamic>> scoreTrend;

  const GrowthSummary({
    this.totalTests = 0,
    this.overallAvgScore = 0,
    this.totalStudyMinutes = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.dailyStats = const [],
    this.categoryStats = const CategoryStats(),
    this.scoreTrend = const [],
  });
}

// ─── 状态 ───

class GrowthState {
  final GrowthSummary? summary;
  final List<TestSession> recentTests;
  final TestSession? selectedTest;
  final TestEvaluation? selectedEvaluation;
  final List<TestItem> selectedItems;
  final bool isLoading;
  final String? error;

  const GrowthState({
    this.summary,
    this.recentTests = const [],
    this.selectedTest,
    this.selectedEvaluation,
    this.selectedItems = const [],
    this.isLoading = false,
    this.error,
  });

  GrowthState copyWith({
    GrowthSummary? summary,
    List<TestSession>? recentTests,
    TestSession? selectedTest,
    TestEvaluation? selectedEvaluation,
    List<TestItem>? selectedItems,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return GrowthState(
      summary: summary ?? this.summary,
      recentTests: recentTests ?? this.recentTests,
      selectedTest: selectedTest ?? this.selectedTest,
      selectedEvaluation: selectedEvaluation ?? this.selectedEvaluation,
      selectedItems: selectedItems ?? this.selectedItems,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Provider ───

class GrowthNotifier extends StateNotifier<GrowthState> {
  GrowthNotifier() : super(const GrowthState());

  /// 加载成长概览数据
  Future<void> loadGrowthData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 获取所有已完成的评测
      final tests = await DatabaseService.findByCondition<TestSession>(
        () => TestSession(),
        where: "status = 'completed'",
        orderBy: 'started_at DESC',
      );

      // 计算汇总
      int totalMinutes = 0;
      double totalScore = 0;
      for (final t in tests) {
        totalMinutes += t.durationSeconds ~/ 60;
        if (t.totalScore != null) {
          totalScore += t.totalScore!;
        }
      }

      final avgScore = tests.isNotEmpty ? totalScore / tests.length : 0.0;

      // 计算每日统计和连胜
      final dailyMap = <DateTime, List<TestSession>>{};
      for (final t in tests) {
        final day = DateTime(t.startedAt.year, t.startedAt.month, t.startedAt.day);
        dailyMap.putIfAbsent(day, () => []).add(t);
      }

      final dailyStatsList = dailyMap.entries.map((e) {
        final dayTests = e.value;
        final dayAvg = dayTests
            .where((t) => t.totalScore != null)
            .fold<double>(0, (a, b) => a + b.totalScore!) /
            (dayTests.where((t) => t.totalScore != null).length.clamp(1, 999));
        final dayMinutes =
            dayTests.fold<int>(0, (a, b) => a + b.durationSeconds ~/ 60);
        return DailyStats(
          date: e.key,
          testCount: dayTests.length,
          avgScore: dayAvg,
          totalMinutes: dayMinutes,
        );
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      // 计算连胜
      final (currentStreak, bestStreak) = _calculateStreaks(dailyStatsList);

      // 类别分数
      CategoryStats categoryStats = const CategoryStats();
      if (tests.isNotEmpty) {
        final evaluations = await DatabaseService.findByCondition<TestEvaluation>(
          () => TestEvaluation(),
          where: 'test_session_id IN (${tests.map((t) => t.id).join(',')})',
        );
        double listening = 0, speaking = 0, reading = 0, writing = 0;
        int count = 0;
        for (final e in evaluations) {
          final scores = e.categoryScores;
          if (scores.isNotEmpty) {
            listening += scores['听'] ?? 0;
            speaking += scores['说'] ?? 0;
            reading += scores['读'] ?? 0;
            writing += scores['写'] ?? 0;
            count++;
          }
        }
        if (count > 0) {
          categoryStats = CategoryStats(
            listening: listening / count,
            speaking: speaking / count,
            reading: reading / count,
            writing: writing / count,
          );
        }
      }

      // 分数趋势（最近30天）
      final trend = dailyStatsList.reversed.take(30).map((d) => {
            'date': '${d.date.month}/${d.date.day}',
            'score': d.avgScore,
          }).toList();

      final summary = GrowthSummary(
        totalTests: tests.length,
        overallAvgScore: avgScore,
        totalStudyMinutes: totalMinutes,
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        dailyStats: dailyStatsList,
        categoryStats: categoryStats,
        scoreTrend: trend,
      );

      state = GrowthState(
        summary: summary,
        recentTests: tests.take(50).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载评测详情
  Future<void> loadTestDetail(int sessionId) async {
    try {
      final test = await DatabaseService.findById<TestSession>(sessionId, () => TestSession());
      final evaluations = await DatabaseService.findByCondition<TestEvaluation>(
        () => TestEvaluation(),
        where: 'test_session_id = ?',
        whereArgs: [sessionId],
      );
      final items = await DatabaseService.findByCondition<TestItem>(
        () => TestItem(),
        where: 'test_session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'item_order ASC',
      );

      state = state.copyWith(
        selectedTest: test,
        selectedEvaluation: evaluations.isNotEmpty ? evaluations.first : null,
        selectedItems: items,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 清除详情选择
  void clearSelection() {
    state = state.copyWith(
      selectedTest: null,
      selectedEvaluation: null,
      selectedItems: [],
    );
  }

  // ─── 连胜计算 ───

  (int current, int best) _calculateStreaks(List<DailyStats> dailyStats) {
    if (dailyStats.isEmpty) return (0, 0);

    final sorted = List<DailyStats>.from(dailyStats)
      ..sort((a, b) => a.date.compareTo(b.date));

    int bestStreak = 0;
    int currentStreak = 0;
    DateTime? prevDate;

    for (final day in sorted) {
      if (prevDate == null) {
        currentStreak = 1;
      } else {
        final diff = day.date.difference(prevDate).inDays;
        if (diff <= 1) {
          currentStreak++;
        } else {
          currentStreak = 1;
        }
      }
      if (currentStreak > bestStreak) {
        bestStreak = currentStreak;
      }
      prevDate = day.date;
    }

    // 检查当前连胜：如果最近一天是今天或昨天
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final lastDay = sorted.last.date;
    final lastDiff = todayDay.difference(lastDay).inDays;

    if (lastDiff > 1) {
      currentStreak = 0;
    }

    return (currentStreak, bestStreak);
  }
}

// ─── Provider ───

final growthProvider =
    StateNotifierProvider<GrowthNotifier, GrowthState>((ref) => GrowthNotifier());
