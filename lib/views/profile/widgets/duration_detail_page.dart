/// 学习时长详情页
///
/// 展示学习时长的详细分析，包括：
/// - 趋势图（每天学习时长柱状图）
/// - 综合统计（总时长/日均/最长单次/环比）
/// - 资源时长排行
/// - 学习时段偏好分析
library;

import 'package:flutter/material.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/time_range_selector.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

class DurationDetailPage extends StatefulWidget {
  final String timeRange;

  const DurationDetailPage({super.key, this.timeRange = 'all'});

  @override
  State<DurationDetailPage> createState() => _DurationDetailPageState();
}

class _DurationDetailPageState extends State<DurationDetailPage> {
  DurationMetrics? _metrics;
  List<ResourceDurationDetail> _resourceRanking = [];
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
      final results = await Future.wait([
        LearningStatsService.getDurationMetrics(_timeRange),
        LearningStatsService.getResourceDurationRanking(_timeRange),
      ]);
      if (!mounted) return;
      setState(() {
        _metrics = results[0] as DurationMetrics;
        _resourceRanking = results[1] as List<ResourceDurationDetail>;
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
        title: '学习时长详情',
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
                  _buildTrendChart(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildStatistics(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildResourceRanking(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildTimePreference(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(32)),
                ],
              ),
            ),
    );
  }

  // ─── 趋势图 ───

  Widget _buildTrendChart(ColorScheme colorScheme) {
    final dailyData = _metrics?.dailyData ?? {};
    if (dailyData.isEmpty) {
      return _buildEmptyCard('暂无学习时长数据', colorScheme);
    }

    final sortedDates = dailyData.keys.toList()..sort();
    final maxMinutes = dailyData.values.fold<int>(
      0,
      (m, v) => (v ~/ 60) > m ? (v ~/ 60) : m,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('学习趋势', AppIcons.showChart, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        Container(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.02),
                blurRadius: adaptive.Adaptive.w(10),
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: adaptive.Adaptive.h(160),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: sortedDates.map((date) {
                    final minutes = (dailyData[date] ?? 0) ~/ 60;
                    final ratio = maxMinutes > 0 ? minutes / maxMinutes : 0.0;
                    final barHeight = (adaptive.Adaptive.h(100) * ratio).clamp(
                      adaptive.Adaptive.h(4),
                      adaptive.Adaptive.h(100),
                    );
                    final weekday = _getWeekdayLabel(date);
                    final dateStr = date.substring(5);

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: adaptive.Adaptive.w(2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (minutes > 0)
                              Text(
                                '$minutes分',
                                style: TextStyle(
                                  fontSize: adaptive.Adaptive.sp(9),
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            if (minutes > 0)
                              SizedBox(height: adaptive.Adaptive.h(3)),
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(adaptive.Adaptive.r(3)),
                                ),
                                gradient: minutes > 0
                                    ? LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          colorScheme.primary.withValues(
                                            alpha: 0.5,
                                          ),
                                          colorScheme.primary,
                                        ],
                                      )
                                    : null,
                                color: minutes > 0
                                    ? null
                                    : colorScheme.outlineVariant.withValues(
                                        alpha: 0.15,
                                      ),
                              ),
                            ),
                            SizedBox(height: adaptive.Adaptive.h(6)),
                            Text(
                              weekday,
                              style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(10),
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(8),
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
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
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.02),
                blurRadius: adaptive.Adaptive.w(10),
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              _statRow(
                '总学习时长',
                metrics.formattedTotal,
                AppIcons.timer,
                colorScheme,
              ),
              Divider(
                height: adaptive.Adaptive.h(24),
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
              _statRow(
                '日均学习时长',
                metrics.formattedAvgDaily,
                AppIcons.schedule,
                colorScheme,
              ),
              Divider(
                height: adaptive.Adaptive.h(24),
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
              _statRow(
                '学习次数',
                '${metrics.sessionCount} 次',
                AppIcons.playCircleOutline,
                colorScheme,
              ),
              Divider(
                height: adaptive.Adaptive.h(24),
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
              _statRow(
                '最长单次',
                _formatDuration(metrics.maxSessionSeconds),
                AppIcons.trendingUp,
                colorScheme,
              ),
              if (metrics.changePercent != 0) ...[
                Divider(
                  height: adaptive.Adaptive.h(24),
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
                _statRow(
                  '环比变化',
                  '${metrics.changePercent > 0 ? '+' : ''}${metrics.changePercent}%',
                  metrics.changePercent > 0
                      ? AppIcons.trendingUp
                      : AppIcons.arrowDownward,
                  colorScheme,
                  valueColor: metrics.changePercent > 0
                      ? const Color(0xFF30D158)
                      : const Color(0xFFFF3B30),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(
    String label,
    String value,
    IconData icon,
    ColorScheme colorScheme, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(adaptive.Adaptive.w(8)),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
          ),
          child: Icon(
            icon,
            size: adaptive.Adaptive.w(18),
            color: colorScheme.primary,
          ),
        ),
        SizedBox(width: adaptive.Adaptive.w(12)),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(16),
            fontWeight: FontWeight.w600,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // ─── 资源时长排行 ───

  Widget _buildResourceRanking(ColorScheme colorScheme) {
    if (_resourceRanking.isEmpty) {
      return _buildEmptyCard('暂无资源学习数据', colorScheme);
    }

    // 只展示前10个
    final displayList = _resourceRanking.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('资源时长排行', AppIcons.movie, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        ...displayList.asMap().entries.map((entry) {
          final index = entry.key;
          final resource = entry.value;
          return _resourceDurationItem(index + 1, resource, colorScheme);
        }),
      ],
    );
  }

  Widget _resourceDurationItem(
    int rank,
    ResourceDurationDetail resource,
    ColorScheme colorScheme,
  ) {
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
        ? const Color(0xFFC0C0C0)
        : rank == 3
        ? const Color(0xFFCD7F32)
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4);

    final iconData = resource.resourceType == 'article'
        ? AppIcons.article
        : resource.resourceType == 'music'
        ? AppIcons.musicNote
        : AppIcons.video;

    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(10)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(14)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.02),
            blurRadius: adaptive.Adaptive.w(8),
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: adaptive.Adaptive.w(28),
            height: adaptive.Adaptive.w(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rank <= 3
                  ? rankColor.withValues(alpha: 0.15)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(13),
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? rankColor : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          Container(
            padding: EdgeInsets.all(adaptive.Adaptive.w(8)),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
            ),
            child: Icon(
              iconData,
              size: adaptive.Adaptive.w(18),
              color: colorScheme.primary,
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.displayName,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(14),
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: adaptive.Adaptive.h(2)),
                Text(
                  '${resource.sessionCount} 次学习',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(12),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            resource.formattedDuration,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(15),
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 学习时段偏好 ───

  Widget _buildTimePreference(ColorScheme colorScheme) {
    // 基于 dailyData 的学习天数统计
    final dailyData = _metrics?.dailyData ?? {};
    if (dailyData.isEmpty) return const SizedBox.shrink();

    // 计算有学习记录的天数
    final studyDays = dailyData.values.where((seconds) => seconds > 0).length;
    final totalDays = dailyData.length;
    final studyRate = totalDays > 0
        ? (studyDays / totalDays * 100).toStringAsFixed(1)
        : '0';

    // 找出学习最多的那天
    String? maxDay;
    int maxSeconds = 0;
    dailyData.forEach((day, seconds) {
      if (seconds > maxSeconds) {
        maxSeconds = seconds;
        maxDay = day;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('学习活跃度', AppIcons.accessTime, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        Container(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.02),
                blurRadius: adaptive.Adaptive.w(10),
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _timePreferenceItem(
                      '活跃天数',
                      '$studyDays天',
                      AppIcons.calendarToday,
                      colorScheme.primary,
                      colorScheme,
                    ),
                  ),
                  Expanded(
                    child: _timePreferenceItem(
                      '学习频率',
                      '$studyRate%',
                      AppIcons.trendingUp,
                      const Color(0xFF30D158),
                      colorScheme,
                    ),
                  ),
                ],
              ),
              if (maxDay != null) ...[
                SizedBox(height: adaptive.Adaptive.h(16)),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
                SizedBox(height: adaptive.Adaptive.h(16)),
                Row(
                  children: [
                    Icon(
                      AppIcons.emojiEvents,
                      size: adaptive.Adaptive.sp(18),
                      color: const Color(0xFFFFA726),
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    Text(
                      '单日最长学习：',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(13),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      maxDay!,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(13),
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '（${_formatDuration(maxSeconds)}）',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(13),
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _timePreferenceItem(
    String label,
    String value,
    IconData icon,
    Color color,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(adaptive.Adaptive.w(10)),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
          ),
          child: Icon(icon, size: adaptive.Adaptive.w(20), color: color),
        ),
        SizedBox(width: adaptive.Adaptive.w(12)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(12),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(16),
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
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
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(16),
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
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
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.info,
            size: adaptive.Adaptive.sp(36),
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          SizedBox(height: adaptive.Adaptive.h(12)),
          Text(
            message,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
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

  String _formatDuration(int seconds) {
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
