import 'package:vidlang/models/base_entity.dart';

/// 文章章节实体类
///
/// 从 Markdown 中按标题（#/##/###）解析出的章节。
/// 一个章节包含若干句子，支持单独跟读和学习进度追踪。
class ArticleChapter extends BaseEntity {
  /// 所属文章 code（关联 article.code）
  String articleCode;

  /// 章节标题
  String title;

  /// 章节在文章中的索引（从 1 开始）
  int chapterIndex;

  /// 该章节包含的句子数
  int sentenceCount;

  /// 章节纯文本（不含 Markdown 标记）
  String plainText;

  /// 学习进度 0.0 ~ 1.0
  double progress;

  /// 起始句子索引（包含，用于在 sentences 表中定位）
  int startSentenceIndex;

  /// 结束句子索引（包含）
  int endSentenceIndex;

  ArticleChapter({
    this.articleCode = '',
    this.title = '',
    this.chapterIndex = 0,
    this.sentenceCount = 0,
    this.plainText = '',
    this.progress = 0.0,
    this.startSentenceIndex = 0,
    this.endSentenceIndex = 0,
  });

  @override
  String get tableName => 'article_chapter';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'article_code': articleCode,
      'title': title,
      'chapter_index': chapterIndex,
      'sentence_count': sentenceCount,
      'plain_text': plainText,
      'progress': progress,
      'start_sentence_index': startSentenceIndex,
      'end_sentence_index': endSentenceIndex,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'deleted_by': deletedBy,
    };
  }

  @override
  BaseEntity fromMap(Map<String, dynamic> map) {
    id = map['id'];
    code = map['code'];
    userCode = map['user_code'];
    articleCode = map['article_code'] ?? '';
    title = map['title'] ?? '';
    chapterIndex = map['chapter_index'] ?? 0;
    sentenceCount = map['sentence_count'] ?? 0;
    plainText = map['plain_text'] ?? '';
    progress = (map['progress'] as num?)?.toDouble() ?? 0.0;
    startSentenceIndex = map['start_sentence_index'] ?? 0;
    endSentenceIndex = map['end_sentence_index'] ?? 0;
    createdAt = map['created_at'] != null ? DateTime.parse(map['created_at']) : null;
    updatedAt = map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null;
    deletedAt = map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null;
    isDeleted = map['is_deleted'] == 1;
    createdBy = map['created_by'];
    updatedBy = map['updated_by'];
    deletedBy = map['deleted_by'];
    return this;
  }
}
