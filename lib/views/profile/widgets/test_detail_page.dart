/// 评测详情页
///
/// 展示测试评分的详细分析，包括：
/// - 趋势图（每次测试得分折线图）
/// - 综合统计（总次数/平均分/及格率/最高/最低）
/// - 资源评测排行（按平均分升序，突出薄弱）
/// - 题型正确率分析
library;

import 'package:flutter/material.dart';
import 'package:vidlang/components/time_range_selector.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

class TestDetailPage extends StatefulWidget {
  final String timeRange;

  const TestDetailPage({
    super.key,
    this.timeRange = 'all',
  });

  @override
  State<TestDetailPage> createState() => _TestDetailPageState();
}

class _TestDetailPageState extends State<TestDetailPage> {
  TestMetrics? _metrics;
  bool _loading = true;

  String _timeRange = 'all';

  @override
  void initState() {
    super.initState();
    _timeRange = widget.timeRange;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final metrics = await LearningStatsService.getTestMetrics(_timeRange);
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
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrowBackIos, color: colorScheme.onSurface, size: adaptive.Adaptive.icon(20)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '评测详情',
          style: TextStyle(fontSize: adaptive.Adaptive.sp(17), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        ),
        actions: [
          TimeRangeSelector(
            currentValue: _timeRange,
            onSelected: (value) {
              if (_timeRange != value) {
                setState(() => _timeRange = value);
                _loadData();
              }
            },
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
                  _buildPassRateIndicator(colorScheme),
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
            '平均评测分',
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

  // ─── 及格率指示器 ───

  Widget _buildPassRateIndicator(ColorScheme colorScheme) {
    final metrics = _metrics;
    if (metrics == null || metrics.totalCount == 0) return const SizedBox.shrink();

    final passRate = metrics.passRate;
    final passPercent = (passRate * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('及格率', AppIcons.checkCircle, colorScheme),
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$passPercent%',
                          style: TextStyle(
                            fontSize: adaptive.Adaptive.sp(28),
                            fontWeight: FontWeight.bold,
                            color: passRate >= 0.7 ? const Color(0xFF30D158) : passRate >= 0.5 ? const Color(0xFFFFCC00) : const Color(0xFFFF3B30),
                          ),
                        ),
                        SizedBox(height: adaptive.Adaptive.h(4)),
                        Text(
                          '共 ${metrics.totalCount} 次测试',
                          style: TextStyle(fontSize: adaptive.Adaptive.sp(13), color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: adaptive.Adaptive.w(60),
                    height: adaptive.Adaptive.w(60),
                    child: CircularProgressIndicator(
                      value: passRate,
                      strokeWidth: adaptive.Adaptive.w(6),
                      backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation(
                        passRate >= 0.7 ? const Color(0xFF30D158) : passRate >= 0.5 ? const Color(0xFFFFCC00) : const Color(0xFFFF3B30),
                      ),
                    ),
                  ),
                ],
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
              _statRow('总测试次数', '${metrics.totalCount} 次', AppIcons.rule, colorScheme),
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

  // ─── 资源评测排行（按平均分升序，突出薄弱） ───

  Widget _buildResourceRanking(ColorScheme colorScheme) {
    final resourceScores = _metrics?.resourceAvgScores ?? {};
    if (resourceScores.isEmpty) {
      return _buildEmptyCard('暂无资源评测数据', colorScheme);
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
            _sectionTitle('资源评测排行', AppIcons.movie, colorScheme),
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
          return _resourceTestItem(index + 1, resourceCode, avgScore, colorScheme);
        }),
      ],
    );
  }

  Widget _resourceTestItem(int rank, String resourceCode, double avgScore, ColorScheme colorScheme) {
    final scoreColor = avgScore >= 80
        ? const Color(0xFF30D158)
        : avgScore >= 60
            ? const Color(0xFFFFCC00)
            : const Color(0xFFFF3B30);

    // 根据分数显示不同的AI建议
    String aiSuggestion;
    if (avgScore >= 85) {
      aiSuggestion = '掌握良好，可尝试更高难度';
    } else if (avgScore >= 70) {
      aiSuggestion = '基础扎实，注意细节题型';
    } else if (avgScore >= 50) {
      aiSuggestion = '建议复习该资源字幕后重新测试';
    } else {
      aiSuggestion = '得分偏低，建议先增加学习时长再测试';
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
                  resourceCode,
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

}
