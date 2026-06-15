import 'package:vidlang/models/base_entity.dart';

/// 文章段落实体类
///
/// 段落是文章阅读和操作的基本单元。
/// 一个段落包含连续的多句话，用于：
/// - 侧边栏导航
/// - 段落级操作（释义/朗读）
/// - 翻译上下文（以段落为单位请求翻译）
class ArticleParagraph extends BaseEntity {
  /// 所属文章 code（关联 article.code）
  String articleCode;

  /// 段落在文章中的序号（从 0 开始）
  int paragraphIndex;

  /// 段落 Markdown 原文（保留格式）
  String contentMarkdown;

  /// 段落纯文本（TTS 朗读用，去除 Markdown 标记）
  String contentPlain;

  /// 段落中文译文缓存
  String? translation;

  /// 本段落起始句子在 article_sentence 表中的全局索引
  int startSentenceIdx;

  /// 本段落结束句子在 article_sentence 表中的全局索引
  int endSentenceIdx;

  ArticleParagraph({
    this.articleCode = '',
    this.paragraphIndex = 0,
    this.contentMarkdown = '',
    this.contentPlain = '',
    this.translation,
    this.startSentenceIdx = 0,
    this.endSentenceIdx = 0,
  });

  @override
  String get tableName => 'article_paragraph';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'article_code': articleCode,
      'paragraph_index': paragraphIndex,
      'content_markdown': contentMarkdown,
      'content_plain': contentPlain,
      'translation': translation,
      'start_sentence_idx': startSentenceIdx,
      'end_sentence_idx': endSentenceIdx,
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
    contentMarkdown = map['content_markdown'] ?? '';
    contentPlain = map['content_plain'] ?? '';
    translation = map['translation'];
    startSentenceIdx = map['start_sentence_idx'] ?? 0;
    endSentenceIdx = map['end_sentence_idx'] ?? 0;
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
