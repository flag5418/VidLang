import 'dart:developer' as dev;

import 'package:vidlang/models/shengtong_evaluation_result.dart';
import 'package:vidlang/services/ai/ai_service.dart';
import 'package:vidlang/services/evaluation/evaluation_storage_service.dart';

/// AI 发音分析服务
///
/// 手动触发，基于声通评测结果提供个性化改进建议。
/// 使用千问 qwen-turbo 高性价比模型。
class AiEvaluationService {
  /// 手动触发 AI 发音分析
  ///
  /// [evaluationResult] 声通评测结构化结果
  /// [resourceTitle] 资源标题
  /// [refText] 参考文本
  /// [language] 语言，默认 'en'
  /// [sourceType] 资源类型（video/article/music），用于资源溯源
  /// [sourceCode] 资源编码，用于资源溯源
  ///
  /// 返回 AI 分析结果，失败返回 null
  static Future<AiAnalysisResult?> analyzePronunciation({
    required ShengtongEvaluationResult evaluationResult,
    required String resourceTitle,
    String? refText,
    String? language,
    String? sourceType,
    String? sourceCode,
  }) async {
    try {
      // 1. 可选：获取历史摘要（提供上下文）
      final evalType = EvaluationStorageService.detectEvaluationType(
        refText ?? evaluationResult.refText,
      );

      Map<String, dynamic>? historySummary;
      try {
        final historyResponse = await EvaluationStorageService.getSummary(
          evaluationType: evalType,
        );
        if (historyResponse['ok'] == true) {
          final summaries = historyResponse['summaries'] as List<dynamic>?;
          if (summaries != null && summaries.isNotEmpty) {
            final match = summaries.firstWhere(
              (s) => s['evaluation_type'] == evalType,
              orElse: () => null,
            );
            if (match != null) {
              historySummary = {
                'total_count': match['total_count'] ?? 0,
                'avg_overall': match['avg_overall'] ?? 0,
                'weak_dimensions': match['weak_dimensions'] ?? [],
              };
            }
          }
        }
      } catch (e) {
        dev.log('⚠️ 获取历史摘要失败（非致命）: $e', name: 'AiEvaluationService');
      }

      // 2. 构建 AI 分析参数
      final aiData = evaluationResult.toAiAnalysisData();

      // 3. 调用 ai-proxy Edge Function
      final result = await AiService.callAiProxyRaw(
        ruleCode: 'ai_audio_evaluation',
        scene: 'shadow_reader',
        entry: 'ai_analysis',
        sourceType: sourceType,
        sourceCode: sourceCode,
        params: {
          ...aiData,
          'resource_title': resourceTitle,
          'ref_text': refText ?? evaluationResult.refText ?? '',
          'language': language ?? 'en',
          'history_summary': ?historySummary,
        },
      );

      if (result['ok'] != true) {
        dev.log('❌ AI 分析失败: ${result['error']}', name: 'AiEvaluationService');
        return null;
      }

      final aiResult = result['result'] as Map<String, dynamic>?;
      if (aiResult == null) return null;

      return AiAnalysisResult.fromJson(aiResult);
    } catch (e, stack) {
      dev.log('❌ AI 分析异常: $e', name: 'AiEvaluationService');
      dev.log(stack.toString(), name: 'AiEvaluationService');
      return null;
    }
  }
}

/// AI 分析结果模型
class AiAnalysisResult {
  /// 整体评价（2-3句话）
  final String analysis;

  /// 具体改进建议列表
  final List<String> suggestions;

  /// 重点练习区域
  final List<FocusArea> focusAreas;

  /// 建议重点练习的单词
  final List<PracticeWord> practiceWords;

  AiAnalysisResult({
    required this.analysis,
    required this.suggestions,
    required this.focusAreas,
    required this.practiceWords,
  });

  factory AiAnalysisResult.fromJson(Map<String, dynamic> json) {
    return AiAnalysisResult(
      analysis: json['analysis'] as String? ?? '',
      suggestions:
          (json['suggestions'] as List<dynamic>?)?.cast<String>() ?? [],
      focusAreas:
          (json['focus_areas'] as List<dynamic>?)
              ?.map((e) => FocusArea.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      practiceWords:
          (json['practice_words'] as List<dynamic>?)
              ?.map((e) => PracticeWord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'analysis': analysis,
    'suggestions': suggestions,
    'focus_areas': focusAreas.map((e) => e.toJson()).toList(),
    'practice_words': practiceWords.map((e) => e.toJson()).toList(),
  };
}

/// 重点练习区域
class FocusArea {
  final String area;
  final String priority; // high / medium / low

  FocusArea({required this.area, required this.priority});

  factory FocusArea.fromJson(Map<String, dynamic> json) {
    return FocusArea(
      area: json['area'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toJson() => {'area': area, 'priority': priority};
}

/// 建议练习的单词
class PracticeWord {
  final String word;
  final String reason;

  PracticeWord({required this.word, required this.reason});

  factory PracticeWord.fromJson(Map<String, dynamic> json) {
    return PracticeWord(
      word: json['word'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'word': word, 'reason': reason};
}
