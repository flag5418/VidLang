import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vidlang/views/growth/providers/growth_provider.dart';
import 'package:vidlang/views/growth/growth_detail_page.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/theme/theme.dart';

/// 成长记录主页 — 年→月→日→评测 四层结构 + 日历热力图 + 能力雷达图
class GrowthRecordPage extends ConsumerStatefulWidget {
  const GrowthRecordPage({super.key});

  @override
  ConsumerState<GrowthRecordPage> createState() => _GrowthRecordPageState();
}

class _GrowthRecordPageState extends ConsumerState<GrowthRecordPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(growthProvider.notifier).loadGrowthData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(growthProvider);
    final summary = state.summary;

    return Scaffold(
appBar: AppNavBar(
  title: '成长记录',
  actions: [
    IconButton(
      icon: const Icon(AppIcons.refresh),
      onPressed: () => ref.read(growthProvider.notifier).loadGrowthData(),
    ),
  ],
),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : summary == null
              ? const Center(child: Text('暂无学习记录'))
              : RefreshIndicator(
                  onRefresh: () => ref.read(growthProvider.notifier).loadGrowthData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildOverviewCard(context, summary),
                        SizedBox(height: 16),
                        _buildStreakCard(context, summary),
                        SizedBox(height: 16),
                        _buildHeatmap(context, summary),
                        SizedBox(height: 16),
                        _buildScoreTrend(context, summary),
                        SizedBox(height: 16),
                        _buildHistoryList(context, state),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, dynamic summary) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text('学习概览', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _overviewStat('总评测', '${summary.totalTests}次', AppIcons.assignment),
                _overviewStat(
                    '平均分', '${summary.overallAvgScore.toStringAsFixed(1)}', AppIcons.trendingUp),
                _overviewStat(
                    '总时长', '${summary.totalStudyMinutes}分钟', AppIcons.timer),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildStreakCard(BuildContext context, dynamic summary) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Icon(AppIcons.localFireDepartment, color: AppColors.warning, size: 36),
                SizedBox(height: 4),
                Text('当前连胜',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('${summary.currentStreak} 天',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            Container(width: 1, height: 48, color: AppColors.borderLight),
            Column(
              children: [
                Icon(AppIcons.emojiEvents, color: AppColors.warning, size: 36),
                SizedBox(height: 4),
                Text('最佳纪录',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('${summary.bestStreak} 天',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context, dynamic summary) {
    final dailyStats = summary.dailyStats as List;
    if (dailyStats.isEmpty) return const SizedBox.shrink();

    // 最近 7 天的热力图
    final recent = dailyStats.take(7).toList();
    final maxCount = recent
        .map((d) => d.testCount as int)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('学习活跃度', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: recent.map((day) {
                  final count = day.testCount as int;
                  final intensity = maxCount > 0 ? count / maxCount : 0.0;
                  final date = day.date as DateTime;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.month}/${date.day}',
                        style: TextStyle(fontSize: 11),
                      ),
                      SizedBox(height: 4),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.2 + intensity * 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: intensity > 0.5 ? AppColors.surface : AppColors.success,
                          ),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${day.avgScore.toStringAsFixed(0)}分',
                        style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreTrend(BuildContext context, dynamic summary) {
    final trend = summary.scoreTrend as List;
    if (trend.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('分数趋势', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: CustomPaint(
                size: const Size(double.infinity, 150),
                painter: _TrendLinePainter(
                  data: trend
                      .map((d) => (d['score'] as num).toDouble())
                      .toList(),
                  labels:
                      trend.map((d) => d['date'] as String).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, dynamic state) {
    final tests = state.recentTests as List;
    if (tests.isEmpty) return const SizedBox.shrink();

    // 按年-月-日分组
    final grouped = <String, List<dynamic>>{};
    for (final t in tests) {
      final date = t.startedAt as DateTime;
      final key = '${date.year}年${date.month}月${date.day}日';
      grouped.putIfAbsent(key, () => []).add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('历史记录', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 8),
        ...grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              ...entry.value.map((t) => _buildTestItem(context, t)),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTestItem(BuildContext context, dynamic t) {
    final score = t.totalScore?.round() ?? 0;
    final date = t.startedAt as DateTime;
    final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: score >= 80
              ? AppColors.success.withValues(alpha: 0.15)
              : score >= 60
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : AppColors.error.withValues(alpha: 0.15),
          child: Text(
            '$score',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: score >= 80
                  ? AppColors.success
                  : score >= 60
                      ? AppColors.warning
                      : AppColors.error,
            ),
          ),
        ),
        title: Text(
          _testTypeLabel(t.testType as String),
        ),
        subtitle: Text(
          '${t.completedItems}/${t.totalItems}题 · $time · ${t.difficulty}',
        ),
        trailing: const Icon(AppIcons.chevronRight),
        onTap: () {
          final growthNotifier = ref.read(growthProvider.notifier);
          growthNotifier.loadTestDetail(t.id as int);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GrowthDetailPage(testId: t.id as int),
            ),
          );
        },
      ),
    );
  }

  String _testTypeLabel(String type) {
    switch (type) {
      case 'mixed':
        return '综合评测';
      case 'pronunciation':
        return '发音专项';
      case 'vocabulary':
        return '词汇专项';
      case 'grammar':
        return '语法专项';
      default:
        return type;
    }
  }
}

// ─── 趋势线绘制 ───

class _TrendLinePainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;

  _TrendLinePainter({required this.data, required this.labels});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce((a, b) => a > b ? a : b).clamp(1, 100);
    final minVal = data.reduce((a, b) => a < b ? a : b).clamp(0, 100);
    final range = (maxVal - minVal).clamp(1, 100);

    final padding = 30.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    // 网格线
    final gridPaint = Paint()
      ..color = AppColors.borderLight
      ..style = PaintingStyle.stroke;
    for (int i = 0; i <= 3; i++) {
      final y = padding + h * i / 3;
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }

    // 数据线
    final linePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = padding + (w * i / (data.length - 1).clamp(1, 999));
      final y = padding + h * (1 - (data[i] - minVal) / range);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // 数据点
    for (int i = 0; i < data.length; i++) {
      final x = padding + (w * i / (data.length - 1).clamp(1, 999));
      final y = padding + h * (1 - (data[i] - minVal) / range);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = AppColors.primary);
    }

    // X 轴标签（仅显示部分）
    for (int i = 0; i < labels.length; i += (labels.length / 5).ceil().clamp(1, 99)) {
      final x = padding + (w * i / (labels.length - 1).clamp(1, 999));
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - padding + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
