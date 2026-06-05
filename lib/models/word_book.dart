import 'package:vidlang/models/base_entity.dart';

/// 单词本实体类
///
/// 替代/扩展 participle，支持跨来源（视频/文章/歌曲）收藏和复习。
/// 使用间隔重复算法（SM-2）安排复习计划。
class WordBook extends BaseEntity {
  /// 单词
  String word;

  /// 来源类型：video / article / music
  String sourceType;

  /// 来源资源 code
  String sourceCode;

  /// 来源标题（缓存展示用）
  String? sourceTitle;

  /// 来源句子/字幕 code
  String? segmentCode;

  /// 上下文句子原文
  String? contextSentence;

  /// DeepSeek 查询结果缓存（JSON）
  String? definitionsJson;

  /// 英式音标
  String? phoneticUk;

  /// 美式音标
  String? phoneticUs;

  /// 难度 1-5
  int difficulty;

  /// 复习次数
  int reviewCount;

  /// 答对次数
  int correctCount;

  /// 最后复习时间
  DateTime? lastReviewAt;

  /// 下次复习时间（间隔重复）
  DateTime? nextReviewAt;

  /// 掌握程度：learning / reviewing / mastered
  String masteryLevel;

  WordBook({
    this.word = '',
    this.sourceType = 'video',
    this.sourceCode = '',
    this.sourceTitle,
    this.segmentCode,
    this.contextSentence,
    this.definitionsJson,
    this.phoneticUk,
    this.phoneticUs,
    this.difficulty = 1,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.lastReviewAt,
    this.nextReviewAt,
    this.masteryLevel = 'learning',
  });

  @override
  String get tableName => 'word_book';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'word': word,
      'source_type': sourceType,
      'source_code': sourceCode,
      'source_title': sourceTitle,
      'segment_code': segmentCode,
      'context_sentence': contextSentence,
      'definitions_json': definitionsJson,
      'phonetic_uk': phoneticUk,
      'phonetic_us': phoneticUs,
      'difficulty': difficulty,
      'review_count': reviewCount,
      'correct_count': correctCount,
      'last_review_at': lastReviewAt?.toIso8601String(),
      'next_review_at': nextReviewAt?.toIso8601String(),
      'mastery_level': masteryLevel,
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
    word = map['word'] ?? '';
    sourceType = map['source_type'] ?? 'video';
    sourceCode = map['source_code'] ?? '';
    sourceTitle = map['source_title'];
    segmentCode = map['segment_code'];
    contextSentence = map['context_sentence'];
    definitionsJson = map['definitions_json'];
    phoneticUk = map['phonetic_uk'];
    phoneticUs = map['phonetic_us'];
    difficulty = map['difficulty'] ?? 1;
    reviewCount = map['review_count'] ?? 0;
    correctCount = map['correct_count'] ?? 0;
    lastReviewAt = map['last_review_at'] != null ? DateTime.parse(map['last_review_at']) : null;
    nextReviewAt = map['next_review_at'] != null ? DateTime.parse(map['next_review_at']) : null;
    masteryLevel = map['mastery_level'] ?? 'learning';
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
