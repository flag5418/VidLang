import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_chapter.dart';
import 'package:vidlang/models/article_translation.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/database_service.dart';

class TranslationService {
  static Future<ArticleTranslation?> translateArticle({
    required String articleCode,
    required Article article,
    required List<ArticleChapter> chapters,
  }) async {
    final cached = await DatabaseService.findByCondition<ArticleTranslation>(
      () => ArticleTranslation(),
      where: 'article_code = ? AND lang_to = ? AND is_deleted = 0',
      whereArgs: [articleCode, 'zh'],
      limit: 1,
    );
    if (cached.isNotEmpty) return cached.first;

    final prompt = _buildTranslationPrompt(article, chapters);
    final result = await _callAiProxy(prompt, articleCode);
    if (result == null) return null;

    final chapterMap = _parseChapterTranslations(result, chapters.length);

    final translation = ArticleTranslation(
      articleCode: articleCode,
      langFrom: 'en',
      langTo: 'zh',
      fullTranslation: result,
      chapterTranslations: chapterMap,
    );
    await DatabaseService.insert(translation);
    return translation;
  }

  static String _buildTranslationPrompt(Article article, List<ArticleChapter> chapters) {
    final buf = StringBuffer();
    buf.writeln('请将以下英文文章逐章翻译成中文。每章之间用空行分隔。');
    buf.writeln('要求：');
    buf.writeln('1. 保持原文段落结构');
    buf.writeln('2. 人名/地名/专业术语保留原词或通用译法');
    buf.writeln('3. 翻译结果格式：每章以 "--- CHAPTER N ---" 开头，后跟中文翻译');
    buf.writeln();
    buf.writeln('标题：${article.title}');
    buf.writeln();

    for (int i = 0; i < chapters.length; i++) {
      final ch = chapters[i];
      buf.writeln('--- CHAPTER $i ---');
      if (ch.title.isNotEmpty) {
        buf.writeln('章标题: ${ch.title}');
      }
      buf.writeln(ch.plainText);
      buf.writeln();
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
        'temperature': 0.3,
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

  static Map<String, String> _parseChapterTranslations(String raw, int expectedChapters) {
    final result = <String, String>{};
    final regex = RegExp(r'--- CHAPTER (\d+) ---\s*\n?([\s\S]*?)(?=--- CHAPTER \d+ ---|$)');
    final matches = regex.allMatches(raw);

    for (final m in matches) {
      final idx = m.group(1)!;
      final text = m.group(2)!.trim();
      if (text.isNotEmpty) {
        result[idx] = text;
      }
    }

    if (result.isEmpty && raw.isNotEmpty) {
      result['0'] = raw.trim();
    }

    return result;
  }
}
