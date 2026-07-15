/// 音频主卡片组件（对标 ArticleHeroCard）
///
/// 在音频集详情页顶部展示当前/第一个音频：
/// - 使用 16:9 比例，响应式高度
/// - 紫色系渐变背景，大字母居中
/// - 底部渐变遮罩叠加标题 + 时长
/// - 整张卡片可点击播放
/// - 底部播放进度条
/// - 右下竖三点菜单
library;

import 'package:flutter/material.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

class AudioHeroCard extends StatefulWidget {
  final VideoInfo video;
  final VoidCallback? onPlay;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const AudioHeroCard({
    super.key,
    required this.video,
    this.onPlay,
    this.onRename,
    this.onDelete,
  });

  @override
  State<AudioHeroCard> createState() => _AudioHeroCardState();
}

class _AudioHeroCardState extends State<AudioHeroCard> {
  bool _isPressed = false;

  static const _palette = [
    Color(0xFF7C3AED),
    Color(0xFFA855F7),
    Color(0xFF8B5CF6),
    Color(0xFF9333EA),
    Color(0xFF6D28D9),
    Color(0xFFC084FC),
    Color(0xFF7E22CE),
    Color(0xFF581C87),
    Color(0xFF3B0764),
    Color(0xFF4C1D95),
  ];

  Color _cardColor() {
    final hash = widget.video.name.hashCode;
    return _palette[hash.abs() % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = (screenWidth - AppSpacing.space8) * 9 / 16;
    final clampedHeight = cardHeight.clamp(200.0, 400.0);
    final cardColor = _cardColor();
    final hasActions = widget.onRename != null || widget.onDelete != null;
    final letter = widget.video.name.isNotEmpty
        ? widget.video.name[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: widget.onPlay,
      onPanDown: (_) => setState(() => _isPressed = true),
      onPanEnd: (_) => setState(() => _isPressed = false),
      onPanCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0, 1.0, 1.0),
        width: double.infinity,
        height: clampedHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Color(0x20000000),
              blurRadius: Adaptive.w(12),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                AppIcons.headphones,
                size: Adaptive.sp(80),
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: Adaptive.sp(72),
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.2),
                  height: 1,
                ),
              ),
            ),
            _buildBottomSection(cs, cardColor),
            _buildPlayButton(cs),
            if (hasActions)
              Positioned(
                bottom: AppSpacing.space4,
                right: AppSpacing.space3,
                child: _buildMenu(cs),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(AppColorsData cs, Color cardColor) {
    final progress = widget.video.duration > 0
        ? widget.video.currentPosition / widget.video.duration
        : 0.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress > 0)
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: Adaptive.h(2),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space4,
              AppSpacing.space3,
              AppSpacing.space4,
              AppSpacing.space4,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.video.name,
                  style: TextStyle(
                    fontSize: Adaptive.sp(AppTypography.fontSizeBase),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: Adaptive.h(2)),
                Row(
                  children: [
                    Icon(
                      AppIcons.schedule,
                      size: Adaptive.icon(10),
                      color: Colors.white70,
                    ),
                    SizedBox(width: Adaptive.w(4)),
                    Text(
                      '${widget.video.currentPositionString} / ${widget.video.durationString}',
                      style: TextStyle(
                        fontSize: Adaptive.sp(AppTypography.fontSizeXSmall),
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (progress > 0) ...[
                  SizedBox(height: Adaptive.h(4)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Adaptive.w(6),
                      vertical: Adaptive.h(1),
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Text(
                      '已播放 ${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: Adaptive.sp(AppTypography.fontSizeXSmall),
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(AppColorsData cs) {
    return Center(
      child: Container(
        width: Adaptive.w(36),
        height: Adaptive.w(36),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: Adaptive.w(12),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          AppIcons.play,
          size: Adaptive.w(20),
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMenu(AppColorsData cs) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'rename':
            widget.onRename?.call();
            break;
          case 'delete':
            widget.onDelete?.call();
            break;
        }
      },
      offset: const Offset(-120, 0),
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      elevation: 6,
      child: Container(
        width: Adaptive.r(28),
        height: Adaptive.r(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            Adaptive.r(AppRadius.sm),
          ),
          color: Colors.black.withValues(alpha: 0.65),
        ),
        child: Icon(
          AppIcons.moreVert,
          size: Adaptive.sp(18),
          color: Colors.white,
        ),
      ),
      itemBuilder: (context) => [
        if (widget.onRename != null)
          PopupMenuItem(
            value: 'rename',
            child: _menuRow(context, AppIcons.edit, '重命名', cs),
          ),
        if (widget.onDelete != null) ...[
          const PopupMenuDivider(height: 1),
          PopupMenuItem(
            value: 'delete',
            child: _menuRow(context, AppIcons.delete, '删除', cs),
          ),
        ],
      ],
    );
  }

  Widget _menuRow(
    BuildContext context,
    IconData icon,
    String title,
    AppColorsData cs,
  ) {
    return Row(
      children: [
        Icon(icon, size: Adaptive.sp(18), color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.space2),
        Text(
          title,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: Adaptive.sp(AppTypography.fontSizeBase),
          ),
        ),
      ],
    );
  }
}
