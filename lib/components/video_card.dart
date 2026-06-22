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
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_radius.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/theme/app_typography.dart';

class VideoCard extends StatefulWidget {
  final VideoInfo video;
  final bool isCurrentPlaying;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onImportSubtitle;
  final VoidCallback? onAiConversation;
  final VoidCallback? onUnitTest;
  final VoidCallback? onDelete;

  const VideoCard({
    super.key,
    required this.video,
    required this.isCurrentPlaying,
    required this.onTap,
    this.onRename,
    this.onImportSubtitle,
    this.onAiConversation,
    this.onUnitTest,
    this.onDelete,
  });

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      onPanDown: (_) => setState(() => _isPressed = true),
      onPanEnd: (_) => setState(() => _isPressed = false),
      onPanCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0, 1.0, 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: AppColors.cardThumbnailBg,
          border: widget.isCurrentPlaying ? Border.all(color: colorScheme.primary, width: 2.5) : null,
          boxShadow: [BoxShadow(color: Color(0x20000000), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.isCurrentPlaying ? AppRadius.md - 2.5 : AppRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(context, colorScheme),
              _buildBottomOverlay(context, colorScheme),
              _buildSubtitleBadge(context, colorScheme),
              if (widget.video.lastFollowScore != null) _buildScoreBadge(context),
              _buildMoreButton(context, colorScheme),
              if (widget.isCurrentPlaying) _buildPlayingBadge(context, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, ColorScheme colorScheme) {
    final cover = (widget.video.currentCover != null && widget.video.currentCover!.isNotEmpty) ? widget.video.currentCover : widget.video.cover;

    if (cover != null && cover.isNotEmpty) {
      return FutureBuilder<String>(
        future: ThumbnailService.getFullPath(cover),
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (path != null && File(path).existsSync()) {
            return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder(context, colorScheme));
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
        child: Icon(Icons.movie_outlined, size: 22.sp, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildBottomOverlay(BuildContext context, ColorScheme colorScheme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(AppSpacing.space3, 20.h, AppSpacing.space3, AppSpacing.space3),
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
              widget.video.name,
              style: TextStyle(fontSize: AppTypography.fontSizeBase.sp, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 10.sp, color: Colors.white70),
                SizedBox(width: 4.w),
                Text(
                  '${widget.video.currentPositionString} / ${widget.video.durationString}',
                  style: TextStyle(fontSize: AppTypography.fontSizeXSmall.sp, color: Colors.white70, fontWeight: FontWeight.w500),
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
      top: AppSpacing.space2.h,
      left: AppSpacing.space2.w,
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xs.r),
          color: widget.video.hasSubtitles ? colorScheme.primary : Colors.black.withValues(alpha: 0.5),
        ),
        child: Icon(Icons.subtitles, size: 12.sp, color: widget.video.hasSubtitles ? Colors.white : Colors.white38),
      ),
    );
  }

  Widget _buildScoreBadge(BuildContext context) {
    final score = widget.video.lastFollowScore!;
    final color = _scoreColor(score);
    return Positioned(
      top: AppSpacing.space2.h,
      left: 28.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xs.r),
          color: color.withValues(alpha: 0.85),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 9.sp, color: Colors.white),
            SizedBox(width: 2.w),
            Text(
              '${score.round()}',
              style: TextStyle(fontSize: AppTypography.fontSizeXSmall.sp, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.orange;
    if (score >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  Widget _buildMoreButton(BuildContext context, ColorScheme colorScheme) {
    return Positioned(
      bottom: AppSpacing.space2,
      right: AppSpacing.space2,
      child: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'rename':
              widget.onRename?.call();
              break;
            case 'importSubtitle':
              widget.onImportSubtitle?.call();
              break;
            case 'aiConversation':
              widget.onAiConversation?.call();
              break;
            case 'unitTest':
              widget.onUnitTest?.call();
              break;
            case 'delete':
              widget.onDelete?.call();
              break;
          }
        },
        offset: const Offset(-120, 0),
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        elevation: 6,
        child: Container(
          width: 26.r,
          height: 26.r,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.sm.r), color: Colors.black.withValues(alpha: 0.65)),
          child: Icon(Icons.more_vert, size: 16.sp, color: Colors.white),
        ),
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[PopupMenuItem(value: 'rename', child: _menuRow(context, Icons.edit_outlined, '重命名', colorScheme))];
          if (!widget.video.hasSubtitles && widget.onImportSubtitle != null) {
            items.add(PopupMenuItem(value: 'importSubtitle', child: _menuRow(context, Icons.closed_caption, '导入字幕', colorScheme)));
          }
          if (widget.video.hasSubtitles && widget.onAiConversation != null) {
            items.add(PopupMenuItem(value: 'aiConversation', child: _menuRow(context, Icons.forum_outlined, 'AI 对话', colorScheme)));
          }
          if (widget.onUnitTest != null) {
            items.add(PopupMenuItem(value: 'unitTest', child: _menuRow(context, Icons.quiz_outlined, '单元测试', colorScheme)));
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
        Icon(icon, size: 18.sp, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.space2),
        Text(
          title,
          style: TextStyle(color: cs.onSurface, fontSize: AppTypography.fontSizeBase.sp),
        ),
      ],
    );
  }

  Widget _buildPlayingBadge(BuildContext context, ColorScheme colorScheme) {
    return Positioned(
      bottom: AppSpacing.space2,
      left: AppSpacing.space2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.sm), color: colorScheme.primary),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, size: 10.sp, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              '播放中',
              style: TextStyle(fontSize: AppTypography.fontSizeXSmall.sp, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
