/// 资源集卡片（首页 / 资源列表）
///
/// 圆角矩形卡片风格：
/// - 类型色背景 + 圆角
/// - 左上角 Material 类型图标 + 右上角数量角标
/// - 居中大号文件夹名称
/// - 底部当前学习/首个资源标题（首页不会展示空文件夹）
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

class FolderCard extends StatelessWidget {
  final VideoFolder folder;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FolderCard({super.key, required this.folder, this.isSelected = false, required this.onTap, required this.onLongPress});

  String get _type => folder.folderType.name;

  Future<_FolderInfo> _loadFolderInfo() async {
    if (_type == 'article') {
      final articles = await BaseEntityExtension.findByCondition<Article>(
        () => Article(),
        where: 'folder_code = ? AND is_deleted = 0',
        whereArgs: [folder.code],
        orderBy: 'order_index ASC, created_at DESC',
      );
      return _FolderInfo(articles.length, articles.isNotEmpty ? articles.first.title : null);
    }
    final videos = await BaseEntityExtension.findByCondition<VideoInfo>(
      () => VideoInfo(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [folder.code],
      orderBy: 'updated_at DESC',
    );
    if (videos.isEmpty) return _FolderInfo(0, null);
    final current = videos.where((v) => v.isCurrentPlaying).toList();
    final title = current.isNotEmpty ? current.first.name : videos.first.name;
    return _FolderInfo(videos.length, title);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final typeColor = AppColors.colorForType(_type, brightness: brightness);
    final bgColor = AppColors.cardBgForType(_type, brightness: brightness);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          color: bgColor,
          border: isSelected ? Border.all(color: typeColor, width: 2.5) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? AppRadius.card - 2.5 : AppRadius.card),
          child: FutureBuilder<_FolderInfo>(
            future: _loadFolderInfo(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopRow(typeColor, info?.count ?? 0),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        child: Text(
                          folder.name,
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  _buildBottomRow(colorScheme, info?.currentTitle),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(Color typeColor, int count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 12.w, 10.w, 0),
      child: 
      
      Row(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 4.w,
            children: [
              Icon(ResourceIcons.displayIconFor(_type), size: 28.w, color: typeColor),
               
              if (count > 0)
                _buildBadge(count, typeColor),
            ],
          ),
          Expanded(child: Container()),
        ],
      ),
    );
  }

  Widget _buildBottomRow(ColorScheme colorScheme, String? currentTitle) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 12.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 13.sp, color: colorScheme.onSurfaceVariant),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              currentTitle ?? '',
              style: TextStyle(fontSize: 11.sp, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(int count, Color typeColor) {
    final unit = ResourceIcons.unitLabel(_type);
    return Text(
      '($count$unit)',
      style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: typeColor.withValues(alpha: 0.85)),
    );
  }
}
