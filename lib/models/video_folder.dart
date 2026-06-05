import 'package:vidlang/models/base_entity.dart';

/// 文件夹内容类型
enum FolderContentType {
  video,    // 视频文件夹（默认）
  article,  // 文章文件夹
  music,    // 歌曲/MTV文件夹
}

/// 视频文件夹类型
/// - [virtual]: 虚拟视频集，媒体文件在用户目录（导入不搬家）
/// - [real]: WiFi 等托管目录（文件在应用目录）
enum VideoFolderType { virtual, real }

/// 兼容旧库中的 type 索引：0 曾为 local，现视为 virtual
VideoFolderType videoFolderTypeFromIndex(int index) {
  if (index == 1) return VideoFolderType.real;
  return VideoFolderType.virtual;
}

/// 资源文件夹实体类
///
/// 用于管理和组织视频/文章/音乐文件，支持本地存储和虚拟分组两种模式。
/// 通过 [folderType] 区分文件夹内容类型。
///
/// 主要功能：
/// - 管理文件夹名称和层级关系
/// - 跟踪资源数量和完成进度
/// - 记录最后播放的资源进度
/// - 配置播放参数（片头/片尾跳过、封面截图时间）
class VideoFolder extends BaseEntity {
  /// 文件夹名称
  String name;

  /// 文件夹路径（本地文件夹使用）
  String path;

  /// 父文件夹code（用于支持文件夹层级）
  String? parentCode;

  /// 文件夹类型：本地或虚拟
  VideoFolderType type;

  /// 文件夹内容类型：video / article / music
  /// 默认为 video，保持向后兼容
  FolderContentType folderType;

  /// 视频总数（视频/音乐模式时有效）
  int videoCount;

  /// 已完成播放的资源数
  int completedCount;

  /// 文件夹封面图片路径
  String? cover;

  /// 最后播放的资源code
  String? lastVideoCode;

  /// 最后播放时间
  DateTime? lastPlayDate;

  /// 最后播放进度（毫秒）
  int lastPlayDuration;

  /// 是否启用片头跳过功能
  bool skipOpening;

  /// 片头跳过时长（秒）
  int skipOpeningDuration;

  /// 封面截图时间点（秒）
  int thumbnailTime;

  /// 是否启用片尾跳过功能
  bool skipEnding;

  /// 片尾跳过时长（秒）
  int skipEndingDuration;

  VideoFolder({
    this.name = '',
    this.path = '',
    this.parentCode,
    this.type = VideoFolderType.virtual,
    this.folderType = FolderContentType.video,
    this.videoCount = 0,
    this.completedCount = 0,
    this.cover,
    this.lastVideoCode,
    this.lastPlayDate,
    this.lastPlayDuration = 0,
    this.skipOpening = false,
    this.skipOpeningDuration = 0,
    this.thumbnailTime = 15,
    this.skipEnding = false,
    this.skipEndingDuration = 0,
  });

  @override
  String get tableName => 'video_folder';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'name': name,
      'path': path,
      'parent_code': parentCode,
      'type': type.index,
      'folder_type': folderType.name,
      'video_count': videoCount,
      'completed_count': completedCount,
      'cover': cover,
      'last_video_code': lastVideoCode,
      'last_play_date': lastPlayDate?.toIso8601String(),
      'last_play_duration': lastPlayDuration,
      'skip_opening': skipOpening ? 1 : 0,
      'skip_opening_duration': skipOpeningDuration,
      'thumbnail_time': thumbnailTime,
      'skip_ending': skipEnding ? 1 : 0,
      'skip_ending_duration': skipEndingDuration,
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
    name = map['name'] ?? '';
    path = map['path'] ?? '';
    parentCode = map['parent_code'];
    type = videoFolderTypeFromIndex(map['type'] ?? 0);
    folderType = FolderContentType.values.firstWhere(
      (e) => e.name == map['folder_type'],
      orElse: () => FolderContentType.video,
    );
    videoCount = map['video_count'] ?? 0;
    completedCount = map['completed_count'] ?? 0;
    cover = map['cover'];
    lastVideoCode = map['last_video_code'];
    lastPlayDate = map['last_play_date'] != null ? DateTime.parse(map['last_play_date']) : null;
    lastPlayDuration = map['last_play_duration'] ?? 0;
    skipOpening = map['skip_opening'] == 1;
    skipOpeningDuration = map['skip_opening_duration'] ?? 0;
    thumbnailTime = map['thumbnail_time'] ?? 15;
    skipEnding = map['skip_ending'] == 1;
    skipEndingDuration = map['skip_ending_duration'] ?? 0;
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
