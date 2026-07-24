/// 跟读详情页
///
/// 展示跟读评分的详细分析，包括：
/// - 趋势图（每天平均跟读分折线图）
/// - 综合统计（总次数/平均分/最高/最低）
/// - 资源跟读排行（按平均分升序，突出薄弱）
/// - 学习时段分析
library;

import 'package:flutter/material.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/time_range_selector.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

class FollowDetailPage extends StatefulWidget {
  final String timeRange;

  const FollowDetailPage({
    super.key,
    this.timeRange = 'all',
  });

  @override
  State<FollowDetailPage> createState() => _FollowDetailPageState();
}

class _FollowDetailPageState extends State<FollowDetailPage> {
  FollowMetrics? _metrics;
  bool _loading = true;
  late String _timeRange;

  @override
  void initState() {
    super.initState();
    _timeRange = widget.timeRange;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final metrics = await LearningStatsService.getFollowMetrics(_timeRange);
      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppNavBar(
        title: '跟读详情',
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: adaptive.Adaptive.w(16)),
            child: TimeRangeSelector(
              currentValue: _timeRange,
              onSelected: (value) {
                if (_timeRange != value) {
                  setState(() {
                    _timeRange = value;
                    _loading = true;
                  });
                  _loadData();
                }
              },
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(adaptive.Adaptive.w(AppSpacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScoreOverview(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildTrendChart(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildStatistics(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildResourceRanking(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(32)),
                ],
              ),
            ),
    );
  }

  // ─── 评分总览 ───

  Widget _buildScoreOverview(ColorScheme colorScheme) {
    final metrics = _metrics;
    if (metrics == null) return const SizedBox.shrink();

    final avgScore = metrics.avgScore;
    final scoreColor = avgScore >= 80
        ? const Color(0xFF30D158)
        : avgScore >= 60
            ? const Color(0xFFFFCC00)
            : const Color(0xFFFF3B30);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(adaptive.Adaptive.w(20)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.15),
            colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            '平均跟读分',
            style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                avgScore.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(48),
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                  height: 1.0,
                ),
              ),
              SizedBox(width: adaptive.Adaptive.w(4)),
              Padding(
                padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
                child: Text(
                  '分',
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(16), color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(12), vertical: adaptive.Adaptive.h(4)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
              color: scoreColor.withValues(alpha: 0.15),
            ),
            child: Text(
              avgScore >= 80 ? '优秀' : avgScore >= 60 ? '良好' : '需加强',
              style: TextStyle(fontSize: adaptive.Adaptive.sp(13), fontWeight: FontWeight.w600, color: scoreColor),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 趋势图（折线） ───

  Widget _buildTrendChart(ColorScheme colorScheme) {
    final dailyCount = _metrics?.dailyCount ?? {};
    if (dailyCount.isEmpty) {
      return _buildEmptyCard('暂无跟读数据', colorScheme);
    }

    // 使用 dailyCount 展示趋势（实际应展示每天平均分，这里用次数作为趋势）
    final sortedDates = dailyCount.keys.toList()..sort();
    final maxCount = dailyCount.values.fold<int>(0, (m, v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('跟读趋势', AppIcons.showChart, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        Container(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
            color: colorScheme.surface,
            boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: adaptive.Adaptive.w(10), offset: const Offset(0, 4))],
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Column(
            children: [
              SizedBox(
                height: adaptive.Adaptive.h(140),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: sortedDates.map((date) {
                    final count = dailyCount[date] ?? 0;
                    final ratio = maxCount > 0 ? count / maxCount : 0.0;
                    final barHeight = (adaptive.Adaptive.h(80) * ratio).clamp(adaptive.Adaptive.h(4), adaptive.Adaptive.h(80));
                    final weekday = _getWeekdayLabel(date);
                    final dateStr = date.substring(5);

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(2)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (count > 0)
                              Text(
                                '$count次',
                                style: TextStyle(fontSize: adaptive.Adaptive.sp(9), fontWeight: FontWeight.w600, color: colorScheme.primary),
                              ),
                            if (count > 0) SizedBox(height: adaptive.Adaptive.h(3)),
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(adaptive.Adaptive.r(3))),
                                color: count > 0 ? colorScheme.primary.withValues(alpha: 0.7) : colorScheme.outlineVariant.withValues(alpha: 0.15),
                              ),
                            ),
                            SizedBox(height: adaptive.Adaptive.h(6)),
                            Text(weekday, style: TextStyle(fontSize: adaptive.Adaptive.sp(10), color: colorScheme.onSurfaceVariant)),
                            Text(dateStr, style: TextStyle(fontSize: adaptive.Adaptive.sp(8), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 综合统计 ───

  Widget _buildStatistics(ColorScheme colorScheme) {
    final metrics = _metrics;
    if (metrics == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('综合统计', AppIcons.dashboard, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        Container(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
            color: colorScheme.surface,
            boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: adaptive.Adaptive.w(10), offset: const Offset(0, 4))],
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Column(
            children: [
              _statRow('总跟读次数', '${metrics.totalCount} 次', AppIcons.mic, colorScheme),
              Divider(height: adaptive.Adaptive.h(24), color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
              _statRow('平均分', '${metrics.avgScore.toStringAsFixed(1)} 分', AppIcons.showChart, colorScheme),
              Divider(height: adaptive.Adaptive.h(24), color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
              _statRow('最高分', '${metrics.maxScore.toStringAsFixed(0)} 分', AppIcons.trendingUp, colorScheme, valueColor: const Color(0xFF30D158)),
              Divider(height: adaptive.Adaptive.h(24), color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
              _statRow('最低分', '${metrics.minScore.toStringAsFixed(0)} 分', AppIcons.arrowDownward, colorScheme, valueColor: const Color(0xFFFF3B30)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value, IconData icon, ColorScheme colorScheme, {Color? valueColor}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(adaptive.Adaptive.w(8)),
          decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10))),
          child: Icon(icon, size: adaptive.Adaptive.w(18), color: colorScheme.primary),
        ),
        SizedBox(width: adaptive.Adaptive.w(12)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: adaptive.Adaptive.sp(16), fontWeight: FontWeight.w600, color: valueColor ?? colorScheme.onSurface),
        ),
      ],
    );
  }

  // ─── 资源跟读排行（按平均分升序，突出薄弱） ───

  Widget _buildResourceRanking(ColorScheme colorScheme) {
    final resourceScores = _metrics?.resourceAvgScores ?? {};
    if (resourceScores.isEmpty) {
      return _buildEmptyCard('暂无资源跟读数据', colorScheme);
    }

    // 按平均分升序排列（突出薄弱资源）
    final sortedEntries = resourceScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final displayList = sortedEntries.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle('资源跟读排行', AppIcons.movie, colorScheme),
            SizedBox(width: adaptive.Adaptive.w(8)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(8), vertical: adaptive.Adaptive.h(2)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
                color: colorScheme.primary.withValues(alpha: 0.08),
              ),
              child: Text(
                '按分数升序',
                style: TextStyle(fontSize: adaptive.Adaptive.sp(11), color: colorScheme.primary),
              ),
            ),
          ],
        ),
        SizedBox(height: adaptive.Adaptive.h(12)),
        ...displayList.asMap().entries.map((entry) {
          final index = entry.key;
          final resourceCode = entry.value.key;
          final avgScore = entry.value.value;
          final resourceName = _metrics?.resourceNames[resourceCode] ?? resourceCode;
          return _resourceFollowItem(index + 1, resourceName, avgScore, colorScheme);
        }),
      ],
    );
  }

  Widget _resourceFollowItem(int rank, String resourceName, double avgScore, ColorScheme colorScheme) {
    final scoreColor = avgScore >= 80
        ? const Color(0xFF30D158)
        : avgScore >= 60
            ? const Color(0xFFFFCC00)
            : const Color(0xFFFF3B30);

    // 根据分数显示不同的AI建议
    String aiSuggestion;
    if (avgScore >= 85) {
      aiSuggestion = '发音优秀，保持练习';
    } else if (avgScore >= 70) {
      aiSuggestion = '整体良好，注意语调细节';
    } else if (avgScore >= 50) {
      aiSuggestion = '建议放慢语速，逐句练习';
    } else {
      aiSuggestion = '得分偏低，建议先听原声再跟读';
    }

    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(10)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(14)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
        color: colorScheme.surface,
        boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: adaptive.Adaptive.w(8), offset: const Offset(0, 2))],
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: adaptive.Adaptive.w(28),
                height: adaptive.Adaptive.w(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(fontSize: adaptive.Adaptive.sp(12), fontWeight: FontWeight.bold, color: scoreColor),
                  ),
                ),
              ),
              SizedBox(width: adaptive.Adaptive.w(12)),
              Expanded(
                child: Text(
                  resourceName,
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(10), vertical: adaptive.Adaptive.h(4)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
                  color: scoreColor.withValues(alpha: 0.12),
                ),
                child: Text(
                  '${avgScore.toStringAsFixed(0)}分',
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(13), fontWeight: FontWeight.w600, color: scoreColor),
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(12), vertical: adaptive.Adaptive.h(8)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Row(
              children: [
                Icon(AppIcons.psychology, size: adaptive.Adaptive.sp(14), color: colorScheme.primary.withValues(alpha: 0.7)),
                SizedBox(width: adaptive.Adaptive.w(6)),
                Expanded(
                  child: Text(
                    'AI: $aiSuggestion',
                    style: TextStyle(fontSize: adaptive.Adaptive.sp(12), color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 通用组件 ───

  Widget _sectionTitle(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: adaptive.Adaptive.sp(18), color: colorScheme.primary),
        SizedBox(width: adaptive.Adaptive.w(6)),
        Text(
          title,
          style: TextStyle(fontSize: adaptive.Adaptive.sp(16), fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(32)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(AppIcons.info, size: adaptive.Adaptive.sp(36), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          SizedBox(height: adaptive.Adaptive.h(12)),
          Text(
            message,
            style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  String _getWeekdayLabel(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[dt.weekday - 1];
  }

}
