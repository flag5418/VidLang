/// 主视频卡片组件
///
/// 在视频集详情页顶部展示当前视频，模仿视频播放器封面风格：
/// - 使用 16:9 比例，响应式高度
/// - 图片铺满，底部渐变遮罩
/// - 整张卡片可点击播放（不限于播放按钮）
/// - 底部保留单个视频的播放进度条
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/theme/theme.dart';

class MainVideoCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback? onPlay;
  final VoidCallback onMoreTap;

  const MainVideoCard({super.key, required this.video, this.onPlay, required this.onMoreTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = (screenWidth - 32) * 9 / 16;
    final clampedHeight = cardHeight.clamp(220.0, 420.0);

    final cover = (video.currentCover != null && video.currentCover!.isNotEmpty) ? video.currentCover : video.cover;

    return GestureDetector(
      onTap: onPlay,
      child: Container(
        width: double.infinity,
        height: clampedHeight,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AppColors.cardThumbnailBg),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null && cover.isNotEmpty)
              FutureBuilder<String>(
                future: ThumbnailService.getFullPath(cover),
                builder: (context, snapshot) {
                  final path = snapshot.data;
                  if (path != null && File(path).existsSync()) {
                    return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder(colorScheme));
                  }
                  return _placeholder(colorScheme);
                },
              )
            else
              _placeholder(colorScheme),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                ),
              ),
            ),
            _buildTopContent(colorScheme),
            _buildBottomSection(colorScheme),
            _buildPlayButton(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return Container(
      color: AppColors.cardThumbnailBg,
      child: Center(child: Icon(Icons.movie_outlined, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3))),
    );
  }

  Widget _buildTopContent(ColorScheme colorScheme) {
    return Positioned(
      top: 12,
      right: 12,
      child: GestureDetector(
        onTap: () => onMoreTap(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.black.withValues(alpha: 0.6)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (video.hasSubtitles) ...[Icon(Icons.subtitles, size: 14, color: colorScheme.primary), const SizedBox(width: 6)],
              Text(
                '${video.currentPositionString} / ${video.durationString}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection(ColorScheme colorScheme) {
    final progress = video.duration > 0 ? video.currentPosition / video.duration : 0.0;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 3,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.85)],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    video.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(ColorScheme colorScheme) {
    return Center(
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(Icons.play_arrow_rounded, size: 34, color: AppColors.primary),
      ),
    );
  }
}
