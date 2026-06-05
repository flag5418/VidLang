import 'package:vidlang/models/base_entity.dart';

/// 学习记录实体类
///
/// 用于记录用户学习视频/文章/歌曲的详细情况。
/// 向后兼容：保留 video_code 字段以便读取旧数据，
/// 新数据优先使用 resource_code + resource_type。
class StudyRecord extends BaseEntity {
  /// 资源 code（关联 video_info.code / article.code）
  /// 新数据使用此字段，替代原有的 videoCode
  String resourceCode;

  /// 资源类型：video / article / music
  String resourceType;

  /// 所属文件夹 code
  String folderCode;

  /// 学习日期（用于按日期分组统计）
  DateTime date;

  /// 学习开始时间
  DateTime startTime;

  /// 学习结束时间（可选，学习中为 null）
  DateTime? endTime;

  /// 学习时长（秒）
  int duration;

  /// 完整播放次数
  int playCount;

  /// 学习进度（本次学习了多少句/条）
  int segmentsStudied;

  /// 收藏单词数
  int wordsSaved;

  /// 测试得分（可选）
  double? testScore;

  /// 跟读次数
  int followCount;

  /// 最佳跟读分数
  double? bestFollowScore;

  /// 旧版视频 code（保留向后兼容）
  /// 读数据时如果 resource_code 为空，用此字段回退
  String? videoCode;

  StudyRecord({
    this.resourceCode = '',
    this.resourceType = 'video',
    this.folderCode = '',
    DateTime? date,
    DateTime? startTime,
    this.endTime,
    this.duration = 0,
    this.playCount = 0,
    this.segmentsStudied = 0,
    this.wordsSaved = 0,
    this.testScore,
    this.followCount = 0,
    this.bestFollowScore,
    this.videoCode,
  })  : date = date ?? DateTime.now(),
      startTime = startTime ?? DateTime.now();

  @override
  String get tableName => 'study_record';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'resource_code': resourceCode,
      'resource_type': resourceType,
      'folder_code': folderCode,
      'video_code': videoCode,
      'date': date.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration': duration,
      'play_count': playCount,
      'segments_studied': segmentsStudied,
      'words_saved': wordsSaved,
      'test_score': testScore,
      'follow_count': followCount,
      'best_follow_score': bestFollowScore,
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

    // 向后兼容：优先 resource_code，回退到 video_code
    resourceCode = map['resource_code'] ?? map['video_code'] ?? '';
    resourceType = map['resource_type'] ?? 'video';
    folderCode = map['folder_code'] ?? '';

    // 保留旧 video_code 作为回退
    videoCode = map['video_code'];

    date = map['date'] != null ? DateTime.parse(map['date']) : DateTime.now();
    startTime = map['start_time'] != null ? DateTime.parse(map['start_time']) : DateTime.now();
    endTime = map['end_time'] != null ? DateTime.parse(map['end_time']) : null;
    duration = map['duration'] ?? 0;
    playCount = map['play_count'] ?? 0;
    segmentsStudied = map['segments_studied'] ?? 0;
    wordsSaved = map['words_saved'] ?? 0;
    testScore = (map['test_score'] as num?)?.toDouble();
    followCount = map['follow_count'] ?? 0;
    bestFollowScore = (map['best_follow_score'] as num?)?.toDouble();
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
