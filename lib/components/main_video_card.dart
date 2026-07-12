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
import 'package:vidlang/utils/adaptive.dart';

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
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final isPad = Adaptive.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = (screenWidth - (Adaptive.w(context, 16))) * 9 / 16;
    final clampedHeight = cardHeight.clamp(200.0, 400.0);

    final cover =
        (widget.video.currentCover != null &&
            widget.video.currentCover!.isNotEmpty)
        ? widget.video.currentCover
        : widget.video.cover;

    return GestureDetector(
      onTap: widget.onPlay,
      child: Container(
        width: double.infinity,
        height: clampedHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            Adaptive.r(context, AppRadius.outlinedCard),
          ),
        ),
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
                    return Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(context, colors),
                    );
                  }
                  return _placeholder(context, colors);
                },
              )
            else
              _placeholder(context, colors),
            // 单层渐变遮罩
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
            ),
            _buildSubtitleBadge(context, colors),
            _buildBottomSection(context, colors, textStyles, isPad),
            _buildMenu(context, colors, isPad),
            _buildPlayButton(context, colors, isPad),
          ],
        ),
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

  Widget _placeholder(BuildContext context, AppColorsData colors) {
    final isPad = Adaptive.of(context);
    return Container(
      color: AppColors.cardThumbnailBg,
      child: Center(
        child: Icon(
          AppIcons.movie,
          size: Adaptive.sp(context, 24),
          color: colors.textWeak,
        ),
      ),
    );
  }

  Widget _buildSubtitleBadge(BuildContext context, AppColorsData colors) {
    final isPad = Adaptive.of(context);
    return Positioned(
      top: Adaptive.w(context, 8),
      left: Adaptive.w(context, 8),
      child: Container(
        padding: EdgeInsets.all(Adaptive.w(context, 4)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.small),
          color: widget.video.hasSubtitles
              ? colors.primary
              : Colors.black.withValues(alpha: 0.5),
        ),
        child: Icon(
          AppIcons.subtitles,
          size: Adaptive.sp(context, 14),
          color: widget.video.hasSubtitles ? Colors.white : Colors.white38,
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, AppColorsData colors, bool isPad) {
    return Positioned(
      bottom: Adaptive.h(context, 8),
      right: Adaptive.w(context, 12),
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
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.outlinedCard),
        ),
        elevation: 6,
        child: Container(
          width: Adaptive.r(context, 28),
          height: Adaptive.r(context, 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.small),
            color: Colors.black.withValues(alpha: 0.65),
          ),
          child: Icon(
            AppIcons.moreVert,
            size: Adaptive.sp(context, 18),
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

  Widget _buildBottomSection(
    BuildContext context,
    AppColorsData colors,
    AppTextStylesData textStyles,
    bool isPad,
  ) {
    final progress = widget.video.duration > 0
        ? widget.video.currentPosition / widget.video.duration
        : 0.0;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // 进度条：4pt 高，20pt 拖动热区
          SizedBox(
            height: 20,
            child: Center(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    minHeight: 4,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              Adaptive.w(context, 16),
              Adaptive.w(context, 12),
              Adaptive.w(context, 16),
              Adaptive.w(context, 16),
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
                SizedBox(height: Adaptive.h(context, 2)),
                Row(
                  children: [
                    const Icon(
                      AppIcons.schedule,
                      size: 10,
                      color: Colors.white70,
                    ),
                    SizedBox(width: Adaptive.w(context, 4)),
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
        ],
      ),
    );
  }

  Widget _buildPlayButton(
    BuildContext context,
    AppColorsData colors,
    bool isPad,
  ) {
    final size = Adaptive.w(context, 44);
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        child: Icon(
          AppIcons.play,
          size: Adaptive.sp(context, 24),
          color: colors.primary,
        ),
      ),
    );
  }
}
