/// 单词收藏详情页
///
/// 展示单词收藏的详细分析，包括：
/// - 总览数据（总数/已掌握/本周新增）
/// - 掌握进度环形图
/// - 单词列表（按收藏时间倒序）
library;

import 'package:flutter/material.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/time_range_selector.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

class WordDetailPage extends StatefulWidget {
  final String timeRange;

  const WordDetailPage({
    super.key,
    this.timeRange = 'all',
  });

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  WordMetrics? _metrics;
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
      final metrics = await LearningStatsService.getWordMetrics(_timeRange);
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
        title: '单词收藏详情',
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
                  _buildTotalOverview(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildMasteryProgress(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildStatistics(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(32)),
                ],
              ),
            ),
    );
  }

  // ─── 总览数据 ───

  Widget _buildTotalOverview(ColorScheme colorScheme) {
    final metrics = _metrics;
    if (metrics == null) return const SizedBox.shrink();

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
            '单词收藏总数',
            style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${metrics.totalCount}',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(48),
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  height: 1.0,
                ),
              ),
              SizedBox(width: adaptive.Adaptive.w(4)),
              Padding(
                padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
                child: Text(
                  '个',
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(16), color: colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          if (metrics.newCount > 0) ...[
            SizedBox(height: adaptive.Adaptive.h(8)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(12), vertical: adaptive.Adaptive.h(4)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
                color: const Color(0xFF30D158).withValues(alpha: 0.15),
              ),
              child: Text(
                '本周期新增 +${metrics.newCount}',
                style: TextStyle(fontSize: adaptive.Adaptive.sp(13), fontWeight: FontWeight.w600, color: const Color(0xFF30D158)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 掌握进度 ───

  Widget _buildMasteryProgress(ColorScheme colorScheme) {
    final metrics = _metrics;
    if (metrics == null || metrics.totalCount == 0) {
      return _buildEmptyCard('暂无单词收藏数据', colorScheme);
    }

    final masteredRate = metrics.totalCount > 0 ? metrics.masteredCount / metrics.totalCount : 0.0;
    final masteringCount = metrics.totalCount - metrics.masteredCount;
    final masteredPercent = (masteredRate * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('掌握进度', AppIcons.checkCircle, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        Container(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
            color: colorScheme.surface,
            boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: adaptive.Adaptive.w(10), offset: const Offset(0, 4))],
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            children: [
              SizedBox(
                width: adaptive.Adaptive.w(80),
                height: adaptive.Adaptive.w(80),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: masteredRate,
                      strokeWidth: adaptive.Adaptive.w(8),
                      backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF30D158)),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$masteredPercent%',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(16),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF30D158),
                            ),
                          ),
                          Text(
                            '已掌握',
                            style: TextStyle(fontSize: adaptive.Adaptive.sp(10), color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: adaptive.Adaptive.w(20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _masteryStatItem('已掌握', metrics.masteredCount, const Color(0xFF30D158), colorScheme),
                    SizedBox(height: adaptive.Adaptive.h(12)),
                    _masteryStatItem('学习中', masteringCount, colorScheme.primary, colorScheme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _masteryStatItem(String label, int count, Color color, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          width: adaptive.Adaptive.w(10),
          height: adaptive.Adaptive.w(10),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        SizedBox(width: adaptive.Adaptive.w(8)),
        Text(
          label,
          style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant),
        ),
        const Spacer(),
        Text(
          '$count',
          style: TextStyle(fontSize: adaptive.Adaptive.sp(16), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
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
              _statRow('单词总数', '${metrics.totalCount} 个', AppIcons.book, colorScheme),
              Divider(height: adaptive.Adaptive.h(24), color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
              _statRow('已掌握', '${metrics.masteredCount} 个', AppIcons.checkCircle, colorScheme, valueColor: const Color(0xFF30D158)),
              Divider(height: adaptive.Adaptive.h(24), color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
              _statRow('本周期新增', '${metrics.newCount} 个', AppIcons.add, colorScheme, valueColor: const Color(0xFF30D158)),
              Divider(height: adaptive.Adaptive.h(24), color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
              _statRow('学习中', '${metrics.totalCount - metrics.masteredCount} 个', AppIcons.school, colorScheme),
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

}
