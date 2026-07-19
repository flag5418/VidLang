import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/files/thumbnail_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 侧边栏（资源列表）
///
/// 布局设计:
/// - 滑出模式: 右侧滑出，毛玻璃背景 + 黑色半透明
/// - 固定模式: iPad 横屏分栏
/// - 列表项: 缩略图 + 标题 + 进度条 + 时长 + 字幕标签
class SideDrawer extends ConsumerWidget {
  final bool isOpen;
  final bool isPermanent;
  final List<VideoInfo> videos;
  final String currentVideoCode;
  final String title;
  final void Function(String code) onSwitchTo;
  final VoidCallback onClose;

  const SideDrawer({
    super.key,
    this.isOpen = false,
    this.isPermanent = false,
    this.videos = const [],
    required this.currentVideoCode,
    required this.title,
    required this.onSwitchTo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerContent = _buildDrawerContent(context, ref);

    if (isPermanent) {
      return _buildPermanentDrawer(context, drawerContent);
    }

    if (!isOpen) return const SizedBox.shrink();

    return _buildSlidingDrawer(context, drawerContent);
  }

  Widget _buildSlidingDrawer(BuildContext context, Widget drawerContent) {
    return GestureDetector(
      onTap: onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        alignment: Alignment.centerRight,
        child: AnimatedSlide(
          offset: Offset(isOpen ? 0.0 : 1.0, 0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: FractionallySizedBox(
            widthFactor: adaptive.isIPad() ? 0.35 : 0.8,
            alignment: Alignment.centerRight,
            child: SafeArea(
              top: true,
              bottom: false,
              child: _buildDrawerContainer(context, drawerContent),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerContainer(BuildContext context, Widget drawerContent) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: _getDrawerWidth(context),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            border: Border(
              left: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: drawerContent,
        ),
      ),
    );
  }

  /// 固定模式（iPad 横屏分栏）
  Widget _buildPermanentDrawer(BuildContext context, Widget content) {
    return Container(
      width: _getDrawerWidth(context),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: content,
      ),
    );
  }

  double _getDrawerWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (adaptive.isIPad()) {
      return (screenWidth * 0.33).clamp(
        adaptive.Adaptive.w(280),
        screenWidth * 0.5,
      ).toDouble();
    }
    return adaptive.Adaptive.w(320);
  }

  /// 主内容区（仅资源列表）
  Widget _buildDrawerContent(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // 标题栏
        _buildTitleBar(context),

        // 分隔线
        Divider(height: 1, color: Colors.white10),

        // 资源列表
        Expanded(child: _buildResourceList(context)),
      ],
    );
  }

  /// 标题栏
  Widget _buildTitleBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(12),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(16),
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 资源列表
  // ═══════════════════════════════════════════════════════════

  Widget _buildResourceList(BuildContext context) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.folder, size: 48, color: Colors.white24),
            SizedBox(height: adaptive.Adaptive.h(12)),
            Text(
              '暂无内容',
              style: TextStyle(
                color: Colors.white38,
                fontSize: adaptive.Adaptive.sp(14),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(8),
        vertical: adaptive.Adaptive.h(8),
      ),
      itemCount: videos.length,
      separatorBuilder: (_, __) => SizedBox(height: adaptive.Adaptive.h(8)),
      itemBuilder: (ctx, index) => _buildListItem(videos[index]),
    );
  }

  /// 列表项（对齐 VideoCard 风格）
  Widget _buildListItem(VideoInfo video) {
    final isSelected = video.code == currentVideoCode;
    final progress = _getProgress(video);

    return GestureDetector(
      onTap: () => onSwitchTo(video.code ?? ''),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          color: const Color(0xFF2A2A2A),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧：缩略图
            SizedBox(
              width: adaptive.Adaptive.w(80),
              height: adaptive.Adaptive.h(60),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: _buildThumbnail(video),
              ),
            ),

            // 右侧：信息列
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(adaptive.Adaptive.w(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      video.name,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(14),
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: adaptive.Adaptive.h(4)),

                    // 进度条
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(
                          isSelected
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    SizedBox(height: adaptive.Adaptive.h(4)),

                    // 时长行
                    Row(
                      children: [
                        Icon(
                          AppIcons.schedule,
                          size: adaptive.Adaptive.sp(10),
                          color: Colors.white54,
                        ),
                        SizedBox(width: adaptive.Adaptive.w(4)),
                        Text(
                          '${video.currentPositionString} / ${video.durationString}',
                          style: TextStyle(
                            fontSize: adaptive.Adaptive.sp(11),
                            color: Colors.white54,
                          ),
                        ),
                        if (video.hasSubtitles) ...[
                          SizedBox(width: adaptive.Adaptive.w(8)),
                          Icon(
                            AppIcons.subtitles,
                            size: adaptive.Adaptive.sp(12),
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getProgress(VideoInfo video) {
    if (video.duration <= 0) return 0.0;
    return (video.currentPosition / video.duration).clamp(0.0, 1.0);
  }

  Widget _buildThumbnail(VideoInfo video) {
    final cover = video.currentCover ?? video.cover;
    if (cover != null && cover.isNotEmpty) {
      return FutureBuilder<String>(
        future: ThumbnailService.getFullPath(cover),
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (path != null && File(path).existsSync()) {
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _thumbnailPlaceholder(),
            );
          }
          return _thumbnailPlaceholder();
        },
      );
    }
    return _thumbnailPlaceholder();
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Icon(
        AppIcons.movie,
        size: adaptive.Adaptive.sp(22),
        color: Colors.white24,
      ),
    );
  }
}
