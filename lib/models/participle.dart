import 'package:vidlang/models/base_entity.dart';

/// 分词实体类
/// 
/// 用于存储和管理字幕的分词信息，将字幕文本拆分成单个单词或词组。
/// 支持单词学习、查询和复习功能。
/// 
/// 主要功能：
/// - 存储分词内容
/// - 与视频和字幕关联
/// - 支持全文检索
/// - 方便单词复习和学习追踪
/// 
/// 数据来源：
/// - 导入字幕时自动分词
/// - 用户可以手动添加或修正分词
/// 
/// 示例：
/// ```dart
/// final word = Participle(
///   videoCode: 'video_123',
///   subtitlesCode: 'subtitle_456',
///   content: 'hello',
/// );
/// ```
class Participle extends BaseEntity {
  /// 视频code（关联 VideoInfo）
  String videoCode;
  
  /// 字幕code（关联 Subtitles）
  String subtitlesCode;
  
  /// 分词内容
  /// 
  /// 通常是单个单词，也可以是短语
  String content;

  Participle({
    this.videoCode = '',
    this.subtitlesCode = '',
    this.content = '',
  });

  @override
  String get tableName => 'participle';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'video_code': videoCode,
      'subtitles_code': subtitlesCode,
      'content': content,
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
    subtitlesCode = map['subtitles_code'] ?? '';
    content = map['content'] ?? '';
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
