/// 视频集卡片（首页列表）
///
/// 与 VideoCard 统一的全铺封面设计：
/// - 缩略图填充整个卡片
/// - 底部渐变遮罩叠加视频集名称
/// - 右上角完成/总集数徽章
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/services/folder_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/responsive_size.dart';

class FolderCard extends StatelessWidget {
  final VideoFolder folder;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FolderCard({super.key, required this.folder, this.isSelected = false, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.cardThumbnailBg,
          border: isSelected ? Border.all(color: colorScheme.primary, width: 2.5) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 7.5 : 10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(context, colorScheme),
              _buildBottomOverlay(context, colorScheme),
              _buildBadge(context, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, ColorScheme colorScheme) {
    return FutureBuilder<String?>(
      future: FolderStatsService.coverFullPath(folder.cover),
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path != null && File(path).existsSync()) {
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(context, colorScheme),
          );
        }
        return _placeholder(context, colorScheme);
      },
    );
  }

  Widget _placeholder(BuildContext context, ColorScheme colorScheme) {
    return Container(
      color: AppColors.cardThumbnailBg,
      child: Center(
        child: Icon(Icons.play_circle_outline, size: ResponsiveSize.icon(context) * 1.5, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _buildBottomOverlay(BuildContext context, ColorScheme colorScheme) {
    final isTablet = ResponsiveSize.isTablet(context);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 24, 10, isTablet ? 12 : 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
          ),
        ),
        child: Text(
          folder.name,
          style: TextStyle(
            fontSize: ResponsiveSize.fontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, ColorScheme colorScheme) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: ResponsiveSize.fontSize(context, 10), color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              '${folder.completedCount}/${folder.videoCount}',
              style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 11), fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
