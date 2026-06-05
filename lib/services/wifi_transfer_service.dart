library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:vidlang/models/error_log.dart';
import 'package:vidlang/models/participle.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_chapter.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/file_picker_service.dart';
import 'package:vidlang/services/folder_stats_service.dart';
import 'package:vidlang/services/settings_service.dart';
import 'package:vidlang/services/thumbnail_service.dart';

class WifiTransferService extends ChangeNotifier {
  static final WifiTransferService instance = WifiTransferService._();
  WifiTransferService._();

  HttpServer? _server;
  int? _port;
  List<String> _addresses = const [];
  Uint8List? _emptyPng;

  bool get isRunning => _server != null;
  int? get port => _port;
  List<String> get addresses => _addresses;

  String? get primaryUrl {
    if (_addresses.isEmpty || _port == null) return null;
    return 'http://${_addresses.first}:$_port/';
  }

  Future<void> start({int preferredPort = 9999}) async {
    if (isRunning) return;

    HttpServer? server;
    int? boundPort;

    for (int i = 0; i <= 20; i++) {
      final tryPort = preferredPort + i;
      try {
        server = await HttpServer.bind(InternetAddress.anyIPv4, tryPort, shared: true);
        boundPort = tryPort;
        break;
      } catch (_) {}
    }

    if (server == null || boundPort == null) {
      throw Exception('端口绑定失败（从 $preferredPort 开始尝试 21 个端口）');
    }

    _server = server;
    _port = boundPort;
    _addresses = await _resolveLanIPv4Addresses();

    server.listen(
      (req) async {
        try {
          await _handle(req);
        } catch (e, st) {
          logger.error('wifi request failed', tag: 'WIFI', error: e, stackTrace: st);
          await _tryPersistError('WIFI', 'wifi request failed', e, st, extra: {'path': req.uri.path, 'method': req.method});
          _replyJson(req.response, 500, {'ok': false, 'message': e.toString()});
        }
      },
      onError: (e, st) async {
        logger.error('wifi server error', tag: 'WIFI', error: e, stackTrace: st);
        await _tryPersistError('WIFI', 'wifi server error', e, st);
      },
    );

    logger.info('wifi server started', tag: 'WIFI', extra: {'port': boundPort, 'addresses': _addresses});
    notifyListeners();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _port = null;
    _addresses = const [];
    notifyListeners();
    try {
      await server?.close(force: true);
    } catch (_) {}
  }

  Future<List<String>> _resolveLanIPv4Addresses() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      final ips = <String>[];
      for (final i in interfaces) {
        for (final addr in i.addresses) {
          final ip = addr.address;
          if (ip.startsWith('169.254.')) continue;
          ips.add(ip);
        }
      }
      return ips.isEmpty ? const ['127.0.0.1'] : ips;
    } catch (_) {
      return const ['127.0.0.1'];
    }
  }

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    if (req.method == 'OPTIONS') {
      return _replyJson(req.response, 204, {});
    }
    if (path == '/' && req.method == 'GET') {
      return _replyHtml(req.response, _html());
    }
    if (path == '/assets/empty.png' && req.method == 'GET') {
      final bytes = await _loadEmptyPng();
      return _replyBytes(req.response, bytes, contentType: ContentType('image', 'png'));
    }

    if (path == '/api/folders' && req.method == 'GET') {
      final folders = await _listFolders();
      return _replyJson(req.response, 200, {'ok': true, 'data': folders});
    }

    if (path == '/api/folders' && req.method == 'POST') {
      final body = await _readJson(req);
      final name = (body['name'] ?? '').toString().trim();
      final type = (body['type'] ?? '').toString().trim().toLowerCase();
      if (name.isEmpty) return _replyJson(req.response, 400, {'ok': false, 'message': 'name 不能为空'});
      final contentType = (body['contentType'] ?? 'video').toString().trim();
      final folder = await _createFolder(name, type: type, contentType: contentType);
      return _replyJson(req.response, 200, {'ok': true, 'data': _folderJson(folder)});
    }

    final folderRename = RegExp(r'^/api/folders/([a-zA-Z0-9]+)$').firstMatch(path);
    if (folderRename != null && req.method == 'PATCH') {
      final folderCode = folderRename.group(1)!;
      final body = await _readJson(req);
      final name = (body['name'] ?? '').toString().trim();
      if (name.isEmpty) return _replyJson(req.response, 400, {'ok': false, 'message': 'name 不能为空'});
      final folder = await _renameFolder(folderCode, name);
      return _replyJson(req.response, 200, {'ok': true, 'data': _folderJson(folder)});
    }
    if (folderRename != null && req.method == 'DELETE') {
      final folderCode = folderRename.group(1)!;
      await _deleteFolder(folderCode);
      return _replyJson(req.response, 200, {'ok': true});
    }

    final listVideos = RegExp(r'^/api/folders/([a-zA-Z0-9]+)/videos$').firstMatch(path);
    if (listVideos != null && req.method == 'GET') {
      final folderCode = listVideos.group(1)!;
      final videos = await _listVideos(folderCode);
      return _replyJson(req.response, 200, {'ok': true, 'data': videos});
    }

    final upload = RegExp(r'^/api/folders/([a-zA-Z0-9]+)/upload$').firstMatch(path);
    if (upload != null && req.method == 'PUT') {
      final folderCode = upload.group(1)!;
      final filename = (req.uri.queryParameters['filename'] ?? '').trim();
      if (filename.isEmpty) return _replyJson(req.response, 400, {'ok': false, 'message': 'filename 不能为空'});
      final video = await _uploadVideo(req, folderCode: folderCode, filename: filename);
      return _replyJson(req.response, 200, {'ok': true, 'data': _videoJson(video)});
    }

    final renameVideo = RegExp(r'^/api/videos/([a-zA-Z0-9]+)$').firstMatch(path);
    if (renameVideo != null && req.method == 'PATCH') {
      final videoCode = renameVideo.group(1)!;
      final body = await _readJson(req);
      final name = (body['name'] ?? '').toString().trim();
      if (name.isEmpty) return _replyJson(req.response, 400, {'ok': false, 'message': 'name 不能为空'});
      final video = await _renameVideo(videoCode, name);
      return _replyJson(req.response, 200, {'ok': true, 'data': _videoJson(video)});
    }
    if (renameVideo != null && req.method == 'DELETE') {
      final videoCode = renameVideo.group(1)!;
      await _deleteVideo(videoCode);
      return _replyJson(req.response, 200, {'ok': true});
    }

    final uploadSubtitle = RegExp(r'^/api/videos/([a-zA-Z0-9]+)/subtitle$').firstMatch(path);
    if (uploadSubtitle != null && req.method == 'PUT') {
      final videoCode = uploadSubtitle.group(1)!;
      final filename = (req.uri.queryParameters['filename'] ?? '').trim();
      if (filename.isEmpty) return _replyJson(req.response, 400, {'ok': false, 'message': 'filename 不能为空'});
      final video = await _uploadSubtitle(req, videoCode: videoCode, filename: filename);
      return _replyJson(req.response, 200, {'ok': true, 'data': _videoJson(video)});
    }


    // === Article routes ===
    final listArticles = RegExp(r'^/api/folders/([a-zA-Z0-9]+)/articles$').firstMatch(path);
    if (listArticles != null && req.method == 'GET') {
      final folderCode = listArticles.group(1)!;
      final articles = await _listArticles(folderCode);
      return _replyJson(req.response, 200, {'ok': true, 'data': articles});
    }

    final uploadArticle = RegExp(r'^/api/folders/([a-zA-Z0-9]+)/article$').firstMatch(path);
    if (uploadArticle != null && req.method == 'PUT') {
      final folderCode = uploadArticle.group(1)!;
      final filename = (req.uri.queryParameters['filename'] ?? '').trim();
      if (filename.isEmpty) return _replyJson(req.response, 400, {'ok': false, 'message': 'filename cannot be empty'});
      final article = await _uploadArticle(req, folderCode: folderCode, filename: filename);
      return _replyJson(req.response, 200, {'ok': true, 'data': _articleJson(article)});
    }

    // Article cover (placeholder)
    final articleCover = RegExp(r'^/api/articles/([a-zA-Z0-9]+)/cover$').firstMatch(path);
    if (articleCover != null && req.method == 'GET') {
      final bytes = await _loadEmptyPng();
      return _replyBytes(req.response, bytes, contentType: ContentType('image', 'png'));
    }

    final coverMatch = RegExp(r'^/api/videos/([a-zA-Z0-9]+)/cover$').firstMatch(path);
    if (coverMatch != null && req.method == 'GET') {
      final videoCode = coverMatch.group(1)!;
      final video = await _getVideoByCode(videoCode);
      final cover = video?.cover;
      if (cover == null || cover.isEmpty) {
        final bytes = await _loadEmptyPng();
        return _replyBytes(req.response, bytes, contentType: ContentType('image', 'png'));
      }
      try {
        final full = await ThumbnailService.getFullPath(cover);
        final f = File(full);
        if (!await f.exists()) {
          final bytes = await _loadEmptyPng();
          return _replyBytes(req.response, bytes, contentType: ContentType('image', 'png'));
        }
        final bytes = await f.readAsBytes();
        return _replyBytes(req.response, bytes, contentType: ContentType('image', 'png'));
      } catch (_) {
        final bytes = await _loadEmptyPng();
        return _replyBytes(req.response, bytes, contentType: ContentType('image', 'png'));
      }
    }

    if (path == '/api/videos/batch_delete' && req.method == 'POST') {
      final body = await _readJson(req);
      final codes = body['codes'];
      if (codes is! List) return _replyJson(req.response, 400, {'ok': false, 'message': 'codes 不能为空'});
      final list = codes.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      await _batchDeleteVideos(list);
      return _replyJson(req.response, 200, {'ok': true});
    }

    final reorder = RegExp(r'^/api/folders/([a-zA-Z0-9]+)/reorder$').firstMatch(path);
    if (reorder != null && req.method == 'POST') {
      final folderCode = reorder.group(1)!;
      final body = await _readJson(req);
      final codes = body['codes'];
      if (codes is! List) return _replyJson(req.response, 400, {'ok': false, 'message': 'codes 不能为空'});
      final list = codes.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      await _reorderVideos(folderCode, list);
      return _replyJson(req.response, 200, {'ok': true});
    }

    _replyJson(req.response, 404, {'ok': false, 'message': 'not found'});
  }

  Future<List<Map<String, Object?>>> _listFolders() async {
    final rows = await DatabaseService.findByCondition(
      () => VideoFolder(),
      where: "is_deleted = 0 AND parent_code IS NOT NULL AND parent_code != ''",
      orderBy: 'CASE WHEN last_play_date IS NULL THEN 1 ELSE 0 END, last_play_date DESC, created_at DESC',
    );
    return rows.map(_folderJson).toList();
  }

  Future<VideoFolder> _createFolder(String name, {required String type, String contentType = 'video'}) async {
    final duplicated = await DatabaseService.findByCondition(() => VideoFolder(), where: 'name = ? AND is_deleted = 0', whereArgs: [name], limit: 1);
    if (duplicated.isNotEmpty) {
      throw Exception('视频集名称已存在');
    }

    final groupCode = await SettingsService.ensureDefaultGroupCode();
    final folderType = type == 'virtual' ? VideoFolderType.virtual : VideoFolderType.real;
    final folderContentType = FolderContentType.values.firstWhere((e) => e.name == contentType, orElse: () => FolderContentType.video);
    final folder = VideoFolder(name: name, type: folderType, parentCode: groupCode, videoCount: 0, completedCount: 0, lastPlayDuration: 0, folderType: folderContentType)
      ..code = const Uuid().v4().replaceAll('-', '');
    await SettingsService.applyGlobalDefaultsToFolder(folder);
    await DatabaseService.insert(folder);
    return folder;
  }

  Future<VideoFolder> _renameFolder(String folderCode, String name) async {
    final folder = await _getFolderByCode(folderCode);
    if (folder == null) throw Exception('文件夹不存在');

    final duplicated = await DatabaseService.findByCondition(
      () => VideoFolder(),
      where: 'name = ? AND code != ? AND is_deleted = 0',
      whereArgs: [name, folderCode],
      limit: 1,
    );
    if (duplicated.isNotEmpty) throw Exception('视频集名称已存在');

    folder.name = name;
    await DatabaseService.update(folder);
    return folder;
  }

  Future<List<Map<String, Object?>>> _listVideos(String folderCode) async {
    final rows = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [folderCode],
      orderBy: 'order_index ASC, created_at ASC',
    );
    return rows.map(_videoJson).toList();
  }

  Future<VideoInfo> _renameVideo(String videoCode, String name) async {
    final video = await _getVideoByCode(videoCode);
    if (video == null) throw Exception('视频不存在');
    video.name = name;
    await DatabaseService.update(video);
    return video;
  }

  Future<VideoInfo> _uploadVideo(HttpRequest req, {required String folderCode, required String filename}) async {
    final folder = await _getFolderByCode(folderCode);
    if (folder == null) throw Exception('文件夹不存在');

    final ext = p.extension(filename).toLowerCase();
    final code = const Uuid().v4().replaceAll('-', '');

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'videos', folderCode));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final dst = p.join(dir.path, '$code$ext');
    final file = File(dst);
    final sink = file.openWrite();
    await for (final data in req) {
      sink.add(data);
    }
    await sink.flush();
    await sink.close();

    int durationMs = 0;
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(File(dst));
      await controller.initialize();
      durationMs = controller.value.duration.inMilliseconds;
    } catch (e, st) {
      logger.error('wifi duration error', tag: 'WIFI', error: e, stackTrace: st, extra: {'file': dst});
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
    }

    int timeSec = folder.thumbnailTime;
    final durationSec = (durationMs / 1000).floor();
    if (durationSec > 0 && timeSec >= durationSec) {
      timeSec = durationSec > 1 ? durationSec - 1 : 0;
    }
    if (ext == '.mkv') {
      timeSec = 0;
    }

    final cover = await ThumbnailService.generateCoverThumbnail(dst, code, timeSec: timeSec);

    final count = await DatabaseService.count(() => VideoInfo(), where: 'folder_code = ? AND is_deleted = 0', whereArgs: [folderCode]);

    final video = VideoInfo(
      name: p.basenameWithoutExtension(filename),
      folderCode: folderCode,
      filePath: dst,
      fileType: 'real',
      extensionName: ext,
      duration: durationMs,
      cover: cover,
      hasSubtitles: false,
      currentPosition: 0,
      isCurrentPlaying: false,
      description: '',
      orderIndex: count + 1,
      playCount: 0,
      totalPlayDuration: 0,
    )..code = code;

    await DatabaseService.insert(video);
    await _normalizeOrderIndex(folderCode);
    await FolderStatsService.refreshFolderStats(folderCode);
    return video;
  }

  Future<VideoInfo> _uploadSubtitle(HttpRequest req, {required String videoCode, required String filename}) async {
    final video = await _getVideoByCode(videoCode);
    if (video == null) throw Exception('视频不存在');

    final bytes = await _readAllBytes(req);
    if (bytes.isEmpty) throw Exception('字幕文件为空');

    final oldPath = video.subtitlePath;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'subtitles', videoCode));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dst = p.join(dir.path, safeName);
    await File(dst).writeAsBytes(bytes, flush: true);

    if (oldPath != null && oldPath.isNotEmpty && oldPath != dst) {
      final sandboxPrefixes = await _sandboxPrefixes();
      final shouldDelete = video.fileType == 'real' || _startsWithAnyPrefix(oldPath, sandboxPrefixes);
      if (shouldDelete) {
        await _deleteFileIfExists(oldPath);
      }
    }

    await _softDeleteSubtitleData(videoCode);
    final stats = await FilePickerService.importSubtitleToDb(dst, video.folderCode, videoCode);

    video.subtitlePath = dst;
    video.hasSubtitles = true;
    await DatabaseService.update(video);

    logger.info(
      'wifi subtitle imported',
      tag: 'WIFI',
      extra: {'videoCode': videoCode, 'file': dst, 'subtitlesInserted': stats.subtitlesInserted, 'participlesInserted': stats.participlesInserted},
    );

    await FolderStatsService.refreshFolderStats(video.folderCode);
    return video;
  }

  Future<void> _softDeleteSubtitleData(String videoCode) async {
    final subtitles = await DatabaseService.findByCondition(() => Subtitles(), where: 'video_code = ? AND is_deleted = 0', whereArgs: [videoCode]);
    for (final s in subtitles) {
      await DatabaseService.softDelete(s);
    }

    final participles = await DatabaseService.findByCondition(() => Participle(), where: 'video_code = ? AND is_deleted = 0', whereArgs: [videoCode]);
    for (final p0 in participles) {
      await DatabaseService.softDelete(p0);
    }
  }

  Future<List<String>> _sandboxPrefixes() async {
    final docs = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    final a = docs.path.replaceAll('\\', '/');
    final b = support.path.replaceAll('\\', '/');
    return [a, b];
  }

  Future<void> _normalizeOrderIndex(String folderCode) async {
    final rows = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [folderCode],
      orderBy: 'order_index ASC, created_at ASC',
    );
    if (rows.isEmpty) return;

    final updated = <VideoInfo>[];
    for (int i = 0; i < rows.length; i++) {
      final v = rows[i];
      final want = i + 1;
      if (v.orderIndex != want) {
        v.orderIndex = want;
        updated.add(v);
      }
    }
    if (updated.isNotEmpty) {
      await DatabaseService.batchUpdate(updated);
    }
  }

  bool _startsWithAnyPrefix(String path0, List<String> prefixes) {
    final p0 = path0.replaceAll('\\', '/');
    for (final prefix in prefixes) {
      if (p0.startsWith(prefix)) return true;
    }
    return false;
  }

  Future<void> _deleteFolder(String folderCode) async {
    final folder = await _getFolderByCode(folderCode);
    if (folder == null) throw Exception('文件夹不存在');

    final videos = await DatabaseService.findByCondition(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [folderCode],
      orderBy: 'created_at ASC',
    );

    for (final v in videos) {
      final code = v.code;
      if (code != null && code.isNotEmpty) {
        await _deleteVideo(code, refreshStats: false, normalize: false);
      }
    }

    await DatabaseService.softDelete(folder);
    await FolderStatsService.refreshFolderStats(folderCode);
  }

  Future<void> _deleteVideo(String videoCode, {bool refreshStats = true, bool normalize = true}) async {
    final video = await _getVideoByCode(videoCode);
    if (video == null) return;

    final sandboxPrefixes = await _sandboxPrefixes();

    if (video.fileType == 'real') {
      await _deleteFileIfExists(video.filePath);
    }

    final subtitlePath = video.subtitlePath;
    if (subtitlePath != null && subtitlePath.isNotEmpty) {
      final shouldDelete = video.fileType == 'real' || _startsWithAnyPrefix(subtitlePath, sandboxPrefixes);
      if (shouldDelete) {
        await _deleteFileIfExists(subtitlePath);
      }
    }

    await ThumbnailService.deleteVideoScreenshots(videoCode);
    await _softDeleteSubtitleData(videoCode);
    await DatabaseService.softDelete(video);

    if (normalize) {
      await _normalizeOrderIndex(video.folderCode);
    }
    if (refreshStats) {
      await FolderStatsService.refreshFolderStats(video.folderCode);
    }
  }

  Future<void> _batchDeleteVideos(List<String> codes) async {
    final folderCodes = <String>{};
    for (final c in codes) {
      final v = await _getVideoByCode(c);
      if (v != null) folderCodes.add(v.folderCode);
      await _deleteVideo(c, refreshStats: false, normalize: false);
    }
    for (final fc in folderCodes) {
      await _normalizeOrderIndex(fc);
      await FolderStatsService.refreshFolderStats(fc);
    }
  }

  Future<void> _reorderVideos(String folderCode, List<String> orderedCodes) async {
    if (orderedCodes.isEmpty) return;

    final rows = await DatabaseService.findByCondition(() => VideoInfo(), where: 'folder_code = ? AND is_deleted = 0', whereArgs: [folderCode]);
    final map = <String, VideoInfo>{};
    for (final v in rows) {
      final c = v.code;
      if (c != null && c.isNotEmpty) map[c] = v;
    }

    final updated = <VideoInfo>[];
    for (int i = 0; i < orderedCodes.length; i++) {
      final code = orderedCodes[i];
      final v = map[code];
      if (v == null) continue;
      v.orderIndex = i + 1;
      updated.add(v);
    }
    if (updated.isNotEmpty) {
      await DatabaseService.batchUpdate(updated);
    }

    await _normalizeOrderIndex(folderCode);
    await FolderStatsService.refreshFolderStats(folderCode);
  }

  Future<void> _deleteFileIfExists(String path0) async {
    try {
      final f = File(path0);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (e, st) {
      logger.error('wifi delete file failed', tag: 'WIFI', error: e, stackTrace: st, extra: {'path': path0});
    }
  }

  Future<Uint8List> _readAllBytes(HttpRequest req) async {
    final chunks = <int>[];
    await for (final data in req) {
      chunks.addAll(data);
    }
    return Uint8List.fromList(chunks);
  }

  Future<VideoFolder?> _getFolderByCode(String code) async {
    final rows = await DatabaseService.findByCondition(() => VideoFolder(), where: 'code = ? AND is_deleted = 0', whereArgs: [code], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<VideoInfo?> _getVideoByCode(String code) async {
    final rows = await DatabaseService.findByCondition(() => VideoInfo(), where: 'code = ? AND is_deleted = 0', whereArgs: [code], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Map<String, Object?> _folderJson(VideoFolder f) {
    return {'code': f.code, 'name': f.name, 'folderType': f.folderType.name, 'canUpload': f.type == VideoFolderType.real};
  }

  Map<String, Object?> _videoJson(VideoInfo v) {
    return {
      'code': v.code,
      'name': v.name,
      'folderCode': v.folderCode,
      'duration': v.duration,
      'cover': v.cover,
      'orderIndex': v.orderIndex,
      'fileType': v.fileType,
      'subtitlePath': v.subtitlePath,
      'hasSubtitles': v.hasSubtitles,
    };
  }

  Map<String, Object?> _articleJson(Article a) {
    return {
      'code': a.code,
      'title': a.title,
      'folderCode': a.folderCode,
      'contentMarkdown': a.contentMarkdown,
      'author': a.author,
      'sourceUrl': a.sourceUrl,
      'totalChapters': a.totalChapters,
      'totalSentences': a.totalSentences,
      'wordCount': a.wordCount,
      'progress': a.progress,
      'orderIndex': a.orderIndex,
      'lastStudyDate': a.lastStudyDate?.toIso8601String(),
    };
  }

  Future<List<Map<String, Object?>>> _listArticles(String folderCode) async {
    final rows = await DatabaseService.findByCondition(
      () => Article(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [folderCode],
      orderBy: 'order_index ASC, created_at ASC',
    );
    return rows.map(_articleJson).toList();
  }


  Future<Article> _uploadArticle(HttpRequest req, {required String folderCode, required String filename}) async {
    final folder = await _getFolderByCode(folderCode);
    if (folder == null) throw Exception('Folder not found');

    final bytes = await _readAllBytes(req);
    if (bytes.isEmpty) throw Exception('Article content is empty');

    final String contentStr = utf8.decode(bytes);
    final String title = p.basenameWithoutExtension(filename);

    // Count chapters - lines starting with # (markdown headers)
    final lines = contentStr.split('\n');
    int totalChapters = 0;
    for (final line in lines) {
      if (line.trim().startsWith('#')) {
        totalChapters++;
      }
    }
    if (totalChapters == 0) totalChapters = 1;

    // Count words
    final wordCount = contentStr.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    final code = const Uuid().v4().replaceAll('-', '');

    final article = Article(
      folderCode: folderCode,
      title: title,
      contentMarkdown: contentStr,
      language: 'en',
      totalChapters: totalChapters,
      totalSentences: 0,
      wordCount: wordCount,
      orderIndex: 0,
    )..code = code;

    await DatabaseService.insert(article);

    // Parse and save chapters + sentences
    await _parseArticleChaptersAndSentences(article);

    return article;
  }

  Future<void> _parseArticleChaptersAndSentences(Article article) async {
    final lines = article.contentMarkdown.split('\n');
    final chapters = <ArticleChapter>[];
    final sentences = <ArticleSentence>[];
    int sentenceIndex = 0;
    int chapterIndex = 0;
    String currentChapterTitle = 'Introduction';
    int chapterStartSentence = 0;
    final chapterSentences = <String>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Check for chapter header (# or ## or ###)
      if (line.startsWith('#')) {
        // Save previous chapter
        if (chapterSentences.isNotEmpty) {
          chapters.add(ArticleChapter(
            articleCode: article.code!,
            title: currentChapterTitle,
            chapterIndex: chapterIndex,
            sentenceCount: chapterSentences.length,
            plainText: chapterSentences.join(' '),
            startSentenceIndex: chapterStartSentence,
            endSentenceIndex: sentenceIndex - 1,
          )..code = const Uuid().v4().replaceAll('-', ''));
        }
        chapterIndex++;
        final headerText = line.replaceAll(RegExp(r'^#+\s+'), '');
        currentChapterTitle = headerText.isNotEmpty ? headerText : 'Chapter $chapterIndex';
        chapterStartSentence = sentenceIndex;
        chapterSentences.clear();
        continue;
      }

      // Simple sentence splitting: split on . ! ? followed by space or end
      final parts = line.split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'));
      if (parts.length <= 1) {
        // Try simpler split
        final simpleParts = <String>[];
        int lastEnd = 0;
        for (int i = 0; i < line.length; i++) {
          final ch = line[i];
          if ((ch == '.' || ch == '!' || ch == '?') && (i + 1 >= line.length || line[i + 1] == ' ')) {
            simpleParts.add(line.substring(lastEnd, i + 1));
            lastEnd = i + 1;
          }
        }
        if (lastEnd < line.length) {
          simpleParts.add(line.substring(lastEnd));
        }
        for (final part in simpleParts) {
          final s = part.trim();
          if (s.isEmpty) continue;
          sentenceIndex++;
          final ws = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
          final chapterCode = chapters.isNotEmpty ? chapters.last.code : null;
          sentences.add(ArticleSentence(
            articleCode: article.code!,
            chapterCode: chapterCode,
            content: s,
            sentenceIndex: sentenceIndex,
            wordCount: ws,
            startPositionMs: (sentenceIndex - 1) * 3000,
            endPositionMs: sentenceIndex * 3000,
          )..code = const Uuid().v4().replaceAll('-', ''));
          chapterSentences.add(s);
        }
      } else {
        // Already split by the regex
        for (final rawSentence in parts) {
          final s = rawSentence.trim();
          if (s.isEmpty) continue;
          sentenceIndex++;
          final ws = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
          final chapterCode = chapters.isNotEmpty ? chapters.last.code : null;
          sentences.add(ArticleSentence(
            articleCode: article.code!,
            chapterCode: chapterCode,
            content: s,
            sentenceIndex: sentenceIndex,
            wordCount: ws,
            startPositionMs: (sentenceIndex - 1) * 3000,
            endPositionMs: sentenceIndex * 3000,
          )..code = const Uuid().v4().replaceAll('-', ''));
          chapterSentences.add(s);
        }
      }
    }

    // Save last chapter
    if (chapterSentences.isNotEmpty || chapterIndex == 0) {
      chapters.add(ArticleChapter(
        articleCode: article.code!,
        title: currentChapterTitle,
        chapterIndex: chapterIndex,
        sentenceCount: chapterSentences.length,
        plainText: chapterSentences.join(' '),
        startSentenceIndex: chapterStartSentence,
        endSentenceIndex: sentenceIndex - 1,
      )..code = const Uuid().v4().replaceAll('-', ''));
    }

    // Batch insert
    for (final ch in chapters) {
      await DatabaseService.insert(ch);
    }
    for (final s in sentences) {
      await DatabaseService.insert(s);
    }

    // Update article stats
    article.totalChapters = chapters.length;
    article.totalSentences = sentenceIndex;
    await DatabaseService.update(article);
  }


  Future<Map<String, dynamic>> _readJson(HttpRequest req) async {
    final body = await utf8.decoder.bind(req).join();
    if (body.trim().isEmpty) return {};
    final obj = jsonDecode(body);
    if (obj is Map<String, dynamic>) return obj;
    return {};
  }

  void _replyHtml(HttpResponse res, String html) {
    res.statusCode = 200;
    res.headers.contentType = ContentType.html;
    res.headers.set('Cache-Control', 'no-store');
    res.write(html);
    res.close();
  }

  void _replyJson(HttpResponse res, int status, Object body) {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
    res.headers.set('Access-Control-Allow-Headers', 'Content-Type');
    res.headers.set('Cache-Control', 'no-store');
    res.write(jsonEncode(body));
    res.close();
  }

  void _replyBytes(HttpResponse res, List<int> bytes, {required ContentType contentType}) {
    res.statusCode = 200;
    res.headers.contentType = contentType;
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Cache-Control', 'no-store');
    res.add(bytes);
    res.close();
  }

  Future<Uint8List> _loadEmptyPng() async {
    final cached = _emptyPng;
    if (cached != null) return cached;
    final data = await rootBundle.load('assets/app/空白.png');
    final bytes = data.buffer.asUint8List();
    _emptyPng = bytes;
    return bytes;
  }

  Future<void> _tryPersistError(String tag, String message, Object error, StackTrace st, {Map<String, Object?>? extra}) async {
    try {
      final userCode = await DatabaseService.getCurrentUserCode();
      final log = ErrorLog(
        level: 'error',
        tag: tag,
        message: message,
        error: error.toString(),
        stackTrace: st.toString(),
        extra: extra == null ? null : jsonEncode(extra),
      );
      log.userCode = userCode;
      log.createdBy = userCode;
      log.updatedBy = userCode;
      await DatabaseService.insert(log);
    } catch (_) {}
  }

  String _html() {
    return '''
<!doctype html>
<html lang="zh">
<head><meta charset="utf-8"/><title>VidLang WiFi</title></head>
<body style="background:#1a1a1a;color:white;font-family:sans-serif;padding:20px">
<h2>VidLang WiFi 传输</h2>
<p>请使用电脑浏览器访问此页面传输文件。</p>
</body>
''';
  }
}
