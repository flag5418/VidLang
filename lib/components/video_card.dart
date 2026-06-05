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

class VideoCard extends StatelessWidget {
  final VideoInfo video;
  final bool isCurrentPlaying;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const VideoCard({
    super.key,
    required this.video,
    required this.isCurrentPlaying,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

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
              _buildBottomOverlay(colorScheme, isTablet),
              _buildSubtitleBadge(colorScheme),
              _buildMoreButton(colorScheme),
              if (isCurrentPlaying) _buildPlayingBadge(colorScheme),
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
              errorBuilder: (_, _, _) => _placeholder(colorScheme),
            );
          }
          return _placeholder(colorScheme);
        },
      );
    }
    return _placeholder(colorScheme);
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return Container(
      color: AppColors.cardThumbnailBg,
      child: Center(
        child: Icon(Icons.movie_outlined, size: 28, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildBottomOverlay(ColorScheme colorScheme, bool isTablet) {
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
                fontSize: isTablet ? 14.0 : 12.0,
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
                Icon(Icons.schedule, size: isTablet ? 12.0 : 10.0, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  '${video.currentPositionString} / ${video.durationString}',
                  style: TextStyle(fontSize: isTablet ? 12.0 : 10.0, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleBadge(ColorScheme colorScheme) {
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
          size: 12,
          color: video.hasSubtitles ? Colors.white : Colors.white38,
        ),
      ),
    );
  }

  Widget _buildMoreButton(ColorScheme colorScheme) {
    return Positioned(
      top: 6,
      right: 6,
      child: GestureDetector(
        onTap: onMoreTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.black.withValues(alpha: 0.6),
          ),
          child: Text(
            '···',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayingBadge(ColorScheme colorScheme) {
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
            Icon(Icons.play_arrow, size: 10, color: Colors.white),
            const SizedBox(width: 3),
            Text('播放中', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
