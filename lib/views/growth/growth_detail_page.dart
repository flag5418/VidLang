import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vidlang/providers/growth_provider.dart';

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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTestInfo(context, test),
                  const SizedBox(height: 16),
                  if (eval != null) ...[
                    _buildAiReport(context, eval),
                    const SizedBox(height: 16),
                  ],
                  _buildCategoryScores(context, eval),
                  const SizedBox(height: 16),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '$score 分',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: score >= 80
                        ? Colors.green
                        : score >= 60
                            ? Colors.orange
                            : Colors.red,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _testTypeLabel(test.testType as String),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
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
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber),
                const SizedBox(width: 8),
                Text('AI 评价报告',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Divider(),
            if (eval.weakPoints != null) ...[
              const SizedBox(height: 4),
              Text('薄弱环节',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(eval.weakPoints as String),
            ],
            if (eval.suggestions != null) ...[
              const SizedBox(height: 16),
              Text('训练建议',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(eval.suggestions as String),
            ],
            if (eval.comparisonJson != null &&
                (eval.comparisonJson as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('与上次对比',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('能力分布', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
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
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  score >= 80
                      ? Colors.green
                      : score >= 60
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${score.round()}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('题目详情', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map((item) {
              final isCorrect = item.isCorrect == true;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      isCorrect ? Colors.green.shade100 : Colors.red.shade100,
                  child: Icon(
                    isCorrect ? Icons.check : Icons.close,
                    size: 16,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(
                  item.refText as String,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  '${_questionTypeLabel(item.questionType as String)} · ${(item.score ?? 0).round()}分',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: (item.score ?? 0) >= 80
                    ? const Icon(Icons.emoji_events, color: Colors.amber, size: 20)
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
      case 'listenChoose':
        return '听音选词';
      case 'meaningWrite':
        return '看义写词';
      case 'sentenceDictation':
        return '句中听写';
      case 'translateBoth':
        return '中英互译';
      case 'wordPron':
        return '跟读单词';
      case 'phrasePron':
        return '跟读短语';
      case 'sentencePron':
        return '句子跟读';
      case 'reorder':
        return '组句题';
      case 'spelling':
        return '拼写填空';
      case 'mcq':
        return '选择题';
      default:
        return type;
    }
  }
}
