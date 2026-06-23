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
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_radius.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/theme/app_typography.dart';

class MainVideoCard extends StatefulWidget {
  final VideoInfo video;
  final VoidCallback? onPlay;
  final VoidCallback? onRename;
  final VoidCallback? onImportSubtitle;
  final VoidCallback? onAiConversation;
  final VoidCallback? onUnitTest;
  final VoidCallback? onDelete;

  const MainVideoCard({
    super.key,
    required this.video,
    this.onPlay,
    this.onRename,
    this.onImportSubtitle,
    this.onAiConversation,
    this.onUnitTest,
    this.onDelete,
  });

  @override
  State<MainVideoCard> createState() => _MainVideoCardState();
}

class _MainVideoCardState extends State<MainVideoCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = (screenWidth - AppSpacing.space8) * 9 / 16;
    final clampedHeight = cardHeight.clamp(200.0, 400.0);

    final cover = (widget.video.currentCover != null && widget.video.currentCover!.isNotEmpty) ? widget.video.currentCover : widget.video.cover;

    return GestureDetector(
      onTap: widget.onPlay,
      onPanDown: (_) => setState(() => _isPressed = true),
      onPanEnd: (_) => setState(() => _isPressed = false),
      onPanCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0, 1.0, 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [const BoxShadow(color: Color(0x20000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: _buildCard(clampedHeight, cover, colorScheme),
      ),
    );
  }

  Widget _buildCard(double height, String? cover, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), color: AppColors.cardThumbnailBg),
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
                  return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder(context, colorScheme));
                }
                return _placeholder(context, colorScheme);
              },
            )
          else
            _placeholder(context, colorScheme),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
              ),
            ),
          ),
          _buildSubtitleBadge(context, colorScheme),
          _buildBottomSection(context, colorScheme),
          _buildMenu(context, colorScheme),
          _buildPlayButton(context, colorScheme),
        ],
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

  Widget _placeholder(BuildContext context, ColorScheme colorScheme) {
    return Container(
      color: AppColors.cardThumbnailBg,
      child: Center(
        child: Icon(Icons.movie_outlined, size: 24.sp, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildSubtitleBadge(BuildContext context, ColorScheme colorScheme) {
    return Positioned(
      top: AppSpacing.space2,
      left: AppSpacing.space2,
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          color: widget.video.hasSubtitles ? colorScheme.primary : Colors.black.withValues(alpha: 0.5),
        ),
        child: Icon(Icons.subtitles, size: 14.sp, color: widget.video.hasSubtitles ? Colors.white : Colors.white38),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, ColorScheme colorScheme) {
    return Positioned(
      bottom: AppSpacing.space4,
      right: AppSpacing.space3,
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
        offset: const Offset(-100, 0),
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        elevation: 6,
        child: Container(
          width: 28.r,
          height: 28.r,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.sm.r), color: Colors.black.withValues(alpha: 0.65)),
          child: Icon(Icons.more_vert, size: 18.sp, color: Colors.white),
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

  Widget _buildBottomSection(BuildContext context, ColorScheme colorScheme) {
    final progress = widget.video.duration > 0 ? widget.video.currentPosition / widget.video.duration : 0.0;
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
            padding: EdgeInsets.fromLTRB(AppSpacing.space4, AppSpacing.space3, AppSpacing.space4, AppSpacing.space4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.85)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.video.name,
                  style: TextStyle(fontSize: AppTypography.fontSizeBase.sp, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Row(
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
        ],
      ),
    );
  }

  Widget _buildPlayButton(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Container(
        width: 36.w,
        height: 36.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(Icons.play_arrow_rounded, size: 20.w, color: AppColors.primary),
      ),
    );
  }
}
