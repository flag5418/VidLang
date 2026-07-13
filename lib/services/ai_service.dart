import 'dart:developer' as dev;

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/services/auth_service.dart';

/// 统一调用 ai-proxy Edge Function
///
/// **严格按订阅模式分流，无 fallback、无保底、无降级**：
/// - 免费模式（仅 iOS）：调用方应使用 IosNativeFeatures / UnifiedTranslationService / LocalTtsService
/// - 收费模式（iOS + Android）：走此服务调用云端 AI（DeepSeek / 阿里云 TTS / 声通评测）
///
/// 后端统一返回格式：
/// ```json
/// {
///   "ok": true,
///   "rule_code": "ai_translate",
///   "cost_cny": 0.01,
///   "balance_after": 9.99,
///   "result": { ... }  // 统一为 Map 结构
/// }
/// ```
class AiService {
  static const _functionName = 'ai-proxy';
  static const _uuid = Uuid();

  /// 缓存版本号 — 当 Edge Function prompt 更新时，递增此版本使旧缓存失效
  static const _cacheVersion = 2;

  // ─── 核心调用 ─────────────────────────────────

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
      dev.log('🚀 callAiProxy START: word="$word" ruleCode="$ruleCode" scene="$scene" entry="$entry" requestId=$requestId',
          name: 'AiService');

      AuthService.instance.ensureActiveSession();

      final client = sb.Supabase.instance.client;
      final response = await client.functions.invoke(
        _functionName,
        body: {
          'rule_code': ruleCode,
          'scene': scene,
          'entry': entry,
          'request_id': requestId,
          'params': {
            ...params,
            if (billing?.isNotEmpty ?? false) 'billing': billing,
          },
          if ((sourceType ?? '') != '') 'source_type': sourceType,
          if ((sourceCode ?? '') != '') 'source_code': sourceCode,
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        dev.log('❌ callAiProxy INVALID_RESPONSE: type=${data.runtimeType}',
            name: 'AiService');
        return WordDetail.error(word, 'AI 服务响应异常');
      }

      final ok = data['ok'] as bool? ?? false;
      if (!ok) {
        final error = data['error'] as String? ?? '';
        final message = data['message'] as String? ?? '';
        dev.log('⚠️ callAiProxy FAIL: error="$error" message="$message"',
            name: 'AiService');

        if (error == 'insufficient_balance') {
          dev.log('💰 callAiProxy INSUFFICIENT_BALANCE: $message',
              name: 'AiService');
          return WordDetail.error(
            word,
            message,
            isInsufficientBalance: true,
            requiredCny: (data['required_cny'] as num?)?.toDouble(),
            balanceCny: (data['balance_cny'] as num?)?.toDouble(),
          );
        }
        return WordDetail.error(word, message.isNotEmpty ? message : 'AI 服务调用失败');
      }

      final result = data['result'];
      if (result is! Map<String, dynamic>) {
        dev.log('❌ callAiProxy BAD_RESULT: type=${result.runtimeType} raw=$result',
            name: 'AiService');
        return WordDetail.error(word, 'AI 服务返回数据格式错误');
      }

      dev.log('✅ callAiProxy SUCCESS: word="$word" ruleCode="$ruleCode" costCny=${data['cost_cny']}',
          name: 'AiService');

      return WordDetail.fromAiResult(
        result,
        costCny: (data['cost_cny'] as num?)?.toDouble(),
        balanceAfter: (data['balance_after'] as num?)?.toDouble(),
      );
    } catch (e, st) {
      dev.log('💥 callAiProxy EXCEPTION: word="$word" error=$e\n$st',
          name: 'AiService');
      return WordDetail.error(word, 'Edge Function 调用失败: $e');
    }
  }

  /// 调用 AI 接口并返回原始 JSON（用于文章翻译等不转 WordDetail 的场景）
  ///
  /// 成功返回 `{'ok': true, 'result': {...}, 'cost_cny': ..., 'balance_after': ...}`
  /// 失败返回 `{'ok': false, 'error': ..., 'message': ...}`
  static Future<Map<String, dynamic>> callAiProxyRaw({
    required String ruleCode,
    required String scene,
    required String entry,
    Map<String, dynamic> params = const {},
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
          'rule_code': ruleCode,
          'scene': scene,
          'entry': entry,
          'request_id': requestId,
          'params': {
            ...params,
            if (billing?.isNotEmpty ?? false) 'billing': billing,
          },
          if ((sourceType ?? '') != '') 'source_type': sourceType,
          if ((sourceCode ?? '') != '') 'source_code': sourceCode,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return {'ok': false, 'error': 'invalid_response', 'message': 'AI 服务响应格式异常'};
    } catch (e) {
      return {
        'ok': false,
        'error': 'invoke_failed',
        'message': 'Edge Function 调用失败: $e',
      };
    }
  }

  // ─── 业务方法 ─────────────────────────────────

  /// 调用 AI 释义（ai_definition）
  ///
  /// **三级缓存策略**：
  /// 1. **完全命中**：缓存中有完整数据（含 context_sentence_info）→ 直接返回
  /// 2. **部分命中**：缓存有基础释义，但缺少当前句信息 → 仅补充 context_sentence_info
  /// 3. **未命中**：调用 AI 获取完整释义 → 写入缓存
  ///
  /// [word] 目标单词
  /// [contextSentence] 字幕完整句子（可选，有则结合语境）
  /// [sourceType] 资源类型（video/article/music/wordbook），用于动态设置 scene
  /// [sourceCode] 资源编码
  /// [billing] 付费参数
  ///
  /// 注意：此方法仅适用于收费模式。免费模式请使用 IosNativeFeatures.translate() 或 UnifiedTranslationService。
  static Future<WordDetail> getDefinition({
    required String word,
    String? contextSentence,
    String? sourceType,
    String? sourceCode,
    Map<String, dynamic>? billing,
  }) async {
    final cacheKey = word.toLowerCase().trim();
    final hasContext = contextSentence?.isNotEmpty ?? false;

    // ════════════════════════════════════════════
    // ① 查询缓存（无上下文时直接返回）
    // ════════════════════════════════════════════
    if (!hasContext) {
      try {
        final cached = await _readWordCache(cacheKey);
        if (cached != null) {
          dev.log('word cache HIT (no-context): $cacheKey', name: 'AiService');
          _bumpWordCacheCount(cacheKey);
          return cached;
        }
      } catch (e) {
        dev.log('word cache read error: $e', name: 'AiService');
      }
    }

    // ════════════════════════════════════════════
    // ② 有上下文时的智能缓存策略
    // ════════════════════════════════════════════
    if (hasContext) {
      try {
        final cached = await _readWordCache(cacheKey);
        if (cached != null) {
          // 检查是否已有该句子的 context_sentence_info
          final hasContextInfo = _hasContextForSentence(cached, contextSentence!);

          if (hasContextInfo) {
            // ✅ 完全命中：直接返回
            dev.log('word cache HIT (with-context): $cacheKey', name: 'AiService');
            _bumpWordCacheCount(cacheKey);
            return cached;
          } else {
            // ⚡ 部分命中：仅补充 context_sentence_info
            dev.log('word cache PARTIAL HIT: $cacheKey (need context info)', name: 'AiService');
            final enriched = await _enrichWithContext(cached, contextSentence, billing: billing, sourceType: sourceType);
            if (enriched != null) {
              // 异步更新缓存（不阻塞返回）
              _writeWordCache(cacheKey, enriched);
              return enriched;
            }
            // 补充失败，返回基础缓存
            _bumpWordCacheCount(cacheKey);
            return cached;
          }
        }
      } catch (e) {
        dev.log('word cache context check error: $e', name: 'AiService');
      }
    }

    // ════════════════════════════════════════════
    // ③ 完全未命中：调用 AI（收费模式专用）
    // ════════════════════════════════════════════
    dev.log('word cache MISS: $cacheKey, calling AI', name: 'AiService');
    // 根据 sourceType 动态设置 scene（符合 billing-redesign §4.3.1）
    final defScene = _resolveScene(sourceType);

    final detail = await callAiProxy(
      ruleCode: 'ai_definition',
      scene: defScene,
      entry: 'subtitle_tap',
      word: word,
      sourceType: sourceType,
      sourceCode: sourceCode,
      params: {
        'word': word,
        if (hasContext) 'sentence': contextSentence,
      },
      billing: billing,
    );

    // 成功时写入缓存
    if (detail.success && detail.source == 'ai') {
      try {
        await _writeWordCache(cacheKey, detail);
      } catch (e) {
        dev.log('word cache write error: $e', name: 'AiService');
      }
    }

    return detail;
  }

  /// 检查缓存数据是否已包含指定句子的上下文信息
  static bool _hasContextForSentence(WordDetail detail, String sentence) {
    // 如果原句匹配，说明已有上下文信息
    if (detail.contextSentence != null &&
        detail.contextSentence!.contains(sentence.substring(0, sentence.length.clamp(0, 20)))) {
      return true;
    }
    // 或者检查 sentenceTranslation 是否非空（说明之前查询过带上下文的）
    return detail.sentenceTranslation != null && detail.sentenceTranslation!.isNotEmpty;
  }

  /// 为已有的 WordDetail 补充 context_sentence_info
  ///
  /// 复用缓存的 base 信息，仅请求 AI 生成当前句的高亮和翻译。
  /// 这样可以节省约 60% 的 token 消耗。
  static Future<WordDetail?> _enrichWithContext(
    WordDetail baseDetail,
    String contextSentence, {
    Map<String, dynamic>? billing,
    String? sourceType,
  }) async {
    try {
      // 调用 AI 仅获取 context_sentence_info
      // enrich 复用相同的 scene 策略
      final result = await callAiProxyRaw(
        ruleCode: 'ai_definition',
        scene: _resolveScene(sourceType),
        entry: 'subtitle_tap_enrich',
        params: {
          'word': baseDetail.word,
          'sentence': contextSentence,
          'mode': 'context_only', // 告诉 Edge Function 只需要上下文信息
        },
        billing: billing,
      );

      if (result['ok'] != true || result['result'] == null) {
        return null;
      }

      final aiResult = result['result'] as Map<String, dynamic>;
      final contextInfo = aiResult['context_sentence_info'];

      if (contextInfo is! Map<String, dynamic>) {
        return null;
      }

      // 合并到基础 WordDetail
      return WordDetail(
        word: baseDetail.word,
        pronounce: baseDetail.pronounce,
        definitions: baseDetail.definitions,
        standaloneExamples: baseDetail.standaloneExamples,
        difficulty: baseDetail.difficulty,
        morphology: baseDetail.morphology,
        mnemonic: baseDetail.mnemonic,
        // 使用新的上下文信息
        contextSentence: contextInfo['word_highlighted_sentence'] as String? ??
            contextInfo['original_sentence'] as String? ??
            contextSentence,
        sentenceTranslation: contextInfo['sentence_translation'] as String?,
        wordMeaningInContext: contextInfo['word_meaning_in_context'] as String?,
        translation: baseDetail.translation,
        success: true,
        costCny: (result['cost_cny'] as num?)?.toDouble(),
        balanceAfter: (result['balance_after'] as num?)?.toDouble(),
        source: 'ai_enriched', // 标记来源为"AI增强"
      );
    } catch (e) {
      dev.log('_enrichWithContext error: $e', name: 'AiService');
      return null;
    }
  }

  // ─── Word Cache 辅助方法 ─────────────────────────────

  /// 从 word_cache 表读取缓存，返回 WordDetail；未命中或版本过期返回 null
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

    // 检查缓存版本 — 如果版本不匹配，说明 prompt 已更新，缓存失效
    final cachedVersion = result['cache_version'] as int? ?? 1;
    if (cachedVersion < _cacheVersion) {
      dev.log('word cache VERSION_MISMATCH: $key (cached=$cachedVersion, current=$_cacheVersion)', name: 'AiService');
      return null;
    }

    return WordDetail.fromJson(result);
  }

  /// 将 WordDetail 写入 word_cache 表（UPSERT，重复单词更新 result）
  static Future<void> _writeWordCache(String key, WordDetail detail) async {
    final client = sb.Supabase.instance.client;
    final json = detail.toJson();
    // 写入缓存版本号
    json['cache_version'] = _cacheVersion;
    await client.from('word_cache').upsert(
      {
        'word': key,
        'result': json,
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
  ///
  /// 新版后端返回结构化 Map：
  /// { translation, phrase_explanations?, part_of_speech?, word_forms? }
  ///
  /// 注意：此方法仅适用于收费模式。免费模式请使用 IosNativeFeatures.translate() 或 UnifiedTranslationService。
  static Future<WordDetail> translateText({
    required String text,
    String sourceLanguage = 'en',
    String targetLanguage = 'zh-Hans',
    String? sourceType,
    String? sourceCode,
    Map<String, dynamic>? billing,
  }) async {
    // 根据 sourceType 动态设置 scene
    final transScene = _resolveScene(sourceType);

    final result = await callAiProxy(
      ruleCode: 'ai_translate',
      scene: transScene,
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
    return result;
  }

  /// 翻译对话中的英文回复为中文
  ///
  /// 注意：此方法仅适用于收费模式。
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
          'params': {
            'text': text,
            if (billing?.isNotEmpty ?? false) 'billing': billing,
          },
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      final ok = data['ok'] as bool? ?? false;
      if (!ok) return null;

      final result = data['result'];
      // 新版后端返回 Map: { translation: "..." }
      if (result is Map<String, dynamic>) {
        return result['translation'] as String?;
      }
      // 兼容旧版直接返回 String
      if (result is String) {
        return result;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 调用 AI TTS（ai_tts）
  ///
  /// 注意：此方法仅适用于收费模式。免费模式请使用 LocalTtsService 或 UnifiedTtsService。
  static Future<Map<String, dynamic>?> getTtsAudio({
    required String text,
    String language = 'en-US',
    String? sourceType,
    String? sourceCode,
    Map<String, dynamic>? billing,
  }) async {
    // 根据 sourceType 动态设置 scene
    final ttsScene = _resolveScene(sourceType);

    final requestId = _uuid.v4();
    try {
      AuthService.instance.ensureActiveSession();
      final client = sb.Supabase.instance.client;
      final response = await client.functions.invoke(
        _functionName,
        body: {
          'rule_code': 'ai_tts',
          'scene': ttsScene,
          'entry': 'tts_btn',
          'request_id': requestId,
          'params': {
            'text': text,
            'language': language,
            if (billing?.isNotEmpty ?? false) 'billing': billing,
          },
          if ((sourceType ?? '') != '') 'source_type': sourceType,
          if ((sourceCode ?? '') != '') 'source_code': sourceCode,
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

  // ─── Scene 动态化辅助方法 ─────────────────────────────

  /// 根据 sourceType 解析对应的 scene 值
  ///
  /// 符合 billing-redesign §4.3.1 设计：
  /// - article → 'reader'（文章阅读器）
  /// - video   → 'player'（视频播放器）
  /// - music   → 'player'（音频播放器，复用 player）
  /// - wordbook → 'wordbook'（生词本）
  /// - 其他/默认 → 'player'
  static String _resolveScene(String? sourceType) {
    switch (sourceType) {
      case 'article':
        return 'reader';
      case 'video':
      case 'music':
        return 'player';
      case 'wordbook':
        return 'wordbook';
      default:
        return 'player';
    }
  }
}
