import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:vidlang/models/participle.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/folder_stats_service.dart';
import 'package:vidlang/services/settings_service.dart';
import 'package:vidlang/services/thumbnail_service.dart';

class _LocalVideoImportResult {
  final VideoInfo? video;
  final int subtitlesInserted;
  final int participlesInserted;

  const _LocalVideoImportResult({required this.video, required this.subtitlesInserted, required this.participlesInserted});

  const _LocalVideoImportResult.empty() : video = null, subtitlesInserted = 0, participlesInserted = 0;
}

class _SubtitleImportStats {
  final int subtitlesInserted;
  final int participlesInserted;

  const _SubtitleImportStats({required this.subtitlesInserted, required this.participlesInserted});

  const _SubtitleImportStats.empty() : subtitlesInserted = 0, participlesInserted = 0;
}

/// 文件选择服务类
///
/// 提供视频文件选择和导入功能，支持：
/// - 视频文件选择（支持多种格式）
/// - 文件夹选择（扫描本地视频）
/// - 视频导入（自动生成缩略图、获取时长）
/// - 字幕文件自动检测和导入
/// - 分词处理
/// - 文件复制到应用目录
///
/// 支持的视频格式：
/// - MP4、MOV、AVI、MKV、WebM、FLV、WMV
///
/// 支持的字幕格式：
/// - SRT、ASS、SSA、VTT
class FilePickerService {
  /// 支持的视频文件扩展名列表
  static const List<String> supportedVideoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.wmv'];

  /// 支持的字幕文件扩展名列表
  static const List<String> supportedSubtitleExtensions = ['.srt', '.ass', '.ssa', '.vtt'];

  /// 选择文件夹
  ///
  /// 打开系统文件选择器，允许用户选择一个本地文件夹
  /// 返回选中文件夹的路径，用户取消返回 null
  static Future<String?> pickFolder() async {
    try {
      // 使用 getDirectoryPath 方法专门选择文件夹
      // withData: false 确保不加载文件内容，只获取路径
      final folderPath = await FilePicker.getDirectoryPath(dialogTitle: '选择视频文件夹', lockParentWindow: !Platform.isIOS);

      if (folderPath != null && folderPath.isNotEmpty) {
        // 检查是否为文件夹
        final entity = await FileSystemEntity.type(folderPath);
        if (entity == FileSystemEntityType.directory) {
          return folderPath;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 扫描文件夹中的视频和字幕文件
  ///
  /// [folderPath] 文件夹路径
  /// 返回文件夹中所有视频和字幕文件的路径列表
  /// 规范化 iOS/Files 返回的路径
  static String normalizePath(String rawPath) {
    if (rawPath.startsWith('file://')) {
      return Uri.parse(rawPath).toFilePath();
    }
    if (rawPath.contains('%')) {
      try {
        return Uri.decodeFull(rawPath);
      } catch (_) {}
    }
    return rawPath;
  }

  static Future<Map<String, List<String>>> scanFilesInFolder(String folderPath) async {
    final videoFiles = <String>[];
    final subtitleFiles = <String>[];
    final normalized = normalizePath(folderPath);

    try {
      final directory = Directory(normalized);
      if (!await directory.exists()) {
        debugPrint('scanFilesInFolder: directory not exists: $normalized');
        return {'videos': videoFiles, 'subtitles': subtitleFiles};
      }

      void collectFrom(Iterable<FileSystemEntity> entities) {
        for (final entity in entities) {
          if (entity is! File) continue;
          final extension = _getFileExtension(entity.path);
          if (_isVideoFile(extension)) {
            videoFiles.add(entity.path);
          } else if (_isSubtitleFile(extension)) {
            subtitleFiles.add(entity.path);
          }
        }
      }

      // iOS 须在选取后立即 listSync，异步 list 可能因授权失效而失败
      if (Platform.isIOS) {
        collectFrom(directory.listSync(followLinks: false));
      } else {
        collectFrom(await directory.list(followLinks: false).toList());
      }
    } catch (e, st) {
      debugPrint('scanFilesInFolder error: $e\n$st');
    }

    debugPrint('scanFilesInFolder: $normalized -> ${videoFiles.length} videos, ${subtitleFiles.length} subtitles');
    return {'videos': videoFiles, 'subtitles': subtitleFiles};
  }

  /// 检查文件夹是否已导入（包括已删除的）
  ///
  /// [folderPath] 文件夹路径
  /// 返回是否已存在相同路径的视频集（包括软删除的）
  static Future<bool> isFolderImported(String folderPath) async {
    try {
      final normalized = normalizePath(folderPath);
      // 检查所有状态，包括已删除的，防止重复导入
      final folders = await DatabaseService.findByCondition(() => VideoFolder(), where: 'path = ?', whereArgs: [normalized]);
      return folders.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 导入本地文件夹作为视频集
  ///
  /// [folderPath] 本地文件夹路径
  /// [collectionName] 视频集名称（可选，默认使用文件夹名称）
  /// [onProgress] 进度回调 (当前进度，总进度)
  ///
  /// 功能流程：
  /// 1. 检查文件夹是否已导入
  /// 2. 扫描文件夹中的视频和字幕文件
  /// 3. 创建视频集（VideoFolder）
  /// 4. 逐个导入视频，同时处理字幕和分词
  /// 5. 视频文件保留在用户目录，仅写入元数据
  ///
  /// 返回创建的视频集对象，失败返回null
  static Future<VideoFolder?> importLocalFolder(
    String folderPath, {
    String? collectionName,
    Function(int, int)? onProgress,
    Map<String, List<String>>? preScannedFiles,
  }) async {
    try {
      final normalizedPath = normalizePath(folderPath);

      final currentUserCode = await DatabaseService.getCurrentUserCode();
      final beforeVideoTotal = await DatabaseService.count(() => VideoInfo());
      final beforeSubtitleTotal = await DatabaseService.count(() => Subtitles());
      final beforeParticipleTotal = await DatabaseService.count(() => Participle());

      debugPrint(
        '[IMPORT_FOLDER][START] userCode=$currentUserCode path=$normalizedPath '
        'before(video=$beforeVideoTotal subtitle=$beforeSubtitleTotal participle=$beforeParticipleTotal)',
      );

      // 先扫描（iOS 需在授权有效期内立即读目录）
      final files = preScannedFiles ?? await scanFilesInFolder(normalizedPath);
      final videoPaths = files['videos'] ?? [];
      final subtitlePaths = files['subtitles'] ?? [];

      if (videoPaths.isEmpty) {
        return null;
      }

      if (await isFolderImported(normalizedPath)) {
        debugPrint('[IMPORT_FOLDER][BLOCK] 已导入过：$normalizedPath');
        throw Exception('该文件夹已导入过，禁止重复导入');
      }

      final folderName = collectionName ?? path.basename(normalizedPath);

      final duplicatedName = await DatabaseService.findByCondition(
        () => VideoFolder(),
        where: 'name = ? AND is_deleted = 0',
        whereArgs: [folderName],
        limit: 1,
      );
      if (duplicatedName.isNotEmpty) {
        debugPrint('[IMPORT_FOLDER][BLOCK] 文件夹名称重复：$folderName');
        throw Exception('视频集名称「$folderName」已存在，请更换名称');
      }

      debugPrint('[IMPORT_FOLDER][INFO] normalizedPath=$normalizedPath');
      debugPrint('[IMPORT_FOLDER][INFO] folderName=$folderName');
      debugPrint('[IMPORT_FOLDER][INFO] collectionName=$collectionName');

      final parentCode = await SettingsService.ensureDefaultGroupCode();
      debugPrint('[IMPORT_FOLDER][INFO] parentCode=$parentCode');

      final folderCode = const Uuid().v4().replaceAll('-', '');
      final folder = VideoFolder(
        name: folderName,
        type: VideoFolderType.virtual,
        path: normalizedPath,
        parentCode: parentCode,
        videoCount: 0,
        completedCount: 0,
      )..code = folderCode;

      logger.info(
        'creating folder',
        tag: 'IMPORT_FOLDER',
        extra: {'name': folder.name, 'code': folder.code, 'parentCode': folder.parentCode, 'path': folder.path},
      );

      await SettingsService.applyGlobalDefaultsToFolder(folder);
      await DatabaseService.insert(folder);

      // 验证插入是否成功
      final inserted = await DatabaseService.findByCondition(() => VideoFolder(), where: 'code = ?', whereArgs: [folderCode]);
      debugPrint('[IMPORT_FOLDER][INFO] inserted folder count = ${inserted.length}');
      if (inserted.isNotEmpty) {
        final f = inserted.first;
        debugPrint('[IMPORT_FOLDER][INFO] inserted folder name=${f.name} code=${f.code} parentCode=${f.parentCode} isDeleted=${f.isDeleted}');
      }

      // 建立字幕文件映射（基于文件名）
      final subtitleMap = <String, String>{};
      for (final subtitlePath in subtitlePaths) {
        final baseName = _getFileNameWithoutExtension(path.basename(subtitlePath));
        subtitleMap[baseName] = subtitlePath;
      }

      // 导入视频
      int completedCount = 0;
      int insertedVideos = 0;
      int insertedSubtitles = 0;
      int insertedParticiples = 0;
      for (int i = 0; i < videoPaths.length; i++) {
        final videoPath = videoPaths[i];
        final videoName = _getFileNameWithoutExtension(path.basename(videoPath));

        // 查找匹配的字幕文件
        final subtitlePath = subtitleMap[videoName];

        // 导入视频
        final result = await _importLocalVideo(videoPath, folderCode, subtitlePath: subtitlePath);

        if (result.video != null) {
          insertedVideos++;
          insertedSubtitles += result.subtitlesInserted;
          insertedParticiples += result.participlesInserted;
          completedCount++;
        }

        // 更新进度
        onProgress?.call(completedCount, videoPaths.length);
      }

      await FolderStatsService.refreshFolderStats(folderCode);
      final updated = await DatabaseService.findByCondition(
        () => VideoFolder(),
        where: 'code = ? AND is_deleted = 0',
        whereArgs: [folderCode],
        limit: 1,
      );
      final afterVideoTotal = await DatabaseService.count(() => VideoInfo());
      final afterSubtitleTotal = await DatabaseService.count(() => Subtitles());
      final afterParticipleTotal = await DatabaseService.count(() => Participle());

      debugPrint(
        '[IMPORT_FOLDER][DONE] folderCode=$folderCode name=$folderName '
        'scanned(video=${videoPaths.length} subtitle=${subtitlePaths.length}) '
        'inserted(video=$insertedVideos subtitle=$insertedSubtitles participle=$insertedParticiples) '
        'after(video=$afterVideoTotal subtitle=$afterSubtitleTotal participle=$afterParticipleTotal)',
      );

      return updated.isNotEmpty ? updated.first : folder;
    } catch (e, st) {
      debugPrint('importLocalFolder failed: $e\n$st');
      rethrow;
    }
  }

  /// 导入单个本地视频文件
  ///
  /// [videoPath] 视频文件路径
  /// [folderCode] 目标视频集 code
  /// [subtitlePath] 字幕文件路径（可选）
  static Future<_LocalVideoImportResult> _importLocalVideo(String videoPath, String folderCode, {String? subtitlePath}) async {
    try {
      videoPath = normalizePath(videoPath);
      if (subtitlePath != null && subtitlePath.isNotEmpty) {
        subtitlePath = normalizePath(subtitlePath);
      }
      final file = File(videoPath);
      if (!await file.exists()) {
        return const _LocalVideoImportResult.empty();
      }

      final displayFileName = path.basename(videoPath);
      final displayNameWithoutExt = _getFileNameWithoutExtension(displayFileName);
      final fileExtension = _getFileExtension(displayFileName);
      if (!_isVideoFile(fileExtension)) {
        return const _LocalVideoImportResult.empty();
      }

      // 自动检测同名字幕文件（当外部未传入 subtitlePath 时）
      subtitlePath ??= _detectSubtitleFile(videoPath);

      final isIosTmp = _isProbablyIosTmpPath(videoPath);
      if (isIosTmp) {
        final existingByName = await DatabaseService.findByCondition(
          () => VideoInfo(),
          where: 'folder_code = ? AND name = ? AND extension_name = ? AND is_deleted = 0',
          whereArgs: [folderCode, displayNameWithoutExt, fileExtension],
          limit: 1,
        );
        if (existingByName.isNotEmpty) {
          final existing = existingByName.first;
          if (subtitlePath != null &&
              subtitlePath.isNotEmpty &&
              (existing.subtitlePath == null || existing.subtitlePath!.isEmpty || existing.hasSubtitles == false)) {
            existing.subtitlePath = subtitlePath;
            existing.hasSubtitles = true;
            await DatabaseService.update(existing);
            final stats = await _importSubtitle(subtitlePath, folderCode, existing.code ?? '');
            return _LocalVideoImportResult(
              video: existing,
              subtitlesInserted: stats.subtitlesInserted,
              participlesInserted: stats.participlesInserted,
            );
          }
          return const _LocalVideoImportResult.empty();
        }
      } else {
        final existingVideos = await DatabaseService.findByCondition(
          () => VideoInfo(),
          where: 'folder_code = ? AND file_path = ? AND is_deleted = 0',
          whereArgs: [folderCode, videoPath],
          limit: 1,
        );
        if (existingVideos.isNotEmpty) {
          return const _LocalVideoImportResult.empty();
        }
      }

      final videoCode = const Uuid().v4().replaceAll('-', '');

      final persisted = await _persistIosTmpFilesIfNeeded(
        videoPath: videoPath,
        subtitlePath: subtitlePath,
        folderCode: folderCode,
        videoCode: videoCode,
      );
      videoPath = persisted.videoPath;
      subtitlePath = persisted.subtitlePath;

      final duration = await _getVideoDuration(videoPath, videoCode: videoCode);

      int thumbnailTime = 15;
      final folderRows = await DatabaseService.findByCondition(
        () => VideoFolder(),
        where: 'code = ? AND is_deleted = 0',
        whereArgs: [folderCode],
        limit: 1,
      );
      if (folderRows.isNotEmpty) {
        thumbnailTime = folderRows.first.thumbnailTime;
      }

      final durationSec = (duration / 1000).floor();
      if (durationSec > 0 && thumbnailTime >= durationSec) {
        thumbnailTime = durationSec > 1 ? durationSec - 1 : 0;
      }
      if (fileExtension.toLowerCase() == '.mkv') {
        thumbnailTime = 0;
      }

      final thumbnailPath = await ThumbnailService.generateThumbnail(videoPath, folderCode, videoCode, timeSec: thumbnailTime);
      if (thumbnailPath != null) {
        final fullPath = await ThumbnailService.getFullPath(thumbnailPath);
        final exists = await File(fullPath).exists();
        logger.info(
          'thumbnail generated',
          tag: 'IMPORT_VIDEO',
          extra: {
            'video': videoPath,
            'videoCode': videoCode,
            'ext': fileExtension,
            'durationMs': duration,
            'timeSec': thumbnailTime,
            'thumbnail': thumbnailPath,
            'thumbnailFullPath': fullPath,
            'exists': exists,
          },
        );
      } else {
        logger.warning(
          'thumbnail null',
          tag: 'IMPORT_VIDEO',
          extra: {'video': videoPath, 'videoCode': videoCode, 'ext': fileExtension, 'durationMs': duration, 'timeSec': thumbnailTime},
        );
      }

      final count = await DatabaseService.count(() => VideoInfo(), where: 'folder_code = ? AND is_deleted = 0', whereArgs: [folderCode]);

      final video = VideoInfo(
        name: displayNameWithoutExt,
        folderCode: folderCode,
        filePath: videoPath,
        fileType: 'virtual',
        subtitlePath: subtitlePath,
        extensionName: fileExtension,
        duration: duration,
        cover: thumbnailPath,
        hasSubtitles: subtitlePath != null,
        currentPosition: 0,
        isCurrentPlaying: false,
        description: '',
        orderIndex: count + 1,
        playCount: 0,
        totalPlayDuration: 0,
      )..code = videoCode;

      // 保存到数据库
      await DatabaseService.insert(video);

      // 如果有字幕文件，导入字幕
      int subtitlesInserted = 0;
      int participlesInserted = 0;
      if (subtitlePath != null) {
        final stats = await _importSubtitle(subtitlePath, folderCode, videoCode);
        subtitlesInserted = stats.subtitlesInserted;
        participlesInserted = stats.participlesInserted;
      }

      debugPrint(
        '[IMPORT_VIDEO][DONE] folderCode=$folderCode videoCode=$videoCode file=$videoPath '
        'subtitle=${subtitlePath ?? '-'} subtitlesInserted=$subtitlesInserted participlesInserted=$participlesInserted',
      );
      return _LocalVideoImportResult(video: video, subtitlesInserted: subtitlesInserted, participlesInserted: participlesInserted);
    } catch (e) {
      debugPrint('[IMPORT_VIDEO][ERROR] video=$videoPath error=$e');
      return const _LocalVideoImportResult.empty();
    }
  }

  /// 导入字幕文件
  ///
  /// [subtitlePath] 字幕文件路径
  /// [folderCode] 视频集 code
  /// [videoCode] 视频 code
  static Future<_SubtitleImportStats> _importSubtitle(String subtitlePath, String folderCode, String videoCode) async {
    try {
      final subtitleFile = File(subtitlePath);
      if (!await subtitleFile.exists()) {
        return const _SubtitleImportStats.empty();
      }

      // 读取字幕文件内容
      final content = await subtitleFile.readAsString();

      // 解析字幕内容
      final subtitles = _parseSubtitleContent(content);
      int subtitlesInserted = 0;
      int participlesInserted = 0;

      // 保存字幕到数据库
      for (final subtitle in subtitles) {
        subtitle.videoCode = videoCode;
        subtitle.code = const Uuid().v4().replaceAll('-', '');
        await DatabaseService.insert(subtitle);
        subtitlesInserted++;

        // 分词处理
        participlesInserted += await _processParticiple(videoCode, subtitle.code!, subtitle.content);
      }
      debugPrint(
        '[IMPORT_SUBTITLE][DONE] videoCode=$videoCode subtitleFile=$subtitlePath '
        'parsed=${subtitles.length} inserted=$subtitlesInserted participles=$participlesInserted',
      );
      return _SubtitleImportStats(subtitlesInserted: subtitlesInserted, participlesInserted: participlesInserted);
    } catch (e) {
      debugPrint('[IMPORT_SUBTITLE][ERROR] videoCode=$videoCode subtitleFile=$subtitlePath error=$e');
      return const _SubtitleImportStats.empty();
    }
  }

  /// 导入字幕文件到数据库（公开入口）
  ///
  /// 用于 WiFi 上传字幕或手动补字幕：字幕文件先落盘，再调用该方法解析并入库。
  static Future<({int subtitlesInserted, int participlesInserted})> importSubtitleToDb(
    String subtitlePath,
    String folderCode,
    String videoCode,
  ) async {
    final stats = await _importSubtitle(subtitlePath, folderCode, videoCode);
    return (subtitlesInserted: stats.subtitlesInserted, participlesInserted: stats.participlesInserted);
  }

  /// 处理分词
  ///
  /// [videoCode] 视频 code
  /// [subtitlesCode] 字幕 code
  /// [content] 字幕文本内容
  static Future<int> _processParticiple(String videoCode, String subtitlesCode, String content) async {
    try {
      // 简单的分词逻辑：按空格和标点符号分割
      String processedText = content;
      // 移除标点符号
      processedText = processedText.replaceAll(RegExp(r'[^\w\s]'), ' ');
      // 分割单词
      List<String> words = processedText.split(RegExp(r'\s+'));
      // 过滤空字符串
      words = words.where((word) => word.isNotEmpty).toList();

      // 去重
      Set<String> uniqueWords = words.toSet();

      // 保存分词到数据库
      int inserted = 0;
      for (final word in uniqueWords) {
        final participle = Participle(videoCode: videoCode, subtitlesCode: subtitlesCode, content: word.toLowerCase());
        participle.code = const Uuid().v4().replaceAll('-', '');
        await DatabaseService.insert(participle);
        inserted++;
      }
      return inserted;
    } catch (e) {
      // 静默处理分词失败
      return 0;
    }
  }

  /// 解析字幕内容
  ///
  /// [content] 字幕文件内容
  /// 返回字幕列表
  static List<Subtitles> _parseSubtitleContent(String content) {
    final subtitles = <Subtitles>[];

    try {
      // 简单的 SRT 格式解析
      final blocks = content.split(RegExp(r'\n\s*\n'));

      for (final block in blocks) {
        final lines = block.split('\n');
        if (lines.length >= 3) {
          // 解析时间轴
          final timeLine = lines[1];
          final timeMatch = RegExp(r'(\d{2}:\d{2}:\d{2}[,.]\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}[,.]\d{3})').firstMatch(timeLine);

          if (timeMatch != null) {
            final startTime = _parseTimestamp(timeMatch.group(1)!);
            final endTime = _parseTimestamp(timeMatch.group(2)!);

            // 合并字幕文本（可能有多行）
            final text = lines.sublist(2).join('\n').trim();

            if (text.isNotEmpty) {
              final split = _splitSubtitleText(text);
              subtitles.add(
                Subtitles(
                  videoCode: '', // 后续设置
                  startPosition: startTime,
                  endPosition: endTime,
                  content: split.$1,
                  contentTranslate: split.$2,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      // 解析失败
    }

    return subtitles;
  }

  /// 将字幕文本尝试拆分为“英文原文 + 翻译（默认中文）”
  ///
  /// 规则：只有在同一块文本中同时出现“明显中文 + 明显英文”时才拆分；
  /// 否则保持原文全部放在 content，contentTranslate 为空。
  static (String, String?) _splitSubtitleText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return ('', null);

    final hasZh = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    final hasEn = RegExp(r'[A-Za-z]').hasMatch(text);
    if (!hasZh || !hasEn) return (text, null);

    final lines = text.split(RegExp(r'\r?\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.length <= 1) return (text, null);

    final zhLines = <String>[];
    final enLines = <String>[];

    for (final line in lines) {
      final lineHasZh = RegExp(r'[\u4e00-\u9fff]').hasMatch(line);
      if (lineHasZh) {
        zhLines.add(line);
      } else {
        enLines.add(line);
      }
    }

    if (zhLines.isEmpty || enLines.isEmpty) return (text, null);

    return (enLines.join(' '), zhLines.join(' '));
  }

  /// 解析时间戳
  ///
  /// [timestamp] 时间戳字符串（格式：HH:MM:SS,mmm）
  /// 返回毫秒数
  static int _parseTimestamp(String timestamp) {
    try {
      // 替换逗号为点号
      timestamp = timestamp.replaceAll(',', '.');

      final parts = timestamp.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = double.parse(parts[2]);

        return hours * 3600000 + minutes * 60000 + (seconds * 1000).round();
      }
    } catch (e) {
      // 解析失败
    }

    return 0;
  }

  /// 选择视频文件（用于文件夹详情页的批量导入）
  ///
  /// 打开系统文件选择器，允许用户选择多个视频文件
  /// 返回选中的文件列表，用户取消返回空列表
  static Future<List<PlatformFile>> pickVideos() async {
    try {
      // 使用 FileType.custom + allowedExtensions（无点前缀）
      // 替代 FileType.video，确保在所有平台上
      //（iOS Files、Android 文件管理器）都能正确弹窗选择文件
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        withData: false,
        allowedExtensions: supportedVideoExtensions.map((e) => e.startsWith('.') ? e.substring(1) : e).toList(),
        dialogTitle: '选择视频文件',
      );

      if (result != null) {
        // 过滤掉路径为空的文件（某些情况下可能发生）
        return result.files.where((file) => file.path != null).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 导入多个视频文件
  ///
  /// [files] 要导入的文件列表
  /// [folderCode] 目标文件夹 code
  /// [onProgress] 进度回调
  static Future<int> importVideos(List<PlatformFile> files, String folderCode, {Function(int, int)? onProgress}) async {
    int completedCount = 0;
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      if (file.path != null) {
        await _importLocalVideo(file.path!, folderCode);
        completedCount++;
      }
      onProgress?.call(completedCount, files.length);
    }

    await FolderStatsService.refreshFolderStats(folderCode);
    return completedCount;
  }

  /// 导入单个视频文件（可选字幕文件）
  ///
  /// [videoPath] 视频文件路径
  /// [subtitlePath] 字幕文件路径（可选，传入 null 时自动检测）
  /// [folderCode] 目标文件夹 code
  static Future<bool> importVideoWithSubtitle(String videoPath, String? subtitlePath, String folderCode) async {
    if (videoPath.isEmpty) return false;
    final result = await _importLocalVideo(videoPath, folderCode, subtitlePath: subtitlePath);
    await FolderStatsService.refreshFolderStats(folderCode);
    return result.video != null;
  }

  /// 获取文件扩展名
  ///
  /// [filePath] 文件路径
  /// 返回小写扩展名（含点号），如 '.mp4'
  static String _getFileExtension(String filePath) {
    final lastDotIndex = filePath.lastIndexOf('.');
    if (lastDotIndex != -1) {
      return filePath.substring(lastDotIndex).toLowerCase();
    }
    return '';
  }

  /// 检查是否为支持的视频格式
  ///
  /// [extension] 文件扩展名
  /// 返回是否支持
  static bool _isVideoFile(String extension) {
    return supportedVideoExtensions.contains(extension);
  }

  /// 检查是否为支持的字幕格式
  ///
  /// [extension] 文件扩展名
  /// 返回是否支持
  static bool _isSubtitleFile(String extension) {
    return supportedSubtitleExtensions.contains(extension);
  }

  /// 获取不带扩展名的文件名
  ///
  /// [fileName] 文件名
  /// 返回不含扩展名的文件名
  static String _getFileNameWithoutExtension(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex != -1) {
      return fileName.substring(0, lastDotIndex);
    }
    return fileName;
  }

  /// 根据视频文件路径自动检测同名字幕文件
  ///
  /// [videoPath] 视频文件路径
  /// 返回第一个存在的同名字幕文件路径，未找到返回 null
  static String? _detectSubtitleFile(String videoPath) {
    final normalizedVideoPath = normalizePath(videoPath);
    final dir = path.dirname(normalizedVideoPath);
    final stem = path.basenameWithoutExtension(normalizedVideoPath);
    if (stem.isEmpty) return null;

    for (final ext in supportedSubtitleExtensions) {
      final sp = path.join(dir, '$stem$ext');
      if (FileSystemEntity.isFileSync(sp)) return sp;

      final upper = path.join(dir, '$stem${ext.toUpperCase()}');
      if (upper != sp && FileSystemEntity.isFileSync(upper)) return upper;
    }

    try {
      final directory = Directory(dir);
      final entities = directory.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is! File) continue;
        final ext = _getFileExtension(entity.path);
        if (!_isSubtitleFile(ext)) continue;
        if (path.basenameWithoutExtension(entity.path) == stem) {
          return entity.path;
        }
      }
    } catch (_) {}

    return null;
  }

  static bool _isProbablyIosTmpPath(String filePath) {
    if (!Platform.isIOS) return false;
    final p = normalizePath(filePath);
    if (!p.contains('/tmp/')) return false;
    if (p.contains('/Containers/Data/Application/')) return true;
    if (p.contains('/var/mobile/Containers/Data/Application/')) return true;
    return false;
  }

  static Future<({String videoPath, String? subtitlePath})> _persistIosTmpFilesIfNeeded({
    required String videoPath,
    required String? subtitlePath,
    required String folderCode,
    required String videoCode,
  }) async {
    if (!_isProbablyIosTmpPath(videoPath)) {
      return (videoPath: videoPath, subtitlePath: subtitlePath);
    }

    try {
      subtitlePath ??= _detectSubtitleFile(videoPath);

      final directory = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${directory.path}/videos/$folderCode');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      final videoExt = _getFileExtension(videoPath);
      final destVideoPath = '${videosDir.path}/$videoCode$videoExt';
      final srcVideo = File(videoPath);
      if (await srcVideo.exists()) {
        try {
          await srcVideo.rename(destVideoPath);
        } catch (_) {
          await srcVideo.copy(destVideoPath);
          try {
            await srcVideo.delete();
          } catch (_) {}
        }
        videoPath = destVideoPath;
      }

      if (subtitlePath != null && subtitlePath.isNotEmpty && _isProbablyIosTmpPath(subtitlePath)) {
        final srcSub = File(subtitlePath);
        if (await srcSub.exists()) {
          final subExt = _getFileExtension(subtitlePath);
          final destSubPath = '${videosDir.path}/$videoCode$subExt';
          try {
            await srcSub.rename(destSubPath);
          } catch (_) {
            await srcSub.copy(destSubPath);
            try {
              await srcSub.delete();
            } catch (_) {}
          }
          subtitlePath = destSubPath;
        }
      }
    } catch (_) {}

    return (videoPath: videoPath, subtitlePath: subtitlePath);
  }

  /// 获取视频时长
  ///
  /// [filePath] 视频文件路径
  /// 返回视频时长（毫秒），获取失败返回0
  static Future<int> _getVideoDuration(String filePath, {String? videoCode}) async {
    VideoPlayerController? controller;
    try {
      logger.info('duration start', tag: 'IMPORT_VIDEO', extra: {'video': filePath, 'videoCode': videoCode});
      controller = VideoPlayerController.file(File(filePath));
      await controller.initialize();
      final duration = controller.value.duration.inMilliseconds;
      logger.info('duration done', tag: 'IMPORT_VIDEO', extra: {'video': filePath, 'videoCode': videoCode, 'durationMs': duration});
      return duration;
    } catch (e, st) {
      logger.error('duration error', tag: 'IMPORT_VIDEO', error: e, stackTrace: st, extra: {'video': filePath, 'videoCode': videoCode});
      return 0;
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
    }
  }

  /// 更新文件夹封面
  ///
  /// [folderCode] 文件夹 code
  ///
  /// 将该文件夹中最近播放的视频封面设为文件夹封面
  static Future<void> _updateFolderCover(String folderCode) async {
    // 查询该文件夹下的视频，按最近播放时间和创建时间排序
    final videos = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [folderCode],
      orderBy: 'play_date DESC, created_at ASC',
    );

    if (videos.isNotEmpty) {
      final coverVideo = videos.first;
      if (coverVideo.cover != null) {
        // 更新文件夹封面
        await DatabaseService.update(
          VideoFolder()
            ..code = folderCode
            ..cover = coverVideo.cover,
        );
      }
    }
  }

  /// 复制文件到应用目录
  ///
  /// [sourcePath] 源文件路径
  /// [folderCode] 文件夹 code（用于组织文件）
  /// [videoCode] 视频 code（用于命名文件）
  ///
  /// 将视频文件复制到应用的文档目录，便于统一管理
  static Future<void> copyFileToAppDirectory(String sourcePath, String folderCode, String videoCode) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // 按文件夹组织视频存储
      final videosDir = Directory('${directory.path}/videos/$folderCode');

      // 创建目录（如果不存在）
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      final sourceFile = File(sourcePath);
      final extension = _getFileExtension(sourcePath);
      final destinationPath = '${videosDir.path}/$videoCode$extension';
      final destinationFile = File(destinationPath);

      // 仅在目标文件不存在时复制
      if (!await destinationFile.exists()) {
        await sourceFile.copy(destinationPath);
      }
    } catch (e) {
      // 静默处理复制失败
    }
  }
}
