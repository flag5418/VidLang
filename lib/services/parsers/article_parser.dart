import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_paragraph.dart';
import 'package:vidlang/models/article_sentence.dart';

/// 文章解析工具
///
/// 将用户输入的 Markdown 文本解析为 Article + ArticleParagraph[] + ArticleSentence[]
///
/// 注意：ArticleChapter 已移除，章节概念不再使用。文章直接按段落+句子组织。
class ArticleParser {
  /// 解析结果
  final Article article;
  final List<ArticleParagraph> paragraphs;
  final List<ArticleSentence> sentences;

  ArticleParser({
    required this.article,
    required this.paragraphs,
    required this.sentences,
  });

  /// 解析文章
  ///
  /// [title] 文章标题
  /// [content] 用户粘贴的文章正文（Markdown 格式）
  ///
  /// 按空行拆分为段落，段内按句子分割。
  static ArticleParser parse({required String title, required String content}) {
    final article = Article(title: title, contentMarkdown: content);

    final paraTexts = content.split(RegExp(r'\n\s*\n'));
    final List<ArticleParagraph> paragraphs = [];
    final List<ArticleSentence> sentences = [];
    int globalSentenceIdx = 0;
    int totalWordCount = 0;
    int globalParagraphIdx = 0;

    for (int pIdx = 0; pIdx < paraTexts.length; pIdx++) {
      final text = paraTexts[pIdx].trim();
      if (text.isEmpty) continue;

      // 跳过 Markdown 标题行（原章节标题，不再创建 Chapter 对象）
      if (RegExp(r'^#{1,6}\s+').hasMatch(text)) continue;

      final plainText = _stripMarkdown(text);
      final paraSentences = _splitSentences(plainText);
      int paraWordCount = 0;

      for (int sIdx = 0; sIdx < paraSentences.length; sIdx++) {
        final s = paraSentences[sIdx].trim();
        if (s.isEmpty) continue;

        final wc = _wordCount(s);
        paraWordCount += wc;

        sentences.add(
          ArticleSentence(
            articleCode: '',
            paragraphIndex: globalParagraphIdx,
            sentenceIndex: globalSentenceIdx,
            content: s,
            wordCount: wc,
          ),
        );
        globalSentenceIdx++;
      }

      totalWordCount += paraWordCount;

      paragraphs.add(
        ArticleParagraph(
          articleCode: '',
          paragraphIndex: globalParagraphIdx,
          contentMarkdown: text,
          contentPlain: plainText,
          startSentenceIdx:
              globalSentenceIdx -
              paraSentences.where((s) => s.trim().isNotEmpty).length,
          endSentenceIdx: globalSentenceIdx - 1,
        ),
      );
      globalParagraphIdx++;
    }

    article.totalParagraphs = paragraphs.length;
    article.totalSentences = sentences.length;
    article.wordCount = totalWordCount;
    article.language = 'en';

    return ArticleParser(
      article: article,
      paragraphs: paragraphs,
      sentences: sentences,
    );
  }

  /// 按句子分割
  ///
  /// 按 . ! ? 分割，排除常见缩写
  static List<String> _splitSentences(String text) {
    // 保护缩写
    const abbreviations = [
      'Mr.',
      'Mrs.',
      'Ms.',
      'Dr.',
      'Prof.',
      'e.g.',
      'i.e.',
      'etc.',
      'vs.',
      'St.',
      'Jr.',
      'Sr.',
      'U.S.',
      'U.K.',
      'a.m.',
      'p.m.',
    ];

    String processed = text;
    final placeholders = <String, String>{};
    for (int i = 0; i < abbreviations.length; i++) {
      final abbr = abbreviations[i];
      if (processed.contains(abbr)) {
        final placeholder = '\x00ABBR$i\x00';
        placeholders[placeholder] = abbr;
        processed = processed.replaceAll(abbr, placeholder);
      }
    }

    // 按句子分隔符分割
    final parts = processed.split(RegExp(r'(?<=[.!?])\s+'));

    // 恢复缩写
    final result = parts
        .map((p) {
          String r = p.trim();
          for (final entry in placeholders.entries) {
            r = r.replaceAll(entry.key, entry.value);
          }
          return r;
        })
        .where((s) => s.isNotEmpty)
        .toList();

    return result;
  }

  static String _stripMarkdown(String text) {
    return text
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'_(.+?)_'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'`(.+?)`'), (m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '')
        .replaceAllMapped(RegExp(r'\[(.+?)\]\(.*?\)'), (m) => m.group(1)!)
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^>\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^[-*+]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '');
  }

  /// 统计单词数
  static int _wordCount(String text) {
    return RegExp(r'\b[a-zA-Z]+\b').allMatches(text).length;
  }
}
