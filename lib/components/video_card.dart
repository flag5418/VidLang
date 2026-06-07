/// 视频卡片组件
///
/// 全铺封面设计（与 FolderCard 统一）：
/// - 缩略图填充整个卡片
/// - 底部渐变遮罩叠加名称 + 时长
/// - 左上角字幕标签（始终显示，区分状态）
/// - 右上角更多按钮
/// - 当前播放视频有橙色边框 + 角标
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/responsive_size.dart';

class VideoCard extends StatelessWidget {
  final VideoInfo video;
  final bool isCurrentPlaying;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onImportSubtitle;
  final VoidCallback? onDelete;

  const VideoCard({
    super.key,
    required this.video,
    required this.isCurrentPlaying,
    required this.onTap,
    this.onRename,
    this.onImportSubtitle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.cardThumbnailBg,
          border: isCurrentPlaying ? Border.all(color: colorScheme.primary, width: 2.5) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isCurrentPlaying ? 7.5 : 10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(context, colorScheme),
              _buildBottomOverlay(context, colorScheme),
              _buildSubtitleBadge(context, colorScheme),
              _buildMoreButton(context, colorScheme),
              if (isCurrentPlaying) _buildPlayingBadge(context, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, ColorScheme colorScheme) {
    final cover = (video.currentCover != null && video.currentCover!.isNotEmpty) ? video.currentCover : video.cover;

    if (cover != null && cover.isNotEmpty) {
      return FutureBuilder<String>(
        future: ThumbnailService.getFullPath(cover),
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (path != null && File(path).existsSync()) {
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(context, colorScheme),
            );
          }
          return _placeholder(context, colorScheme);
        },
      );
    }
    return _placeholder(context, colorScheme);
  }

  Widget _placeholder(BuildContext context, ColorScheme colorScheme) {
    return Container(
      color: AppColors.cardThumbnailBg,
      child: Center(
        child: Icon(Icons.movie_outlined, size: ResponsiveSize.icon(context), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildBottomOverlay(BuildContext context, ColorScheme colorScheme) {
    final isTablet = ResponsiveSize.isTablet(context);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 24, 10, isTablet ? 12 : 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              video.name,
              style: TextStyle(
                fontSize: ResponsiveSize.fontSize(context, 12),
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isTablet ? 4 : 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: ResponsiveSize.fontSize(context, 10), color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  '${video.currentPositionString} / ${video.durationString}',
                  style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 10), color: Colors.white70, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleBadge(BuildContext context, ColorScheme colorScheme) {
    return Positioned(
      top: 6,
      left: 6,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: video.hasSubtitles ? colorScheme.primary : Colors.black.withValues(alpha: 0.5),
        ),
        child: Icon(
          Icons.subtitles,
          size: ResponsiveSize.fontSize(context, 12),
          color: video.hasSubtitles ? Colors.white : Colors.white38,
        ),
      ),
    );
  }

  Widget _buildMoreButton(BuildContext context, ColorScheme colorScheme) {
    return Positioned(
      top: 6,
      right: 6,
      child: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'rename':
              onRename?.call();
              break;
            case 'importSubtitle':
              onImportSubtitle?.call();
              break;
            case 'delete':
              onDelete?.call();
              break;
          }
        },
        offset: const Offset(-120, 0),
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.black.withValues(alpha: 0.6),
          ),
          child: Text(
            '···',
            style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 14), fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
          ),
        ),
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[
            PopupMenuItem(value: 'rename', child: _menuRow(context, Icons.edit_outlined, '重命名', colorScheme)),
          ];
          if (!video.hasSubtitles && onImportSubtitle != null) {
            items.add(PopupMenuItem(value: 'importSubtitle', child: _menuRow(context, Icons.closed_caption, '导入字幕', colorScheme)));
          }
          items.addAll([
            const PopupMenuDivider(height: 1),
            PopupMenuItem(value: 'delete', child: _menuRow(context, Icons.delete_outline, '删除', colorScheme)),
          ]);
          return items;
        },
      ),
    );
  }

  Widget _menuRow(BuildContext context, IconData icon, String title, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: ResponsiveSize.fontSize(context, 18), color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: cs.onSurface, fontSize: ResponsiveSize.fontSize(context, 14))),
      ],
    );
  }

  Widget _buildPlayingBadge(BuildContext context, ColorScheme colorScheme) {
    return Positioned(
      bottom: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: colorScheme.primary,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, size: ResponsiveSize.fontSize(context, 10), color: Colors.white),
            const SizedBox(width: 3),
            Text('播放中', style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 9), fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
