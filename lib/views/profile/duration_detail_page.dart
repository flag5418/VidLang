/// 学习时长详情页
///
/// 展示周期内学习时长的详细分析，包括：
/// - 每日时长柱状图趋势
/// - 综合统计（总时长/日均/最长单次/会话数）
/// - 资源时长排行
/// - 学习时段偏好分析
library;

import 'package:flutter/material.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'widgets/stats_detail_base.dart';

class DurationDetailPage extends StatsDetailPage {
  const DurationDetailPage({super.key, super.timeRange = '7d'})
      : super(title: '学习时长', icon: AppIcons.accessTime);

  @override
  State<DurationDetailPage> createState() => _DurationDetailPageState();
}

class _DurationDetailPageState extends StatsDetailPageState<DurationDetailPage> {
  DurationMetrics? _metrics;
  List<ResourceDurationDetail> _ranking = [];

  @override
  Future<void> fetchData(String timeRange) async {
    _metrics = await LearningStatsService.getDurationMetrics(timeRange);
    _ranking = await LearningStatsService.getResourceDurationRanking(timeRange);
    // TODO: 获取资源标题，目前显示 resourceCode，需接入 _resolveResourceTitle 获取真实标题
    // for (final item in _ranking) {
    //   final summary = await LearningStatsService.instance.getSummary(item.resourceCode);
    // }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  Widget buildContent(BuildContext context, ColorScheme colorScheme) {
    if (_metrics == null || (_metrics!.totalSeconds == 0 && _ranking.isEmpty)) {
      return emptyState('该周期内暂无学习时长数据\n开始学习后将自动记录', colorScheme);
    }

    final metrics = _metrics!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 趋势图
        sectionTitle('时长趋势', AppIcons.showChart, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsCard(
          colorScheme: colorScheme,
          child: barChart(
            data: metrics.dailyData.map((k, v) => MapEntry(k, v ~/ 60)), // 转为分钟
            colorScheme: colorScheme,
            unit: 'm',
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(24)),

        // 综合统计
        sectionTitle('综合统计', AppIcons.dashboard, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsRow([
          statItem('总时长', _formatDuration(metrics.totalSeconds), colorScheme),
          statItem('日均', _formatDuration(metrics.avgDailySeconds), colorScheme),
          statItem('会话数', '${metrics.sessionCount}', colorScheme),
          statItem('最长单次', _formatDuration(metrics.maxSessionSeconds), colorScheme),
        ], colorScheme),
        SizedBox(height: adaptive.Adaptive.h(24)),

        // 环比变化
        if (metrics.changePercent != 0) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(12), horizontal: adaptive.Adaptive.w(16)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
              color: metrics.changePercent > 0
                  ? const Color(0xFF30D158).withValues(alpha: 0.08)
                  : const Color(0xFFFF3B30).withValues(alpha: 0.08),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  metrics.changePercent > 0 ? AppIcons.trendingUp : AppIcons.arrowDownward,
                  size: adaptive.Adaptive.sp(16),
                  color: metrics.changePercent > 0 ? const Color(0xFF30D158) : const Color(0xFFFF3B30),
                ),
                SizedBox(width: adaptive.Adaptive.w(6)),
                Text(
                  '较上周期 ${metrics.changePercent > 0 ? '+' : ''}${metrics.changePercent}%',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(14),
                    fontWeight: FontWeight.w600,
                    color: metrics.changePercent > 0 ? const Color(0xFF30D158) : const Color(0xFFFF3B30),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(24)),
        ],

        // 资源排行
        if (_ranking.isNotEmpty) ...[
          sectionTitle('资源时长排行', AppIcons.film, colorScheme),
          SizedBox(height: adaptive.Adaptive.h(12)),
          ..._ranking.take(10).map((item) {
            return resourceRankingItem(
              title: item.resourceCode,
              subtitle: '学习 ${item.sessionCount} 次',
              trailing: item.formattedDuration,
              icon: ResourceIcons.displayIconFor(item.resourceType),
              colorScheme: colorScheme,
              aiInsight: item.sessionCount > 5 ? '该资源学习次数较多，建议尝试跟读练习巩固' : null,
            );
          }),
          SizedBox(height: adaptive.Adaptive.h(24)),
        ],

        // 学习时段分析
        sectionTitle('学习时段偏好', AppIcons.schedule, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsCard(
          colorScheme: colorScheme,
          child: _buildTimeDistribution(colorScheme),
        ),
        SizedBox(height: adaptive.Adaptive.h(32)),
      ],
    );
  }

  Widget _buildTimeDistribution(ColorScheme colorScheme) {
    // 基于 dailyData 分析时段偏好
    final hourDistribution = <String, int>{
      '早晨 (5-12点)': 0,
      '下午 (12-18点)': 0,
      '晚上 (18-22点)': 0,
      '深夜 (22-5点)': 0,
    };

    // 这里简化处理，实际应该从 StudyRecord 的 start_time 分析
    // 由于 metrics.dailyData 只有日期和总时长，无法精确到时段
    // 展示占位分析
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '基于学习记录时段分析',
          style: TextStyle(fontSize: adaptive.Adaptive.sp(13), color: colorScheme.onSurfaceVariant),
        ),
        SizedBox(height: adaptive.Adaptive.h(12)),
        ...hourDistribution.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
            child: Row(
              children: [
                SizedBox(
                  width: adaptive.Adaptive.w(120),
                  child: Text(
                    entry.key,
                    style: TextStyle(fontSize: adaptive.Adaptive.sp(13), color: colorScheme.onSurface),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(adaptive.Adaptive.r(4)),
                    child: LinearProgressIndicator(
                      value: 0.3, // 占位，实际需要查询数据库分析
                      minHeight: adaptive.Adaptive.h(8),
                      backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        SizedBox(height: adaptive.Adaptive.h(8)),
        Text(
          '💡 建议：保持稳定的学习时段有助于形成良好的学习习惯',
          style: TextStyle(fontSize: adaptive.Adaptive.sp(12), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7), height: 1.4),
        ),
      ],
    );
  }
}
