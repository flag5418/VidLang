/// 文章单资源卡片（文件夹详情网格）
///
/// 风格与 VideoCard 统一（音频明细的直接复用）：
/// - 彩色背景 + 大首字母居中显示
/// - 底部渐变遮罩叠加标题 + 元数据
/// - 右下竖三点菜单
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/theme.dart';

class ArticleItemCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = AppColors.articleColorFor(article.title);
    final hasActions = onRename != null || onDelete != null;
    final letter = article.title.isNotEmpty ? article.title[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: cardColor,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  letter,
                  style: TextStyle(fontSize: 36.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.25), height: 1),
                ),
              ),
              _buildBottomOverlay(colorScheme),
              if (hasActions)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: _buildMoreButton(colorScheme),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(ColorScheme colorScheme) {
    final metaParts = <String>[];
    if (article.totalParagraphs > 0) metaParts.add('${article.totalParagraphs}段');
    if (article.totalSentences > 0) metaParts.add('${article.totalSentences}句');
    if (article.wordCount > 0) metaParts.add('${article.wordCount}词');

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 24, 10, 10),
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
              article.title,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (metaParts.isNotEmpty) SizedBox(height: 2.h),
            if (metaParts.isNotEmpty)
              Text(
                metaParts.join(' · '),
                style: TextStyle(fontSize: 10.sp, color: Colors.white70, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreButton(ColorScheme colorScheme) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'rename':
            onRename?.call();
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
        width: 26.r,
        height: 26.r,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6.r), color: Colors.black.withValues(alpha: 0.65)),
        child: Icon(Icons.more_vert, size: 16.sp, color: Colors.white),
      ),
      itemBuilder: (context) => [
        if (onRename != null)
          PopupMenuItem(value: 'rename', child: _menuRow(context, Icons.edit_outlined, '重命名', colorScheme)),
        if (onDelete != null) ...[
          const PopupMenuDivider(height: 1),
          PopupMenuItem(value: 'delete', child: _menuRow(context, Icons.delete_outline, '删除', colorScheme)),
        ],
      ],
    );
  }

  Widget _menuRow(BuildContext context, IconData icon, String title, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: cs.onSurface, fontSize: 14.sp)),
      ],
    );
  }
}
