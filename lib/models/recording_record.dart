import 'package:vidlang/models/base_entity.dart';

/// 跟读录音记录实体类
///
/// 记录用户跟读时的录音文件和声通评测结果。
/// 支持全篇/章节/单句三种跟读范围。
class RecordingRecord extends BaseEntity {
  /// 资源 code
  String resourceCode;

  /// 资源类型：video / article / music
  String resourceType;

  /// 跟读范围：full / chapter / sentence
  String scope;

  /// 章节 code（可选，scope 为 chapter 时必填）
  String? chapterCode;

  /// 句子 code（可选，scope 为 sentence 时必填）
  String? sentenceCode;

  /// 录音文件路径
  String audioPath;

  /// 录音时长（毫秒）
  int durationMs;

  /// 总分 0-100
  double? overallScore;

  /// 流利度
  double? fluencyScore;

  /// 准确度
  double? accuracyScore;

  /// 完整度
  double? completenessScore;

  /// 逐词评分 JSON
  String? wordScoresJson;

  /// 声通原始返回 JSON
  String? rawResultJson;

  /// 录音时间
  DateTime recordedAt;

  RecordingRecord({
    this.resourceCode = '',
    this.resourceType = 'video',
    this.scope = 'sentence',
    this.chapterCode,
    this.sentenceCode,
    this.audioPath = '',
    this.durationMs = 0,
    this.overallScore,
    this.fluencyScore,
    this.accuracyScore,
    this.completenessScore,
    this.wordScoresJson,
    this.rawResultJson,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  @override
  String get tableName => 'recording_record';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'resource_code': resourceCode,
      'resource_type': resourceType,
      'scope': scope,
      'chapter_code': chapterCode,
      'sentence_code': sentenceCode,
      'audio_path': audioPath,
      'duration_ms': durationMs,
      'overall_score': overallScore,
      'fluency_score': fluencyScore,
      'accuracy_score': accuracyScore,
      'completeness_score': completenessScore,
      'word_scores_json': wordScoresJson,
      'raw_result_json': rawResultJson,
      'recorded_at': recordedAt.toIso8601String(),
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
    resourceCode = map['resource_code'] ?? '';
    resourceType = map['resource_type'] ?? 'video';
    scope = map['scope'] ?? 'sentence';
    chapterCode = map['chapter_code'];
    sentenceCode = map['sentence_code'];
    audioPath = map['audio_path'] ?? '';
    durationMs = map['duration_ms'] ?? 0;
    overallScore = (map['overall_score'] as num?)?.toDouble();
    fluencyScore = (map['fluency_score'] as num?)?.toDouble();
    accuracyScore = (map['accuracy_score'] as num?)?.toDouble();
    completenessScore = (map['completeness_score'] as num?)?.toDouble();
    wordScoresJson = map['word_scores_json'];
    rawResultJson = map['raw_result_json'];
    recordedAt = map['recorded_at'] != null ? DateTime.parse(map['recorded_at']) : DateTime.now();
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
