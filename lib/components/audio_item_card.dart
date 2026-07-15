/// 音频单资源卡片（文件夹详情网格）
///
/// 风格与 ArticleItemCard 统一：
/// - 紫色系渐变背景 + 大首字母居中显示
/// - 底部渐变遮罩叠加标题 + 时长
/// - 右下竖三点菜单
library;

import 'package:flutter/material.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

class AudioItemCard extends StatefulWidget {
  final VideoInfo video;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const AudioItemCard({
    super.key,
    required this.video,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  State<AudioItemCard> createState() => _AudioItemCardState();
}

class _AudioItemCardState extends State<AudioItemCard> {
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
    final cardColor = _cardColor();
    final hasActions = widget.onRename != null || widget.onDelete != null;
    final letter = widget.video.name.isNotEmpty
        ? widget.video.name[0].toUpperCase()
        : '?';

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
          color: cardColor,
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: Adaptive.w(8),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Icon(
                  AppIcons.headphones,
                  size: Adaptive.sp(48),
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: Adaptive.sp(36),
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.25),
                    height: 1,
                  ),
                ),
              ),
              _buildBottomOverlay(cs),
              if (hasActions)
                Positioned(
                  bottom: AppSpacing.space2,
                  right: AppSpacing.space2,
                  child: _buildMoreButton(cs),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(AppColorsData cs) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space3,
          Adaptive.h(20),
          AppSpacing.space3,
          AppSpacing.space3,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
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
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: Adaptive.h(2)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.schedule,
                  size: Adaptive.icon(10),
                  color: Colors.white70,
                ),
                SizedBox(width: Adaptive.w(4)),
                Text(
                  widget.video.durationString,
                  style: TextStyle(
                    fontSize: Adaptive.sp(AppTypography.fontSizeXSmall),
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

  Widget _buildMoreButton(AppColorsData cs) {
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
        width: Adaptive.r(26),
        height: Adaptive.r(26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            Adaptive.r(AppRadius.sm),
          ),
          color: Colors.black.withValues(alpha: 0.65),
        ),
        child: Icon(
          AppIcons.moreVert,
          size: Adaptive.sp(16),
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
