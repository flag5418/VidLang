import 'package:vidlang/models/base_entity.dart';

class AiEvaluationLog extends BaseEntity {
  String resourceCode;
  String resourceType;
  String? resourceTitle;
  String language;
  double? sentenceFollowAvgScore;
  int sentenceFollowCount;
  double? fullFollowAvgScore;
  int fullFollowCount;
  double? resourceScore;
  String evaluationJson;
  String? summary;
  String? overallLevel;
  double? costCny;
  DateTime evaluatedAt;

  AiEvaluationLog({
    this.resourceCode = '',
    this.resourceType = 'music',
    this.resourceTitle,
    this.language = 'en',
    this.sentenceFollowAvgScore,
    this.sentenceFollowCount = 0,
    this.fullFollowAvgScore,
    this.fullFollowCount = 0,
    this.resourceScore,
    this.evaluationJson = '',
    this.summary,
    this.overallLevel,
    this.costCny,
    DateTime? evaluatedAt,
  }) : evaluatedAt = evaluatedAt ?? DateTime.now();

  @override
  String get tableName => 'ai_evaluation_log';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'resource_code': resourceCode,
      'resource_type': resourceType,
      'resource_title': resourceTitle,
      'language': language,
      'sentence_follow_avg_score': sentenceFollowAvgScore,
      'sentence_follow_count': sentenceFollowCount,
      'full_follow_avg_score': fullFollowAvgScore,
      'full_follow_count': fullFollowCount,
      'resource_score': resourceScore,
      'evaluation_json': evaluationJson,
      'summary': summary,
      'overall_level': overallLevel,
      'cost_cny': costCny,
      'evaluated_at': evaluatedAt.toIso8601String(),
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
    resourceType = map['resource_type'] ?? 'music';
    resourceTitle = map['resource_title'];
    language = map['language'] ?? 'en';
    sentenceFollowAvgScore = (map['sentence_follow_avg_score'] as num?)?.toDouble();
    sentenceFollowCount = map['sentence_follow_count'] ?? 0;
    fullFollowAvgScore = (map['full_follow_avg_score'] as num?)?.toDouble();
    fullFollowCount = map['full_follow_count'] ?? 0;
    resourceScore = (map['resource_score'] as num?)?.toDouble();
    evaluationJson = map['evaluation_json'] ?? '';
    summary = map['summary'];
    overallLevel = map['overall_level'];
    costCny = (map['cost_cny'] as num?)?.toDouble();
    evaluatedAt = map['evaluated_at'] != null ? DateTime.parse(map['evaluated_at']) : DateTime.now();
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
