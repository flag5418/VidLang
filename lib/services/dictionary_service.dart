import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/ios_native_features.dart';

/// 统一词典查询服务
///
/// **严格按订阅模式分流（无 fallback、无保底）**：
/// - 免费模式（仅 iOS）：iOS 原生系统翻译（MLTranslation，需 iOS 17.4+）
/// - 收费模式（iOS + Android）：AiService.getDefinition（ai-proxy Edge Function → DeepSeek）
///
/// 注意：本地模型（MarianMT / LocalAiService）已移除，stardict.db 离线词典已废弃。
class DictionaryService {
  DictionaryService._();
  static final DictionaryService _instance = DictionaryService._();
  factory DictionaryService() => _instance;

  /// 查询单词释义（按免费/收费模式走统一服务）
  ///
  /// [word] 目标单词
  /// [mode] 订阅模式（免费/收费）
  /// [contextSentence] 上下文句子（可选，收费模式下传给 AI）
  /// [sourceType] 资源类型（video/article/music/wordbook）
  /// [sourceCode] 资源编码
  Future<WordDetail> lookup(
    String word, {
    required SubscriptionMode mode,
    String? contextSentence,
    String? sourceType,
    String? sourceCode,
  }) async {
    if (mode == SubscriptionMode.premium) {
      // 收费模式：走 AI 释义（带三级缓存）
      return await AiService.getDefinition(
        word: word,
        contextSentence: contextSentence,
        sourceType: sourceType,
        sourceCode: sourceCode,
      );
    } else {
      // 免费模式：iOS 原生翻译 + 本地 MarianMT 并行
      return await _lookupFree(word: word);
    }
  }

  /// 免费模式查词：iOS 原生系统翻译（MLTranslation，需 iOS 17.4+）
  /// 注意：Android 不支持免费模式，此方法仅在 iOS 免费模式下调用
  Future<WordDetail> _lookupFree({required String word}) async {
    try {
      final result = await IosNativeFeatures.translate(text: word);

      String? translation;
      if (result.success &&
          result.translatedText.isNotEmpty &&
          result.translatedText != word) {
        translation = result.translatedText;
      }

      return WordDetail(
        word: word,
        translation: translation,
        success: translation != null && translation.isNotEmpty,
        source: 'ios_translate',
      );
    } catch (e) {
      return WordDetail.error(word, '查询失败: $e');
    }
  }

  /// 批量查询多个单词
  Future<List<WordDetail>> lookupAll(
    List<String> words, {
    required SubscriptionMode mode,
    String? sourceType,
    String? sourceCode,
  }) async {
    final results = <WordDetail>[];
    for (final w in words) {
      try {
        final detail = await lookup(
          w,
          mode: mode,
          sourceType: sourceType,
          sourceCode: sourceCode,
        );
        results.add(detail);
      } catch (e) {
        results.add(WordDetail.error(w, '查询失败: $e'));
      }
    }
    return results;
  }
}
