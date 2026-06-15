import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vidlang/models/test_models.dart';
import 'package:vidlang/providers/test_provider.dart';

/// 评测结果页 - 展示得分 + AI 评价报告
class TestResultPage extends ConsumerWidget {
  const TestResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(testProvider);
    final session = state.session;
    final evaluation = state.evaluation;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('评测结果')),
        body: const Center(child: Text('暂无结果')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('评测结果'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(testProvider.notifier).reset();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      body: state.isGeneratingEvaluation
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在生成 AI 评价...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildScoreCard(context, session),
                  const SizedBox(height: 20),
                  if (evaluation != null) ...[
                    _buildEvaluationCard(context, evaluation),
                    const SizedBox(height: 20),
                  ],
                  _buildCategoryRadar(context, evaluation),
                  const SizedBox(height: 20),
                  _buildItemsSummary(context, state.items),
                  const SizedBox(height: 24),
                  _buildActions(context, ref, state),
                ],
              ),
            ),
    );
  }

  Widget _buildScoreCard(BuildContext context, TestSession session) {
    final score = session.totalScore?.round() ?? 0;
    final color = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('综合得分', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              '$score',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '完成 ${session.completedItems}/${session.totalItems} 题 · 用时 ${_formatDuration(session.durationSeconds)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationCard(BuildContext context, TestEvaluation eval) {
    return Card(
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
              Text('薄弱环节',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(eval.weakPoints!),
              const SizedBox(height: 12),
            ],
            if (eval.suggestions != null) ...[
              Text('训练建议',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(eval.suggestions!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRadar(BuildContext context, TestEvaluation? eval) {
    if (eval == null || eval.categoryScores.isEmpty) return const SizedBox.shrink();

    final scores = eval.categoryScores;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('能力分布', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: _RadarChartPainter(
                  listening: scores['听'] ?? 0,
                  speaking: scores['说'] ?? 0,
                  reading: scores['读'] ?? 0,
                  writing: scores['写'] ?? 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['听', '说', '读', '写'].map((label) {
                return Column(
                  children: [
                    Text(
                      '${(scores[label] ?? 0).round()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSummary(BuildContext context, List<TestItem> items) {
    final correct = items.where((i) => i.isCorrect == true).length;
    final wrong = items.where((i) => i.isCorrect == false).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('答题统计', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('正确', correct, Colors.green),
                _statItem('错误', wrong, Colors.red),
                _statItem('总题数', items.length, Colors.blue),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => ListTile(
                  dense: true,
                  leading: Icon(
                    item.isCorrect == true
                        ? Icons.check_circle
                        : item.isCorrect == false
                            ? Icons.cancel
                            : Icons.help,
                    color: item.isCorrect == true
                        ? Colors.green
                        : item.isCorrect == false
                            ? Colors.red
                            : Colors.grey,
                    size: 20,
                  ),
                  title: Text(
                    item.refText,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '${item.type.label} · ${(item.score ?? 0).round()}分',
                    style: const TextStyle(fontSize: 12),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, TestState state) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              ref.read(testProvider.notifier).reset();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('返回'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton(
            onPressed: () {
              ref.read(testProvider.notifier).reset();
              Navigator.of(context)
                  .popUntil((route) => route.isFirst);
            },
            child: const Text('再来一次'),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}分${s}秒';
    return '${s}秒';
  }
}

// ─── 雷达图绘制 ───

class _RadarChartPainter extends CustomPainter {
  final double listening;
  final double speaking;
  final double reading;
  final double writing;

  _RadarChartPainter({
    required this.listening,
    required this.speaking,
    required this.reading,
    required this.writing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2.5;

    final labels = ['听', '说', '读', '写'];
    final values = [listening, speaking, reading, writing];

    // 背景网格
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      final path = Path();
      final r = radius * i / 3;
      for (int j = 0; j < 4; j++) {
        final angle = (j * 90 - 90) * 3.14159 / 180;
        final point = Offset(
          center.dx + r * cos(angle),
          center.dy + r * sin(angle),
        );
        if (j == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 轴线
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * 3.14159 / 180;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        ),
        gridPaint,
      );
    }

    // 数据区域
    final dataPath = Path();
    final dataPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * 3.14159 / 180;
      final r = radius * (values[i] / 100).clamp(0.05, 1.0);
      final point = Offset(
        center.dx + r * cos(angle),
        center.dy + r * sin(angle),
      );
      if (i == 0) {
        dataPath.moveTo(point.dx, point.dy);
      } else {
        dataPath.lineTo(point.dx, point.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataPaint);

    // 数据边框
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(dataPath, borderPaint);

    // 标签
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * 3.14159 / 180;
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final offset = Offset(
        center.dx + (radius + 20) * cos(angle) - tp.width / 2,
        center.dy + (radius + 20) * sin(angle) - tp.height / 2,
      );
      tp.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
