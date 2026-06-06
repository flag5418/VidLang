/// 文件夹详情页面
///
/// 展示文件夹内的资源列表，适配视频/文章/音频3类资源。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:vidlang/components/main_video_card.dart';
import 'package:vidlang/components/playback_settings_sheet.dart';
import 'package:vidlang/components/video_card.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_chapter.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/models/playback_settings.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/file_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/file_picker_service.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/files/wifi_transfer_page.dart';
import 'package:vidlang/views/player/player_page.dart';

/// 文件夹详情页面
class FolderDetailPage extends ConsumerStatefulWidget {
  final String folderCode;

  const FolderDetailPage({super.key, required this.folderCode});

  @override
  ConsumerState<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends ConsumerState<FolderDetailPage> {
  bool _isImporting = false;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    if (widget.folderCode.trim().isEmpty) {
      _pageError = '视频集标识为空，无法加载详情';
      return;
    }
    Future.microtask(() => ref.read(fileProvider.notifier).loadVideos(widget.folderCode));
  }

  String _typeLabel(FolderContentType type) {
    switch (type) {
      case FolderContentType.video:
        return '视频';
      case FolderContentType.article:
        return '文章';
      case FolderContentType.music:
        return '音频';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fileProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final folder = state.currentFolder;
    final folderType = folder?.folderType ?? FolderContentType.video;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              _buildHeader(folder?.name ?? '', folderType, colorScheme),
              SizedBox(height: AppSpacing.md),
              Expanded(
                child: state.isLoading || _isImporting
                    ? const Center(child: CircularProgressIndicator())
                    : _pageError != null
                    ? _buildErrorState(colorScheme, _pageError!)
                    : state.error != null && state.videos.isEmpty
                    ? _buildErrorState(colorScheme, state.error!)
                    : state.videos.isEmpty
                    ? _buildEmptyState(colorScheme, folderType)
                    : _buildContent(state, folderType),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title, FolderContentType folderType, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppColors.surfaceElevated),
                  child: Icon(Icons.arrow_back, size: 20, color: colorScheme.onSurface),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: AppTypography.fontSizeLarge, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Row(
          spacing: AppSpacing.space2,
          children: [
            if (folderType != FolderContentType.article)
              GestureDetector(
                onTap: _showSettings,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: AppColors.surfaceElevated),
                  child: Icon(Icons.settings, size: 18, color: colorScheme.onSurfaceVariant),
                ),
              ),

            PopupMenuButton<String>(
              enabled: !_isImporting,
              onSelected: _handleMenuAction,
              offset: const Offset(0, 44),
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 8,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: colorScheme.primary),
                child: Icon(Icons.add, size: 18, color: colorScheme.onPrimary),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'import', child: _popupMenuItem(Icons.add_circle_outline, '选择导入（可多选）', colorScheme)),
                if (Platform.isIOS && folderType == FolderContentType.video)
                  PopupMenuItem(value: 'importFolder', child: _popupMenuItem(Icons.folder_open, '导入文件夹（全部）', colorScheme)),
                PopupMenuDivider(height: 1),
                PopupMenuItem(value: 'wifi', child: _popupMenuItem(Icons.wifi_rounded, 'WiFi 导入', colorScheme)),
                PopupMenuItem(value: 'rename', child: _popupMenuItem(Icons.edit_outlined, '重命名', colorScheme)),
                PopupMenuItem(value: 'test', child: _popupMenuItem(Icons.quiz_outlined, '综合测试', colorScheme)),
                PopupMenuDivider(height: 1),
                PopupMenuItem(value: 'deleteAll', child: _popupMenuItem(Icons.delete_forever_rounded, '全部删除', colorScheme)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, FolderContentType folderType) {
    final icon = folderType == FolderContentType.video
        ? Icons.videocam
        : folderType == FolderContentType.article
        ? Icons.article
        : Icons.headphones;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          SizedBox(height: AppSpacing.md),
          Text('暂无${_typeLabel(folderType)}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          SizedBox(height: AppSpacing.sm),
          Text('点击 + 导入资源', style: TextStyle(fontSize: 13, color: colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: colorScheme.error.withValues(alpha: 0.8)),
          SizedBox(height: AppSpacing.md),
          Text(
            '加载失败',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 44,
            child: OutlinedButton(onPressed: () => ref.read(fileProvider.notifier).loadVideos(widget.folderCode), child: const Text('重试')),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(FileState state, FolderContentType folderType) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 900 ? 4 : (screenWidth >= 600 ? 3 : 2);
    final mainVideo = state.currentVideo ?? (state.videos.isNotEmpty ? state.videos.first : null);
    final gridVideos = mainVideo == null ? state.videos : state.videos.where((v) => v.code != mainVideo.code).toList();

    return CustomScrollView(
      slivers: [
        if (mainVideo != null)
          SliverToBoxAdapter(
            child: MainVideoCard(
              video: mainVideo,
              onPlay: () => _playVideo(mainVideo),
              onRename: () => _showVideoRenameDialog(mainVideo),
              onImportSubtitle: () => _importSubtitleForVideo(mainVideo),
              onDelete: () => _confirmDeleteVideo(mainVideo),
            ),
          ),
        if (mainVideo != null) SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            final video = gridVideos[index];
            return VideoCard(
              video: video,
              isCurrentPlaying: video.isCurrentPlaying,
              onTap: () => _playVideo(video),
              onRename: () => _showVideoRenameDialog(video),
              onImportSubtitle: () => _importSubtitleForVideo(video),
              onDelete: () => _confirmDeleteVideo(video),
            );
          }, childCount: gridVideos.length),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 16 / 9,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
      ],
    );
  }

  Future<void> _playVideo(dynamic video) async {
    final code = video.code;
    if (code == null || code.isEmpty) return;
    final state = ref.read(fileProvider);
    await ref.read(fileProvider.notifier).selectVideo(code);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerPage(videoCode: code, folderVideos: state.videos),
      ),
    );
  }

  /// 显示 + 按钮的下拉菜单
  Widget _popupMenuItem(IconData icon, String title, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        SizedBox(width: 10),
        Text(title, style: TextStyle(color: cs.onSurface, fontSize: 14)),
      ],
    );
  }

  /// 确认全部删除
  Future<void> _confirmDeleteAll() async {
    final folder = ref.read(fileProvider).currentFolder;
    if (folder == null) return;
    final colorScheme = Theme.of(context).colorScheme;
    final typeLabel = _typeLabel(folder.folderType);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('删除确认', style: TextStyle(color: colorScheme.onSurface)),
        content: Text('确定要删除当前$typeLabel文件夹及其所有资源吗？\n此操作不可恢复。', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确认删除', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await ref.read(fileProvider.notifier).deleteFolder(folder.code!);
      if (result == null && mounted) {
        Navigator.pop(context);
      } else if (result != null) {
        _showMessage('删除失败: $result', theme: MessageTheme.error);
      }
    }
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'import':
        _importResourcesByType();
        break;
      case 'importFolder':
        _importWholeFolderForIosVideo();
        break;
      case 'wifi':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WifiTransferPage()));
        break;
      case 'rename':
        _showRenameDialog();
        break;
      case 'test':
        _showComprehensiveTest();
        break;
      case 'deleteAll':
        _confirmDeleteAll();
        break;
    }
  }

  /// 根据当前文件夹类型导入资源
  Future<void> _importResourcesByType() async {
    final folder = ref.read(fileProvider).currentFolder;
    if (folder == null) return;

    setState(() => _isImporting = true);
    try {
      switch (folder.folderType) {
        case FolderContentType.video:
          await _importVideos();
          break;
        case FolderContentType.article:
          await _importArticles();
          break;
        case FolderContentType.music:
          await _importMusic();
          break;
      }
      await ref.read(fileProvider.notifier).loadVideos(widget.folderCode);
      _showMessage('导入完成');
    } catch (e) {
      _showMessage('导入失败: $e', theme: MessageTheme.error);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _importWholeFolderForIosVideo() async {
    if (!Platform.isIOS) return;
    final folder = ref.read(fileProvider).currentFolder;
    if (folder == null || folder.folderType != FolderContentType.video) return;

    setState(() => _isImporting = true);
    try {
      final folderPath = await FilePickerService.pickFolder();
      if (folderPath == null || folderPath.trim().isEmpty) return;

      final scanned = await FilePickerService.scanFilesInFolder(folderPath);
      final videoPaths = scanned['videos'] ?? [];
      final subtitlePaths = scanned['subtitles'] ?? [];
      if (videoPaths.isEmpty) return;

      final subtitleMap = <String, String>{};
      for (final subtitlePath in subtitlePaths) {
        final sp = FilePickerService.normalizePath(subtitlePath);
        subtitleMap[_getFileNameWithoutExtension(path.basename(sp))] = sp;
      }

      for (final videoPath in videoPaths) {
        final vp = FilePickerService.normalizePath(videoPath);
        final name = _getFileNameWithoutExtension(path.basename(vp));
        await FilePickerService.importVideoWithSubtitle(vp, subtitleMap[name], widget.folderCode);
      }

      await ref.read(fileProvider.notifier).loadVideos(widget.folderCode);
      _showMessage('导入完成');
    } catch (e) {
      _showMessage('导入失败: $e', theme: MessageTheme.error);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// 选择文件（兼容不同 file_picker 版本）
  Future<FilePickerResult?> _pickFiles({required FileType type, List<String>? allowedExtensions, bool allowMultiple = true}) async {
    try {
      return await FilePicker.pickFiles(type: type, allowedExtensions: allowedExtensions, allowMultiple: allowMultiple);
    } catch (e) {
      return null;
    }
  }

  /// 导入视频文件（自动检测同目录下的同名字幕文件）
  Future<void> _importVideos() async {
    if (Platform.isIOS) {
      final result = await FilePicker.pickFiles(type: FileType.any, allowMultiple: true, withData: false, dialogTitle: '选择视频与字幕（同一文件夹可多选）');
      if (result == null || result.files.isEmpty) return;

      final videos = <String>[];
      final subtitleMap = <String, String>{};
      for (final f in result.files) {
        if (f.path == null) continue;
        final p = FilePickerService.normalizePath(f.path!);
        final ext = FilePickerService.normalizePath(path.extension(p)).toLowerCase();
        final base = _getFileNameWithoutExtension(path.basename(p));
        if (FilePickerService.supportedSubtitleExtensions.contains(ext)) {
          subtitleMap[base] = p;
        } else if (FilePickerService.supportedVideoExtensions.contains(ext)) {
          videos.add(p);
        }
      }

      for (final vp in videos) {
        final name = _getFileNameWithoutExtension(path.basename(vp));
        await FilePickerService.importVideoWithSubtitle(vp, subtitleMap[name], widget.folderCode);
      }
      return;
    }

    final files = await FilePickerService.pickVideos();
    if (files.isEmpty) return;
    await FilePickerService.importVideos(files, widget.folderCode);
  }

  /// 导入文章文件
  Future<void> _importArticles() async {
    final result = await _pickFiles(type: FileType.custom, allowedExtensions: ['txt', 'md', 'markdown'], allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      if (file.path == null) continue;
      await _importSingleArticle(file.path!, file.name);
    }
  }

  /// 导入单个文章
  Future<void> _importSingleArticle(String filePath, String fileName) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final content = await file.readAsString();
    final title = _getFileNameWithoutExtension(fileName);
    final folderCode = widget.folderCode;

    final article = Article(folderCode: folderCode, title: title, contentMarkdown: content, language: 'en');
    article.code = const Uuid().v4().replaceAll('-', '');
    await DatabaseService.insert(article);

    // 解析章节和句子
    await _parseArticleContent(article, content);
  }

  /// 解析文章内容为章节和句子
  Future<void> _parseArticleContent(Article article, String content) async {
    final lines = content.split('\n');
    final chapters = <ArticleChapter>[];
    final sentences = <ArticleSentence>[];
    int chapterIndex = 0;
    int sentenceIndex = 0;
    String currentChapterTitle = 'Introduction';
    List<String> chapterLines = [];

    for (final line in lines) {
      if (line.trim().startsWith('# ')) {
        // 保存上一章
        if (chapterLines.isNotEmpty) {
          _processChapterLines(article, chapters, sentences, chapterIndex, currentChapterTitle, chapterLines, sentenceIndex);
          sentenceIndex = sentences.length;
          chapterIndex++;
          chapterLines = [];
        }
        // 移除 # 前缀，多个 # 视为子章节标题但保留在同一章
        currentChapterTitle = line.trim().replaceAll(RegExp(r'^#+\s*'), '');
      } else {
        chapterLines.add(line);
      }
    }
    // 最后一章
    if (chapterLines.isNotEmpty || chapterIndex == 0) {
      _processChapterLines(article, chapters, sentences, chapterIndex, currentChapterTitle, chapterLines, sentenceIndex);
    }

    // 批量保存
    for (final ch in chapters) {
      await DatabaseService.insert(ch);
    }
    for (final s in sentences) {
      await DatabaseService.insert(s);
    }

    // 更新文章统计
    article.totalChapters = chapters.length;
    article.totalSentences = sentences.length;
    await DatabaseService.update(article);
  }

  void _processChapterLines(
    Article article,
    List<ArticleChapter> chapters,
    List<ArticleSentence> sentences,
    int chapterIndex,
    String title,
    List<String> lines,
    int startSentenceIndex,
  ) {
    final fullText = lines.join(' ').trim();
    if (fullText.isEmpty) return;

    // 按句号/问号/感叹号分割句子
    final sentenceParts = fullText.split(RegExp(r'(?<=[.!?])\s+'));
    final chapterSentences = <String>[];
    int wordCount = 0;
    int sentenceCount = 0;

    for (final part in sentenceParts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      chapterSentences.add(trimmed);
      final ws = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      wordCount += ws;
      sentenceCount++;

      sentences.add(
        ArticleSentence(
          articleCode: article.code!,
          chapterCode: null, // 稍后设置
          content: trimmed,
          sentenceIndex: startSentenceIndex + sentences.length,
          wordCount: ws,
          startPositionMs: (sentences.length) * 3000,
          endPositionMs: (sentences.length + 1) * 3000,
        )..code = const Uuid().v4().replaceAll('-', ''),
      );
    }

    final chapter = ArticleChapter(
      articleCode: article.code!,
      title: title,
      chapterIndex: chapterIndex,
      sentenceCount: sentenceCount,
      plainText: chapterSentences.join(' '),
      startSentenceIndex: startSentenceIndex,
      endSentenceIndex: startSentenceIndex + sentenceCount - 1,
    );
    chapter.code = const Uuid().v4().replaceAll('-', '');
    chapters.add(chapter);

    // 更新句子的 chapterCode
    for (int i = sentences.length - sentenceCount; i < sentences.length; i++) {
      sentences[i].chapterCode = chapter.code;
    }
  }

  /// 导入音频文件
  Future<void> _importMusic() async {
    final result = await _pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'wma'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      if (file.path == null) continue;
      await _importLocalVideo(file.path!, widget.folderCode);
    }
  }

  /// 导入本地视频/音频文件到数据库
  Future<void> _importLocalVideo(String filePath, String folderCode) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(filePath);
    if (!await file.exists()) return;

    final fileName = _getFileNameWithoutExtension(filePath);
    final extension = _getFileExtension(filePath);
    final videoCode = const Uuid().v4().replaceAll('-', '');
    final coverCode = const Uuid().v4().replaceAll('-', '');

    // 复制文件到应用目录
    final destDir = Directory('${docs.path}/videos/$folderCode');
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final destPath = '${destDir.path}/$videoCode$extension';
    await file.copy(destPath);

    // 获取时长
    int durationMs = 0;
    try {
      final controller = VideoPlayerController.file(File(destPath));
      await controller.initialize();
      durationMs = controller.value.duration.inMilliseconds;
      await controller.dispose();
    } catch (_) {}

    // 生成缩略图
    String? coverPath;
    try {
      final coverFile = 'covers/$folderCode/$coverCode.jpg';
      final fullCoverPath = await ThumbnailService.getFullPath(coverFile);
      final coverDir = Directory(fullCoverPath);
      if (!await coverDir.exists()) {
        await coverDir.create(recursive: true);
      }
      await VideoThumbnail.thumbnailFile(video: destPath, thumbnailPath: fullCoverPath, imageFormat: ImageFormat.JPEG, maxWidth: 512, timeMs: 5000);
      coverPath = coverFile;
    } catch (_) {}

    // 检测同名字幕文件
    final subtitleBasePath = filePath.substring(0, filePath.lastIndexOf('.'));
    String? subtitlePath;
    for (final ext in ['.srt', '.ass', '.ssa', '.vtt']) {
      final sp = '$subtitleBasePath$ext';
      if (await File(sp).exists()) {
        subtitlePath = sp;
        break;
      }
    }

    // 保存到数据库
    final video = VideoInfo(
      name: fileName,
      folderCode: folderCode,
      filePath: destPath,
      subtitlePath: subtitlePath,
      extensionName: extension.replaceAll('.', ''),
      duration: durationMs,
      cover: coverPath,
      hasSubtitles: subtitlePath != null && subtitlePath.isNotEmpty,
      fileType: 'virtual',
    );
    video.code = videoCode;
    await DatabaseService.insert(video);

    // 导入字幕
    if (subtitlePath != null) {
      await _importSubtitles(subtitlePath, videoCode);
    }
  }

  /// 导入字幕文件
  Future<void> _importSubtitles(String subtitlePath, String videoCode) async {
    final subFile = File(subtitlePath);
    if (!await subFile.exists()) return;

    final content = await subFile.readAsString();
    final subtitles = <Subtitles>[];
    var buf = StringBuffer();
    int lastMs = 0;

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty && buf.isNotEmpty) {
        buf.clear();
        continue;
      }
      // 检查是否为时间轴行
      if (trimmed.contains('-->')) {
        final parts = trimmed.split('-->');
        if (parts.length >= 2) {
          final startStr = parts[0].trim();
          final endStr = parts[1].trim();
          final startMs = _srtTimeToMs(startStr);
          _srtTimeToMs(endStr);

          if (lastMs > 0 && buf.isNotEmpty) {
            subtitles.add(
              Subtitles(videoCode: videoCode, startPosition: lastMs, endPosition: startMs, content: buf.toString().trim(), type: 'subtitle')
                ..code = const Uuid().v4().replaceAll('-', ''),
            );
          }
          buf = StringBuffer();
          lastMs = startMs;
          buf.write(endStr.split(RegExp(r'\s+')).first);
        }
        continue;
      }
      if (!trimmed.contains('-->') && !RegExp(r'^\d+$').hasMatch(trimmed)) {
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(trimmed);
      }
    }

    // 最后一条
    if (buf.isNotEmpty) {
      subtitles.add(
        Subtitles(videoCode: videoCode, startPosition: lastMs, endPosition: lastMs + 3000, content: buf.toString().trim(), type: 'subtitle')
          ..code = const Uuid().v4().replaceAll('-', ''),
      );
    }

    for (final s in subtitles) {
      await DatabaseService.insert(s);
    }
  }

  /// SRT 时间格式转毫秒
  int _srtTimeToMs(String timeStr) {
    final parts = timeStr.trim().split(RegExp(r'[:,]'));
    if (parts.length >= 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = double.tryParse(parts[2]) ?? 0.0;
      return (h * 3600000 + m * 60000 + (s * 1000).round());
    }
    return 0;
  }

  String _getFileNameWithoutExtension(String filePath) {
    final name = filePath.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String _getFileExtension(String filePath) {
    final dot = filePath.lastIndexOf('.');
    return dot > 0 ? filePath.substring(dot).toLowerCase() : '';
  }

  /// 重命名当前文件夹
  Future<void> _showRenameDialog() async {
    final folder = ref.read(fileProvider).currentFolder;
    if (folder == null) return;
    final colorScheme = Theme.of(context).colorScheme;

    final controller = TextEditingController(text: folder.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('重命名', style: TextStyle(color: colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                folder.name = name;
                await DatabaseService.update(folder);
                await ref.read(fileProvider.notifier).loadVideos(widget.folderCode);
              } catch (e) {
                _showMessage('重命名失败: $e', theme: MessageTheme.error);
              }
            },
            child: Text('保存', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  /// 综合测试（针对当前资源集所有资源）
  /// 视频重命名
  Future<void> _showVideoRenameDialog(dynamic video) async {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: video.name ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('重命名视频', style: TextStyle(color: colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(fileProvider.notifier).renameVideo(video.code ?? '', name);
                _showMessage('重命名成功');
              } catch (e) {
                _showMessage('重命名失败: $e', theme: MessageTheme.error);
              }
            },
            child: Text('保存', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  /// 为视频导入字幕文件
  Future<void> _importSubtitleForVideo(dynamic video) async {
    final result = await _pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'ass', 'ssa', 'vtt'], allowMultiple: false);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final subtitlePath = result.files.first.path!;
    try {
      await ref.read(fileProvider.notifier).importSubtitleForVideo(video.code ?? '', subtitlePath);
      _showMessage('字幕导入成功');
    } catch (e) {
      _showMessage('导入字幕失败: $e', theme: MessageTheme.error);
    }
  }

  /// 确认删除视频
  Future<void> _confirmDeleteVideo(dynamic video) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('删除确认', style: TextStyle(color: colorScheme.onSurface)),
        content: Text('确定要删除「${video.name ?? ''}」吗？\n此操作不可恢复。', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确认删除', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(fileProvider.notifier).deleteVideo(video.code ?? '');
        _showMessage('删除成功');
      } catch (e) {
        _showMessage('删除失败: $e', theme: MessageTheme.error);
      }
    }
  }

  Future<void> _showComprehensiveTest() async {
    final folder = ref.read(fileProvider).currentFolder;
    final typeLabel = _typeLabel(folder?.folderType ?? FolderContentType.video);
    _showMessage('$typeLabel 综合测试功能开发中', theme: MessageTheme.info);
  }

  void _showSettings() {
    final folder = ref.read(fileProvider).currentFolder;
    if (folder == null) return;

    PlaybackSettingsSheet.show(
      context,
      initial: PlaybackSettings.fromFolder(folder),
      onSave: (settings) async {
        await ref.read(fileProvider.notifier).updateFolderPlaybackSettings(folder.code!, settings);
      },
    );
  }

  void _showMessage(String content, {MessageTheme theme = MessageTheme.info}) {
    TDMessage.showMessage(context: context, content: content, visible: true, icon: true, theme: theme, duration: 3000);
  }
}
