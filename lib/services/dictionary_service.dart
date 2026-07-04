import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/ios_native_features.dart';
import 'package:vidlang/services/local_translation_service.dart';

/// 统一词典查询服务
///
/// 按免费/收费模式分流：
/// - 免费模式：iOS 原生翻译 + 本地 MarianMT 模型
/// - 收费模式：AiService.getDefinition（ai-proxy Edge Function → 阿里 Qwen）
///
/// 废弃了旧的 stardict.db 离线词典，统一走翻译/释义服务体系。
class DictionaryService {
  DictionaryService._();
  static final DictionaryService _instance = DictionaryService._();
  factory DictionaryService() => _instance;

  final LocalTranslationService _localTranslation = LocalTranslationService.instance;

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

  /// 免费模式查词：iOS 原生翻译 + 本地 MarianMT
  Future<WordDetail> _lookupFree({required String word}) async {
    try {
      final results = await Future.wait([
        IosNativeFeatures.translate(text: word),
        _localTranslation.translate(text: word),
      ]);

      final translationResult = results[0] as TranslationResult;
      final localTranslation = results[1] as String;

      String? translation;
      if (translationResult.success &&
          translationResult.translatedText.isNotEmpty &&
          translationResult.translatedText != word) {
        translation = translationResult.translatedText;
      }

      // 本地翻译作为 fallback
      if ((translation == null || translation.isEmpty) &&
          localTranslation != '翻译失败' &&
          localTranslation != '本地翻译模型未就绪，请使用云端翻译' &&
          localTranslation != '翻译模型加载失败' &&
          localTranslation != word) {
        translation = localTranslation;
      }

      return WordDetail(
        word: word,
        translation: translation,
        success: translation != null && translation.isNotEmpty,
        source: 'native',
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
