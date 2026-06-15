import '../models/article.dart';
import '../models/article_chapter.dart';
import '../models/article_paragraph.dart';
import '../models/article_sentence.dart';

/// 文章解析工具
///
/// 将用户输入的 Markdown 文本解析为 Article + ArticleChapter[] + ArticleSentence[]
class ArticleParser {
  /// 解析结果
  final Article article;
  final List<ArticleParagraph> paragraphs;
  final List<ArticleChapter> chapters;
  final List<ArticleSentence> sentences;

  ArticleParser({
    required this.article,
    required this.paragraphs,
    required this.chapters,
    required this.sentences,
  });

  /// 解析文章
  ///
  /// [title] 文章标题
  /// [content] 用户粘贴的文章正文（Markdown 格式）
  ///
  /// 按 # 标题拆分为章，章内按句子分割。
  /// 无标题时整个文章视为单章。
  static ArticleParser parse({required String title, required String content}) {
    final article = Article(title: title, contentMarkdown: content);

    // 按 # 标题拆分为章
    final chapSections = _splitIntoChapterSections(content);
    final List<ArticleParagraph> paragraphs = [];
    final List<ArticleChapter> chapters = [];
    final List<ArticleSentence> sentences = [];
    int globalSentenceIdx = 0;
    int totalWordCount = 0;

    for (int cIdx = 0; cIdx < chapSections.length; cIdx++) {
      final section = chapSections[cIdx];
      final chapTitle = section.title;

      // 章内按空行分段落
      final paraTexts = section.body.split(RegExp(r'\n\s*\n'));
      final startSentenceIdx = globalSentenceIdx;

      for (int pIdx = 0; pIdx < paraTexts.length; pIdx++) {
        final text = paraTexts[pIdx].trim();
        if (text.isEmpty) continue;

        final plainText = _stripMarkdown(text);
        final paraSentences = _splitSentences(plainText);
        int paraWordCount = 0;

        for (int sIdx = 0; sIdx < paraSentences.length; sIdx++) {
          final s = paraSentences[sIdx].trim();
          if (s.isEmpty) continue;

          final wc = _wordCount(s);
          paraWordCount += wc;

          sentences.add(ArticleSentence(
            articleCode: '',
            paragraphIndex: cIdx, // paragraphIndex = chapterIndex for backward compat
            sentenceIndex: globalSentenceIdx,
            content: s,
            wordCount: wc,
          ));
          globalSentenceIdx++;
        }

        totalWordCount += paraWordCount;

        paragraphs.add(ArticleParagraph(
          articleCode: '',
          paragraphIndex: cIdx,
          contentMarkdown: text,
          contentPlain: plainText,
          startSentenceIdx: globalSentenceIdx - paraSentences.length,
          endSentenceIdx: globalSentenceIdx - 1,
        ));
      }

      // 构建 ArticleChapter
      final chapPlainText = section.body.split(RegExp(r'\n\s*\n')).map((t) => _stripMarkdown(t.trim())).where((t) => t.isNotEmpty).join(' ');
      chapters.add(ArticleChapter(
        articleCode: '',
        title: chapTitle,
        chapterIndex: cIdx,
        sentenceCount: globalSentenceIdx - startSentenceIdx,
        plainText: chapPlainText,
        startSentenceIndex: startSentenceIdx,
        endSentenceIndex: globalSentenceIdx - 1,
      ));
    }

    article.totalParagraphs = paragraphs.length;
    article.totalSentences = sentences.length;
    article.wordCount = totalWordCount;
    article.language = 'en';

    return ArticleParser(
      article: article,
      paragraphs: paragraphs,
      chapters: chapters,
      sentences: sentences,
    );
  }

  /// 按 # / ## / ### 标题将文章拆分为章
  static List<_ChapterSection> _splitIntoChapterSections(String content) {
    final headingRegex = RegExp(r'^(#{1,6})\s+(.+)$', multiLine: true);
    final matches = headingRegex.allMatches(content).toList();

    if (matches.isEmpty) {
      // 无标题，整篇文章作为单章
      return [_ChapterSection(title: '', body: content.trim())];
    }

    final sections = <_ChapterSection>[];
    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      final title = match.group(2) ?? '';
      final start = match.end;

      // 下一章开始（或文末）
      final end = i + 1 < matches.length ? matches[i + 1].start : content.length;
      final body = content.substring(start, end).trim();

      sections.add(_ChapterSection(title: title, body: body));
    }

    // 处理第一个标题前的内容（作为前言章）
    if (matches.isNotEmpty && matches.first.start > 0) {
      final preBody = content.substring(0, matches.first.start).trim();
      if (preBody.isNotEmpty) {
        sections.insert(0, _ChapterSection(title: '', body: preBody));
      }
    }

    return sections;
  }

  /// 按句子分割
  ///
  /// 按 . ! ? 分割，排除常见缩写
  static List<String> _splitSentences(String text) {
    // 保护缩写
    final abbreviations = [
      'Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.',
      'e.g.', 'i.e.', 'etc.', 'vs.', 'St.',
      'Jr.', 'Sr.', 'U.S.', 'U.K.', 'a.m.', 'p.m.',
    ];

    // 用占位符替换缩写中的句点
    String processed = text;
    final placeholders = <String, String>{};
    for (int i = 0; i < abbreviations.length; i++) {
      final abbr = abbreviations[i];
      final idx = processed.indexOf(abbr);
      if (idx >= 0) {
        final placeholder = '\x00ABBR${i}\x00';
        placeholders[placeholder] = abbr;
        processed = processed.replaceAll(abbr, placeholder);
      }
    }

    // 按句子分隔符分割
    final parts = processed.split(RegExp(r'(?<=[.!?])\s+'));

    // 恢复缩写
    final result = parts.map((p) {
      String r = p.trim();
      for (final entry in placeholders.entries) {
        r = r.replaceAll(entry.key, entry.value);
      }
      return r;
    }).where((s) => s.isNotEmpty).toList();

    return result;
  }

  /// 简单去除 Markdown 标记
  static String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'__(.+?)__'), r'$1')
        .replaceAll(RegExp(r'_(.+?)_'), r'$1')
        .replaceAll(RegExp(r'`(.+?)`'), r'$1')
        .replaceAll(RegExp(r'~~(.+?)~~'), r'$1')
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '')
        .replaceAll(RegExp(r'\[(.+?)\]\(.*?\)'), r'$1')
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

class _ChapterSection {
  final String title;
  final String body;
  const _ChapterSection({required this.title, required this.body});
}
