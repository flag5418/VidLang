import 'package:vidlang/models/base_entity.dart';

/// 文章句子实体类
///
/// 从 Markdown 解析出的最小学习单位。
/// 支持全文检索（FTS5），用于单词搜索和跨文章查询。
/// 每个句子包含时间轴字段（毫秒），用于文章逐句 TTS 播放模式。
class ArticleSentence extends BaseEntity {
  /// 所属文章 code（关联 article.code）
  String articleCode;

  /// 所属段落索引（从 0 开始）
  int paragraphIndex;

  /// 句子在文章中的全局序号（从 0 开始）
  int sentenceIndex;

  /// 句子内容
  String content;

  /// 翻译文本
  String? contentTranslate;

  /// 翻译来源：-1=无翻译 0=原生翻译 1=AI翻译
  int translateSource = -1;

  /// 阅读时间轴：累计起始位置（毫秒）
  int startPositionMs;

  /// 阅读时间轴：累计结束位置（毫秒）
  int endPositionMs;

  /// 单词数
  int wordCount;

  /// 是否被用户标记为重点句
  bool isKeySentence;

  ArticleSentence({
    this.articleCode = '',
    this.paragraphIndex = 0,
    this.sentenceIndex = 0,
    this.content = '',
    this.contentTranslate,
    this.translateSource = -1,
    this.startPositionMs = 0,
    this.endPositionMs = 0,
    this.wordCount = 0,
    this.isKeySentence = false,
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
      'paragraph_index': paragraphIndex,
      'sentence_index': sentenceIndex,
      'content': content,
      'content_translate': contentTranslate,
      'translate_source': translateSource,
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
    paragraphIndex = map['paragraph_index'] ?? 0;
    sentenceIndex = map['sentence_index'] ?? 0;
    content = map['content'] ?? '';
    contentTranslate = map['content_translate'];
    translateSource = map['translate_source'] ?? -1;
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
