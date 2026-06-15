import 'dart:convert';
import 'package:vidlang/models/base_entity.dart';

/// 文章翻译实体
///
/// 存储整篇文章从英文到中文的翻译结果。
/// 翻译由 Qwen LLM 一次性生成，按章拆分存储，确保上下文准确。
class ArticleTranslation extends BaseEntity {
  /// 所属文章 code
  String articleCode;

  /// 源语言（默认 'en'）
  String langFrom;

  /// 目标语言（默认 'zh'）
  String langTo;

  /// 全文翻译（纯文本，用于全文对照）
  String fullTranslation;

  /// 按章翻译：{chapterIndex: translatedText}
  /// 存储为 JSON 字符串，读取时解析
  Map<String, String> chapterTranslations;

  ArticleTranslation({
    this.articleCode = '',
    this.langFrom = 'en',
    this.langTo = 'zh',
    this.fullTranslation = '',
    Map<String, String>? chapterTranslations,
  }) : chapterTranslations = chapterTranslations ?? {};

  @override
  String get tableName => 'article_translation';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'article_code': articleCode,
      'lang_from': langFrom,
      'lang_to': langTo,
      'full_translation': fullTranslation,
      'chapter_translations': jsonEncode(chapterTranslations),
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
    langFrom = map['lang_from'] ?? 'en';
    langTo = map['lang_to'] ?? 'zh';
    fullTranslation = map['full_translation'] ?? '';

    final raw = map['chapter_translations'];
    if (raw is String && raw.isNotEmpty) {
      try {
        chapterTranslations = (jsonDecode(raw) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        chapterTranslations = {};
      }
    } else if (raw is Map) {
      chapterTranslations =
          (raw).map((k, v) => MapEntry(k.toString(), v.toString()));
    } else {
      chapterTranslations = {};
    }

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
