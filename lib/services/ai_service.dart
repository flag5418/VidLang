import 'dart:developer' as dev;

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/services/auth_service.dart';

/// 统一调用 ai-proxy Edge Function
class AiService {
  static const _functionName = 'ai-proxy';
  static const _uuid = Uuid();

  /// 调用 AI 接口并返回 WordDetail
  /// - 成功：返回 WordDetail（含释义/翻译/音标）
  /// - 余额不足：返回 WordDetail.error(isInsufficientBalance: true)
  /// - 其他错误：返回 WordDetail.error
  static Future<WordDetail> callAiProxy({
    required String ruleCode,
    required String scene,
    required String entry,
    required String word,
    String? sourceType,
    String? sourceCode,
    Map<String, dynamic> params = const {},
    Map<String, dynamic>? billing,
  }) async {
    final requestId = _uuid.v4();

    try {
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
          if (sourceType != null) 'source_type': sourceType,
          if (sourceCode != null) 'source_code': sourceCode,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return WordDetail.error(word, 'AI 服务响应异常');
      }

      final ok = data['ok'] as bool? ?? false;
      if (!ok) {
        final error = data['error'] as String? ?? '';
        if (error == 'insufficient_balance') {
          return WordDetail.error(
            word,
            data['message'] as String? ?? '余额不足',
            isInsufficientBalance: true,
            requiredCny: (data['required_cny'] as num?)?.toDouble(),
            balanceCny: (data['balance_cny'] as num?)?.toDouble(),
          );
        }
        return WordDetail.error(word, data['message'] as String? ?? 'AI 服务调用失败');
      }

      final result = data['result'];
      if (result is! Map<String, dynamic>) {
        return WordDetail.error(word, 'AI 服务返回数据格式错误');
      }

      return WordDetail.fromAiResult(
        result,
        costCny: (data['cost_cny'] as num?)?.toDouble(),
        balanceAfter: (data['balance_after'] as num?)?.toDouble(),
      );
    } catch (e) {
      return WordDetail.error(word, 'Edge Function 调用失败: $e');
    }
  }

  /// 调用 AI 释义（ai_definition）
  ///
  /// 优先查询全局缓存（word_cache 表），命中则直接返回，
  /// 未命中才调用 AI，并将结果写入缓存。
  ///
  /// [word] 目标单词
  /// [contextSentence] 字幕完整句子（可选，有则结合语境）
  /// [billing] 付费参数
  static Future<WordDetail> getDefinition({
    required String word,
    String? contextSentence,
    String? sourceType,
    String? sourceCode,
    Map<String, dynamic>? billing,
  }) async {
    final cacheKey = word.toLowerCase().trim();

    // ① 先查缓存
    try {
      final cached = await _readWordCache(cacheKey);
      if (cached != null) {
        dev.log('word cache HIT: $cacheKey', name: 'AiService');
        // 异步递增命中次数，不阻塞返回
        _bumpWordCacheCount(cacheKey);
        return cached;
      }
    } catch (e) {
      dev.log('word cache read error: $e', name: 'AiService');
    }

    // ② 未命中，调 AI
    dev.log('word cache MISS: $cacheKey, calling AI', name: 'AiService');
    final detail = await callAiProxy(
      ruleCode: 'ai_definition',
      scene: 'player',
      entry: 'subtitle_tap',
      word: word,
      sourceType: sourceType,
      sourceCode: sourceCode,
      params: {
        'word': word,
        if (contextSentence?.isNotEmpty ?? false) 'context_sentence': contextSentence,
      },
      billing: billing,
    );

    // ③ 成功时写入缓存
    if (detail.success && detail.source == 'ai') {
      try {
        await _writeWordCache(cacheKey, detail);
      } catch (e) {
        dev.log('word cache write error: $e', name: 'AiService');
      }
    }

    return detail;
  }

  // ─── Word Cache 辅助方法 ─────────────────────────────

  /// 从 word_cache 表读取缓存，返回 WordDetail；未命中返回 null
  static Future<WordDetail?> _readWordCache(String key) async {
    final client = sb.Supabase.instance.client;
    final rows = await client
        .from('word_cache')
        .select('result')
        .eq('word', key)
        .limit(1);

    if (rows.isEmpty) return null;
    final result = rows.first['result'];
    if (result is! Map<String, dynamic> || result.isEmpty) return null;

    return WordDetail.fromJson(result);
  }

  /// 将 WordDetail 写入 word_cache 表（UPSERT，重复单词更新 result）
  static Future<void> _writeWordCache(String key, WordDetail detail) async {
    final client = sb.Supabase.instance.client;
    await client.from('word_cache').upsert(
      {
        'word': key,
        'result': detail.toJson(),
      },
      onConflict: 'word',
    );
  }

  /// 异步递增 query_count，失败不抛异常
  /// 注：supabase_flutter Dart SDK 不支持 SQL 表达式（query_count + 1），
  /// 通过 RPC 实现，若函数不存在则静默忽略。
  static void _bumpWordCacheCount(String key) {
    sb.Supabase.instance.client
        .rpc('bump_word_cache_count', params: {'p_word': key})
        .then((_) {}, onError: (_) {});
  }

  /// 调用 AI 翻译（ai_translate）
  static Future<WordDetail> translateText({
    required String text,
    String sourceLanguage = 'en',
    String targetLanguage = 'zh-Hans',
    String? sourceType,
    String? sourceCode,
    Map<String, dynamic>? billing,
  }) async {
    final result = await callAiProxy(
      ruleCode: 'ai_translate',
      scene: 'player',
      entry: 'trans_btn',
      word: text,
      sourceType: sourceType,
      sourceCode: sourceCode,
      params: {
        'text': text,
        'source_language': sourceLanguage,
        'target_language': targetLanguage,
      },
      billing: billing,
    );
    // 翻译场景下，将 translation 字段回填
    if (result.success && result.translation != null) {
      return result;
    }
    return result;
  }

  /// 翻译对话中的英文回复为中文
  static Future<String?> translateConversationText({
    required String text,
    Map<String, dynamic>? billing,
  }) async {
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
  static Future<Map<String, dynamic>?> getTtsAudio({
    required String text,
    String language = 'en-US',
    String? sourceType,
    String? sourceCode,
    Map<String, dynamic>? billing,
  }) async {
    final requestId = _uuid.v4();
    try {
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
          if (sourceType != null) 'source_type': sourceType,
          if (sourceCode != null) 'source_code': sourceCode,
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
