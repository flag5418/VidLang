import 'package:vidlang/models/base_entity.dart';

/// 文章书签实体类
///
/// 记录用户的阅读位置，支持断点续读。
/// - 退出时自动保存当前位置（lastParagraphIndex / lastSentenceIndex）
/// - 用户可手动标记书签并添加备注
class ArticleBookmark extends BaseEntity {
  /// 所属文章 code（关联 article.code）
  String articleCode;

  /// 段落索引（从 0 开始）
  int paragraphIndex;

  /// 句子索引（从 0 开始）
  int sentenceIndex;

  /// 滚动偏移量（用于精确恢复位置）
  double scrollOffset;

  /// 用户备注（可选）
  String? note;

  ArticleBookmark({
    this.articleCode = '',
    this.paragraphIndex = 0,
    this.sentenceIndex = 0,
    this.scrollOffset = 0.0,
    this.note,
  });

  @override
  String get tableName => 'article_bookmark';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'article_code': articleCode,
      'paragraph_index': paragraphIndex,
      'sentence_index': sentenceIndex,
      'scroll_offset': scrollOffset,
      'note': note,
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
    scrollOffset = _toDouble(map['scroll_offset']) ?? 0.0;
    note = map['note'];
    createdAt = map['created_at'] != null ? DateTime.parse(map['created_at']) : null;
    updatedAt = map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null;
    deletedAt = map['deleted_at'] != null ? DateTime.parse(map['deleted_at']) : null;
    isDeleted = map['is_deleted'] == 1;
    createdBy = map['created_by'];
    updatedBy = map['updated_by'];
    deletedBy = map['deleted_by'];
    return this;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
