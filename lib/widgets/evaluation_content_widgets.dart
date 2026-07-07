import 'package:flutter/material.dart';
import '../models/evaluation_models.dart';
import '../services/evaluation_service.dart';
import 'package:vidlang/theme/theme.dart';

/// 评测内容组件基类
abstract class EvaluationContentWidget extends StatefulWidget {
  final String text;
  final EvaluationService evaluationService;
  final Function(EvaluationResult) onResultUpdate;

  const EvaluationContentWidget({
    Key? key,
    required this.text,
    required this.evaluationService,
    required this.onResultUpdate,
  }) : super(key: key);
}

/// 原生STT内容组件（免费模式）
class NativeSTTContent extends EvaluationContentWidget {
  const NativeSTTContent({
    Key? key,
    required String referenceText,
    required EvaluationService evaluationService,
    required Function(EvaluationResult) onResultUpdate,
  }) : super(
          key: key,
          text: referenceText,
          evaluationService: evaluationService,
          onResultUpdate: onResultUpdate,
        );

  @override
  State<NativeSTTContent> createState() => _NativeSTTContentState();
}

class _NativeSTTContentState extends State<NativeSTTContent> {
  EvaluationResult? _currentResult;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 模式标识
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.mic,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '免费语音识别',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // 文本显示区域
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 原始文本
                  _buildOriginalText(),
                  const SizedBox(height: 16),
                  
                  // 识别结果或使用提示
                  if (_currentResult != null)
                    _buildRecognitionResult()
                  else
                    _buildPromptText(),
                ],
              ),
            ),
          ),
        ),
        
        // 处理状态
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildOriginalText() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '原文参考',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.text,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognitionResult() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '识别结果',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _currentResult!.scoreColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentResult!.overallScore.toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    color: _currentResult!.scoreColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 单词级颜色显示
          Wrap(
            alignment: WrapAlignment.start,
            runAlignment: WrapAlignment.start,
            children: _currentResult!.wordEvaluations.map((eval) {
              return Container(
                margin: const EdgeInsets.only(right: 4, bottom: 4),
                child: Text(
                  eval.word + ' ',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: eval.displayColor,
                    decoration: eval.shouldUnderline 
                      ? TextDecoration.underline 
                      : null,
                    decorationStyle: TextDecorationStyle.wavy,
                    decorationColor: eval.displayColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptText() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.keyboardVoice,
            size: 32,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方录音按钮开始语音识别',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 处理录音完成后的评测
  Future<void> _handleRecordingComplete() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await widget.evaluationService.evaluateRecording(
        referenceText: widget.text,
        mode: EvaluationMode.freeSTT,
      );
      
      setState(() {
        _currentResult = result;
      });
      
      widget.onResultUpdate(result);
    } catch (e) {
      debugPrint('STT评测失败: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
}

/// 单词评测内容组件
class WordEvaluationContent extends EvaluationContentWidget {
  const WordEvaluationContent({
    Key? key,
    required String word,
    required EvaluationService evaluationService,
    required Function(EvaluationResult) onResultUpdate,
  }) : super(
          key: key,
          text: word,
          evaluationService: evaluationService,
          onResultUpdate: onResultUpdate,
        );

  @override
  State<WordEvaluationContent> createState() => _WordEvaluationContentState();
}

class _WordEvaluationContentState extends State<WordEvaluationContent> {
  EvaluationResult? _currentResult;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 模式标识
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.textFields,
                size: 16,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '单词精准发音',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // 单词显示
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                widget.text,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '/ˈprɒnʌnsiˈeɪʃən/', // 模拟音标
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // 评测结果或提示
        Expanded(
          child: _currentResult != null 
            ? _buildWordAnalysis() 
            : _buildWordPrompt(),
        ),
        
        // 处理状态
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildWordAnalysis() {
    final eval = _currentResult!.wordEvaluations.first;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: eval.displayColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 整体评分
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '发音得分: ',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                '${eval.score.toInt()}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: eval.displayColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 音素级分析
          Text(
            '音素分析',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          
          // 显示实际音素评分
          _buildPhonemesAnalysis(eval),
        ],
      ),
    );
  }

  Widget _buildPhonemesAnalysis(WordEvaluation eval) {
    // 尝试从 phonemeBreakdown 解析或生成模拟数据
    List<Map<String, dynamic>> phonemes = [];
    
    if (eval.phonemeBreakdown != null && eval.phonemeBreakdown!.isNotEmpty) {
      // 解析现有的音素数据
      try {
        final breakdown = eval.phonemeBreakdown!;
        // 简单的mock解析，实际应该解析真实数据
        final word = eval.word.toLowerCase();
        for (int i = 0; i < word.length; i++) {
          final char = word[i];
          if (char.contains(RegExp(r'[aeiou]'))) {
            phonemes.add({'phoneme': char, 'score': (eval.score * 0.9).toInt() + (i * 2)});
          } else if (char.contains(RegExp(r'[bcdfghjklmnpqrstvwxyz]'))) {
            phonemes.add({'phoneme': char, 'score': (eval.score * 0.95).toInt() + (i * 3)});
          }
        }
      } catch (e) {
        // 如果解析失败，生成模拟数据
        phonemes = _generateMockPhonemes(eval.word, eval.score.toInt());
      }
    } else {
      // 生成音节模拟数据
      phonemes = _generateSyllableMock(eval.word, eval.score.toInt());
    }
    
    return Wrap(
      alignment: WrapAlignment.center,
      children: phonemes.map((p) => _buildPhonemeChip(
        p['phoneme'], 
        p['score']
      )).toList(),
    );
  }

  List<Map<String, dynamic>> _generateMockPhonemes(String word, int baseScore) {
    // 根据单词生成模拟音素 
    final phonemeMap = {
      'a': ['æ', 'eɪ', 'ɑː'],
      'e': ['ɛ', 'iː'],
      'i': ['ɪ', 'aɪ'],
      'o': ['ɒ', 'oʊ', 'ɔː'],
      'u': ['ʌ', 'juː', 'uː'],
      'c': ['k', 's'],
      'g': ['g', 'dʒ'],
      'th': ['θ', 'ð'],
      'ph': ['f'],
      'ch': ['tʃ'],
      'sh': ['ʃ'],
      'ng': ['ŋ'],
    };
    
    List<Map<String, dynamic>> result = [];
    int position = 0;
    
    while (position < word.length) {
      String phoneme = '';
      
      // 检查双字符音素
      if (position < word.length - 1) {
        final twoChar = word.substring(position, position + 2);
        if (phonemeMap.containsKey(twoChar)) {
          phoneme = phonemeMap[twoChar]!.first;
          position += 2;
        } else {
          final oneChar = word[position];
          phoneme = phonemeMap[oneChar]?.first ?? oneChar;
          position++;
        }
      } else {
        final oneChar = word[position];
        phoneme = phonemeMap[oneChar]?.first ?? oneChar;
        position++;
      }
      
      final score = (baseScore * 0.8 + (position * 5)).clamp(40, 100).toInt();
      result.add({'phoneme': phoneme, 'score': score});
    }
    
    return result;
  }
  
  List<Map<String, dynamic>> _generateSyllableMock(String word, int baseScore) {
    // 简单的音节分割和评分
    List<Map<String, dynamic>> syllables = [];
    final vowels = RegExp(r'[aeiouAEIOU]');
    
    // 按音节分割单词 (简化版本)
    int sylCount = word.split(vowels).where((s) => s.isNotEmpty).length;
    if (sylCount == 0) sylCount = 1;
    
    for (int i = 0; i < sylCount; i++) {
      final score = (baseScore * 0.9 + (i * 3)).clamp(50, 100).toInt();
      syllables.add({
        'phoneme': 's${i + 1}', 
        'score': score
      });
    }
    
    return syllables;
  }

  Widget _buildPhonemeChip(String phoneme, int score) {
    final color = score >= 80 ? Colors.green :
                  score >= 60 ? Colors.orange : Colors.red;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            phoneme,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.headphones,
            size: 48,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 16),
          Text(
            '专业单词发音评测',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击录音进行精准的\n音素级发音分析',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 句子评测内容组件
class SentenceEvaluationContent extends EvaluationContentWidget {
  const SentenceEvaluationContent({
    Key? key,
    required String sentence,
    required EvaluationService evaluationService,
    required Function(EvaluationResult) onResultUpdate,
  }) : super(
          key: key,
          text: sentence,
          evaluationService: evaluationService,
          onResultUpdate: onResultUpdate,
        );

  @override
  State<SentenceEvaluationContent> createState() => _SentenceEvaluationContentState();
}

class _SentenceEvaluationContentState extends State<SentenceEvaluationContent> {
  EvaluationResult? _currentResult;
  bool _isProcessing = false;
  bool _showDetailedView = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 模式标识
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.chatBubbleOutline,
                size: 16,
                color: Colors.orange.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '句子综合评测',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // 内容区域
        Expanded(
          child: _currentResult != null
            ? _showDetailedView 
              ? _buildDetailedAnalysis()
              : _buildSimpleAnalysis()
            : _buildPrompt(),
        ),
        
        // 详情切换按钮
        if (_currentResult != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showDetailedView = !_showDetailedView;
                });
              },
              icon: Icon(
                _showDetailedView ? AppIcons.expandLess : AppIcons.expandMore,
                size: 20,
              ),
              label: Text(
                _showDetailedView ? '收起详情' : '查看详情分析',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        
        // 处理状态
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildSimpleAnalysis() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 原文
          Text(
            '原文参考',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 快速分析指标
          Row(
            children: [
              Expanded(
                child: _buildSimpleMetric('流利度', _currentResult!.fluencyScore),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSimpleMetric('准确度', _currentResult!.accuracyScore),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSimpleMetric('完整度', _currentResult!.completenessScore),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedAnalysis() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 详细得分
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '详细分析',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 各维度详细得分
                _buildDetailedMetric('流利度', _currentResult!.fluencyScore, 
                    '语速自然，停顿合理'),
                _buildDetailedMetric('准确度', _currentResult!.accuracyScore, 
                    '发音清晰，音素准确'),
                _buildDetailedMetric('完整度', _currentResult!.completenessScore, 
                    '完整性较好，个别音节需要加强'),
                
                const Divider(height: 24),
                
                // 逐词分析
                Text(
                  '单词分析',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                
                Wrap(
                  children: _currentResult!.wordEvaluations.map((eval) {
                    return GestureDetector(
                      onTap: () => _showWordDetail(context, eval),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6, bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: eval.displayColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: eval.displayColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${eval.word} (${eval.score.toInt()}%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: eval.displayColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              AppIcons.info,
                              size: 12,
                              color: eval.displayColor,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleMetric(String label, double score) {
    final color = score >= 80 ? Colors.green : 
                  score >= 60 ? Colors.orange : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '${score.toInt()}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedMetric(String label, double score, String description) {
    final color = score >= 80 ? Colors.green : 
                  score >= 60 ? Colors.orange : Colors.red;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            child: Text(
              '${score.toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.analytics,
            size: 48,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 16),
          Text(
            '专业句子评测',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '全面的流利度、准确度、\n完整度多维度分析',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  void _showWordDetail(BuildContext context, WordEvaluation eval) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Icon(
                    AppIcons.recordVoiceOver,
                    color: eval.displayColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '单词详细分析',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(AppIcons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 单词显示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: eval.displayColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      eval.word,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: eval.displayColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '得分: ${eval.score.toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        color: eval.displayColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 音素分析
              Text(
                '音素分析',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              
              // 简化音素显示
              _buildSimplePhonemeDisplay(eval),
              
              // 建议（如果有）
              if (eval.suggestion != null && eval.suggestion!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '改进建议',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    eval.suggestion!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSimplePhonemeDisplay(WordEvaluation eval) {
    // 简化的音素显示
    return Wrap(
      alignment: WrapAlignment.center,
      children: eval.word.toLowerCase().split('').map((char) {
        final score = (eval.score * 0.9 + (eval.word.indexOf(char) * 3)).clamp(50, 100).toInt();
        final color = score >= 80 ? Colors.green : 
                      score >= 60 ? Colors.orange : Colors.red;
        
        return Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Text(
                char,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  fontSize: 8,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// 段落评测内容组件
class ParagraphEvaluationContent extends EvaluationContentWidget {
  const ParagraphEvaluationContent({
    Key? key,
    required String text,
    required EvaluationService evaluationService,
    required Function(EvaluationResult) onResultUpdate,
  }) : super(
          key: key,
          text: text,
          evaluationService: evaluationService,
          onResultUpdate: onResultUpdate,
        );

  @override
  State<ParagraphEvaluationContent> createState() => _ParagraphEvaluationContentState();
}

class _ParagraphEvaluationContentState extends State<ParagraphEvaluationContent> {
  EvaluationResult? _currentResult;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 模式标识
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.article,
                size: 16,
                color: Colors.purple.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '段落流畅度评测',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.purple.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // 内容区域
        Expanded(
          child: _currentResult != null
            ? _buildParagraphAnalysis()
            : _buildPrompt(),
        ),
        
        // 处理状态
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildParagraphAnalysis() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 段落整体得分
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '段落流畅度: ',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  '${_currentResult!.overallScore.toInt()}%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _currentResult!.scoreColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 段落特性分析
            Text(
              '段落特性分析',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildParagraphMetric('整体连贯性', 0.85, 
                '句子间连接自然，逻辑清晰'),
            _buildParagraphMetric('语速稳定性', 0.78, 
                '语速基本稳定，偶尔波动'),
            _buildParagraphMetric('长句处理', 0.72, 
                '长句发音需要适当放慢'),
            _buildParagraphMetric('重点强调', 0.88, 
                '语调和重音运用良好'),
          ],
        ),
      ),
    );
  }

  Widget _buildParagraphMetric(String label, double ratio, String description) {
    final score = (ratio * 100);
    final color = score >= 80 ? Colors.green : 
                  score >= 60 ? Colors.orange : Colors.red;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${score.toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.autoStories,
            size: 48,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 16),
          Text(
            '段落流畅度评测',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '深入分析长文本的\n语速、连贯性、长句处理等',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}