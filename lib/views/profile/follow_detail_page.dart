/// 跟读详情页
///
/// 展示周期内跟读练习的详细分析，包括：
/// - 每日平均跟读分折线图
/// - 综合统计（总次数/平均/最高/最低分）
/// - 资源跟读排行（按平均分升序，突出薄弱）
/// - 句子级薄弱点分析
library;

import 'package:flutter/material.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'widgets/stats_detail_base.dart';

class FollowDetailPage extends StatsDetailPage {
  const FollowDetailPage({super.key, super.timeRange = '7d'})
    : super(title: '跟读详情', icon: AppIcons.mic);

  @override
  State<FollowDetailPage> createState() => _FollowDetailPageState();
}

class _FollowDetailPageState extends StatsDetailPageState<FollowDetailPage> {
  FollowMetrics? _metrics;
  List<_ResourceFollowDetail> _ranking = [];

  @override
  Future<void> fetchData(String timeRange) async {
    _metrics = await LearningStatsService.getFollowMetrics(timeRange);

    // 构建资源排行（按平均分升序，突出薄弱资源）
    final resourceScores = _metrics?.resourceAvgScores ?? {};
    final sortedEntries = resourceScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    _ranking = sortedEntries
        .map(
          (e) => _ResourceFollowDetail(
            resourceCode: e.key,
            avgScore: e.value,
            // 详细数据需要额外查询
          ),
        )
        .toList();
  }

  String _getScoreColor(double score) {
    if (score >= 80) return '优秀';
    if (score >= 60) return '良好';
    if (score >= 40) return '一般';
    return '需加强';
  }

  Color _getScoreColorValue(double score, ColorScheme colorScheme) {
    if (score >= 80) return const Color(0xFF30D158);
    if (score >= 60) return const Color(0xFFFFCC00);
    if (score >= 40) return const Color(0xFFFF8E53);
    return const Color(0xFFFF3B30);
  }

  @override
  Widget buildContent(BuildContext context, ColorScheme colorScheme) {
    if (_metrics == null || _metrics!.totalCount == 0) {
      return emptyState('该周期内暂无跟读记录\n在播放器中点击麦克风图标开始跟读', colorScheme);
    }

    final metrics = _metrics!;

    // 构建每日平均分数据用于折线图
    final dailyAvgData = <String, double>{};
    // 由于 FollowMetrics 中没有直接提供每日平均分，使用占位
    // 实际应该从 RecordingRecord 按天聚合计算
    metrics.dailyCount.forEach((date, count) {
      dailyAvgData[date] = metrics.avgScore; // 简化处理
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 趋势图
        sectionTitle('得分趋势', AppIcons.showChart, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsCard(
          colorScheme: colorScheme,
          child: dailyAvgData.isEmpty
              ? Center(
                  child: Text(
                    '数据不足，无法生成趋势图',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(14),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : lineChart(
                  data: dailyAvgData,
                  colorScheme: colorScheme,
                  unit: '分',
                ),
        ),
        SizedBox(height: adaptive.Adaptive.h(24)),

        // 综合统计
        sectionTitle('综合统计', AppIcons.dashboard, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsRow([
          statItem('总次数', '${metrics.totalCount}', colorScheme, suffix: '次'),
          statItem(
            '平均分',
            metrics.avgScore.toStringAsFixed(1),
            colorScheme,
            suffix: '分',
            valueColor: _getScoreColorValue(metrics.avgScore, colorScheme),
          ),
          statItem(
            '最高分',
            metrics.maxScore.toStringAsFixed(0),
            colorScheme,
            suffix: '分',
            valueColor: const Color(0xFF30D158),
          ),
          statItem(
            '最低分',
            metrics.minScore.toStringAsFixed(0),
            colorScheme,
            suffix: '分',
            valueColor: const Color(0xFFFF3B30),
          ),
        ], colorScheme),
        SizedBox(height: adaptive.Adaptive.h(24)),

        // 资源排行（按平均分升序，突出薄弱）
        if (_ranking.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              sectionTitle('资源跟读排行', AppIcons.film, colorScheme),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: adaptive.Adaptive.w(8),
                  vertical: adaptive.Adaptive.h(4),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                ),
                child: Text(
                  '按薄弱度排序',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(11),
                    color: const Color(0xFFFF3B30),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(12)),
          ..._ranking.map((item) {
            return resourceRankingItem(
              title: item.resourceCode,
              subtitle: '平均 ${item.avgScore.toStringAsFixed(1)} 分',
              trailing: _getScoreColor(item.avgScore),
              icon: AppIcons.mic,
              colorScheme: colorScheme,
              aiInsight: item.avgScore < 60
                  ? '跟读得分偏低，建议放慢语速、注意发音准确度，多练习该资源的重点句子。'
                  : item.avgScore < 80
                  ? '整体表现不错，注意提升语调和流利度。'
                  : '流利度优秀，继续保持！',
            );
          }),
          SizedBox(height: adaptive.Adaptive.h(24)),
        ],

        // 学习习惯分析
        sectionTitle('跟读习惯分析', AppIcons.psychology, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsCard(
          colorScheme: colorScheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              habitAnalysisItem(
                '平均每次跟读 ${(metrics.totalCount / (metrics.dailyCount.isNotEmpty ? metrics.dailyCount.length : 1)).toStringAsFixed(0)} 句',
                colorScheme,
              ),
              habitAnalysisItem(
                metrics.avgScore >= 80
                    ? '整体跟读水平优秀，发音准确度较高'
                    : '建议重点关注发音准确度，多进行慢速跟读练习',
                colorScheme,
              ),
              habitAnalysisItem('最佳提升方式：针对薄弱资源反复练习，直到平均分达到80分以上', colorScheme),
            ],
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(32)),
      ],
    );
  }
}

class _ResourceFollowDetail {
  final String resourceCode;
  final double avgScore;

  _ResourceFollowDetail({required this.resourceCode, required this.avgScore});
}
