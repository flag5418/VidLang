/// 文章主卡片组件（对标 MainVideoCard）
///
/// 在文章集详情页顶部展示当前/最后一篇阅读文章：
/// - 使用 16:9 比例，响应式高度（与 MainVideoCard 一致）
/// - 彩色背景，大字母居中
/// - 底部渐变遮罩叠加标题 + 元数据
/// - 整张卡片可点击进入阅读器
/// - 底部阅读进度条
/// - 右下竖三点菜单
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/theme.dart';

class ArticleHeroCard extends StatelessWidget {
  final Article article;
  final VoidCallback? onRead;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const ArticleHeroCard({
    super.key,
    required this.article,
    this.onRead,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = (screenWidth - 32) * 9 / 16;
    final clampedHeight = cardHeight.clamp(220.0, 420.0);
    final cardColor = AppColors.articleColorFor(article.title);
    final hasActions = onRename != null || onDelete != null;
    final letter = article.title.isNotEmpty ? article.title[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: onRead,
      child: Container(
        width: double.infinity,
        height: clampedHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: cardColor,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                letter,
                style: TextStyle(fontSize: 72.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.2), height: 1),
              ),
            ),
            _buildBottomSection(colorScheme, cardColor),
            _buildPlayButton(colorScheme),
            if (hasActions)
              Positioned(
                bottom: 14,
                right: 12,
                child: _buildMenu(colorScheme),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(ColorScheme colorScheme, Color cardColor) {
    final progress = article.progress.clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    final metaParts = <String>[];
    if (article.totalParagraphs > 0) metaParts.add('${article.totalParagraphs}段');
    if (article.totalSentences > 0) metaParts.add('${article.totalSentences}句');
    if (article.wordCount > 0) metaParts.add('${article.wordCount}词');

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
              minHeight: 2,
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
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
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metaParts.isNotEmpty) SizedBox(height: 2.h),
                if (metaParts.isNotEmpty)
                  Text(
                    metaParts.join(' · '),
                    style: TextStyle(fontSize: 11.sp, color: Colors.white70, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (progress > 0 && metaParts.isNotEmpty) SizedBox(height: 4.h),
                if (progress > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: Colors.white.withValues(alpha: 0.2)),
                    child: Text(
                      '已读 $percent%',
                      style: TextStyle(fontSize: 10.sp, color: Colors.white, fontWeight: FontWeight.w500),
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
        width: 34.w,
        height: 34.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Icon(Icons.play_arrow_rounded, size: 18.w, color: Colors.white),
      ),
    );
  }

  Widget _buildMenu(ColorScheme colorScheme) {
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
        width: 28.r,
        height: 28.r,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6.r),
          color: Colors.black.withValues(alpha: 0.65),
        ),
        child: Icon(Icons.more_vert, size: 18.sp, color: Colors.white),
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
