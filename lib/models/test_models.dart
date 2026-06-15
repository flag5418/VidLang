import 'package:vidlang/models/base_entity.dart';

// ─── 题型枚举 ───

/// 评测题型标识
enum QuestionType {
  /// 听音选词：TTS 发音 → 从选项中选择正确单词
  listenChoose,

  /// 看义写词：千问生成中文释义 → 用户拼写英文单词
  meaningWrite,

  /// 句中听写：TTS 朗读句子 → 千问语义判分
  sentenceDictation,

  /// 中英互译：千问翻译判分
  translateBoth,

  /// 跟读单词：声通 word.eval
  wordPron,

  /// 跟读短语：声通 sent.eval
  phrasePron,

  /// 句子跟读：声通 sent.eval（长句）
  sentencePron,

  /// 组句题（已有）
  reorder,

  /// 拼写填空（已有）
  spelling,

  /// 选择题（已有）
  mcq,
}

extension QuestionTypeLabel on QuestionType {
  String get label {
    switch (this) {
      case QuestionType.listenChoose:
        return '听音选词';
      case QuestionType.meaningWrite:
        return '看义写词';
      case QuestionType.sentenceDictation:
        return '句中听写';
      case QuestionType.translateBoth:
        return '中英互译';
      case QuestionType.wordPron:
        return '跟读单词';
      case QuestionType.phrasePron:
        return '跟读短语';
      case QuestionType.sentencePron:
        return '句子跟读';
      case QuestionType.reorder:
        return '组句题';
      case QuestionType.spelling:
        return '拼写填空';
      case QuestionType.mcq:
        return '选择题';
    }
  }

  /// 学习目标分组：听 / 读 / 写 / 说
  String get category {
    switch (this) {
      case QuestionType.listenChoose:
      case QuestionType.sentenceDictation:
        return '听';
      case QuestionType.mcq:
      case QuestionType.reorder:
        return '读';
      case QuestionType.spelling:
      case QuestionType.meaningWrite:
      case QuestionType.translateBoth:
        return '写';
      case QuestionType.wordPron:
      case QuestionType.phrasePron:
      case QuestionType.sentencePron:
        return '说';
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
    totalScore = (map['total_score'] as num?)?.toDouble();
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
    score = (map['score'] as num?)?.toDouble();
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
      final map = Map<String, dynamic>.from(
        Uri.base.queryParameters.isEmpty
            ? (RegExp(r'[{}"]').hasMatch(categoryScoresJson!)
                ? _parseJson(categoryScoresJson!)
                : {})
            : {},
      );
      return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  static Map<String, dynamic> _parseJson(String json) {
    // Simple JSON parsing for category scores
    final cleaned = json.replaceAll('{', '').replaceAll('}', '').replaceAll('"', '');
    final pairs = cleaned.split(',');
    final map = <String, dynamic>{};
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        map[parts[0].trim()] = double.tryParse(parts[1].trim()) ?? 0;
      }
    }
    return map;
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
    overallScore = (map['overall_score'] as num?)?.toDouble();
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
}
