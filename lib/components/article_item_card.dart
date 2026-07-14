/// 文章单资源卡片（文件夹详情网格）
///
/// 风格与 VideoCard 统一：
/// - 彩色背景 + 大首字母居中显示
/// - 底部渐变遮罩叠加标题 + 元数据
/// - 右下竖三点菜单
library;

import 'package:flutter/material.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/theme/app_colors.dart';

class ArticleItemCard extends StatefulWidget {
  final Article article;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const ArticleItemCard({
    super.key,
    required this.article,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  State<ArticleItemCard> createState() => _ArticleItemCardState();
}

class _ArticleItemCardState extends State<ArticleItemCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final cardColor = AppColors.articleColorFor(widget.article.title);
    final hasActions = widget.onRename != null || widget.onDelete != null;
    final letter = widget.article.title.isNotEmpty
        ? widget.article.title[0].toUpperCase()
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
              blurRadius: Adaptive.w(context, 8),
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
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 36),
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
    final metaParts = <String>[];
    if (widget.article.totalParagraphs > 0) {
      metaParts.add('${widget.article.totalParagraphs}段');
    }
    if (widget.article.totalSentences > 0) {
      metaParts.add('${widget.article.totalSentences}句');
    }
    if (widget.article.wordCount > 0) {
      metaParts.add('${widget.article.wordCount}词');
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.space3,
          Adaptive.h(context, 20),
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
              widget.article.title,
              style: TextStyle(
                fontSize: Adaptive.sp(context, AppTypography.fontSizeBase),
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (metaParts.isNotEmpty) SizedBox(height: Adaptive.h(context, 2)),
            if (metaParts.isNotEmpty)
              Text(
                metaParts.join(' · '),
                style: TextStyle(
                  fontSize: Adaptive.sp(context, AppTypography.fontSizeXSmall),
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        width: Adaptive.r(context, 26),
        height: Adaptive.r(context, 26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            Adaptive.r(context, AppRadius.sm),
          ),
          color: Colors.black.withValues(alpha: 0.65),
        ),
        child: Icon(
          AppIcons.moreVert,
          size: Adaptive.sp(context, 16),
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
        Icon(icon, size: Adaptive.sp(context, 18), color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.space2),
        Text(
          title,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: Adaptive.sp(context, AppTypography.fontSizeBase),
          ),
        ),
      ],
    );
  }
}
