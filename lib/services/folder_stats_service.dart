import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/settings_service.dart';
import 'package:vidlang/services/thumbnail_service.dart';

/// 视频集统计：集数、播完数、封面
class FolderStatsService {
  FolderStatsService._();

  static Future<void> refreshFolderStats(String folderCode) async {
    final folders = await DatabaseService.findByCondition(
      () => VideoFolder(),
      where: 'code = ? AND is_deleted = 0',
      whereArgs: [folderCode],
      limit: 1,
    );
    if (folders.isEmpty) return;
    final folder = folders.first;

    final videos = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [folderCode],
      orderBy: 'order_index ASC, created_at ASC',
    );

    final settings = await SettingsService.resolveForFolder(folder);
    int completed = 0;
    for (final v in videos) {
      if (settings.isPlaybackCompleted(v.currentPosition, v.duration)) {
        completed++;
      }
    }

    folder.videoCount = videos.length;
    folder.completedCount = completed;
    folder.cover = await _resolveFolderCover(folder, videos);

    await DatabaseService.update(folder);
  }

  static Future<String?> _resolveFolderCover(
    VideoFolder folder,
    List<VideoInfo> videos,
  ) async {
    if (videos.isEmpty) return null;

    if (folder.lastVideoCode != null && folder.lastPlayDate != null) {
      final last = videos.where((v) => v.code == folder.lastVideoCode);
      if (last.isNotEmpty) {
        final v = last.first;
        if (v.currentCover != null && v.currentCover!.isNotEmpty) {
          return v.currentCover;
        }
        if (v.cover != null && v.cover!.isNotEmpty) return v.cover;
      }
    }

    final first = videos.first;
    return first.cover;
  }

  /// 封面图完整路径（供 Image.file）
  static Future<String?> coverFullPath(String? relativeOrAbsolute) async {
    if (relativeOrAbsolute == null || relativeOrAbsolute.isEmpty) {
      return null;
    }
    if (relativeOrAbsolute.startsWith('/')) {
      return relativeOrAbsolute;
    }
    return ThumbnailService.getFullPath(relativeOrAbsolute);
  }
}
