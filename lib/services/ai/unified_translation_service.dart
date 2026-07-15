import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/native/ios_native_features.dart';

/// 统一翻译服务
/// 免费模式 → iOS 系统翻译（MLTranslation，需 iOS 17.4+）
/// 收费模式 → 云端 ai-proxy Edge Function
class UnifiedTranslationService {
  static UnifiedTranslationService? _instance;
  static UnifiedTranslationService get instance =>
      _instance ??= UnifiedTranslationService._();
  UnifiedTranslationService._();

  /// 翻译文本（单词/句子/文章片段）
  Future<WordDetail> translate({
    required String text,
    required SubscriptionMode mode,
    String? contextSentence,
    String? sourceType,
    String? sourceCode,
    Map<String, dynamic>? billing,
  }) async {
    if (mode == SubscriptionMode.free) {
      return await _translateLocal(text: text);
    } else {
      return await _translateCloud(
        text: text,
        contextSentence: contextSentence,
        sourceType: sourceType,
        sourceCode: sourceCode,
        billing: billing,
      );
    }
  }

  /// 批量翻译（字幕行/文章句子）
  Future<List<WordDetail>> translateBatch({
    required List<String> texts,
    required SubscriptionMode mode,
  }) async {
    if (mode == SubscriptionMode.free) {
      final results = <WordDetail>[];
      for (final text in texts) {
        try {
          final result = await _translateLocal(text: text);
          results.add(result);
        } catch (e) {
          debugPrint('批量翻译失败 [$text]: $e');
          results.add(WordDetail.error(text, e.toString()));
        }
      }
      return results;
    } else {
      return await _translateBatchCloud(texts: texts, mode: mode);
    }
  }

  /// 本地翻译（iOS 系统翻译，MLTranslation）
  Future<WordDetail> _translateLocal({required String text}) async {
    try {
      final result = await IosNativeFeatures.translate(text: text);

      if (result.success &&
          result.translatedText.isNotEmpty &&
          result.translatedText != text) {
        return WordDetail(
          word: text,
          translation: result.translatedText,
          source: 'ios_translate',
          success: true,
        );
      }

      // 翻译失败或翻译结果与原文相同
      final errorMsg = result.error ?? '翻译失败';
      debugPrint('iOS 系统翻译失败: $errorMsg');

      // 检查是否需要下载语言包
      final needsLanguagePack =
          errorMsg.contains('not available') ||
          errorMsg.contains('language') ||
          errorMsg.contains('未找到') ||
          errorMsg.contains('下载');

      return WordDetail.error(
        text,
        errorMsg,
        languagePackRequired: needsLanguagePack,
      );
    } catch (e) {
      debugPrint('本地翻译失败: $e');
      return WordDetail.error(text, '本地翻译失败: $e');
    }
  }

  /// 云端翻译（ai-proxy Edge Function）
  Future<WordDetail> _translateCloud({
    required String text,
    String? contextSentence,
    String? sourceType,
    String? sourceCode,
    Map<String, dynamic>? billing,
  }) async {
    try {
      final client = sb.Supabase.instance.client;
      final requestId = const Uuid().v4();

      final response = await client.functions.invoke(
        'ai-proxy',
        body: {
          'rule_code': 'ai_translate',
          'scene': 'player',
          'entry': 'subtitle_tap',
          'request_id': requestId,
          'params': {'text': text, 'target_language': '中文'},
          if (billing?.isNotEmpty ?? false) 'billing': billing,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['ok'] == true) {
        final result = data['result'] as Map<String, dynamic>?;
        if (result != null) {
          return WordDetail.fromAiResult(
            result,
            costCny: (data['cost_cny'] as num?)?.toDouble(),
            balanceAfter: (data['balance_after'] as num?)?.toDouble(),
          );
        }
      }

      final error =
          data['error'] as String? ?? data['message'] as String? ?? '翻译失败';
      if (error == 'insufficient_balance') {
        return WordDetail.error(
          text,
          data['message'] as String? ?? '余额不足',
          isInsufficientBalance: true,
          requiredCny: (data['required_cny'] as num?)?.toDouble(),
          balanceCny: (data['balance_cny'] as num?)?.toDouble(),
        );
      }

      return WordDetail.error(text, error);
    } catch (e) {
      debugPrint('云端翻译失败: $e');
      return WordDetail.error(text, '云端翻译失败: $e');
    }
  }

  /// 批量云端翻译
  Future<List<WordDetail>> _translateBatchCloud({
    required List<String> texts,
    required SubscriptionMode mode,
  }) async {
    final results = <WordDetail>[];
    for (final text in texts) {
      try {
        final detail = await _translateCloud(text: text);
        results.add(detail);
      } catch (e) {
        results.add(WordDetail.error(text, e.toString()));
      }
    }
    return results;
  }
}
