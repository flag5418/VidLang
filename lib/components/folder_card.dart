/// 资源集卡片（首页 / 资源列表）
///
/// 圆角矩形卡片风格：
/// - 类型色背景 + 圆角
/// - 左上角 Material 类型图标 + 右上角数量角标
/// - 居中大号文件夹名称
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
import 'package:vidlang/theme/app_shadows.dart';
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

class _FolderCardState extends State<FolderCard> with TickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _rippleAnimation = Tween<double>(begin: 0.0, end: 0.15).animate(CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _rippleController.forward();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final typeColor = AppColors.colorForType(widget.folder.folderType.name, brightness: brightness);
    final bgColor = AppColors.cardBgForType(widget.folder.folderType.name, brightness: brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        onLongPress: widget.onLongPress,
        splashColor: typeColor.withValues(alpha: 0.2),
        highlightColor: typeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
          transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0, 1.0, 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            gradient: LinearGradient(
              colors: [bgColor.withValues(alpha: 1.0), bgColor.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: widget.isSelected
                ? Border.all(color: typeColor, width: 2.5)
                : Border.all(color: typeColor.withValues(alpha: 0.08), width: 1),
            boxShadow: [
              ...AppShadows.sm,
              BoxShadow(
                color: typeColor.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(widget.isSelected ? AppRadius.card - 2.5 : AppRadius.card),
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
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.space4),
                              child: Text(
                                widget.folder.name,
                                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colorScheme.onSurface, letterSpacing: 0.2),
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
              Align(
                alignment: Alignment.topCenter,
                child: AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(widget.isSelected ? AppRadius.card - 2.5 : AppRadius.card),
                          topRight: Radius.circular(widget.isSelected ? AppRadius.card - 2.5 : AppRadius.card),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: _rippleAnimation.value),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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

  Widget _buildTopRow(Color typeColor, int count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.space4, AppSpacing.space4, 10, 0),
      child: Row(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 4,
            children: [
              Icon(ResourceIcons.displayIconFor(widget.folder.folderType.name), size: 26.sp, color: typeColor),
              if (count > 0) _buildBadge(count, typeColor),
            ],
          ),
          Expanded(child: Container()),
        ],
      ),
    );
  }

  Widget _buildBottomRow(ColorScheme colorScheme, String? currentTitle) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.space4, 4, AppSpacing.space4, AppSpacing.space4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow_rounded, size: 13.sp, color: colorScheme.onSurfaceVariant),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              currentTitle ?? '',
              style: TextStyle(fontSize: AppTypography.fontSizeXSmall, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(int count, Color typeColor) {
    final unit = ResourceIcons.unitLabel(widget.folder.folderType.name);
    return Text(
      '($count$unit)',
      style: TextStyle(fontSize: AppTypography.fontSizeXSmall, fontWeight: FontWeight.w600, color: typeColor.withValues(alpha: 0.85)),
    );
  }
}
