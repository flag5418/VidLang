import 'package:flutter/material.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vidlang/providers/growth_provider.dart';
import 'package:vidlang/theme/theme.dart';

/// 单次评测详细页 — 展示完整 AI 评价报告
class GrowthDetailPage extends ConsumerStatefulWidget {
  final int testId;

  const GrowthDetailPage({super.key, required this.testId});

  @override
  ConsumerState<GrowthDetailPage> createState() => _GrowthDetailPageState();
}

class _GrowthDetailPageState extends ConsumerState<GrowthDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(growthProvider.notifier).loadTestDetail(widget.testId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(growthProvider);
    final test = state.selectedTest;
    final eval = state.selectedEvaluation;
    final items = state.selectedItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('评测详情'),
      ),
      body: test == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTestInfo(context, test),
                  SizedBox(height: adaptive.Adaptive.h(context, 16)),
                  if (eval != null) ...[
                    _buildAiReport(context, eval),
                    SizedBox(height: adaptive.Adaptive.h(context, 16)),
                  ],
                  _buildCategoryScores(context, eval),
                  SizedBox(height: adaptive.Adaptive.h(context, 16)),
                  _buildItemList(context, items),
                ],
              ),
            ),
    );
  }

  Widget _buildTestInfo(BuildContext context, dynamic test) {
    final score = test.totalScore?.round() ?? 0;
    final date = test.startedAt as DateTime;
    final minutes = (test.durationSeconds as int) ~/ 60;
    final seconds = (test.durationSeconds as int) % 60;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 20)),
        child: Column(
          children: [
            Text(
              '$score 分',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: score >= 80
                        ? AppColors.success
                        : score >= 60
                            ? AppColors.warning
                            : AppColors.error,
                  ),
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 8)),
            Text(
              _testTypeLabel(test.testType as String),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 4)),
            Text(
              '${date.year}年${date.month}月${date.day}日 ${date.hour}:${date.minute.toString().padLeft(2, '0')} · '
              '${test.completedItems}/${test.totalItems}题 · '
              '$minutes分$seconds秒',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiReport(BuildContext context, dynamic eval) {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(AppIcons.autoAwesome, color: AppColors.warning),
                SizedBox(width: adaptive.Adaptive.w(context, 8)),
                Text('AI 评价报告',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Divider(),
            if (eval.weakPoints != null) ...[
              SizedBox(height: adaptive.Adaptive.h(context, 4)),
              Text('薄弱环节',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: adaptive.Adaptive.h(context, 4)),
              Text(eval.weakPoints as String),
            ],
            if (eval.suggestions != null) ...[
              SizedBox(height: adaptive.Adaptive.h(context, 16)),
              Text('训练建议',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: adaptive.Adaptive.h(context, 4)),
              Text(eval.suggestions as String),
            ],
            if (eval.comparisonJson != null &&
                (eval.comparisonJson as String).isNotEmpty) ...[
              SizedBox(height: adaptive.Adaptive.h(context, 16)),
              Text('与上次对比',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              SizedBox(height: adaptive.Adaptive.h(context, 4)),
              Text(eval.comparisonJson as String),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryScores(BuildContext context, dynamic eval) {
    if (eval == null) return const SizedBox.shrink();
    final scores = eval.categoryScores;
    if (scores.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('能力分布', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: adaptive.Adaptive.h(context, 12)),
            _scoreBar('听力', scores['听'] ?? 0),
            _scoreBar('口语', scores['说'] ?? 0),
            _scoreBar('阅读', scores['读'] ?? 0),
            _scoreBar('写作', scores['写'] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _scoreBar(String label, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(label, style: TextStyle(fontSize: adaptive.Adaptive.sp(context, 13))),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 4)),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 12,
                backgroundColor: AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation(
                  score >= 80
                      ? AppColors.success
                      : score >= 60
                          ? AppColors.warning
                          : AppColors.error,
                ),
              ),
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(context, 8)),
          SizedBox(
            width: 36,
            child: Text(
              '${score.round()}',
              style: TextStyle(fontSize: adaptive.Adaptive.sp(context, 13), fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(BuildContext context, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('题目详情', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: adaptive.Adaptive.h(context, 8)),
            ...items.map((item) {
              final isCorrect = item.isCorrect == true;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      isCorrect ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15),
                  child: Icon(
                    isCorrect ? AppIcons.check : AppIcons.close,
                    size: adaptive.Adaptive.icon(context, 16),
                    color: isCorrect ? AppColors.success : AppColors.error,
                  ),
                ),
                title: Text(
                  item.refText as String,
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(context, 14)),
                ),
                subtitle: Text(
                  '${_questionTypeLabel(item.questionType as String)} · ${(item.score ?? 0).round()}分',
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(context, 12)),
                ),
                trailing: (item.score ?? 0) >= 80
                    ? Icon(AppIcons.emojiEvents, color: AppColors.warning, size: adaptive.Adaptive.icon(context, 20))
                    : null,
              );
            }),
          ],
        ),
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

  String _questionTypeLabel(String type) {
    switch (type) {
      // 新版题型
      case 'listen_choose':
      case 'listenChoose':
        return '原音选择';
      case 'listen_meaning':
      case 'listenMeaning':
        return '听音辩义';
      case 'listen_reply':
      case 'listenReply':
        return '听音回复';
      case 'definition_choice':
      case 'definitionChoice':
        return '释义选择';
      case 'translate_meaning':
      case 'translateMeaning':
        return '英义互译';
      case 'word_relation':
      case 'wordRelation':
        return '词性测试';
      case 'word_pron':
      case 'wordPron':
        return '跟读单词';
      case 'phrase_pron':
      case 'phrasePron':
        return '跟读短语';
      case 'sentence_pron':
      case 'sentencePron':
        return '句子跟读';
      case 'reorder':
        return '组句';
      case 'spelling':
        return '拼写填空';
      // 旧版题型
      case 'meaningWrite':
        return '看义写词';
      case 'sentenceDictation':
        return '句中听写';
      case 'translateBoth':
        return '中英互译';
      case 'mcq':
        return '选择题';
      default:
        return type;
    }
  }
}
