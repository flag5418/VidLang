import 'dart:convert';
import 'dart:developer' as dev;

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_chapter.dart';
import 'package:vidlang/models/article_paragraph.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/models/article_translation.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/database_service.dart';

class TranslationService {
  static Future<ArticleTranslation?> translateArticle({
    required String articleCode,
    required Article article,
    required List<ArticleChapter> chapters,
    required List<ArticleParagraph> paragraphs,
    required List<ArticleSentence> sentences,
  }) async {
    if (sentences.isEmpty) return null;

    final alreadyTranslated = sentences.any((s) => (s.contentTranslate ?? '').trim().isNotEmpty);
    if (alreadyTranslated) {
      final cached = await _getCachedTranslation(articleCode: articleCode);
      await _tryUploadToCloud(
        articleCode: articleCode,
        title: article.title,
        sentences: sentences,
      );
      return cached ??
          ArticleTranslation(
            articleCode: articleCode,
            langFrom: 'en',
            langTo: 'zh',
            fullTranslation: '',
            chapterTranslations: const {},
          );
    }

    final cached = await DatabaseService.findByCondition<ArticleTranslation>(
      () => ArticleTranslation(),
      where: 'article_code = ? AND lang_to = ? AND is_deleted = 0',
      whereArgs: [articleCode, 'zh'],
      limit: 1,
    );
    if (cached.isNotEmpty) {
      final parsed = _tryParseSentenceTranslations(cached.first.fullTranslation);
      if (parsed != null) {
        _applyTranslations(sentences: sentences, paragraphs: paragraphs, parsed: parsed);
        await DatabaseService.batchUpdate(sentences);
        if (paragraphs.isNotEmpty) await DatabaseService.batchUpdate(paragraphs);
        await _tryUploadToCloud(articleCode: articleCode, title: article.title, sentences: sentences);
      }
      return cached.first;
    }

    final cloud = await _tryGetFromCloud(articleCode: articleCode);
    if (cloud != null) {
      _applyTranslations(sentences: sentences, paragraphs: paragraphs, parsed: cloud);
      await DatabaseService.batchUpdate(sentences);
      if (paragraphs.isNotEmpty) await DatabaseService.batchUpdate(paragraphs);
      return ArticleTranslation(
        articleCode: articleCode,
        langFrom: 'en',
        langTo: 'zh',
        fullTranslation: jsonEncode(cloud),
        chapterTranslations: const {},
      );
    }

    final prompt = _buildSentenceTranslationPrompt(article, chapters, paragraphs, sentences);
    final result = await _callAiProxy(prompt, articleCode);
    if (result == null) return null;

    final parsed = _tryParseSentenceTranslations(result);
    if (parsed == null) return null;

    _applyTranslations(sentences: sentences, paragraphs: paragraphs, parsed: parsed);
    await DatabaseService.batchUpdate(sentences);
    if (paragraphs.isNotEmpty) await DatabaseService.batchUpdate(paragraphs);
    await _tryUploadToCloud(articleCode: articleCode, title: article.title, sentences: sentences);

    final translation = ArticleTranslation(
      articleCode: articleCode,
      langFrom: 'en',
      langTo: 'zh',
      fullTranslation: jsonEncode(parsed),
      chapterTranslations: const {},
    );
    await DatabaseService.insert(translation);
    return translation;
  }

  static Future<ArticleTranslation?> _getCachedTranslation({required String articleCode}) async {
    final cached = await DatabaseService.findByCondition<ArticleTranslation>(
      () => ArticleTranslation(),
      where: 'article_code = ? AND lang_to = ? AND is_deleted = 0',
      whereArgs: [articleCode, 'zh'],
      limit: 1,
    );
    return cached.isNotEmpty ? cached.first : null;
  }

  static String _buildSentenceTranslationPrompt(
    Article article,
    List<ArticleChapter> chapters,
    List<ArticleParagraph> paragraphs,
    List<ArticleSentence> sentences,
  ) {
    final buf = StringBuffer();
    buf.writeln('你是专业的英文学习翻译助手。请对下面的英文短文做“逐句翻译”，每句翻译需要结合上下文，保证指代、时态和语气自然。');
    buf.writeln('输出必须是严格 JSON，禁止输出除 JSON 以外的任何内容。');
    buf.writeln('JSON 格式：');
    buf.writeln('{"sentences":[{"sentence_index":0,"paragraph_index":0,"zh":"..."}], "paragraphs":[{"paragraph_index":0,"zh":"..."}]}');
    buf.writeln('规则：');
    buf.writeln('1) sentences 数组长度必须与输入句子数一致，不得漏句/增句');
    buf.writeln('2) zh 为中文译文，不要加序号，不要换行编号');
    buf.writeln('3) paragraphs.zh 是该段落的自然中文译文（允许合并句子），但必须与 paragraph_index 对应');
    buf.writeln();
    buf.writeln('标题：${article.title}');
    buf.writeln();
    buf.writeln('输入句子列表：');
    for (final s in sentences) {
      buf.writeln(
        jsonEncode({
          'sentence_index': s.sentenceIndex,
          'paragraph_index': s.paragraphIndex,
          'en': s.content,
        }),
      );
    }
    buf.writeln();
    if (paragraphs.isNotEmpty) {
      buf.writeln('段落原文（用于段落翻译，index 与 paragraph_index 对齐）：');
      for (final p in paragraphs) {
        buf.writeln(jsonEncode({'paragraph_index': p.paragraphIndex, 'en': p.contentPlain}));
      }
    } else {
      buf.writeln('段落原文缺失时，可忽略 paragraphs 输出或输出空数组。');
    }
    return buf.toString();
  }

  static Future<String?> _callAiProxy(String prompt, String articleCode) async {
    final resp = await AiService.callAiProxyRaw(
      ruleCode: 'ai_translate_article',
      scene: 'article',
      entry: 'translate_article',
      params: {
        'prompt': prompt,
        'model': 'qwen',
        'temperature': 0.2,
        'max_tokens': 8192,
      },
      sourceType: 'article',
      sourceCode: articleCode,
    );

    final ok = resp['ok'] as bool? ?? false;
    if (!ok) return null;

    final result = resp['result'];
    if (result is Map<String, dynamic>) {
      return (result['content'] as String?)?.trim();
    }
    if (result is String) {
      return result.trim();
    }
    return null;
  }

  static Map<String, dynamic>? _tryParseSentenceTranslations(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final sub = raw.substring(start, end + 1);
      try {
        final decoded = jsonDecode(sub);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  static void _applyTranslations({
    required List<ArticleSentence> sentences,
    required List<ArticleParagraph> paragraphs,
    required Map<String, dynamic> parsed,
  }) {
    final sentList = parsed['sentences'];
    if (sentList is List) {
      final map = <int, String>{};
      for (final item in sentList) {
        if (item is! Map) continue;
        final idx = item['sentence_index'];
        final zh = item['zh'];
        if (idx is int && zh is String && zh.trim().isNotEmpty) {
          map[idx] = zh.trim();
        } else if (idx is num && zh is String && zh.trim().isNotEmpty) {
          map[idx.toInt()] = zh.trim();
        }
      }
      for (final s in sentences) {
        final t = map[s.sentenceIndex];
        if (t != null) s.contentTranslate = t;
      }
    }

    final paraList = parsed['paragraphs'];
    if (paraList is List && paragraphs.isNotEmpty) {
      final map = <int, String>{};
      for (final item in paraList) {
        if (item is! Map) continue;
        final idx = item['paragraph_index'];
        final zh = item['zh'];
        if (idx is int && zh is String && zh.trim().isNotEmpty) {
          map[idx] = zh.trim();
        } else if (idx is num && zh is String && zh.trim().isNotEmpty) {
          map[idx.toInt()] = zh.trim();
        }
      }
      for (final p in paragraphs) {
        final t = map[p.paragraphIndex];
        if (t != null) p.translation = t;
      }
    }
  }

  static String _cloudCodeForArticle(String articleCode) => 'article_$articleCode';

  static Future<Map<String, dynamic>?> _tryGetFromCloud({required String articleCode}) async {
    try {
      AuthService.instance.ensureActiveSession();
      final client = sb.Supabase.instance.client;
      final resp = await client.functions.invoke('subtitle-storage', body: {'op': 'get', 'video_code': _cloudCodeForArticle(articleCode)});
      final data = resp.data;
      if (data is! Map) return null;
      final ok = data['ok'] as bool? ?? false;
      if (!ok) return null;
      final payload = data['data'];
      if (payload is! Map) return null;
      final items = payload['items'];
      if (items is! List) return null;

      final sentences = <Map<String, dynamic>>[];
      for (final item in items) {
        if (item is! Map) continue;
        sentences.add({
          'sentence_index': item['sentence_index'] ?? item['sentenceIndex'],
          'paragraph_index': item['paragraph_index'] ?? item['paragraphIndex'],
          'zh': item['content_translate'] ?? item['contentTranslate'],
        });
      }
      return {'sentences': sentences, 'paragraphs': const []};
    } catch (e) {
      dev.log('tryGetFromCloud failed: $e', name: 'TranslationService');
      return null;
    }
  }

  static Future<void> _tryUploadToCloud({
    required String articleCode,
    required String title,
    required List<ArticleSentence> sentences,
  }) async {
    try {
      AuthService.instance.ensureActiveSession();
      final client = sb.Supabase.instance.client;
      final items = sentences
          .map(
            (s) => {
              'sentence_index': s.sentenceIndex,
              'paragraph_index': s.paragraphIndex,
              'content': s.content,
              'content_translate': s.contentTranslate,
            },
          )
          .toList();
      await client.functions.invoke(
        'subtitle-storage',
        body: {
          'op': 'upload',
          'video_code': _cloudCodeForArticle(articleCode),
          'title': title,
          'items': items,
        },
      );
    } catch (e) {
      dev.log('tryUploadToCloud failed: $e', name: 'TranslationService');
    }
  }
}
