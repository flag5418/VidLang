import 'dart:async';

import 'package:vidlang/models/word_card_data.dart';
import 'package:vidlang/models/word_detail.dart' as wd;
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/ai/ai_service.dart';
import 'package:vidlang/services/native/ios_native_features.dart';
import 'package:vidlang/services/tts/tts_service.dart';

/// 原生功能封装（免费模式 iOS 使用）
/// 聚合 IosNativeFeatures + TtsService + AiService
/// 
/// **严格按订阅模式分流**：
/// - 免费模式（仅 iOS）：使用 iOS 原生系统翻译（MLTranslation，需 iOS 17.4+）
/// - 收费模式（iOS + Android）：使用 ai-proxy Edge Function（DeepSeek / 阿里云 TTS）
/// 
/// 注意：本地模型（LocalAiService / LocalModelService / MarianMT / Piper TTS）已移除
class NativeService {
  static NativeService? _instance;
  static NativeService get instance => _instance ??= NativeService._();
  NativeService._();

  /// 查单词释义（按免费/收费模式走统一服务）
  /// 
  /// - 收费模式：AiService.getDefinition（ai-proxy Edge Function → DeepSeek）
  /// - 免费模式（仅 iOS）：IosNativeFeatures.translate（MLTranslation）
  static Future<WordCardData> lookupWord(
    String word, {
    required SubscriptionMode mode,
    String? contextSentence,
    String? sourceType,
    String? sourceCode,
  }) async {
    try {
      if (mode == SubscriptionMode.premium) {
        // 收费模式：走 AI 释义
        final detail = await AiService.getDefinition(
          word: word,
          contextSentence: contextSentence,
          sourceType: sourceType,
          sourceCode: sourceCode,
        );
        if (!detail.success) {
          return WordCardData.error(
            word,
            detail.error ?? 'AI 释义失败',
            isInsufficientBalance: detail.isInsufficientBalance,
            requiredCny: detail.costCny,
            balanceCny: detail.balanceAfter,
          );
        }
        return _wordDetailToWordCardData(detail);
      } else {
        // 免费模式：iOS 原生系统翻译（MLTranslation，需 iOS 17.4+）
        final results = await Future.wait([
          IosNativeFeatures.translate(text: word),
          IosNativeFeatures.lookUp(word: word),
        ]);

        final translationResult = results[0] as TranslationResult;

        String? translation;
        if (translationResult.success &&
            translationResult.translatedText.isNotEmpty &&
            translationResult.translatedText != word) {
          translation = translationResult.translatedText;
        }

        return WordCardData.fromNative(
          word: word,
          translation: translation,
        );
      }
    } catch (e) {
      return WordCardData.error(word, '查询失败: $e');
    }
  }

  /// 将 WordDetail 转换为 WordCardData（用于统一 UI 展示）
  static WordCardData _wordDetailToWordCardData(wd.WordDetail detail) {
    return WordCardData(
      word: detail.word,
      phonetic: detail.displayPhonetic,
      partOfSpeech: detail.definitions.isNotEmpty ? detail.definitions.first.partOfSpeech : null,
      definitions: detail.definitions.map((d) {
        return WordDefinition(
          partOfSpeech: d.partOfSpeech,
          meaning: d.chineseMeaning,
          example: d.examples.isNotEmpty ? d.examples.first.english : null,
        );
      }).toList(),
      examples: detail.standaloneExamples.map((e) {
        return WordExample(
          english: e.english,
          chinese: e.chinese,
        );
      }).toList(),
      translation: detail.translation,
      success: true,
      costCny: detail.costCny,
      balanceAfter: detail.balanceAfter,
      source: 'ai',
    );
  }

  /// 翻译句子（按免费/收费模式走统一服务）
  /// 
  /// 免费模式：iOS 原生系统翻译
  /// 收费模式：AiService.translateText（ai-proxy Edge Function）
  static Future<String?> translateSentence(
    String text, {
    required SubscriptionMode mode,
    String? sourceType,
    String? sourceCode,
  }) async {
    try {
      if (mode == SubscriptionMode.premium) {
        final result = await AiService.translateText(
          text: text,
          sourceType: sourceType,
          sourceCode: sourceCode,
        );
        if (result.success) {
          return result.translation ?? '';
        }
        return null;
      } else {
        final result = await IosNativeFeatures.translate(
          text: text,
          sourceLanguage: 'en',
          targetLanguage: 'zh-Hans',
        );
        if (result.success && result.translatedText.isNotEmpty && result.translatedText != text) {
          return result.translatedText;
        }
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// TTS 朗读
  static Future<void> speakWord(String word) async {
    await TtsService().speakWord(word);
  }

  /// TTS 朗读字幕
  static Future<void> speakSubtitle(String text) async {
    await TtsService().speakSubtitle(text);
  }

  /// TTS 清晰朗读
  static Future<void> speakClarity({required String text, FutureOr<void> Function()? onComplete}) async {
    await TtsService().speakClarity(text: text, onComplete: onComplete);
  }
}
