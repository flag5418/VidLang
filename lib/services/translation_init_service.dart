import 'dart:convert';
import 'dart:developer' as dev;

import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/ios_native_features.dart';
import 'package:vidlang/services/translation_service.dart';

/// 翻译来源枚举
enum TranslateSource {
  none(-1),   // 无翻译
  native(0),  // 原生翻译（免费模式）
  ai(1);      // AI翻译（付费模式）

  final int value;
  const TranslateSource(this.value);

  static TranslateSource fromInt(int? value) {
    return TranslateSource.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TranslateSource.none,
    );
  }
}

/// 翻译初始化服务
///
/// 负责在打开视频/音频/文章时检查翻译状态，并根据订阅模式自动翻译。
class TranslationInitService {
  /// 统计需要翻译的句子数量
  static int countNeedTranslate<T>(List<T> items, bool isPremium) {
    int count = 0;
    final targetSource = isPremium ? TranslateSource.ai : TranslateSource.native;
    for (final item in items) {
      String? translate;
      int? source;
      if (item is Subtitles) {
        translate = item.contentTranslate;
        source = item.translateSource;
      } else if (item is ArticleSentence) {
        translate = item.contentTranslate;
        source = item.translateSource;
      }
      final hasContent = (translate ?? '').trim().isNotEmpty;
      final hasCorrectSource = source == targetSource.value;
      if (!hasContent || !hasCorrectSource) count++;
    }
    return count;
  }

  /// 翻译视频/音频字幕
  static Future<bool> translateSubtitles({
    required List<Subtitles> subtitles,
    required String videoCode,
    required String title,
    required bool isNative,
    required void Function(int current, int total) onProgress,
  }) async {
    if (subtitles.isEmpty) return true;
    if (isNative) {
      return await _translateSubtitlesNative(subtitles, onProgress);
    } else {
      return await _translateSubtitlesAI(subtitles, videoCode, title, onProgress);
    }
  }

  /// 翻译文章句子
  static Future<bool> translateArticleSentences({
    required List<ArticleSentence> sentences,
    required String articleCode,
    required String title,
    required bool isNative,
    required void Function(int current, int total) onProgress,
  }) async {
    if (sentences.isEmpty) return true;
    if (isNative) {
      return await _translateArticleSentencesNative(sentences, onProgress);
    } else {
      return await TranslationService.translateArticle(
        articleCode: articleCode,
        article: _dummyArticle(title),
        chapters: [],
        paragraphs: [],
        sentences: sentences,
      ) != null;
    }
  }

  /// 使用 iOS 原生翻译逐句翻译字幕
  static Future<bool> _translateSubtitlesNative(
    List<Subtitles> subtitles,
    void Function(int current, int total) onProgress,
  ) async {
    int success = 0;
    bool versionTooLow = false;
    for (int i = 0; i < subtitles.length; i++) {
      final sub = subtitles[i];
      try {
        final result = await IosNativeFeatures.translate(
          text: sub.content,
          sourceLanguage: 'en',
          targetLanguage: 'zh-Hans',
        );
        if (result.success && result.translatedText.isNotEmpty) {
          sub.contentTranslate = result.translatedText;
          sub.translateSource = TranslateSource.native.value;
          success++;
        } else if (result.error != null &&
            (result.error!.contains('iOS 26+') || result.error!.toLowerCase().contains('required for native translation'))) {
          // iOS 版本过低，标记并跳出循环
          versionTooLow = true;
          dev.log('iOS version too low for native translation: ${result.error}', name: 'TranslationInitService');
          break;
        }
      } catch (e) {
        dev.log('Native translation failed for subtitle ${i}: $e', name: 'TranslationInitService');
      }
      onProgress(i + 1, subtitles.length);
    }

    if (versionTooLow) {
      // iOS 版本过低，返回 false 让上层提示用户使用 AI 翻译
      return false;
    }

    if (success > 0) {
      try {
        final updatedCount = await DatabaseService.batchUpdate(subtitles);
        if (updatedCount == 0) {
          dev.log('batchUpdate returned 0, database may be corrupted', name: 'TranslationInitService');
          // 数据库可能已损坏，但翻译已成功应用到内存对象
          // 返回 true 让播放器继续显示翻译（内存中已更新）
          return true;
        }
      } catch (e) {
        dev.log('batchUpdate failed: $e', name: 'TranslationInitService');
        // 数据库更新失败，但翻译已成功应用到内存对象
        // 返回 true 让播放器继续显示翻译（内存中已更新）
        return true;
      }
    }

    dev.log('Native translation completed: $success/${subtitles.length} succeeded', name: 'TranslationInitService');
    return success > 0;
  }

  /// 使用 AI 批量翻译字幕（整篇理解后逐句翻译）
  static Future<bool> _translateSubtitlesAI(
    List<Subtitles> subtitles,
    String videoCode,
    String title,
    void Function(int current, int total) onProgress,
  ) async {
    if (subtitles.isEmpty) return false;

    try {
      final result = await _callAiTranslateSubtitles(subtitles, videoCode, title);
      if (result == null) return false;

      final sentList = result['sentences'] as List<dynamic>?;
      if (sentList == null) return false;

      final map = <int, String>{};
      for (final item in sentList) {
        if (item is Map<String, dynamic>) {
          final idx = item['sentence_index'] as int?;
          final zh = item['zh'] as String?;
          if (idx != null && zh != null && zh.trim().isNotEmpty) {
            map[idx] = zh.trim();
          }
        }
      }

      int success = 0;
      for (int i = 0; i < subtitles.length; i++) {
        final sub = subtitles[i];
        final translation = map[i];
        if (translation != null) {
          sub.contentTranslate = translation;
          sub.translateSource = TranslateSource.ai.value;
          success++;
        }
        onProgress(i + 1, subtitles.length);
      }

      if (success > 0) {
        await DatabaseService.batchUpdate(subtitles);
      }

      dev.log('AI translation completed: $success/${subtitles.length} succeeded', name: 'TranslationInitService');
      return success > 0;
    } catch (e) {
      dev.log('AI translation failed: $e', name: 'TranslationInitService');
      return false;
    }
  }

  /// 调用 AI 翻译接口（整篇理解后逐句翻译）
  static Future<Map<String, dynamic>?> _callAiTranslateSubtitles(
    List<Subtitles> subtitles,
    String videoCode,
    String title,
  ) async {
    final buf = StringBuffer();
    buf.writeln('你是专业的英文学习翻译助手。请对下面的英文做"逐句翻译"，每句翻译需要结合上下文，保证指代、时态和语气自然。');
    buf.writeln('输出必须是严格 JSON，禁止输出除 JSON 以外的任何内容。');
    buf.writeln('JSON 格式：{"sentences":[{"sentence_index":0,"zh":"..."}]}');
    buf.writeln('规则：');
    buf.writeln('1) sentences 数组长度必须与输入句子数一致，不得漏句/增句');
    buf.writeln('2) zh 为中文译文，不要加序号，不要换行编号');
    buf.writeln();
    buf.writeln('标题：$title');
    buf.writeln();
    buf.writeln('输入句子列表：');
    for (int i = 0; i < subtitles.length; i++) {
      final sub = subtitles[i];
      buf.writeln('[$i] ${sub.content}');
    }

    final resp = await AiService.callAiProxyRaw(
      ruleCode: 'ai_translate_article',
      scene: 'player',
      entry: 'translate_subtitles',
      params: {
        'prompt': buf.toString(),
        'model': 'qwen',
        'temperature': 0.2,
        'max_tokens': 8192,
      },
      sourceType: 'video',
      sourceCode: videoCode,
    );

    final ok = resp['ok'] as bool? ?? false;
    if (!ok) return null;

    final result = resp['result'];
    if (result is Map<String, dynamic>) {
      return (result['raw'] as String?)?.trim() != null
          ? jsonDecode((result['raw'] as String).trim())
          : null;
    }
    if (result is String) {
      final decoded = jsonDecode(result.trim());
      return decoded is Map<String, dynamic> ? decoded : null;
    }
    return null;
  }

  /// 使用 iOS 原生翻译逐句翻译文章句子
  static Future<bool> _translateArticleSentencesNative(
    List<ArticleSentence> sentences,
    void Function(int current, int total) onProgress,
  ) async {
    int success = 0;
    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      try {
        final result = await IosNativeFeatures.translate(
          text: sentence.content,
          sourceLanguage: 'en',
          targetLanguage: 'zh-Hans',
        );
        if (result.success && result.translatedText.isNotEmpty) {
          sentence.contentTranslate = result.translatedText;
          sentence.translateSource = TranslateSource.native.value;
          success++;
        }
      } catch (e) {
        dev.log('Native translation failed for article sentence ${i}: $e', name: 'TranslationInitService');
      }
      onProgress(i + 1, sentences.length);
    }

    if (success > 0) {
      await DatabaseService.batchUpdate(sentences);
    }

    dev.log('Native article translation completed: $success/${sentences.length} succeeded', name: 'TranslationInitService');
    return success > 0;
  }

  /// 创建一个虚拟 Article 对象用于翻译
  static dynamic _dummyArticle(String title) {
    return {'title': title};
  }
}
