import 'package:vidlang/models/base_entity.dart';

/// 视频信息实体类
/// 
/// 用于存储和管理视频文件的元数据信息，包括播放进度、封面、学习统计等。
/// 每个视频归属于一个文件夹（通过 folderCode 关联）。
/// 
/// 主要功能：
/// - 视频基本信息管理（名称、时长、格式）
/// - 播放进度跟踪（当前位置、是否正在播放）
/// - 封面和截图管理（导入封面、播放中截图）
/// - 学习统计（播放次数、总学习时长）
/// - 字幕状态跟踪
/// 
/// 时间字段说明：
/// - 所有时长字段使用毫秒（milliseconds）为单位
/// - 使用 [DurationHelper] 进行时长格式化转换
/// 
/// 示例：
/// ```dart
/// final video = VideoInfo(
///   name: 'Lesson 01 - Greetings',
///   folderCode: 'folder_1',
///   duration: 15 * 60 * 1000 + 30 * 1000, // 15分30秒
///   hasSubtitles: true,
/// );
/// ```
class VideoInfo extends BaseEntity {
  /// 视频名称
  String name;
  
  /// 所属文件夹的code
  String folderCode;
  
  /// 视频文件实际路径（虚拟视频集不复制文件，仅存此路径）
  String filePath;

  /// 文件类型：virtual（仅保存设备路径） / real（存储在应用沙盒）
  String fileType;

  /// 关联字幕文件路径（可选，用于手动重选字幕）
  String? subtitlePath;

  /// 视频文件扩展名（如 .mp4, .mov）
  String extensionName;
  
  /// 视频总时长（毫秒）
  int duration;
  
  /// 视频封面图片路径
  /// 
  /// 导入视频时自动截取，默认在视频第15秒处截图
  String? cover;
  
  /// 是否包含字幕
  /// 
  /// 用于标记该视频是否有可用的字幕文件
  bool hasSubtitles;
  
  /// 当前播放位置（毫秒）
  /// 
  /// 用于记录和恢复播放进度
  int currentPosition;
  
  /// 是否为当前正在播放的视频
  /// 
  /// 同一文件夹下只有一个视频可以标记为当前播放
  bool isCurrentPlaying;
  
  /// 视频描述/简介
  String description;
  
  /// 最后播放时间
  /// 
  /// 用于按最近播放排序
  DateTime? playDate;
  
  /// 排序索引
  /// 
  /// 用于手动排序视频顺序
  int orderIndex;
  
  /// 当前视频截图路径
  /// 
  /// 播放过程中用户手动截取的图片
  String? currentCover;
  
  /// 总播放次数
  /// 
  /// 每次切换到该视频播放时 +1
  int playCount;
  
  /// 总学习时长（秒）
  /// 
  /// 累计播放时长的总和（不含重复计算）
  int totalPlayDuration;

  VideoInfo({
    this.name = '',
    this.folderCode = '',
    this.filePath = '',
    this.fileType = 'virtual',
    this.subtitlePath,
    this.extensionName = '',
    this.duration = 0,
    this.cover,
    this.hasSubtitles = false,
    this.currentPosition = 0,
    this.isCurrentPlaying = false,
    this.description = '',
    this.playDate,
    this.orderIndex = 0,
    this.currentCover,
    this.playCount = 0,
    this.totalPlayDuration = 0,
  });

  @override
  String get tableName => 'video_info';

  /// 将时长（毫秒）格式化为可读字符串
  /// 
  /// 格式：HH:MM:SS 或 MM:SS（不足1小时时）
  /// 
  /// 示例：
  /// - 0 -> "00:00"
  /// - 60000 -> "01:00"
  /// - 3661000 -> "01:01:01"
  String get durationString => DurationHelper.formatMilliseconds(duration);

  /// 将当前播放位置格式化为可读字符串
  String get currentPositionString => DurationHelper.formatMilliseconds(currentPosition);

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'user_code': userCode,
      'name': name,
      'folder_code': folderCode,
      'file_path': filePath,
      'file_type': fileType,
      'subtitle_path': subtitlePath,
      'extension_name': extensionName,
      'duration': duration,
      'cover': cover,
      'has_subtitles': hasSubtitles ? 1 : 0,
      'current_position': currentPosition,
      'is_current_playing': isCurrentPlaying ? 1 : 0,
      'description': description,
      'play_date': playDate?.toIso8601String(),
      'order_index': orderIndex,
      'current_cover': currentCover,
      'play_count': playCount,
      'total_play_duration': totalPlayDuration,
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
    folderCode = map['folder_code'] ?? '';
    filePath = map['file_path'] ?? '';
    fileType = map['file_type'] ?? 'virtual';
    subtitlePath = map['subtitle_path'];
    extensionName = map['extension_name'] ?? '';
    duration = map['duration'] ?? 0;
    cover = map['cover'];
    hasSubtitles = map['has_subtitles'] == 1;
    currentPosition = map['current_position'] ?? 0;
    isCurrentPlaying = map['is_current_playing'] == 1;
    description = map['description'] ?? '';
    playDate = map['play_date'] != null ? DateTime.parse(map['play_date']) : null;
    orderIndex = map['order_index'] ?? 0;
    currentCover = map['current_cover'];
    playCount = map['play_count'] ?? 0;
    totalPlayDuration = map['total_play_duration'] ?? 0;
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

/// 时长格式化工具类
/// 
/// 提供毫秒与可读时间字符串之间的转换功能
class DurationHelper {
  /// 将毫秒转换为时分秒格式字符串
  /// 
  /// [milliseconds] 时间长度（毫秒）
  /// 
  /// 返回格式：
  /// - 不足1小时：MM:SS（如 05:30）
  /// - 超过1小时：HH:MM:SS（如 01:05:30）
  static String formatMilliseconds(int milliseconds) {
    if (milliseconds <= 0) return '00:00';
    
    int totalSeconds = (milliseconds / 1000).floor();
    int hours = (totalSeconds / 3600).floor();
    int minutes = ((totalSeconds % 3600) / 60).floor();
    int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// 将时分秒格式字符串转换为毫秒
  /// 
  /// [timeString] 时间字符串，支持格式：
  /// - MM:SS（如 05:30）
  /// - HH:MM:SS（如 01:05:30）
  /// 
  /// 返回毫秒值，解析失败返回 0
  static int parseToMilliseconds(String timeString) {
    List<String> parts = timeString.split(':');
    if (parts.length == 2) {
      int minutes = int.tryParse(parts[0]) ?? 0;
      int seconds = int.tryParse(parts[1]) ?? 0;
      return (minutes * 60 + seconds) * 1000;
    } else if (parts.length == 3) {
      int hours = int.tryParse(parts[0]) ?? 0;
      int minutes = int.tryParse(parts[1]) ?? 0;
      int seconds = int.tryParse(parts[2]) ?? 0;
      return (hours * 3600 + minutes * 60 + seconds) * 1000;
    }
    return 0;
  }
}
