/// 文件夹详情页面
///
/// 展示文件夹内的资源列表，适配视频/文章/音频3类资源。
library;

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/widgets/app_dialogs.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:vidlang/components/article_hero_card.dart';
import 'package:vidlang/components/article_item_card.dart';
import 'package:vidlang/components/main_video_card.dart';
import 'package:vidlang/components/playback_settings_sheet.dart';
import 'package:vidlang/components/video_card.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/playback_settings.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/file_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/article_parser.dart';
import 'package:vidlang/services/conversation_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/file_picker_service.dart';
import 'package:vidlang/services/id3_parser.dart';
import 'package:vidlang/services/initial_letter_cover.dart';
import 'package:vidlang/services/lrc_parser.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/services/wifi_transfer_service.dart';
import 'package:omni_player/omni_player.dart' show VideoMetadataExtractor;
import 'package:flutter_vscode_logger/flutter_vscode_logger.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/article/article_reader_page.dart';
import 'package:vidlang/views/conversation/conversation_page.dart';
import 'package:vidlang/views/files/wifi_transfer_page.dart';
import 'package:vidlang/views/audio_player/audio_player_page.dart';
import 'package:vidlang/views/player/player_page.dart';
import 'package:vidlang/views/test/test_page.dart';

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
  List<Article> _articles = [];
  bool _articlesLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.folderCode.trim().isEmpty) {
      _pageError = '资源集标识为空，无法加载详情';
      return;
    }
    Future.microtask(() async {
      await ref.read(fileProvider.notifier).loadVideos(widget.folderCode);
      _loadArticlesIfNeeded();
    });
    WifiTransferService.instance.addListener(_onWifiChanged);
  }

  @override
  void dispose() {
    WifiTransferService.instance.removeListener(_onWifiChanged);
    super.dispose();
  }

  Future<void> _onWifiChanged() async {
    if (!mounted) return;
    await ref
        .read(fileProvider.notifier)
        .refreshVideosSilently(widget.folderCode);
    if (!mounted) return;
    _loadArticlesIfNeeded();
  }

  Future<void> _loadArticlesIfNeeded() async {
    final folder = ref.read(fileProvider).currentFolder;
    if (folder == null || folder.folderType != FolderContentType.article) {
      return;
    }

    setState(() => _articlesLoading = true);
    try {
      final articles = await BaseEntityExtension.findByCondition<Article>(
        () => Article(),
        where: 'folder_code = ? AND is_deleted = 0',
        whereArgs: [widget.folderCode],
        orderBy: 'order_index ASC, created_at DESC',
      );
      logger.debug(
        '_loadArticlesIfNeeded: found ${articles.length} articles for folder ${widget.folderCode}',
      );
      if (mounted) {
        setState(() {
          _articles = articles;
          _articlesLoading = false;
        });
      }
    } catch (e) {
      logger.error('_loadArticlesIfNeeded failed', error: e);
      if (mounted) setState(() => _articlesLoading = false);
    }
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
                    ? (folderType == FolderContentType.article
                          ? _buildContent(state, folderType)
                          : _buildEmptyState(colorScheme, folderType))
                    : _buildContent(state, folderType),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    String title,
    FolderContentType folderType,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Material(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20.r),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20.r),
                  onTap: () => Navigator.pop(context),
                  child: SizedBox(
                    width: 40.r,
                    height: 40.r,
                    child: Icon(
                      Icons.arrow_back,
                      size: 18.sp,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTypography.fontSizeLarge.sp,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
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
              Material(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20.r),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20.r),
                  onTap: _showSettings,
                  child: SizedBox(
                    width: 40.r,
                    height: 40.r,
                    child: Icon(
                      Icons.settings,
                      size: 18.sp,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

            PopupMenuButton<String>(
              enabled: !_isImporting,
              onSelected: _handleMenuAction,
              offset: const Offset(0, 44),
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
              child: Material(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(20.r),
                child: SizedBox(
                  width: 40.r,
                  height: 40.r,
                  child: Icon(
                    Icons.add,
                    size: 18.sp,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
              itemBuilder: (context) {
                final isPremium =
                    ref.watch(subscriptionProvider).mode ==
                    SubscriptionMode.premium;
                return [
                  PopupMenuItem(
                    value: 'import',
                    child: _popupMenuItem(
                      Icons.add_circle_outline,
                      '选择导入（可多选）',
                      colorScheme,
                    ),
                  ),
                  if (Platform.isIOS && folderType == FolderContentType.video)
                    PopupMenuItem(
                      value: 'importFolder',
                      child: _popupMenuItem(
                        Icons.folder_open,
                        '导入文件夹（全部）',
                        colorScheme,
                      ),
                    ),
                  PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'wifi',
                    child: _popupMenuItem(
                      Icons.wifi_rounded,
                      'WiFi 导入',
                      colorScheme,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: _popupMenuItem(
                      Icons.edit_outlined,
                      '重命名',
                      colorScheme,
                    ),
                  ),
                  if (isPremium)
                    PopupMenuItem(
                      value: 'test',
                      child: _popupMenuItem(
                        Icons.quiz_outlined,
                        '综合测试',
                        colorScheme,
                      ),
                    ),
                  if (isPremium && folderType == FolderContentType.video)
                    PopupMenuItem(
                      value: 'aiConversation',
                      child: _popupMenuItem(
                        Icons.forum_outlined,
                        'AI 对话',
                        colorScheme,
                      ),
                    ),
                  PopupMenuDivider(height: 1),
                  PopupMenuItem(
                    value: 'deleteAll',
                    child: _popupMenuItem(
                      Icons.delete_forever_rounded,
                      '全部删除',
                      colorScheme,
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    ColorScheme colorScheme,
    FolderContentType folderType,
  ) {
    final icon = folderType == FolderContentType.video
        ? Icons.videocam
        : folderType == FolderContentType.article
        ? Icons.article
        : Icons.headphones;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '暂无${_typeLabel(folderType)}',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '点击 + 导入资源',
            style: TextStyle(fontSize: 13.sp, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 56,
            color: colorScheme.error.withValues(alpha: 0.8),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '加载失败',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () =>
                  ref.read(fileProvider.notifier).loadVideos(widget.folderCode),
              child: const Text('重试'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(FileState state, FolderContentType folderType) {
    if (folderType == FolderContentType.article) {
      return _buildArticleList(state);
    }
    return _buildVideoList(state);
  }

  Widget _buildArticleList(FileState state) {
    if (_articlesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_articles.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return RefreshIndicator(
        onRefresh: _loadArticlesIfNeeded,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildEmptyState(colorScheme, FolderContentType.article),
            ),
          ],
        ),
      );
    }
    final crossAxisCount = 2;
    final gridSpacing = 12.0;

    // 选"主文章"：最后阅读的（按 lastStudyDate），没有则取第一篇
    final readArticles =
        _articles.where((a) => a.lastStudyDate != null).toList()
          ..sort((a, b) => b.lastStudyDate!.compareTo(a.lastStudyDate!));
    final heroArticle = readArticles.isNotEmpty
        ? readArticles.first
        : _articles.first;
    final gridArticles = _articles
        .where((a) => a.code != heroArticle.code)
        .toList();

    return RefreshIndicator(
      onRefresh: _loadArticlesIfNeeded,
      child: ListView(
        children: [
          ArticleHeroCard(
            article: heroArticle,
            onRead: () => _openArticle(heroArticle),
            onRename: () => _showArticleRenameDialog(heroArticle),
            onDelete: () => _confirmDeleteArticle(heroArticle),
          ),
          SizedBox(height: AppSpacing.md),
          GridView.builder(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: gridSpacing,
              mainAxisSpacing: gridSpacing,
              childAspectRatio: 4 / 3,
            ),
            itemCount: gridArticles.length,
            itemBuilder: (context, index) {
              final article = gridArticles[index];
              return ArticleItemCard(
                article: article,
                onTap: () => _openArticle(article),
                onRename: () => _showArticleRenameDialog(article),
                onDelete: () => _confirmDeleteArticle(article),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openArticle(Article article) {
    if (article.code == null || article.code!.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArticleReaderPage(articleCode: article.code!),
      ),
    );
  }

  Widget _buildVideoList(FileState state) {
    final crossAxisCount = 2;
    final gridSpacing = 12.0;
    final mainVideo =
        state.currentVideo ??
        (state.videos.isNotEmpty ? state.videos.first : null);
    final gridVideos = mainVideo == null
        ? state.videos
        : state.videos.where((v) => v.code != mainVideo.code).toList();

    return ListView(
      children: [
        if (mainVideo != null)
          MainVideoCard(
            video: mainVideo,
            onPlay: () => _playVideo(mainVideo),
            onRename: () => _showVideoRenameDialog(mainVideo),
            onImportSubtitle: () => _importSubtitleForVideo(mainVideo),
            onAiConversation:
                ref.read(subscriptionProvider).mode == SubscriptionMode.premium
                ? () => _openAiConversationForVideo(mainVideo)
                : null,
            onUnitTest:
                ref.read(subscriptionProvider).mode == SubscriptionMode.premium
                ? () => _showUnitTestForVideo(mainVideo)
                : null,
            onDelete: () => _confirmDeleteVideo(mainVideo),
          ),
        if (mainVideo != null) SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: gridSpacing,
            mainAxisSpacing: gridSpacing,
            childAspectRatio: 4 / 3,
          ),
          itemCount: gridVideos.length,
          itemBuilder: (context, index) {
            final video = gridVideos[index];
            return VideoCard(
              video: video,
              isCurrentPlaying: video.isCurrentPlaying,
              onTap: () => _playVideo(video),
              onRename: () => _showVideoRenameDialog(video),
              onImportSubtitle: () => _importSubtitleForVideo(video),
              onAiConversation:
                  ref.read(subscriptionProvider).mode ==
                      SubscriptionMode.premium
                  ? () => _openAiConversationForVideo(video)
                  : null,
              onUnitTest:
                  ref.read(subscriptionProvider).mode ==
                      SubscriptionMode.premium
                  ? () => _showUnitTestForVideo(video)
                  : null,
              onDelete: () => _confirmDeleteVideo(video),
            );
          },
        ),
        SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Future<void> _playVideo(dynamic video) async {
    final code = video.code;
    if (code == null || code.isEmpty) return;
    final state = ref.read(fileProvider);
    await ref.read(fileProvider.notifier).selectVideo(code);
    if (!mounted) return;
    final folder = state.currentFolder;
    final isMusic = folder?.folderType == FolderContentType.music;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isMusic
            ? AudioPlayerPage(
                videoCode: code,
                folderVideos: state.videos,
                audioType: 'music',
              )
            : PlayerPage(videoCode: code, folderVideos: state.videos),
      ),
    );
  }

  /// 显示 + 按钮的下拉菜单
  Widget _popupMenuItem(IconData icon, String title, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 20.sp, color: cs.onSurfaceVariant),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(color: cs.onSurface, fontSize: 14.sp),
        ),
      ],
    );
  }

  /// 确认全部删除
  Future<void> _confirmDeleteAll() async {
    final folder = ref.read(fileProvider).currentFolder;
    if (folder == null) return;
    final typeLabel = _typeLabel(folder.folderType);

    final confirmed = await AppConfirmDialog.show(
      context,
      title: '删除确认',
      content: '确定要删除当前$typeLabel文件夹及其所有资源吗？\n此操作不可恢复。',
      confirmText: '确认删除',
      cancelText: '取消',
      destructive: true,
    );

    if (confirmed == true && mounted) {
      final result = await ref
          .read(fileProvider.notifier)
          .deleteFolder(folder.code!);
      if (result == null && mounted) {
        // P1-2: 同步清理云端字幕
        unawaited(ConversationService.deleteCloudFolderSubtitles(folder.code!));
        Navigator.pop(context);
      } else if (result != null) {
        _showMessage('删除失败: $result');
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
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WifiTransferPage()),
          );
          if (!mounted) return;
          await ref.read(fileProvider.notifier).loadVideos(widget.folderCode);
          _loadArticlesIfNeeded();
        }();
        break;
      case 'rename':
        _showRenameDialog();
        break;
      case 'test':
        _showComprehensiveTest();
        break;
      case 'aiConversation':
        _openAiConversation();
        break;
      case 'deleteAll':
        _confirmDeleteAll();
        break;
    }
  }

  void _openAiConversation() {
    final state = ref.read(fileProvider);
    final current =
        state.currentVideo ??
        (state.videos.isNotEmpty ? state.videos.first : null);
    if (current == null || (current.code ?? '').isEmpty) {
      _showMessage('暂无可对话的视频', theme: MessageTheme.warning);
      return;
    }
    if (!current.hasSubtitles) {
      _showMessage('请先为该视频导入字幕', theme: MessageTheme.warning);
      return;
    }
    _openAiConversationForVideo(current);
  }

  void _openAiConversationForVideo(VideoInfo video) {
    if ((video.code ?? '').isEmpty) {
      _showMessage('暂无可对话的视频', theme: MessageTheme.warning);
      return;
    }
    Future.microtask(() async {
      final videoCode = video.code!;
      final subs = await DatabaseService.findByCondition(
        () => Subtitles(),
        where: 'video_code = ? AND is_deleted = 0',
        whereArgs: [videoCode],
        limit: 1,
      );
      if (subs.isEmpty) {
        _showMessage('字幕文件已绑定，但字幕内容未入库，请重新导入字幕', theme: MessageTheme.warning);
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationPage(
            sourceType: 'subtitle',
            sourceCode: videoCode,
            sourceTitle: video.name,
          ),
        ),
      );
    });
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
        await FilePickerService.importVideoWithSubtitle(
          vp,
          subtitleMap[name],
          widget.folderCode,
        );
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
  Future<FilePickerResult?> _pickFiles({
    required FileType type,
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    try {
      return await FilePicker.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
      );
    } catch (e) {
      return null;
    }
  }

  /// 导入视频文件（自动检测同目录下的同名字幕文件）
  Future<void> _importVideos() async {
    if (Platform.isIOS) {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: false,
        dialogTitle: '选择视频与字幕（同一文件夹可多选）',
      );
      if (result == null || result.files.isEmpty) return;

      final videos = <String>[];
      final subtitleMap = <String, String>{};
      for (final f in result.files) {
        if (f.path == null) continue;
        final p = FilePickerService.normalizePath(f.path!);
        final ext = FilePickerService.normalizePath(
          path.extension(p),
        ).toLowerCase();
        final base = _getFileNameWithoutExtension(path.basename(p));
        if (FilePickerService.supportedSubtitleExtensions.contains(ext)) {
          subtitleMap[base] = p;
        } else if (FilePickerService.supportedVideoExtensions.contains(ext)) {
          videos.add(p);
        }
      }

      for (final vp in videos) {
        final name = _getFileNameWithoutExtension(path.basename(vp));
        await FilePickerService.importVideoWithSubtitle(
          vp,
          subtitleMap[name],
          widget.folderCode,
        );
      }
      return;
    }

    final files = await FilePickerService.pickVideos();
    if (files.isEmpty) return;
    await FilePickerService.importVideos(files, widget.folderCode);
  }

  /// 导入文章文件
  Future<void> _importArticles() async {
    final result = await _pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'markdown'],
      allowMultiple: true,
    );
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

    final parsed = ArticleParser.parse(title: title, content: content);
    parsed.article.folderCode = folderCode;

    await DatabaseService.insert(parsed.article);
    final articleCode = parsed.article.code!;

    for (final s in parsed.sentences) {
      s.articleCode = articleCode;
    }
    for (final ch in parsed.chapters) {
      ch.articleCode = articleCode;
    }
    for (final p in parsed.paragraphs) {
      p.articleCode = articleCode;
    }

    if (parsed.sentences.isNotEmpty) {
      await DatabaseService.batchInsert(parsed.sentences);
    }
    if (parsed.chapters.isNotEmpty) {
      await DatabaseService.batchInsert(parsed.chapters);
    }
    if (parsed.paragraphs.isNotEmpty) {
      await DatabaseService.batchInsert(parsed.paragraphs);
    }

    // Upload to cloud for AI question generation
    try {
      await ConversationService.uploadArticleContentToCloud(articleCode, folderCode: folderCode);
    } catch (_) {}
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

    final audioExtensions = {
      '.mp3',
      '.wav',
      '.m4a',
      '.aac',
      '.flac',
      '.ogg',
      '.wma',
    };
    final isAudio = audioExtensions.contains(extension.toLowerCase());

    final destDir = Directory('${docs.path}/videos/$folderCode');
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }
    final destPath = '${destDir.path}/$videoCode$extension';
    await file.copy(destPath);

    int durationMs = 0;
    if (isAudio) {
      try {
        final metadata = await VideoMetadataExtractor.extract(destPath);
        durationMs = metadata.durationMs;
      } catch (_) {}
      if (durationMs == 0) {
        try {
          final controller = VideoPlayerController.file(File(destPath));
          await controller.initialize().timeout(const Duration(seconds: 5));
          durationMs = controller.value.duration.inMilliseconds;
          await controller.dispose();
        } catch (_) {}
      }
    } else {
      try {
        final controller = VideoPlayerController.file(File(destPath));
        await controller.initialize();
        durationMs = controller.value.duration.inMilliseconds;
        await controller.dispose();
      } catch (_) {}
    }

    String? coverPath;
    String? coverSource;
    if (isAudio) {
      try {
        final id3Tags = await Id3Parser.parse(destPath);
        if (id3Tags?.coverData != null) {
          final coverFile = 'covers/$folderCode/$coverCode.jpg';
          final fullCoverPath = await ThumbnailService.getFullPath(coverFile);
          final coverDir = Directory(fullCoverPath);
          if (!await coverDir.exists()) await coverDir.create(recursive: true);
          await File(fullCoverPath).writeAsBytes(id3Tags!.coverData!);
          coverPath = coverFile;
          coverSource = 'id3';
        }
      } catch (_) {}
      if (coverPath == null) {
        final generated = await InitialLetterCover.generate(
          fileName,
          folderCode,
        );
        if (generated != null) {
          coverPath = generated;
          coverSource = 'initial_letter';
        }
      }
    } else {
      try {
        final coverFile = 'covers/$folderCode/$coverCode.jpg';
        final fullCoverPath = await ThumbnailService.getFullPath(coverFile);
        final coverDir = Directory(fullCoverPath);
        if (!await coverDir.exists()) await coverDir.create(recursive: true);
        await VideoThumbnail.thumbnailFile(
          video: destPath,
          thumbnailPath: fullCoverPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 512,
          timeMs: 5000,
        );
        coverPath = coverFile;
        coverSource = 'thumbnail';
      } catch (_) {}
    }

    final subtitleBasePath = filePath.substring(0, filePath.lastIndexOf('.'));
    String? subtitlePath;
    final subtitleExts = isAudio
        ? ['.lrc', '.srt', '.ass', '.ssa', '.vtt']
        : ['.srt', '.ass', '.ssa', '.vtt'];
    for (final ext in subtitleExts) {
      final sp = '$subtitleBasePath$ext';
      if (await File(sp).exists()) {
        subtitlePath = sp;
        break;
      }
    }

    final video = VideoInfo(
      name: fileName,
      folderCode: folderCode,
      filePath: destPath,
      subtitlePath: subtitlePath,
      extensionName: extension.replaceAll('.', ''),
      duration: durationMs,
      cover: coverPath,
      coverSource: coverSource,
      hasSubtitles: subtitlePath != null && subtitlePath.isNotEmpty,
      fileType: 'virtual',
    );
    video.code = videoCode;
    await DatabaseService.insert(video);

    if (subtitlePath != null) {
      await _importSubtitles(subtitlePath, videoCode);
    }
  }

  /// 导入字幕文件
  Future<void> _importSubtitles(String subtitlePath, String videoCode) async {
    final subFile = File(subtitlePath);
    if (!await subFile.exists()) return;

    if (subtitlePath.toLowerCase().endsWith('.lrc')) {
      final content = await subFile.readAsString();
      final parsed = LrcParser.parseContent(content, videoCode);
      for (final s in parsed) {
        await DatabaseService.insert(s);
      }
      if (parsed.isNotEmpty) {
        final videos = await DatabaseService.findByCondition(
          () => VideoInfo(),
          where: 'code = ? AND is_deleted = 0',
          whereArgs: [videoCode],
          limit: 1,
        );
        if (videos.isNotEmpty) {
          videos.first.hasSubtitles = true;
          await DatabaseService.update(videos.first);
        }
      }
      await ConversationService.uploadSubtitlesToCloud(videoCode, folderCode: widget.folderCode);
      return;
    }

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
              Subtitles(
                videoCode: videoCode,
                startPosition: lastMs,
                endPosition: startMs,
                content: buf.toString().trim(),
                type: 'subtitle',
              )..code = const Uuid().v4().replaceAll('-', ''),
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
        Subtitles(
          videoCode: videoCode,
          startPosition: lastMs,
          endPosition: lastMs + 3000,
          content: buf.toString().trim(),
          type: 'subtitle',
        )..code = const Uuid().v4().replaceAll('-', ''),
      );
    }

    for (final s in subtitles) {
      await DatabaseService.insert(s);
    }

    await ConversationService.uploadSubtitlesToCloud(videoCode, folderCode: widget.folderCode);
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

  /// 重命名当前文件夹 — 使用 TDesign TDInputDialog
  Future<void> _showRenameDialog() async {
    final folder = ref.read(fileProvider).currentFolder;
    if (folder == null) return;

    final controller = TextEditingController(text: folder.name);
    showGeneralDialog(
      context: context,
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        return TDInputDialog(
          textEditingController: controller,
          title: '重命名',
          content: '请输入新的文件夹名称',
          hintText: folder.name,
          leftBtn: TDDialogButtonOptions(
            title: '取消',
            action: () => Navigator.pop(buildContext),
          ),
          rightBtn: TDDialogButtonOptions(
            title: '保存',
            action: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(buildContext);
              try {
                folder.name = name;
                await DatabaseService.update(folder);
                await ref
                    .read(fileProvider.notifier)
                    .loadVideos(widget.folderCode);
              } catch (e) {
                _showMessage('重命名失败: $e', theme: MessageTheme.error);
              }
            },
          ),
        );
      },
    );
  }

  /// 综合测试（针对当前资源集所有资源）
  /// 视频重命名 — 使用 TDesign TDInputDialog
  Future<void> _showVideoRenameDialog(dynamic video) async {
    final controller = TextEditingController(text: video.name ?? '');
    showGeneralDialog(
      context: context,
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        return TDInputDialog(
          textEditingController: controller,
          title: '重命名视频',
          content: '请输入新的视频名称',
          hintText: video.name ?? '',
          leftBtn: TDDialogButtonOptions(
            title: '取消',
            action: () => Navigator.pop(buildContext),
          ),
          rightBtn: TDDialogButtonOptions(
            title: '保存',
            action: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(buildContext);
              try {
                await ref
                    .read(fileProvider.notifier)
                    .renameVideo(video.code ?? '', name);
                _showMessage('重命名成功');
              } catch (e) {
                _showMessage('重命名失败: $e', theme: MessageTheme.error);
              }
            },
          ),
        );
      },
    );
  }

  /// 为视频导入字幕文件
  Future<void> _importSubtitleForVideo(dynamic video) async {
    final result = await _pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'ass', 'ssa', 'vtt'],
      allowMultiple: false,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }
    final subtitlePath = result.files.first.path!;
    try {
      await ref
          .read(fileProvider.notifier)
          .importSubtitleForVideo(video.code ?? '', subtitlePath);
      _showMessage('字幕导入成功');
    } catch (e) {
      _showMessage('导入字幕失败: $e', theme: MessageTheme.error);
    }
  }

  /// 确认删除视频
  Future<void> _confirmDeleteVideo(dynamic video) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: '删除确认',
      content: '确定要删除「${video.name ?? ''}」吗？\n此操作不可恢复。',
      confirmText: '确认删除',
      cancelText: '取消',
      destructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(fileProvider.notifier).deleteVideo(video.code ?? '');
        // P1-2: 同步清理云端字幕
        unawaited(ConversationService.deleteCloudSubtitles(video.code ?? ''));
        _showMessage('删除成功');
      } catch (e) {
        _showMessage('删除失败: $e');
      }
    }
  }

  Future<void> _showComprehensiveTest() async {
    final state = ref.read(fileProvider);
    final folder = state.currentFolder;
    final folderType = folder?.folderType ?? FolderContentType.video;

    // 文章集：检查文章列表
    if (folderType == FolderContentType.article) {
      if (_articles.isEmpty) {
        _showMessage('暂无可测试的文章', theme: MessageTheme.warning);
        return;
      }
      // 优先选择最后阅读的，否则第一篇
      final readArticles = _articles.where((a) => a.lastStudyDate != null).toList()
        ..sort((a, b) => b.lastStudyDate!.compareTo(a.lastStudyDate!));
      final target = readArticles.isNotEmpty ? readArticles.first : _articles.first;
      final articleCode = target.code ?? '';
      if (articleCode.isEmpty) {
        _showMessage('文章标识为空，无法测试', theme: MessageTheme.warning);
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TestPage(
            videoCode: articleCode,
            videoTitle: target.title,
            testScope: TestScope.folder,
            folderCode: widget.folderCode,
          ),
        ),
      );
      return;
    }

    // 视频/音频集：原有逻辑
    final videos = state.videos;
    if (videos.isEmpty) {
      _showMessage('暂无可测试的视频', theme: MessageTheme.warning);
      return;
    }

    // 检查当前文件夹下是否有任何视频包含字幕
    final hasAnySubtitle = videos.any((v) => v.hasSubtitles);
    if (!hasAnySubtitle) {
      _showMessage('当前文件夹下所有视频均没有字幕，无法进行综合测试', theme: MessageTheme.warning);
      return;
    }

    // 优先选择当前播放的视频，否则选第一个有字幕的视频
    final current = state.currentVideo;
    final target = (current != null && current.hasSubtitles)
        ? current
        : videos.firstWhere((v) => v.hasSubtitles);

    final videoCode = target.code ?? '';
    if (videoCode.isEmpty) {
      _showMessage('视频标识为空，无法测试', theme: MessageTheme.warning);
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestPage(
          videoCode: videoCode,
          videoTitle: target.name,
          testScope: TestScope.folder,
          folderCode: widget.folderCode,
        ),
      ),
    );
  }

  void _showSettings() {
    final folder = ref.read(fileProvider).currentFolder;
    if (folder == null) return;

    PlaybackSettingsSheet.show(
      context,
      initial: PlaybackSettings.fromFolder(folder),
      onSave: (settings) async {
        await ref
            .read(fileProvider.notifier)
            .updateFolderPlaybackSettings(folder.code!, settings);
      },
    );
  }

  /// 单个视频的单元测试
  void _showUnitTestForVideo(dynamic video) {
    if (!video.hasSubtitles) {
      _showMessage('该视频没有字幕，无法进行单元测试', theme: MessageTheme.warning);
      return;
    }
    final videoCode = video.code ?? '';
    if (videoCode.isEmpty) {
      _showMessage('视频标识为空，无法测试', theme: MessageTheme.warning);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TestPage(videoCode: videoCode, videoTitle: video.name ?? 'Video'),
      ),
    );
  }

  void _showMessage(String content, {MessageTheme theme = MessageTheme.info}) {
    final type = switch (theme) {
      MessageTheme.error => ToastType.error,
      MessageTheme.warning => ToastType.warning,
      MessageTheme.success => ToastType.success,
      MessageTheme.info => ToastType.info,
    };
    AppToast.show(context, content, type: type);
  }

  /// 文章重命名 — 使用 TDesign TDInputDialog
  Future<void> _showArticleRenameDialog(Article article) async {
    final controller = TextEditingController(text: article.title);
    showGeneralDialog(
      context: context,
      pageBuilder: (buildContext, animation, secondaryAnimation) {
        return TDInputDialog(
          textEditingController: controller,
          title: '重命名文章',
          content: '请输入新的文章名称',
          hintText: article.title,
          leftBtn: TDDialogButtonOptions(
            title: '取消',
            action: () => Navigator.pop(buildContext),
          ),
          rightBtn: TDDialogButtonOptions(
            title: '确定',
            action: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(buildContext);
              try {
                article.title = name;
                await DatabaseService.update(article);
                if (mounted) setState(() {});
              } catch (_) {}
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteArticle(Article article) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: '删除确认',
      content: '确定要删除文章「${article.title}」吗？',
      confirmText: '删除',
      cancelText: '取消',
      destructive: true,
    );
    if (confirmed == true && mounted) {
      article.isDeleted = true;
      await DatabaseService.update(article);
      // P1-2: 同步清理云端文章内容
      unawaited(ConversationService.deleteCloudSubtitles(article.code!));
      setState(() => _articles.removeWhere((a) => a.code == article.code));
    }
  }
}
