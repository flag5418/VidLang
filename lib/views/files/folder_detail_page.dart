/// 文件夹详情页面
///
/// 展示文件夹内的资源列表，适配视频/文章/音频3类资源。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/components/main_video_card.dart';
import 'package:vidlang/components/playback_settings_sheet.dart';
import 'package:vidlang/components/video_card.dart';
import 'package:vidlang/models/playback_settings.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/providers/file_provider.dart';
import 'package:vidlang/services/file_picker_service.dart';
import 'package:vidlang/theme/theme.dart';
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
          children: [
            GestureDetector(
              onTap: _showUnitTest,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Colors.green.withValues(alpha: 0.15)),
                child: Icon(Icons.quiz, color: Colors.green, size: 18),
              ),
            ),
            SizedBox(width: AppSpacing.space2),
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
            SizedBox(width: AppSpacing.space2),
            GestureDetector(
              onTap: _isImporting ? null : _importResources,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: colorScheme.primary),
                child: Icon(Icons.add, size: 18, color: colorScheme.onPrimary),
              ),
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
            child: MainVideoCard(video: mainVideo, onPlay: () => _playVideo(mainVideo), onMoreTap: () {}),
          ),
        if (mainVideo != null) SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            final video = gridVideos[index];
            return VideoCard(video: video, isCurrentPlaying: video.isCurrentPlaying, onTap: () => _playVideo(video), onMoreTap: () {});
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

  Future<void> _importResources() async {
    final folder = ref.read(fileProvider).currentFolder;
    if (folder == null) return;

    setState(() => _isImporting = true);
    try {
      // 使用现有 FilePickerService 的导入方法
      // Use existing import flow
      final files = await FilePickerService.pickVideos();
      if (files.isNotEmpty) {
        await FilePickerService.importVideos(files, widget.folderCode);
      }
      await ref.read(fileProvider.notifier).loadVideos(widget.folderCode);
      _showMessage('Import complete');
    } catch (e) {
      _showMessage('Import failed: $e', theme: MessageTheme.error);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
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

  void _showUnitTest() {
    _showMessage('Unit test coming soon', theme: MessageTheme.info);
  }

  void _showMessage(String content, {MessageTheme theme = MessageTheme.info}) {
    TDMessage.showMessage(context: context, content: content, visible: true, icon: true, theme: theme, duration: 3000);
  }
}
