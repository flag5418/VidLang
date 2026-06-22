/// 资源集卡片（首页 / 资源列表）
///
/// 圆角矩形卡片：
/// - 纯色背景 + 类型色左侧装饰条
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
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/theme/app_typography.dart';

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
    final brightness = Theme.of(context).brightness;
    final typeColor = AppColors.colorForType(widget.folder.folderType.name, brightness: brightness);
    final cardBg = AppColors.getSurface(brightness: brightness);
    final cardBorder = AppColors.getOutline(brightness: brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            color: cardBg,
            border: widget.isSelected
                ? Border.all(color: typeColor, width: 2)
                : Border.all(color: cardBorder.withValues(alpha: 0.12), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.15 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.isSelected ? AppRadius.card - 2 : AppRadius.card),
            child: Stack(
              children: [
                // 左侧类型色条
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: Container(color: typeColor),
                ),
                // 内容
                Padding(
                  padding: EdgeInsets.only(left: AppSpacing.space4),
                  child: FutureBuilder<_FolderInfo>(
                    future: _loadFolderInfo(),
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopRow(context, typeColor, info?.count ?? 0),
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: AppSpacing.space3),
                                child: Text(
                                  widget.folder.name,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.getOnSurface(brightness: brightness),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          _buildBottomRow(brightness, info?.currentTitle),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(0, AppSpacing.space4, 10, 0),
      child: Row(
        children: [
          Icon(ResourceIcons.displayIconFor(widget.folder.folderType.name), size: 24.sp, color: typeColor),
          SizedBox(width: 4),
          if (count > 0)
            Text(
              '($count${ResourceIcons.unitLabel(widget.folder.folderType.name)})',
              style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: typeColor.withValues(alpha: 0.8)),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomRow(Brightness br, String? currentTitle) {
    if (currentTitle == null || currentTitle.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 4, AppSpacing.space4, AppSpacing.space4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 12.sp, color: AppColors.getOnSurfaceVariant(brightness: br)),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              currentTitle,
              style: TextStyle(
                fontSize: 11.sp,
                color: AppColors.getOnSurfaceVariant(brightness: br),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
