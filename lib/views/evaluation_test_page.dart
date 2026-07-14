import 'package:flutter/material.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import '../widgets/pronunciation_evaluation_modal.dart';
import '../models/evaluation_models.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/widgets/app_dialogs.dart';

/// 评测测试页面 - 用于演示各种评测模式
class EvaluationTestPage extends StatefulWidget {
  const EvaluationTestPage({super.key});

  @override
  State<EvaluationTestPage> createState() => _EvaluationTestPageState();
}

class _EvaluationTestPageState extends State<EvaluationTestPage> {
  EvaluationResult? _lastResult;

  // 测试文本示例
  final Map<String, String> _testTexts = {
    'STT模式': 'This is a simple test for speech recognition evaluation.',
    '单词模式': 'pronunciation',
    '短句模式': 'The quick brown fox jumps over the lazy dog.',
    '段落模式':
        'Artificial intelligence has revolutionized the way we approach complex problems. Machine learning algorithms can now process vast amounts of data and identify patterns that humans might miss. This technology is being applied in various fields including healthcare, transportation, and education.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('跟读评测测试'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: AppColors.surface,
        elevation: 2,
      ),
      body: Container(
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页面标题
            Text(
              '评测功能演示',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 24),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 8)),
            Text(
              '点击下方按钮测试不同类型的跟读评测',
              style: TextStyle(fontSize: adaptive.Adaptive.sp(context, 16), color: AppColors.textSecondary),
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 32)),

            // 测试按钮网格
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  _buildTestCard(
                    '免费STT模式',
                    'speech_to_text',
                    AppColors.primary,
                    AppIcons.mic,
                    () => _showEvaluation(
                      _testTexts['STT模式']!,
                      EvaluationMode.freeSTT,
                    ),
                  ),
                  _buildTestCard(
                    '单词评测',
                    'word_evaluation',
                    AppColors.success,
                    AppIcons.textFields,
                    () => _showEvaluation(
                      _testTexts['单词模式']!,
                      EvaluationMode.word,
                    ),
                  ),
                  _buildTestCard(
                    '句子评测',
                    'sentence_evaluation',
                    AppColors.warning,
                    AppIcons.chatBubbleOutline,
                    () => _showEvaluation(
                      _testTexts['短句模式']!,
                      EvaluationMode.sentence,
                    ),
                  ),
                  _buildTestCard(
                    '段落评测',
                    'paragraph_evaluation',
                    AppColors.primary,
                    AppIcons.article,
                    () => _showEvaluation(
                      _testTexts['段落模式']!,
                      EvaluationMode.paragraph,
                    ),
                  ),
                ],
              ),
            ),

            // 最近结果展示
            if (_lastResult != null) _buildLastResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(
    String title,
    String subtitle,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 16)),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.surface, size: adaptive.Adaptive.icon(context, 24)),
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 12)),
            Text(
              title,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 16),
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 4)),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 12),
                color: color.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastResult() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
      decoration: BoxDecoration(
        color: _lastResult!.scoreColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
        border: Border.all(
          color: _lastResult!.scoreColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.analytics,
                color: _lastResult!.scoreColor,
                size: adaptive.Adaptive.icon(context, 20),
              ),
              SizedBox(width: adaptive.Adaptive.w(context, 8)),
              Text(
                '最近评测结果',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(context, 16),
                  fontWeight: FontWeight.bold,
                  color: _lastResult!.scoreColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _lastResult!.scoreColor,
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
                ),
                child: Text(
                  '${_lastResult!.overallScore.toInt()}%',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(context, 14),
                    fontWeight: FontWeight.bold,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(context, 12)),

          // 文本预览
          Text(
            '评测文本: ${_lastResult!.referenceText.length > 50 ? "${_lastResult!.referenceText.substring(0, 50)}..." : _lastResult!.referenceText}',
            style: TextStyle(fontSize: adaptive.Adaptive.sp(context, 14), color: AppColors.textSecondary),
          ),
          SizedBox(height: adaptive.Adaptive.h(context, 8)),

          // 维度得分
          Row(
            children: [
              Expanded(
                child: _buildScoreChip('流利度', _lastResult!.fluencyScore),
              ),
              SizedBox(width: adaptive.Adaptive.w(context, 8)),
              Expanded(
                child: _buildScoreChip('准确度', _lastResult!.accuracyScore),
              ),
              SizedBox(width: adaptive.Adaptive.w(context, 8)),
              Expanded(
                child: _buildScoreChip('完整度', _lastResult!.completenessScore),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChip(String label, double score) {
    final color = score >= 80
        ? AppColors.success
        : score >= 60
        ? AppColors.warning
        : AppColors.error;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(context, 8), vertical: adaptive.Adaptive.h(context, 4)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 8)),
      ),
      child: Column(
        children: [
          Text(
            '${score.toInt()}%',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(context, 12),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: adaptive.Adaptive.sp(context, 10), color: color)),
        ],
      ),
    );
  }

  void _showEvaluation(String text, EvaluationMode mode) {
    showPronunciationEvaluation(
      context,
      text: text,
      mode: mode,
      onComplete: (result) {
        setState(() {
          _lastResult = result;
        });

        // 显示结果提示
        AppToast.show(context, '评测完成！得分: ${result.overallScore.toInt()}%', type: ToastType.success);
      },
    );
  }
}

/// 便捷方法：在应用中任意位置显示评测弹窗
void showEvaluationTestPage(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const EvaluationTestPage()),
  );
}
