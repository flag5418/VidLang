import 'dart:convert';

import 'package:vidlang/models/base_entity.dart';

// ─── 题型枚举 ───

/// 题型维度分类
enum QuestionCategory { listen, read, speak }

/// 评测题型标识
enum QuestionType {
  // ─── 听 ───

  /// 原音选择：播放音频 → 选择当前播放的内容（单选）
  listenChoose,

  /// 听音辩义：播放音频 → 选择和原义类似的解释（单选）
  listenMeaning,

  /// 听音回复：播放问题 → 根据问题选择回答（单选）
  listenReply,

  // ─── 读 ───

  /// 释义选择：英→中 / 中→英（单选，2种子类型）
  definitionChoice,

  /// 拼写填空：挖空单词 → 补全拼写
  spelling,

  /// 组句：打乱词块 → 排列成正确句子
  reorder,

  /// 英义互译：给出英文 → 选择类似含义的解释（单选）
  translateMeaning,

  /// 词性测试：选择同义词/反义词等（多选）
  wordRelation,

  // ─── 说 ───

  /// 跟读单词：声通 word.eval
  wordPron,

  /// 跟读短语：声通 sent.eval
  phrasePron,

  /// 句子跟读：声通 sent.eval（长句）
  sentencePron,

  // ─── 旧版保留（test_home_page 链路使用） ───

  /// @deprecated 看义写词（旧版保留）
  meaningWrite,

  /// @deprecated 句中听写（旧版保留）
  sentenceDictation,

  /// @deprecated 中英互译（旧版保留）
  translateBoth,

  /// @deprecated 选择题（旧版保留，新系统使用 definitionChoice）
  mcq,
}

extension QuestionTypeLabel on QuestionType {
  String get label {
    switch (this) {
      // 听
      case QuestionType.listenChoose:
        return '原音选择';
      case QuestionType.listenMeaning:
        return '听音辩义';
      case QuestionType.listenReply:
        return '听音回复';
      // 读
      case QuestionType.definitionChoice:
        return '释义选择';
      case QuestionType.spelling:
        return '拼写填空';
      case QuestionType.reorder:
        return '组句';
      case QuestionType.translateMeaning:
        return '英义互译';
      case QuestionType.wordRelation:
        return '词性测试';
      // 说
      case QuestionType.wordPron:
        return '跟读单词';
      case QuestionType.phrasePron:
        return '跟读短语';
      case QuestionType.sentencePron:
        return '句子跟读';
      // 旧版
      case QuestionType.meaningWrite:
        return '看义写词';
      case QuestionType.sentenceDictation:
        return '句中听写';
      case QuestionType.translateBoth:
        return '中英互译';
      case QuestionType.mcq:
        return '选择题';
    }
  }

  /// 题型所属维度
  QuestionCategory get category {
    switch (this) {
      case QuestionType.listenChoose:
      case QuestionType.listenMeaning:
      case QuestionType.listenReply:
        return QuestionCategory.listen;
      case QuestionType.definitionChoice:
      case QuestionType.spelling:
      case QuestionType.reorder:
      case QuestionType.translateMeaning:
      case QuestionType.wordRelation:
        return QuestionCategory.read;
      case QuestionType.wordPron:
      case QuestionType.phrasePron:
      case QuestionType.sentencePron:
        return QuestionCategory.speak;
      // 旧版归类到读
      case QuestionType.meaningWrite:
      case QuestionType.sentenceDictation:
      case QuestionType.translateBoth:
      case QuestionType.mcq:
        return QuestionCategory.read;
    }
  }

  /// 题型作答说明
  String get description {
    switch (this) {
      case QuestionType.listenChoose:
        return '播放音频，选择当前播放的内容';
      case QuestionType.listenMeaning:
        return '播放音频，选择和原义类似的解释';
      case QuestionType.listenReply:
        return '播放一个问题，根据听到的内容选择回答';
      case QuestionType.definitionChoice:
        return '根据给出的单词或翻译，选择正确的释义';
      case QuestionType.spelling:
        return '根据句子提示，拼写缺失的单词';
      case QuestionType.reorder:
        return '将打乱的词块排列成正确语序的句子';
      case QuestionType.translateMeaning:
        return '阅读英文段落，选择与原文类似的中文解释';
      case QuestionType.wordRelation:
        return '根据单词选择同义词、反义词等（可多选）';
      case QuestionType.wordPron:
        return '跟读展示的单词，录音评分';
      case QuestionType.phrasePron:
        return '跟读展示的短语，录音评分';
      case QuestionType.sentencePron:
        return '跟读展示的句子，录音评分';
      case QuestionType.meaningWrite:
        return '根据中文释义拼写英文单词';
      case QuestionType.sentenceDictation:
        return '听句子，写出你听到的内容';
      case QuestionType.translateBoth:
        return '将英文翻译为中文或中文翻译为英文';
      case QuestionType.mcq:
        return '从选项中选择正确答案';
    }
  }
}

// ─── 评测主记录 ───

class TestSession extends BaseEntity {
  String testType;
  DateTime startedAt;
  DateTime? completedAt;
  String status;
  double? totalScore;
  int durationSeconds;
  int totalItems;
  int completedItems;
  String difficulty;
  String? resourceCode;
  String? resourceType;
  String meta;

  TestSession({
    this.testType = 'mixed',
    DateTime? startedAt,
    this.completedAt,
    this.status = 'in_progress',
    this.totalScore,
    this.durationSeconds = 0,
    this.totalItems = 0,
    this.completedItems = 0,
    this.difficulty = 'intermediate',
    this.resourceCode,
    this.resourceType,
    this.meta = '',
  }) : startedAt = startedAt ?? DateTime.now();

  @override
  String get tableName => 'test_session';

  double get progress =>
      totalItems > 0 ? completedItems / totalItems : 0.0;

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'user_code': userCode,
        'test_type': testType,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'status': status,
        'total_score': totalScore,
        'duration_seconds': durationSeconds,
        'total_items': totalItems,
        'completed_items': completedItems,
        'difficulty': difficulty,
        'resource_code': resourceCode,
        'resource_type': resourceType,
        'meta': meta,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
        'created_by': createdBy,
        'updated_by': updatedBy,
        'deleted_by': deletedBy,
      };

  @override
  BaseEntity fromMap(Map<String, dynamic> map) {
    id = map['id'];
    code = map['code'];
    userCode = map['user_code'];
    testType = map['test_type'] ?? 'mixed';
    startedAt = map['started_at'] != null
        ? DateTime.parse(map['started_at'])
        : DateTime.now();
    completedAt = map['completed_at'] != null
        ? DateTime.parse(map['completed_at'])
        : null;
    status = map['status'] ?? 'in_progress';
    totalScore = _toDouble(map['total_score']);
    durationSeconds = map['duration_seconds'] ?? 0;
    totalItems = map['total_items'] ?? 0;
    completedItems = map['completed_items'] ?? 0;
    difficulty = map['difficulty'] ?? 'intermediate';
    resourceCode = map['resource_code'];
    resourceType = map['resource_type'];
    meta = map['meta'] ?? '';
    createdAt = map['created_at'] != null
        ? DateTime.parse(map['created_at'])
        : null;
    updatedAt = map['updated_at'] != null
        ? DateTime.parse(map['updated_at'])
        : null;
    deletedAt = map['deleted_at'] != null
        ? DateTime.parse(map['deleted_at'])
        : null;
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

// ─── 单题记录 ───

class TestItem extends BaseEntity {
  int testSessionId;
  String questionType;
  int itemOrder;
  String refText;
  String prompt;
  String? promptAudioPath;
  String? correctAnswer;
  String? userAnswer;
  String? userAudioPath;
  double? score;
  bool? isCorrect;
  String? rawResult;
  String? aiAnalysis;
  String? distractorsJson;

  TestItem({
    this.testSessionId = 0,
    this.questionType = 'mcq',
    this.itemOrder = 0,
    this.refText = '',
    this.prompt = '',
    this.promptAudioPath,
    this.correctAnswer,
    this.userAnswer,
    this.userAudioPath,
    this.score,
    this.isCorrect,
    this.rawResult,
    this.aiAnalysis,
    this.distractorsJson,
  });

  QuestionType get type => QuestionType.values.firstWhere(
        (t) => t.name == questionType,
        orElse: () => QuestionType.mcq,
      );

  @override
  String get tableName => 'test_item';

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'user_code': userCode,
        'test_session_id': testSessionId,
        'question_type': questionType,
        'item_order': itemOrder,
        'ref_text': refText,
        'prompt': prompt,
        'prompt_audio_path': promptAudioPath,
        'correct_answer': correctAnswer,
        'user_answer': userAnswer,
        'user_audio_path': userAudioPath,
        'score': score,
        'is_correct': isCorrect == true ? 1 : 0,
        'raw_result': rawResult,
        'ai_analysis': aiAnalysis,
        'distractors_json': distractorsJson,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
        'created_by': createdBy,
        'updated_by': updatedBy,
        'deleted_by': deletedBy,
      };

  @override
  BaseEntity fromMap(Map<String, dynamic> map) {
    id = map['id'];
    code = map['code'];
    userCode = map['user_code'];
    testSessionId = map['test_session_id'] ?? 0;
    questionType = map['question_type'] ?? 'mcq';
    itemOrder = map['item_order'] ?? 0;
    refText = map['ref_text'] ?? '';
    prompt = map['prompt'] ?? '';
    promptAudioPath = map['prompt_audio_path'];
    correctAnswer = map['correct_answer'];
    userAnswer = map['user_answer'];
    userAudioPath = map['user_audio_path'];
    score = _toDouble(map['score']);
    isCorrect = map['is_correct'] == 1;
    rawResult = map['raw_result'];
    aiAnalysis = map['ai_analysis'];
    distractorsJson = map['distractors_json'];
    createdAt = map['created_at'] != null
        ? DateTime.parse(map['created_at'])
        : null;
    updatedAt = map['updated_at'] != null
        ? DateTime.parse(map['updated_at'])
        : null;
    deletedAt = map['deleted_at'] != null
        ? DateTime.parse(map['deleted_at'])
        : null;
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

// ─── AI 评价报告 ───

class TestEvaluation extends BaseEntity {
  int testSessionId;
  double? overallScore;
  String? categoryScoresJson;
  String? weakPoints;
  String? suggestions;
  String? comparisonJson;

  TestEvaluation({
    this.testSessionId = 0,
    this.overallScore,
    this.categoryScoresJson,
    this.weakPoints,
    this.suggestions,
    this.comparisonJson,
  });

  Map<String, double> get categoryScores {
    if (categoryScoresJson == null || categoryScoresJson!.isEmpty) return {};
    try {
      final decoded = jsonDecode(categoryScoresJson!);
      if (decoded is Map<String, dynamic>) {
        return decoded.map((k, v) => MapEntry(k, v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0 : 0)));
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  @override
  String get tableName => 'test_evaluation';

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'user_code': userCode,
        'test_session_id': testSessionId,
        'overall_score': overallScore,
        'category_scores_json': categoryScoresJson,
        'weak_points': weakPoints,
        'suggestions': suggestions,
        'comparison_json': comparisonJson,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'deleted_at': deletedAt?.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
        'created_by': createdBy,
        'updated_by': updatedBy,
        'deleted_by': deletedBy,
      };

  @override
  BaseEntity fromMap(Map<String, dynamic> map) {
    id = map['id'];
    code = map['code'];
    userCode = map['user_code'];
    testSessionId = map['test_session_id'] ?? 0;
    overallScore = _toDouble(map['overall_score']);
    categoryScoresJson = map['category_scores_json'];
    weakPoints = map['weak_points'];
    suggestions = map['suggestions'];
    comparisonJson = map['comparison_json'];
    createdAt = map['created_at'] != null
        ? DateTime.parse(map['created_at'])
        : null;
    updatedAt = map['updated_at'] != null
        ? DateTime.parse(map['updated_at'])
        : null;
    deletedAt = map['deleted_at'] != null
        ? DateTime.parse(map['deleted_at'])
        : null;
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
