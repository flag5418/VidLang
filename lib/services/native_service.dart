import 'dart:async';

import 'package:vidlang/models/word_card_data.dart';
import 'package:vidlang/services/dictionary_service.dart';
import 'package:vidlang/services/ios_native_features.dart';
import 'package:vidlang/services/tts_service.dart';

/// 原生翻译/TTS/词典封装（免费模式用）
/// 聚合 IosNativeFeatures + DictionaryService + TtsService
class NativeService {
  /// 查单词释义（原生翻译 + 本地词典并行）
  static Future<WordCardData> lookupWord(String word) async {
    try {
      final results = await Future.wait([
        IosNativeFeatures.translate(text: word),
        DictionaryService().lookup(word),
        IosNativeFeatures.lookUp(word: word),
      ]);

      final translationResult = results[0] as TranslationResult;
      final dictEntry = results[1] as DictEntry?;

      String? translation;
      if (translationResult.success && translationResult.translatedText.isNotEmpty && translationResult.translatedText != word) {
        translation = translationResult.translatedText;
      }

      // 从 DictEntry.translation 解析多行释义
      final definitions = <WordDefinition>[];
      String? partOfSpeech;
      if (dictEntry != null && dictEntry.translation != null && dictEntry.translation!.isNotEmpty) {
        for (final line in dictEntry.translation!.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          // 格式如 "n. 释义" 或 "v. 释义"
          final match = RegExp(r'^([a-z]+\\.)\\s*(.+)\\$').firstMatch(trimmed);
          if (match != null) {
            final pos = match.group(1);
            final meaning = match.group(2)!;
            definitions.add(WordDefinition(partOfSpeech: pos, meaning: meaning));
            partOfSpeech ??= pos;
          } else {
            definitions.add(WordDefinition(meaning: trimmed));
          }
        }
      }

      return WordCardData.fromNative(
        word: word,
        phonetic: dictEntry?.phonetic,
        partOfSpeech: partOfSpeech,
        definitions: definitions,
        translation: translation,
      );
    } catch (e) {
      return WordCardData.error(word, '查询失败: $e');
    }
  }

  /// 翻译句子
  static Future<String?> translateSentence(String text) async {
    try {
      final result = await IosNativeFeatures.translate(text: text, sourceLanguage: 'en', targetLanguage: 'zh-Hans');
      if (result.success && result.translatedText.isNotEmpty && result.translatedText != text) {
        return result.translatedText;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// TTS 朗读
  static Future<bool> speakWord(String word) async {
    return TtsService().speakWord(word);
  }

  /// TTS 朗读字幕
  static Future<bool> speakSubtitle(String text) async {
    return TtsService().speakSubtitle(text);
  }

  /// TTS 清晰朗读
  static Future<void> speakClarity({required String text, FutureOr<void> Function()? onComplete}) async {
    await TtsService().speakClarity(text: text, onComplete: onComplete);
  }
}
