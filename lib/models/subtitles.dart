import 'package:vidlang/models/base_entity.dart';

/// 字幕片段类型
enum SubtitleType {
  subtitle, // 字幕（默认，用于视频）
  lyric,    // 歌词（用于 MTV）
}

/// 字幕实体类
///
/// 用于存储和管理视频字幕/歌词信息，包括时间轴和文本内容。
/// 支持批量导入 SRT 等格式的字幕文件。
///
/// 主要功能：
/// - 存储字幕时间轴（开始时间、结束时间）
/// - 存储字幕文本内容及翻译
/// - 与视频关联（通过 videoCode）
/// - 支持全文检索
/// - 区分字幕与歌词（type 字段）
///
/// 时间字段说明：
/// - startPosition 和 endPosition 使用毫秒为单位
/// - 用于在播放时精确定位字幕显示
class Subtitles extends BaseEntity {
  /// 视频code（关联 VideoInfo）
  /// 对于 MTV：存储歌词时间轴
  String videoCode;

  /// 字幕开始时间（毫秒）
  num startPosition;

  /// 字幕结束时间（毫秒）
  num endPosition;

  /// 字幕文本内容
  String content;

  /// 字幕翻译文本（默认用于中文翻译）
  String? contentTranslate;

  /// 片段类型：subtitle（字幕）/ lyric（歌词）
  /// 默认为 'subtitle'，保持向后兼容
  String type;

  Subtitles({
    this.videoCode = '',
    this.startPosition = 0,
    this.endPosition = 0,
    this.content = '',
    this.contentTranslate,
    this.type = 'subtitle',
  });

  @override
  String get tableName => 'subtitles';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'video_code': videoCode,
      'start_position': startPosition,
      'end_position': endPosition,
      'content': content,
      'content_translate': contentTranslate,
      'type': type,
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
    videoCode = map['video_code'] ?? '';
    startPosition = map['start_position'] ?? 0;
    endPosition = map['end_position'] ?? 0;
    content = map['content'] ?? '';
    contentTranslate = map['content_translate'];
    type = map['type'] ?? 'subtitle';
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
