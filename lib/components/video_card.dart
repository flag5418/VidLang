/// 视频卡片组件
///
/// 全铺封面设计（与 FolderCard 统一）：
/// - 缩略图填充整个卡片
/// - 底部渐变遮罩叠加名称 + 时长
/// - 左上角字幕标签（始终显示，区分状态）
/// - 右上角更多按钮
/// - 当前播放视频底部品牌绿色指示线
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/thumbnail_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

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
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.outlinedCard),
          color: AppColors.cardThumbnailBg,
          border: widget.isCurrentPlaying
              ? null
              : Border.all(color: colors.border, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            widget.isCurrentPlaying
                ? AppRadius.outlinedCard
                : AppRadius.outlinedCard,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(context, colors),
              _buildBottomOverlay(context, colors, textStyles),
              _buildSubtitleBadge(context, colors),
              if (widget.video.lastFollowScore != null)
                _buildScoreBadge(context, colors, textStyles),
              _buildMoreButton(context, colors),
              if (widget.isCurrentPlaying)
                _buildPlayingBadge(context, colors, textStyles),
              if (widget.isCurrentPlaying)
                _buildCurrentIndicator(context, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, AppColorsData colors) {
    final cover =
        (widget.video.currentCover != null &&
            widget.video.currentCover!.isNotEmpty)
        ? widget.video.currentCover
        : widget.video.cover;

    if (cover != null && cover.isNotEmpty) {
      return FutureBuilder<String>(
        future: ThumbnailService.getFullPath(cover),
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (path != null && File(path).existsSync()) {
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(context, colors),
            );
          }
          return _placeholder(context, colors);
        },
      );
    }
    return _placeholder(context, colors);
  }

  Widget _placeholder(BuildContext context, AppColorsData colors) {
    return Container(
      color: AppColors.cardThumbnailBg,
      child: Center(
        child: Icon(
          AppIcons.movie,
          size: Adaptive.sp(context, 22),
          color: colors.textWeak,
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(
    BuildContext context,
    AppColorsData colors,
    AppTextStylesData textStyles,
  ) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, 20, 8, 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black54], // alpha 0.6 → 0x99
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.video.name,
              style: TextStyle(
                fontSize: textStyles.body.fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.schedule, size: 10, color: Colors.white70),
                const SizedBox(width: 4),
                Text(
                  '${widget.video.currentPositionString} / ${widget.video.durationString}',
                  style: TextStyle(
                    fontSize: textStyles.caption.fontSize,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleBadge(BuildContext context, AppColorsData colors) {
    return Positioned(
      top: Adaptive.h(context, 4),
      left: Adaptive.w(context, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.small),
          color: widget.video.hasSubtitles
              ? colors.primary
              : Colors.black.withValues(alpha: 0.5),
        ),
        child: Icon(
          AppIcons.subtitles,
          size: Adaptive.sp(context, 12),
          color: widget.video.hasSubtitles ? Colors.white : Colors.white38,
        ),
      ),
    );
  }

  Widget _buildScoreBadge(
    BuildContext context,
    AppColorsData colors,
    AppTextStylesData textStyles,
  ) {
    final score = widget.video.lastFollowScore!;
    final color = _scoreColor(score);
    return Positioned(
      top: Adaptive.h(context, 4),
      left: Adaptive.w(context, 28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.small),
          color: color.withValues(alpha: 0.85),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.mic, size: 9, color: Colors.white),
            const SizedBox(width: 2),
            Text(
              '${score.round()}',
              style: TextStyle(
                fontSize: textStyles.caption.fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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

  Widget _buildMoreButton(BuildContext context, AppColorsData colors) {
    final isPad = Adaptive.of(context);
    return Positioned(
      bottom: 4,
      right: 4,
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
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.outlinedCard),
        ),
        elevation: 6,
        child: Container(
          width: Adaptive.r(context, 26),
          height: Adaptive.r(context, 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.small),
            color: Colors.black.withValues(alpha: 0.65),
          ),
          child: Icon(
            AppIcons.moreVert,
            size: Adaptive.sp(context, 16),
            color: Colors.white,
          ),
        ),
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[
            PopupMenuItem(
              value: 'rename',
              child: _menuRow(context, AppIcons.edit, '重命名', colors),
            ),
          ];
          if (!widget.video.hasSubtitles && widget.onImportSubtitle != null) {
            items.add(
              PopupMenuItem(
                value: 'importSubtitle',
                child: _menuRow(
                  context,
                  AppIcons.closedCaption,
                  '导入字幕',
                  colors,
                ),
              ),
            );
          }
          if (widget.video.hasSubtitles && widget.onAiConversation != null) {
            items.add(
              PopupMenuItem(
                value: 'aiConversation',
                child: _menuRow(context, AppIcons.forum, 'AI 对话', colors),
              ),
            );
          }
          if (widget.onUnitTest != null) {
            items.add(
              PopupMenuItem(
                value: 'unitTest',
                child: _menuRow(context, AppIcons.quiz, '单元测试', colors),
              ),
            );
          }
          items.addAll([
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'delete',
              child: _menuRow(context, AppIcons.delete, '删除', colors),
            ),
          ]);
          return items;
        },
      ),
    );
  }

  Widget _menuRow(
    BuildContext context,
    IconData icon,
    String title,
    AppColorsData colors,
  ) {
    final isPad = Adaptive.of(context);
    return Row(
      children: [
        Icon(icon, size: Adaptive.sp(context, 18), color: colors.textSecondary),
        const SizedBox(width: AppSpacing.space2),
        Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: Adaptive.sp(context, 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayingBadge(
    BuildContext context,
    AppColorsData colors,
    AppTextStylesData textStyles,
  ) {
    final isPad = Adaptive.of(context);
    return Positioned(
      bottom: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.small),
          color: colors.primary,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.play,
              size: Adaptive.sp(context, 10),
              color: Colors.white,
            ),
            const SizedBox(width: 3),
            Text(
              '播放中',
              style: TextStyle(
                fontSize: textStyles.caption.fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 当前播放态底部品牌绿色指示线（3pt 高，宽度约 40%）
  Widget _buildCurrentIndicator(BuildContext context, AppColorsData colors) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: 0.4,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(1.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
