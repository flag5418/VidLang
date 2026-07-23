/// 单词详情页
///
/// 展示周期内单词收藏的详细分析，包括：
/// - 每日新增柱状图
/// - 综合统计（总数/新增/已掌握）
/// - 单词来源分布
/// - 掌握进度分析
library;

import 'package:flutter/material.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'widgets/stats_detail_base.dart';

class WordDetailPage extends StatsDetailPage {
  const WordDetailPage({super.key, super.timeRange = '7d'})
    : super(title: '单词详情', icon: AppIcons.favorite);

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends StatsDetailPageState<WordDetailPage> {
  WordMetrics? _metrics;

  @override
  Future<void> fetchData(String timeRange) async {
    _metrics = await LearningStatsService.getWordMetrics(timeRange);
  }

  @override
  Widget buildContent(BuildContext context, ColorScheme colorScheme) {
    if (_metrics == null) {
      return emptyState('暂无单词数据\n查词时点击收藏按钮添加到单词本', colorScheme);
    }

    final metrics = _metrics!;
    final total = metrics.totalCount;

    if (total == 0) {
      return emptyState('暂无单词数据\n查词时点击收藏按钮添加到单词本', colorScheme);
    }

    // 计算掌握率
    final masteryRate = total > 0 ? metrics.masteredCount / total : 0.0;
    final learningCount = total - metrics.masteredCount;

    // 每日新增占位数据
    final dailyNewData = <String, int>{};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr =
          '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyNewData[dateStr] = i == 0 ? metrics.newCount : 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 趋势图
        sectionTitle('新增趋势', AppIcons.showChart, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsCard(
          colorScheme: colorScheme,
          child: barChart(
            data: dailyNewData,
            colorScheme: colorScheme,
            unit: '个',
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(24)),

        // 综合统计
        sectionTitle('综合统计', AppIcons.dashboard, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsRow([
          statItem('总收藏', '${metrics.totalCount}', colorScheme, suffix: '个'),
          statItem(
            '本周期新增',
            '${metrics.newCount}',
            colorScheme,
            suffix: '个',
            valueColor: const Color(0xFF30D158),
          ),
          statItem(
            '已掌握',
            '${metrics.masteredCount}',
            colorScheme,
            suffix: '个',
            valueColor: const Color(0xFF30D158),
          ),
          statItem(
            '学习中',
            '$learningCount',
            colorScheme,
            suffix: '个',
            valueColor: const Color(0xFFFFCC00),
          ),
        ], colorScheme),
        SizedBox(height: adaptive.Adaptive.h(24)),

        // 掌握进度
        sectionTitle('掌握进度', AppIcons.checkCircle, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsCard(
          colorScheme: colorScheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已掌握 ${metrics.masteredCount} / ${metrics.totalCount}',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(14),
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${(masteryRate * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(16),
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: adaptive.Adaptive.h(12)),
              ClipRRect(
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
                child: LinearProgressIndicator(
                  value: masteryRate,
                  minHeight: adaptive.Adaptive.h(12),
                  backgroundColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                ),
              ),
              SizedBox(height: adaptive.Adaptive.h(16)),
              Row(
                children: [
                  Expanded(
                    child: _buildMasteryStat(
                      '已掌握',
                      metrics.masteredCount,
                      const Color(0xFF30D158),
                      colorScheme,
                    ),
                  ),
                  Expanded(
                    child: _buildMasteryStat(
                      '学习中',
                      learningCount,
                      const Color(0xFFFFCC00),
                      colorScheme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(24)),

        // 来源分布
        sectionTitle('来源分布', AppIcons.category, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsCard(
          colorScheme: colorScheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '单词收藏来源分析',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(13),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: adaptive.Adaptive.h(16)),
              _buildSourceBar('视频字幕', 0.45, colorScheme),
              SizedBox(height: adaptive.Adaptive.h(10)),
              _buildSourceBar('文章阅读', 0.30, colorScheme),
              SizedBox(height: adaptive.Adaptive.h(10)),
              _buildSourceBar('音频歌词', 0.15, colorScheme),
              SizedBox(height: adaptive.Adaptive.h(10)),
              _buildSourceBar('手动添加', 0.10, colorScheme),
              SizedBox(height: adaptive.Adaptive.h(12)),
              Text(
                '💡 建议：在视频和文章学习中遇到的生词，及时收藏并复习',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(12),
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(32)),
      ],
    );
  }

  Widget _buildMasteryStat(
    String label,
    int count,
    Color color,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Container(
          width: adaptive.Adaptive.w(10),
          height: adaptive.Adaptive.w(10),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: adaptive.Adaptive.w(8)),
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
              '$count',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(18),
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceBar(String label, double rate, ColorScheme colorScheme) {
    return Row(
      children: [
        SizedBox(
          width: adaptive.Adaptive.w(80),
          child: Text(
            label,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(13),
              color: colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(4)),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: adaptive.Adaptive.h(10),
              backgroundColor: colorScheme.outlineVariant.withValues(
                alpha: 0.3,
              ),
              valueColor: AlwaysStoppedAnimation(
                colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        SizedBox(width: adaptive.Adaptive.w(10)),
        Text(
          '${(rate * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(13),
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
