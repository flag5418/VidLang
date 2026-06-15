import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vidlang/config.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_chapter.dart';
import 'package:vidlang/models/article_translation.dart';
import 'package:vidlang/services/database_service.dart';

/// 文章翻译服务
///
/// 使用阿里云 DashScope（千问 LLM）将英文文章全文翻译为中文。
/// 翻译结果缓存在 Supabase article_translation 表中，避免重复调用。
class TranslationService {
  static const _endpoint =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';

  /// 获取文章翻译（优先从 Supabase 缓存读取，否则调用 LLM 生成）
  static Future<ArticleTranslation?> translateArticle({
    required String articleCode,
    required Article article,
    required List<ArticleChapter> chapters,
  }) async {
    // 1. 查缓存
    final cached = await DatabaseService.findByCondition<ArticleTranslation>(
      () => ArticleTranslation(),
      where: 'article_code = ? AND lang_to = ? AND is_deleted = 0',
      whereArgs: [articleCode, 'zh'],
      limit: 1,
    );
    if (cached.isNotEmpty) return cached.first;

    // 2. 构建翻译请求
    final prompt = _buildTranslationPrompt(article, chapters);
    final result = await _callQwen(prompt);
    if (result == null) return null;

    // 3. 解析并按章拆分
    final chapterMap = _parseChapterTranslations(result, chapters.length);

    // 4. 存入 Supabase
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

  /// 构建翻译 Prompt——将文章按章发送给 LLM 一次性翻译
  static String _buildTranslationPrompt(
      Article article, List<ArticleChapter> chapters) {
    final buf = StringBuffer();
    buf.writeln('请将以下英文文章逐章翻译成中文。每章之间用空行分隔。');
    buf.writeln('要求：');
    buf.writeln('1. 保持原文段落结构');
    buf.writeln('2. 人名/地名/专业术语保留原词或通用译法');
    buf.writeln('3. 翻译结果格式：每章以 "--- CHAPTER N ---" 开头，后跟中文翻译');
    buf.writeln();

    final title = article.title;
    buf.writeln('标题：$title');
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

  /// 调用千问 LLM 进行翻译
  static Future<String?> _callQwen(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConfig.aliDashScopeApiKey}',
        },
        body: jsonEncode({
          'model': AppConfig.qwenModel,
          'messages': [
            {
              'role': 'system',
              'content': '你是一个专业的英文到中文翻译助手。请严格按照用户要求的格式输出翻译结果，不要添加额外解释。',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.3,
          'max_tokens': 8192,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        return content?.toString().trim();
      }
      print('[TranslationService] LLM error: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      print('[TranslationService] exception: $e');
      return null;
    }
  }

  /// 解析 LLM 返回的翻译，按章拆分
  static Map<String, String> _parseChapterTranslations(
      String raw, int expectedChapters) {
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

    // 如果正则未匹配到，取全文
    if (result.isEmpty && raw.isNotEmpty) {
      result['0'] = raw.trim();
    }

    return result;
  }
}
