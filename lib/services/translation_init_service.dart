import 'dart:convert';
import 'dart:developer' as dev;

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/unified_translation_service.dart';

/// 翻译来源枚举
enum TranslateSource {
  none(-1), // 无翻译
  native(0), // 原生翻译（已废弃，保留兼容）
  ai(1), // AI翻译（付费模式）
  local(2), // 本地翻译（免费模式，MarianMT）
  cloud(3); // 云端翻译（ai-proxy）

  final int value;
  const TranslateSource(this.value);

  static TranslateSource fromInt(int? value) {
    return TranslateSource.values.firstWhere((e) => e.value == value, orElse: () => TranslateSource.none);
  }
}

/// 翻译初始化服务
///
/// 负责在打开视频/音频/文章时检查翻译状态，并根据订阅模式自动翻译。
class TranslationInitService {
  /// 统计需要翻译的句子数量
  static int countNeedTranslate<T>(List<T> items, SubscriptionMode mode) {
    int count = 0;
    for (final item in items) {
      int? source;
      if (item is Subtitles) {
        source = item.translateSource;
      } else if (item is ArticleSentence) {
        source = item.translateSource;
      }
      // 免费模式：translateSource != 0 表示需要翻译
      // 收费模式：translateSource != 1 表示需要翻译
      final needsTranslate = mode == SubscriptionMode.free
          ? (source == null || source == TranslateSource.none.value || source == TranslateSource.native.value)
          : (source != TranslateSource.ai.value && source != TranslateSource.cloud.value);
      if (needsTranslate) count++;
    }
    return count;
  }

  /// 翻译视频/音频字幕
  static Future<bool> translateSubtitles({
    required List<Subtitles> subtitles,
    required String videoCode,
    required String title,
    required SubscriptionMode mode,
    required void Function(int current, int total) onProgress,
  }) async {
    if (subtitles.isEmpty) return true;
    if (mode == SubscriptionMode.free) {
      return await _translateSubtitlesLocal(subtitles, onProgress);
    } else {
      return await _translateSubtitlesAI(subtitles, videoCode, title, onProgress);
    }
  }

  /// 翻译文章句子
  static Future<bool> translateArticleSentences({
    required List<ArticleSentence> sentences,
    required String articleCode,
    required String title,
    required SubscriptionMode mode,
    required void Function(int current, int total) onProgress,
  }) async {
    if (sentences.isEmpty) return true;
    if (mode == SubscriptionMode.free) {
      return await _translateArticleSentencesLocal(sentences, onProgress);
    } else {
      return await _translateArticleSentencesAI(sentences, articleCode, title, onProgress);
    }
  }

  /// 免费模式：本地 MarianMT 逐句翻译字幕
  static Future<bool> _translateSubtitlesLocal(List<Subtitles> subtitles, void Function(int current, int total) onProgress) async {
    // 诊断日志：记录磁盘空间
    try {
      final dir = await getApplicationSupportDirectory();
      final stat = await dir.stat();
      dev.log(
        'translation start | count=${subtitles.length} | disk=${stat.size} bytes',
        name: 'TranslationInitService',
      );
    } catch (_) {}

    int success = 0;
    for (int i = 0; i < subtitles.length; i++) {
      final sub = subtitles[i];
      try {
        final result = await UnifiedTranslationService.instance.translate(text: sub.content, mode: SubscriptionMode.free);
        if (result.success && result.translation != null && result.translation!.isNotEmpty) {
          sub.contentTranslate = result.translation;
          sub.translateSource = TranslateSource.local.value;
          success++;
        }
      } catch (e) {
        dev.log('Local translation failed for subtitle $i: $e', name: 'TranslationInitService');
      }
      onProgress(i + 1, subtitles.length);

      if ((i + 1) % 10 == 0 || i == subtitles.length - 1) {
        final batchToUpdate = subtitles.sublist((i ~/ 10) * 10, i + 1);
        try {
          await DatabaseService.updateTranslationsByCode(batchToUpdate);
        } catch (e) {
          dev.log(
            'updateTranslationsByCode failed: $e | batch=${batchToUpdate.length} | '
            'index=$i/${subtitles.length}',
            name: 'TranslationInitService',
          );
        }
      }
    }

    dev.log('Local translation completed: $success/${subtitles.length} succeeded', name: 'TranslationInitService');
    return success > 0;
  }

  /// 收费模式：云端 AI 批量翻译字幕
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
        await DatabaseService.updateTranslationsByCode(subtitles);
      }

      dev.log('AI translation completed: $success/${subtitles.length} succeeded', name: 'TranslationInitService');
      return success > 0;
    } catch (e) {
      dev.log('AI translation failed: $e', name: 'TranslationInitService');
      return false;
    }
  }

  /// 调用云端 AI 翻译接口
  static Future<Map<String, dynamic>?> _callAiTranslateSubtitles(List<Subtitles> subtitles, String videoCode, String title) async {
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

    final client = supabase.Supabase.instance.client;
    final resp = await client.functions.invoke(
      'ai-proxy',
      body: {
        'rule_code': 'ai_translate_article',
        'scene': 'player',
        'entry': 'translate_subtitles',
        'request_id': const Uuid().v4(),
        'params': {'prompt': buf.toString(), 'model': 'qwen', 'temperature': 0.2, 'max_tokens': 8192},
        'source_type': 'video',
        'source_code': videoCode,
      },
    );

    final data = resp.data;
    if (data is Map<String, dynamic> && data['ok'] == true) {
      final result = data['result'];
      if (result is Map<String, dynamic>) {
        final raw = result['raw'] as String?;
        if (raw != null) return jsonDecode(raw.trim());
      }
      if (result is String) {
        return jsonDecode(result.trim());
      }
    }
    return null;
  }

  /// 免费模式：本地 MarianMT 逐句翻译文章
  static Future<bool> _translateArticleSentencesLocal(
    List<ArticleSentence> sentences,
    void Function(int current, int total) onProgress,
  ) async {
    int success = 0;
    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      try {
        final result = await UnifiedTranslationService.instance.translate(text: sentence.content, mode: SubscriptionMode.free);
        if (result.success && result.translation != null && result.translation!.isNotEmpty) {
          sentence.contentTranslate = result.translation;
          sentence.translateSource = TranslateSource.local.value;
          success++;
        }
      } catch (e) {
        dev.log('Local translation failed for article sentence $i: $e', name: 'TranslationInitService');
      }
      onProgress(i + 1, sentences.length);
    }

    if (success > 0) {
      try {
        await DatabaseService.updateTranslationsByCode(sentences);
      } catch (e) {
        dev.log('batchUpdate failed: $e', name: 'TranslationInitService');
      }
    }

    dev.log('Local article translation completed: $success/${sentences.length} succeeded', name: 'TranslationInitService');
    return success > 0;
  }

  /// 收费模式：云端 AI 翻译文章
  static Future<bool> _translateArticleSentencesAI(
    List<ArticleSentence> sentences,
    String articleCode,
    String title,
    void Function(int current, int total) onProgress,
  ) async {
    if (sentences.isEmpty) return false;

    try {
      final result = await _callAiTranslateArticle(sentences, articleCode, title);
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
      for (int i = 0; i < sentences.length; i++) {
        final sentence = sentences[i];
        final translation = map[i];
        if (translation != null) {
          sentence.contentTranslate = translation;
          sentence.translateSource = TranslateSource.ai.value;
          success++;
        }
        onProgress(i + 1, sentences.length);
      }

      if (success > 0) {
        await DatabaseService.updateTranslationsByCode(sentences);
      }

      dev.log('AI article translation completed: $success/${sentences.length} succeeded', name: 'TranslationInitService');
      return success > 0;
    } catch (e) {
      dev.log('AI article translation failed: $e', name: 'TranslationInitService');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> _callAiTranslateArticle(
    List<ArticleSentence> sentences,
    String articleCode,
    String title,
  ) async {
    final buf = StringBuffer();
    buf.writeln('你是专业的英文学习翻译助手。请对下面的英文文章做"逐句翻译"。');
    buf.writeln('输出必须是严格 JSON：{"sentences":[{"sentence_index":0,"zh":"..."}]}');
    buf.writeln('规则：sentences 数组长度必须与输入句子数一致，zh 为中文译文。');
    buf.writeln();
    buf.writeln('标题：$title');
    buf.writeln();
    buf.writeln('输入句子列表：');
    for (int i = 0; i < sentences.length; i++) {
      final s = sentences[i];
      buf.writeln('[$i] ${s.content}');
    }

    final client = supabase.Supabase.instance.client;
    final resp = await client.functions.invoke(
      'ai-proxy',
      body: {
        'rule_code': 'ai_translate_article',
        'scene': 'article',
        'entry': 'translate_article',
        'request_id': const Uuid().v4(),
        'params': {'prompt': buf.toString(), 'model': 'qwen', 'temperature': 0.2, 'max_tokens': 8192},
        'source_type': 'article',
        'source_code': articleCode,
      },
    );

    final data = resp.data;
    if (data is Map<String, dynamic> && data['ok'] == true) {
      final result = data['result'];
      if (result is Map<String, dynamic>) {
        final raw = result['raw'] as String?;
        if (raw != null) return jsonDecode(raw.trim());
      }
      if (result is String) {
        return jsonDecode(result.trim());
      }
    }
    return null;
  }
}
