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

  /// 评测语言 ('en'|'fr'|'ja'|'ko'|...)
  String? language;

  /// 参考文本（当前字幕行的 content）
  String? refText;

  /// 字幕行索引（scope='sentence' 时使用）
  int? subtitleIndex;

  /// 跟读时原音音量 (0.0-1.0)
  double? originalVolume;

  /// 是否使用耳机模式
  bool? headphoneMode;

  /// 跟读时播放速度
  double? speed;

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
    this.language,
    this.refText,
    this.subtitleIndex,
    this.originalVolume,
    this.headphoneMode,
    this.speed,
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
      'language': language,
      'ref_text': refText,
      'subtitle_index': subtitleIndex,
      'original_volume': originalVolume,
      'headphone_mode': headphoneMode == true ? 1 : 0,
      'speed': speed,
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
    overallScore = _toDouble(map['overall_score']);
    fluencyScore = _toDouble(map['fluency_score']);
    accuracyScore = _toDouble(map['accuracy_score']);
    completenessScore = _toDouble(map['completeness_score']);
    wordScoresJson = map['word_scores_json'];
    rawResultJson = map['raw_result_json'];
    language = map['language'];
    refText = map['ref_text'];
    subtitleIndex = map['subtitle_index'];
    originalVolume = _toDouble(map['original_volume']);
    headphoneMode = map['headphone_mode'] == 1;
    speed = _toDouble(map['speed']);
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

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
