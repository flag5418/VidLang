import 'package:vidlang/models/base_entity.dart';

/// 单词本实体类
///
/// 替代/扩展 participle，支持跨来源（视频/文章/歌曲）收藏和复习。
/// 通过 content_type 区分三种收藏类型：
/// - word: 单词 → 生词本（带等级标签）
/// - sentence: 句子 → 知识库（带自定义标签）
/// - phrase: 短语 → 短语本（Phase 2）
///
/// 主状态仅保留 learning / mastered 两档。
class WordBook extends BaseEntity {
  /// 单词/短语/句子原文
  String word;

  /// 收藏类型：word / sentence / phrase
  String contentType;

  /// 收藏的原始文本（句子/短语收藏时的完整原文）
  String? sourceText;

  /// 对应的翻译文本
  String? sourceTranslation;

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

  /// 截图路径（视频/音频收藏时截取当前画面）
  String? screenshotPath;

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

  /// 掌握程度：learning / mastered
  String masteryLevel;

  /// 掌握时间
  DateTime? masteredAt;

  /// 词形变化缓存 JSON
  String? morphologyJson;

  /// 助记缓存
  String? mnemonic;

  /// 用户手动添加的备注/注释
  String? note;

  WordBook({
    this.word = '',
    this.contentType = 'word',
    this.sourceText,
    this.sourceTranslation,
    this.sourceType = 'video',
    this.sourceCode = '',
    this.sourceTitle,
    this.segmentCode,
    this.contextSentence,
    this.screenshotPath,
    this.definitionsJson,
    this.phoneticUk,
    this.phoneticUs,
    this.difficulty = 1,
    this.reviewCount = 0,
    this.correctCount = 0,
    this.lastReviewAt,
    this.nextReviewAt,
    this.masteryLevel = 'learning',
    this.masteredAt,
    this.morphologyJson,
    this.mnemonic,
    this.note,
  });

  bool get isLearning => masteryLevel == 'learning';

  bool get isMastered => masteryLevel == 'mastered';

  static String normalizeMasteryLevel(String? raw) {
    if (raw == 'mastered') return 'mastered';
    return 'learning';
  }

  @override
  String get tableName => 'word_book';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'word': word,
      'content_type': contentType,
      'source_text': sourceText,
      'source_translation': sourceTranslation,
      'source_type': sourceType,
      'source_code': sourceCode,
      'source_title': sourceTitle,
      'segment_code': segmentCode,
      'context_sentence': contextSentence,
      'screenshot_path': screenshotPath,
      'definitions_json': definitionsJson,
      'phonetic_uk': phoneticUk,
      'phonetic_us': phoneticUs,
      'difficulty': difficulty,
      'review_count': reviewCount,
      'correct_count': correctCount,
      'last_review_at': lastReviewAt?.toIso8601String(),
      'next_review_at': nextReviewAt?.toIso8601String(),
      'mastery_level': normalizeMasteryLevel(masteryLevel),
      'mastered_at': masteredAt?.toIso8601String(),
      'morphology_json': morphologyJson,
      'mnemonic': mnemonic,
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
    word = map['word'] ?? '';
    contentType = map['content_type'] ?? 'word';
    sourceText = map['source_text'];
    sourceTranslation = map['source_translation'];
    sourceType = map['source_type'] ?? 'video';
    sourceCode = map['source_code'] ?? '';
    sourceTitle = map['source_title'];
    segmentCode = map['segment_code'];
    contextSentence = map['context_sentence'];
    screenshotPath = map['screenshot_path'];
    definitionsJson = map['definitions_json'];
    phoneticUk = map['phonetic_uk'];
    phoneticUs = map['phonetic_us'];
    difficulty = map['difficulty'] ?? 1;
    reviewCount = map['review_count'] ?? 0;
    correctCount = map['correct_count'] ?? 0;
    lastReviewAt = map['last_review_at'] != null ? DateTime.parse(map['last_review_at']) : null;
    nextReviewAt = map['next_review_at'] != null ? DateTime.parse(map['next_review_at']) : null;
    masteryLevel = normalizeMasteryLevel(map['mastery_level'] as String?);
    masteredAt = map['mastered_at'] != null ? DateTime.parse(map['mastered_at']) : null;
    morphologyJson = map['morphology_json'];
    mnemonic = map['mnemonic'];
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
}
