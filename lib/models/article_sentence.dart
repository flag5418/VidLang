import 'package:vidlang/models/base_entity.dart';

/// 文章句子实体类
///
/// 从 Markdown 解析出的最小学习单位。
/// 支持全文检索（FTS5），用于单词搜索和跨文章查询。
/// 每个句子包含时间轴字段（毫秒），用于文章逐句播放模式。
class ArticleSentence extends BaseEntity {
  /// 所属文章 code（关联 article.code）
  String articleCode;

  /// 所属章节 code（关联 article_chapter.code）
  String? chapterCode;

  /// 句子在文章中的序号（从 1 开始）
  int sentenceIndex;

  /// 翻译文本
  String? contentTranslate;

  /// 阅读时间轴：累计起始位置（毫秒）
  int startPositionMs;

  /// 阅读时间轴：累计结束位置（毫秒）
  int endPositionMs;

  /// 单词数
  int wordCount;

  /// 是否被用户标记为重点句
  bool isKeySentence;

  /// 句子内容
  String content;

  ArticleSentence({
    this.articleCode = '',
    this.chapterCode,
    this.sentenceIndex = 0,
    this.contentTranslate,
    this.startPositionMs = 0,
    this.endPositionMs = 0,
    this.wordCount = 0,
    this.isKeySentence = false,
    this.content = '',
  });

  @override
  String get tableName => 'article_sentence';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'article_code': articleCode,
      'chapter_code': chapterCode,
      'sentence_index': sentenceIndex,
      'content': content,
      'content_translate': contentTranslate,
      'start_position_ms': startPositionMs,
      'end_position_ms': endPositionMs,
      'word_count': wordCount,
      'is_key_sentence': isKeySentence ? 1 : 0,
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
    chapterCode = map['chapter_code'];
    sentenceIndex = map['sentence_index'] ?? 0;
    content = map['content'] ?? '';
    contentTranslate = map['content_translate'];
    startPositionMs = map['start_position_ms'] ?? 0;
    endPositionMs = map['end_position_ms'] ?? 0;
    wordCount = map['word_count'] ?? 0;
    isKeySentence = map['is_key_sentence'] == 1;
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
