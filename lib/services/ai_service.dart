import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/word_card_data.dart';
import 'package:vidlang/services/auth_service.dart';

/// 统一调用 ai-proxy Edge Function
class AiService {
  static const _functionName = 'ai-proxy';
  static const _uuid = Uuid();

  /// 调用 AI 接口并返回 WordCardData
  /// - 成功：返回 WordCardData（含释义/翻译/音标）
  /// - 余额不足：返回 WordCardData.error(isInsufficientBalance: true)
  /// - 其他错误：返回 WordCardData.error
  static Future<WordCardData> callAiProxy({
    required String ruleCode,
    required String scene,
    required String entry,
    Map<String, dynamic> params = const {},
    Map<String, dynamic>? billing,
  }) async {
    final requestId = _uuid.v4();

    try {
      // 排他性登录校验：session 已被其他设备顶替则抛出 SessionHijackedException
      AuthService.instance.ensureActiveSession();

      final client = sb.Supabase.instance.client;
      final response = await client.functions.invoke(
        _functionName,
        body: {
          'rule_code': ruleCode,
          'scene': scene,
          'entry': entry,
          'request_id': requestId,
          'params': {...params, if (billing?.isNotEmpty ?? false) 'billing': billing},
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return WordCardData.error(params['word'] as String? ?? '', 'AI 服务响应异常');
      }

      final ok = data['ok'] as bool? ?? false;
      if (!ok) {
        final error = data['error'] as String? ?? '';
        if (error == 'insufficient_balance') {
          return WordCardData.error(
            params['word'] as String? ?? '',
            data['message'] as String? ?? '余额不足',
            isInsufficientBalance: true,
            requiredCny: (data['required_cny'] as num?)?.toDouble(),
            balanceCny: (data['balance_cny'] as num?)?.toDouble(),
          );
        }
        return WordCardData.error(params['word'] as String? ?? '', data['message'] as String? ?? 'AI 服务调用失败');
      }

      final result = data['result'];
      if (result is! Map<String, dynamic>) {
        return WordCardData.error(params['word'] as String? ?? '', 'AI 服务返回数据格式错误');
      }

      return WordCardData.fromAiResult(
        params['word'] as String? ?? '',
        result,
        costCny: (data['cost_cny'] as num?)?.toDouble(),
        balanceAfter: (data['balance_after'] as num?)?.toDouble(),
      );
    } catch (e) {
      return WordCardData.error(params['word'] as String? ?? '', 'Edge Function 调用失败: $e');
    }
  }

  /// 调用 AI 释义（ai_definition）
  static Future<WordCardData> getDefinition({required String word, String? sentence, Map<String, dynamic>? billing}) async {
    return callAiProxy(
      ruleCode: 'ai_definition',
      scene: 'player',
      entry: 'subtitle_tap',
      params: {'word': word, if (sentence?.isNotEmpty ?? false) 'sentence': sentence},
      billing: billing,
    );
  }

  /// 调用 AI 翻译（ai_translate）
  static Future<WordCardData> translateText({
    required String text,
    String sourceLanguage = 'en',
    String targetLanguage = 'zh-Hans',
    Map<String, dynamic>? billing,
  }) async {
    return callAiProxy(
      ruleCode: 'ai_translate',
      scene: 'player',
      entry: 'trans_btn',
      params: {'text': text, 'source_language': sourceLanguage, 'target_language': targetLanguage},
      billing: billing,
    );
  }

  /// 翻译对话中的英文回复为中文
  /// 走 ai-proxy 的 ai_translate_conversation 路由
  static Future<String?> translateConversationText({required String text, Map<String, dynamic>? billing}) async {
    final requestId = _uuid.v4();
    try {
      AuthService.instance.ensureActiveSession();

      final client = sb.Supabase.instance.client;
      final response = await client.functions.invoke(
        _functionName,
        body: {
          'rule_code': 'ai_translate_conversation',
          'scene': 'conversation',
          'entry': 'translate_reply',
          'request_id': requestId,
          'params': {'text': text, if (billing?.isNotEmpty ?? false) 'billing': billing},
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final ok = data['ok'] as bool? ?? false;
      if (!ok) return null;
      return data['result'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 调用 AI TTS（ai_tts）
  /// 返回音频文件路径或 base64
  static Future<Map<String, dynamic>?> getTtsAudio({required String text, String language = 'en-US', Map<String, dynamic>? billing}) async {
    final requestId = _uuid.v4();
    try {
      // 排他性登录校验
      AuthService.instance.ensureActiveSession();

      final client = sb.Supabase.instance.client;
      final response = await client.functions.invoke(
        _functionName,
        body: {
          'rule_code': 'ai_tts',
          'scene': 'player',
          'entry': 'tts_btn',
          'request_id': requestId,
          'params': {'text': text, 'language': language, if (billing?.isNotEmpty ?? false) 'billing': billing},
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final ok = data['ok'] as bool? ?? false;
      if (!ok) return null;
      return data['result'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }
}
