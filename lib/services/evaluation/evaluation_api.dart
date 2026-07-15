import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 评测 API 客户端
///
/// 统一调用 ai-proxy Edge Function 完成：TTS 合成、声通评分、千问判分。
class EvaluationApi {
  static const _functionName = 'ai-proxy';

  // ─── TTS 合成 ───

  /// 合成 TTS 音频，返回 base64 字符串
  static Future<String?> getTtsAudio(String text) async {
    try {
      final client = Supabase.instance.client;
      final resp = await client.functions.invoke(
        _functionName,
        body: {
          'rule_code': 'ai_tts',
          'scene': 'test_prompt',
          'entry': 'tts_synthesis',
          'request_id': _generateRequestId(),
          'params': {
            'text': text,
            'voice': 'Aiden',
          },
        },
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data?['ok'] == true && data?['result'] != null) {
        final result = data!['result'] as Map<String, dynamic>;
        return result['audioBase64'] as String?;
      }
      return null;
    } catch (e) {
      print('EvaluationApi.getTtsAudio error: $e');
      return null;
    }
  }

  // ─── 声通评测 ───

  /// 声通发音评分
  /// [coreType]: word.eval | sent.eval（⚠️ 不带语言前缀，参考声通文档）
  /// [refText]: 参考文本
  /// [audioBase64]: 用户录音 base64
  static Future<Map<String, dynamic>?> scorePronunciation({
    required String coreType,
    required String refText,
    required String audioBase64,
  }) async {
    try {
      final client = Supabase.instance.client;
      final resp = await client.functions.invoke(
        _functionName,
        body: {
          'rule_code': 'st_pron_score',
          'scene': 'test_pronunciation',
          'entry': 'pron_score',
          'request_id': _generateRequestId(),
          'params': {
            'core_type': coreType,
            'ref_text': refText,
            'audio_base64': audioBase64,
            'audio_type': 'wav',
            'sample_rate': 16000,
          },
        },
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data?['ok'] == true && data?['result'] != null) {
        final result = data!['result'] as Map<String, dynamic>;
        // ═══ 完整打印声通评分返回 JSON（用于了解数据结构、设计评分 UI）═══
        debugPrint('🎤 [EvaluationApi] 声通评分返回完整JSON: ${const JsonEncoder.withIndent('  ').convert(result)}');
        return result;
      }
      if (data?['error'] == 'insufficient_balance') {
        throw Exception('余额不足，本次评级需要 ¥${data!['required_cny']}');
      }
      // 打印服务端返回的错误详情，避免日志被吞
      debugPrint('EvaluationApi.scorePronunciation 服务端返回错误: '
          'error=${data?['error']}, message=${data?['message']}, raw=$data');
      return null;
    } catch (e) {
      print('EvaluationApi.scorePronunciation error: $e');
      rethrow;
    }
  }

  // ─── 千问判分 ───

  /// 千问判断翻译是否正确
  /// 返回 { score: 0-100, is_correct: bool, feedback: string }
  static Future<Map<String, dynamic>?> judgeTranslation({
    required String userText,
    required String refText,
    required String targetLanguage,
  }) async {
    try {
      final client = Supabase.instance.client;
      final resp = await client.functions.invoke(
        _functionName,
        body: {
          'rule_code': 'ai_chat',
          'scene': 'test_judge',
          'entry': 'judge_translation',
          'request_id': _generateRequestId(),
          'params': {
            'prompt': _buildJudgeTranslationPrompt(userText, refText, targetLanguage),
            'temperature': 0.3,
            'max_tokens': 500,
          },
        },
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data?['ok'] == true && data?['result'] != null) {
        final result = data!['result'] as Map<String, dynamic>;
        final raw = result['raw'] as String? ?? '';
        return _parseJudgeResult(raw);
      }
      return null;
    } catch (e) {
      print('EvaluationApi.judgeTranslation error: $e');
      return {'score': 0, 'is_correct': false, 'feedback': '判分服务异常'};
    }
  }

  /// 千问判断拼写释义是否正确
  static Future<Map<String, dynamic>?> judgeMeaning({
    required String userWord,
    required String targetWord,
  }) async {
    try {
      final client = Supabase.instance.client;
      final resp = await client.functions.invoke(
        _functionName,
        body: {
          'rule_code': 'ai_chat',
          'scene': 'test_judge',
          'entry': 'judge_meaning',
          'request_id': _generateRequestId(),
          'params': {
            'prompt': _buildJudgeMeaningPrompt(userWord, targetWord),
            'temperature': 0.3,
            'max_tokens': 500,
          },
        },
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data?['ok'] == true && data?['result'] != null) {
        final result = data!['result'] as Map<String, dynamic>;
        final raw = result['raw'] as String? ?? '';
        return _parseJudgeResult(raw);
      }
      return null;
    } catch (e) {
      print('EvaluationApi.judgeMeaning error: $e');
      return {'score': 0, 'is_correct': false, 'feedback': '判分服务异常'};
    }
  }

  /// 千问生成 AI 评价报告
  static Future<Map<String, dynamic>?> generateEvaluation({
    required List<Map<String, dynamic>> items,
    required String difficulty,
  }) async {
    try {
      final itemsSummary = items.map((item) {
        return {
          'type': item['question_type'],
          'ref': item['ref_text'],
          'score': item['score'],
          'correct': item['is_correct'],
        };
      }).toList();

      final prompt = _buildEvaluationPrompt(itemsSummary, difficulty);

      final client = Supabase.instance.client;
      final resp = await client.functions.invoke(
        _functionName,
        body: {
          'rule_code': 'ai_chat',
          'scene': 'test_evaluation',
          'entry': 'generate_evaluation',
          'request_id': _generateRequestId(),
          'params': {
            'prompt': prompt,
            'temperature': 0.3,
            'max_tokens': 2000,
          },
        },
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data?['ok'] == true && data?['result'] != null) {
        final result = data!['result'] as Map<String, dynamic>;
        final raw = result['raw'] as String? ?? '';
        return _parseEvaluationResult(raw);
      }
      return null;
    } catch (e) {
      print('EvaluationApi.generateEvaluation error: $e');
      return null;
    }
  }

  // ─── 内部辅助 ───

  static String _generateRequestId() {
    return 'eval_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  static String _buildJudgeTranslationPrompt(
      String userText, String refText, String targetLanguage) {
    return '''你是一个英语学习评分助手。请判断用户的翻译是否正确。

原文：$refText
用户翻译：$userText
目标语言：$targetLanguage

请按以下 JSON 格式返回评分结果（只返回 JSON，不要任何解释）：
{"score": 0-100的整数分数, "is_correct": true或false, "feedback": "简短反馈，指出对错原因"}''';
  }

  static String _buildJudgeMeaningPrompt(String userWord, String targetWord) {
    return '''你是一个英语学习评分助手。请判断用户的拼写是否正确。

目标单词：$targetWord
用户输入：$userWord

请按以下 JSON 格式返回评分结果（只返回 JSON，不要任何解释）：
{"score": 0-100的整数分数, "is_correct": true或false, "feedback": "简短反馈"}''';
  }

  static String _buildEvaluationPrompt(
      List<Map<String, dynamic>> items, String difficulty) {
    return '''你是一个英语学习 AI 评测师。请根据以下评测结果生成学习评价报告。

难度：$difficulty
答题详情：
${jsonEncode(items)}

请按以下 JSON 格式返回评价报告（只返回 JSON）：
{
  "overall_score": 0-100的整数,
  "category_scores": {"听": 0-100, "说": 0-100, "读": 0-100, "写": 0-100},
  "weak_points": "薄弱环节分析，2-3句话",
  "suggestions": "训练建议，3-5条具体建议",
  "encouragement": "一句鼓励的话"
}''';
  }

  static Map<String, dynamic> _parseJudgeResult(String raw) {
    try {
      final cleaned = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      return {'score': 50, 'is_correct': false, 'feedback': raw};
    }
  }

  static Map<String, dynamic> _parseEvaluationResult(String raw) {
    try {
      final cleaned = raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (_) {
      return {
        'overall_score': 60,
        'category_scores': {'听': 60, '说': 60, '读': 60, '写': 60},
        'weak_points': '评价生成失败',
        'suggestions': '请重新评测',
        'encouragement': '继续加油！',
      };
    }
  }
}
