import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/participle.dart';
import 'package:vidlang/models/playback_settings.dart';
import 'package:vidlang/models/study_record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/folder_stats_service.dart';
import 'package:vidlang/services/settings_service.dart';
import 'package:vidlang/services/file_picker_service.dart';
import 'package:vidlang/services/thumbnail_service.dart';

/// 文件管理 Provider
///
/// 使用 Riverpod 状态管理，提供文件夹和视频文件的全局状态管理
final fileProvider = StateNotifierProvider<FileNotifier, FileState>((ref) {
  return FileNotifier();
});

/// 文件状态类
///
/// 存储当前应用的文件相关状态，包括：
/// - 文件夹列表
/// - 当前选中的文件夹
/// - 视频列表
/// - 当前播放的视频
/// - 加载状态和错误信息
class FileState {
  /// 文件夹列表
  final List<VideoFolder> folders;

  /// 当前选中的文件夹
  final VideoFolder? currentFolder;

  /// 当前文件夹下的视频列表
  final List<VideoInfo> videos;

  /// 当前正在播放的视频
  final VideoInfo? currentVideo;

  /// 是否正在加载数据
  final bool isLoading;

  /// 错误信息
  final String? error;

  FileState({this.folders = const [], this.currentFolder, this.videos = const [], this.currentVideo, this.isLoading = false, this.error});

  /// 复制并返回新状态
  FileState copyWith({
    List<VideoFolder>? folders,
    VideoFolder? currentFolder,
    List<VideoInfo>? videos,
    VideoInfo? currentVideo,
    bool? isLoading,
    String? error,
  }) {
    return FileState(
      folders: folders ?? this.folders,
      currentFolder: currentFolder ?? this.currentFolder,
      videos: videos ?? this.videos,
      currentVideo: currentVideo ?? this.currentVideo,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// 文件状态管理器
///
/// 负责处理所有文件夹和视频文件相关的业务逻辑：
/// - 文件夹的增删改查
/// - 视频文件的增删改查
/// - 播放状态管理
/// - 学习记录管理
/// - 播放进度更新
class FileNotifier extends StateNotifier<FileState> {
  FileNotifier() : super(FileState(folders: [], videos: []));

  Future<List<String>> _sandboxPrefixes() async {
    final docs = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    final a = docs.path.replaceAll('\\', '/');
    final b = support.path.replaceAll('\\', '/');
    return [a, b];
  }

  bool _startsWithAnyPrefix(String path, List<String> prefixes) {
    final p = path.replaceAll('\\', '/');
    for (final prefix in prefixes) {
      if (p.startsWith(prefix)) return true;
    }
    return false;
  }

  bool _shouldDeletePhysicalPath({required VideoFolder folder, required String path, required List<String> sandboxPrefixes}) {
    if (path.isEmpty) return false;
    if (folder.type == VideoFolderType.real) return true;
    return _startsWithAnyPrefix(path, sandboxPrefixes);
  }

  bool _shouldDeletePhysicalPathForVideo({
    required VideoFolder folder,
    required VideoInfo video,
    required String path,
    required List<String> sandboxPrefixes,
  }) {
    if (path.isEmpty) return false;
    final isReal = folder.type == VideoFolderType.real || video.fileType == 'real';
    if (isReal) return true;
    return _startsWithAnyPrefix(path, sandboxPrefixes);
  }

  Future<void> refreshFoldersSilently() async {
    try {
      await migrateLegacyLeafFolders();
      List<VideoFolder> folders = await DatabaseService.findByCondition(
        () => VideoFolder(),
        where: "is_deleted = 0 AND parent_code IS NOT NULL AND parent_code != ''",
        orderBy: 'CASE WHEN last_play_date IS NULL THEN 1 ELSE 0 END, last_play_date DESC, created_at DESC',
      );

      final seenCodes = <String>{};
      folders = folders.where((f) {
        final code = f.code;
        if (code == null || code.isEmpty) return false;
        if (seenCodes.contains(code)) return false;
        seenCodes.add(code);
        return true;
      }).toList();

      state = state.copyWith(folders: folders, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 将旧版无 parent 的视频集挂到默认分组（仅含视频或绑定路径的条目）
  Future<void> migrateLegacyLeafFolders() async {
    final legacy = await DatabaseService.findByCondition(() => VideoFolder(), where: "(parent_code IS NULL OR parent_code = '') AND is_deleted = 0");
    if (legacy.isEmpty) return;
    final groupCode = await SettingsService.ensureDefaultGroupCode();
    for (final folder in legacy) {
      final count = await DatabaseService.count(() => VideoInfo(), where: 'folder_code = ? AND is_deleted = 0', whereArgs: [folder.code]);
      if (count > 0 || folder.path.isNotEmpty) {
        folder.parentCode = groupCode;
        await DatabaseService.update(folder);
      }
    }
  }

  /// 加载首页视频集（仅二级结构中的叶子集，按最近播放倒序）
  Future<void> loadFolders() async {
    state = state.copyWith(isLoading: true);
    try {
      await migrateLegacyLeafFolders();

      // 调试：检查默认分组是否存在
      final defaultGroupCode = await SettingsService.ensureDefaultGroupCode();
      logger.debug('defaultGroupCode = $defaultGroupCode', tag: 'FOLDER');

      List<VideoFolder> folders = await DatabaseService.findByCondition(
        () => VideoFolder(),
        where: "is_deleted = 0 AND parent_code IS NOT NULL AND parent_code != ''",
        orderBy: 'CASE WHEN last_play_date IS NULL THEN 1 ELSE 0 END, last_play_date DESC, created_at DESC',
      );

      // 去重 - 根据 code 去重
      final seenCodes = <String>{};
      folders = folders.where((f) {
        if (seenCodes.contains(f.code)) {
          return false;
        }
        seenCodes.add(f.code!);
        return true;
      }).toList();

      logger.info('found ${folders.length} folders', tag: 'FOLDER');
      for (final f in folders) {
        logger.debug('${f.name} code=${f.code} parentCode=${f.parentCode}', tag: 'FOLDER');
      }

      state = state.copyWith(folders: folders, isLoading: false, error: null);
    } catch (e, st) {
      logger.error('loadFolders failed', tag: 'FOLDER', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载指定文件夹下的视频
  ///
  /// [folderCode] 文件夹code
  ///
  /// 自动设置当前文件夹和当前播放的视频
  Future<void> loadVideos(String folderCode) async {
    state = state.copyWith(isLoading: true);
    try {
      // 获取文件夹信息
      VideoFolder? folder = await findFolderByCode(folderCode);

      // 获取视频列表
      List<VideoInfo> videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'folder_code = ? AND is_deleted = 0',
        whereArgs: [folderCode],
        orderBy: 'order_index ASC, created_at ASC',
      );

      VideoInfo? currentVideo;
      if (videos.isNotEmpty) {
        if (folder?.lastVideoCode != null) {
          for (final v in videos) {
            if (v.code == folder!.lastVideoCode) {
              currentVideo = v;
              break;
            }
          }
        }
        if (currentVideo == null) {
          final playing = videos.where((v) => v.isCurrentPlaying).toList();
          currentVideo = playing.isNotEmpty ? playing.first : videos.first;
        }
      }

      state = state.copyWith(currentFolder: folder, videos: videos, currentVideo: currentVideo, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 创建叶子视频集（挂在默认或指定分组下）
  Future<String?> createFolder(String name, {String? parentCode, String contentType = 'video'}) async {
    state = state.copyWith(isLoading: true);
    try {
      final duplicated = await DatabaseService.findByCondition(
        () => VideoFolder(),
        where: 'name = ? AND is_deleted = 0',
        whereArgs: [name],
        limit: 1,
      );
      if (duplicated.isNotEmpty) {
        state = state.copyWith(isLoading: false, error: '视频集名称已存在');
        return '视频集名称已存在';
      }

      final groupCode = parentCode ?? await SettingsService.ensureDefaultGroupCode();
      final folderContentType = FolderContentType.values.firstWhere(
        (e) => e.name == contentType,
        orElse: () => FolderContentType.video,
      );
      VideoFolder folder = VideoFolder(
        name: name,
        type: VideoFolderType.virtual,
        folderType: folderContentType,
        parentCode: groupCode,
        videoCount: 0,
        completedCount: 0,
        lastPlayDuration: 0,
      )..code = const Uuid().v4().replaceAll('-', '');
      await SettingsService.applyGlobalDefaultsToFolder(folder);
      await DatabaseService.insert(folder);
      await loadFolders();
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }

  /// 重命名文件夹
  ///
  /// [code] 文件夹code
  /// [newName] 新名称
  Future<String?> renameFolder(String code, String newName) async {
    state = state.copyWith(isLoading: true);
    try {
      VideoFolder? folder = await findFolderByCode(code);
      if (folder != null) {
        final duplicated = await DatabaseService.findByCondition(
          () => VideoFolder(),
          where: 'name = ? AND code != ? AND is_deleted = 0',
          whereArgs: [newName, code],
          limit: 1,
        );
        if (duplicated.isNotEmpty) {
          state = state.copyWith(isLoading: false, error: '视频集名称已存在');
          return '视频集名称已存在';
        }

        folder.name = newName;
        await DatabaseService.update(folder);
        await loadFolders();
      }
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }

  /// 删除文件夹（软删除）
  ///
  /// [code] 文件夹code
  Future<String?> deleteFolder(String code) async {
    try {
      VideoFolder? folder = await findFolderByCode(code);
      if (folder != null) {
        final sandboxPrefixes = await _sandboxPrefixes();
        final videos = await DatabaseService.findByCondition(() => VideoInfo(), where: 'folder_code = ? AND is_deleted = 0', whereArgs: [code]);

        final filePaths = <String>[];
        final subtitlePaths = <String>[];
        final coverPaths = <String>[];
        final currentCoverPaths = <String>[];

        for (final v in videos) {
          if (_shouldDeletePhysicalPathForVideo(folder: folder, video: v, path: v.filePath, sandboxPrefixes: sandboxPrefixes)) {
            filePaths.add(v.filePath);
          }
          final subtitlePath = v.subtitlePath;
          if (subtitlePath != null &&
              subtitlePath.isNotEmpty &&
              _shouldDeletePhysicalPathForVideo(folder: folder, video: v, path: subtitlePath, sandboxPrefixes: sandboxPrefixes)) {
            subtitlePaths.add(subtitlePath);
          }
          if (v.cover != null && v.cover!.isNotEmpty) coverPaths.add(v.cover!);
          if (v.currentCover != null && v.currentCover!.isNotEmpty) currentCoverPaths.add(v.currentCover!);

          final videoCode = v.code;
          if (videoCode != null && videoCode.isNotEmpty) {
            final subtitles = await DatabaseService.findByCondition(
              () => Subtitles(),
              where: 'video_code = ? AND is_deleted = 0',
              whereArgs: [videoCode],
            );
            for (final s in subtitles) {
              await s.softDelete();
            }

            final participles = await DatabaseService.findByCondition(
              () => Participle(),
              where: 'video_code = ? AND is_deleted = 0',
              whereArgs: [videoCode],
            );
            for (final p in participles) {
              await p.softDelete();
            }
          }

          await v.softDelete();
        }

        await folder.softDelete();

        state = state.copyWith(
          folders: state.folders.where((f) => f.code != code).toList(),
          currentFolder: state.currentFolder?.code == code ? null : state.currentFolder,
          videos: state.currentFolder?.code == code ? const [] : state.videos,
          currentVideo: state.currentFolder?.code == code ? null : state.currentVideo,
          isLoading: false,
          error: null,
        );
        await refreshFoldersSilently();

        debugPrint(
          '[DELETE_FOLDER][FILES_START] folderCode=$code videos=${videos.length} file=${filePaths.length} subtitle=${subtitlePaths.length} cover=${coverPaths.length} currentCover=${currentCoverPaths.length}',
        );
        for (final p in filePaths) {
          await deleteFileIfExists(p);
        }
        for (final p in subtitlePaths) {
          await deleteFileIfExists(p);
        }
        for (final p in coverPaths) {
          await deleteCoverIfExists(p);
        }
        for (final p in currentCoverPaths) {
          await deleteCoverIfExists(p);
        }
        for (final v in videos) {
          final videoCode = v.code;
          if (videoCode != null && videoCode.isNotEmpty) {
            await ThumbnailService.deleteVideoScreenshots(videoCode);
          }
        }
        debugPrint('[DELETE_FOLDER][FILES_DONE] folderCode=$code');
      }
      state = state.copyWith(isLoading: false);
      return null;
    } catch (e, st) {
      logger.error('deleteFolder failed', tag: 'DELETE', error: e, stackTrace: st, extra: {'folderCode': code});
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }

  Future<void> deleteFileIfExists(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;
    try {
      final f = File(filePath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (e, st) {
      logger.error('delete file failed', tag: 'DELETE', error: e, stackTrace: st, extra: {'path': filePath});
    }
  }

  Future<void> deleteCoverIfExists(String? coverPath) async {
    if (coverPath == null || coverPath.isEmpty) return;
    try {
      if (coverPath.startsWith('covers/') || coverPath.startsWith('screenshot/')) {
        await ThumbnailService.deleteThumbnail(coverPath);
        return;
      }
      final f = File(coverPath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (e, st) {
      logger.error('delete cover failed', tag: 'DELETE', error: e, stackTrace: st, extra: {'path': coverPath});
    }
  }

  /// 设置当前播放的视频
  ///
  /// [video] 要设置为当前播放的视频
  ///
  /// 会更新该视频的 isCurrentPlaying 状态
  Future<void> setCurrentVideo(VideoInfo video) async {
    state = state.copyWith(isLoading: true);
    try {
      // 更新所有视频的播放状态
      List<VideoInfo> updatedVideos = state.videos.map((v) {
        v.isCurrentPlaying = v.code == video.code;
        return v;
      }).toList();

      await DatabaseService.batchUpdate(updatedVideos);

      state = state.copyWith(videos: updatedVideos, currentVideo: video, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 选择视频开始播放
  ///
  /// [videoCode] 视频code
  ///
  /// 更新播放时间、播放次数、当前播放状态
  /// 同时更新文件夹的播放信息
  Future<void> selectVideo(String videoCode) async {
    state = state.copyWith(isLoading: true);
    try {
      VideoInfo? video = await findVideoByCode(videoCode);
      if (video != null) {
        final now = DateTime.now();

        // 更新视频信息
        video.playDate = now;
        video.isCurrentPlaying = true;
        video.playCount += 1;

        // 更新列表中所有视频的播放状态
        List<VideoInfo> updatedVideos = state.videos.map((v) {
          if (v.code == videoCode) {
            v.playDate = now;
            v.isCurrentPlaying = true;
            v.playCount += 1;
          } else {
            v.isCurrentPlaying = false;
          }
          return v;
        }).toList();

        await DatabaseService.batchUpdate(updatedVideos);

        // 更新文件夹的播放信息
        await updateFolderPlayInfo(video.folderCode, videoCode, video.currentPosition);
        await FolderStatsService.refreshFolderStats(video.folderCode);

        state = state.copyWith(videos: updatedVideos, currentVideo: video, isLoading: false, error: null);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 更新视频播放进度
  ///
  /// [videoCode] 视频code
  /// [currentPosition] 当前播放位置（毫秒）
  ///
  /// 保存播放进度到数据库，用于断点续播
  Future<void> updateVideoProgress(String videoCode, int currentPosition) async {
    state = state.copyWith(isLoading: true);
    try {
      VideoInfo? video = await findVideoByCode(videoCode);
      if (video != null) {
        video.currentPosition = currentPosition;
        video.playDate = DateTime.now();
        await DatabaseService.update(video);

        // 更新文件夹播放信息
        await updateFolderPlayInfo(video.folderCode, videoCode, currentPosition);

        // 重新加载视频列表
        final folderCode = state.currentFolder?.code;
        if (folderCode != null) {
          await loadVideos(folderCode);
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 更新视频封面
  ///
  /// [videoCode] 视频code
  /// [coverPath] 封面路径
  ///
  /// 用于保存当前播放位置的截图
  Future<void> updateVideoCover(String videoCode, String coverPath) async {
    state = state.copyWith(isLoading: true);
    try {
      VideoInfo? video = await findVideoByCode(videoCode);
      if (video != null) {
        video.currentCover = coverPath;
        await DatabaseService.update(video);

        // 如果该视频是文件夹正在播放的视频，同步更新文件夹封面
        VideoFolder? folder = await findFolderByCode(video.folderCode);
        if (folder != null && folder.lastVideoCode == videoCode) {
          folder.cover = coverPath;
          await DatabaseService.update(folder);
        }

        final folderCode = state.currentFolder?.code;
        if (folderCode != null) {
          await loadVideos(folderCode);
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 更新视频总播放时长
  ///
  /// [videoCode] 视频code
  /// [duration] 本次播放时长（毫秒）
  ///
  /// 累加到 totalPlayDuration 字段
  Future<void> updateVideoPlayDuration(String videoCode, int duration) async {
    state = state.copyWith(isLoading: true);
    try {
      VideoInfo? video = await findVideoByCode(videoCode);
      if (video != null) {
        video.totalPlayDuration += duration ~/ 1000; // 转换为秒
        await DatabaseService.update(video);

        final folderCode = state.currentFolder?.code;
        if (folderCode != null) {
          await loadVideos(folderCode);
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 创建学习记录
  ///
  /// [videoCode] 视频code
  /// [startTime] 学习开始时间
  ///
  /// 在用户开始学习时创建一条记录
  Future<void> createStudyRecord(String videoCode, DateTime startTime) async {
    try {
      StudyRecord record = StudyRecord(videoCode: videoCode, startTime: startTime)..code = const Uuid().v4().replaceAll('-', '');
      await DatabaseService.insert(record);
    } catch (e) {
      // 静默处理错误
    }
  }

  /// 完成学习记录
  ///
  /// [videoCode] 视频code
  /// [endTime] 学习结束时间
  /// [duration] 学习时长（毫秒）
  /// [playCount] 本次完整播放次数
  ///
  /// 查找该视频未完成的学习记录并更新
  Future<void> completeStudyRecord(String videoCode, DateTime endTime, int duration, int playCount) async {
    try {
      // 查找该视频最近一条未完成的记录
      List<StudyRecord> records = await DatabaseService.findByCondition(
        () => StudyRecord(),
        where: 'video_code = ? AND end_time IS NULL AND is_deleted = 0',
        whereArgs: [videoCode],
        orderBy: 'start_time DESC',
      );

      if (records.isNotEmpty) {
        StudyRecord record = records.first;
        record.endTime = endTime;
        record.duration = duration ~/ 1000; // 转换为秒
        record.playCount = playCount;
        await DatabaseService.update(record);
      }
    } catch (e) {
      // 静默处理错误
    }
  }

  /// 重命名视频
  ///
  /// [code] 视频code
  /// [newName] 新名称
  Future<void> renameVideo(String code, String newName) async {
    state = state.copyWith(isLoading: true);
    try {
      VideoInfo? video = await findVideoByCode(code);
      if (video != null) {
        video.name = newName;
        await DatabaseService.update(video);
        final folderCode = state.currentFolder?.code;
        if (folderCode != null) {
          await loadVideos(folderCode);
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 删除视频（软删除）
  ///
  /// [code] 视频code
  Future<void> deleteVideo(String code) async {
    state = state.copyWith(isLoading: true);
    try {
      VideoInfo? video = await findVideoByCode(code);
      if (video != null) {
        final folder = await findFolderByCode(video.folderCode);
        final sandboxPrefixes = await _sandboxPrefixes();
        if (folder != null &&
            _shouldDeletePhysicalPathForVideo(folder: folder, video: video, path: video.filePath, sandboxPrefixes: sandboxPrefixes)) {
          await deleteFileIfExists(video.filePath);
        }
        final subtitlePath = video.subtitlePath;
        if (folder != null &&
            subtitlePath != null &&
            subtitlePath.isNotEmpty &&
            _shouldDeletePhysicalPathForVideo(folder: folder, video: video, path: subtitlePath, sandboxPrefixes: sandboxPrefixes)) {
          await deleteFileIfExists(subtitlePath);
        }
        await deleteCoverIfExists(video.cover);
        await deleteCoverIfExists(video.currentCover);

        final videoCode = video.code;
        if (videoCode != null && videoCode.isNotEmpty) {
          await ThumbnailService.deleteVideoScreenshots(videoCode);
          final subtitles = await DatabaseService.findByCondition(
            () => Subtitles(),
            where: 'video_code = ? AND is_deleted = 0',
            whereArgs: [videoCode],
          );
          for (final s in subtitles) {
            await s.softDelete();
          }

          final participles = await DatabaseService.findByCondition(
            () => Participle(),
            where: 'video_code = ? AND is_deleted = 0',
            whereArgs: [videoCode],
          );
          for (final p in participles) {
            await p.softDelete();
          }
        }

        await video.softDelete();
        final folderCode = state.currentFolder?.code;
        if (folderCode != null) {
          await loadVideos(folderCode);
        }
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 添加视频
  ///
  /// [video] 要添加的视频对象
  ///
  /// 生成唯一code并保存到数据库
  Future<void> addVideo(VideoInfo video) async {
    state = state.copyWith(isLoading: true);
    try {
      video.code = const Uuid().v4().replaceAll('-', '');
      await DatabaseService.insert(video);
      final folderCode = state.currentFolder?.code;
      if (folderCode != null) {
        await loadVideos(folderCode);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 为已存在的视频导入字幕文件
  ///
  /// [videoCode] 视频 code
  /// [subtitlePath] 字幕文件路径
  Future<void> importSubtitleForVideo(String videoCode, String subtitlePath) async {
    state = state.copyWith(isLoading: true);
    try {
      VideoInfo? video = await findVideoByCode(videoCode);
      if (video == null) return;
      video.subtitlePath = subtitlePath;
      video.hasSubtitles = true;
      await DatabaseService.update(video);

      // 调用服务导入字幕内容
      await FilePickerService.importSubtitleToDb(subtitlePath, video.folderCode, videoCode);

      final folderCode = state.currentFolder?.code;
      if (folderCode != null) {
        await loadVideos(folderCode);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 更新文件夹播放信息
  ///
  /// [folderCode] 文件夹code
  /// [videoCode] 正在播放的视频code
  /// [playDuration] 播放进度（毫秒）
  ///
  /// 更新文件夹的 lastVideoCode、lastPlayDate、lastPlayDuration
  /// 更新视频集播放设置
  Future<void> updateFolderPlaybackSettings(String folderCode, PlaybackSettings settings) async {
    final folder = await findFolderByCode(folderCode);
    if (folder == null) return;
    folder.skipOpening = settings.skipOpening;
    folder.skipOpeningDuration = settings.skipOpeningDuration;
    folder.skipEnding = settings.skipEnding;
    folder.skipEndingDuration = settings.skipEndingDuration;
    folder.thumbnailTime = settings.thumbnailTime;
    await DatabaseService.update(folder);
    await FolderStatsService.refreshFolderStats(folderCode);
    if (state.currentFolder?.code == folderCode) {
      await loadVideos(folderCode);
    }
    await loadFolders();
  }

  Future<void> updateFolderPlayInfo(String folderCode, String videoCode, int playDuration) async {
    try {
      VideoFolder? folder = await findFolderByCode(folderCode);
      if (folder != null) {
        folder.lastVideoCode = videoCode;
        folder.lastPlayDate = DateTime.now();
        folder.lastPlayDuration = playDuration;
        await DatabaseService.update(folder);
        await FolderStatsService.refreshFolderStats(folderCode);
        await loadFolders();
      }
    } catch (e) {
      // 静默处理错误
    }
  }

  /// 根据code查找文件夹
  Future<VideoFolder?> findFolderByCode(String code) async {
    List<VideoFolder> folders = await DatabaseService.findByCondition(() => VideoFolder(), where: 'code = ? AND is_deleted = 0', whereArgs: [code]);
    return folders.isNotEmpty ? folders.first : null;
  }

  /// 根据code查找视频
  Future<VideoInfo?> findVideoByCode(String code) async {
    List<VideoInfo> videos = await DatabaseService.findByCondition(() => VideoInfo(), where: 'code = ? AND is_deleted = 0', whereArgs: [code]);
    return videos.isNotEmpty ? videos.first : null;
  }

}
