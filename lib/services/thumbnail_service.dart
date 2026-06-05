import 'dart:convert';
import 'dart:io';

import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:vidlang/models/error_log.dart';
import 'package:vidlang/services/database_service.dart';

/// 缩略图服务类
///
/// 提供视频缩略图生成和管理功能：
/// - 生成视频缩略图
/// - 缩略图路径管理
/// - 缩略图删除
///
/// 缩略图存储在应用文档目录的 screenshot 文件夹下，
/// 每个视频以 videoCode 单独建目录，便于管理和清理
class ThumbnailService {
  /// 默认截取时间（秒）
  ///
  /// 从视频第15秒位置截取缩略图
  static const int defaultThumbnailTime = 15;

  /// 生成视频缩略图
  ///
  /// [videoPath] 视频文件路径
  /// [folderCode] 文件夹code（历史参数，保留兼容）
  /// [videoCode] 视频code（用于组织存储）
  ///
  /// 存储路径：{appDocDir}/screenshot/{videoCode}/cover.png
  ///
  /// 返回缩略图的相对路径，生成失败返回null
  static Future<String?> generateThumbnail(String videoPath, String folderCode, String videoCode, {int timeSec = defaultThumbnailTime}) async {
    return generateCoverThumbnail(videoPath, videoCode, timeSec: timeSec);
  }

  static Future<String?> generateCoverThumbnail(String videoPath, String videoCode, {int timeSec = defaultThumbnailTime}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final screenshotDir = Directory('${directory.path}/screenshot/$videoCode');

      if (!await screenshotDir.exists()) {
        await screenshotDir.create(recursive: true);
      }

      final thumbnailPath = '${screenshotDir.path}/cover.png';
      final targetFile = File(thumbnailPath);

      logger.info(
        'thumbnail start',
        tag: 'THUMB',
        extra: {'video': videoPath, 'videoCode': videoCode, 'target': thumbnailPath, 'timeSec': timeSec, 'type': 'cover'},
      );

      // 如果已存在则直接返回
      if (await targetFile.exists()) {
        logger.info('thumbnail hit', tag: 'THUMB', extra: {'target': thumbnailPath, 'type': 'cover'});
        return _getRelativePath(thumbnailPath);
      }

      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.PNG,
        maxHeight: 200,
        quality: 75,
        timeMs: timeSec * 1000,
      );

      if (bytes != null && bytes.isNotEmpty) {
        await targetFile.writeAsBytes(bytes, flush: true);
        logger.info('thumbnail done', tag: 'THUMB', extra: {'output': thumbnailPath, 'size': bytes.length, 'type': 'cover'});
        return _getRelativePath(thumbnailPath);
      }
      logger.warning(
        'thumbnail fail',
        tag: 'THUMB',
        extra: {'video': videoPath, 'videoCode': videoCode, 'target': thumbnailPath, 'type': 'cover'},
      );
      return null;
    } catch (e, st) {
      logger.error(
        'thumbnail error',
        tag: 'THUMB',
        error: e,
        stackTrace: st,
        extra: {'video': videoPath, 'videoCode': videoCode, 'timeSec': timeSec, 'type': 'cover'},
      );
      await _tryPersistErrorLog(
        tag: 'THUMB',
        message: '封面截图失败',
        error: e,
        stackTrace: st,
        extra: {'video': videoPath, 'videoCode': videoCode, 'timeSec': timeSec, 'type': 'cover'},
      );
      return null;
    }
  }

  static Future<String?> generateProgressThumbnail(String videoPath, String videoCode, {required int timeMs}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final screenshotDir = Directory('${directory.path}/screenshot/$videoCode');
      if (!await screenshotDir.exists()) {
        await screenshotDir.create(recursive: true);
      }

      final thumbnailPath = '${screenshotDir.path}/progress.png';
      final targetFile = File(thumbnailPath);

      logger.info(
        'thumbnail start',
        tag: 'THUMB',
        extra: {'video': videoPath, 'videoCode': videoCode, 'target': thumbnailPath, 'timeMs': timeMs, 'type': 'progress'},
      );

      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.PNG,
        maxHeight: 200,
        quality: 80,
        timeMs: timeMs,
      );

      if (bytes != null && bytes.isNotEmpty) {
        await targetFile.writeAsBytes(bytes, flush: true);
        logger.info('thumbnail done', tag: 'THUMB', extra: {'output': thumbnailPath, 'size': bytes.length, 'type': 'progress'});
        return _getRelativePath(thumbnailPath);
      }

      logger.warning(
        'thumbnail fail',
        tag: 'THUMB',
        extra: {'video': videoPath, 'videoCode': videoCode, 'target': thumbnailPath, 'type': 'progress'},
      );
      return null;
    } catch (e, st) {
      logger.error(
        'thumbnail error',
        tag: 'THUMB',
        error: e,
        stackTrace: st,
        extra: {'video': videoPath, 'videoCode': videoCode, 'timeMs': timeMs, 'type': 'progress'},
      );
      await _tryPersistErrorLog(
        tag: 'THUMB',
        message: '进度截图失败',
        error: e,
        stackTrace: st,
        extra: {'video': videoPath, 'videoCode': videoCode, 'timeMs': timeMs, 'type': 'progress'},
      );
      return null;
    }
  }

  /// 获取相对路径
  ///
  /// [fullPath] 完整文件路径
  /// 返回相对于应用文档目录的路径
  static String _getRelativePath(String fullPath) {
    final normalized = fullPath.replaceAll('\\', '/');
    final parts = normalized.split('screenshot/');
    if (parts.length > 1) {
      return 'screenshot/${parts[1]}';
    }
    final legacy = normalized.split('covers/');
    if (legacy.length > 1) {
      return 'covers/${legacy[1]}';
    }
    return fullPath;
  }

  /// 获取完整路径
  ///
  /// [relativePath] 相对路径
  /// 返回完整文件系统路径
  static Future<String> getFullPath(String relativePath) async {
    if (relativePath.startsWith('/')) return relativePath;
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$relativePath';
  }

  /// 删除单个缩略图
  ///
  /// [relativePath] 缩略图相对路径
  static Future<void> deleteThumbnail(String relativePath) async {
    try {
      final fullPath = relativePath.startsWith('/') ? relativePath : await getFullPath(relativePath);
      final file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 静默处理删除失败
    }
  }

  static Future<void> deleteVideoScreenshots(String videoCode) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory('${directory.path}/screenshot/$videoCode');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      // 静默处理删除失败
    }
  }
}

Future<void> _tryPersistErrorLog({
  required String tag,
  required String message,
  required Object error,
  required StackTrace stackTrace,
  Map<String, dynamic>? extra,
}) async {
  try {
    final userCode = await DatabaseService.getCurrentUserCode();
    final log = ErrorLog(
      level: 'error',
      tag: tag,
      message: message,
      error: error.toString(),
      stackTrace: stackTrace.toString(),
      extra: extra == null ? null : jsonEncode(extra),
    );
    log.userCode = userCode;
    log.createdBy = userCode;
    log.updatedBy = userCode;
    await DatabaseService.insert(log);
  } catch (_) {}
}
