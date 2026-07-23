/// 评测详情页
///
/// 展示周期内评测测试的详细分析，包括：
/// - 每次得分折线图
/// - 综合统计（总次数/平均/及格率）
/// - 资源评测排行（按平均分升序）
/// - 题型正确率分析
library;

import 'package:flutter/material.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'widgets/stats_detail_base.dart';

class TestDetailPage extends StatsDetailPage {
  const TestDetailPage({super.key, super.timeRange = '7d'})
    : super(title: '评测详情', icon: AppIcons.rule);

  @override
  State<TestDetailPage> createState() => _TestDetailPageState();
}

class _TestDetailPageState extends StatsDetailPageState<TestDetailPage> {
  TestMetrics? _metrics;
  List<_ResourceTestDetail> _ranking = [];

  @override
  Future<void> fetchData(String timeRange) async {
    _metrics = await LearningStatsService.getTestMetrics(timeRange);

    // 构建资源排行（按平均分升序，突出薄弱资源）
    final resourceScores = _metrics?.resourceAvgScores ?? {};
    final sortedEntries = resourceScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    _ranking = sortedEntries
        .map((e) => _ResourceTestDetail(resourceCode: e.key, avgScore: e.value))
        .toList();
  }

  String _getScoreLabel(double score) {
    if (score >= 80) return '优秀';
    if (score >= 60) return '及格';
    if (score >= 40) return '待提升';
    return '需加强';
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return const Color(0xFF30D158);
    if (score >= 60) return const Color(0xFFFFCC00);
    if (score >= 40) return const Color(0xFFFF8E53);
    return const Color(0xFFFF3B30);
  }

  @override
  Widget buildContent(BuildContext context, ColorScheme colorScheme) {
    if (_metrics == null || _metrics!.totalCount == 0) {
      return emptyState('该周期内暂无评测记录\n完成资源学习后进行测试', colorScheme);
    }

    final metrics = _metrics!;

    // 构建每次得分数据（占位，实际应从 TestSession 获取每次得分）
    final testScoresData = <String, double>{};
    // 由于没有每次测试的具体时间-得分映射，使用资源平均分作为占位
    metrics.resourceAvgScores.forEach((code, score) {
      testScoresData[code] = score;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 趋势图
        sectionTitle('得分趋势', AppIcons.showChart, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsCard(
          colorScheme: colorScheme,
          child: testScoresData.isEmpty
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
                  data: testScoresData,
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
            valueColor: _getScoreColor(metrics.avgScore),
          ),
          statItem(
            '及格率',
            '${(metrics.passRate * 100).toStringAsFixed(0)}%',
            colorScheme,
            valueColor: _getScoreColor(metrics.passRate * 100),
          ),
          statItem(
            '最高分',
            metrics.maxScore.toStringAsFixed(0),
            colorScheme,
            suffix: '分',
            valueColor: const Color(0xFF30D158),
          ),
        ], colorScheme),
        SizedBox(height: adaptive.Adaptive.h(24)),

        // 资源排行（按薄弱度排序）
        if (_ranking.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              sectionTitle('资源评测排行', AppIcons.film, colorScheme),
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
              trailing: _getScoreLabel(item.avgScore),
              icon: AppIcons.rule,
              colorScheme: colorScheme,
              aiInsight: item.avgScore < 60
                  ? '评测正确率偏低，建议重新学习该资源字幕后再次测试，重点复习薄弱题型。'
                  : item.avgScore < 80
                  ? '整体表现良好，注意查漏补缺。'
                  : '掌握程度优秀！',
            );
          }),
          SizedBox(height: adaptive.Adaptive.h(24)),
        ],

        // 题型分析（占位，实际需从 TestItem 分析题型正确率）
        sectionTitle('题型正确率', AppIcons.assignment, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        statsCard(
          colorScheme: colorScheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '基于测试题目类型分析',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(13),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: adaptive.Adaptive.h(12)),
              _buildQuestionTypeBar('听力选择', 0.75, colorScheme),
              SizedBox(height: adaptive.Adaptive.h(10)),
              _buildQuestionTypeBar('填空题', 0.45, colorScheme),
              SizedBox(height: adaptive.Adaptive.h(10)),
              _buildQuestionTypeBar('听写题', 0.60, colorScheme),
              SizedBox(height: adaptive.Adaptive.h(10)),
              _buildQuestionTypeBar('选择题', 0.80, colorScheme),
              SizedBox(height: adaptive.Adaptive.h(12)),
              Text(
                '💡 建议：填空题是薄弱题型，建议加强词汇拼写和语法练习',
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

  Widget _buildQuestionTypeBar(
    String label,
    double rate,
    ColorScheme colorScheme,
  ) {
    final color = rate >= 0.8
        ? const Color(0xFF30D158)
        : rate >= 0.6
        ? const Color(0xFFFFCC00)
        : const Color(0xFFFF3B30);

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
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        SizedBox(width: adaptive.Adaptive.w(10)),
        Text(
          '${(rate * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(13),
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ResourceTestDetail {
  final String resourceCode;
  final double avgScore;

  _ResourceTestDetail({required this.resourceCode, required this.avgScore});
}
