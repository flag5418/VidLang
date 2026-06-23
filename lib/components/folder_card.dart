/// 资源集卡片（首页 / 资源列表）
///
/// 圆角矩形卡片：
/// - 白色/纯黑背景 + 类型色左侧装饰条
/// - 全圆角边框 + 阴影
/// - 左上角 Material 类型图标 + 数量
/// - 居中文件夹名称
/// - 底部当前学习/首个资源标题
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/theme/app_radius.dart';

class _FolderInfo {
  final int count;
  final String? currentTitle;
  _FolderInfo(this.count, this.currentTitle);
}

class FolderCard extends StatefulWidget {
  final VideoFolder folder;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FolderCard({super.key, required this.folder, this.isSelected = false, required this.onTap, required this.onLongPress});

  @override
  State<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<FolderCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final typeColor = AppColors.colorForType(widget.folder.folderType.name, brightness: brightness);
    final titleColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;

    final borderColor = widget.isSelected ? typeColor.withValues(alpha: 0.5) : colorScheme.outlineVariant.withValues(alpha: 0.5);
    final shadowColor = Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.05 : 0.02);
    final bgColor = colorScheme.surface;

    return InkWell(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.card),
      highlightColor: typeColor.withValues(alpha: 0.05),
      splashColor: typeColor.withValues(alpha: 0.1),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: borderColor, width: widget.isSelected ? 1.5 : 1),
            boxShadow: [BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: FutureBuilder<_FolderInfo>(
            future: _loadFolderInfo(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopRow(context, typeColor, info?.count ?? 0),
                  const Spacer(),
                  Text(
                    widget.folder.name,
                    style: TextStyle(fontSize: 16.sp, height: 1.4, fontWeight: FontWeight.w600, color: titleColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  _buildBottomRow(subtitleColor, info?.currentTitle),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<_FolderInfo> _loadFolderInfo() async {
    final type = widget.folder.folderType.name;
    if (type == 'article') {
      final articles = await BaseEntityExtension.findByCondition<Article>(
        () => Article(),
        where: 'folder_code = ? AND is_deleted = 0',
        whereArgs: [widget.folder.code],
        orderBy: 'order_index ASC, created_at DESC',
      );
      return _FolderInfo(articles.length, articles.isNotEmpty ? articles.first.title : null);
    }
    final videos = await BaseEntityExtension.findByCondition<VideoInfo>(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [widget.folder.code],
      orderBy: 'updated_at DESC',
    );
    if (videos.isEmpty) return _FolderInfo(0, null);
    final current = videos.where((v) => v.isCurrentPlaying).toList();
    final title = current.isNotEmpty ? current.first.name : videos.first.name;
    return _FolderInfo(videos.length, title);
  }

  Widget _buildTopRow(BuildContext ctx, Color typeColor, int count) {
    final colorScheme = Theme.of(ctx).colorScheme;
    final metaColor = colorScheme.onSurfaceVariant;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ResourceIcons.displayIconFor(widget.folder.folderType.name), size: 14.sp, color: typeColor),
            SizedBox(width: 4.w),
            Text(
              _folderTypeLabel(),
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: metaColor, letterSpacing: 0.2),
            ),
          ],
        ),
        if (count > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 4.w,
                height: 4.w,
                decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
              ),
              SizedBox(width: 4.w),
              Text(
                '$count${ResourceIcons.unitLabel(widget.folder.folderType.name)}',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: metaColor),
              ),
            ],
          ),
      ],
    );
  }

  String _folderTypeLabel() {
    switch (widget.folder.folderType.name) {
      case 'article':
        return '文章';
      case 'music':
        return '音频';
      default:
        return '视频';
    }
  }

  Widget _buildBottomRow(Color subtitleColor, String? currentTitle) {
    if (currentTitle == null || currentTitle.isEmpty) {
      return Row(
        children: [
          Icon(Icons.play_circle_outline_rounded, size: 14.sp, color: subtitleColor.withValues(alpha: 0.5)),
          SizedBox(width: 4.w),
          Text(
            '暂无最近内容',
            style: TextStyle(fontSize: 11.sp, color: subtitleColor.withValues(alpha: 0.5), fontWeight: FontWeight.w400),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.play_circle_filled_rounded, size: 14.sp, color: subtitleColor.withValues(alpha: 0.8)),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            currentTitle,
            style: TextStyle(fontSize: 12.sp, color: subtitleColor, fontWeight: FontWeight.w400),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
