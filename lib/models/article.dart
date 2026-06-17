import 'package:vidlang/models/base_entity.dart';

/// 文章实体类
///
/// 用于存储和管理英文文章。
/// 全文以 Markdown 格式存储，按段落和句子两级模型组织。
/// 段落为阅读和操作的基本单元，句子为 TTS 朗读和收藏的最小单位。
class Article extends BaseEntity {
  /// 所属文件夹 code（关联 video_folder.code）
  String folderCode;

  /// 文章标题
  String title;

  /// 原文全文（Markdown 格式）
  String contentMarkdown;

  /// 封面图路径
  String? coverUrl;

  /// 作者
  String? author;

  /// 来源 URL
  String? sourceUrl;

  /// 语言，默认 'en'
  String language;

  /// 总段落数
  int totalParagraphs;

  /// 总句子数
  int totalSentences;

  /// 总单词数
  int wordCount;

  /// 学习进度 0.0 ~ 1.0
  double progress;

  /// 最后阅读的段落索引（断点续读）
  int lastParagraphIndex;

  /// 最后阅读的句子索引（断点续读）
  int lastSentenceIndex;

  /// 最后学习时间
  DateTime? lastStudyDate;

  /// 学习次数
  int studyCount;

  /// 排序索引
  int orderIndex;

  Article({
    this.folderCode = '',
    this.title = '',
    this.contentMarkdown = '',
    this.coverUrl,
    this.author,
    this.sourceUrl,
    this.language = 'en',
    this.totalParagraphs = 0,
    this.totalSentences = 0,
    this.wordCount = 0,
    this.progress = 0.0,
    this.lastParagraphIndex = 0,
    this.lastSentenceIndex = 0,
    this.lastStudyDate,
    this.studyCount = 0,
    this.orderIndex = 0,
  });

  @override
  String get tableName => 'article';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'folder_code': folderCode,
      'title': title,
      'content_markdown': contentMarkdown,
      'cover_url': coverUrl,
      'author': author,
      'source_url': sourceUrl,
      'language': language,
      'total_paragraphs': totalParagraphs,
      'total_chapters': totalParagraphs,
      'total_sentences': totalSentences,
      'word_count': wordCount,
      'progress': progress,
      'last_paragraph_index': lastParagraphIndex,
      'last_chapter_index': lastParagraphIndex,
      'last_sentence_index': lastSentenceIndex,
      'last_study_date': lastStudyDate?.toIso8601String(),
      'study_count': studyCount,
      'order_index': orderIndex,
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
    folderCode = map['folder_code'] ?? '';
    title = map['title'] ?? '';
    contentMarkdown = map['content_markdown'] ?? '';
    coverUrl = map['cover_url'];
    author = map['author'];
    sourceUrl = map['source_url'];
    language = map['language'] ?? 'en';
    totalParagraphs = map['total_paragraphs'] ?? map['total_chapters'] ?? 0;
    totalSentences = map['total_sentences'] ?? 0;
    wordCount = map['word_count'] ?? 0;
    progress = (map['progress'] as num?)?.toDouble() ?? 0.0;
    lastParagraphIndex = map['last_paragraph_index'] ?? map['last_chapter_index'] ?? 0;
    lastSentenceIndex = map['last_sentence_index'] ?? 0;
    lastStudyDate = map['last_study_date'] != null ? DateTime.parse(map['last_study_date']) : null;
    studyCount = map['study_count'] ?? 0;
    orderIndex = map['order_index'] ?? 0;
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
