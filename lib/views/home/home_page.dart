/// 首页
///
/// 顶部：大图宣传位（预留）
/// 中段：3段资源快速启动（视频/文章/音频）
///   - 每段显示标题 + "更多"按钮
///   - 显示最近3个文件夹，第一个为"正在播放"
///   - 无资源时显示缺省引导
/// 底部：统计信息（🔥 ⏱ 📖 🎯）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/folder_card.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/file_provider.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/responsive_size.dart';
import 'package:vidlang/views/files/folder_detail_page.dart';
import 'package:vidlang/views/player/player_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Map<String, List<VideoFolder>> _recentFolders = {};
  HomeStats _stats = const HomeStats();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([StatsService.getAllRecentFolders(), StatsService.getHomeStats()]);
      if (!mounted) return;
      setState(() {
        _recentFolders = results[0] as Map<String, List<VideoFolder>>;
        _stats = results[1] as HomeStats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _goToResources(String folderType) {
    final typeIndex = ['video', 'article', 'music'].indexOf(folderType);
    if (typeIndex < 0) return;
    ref.read(resourceTabProvider.notifier).state = typeIndex;
    ref.read(navigationIndexProvider.notifier).setIndex(1);
  }

  Future<void> _openFolder(VideoFolder folder) async {
    final code = folder.code;
    if (code == null) return;

    // 有最后播放记录，直接进入播放
    if (folder.lastVideoCode != null && folder.lastVideoCode!.isNotEmpty) {
      try {
        final videos = await DatabaseService.findByCondition(
          () => VideoInfo(),
          where: 'folder_code = ? AND is_deleted = 0',
          whereArgs: [code],
          orderBy: 'order_index ASC, created_at ASC',
        );
        if (videos.isNotEmpty && mounted) {
          // 找到最后播放的视频
          VideoInfo? targetVideo;
          for (final v in videos) {
            if (v.code == folder.lastVideoCode) {
              targetVideo = v;
              break;
            }
          }
          targetVideo ??= videos.first;
          await ref.read(fileProvider.notifier).loadVideos(code);
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerPage(videoCode: targetVideo!.code!, folderVideos: videos),
            ),
          );
          if (!mounted) return;
          await _loadData();
          return;
        }
      } catch (_) {
        // fallback to folder detail
      }
    }

    // 无播放记录，进入文件夹详情页
    if (!mounted) return;
    await ref.read(fileProvider.notifier).loadVideos(code);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FolderDetailPage(folderCode: code)));
    if (!mounted) return;
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBanner(colorScheme),
                    SizedBox(height: AppSpacing.md),
                    _buildResourceSection(colorScheme, 'video', '🎬 视频', Icons.videocam),
                    SizedBox(height: AppSpacing.md),
                    _buildResourceSection(colorScheme, 'article', '📄 文章', Icons.article),
                    SizedBox(height: AppSpacing.md),
                    _buildResourceSection(colorScheme, 'music', '🎵 音频', Icons.headphones),
                    SizedBox(height: AppSpacing.lg),
                    _buildStatsSection(colorScheme),
                    SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBanner(ColorScheme colorScheme) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [colorScheme.primary.withValues(alpha: 0.3), colorScheme.primary.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school, size: ResponsiveSize.icon(context) * 1.5, color: colorScheme.primary.withValues(alpha: 0.6)),
            SizedBox(height: AppSpacing.sm),
            Text(
              'VidLang',
              style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 24), fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
            Text('通过沉浸式学习语言', style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 13), color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceSection(ColorScheme colorScheme, String type, String title, IconData icon) {
    final folders = _recentFolders[type] ?? [];
    final hasResources = folders.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: ResponsiveSize.fontSize(context, AppTypography.fontSizeBase), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
            TextButton(
              onPressed: () => _goToResources(type),
              child: Text('更多', style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 13), color: colorScheme.primary)),
            ),
          ],
        ),
        if (!hasResources) _buildEmptySection(colorScheme, icon, type) else _buildFolderRow(colorScheme, folders),
      ],
    );
  }

  Widget _buildEmptySection(ColorScheme colorScheme, IconData icon, String type) {
    final typeName = type == 'video'
        ? '视频'
        : type == 'article'
        ? '文章'
        : '音频';
    return GestureDetector(
      onTap: () => _goToResources(type),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surfaceElevated,
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: ResponsiveSize.icon(context) * 1.2, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            SizedBox(height: AppSpacing.sm),
            Text('暂无$typeName', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: ResponsiveSize.fontSize(context, 14))),
            SizedBox(height: 4),
            Text('点击进入资源页创建第一个$typeName', style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 12), color: colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderRow(ColorScheme colorScheme, List<VideoFolder> folders) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: folders.length,
        separatorBuilder: (_, _) => SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final folder = folders[index];
          final isPlaying = index == 0 && folder.lastPlayDate != null;

          return SizedBox(
            width: 160,
            child: Stack(
              children: [
                FolderCard(folder: folder, onTap: () => _openFolder(folder), onLongPress: () {}),
                if (isPlaying)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 12, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '播放中',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsSection(ColorScheme colorScheme) {
    final stats = [
      _StatItem(icon: Icons.local_fire_department, label: '连续', value: '${_stats.streakDays} 天', color: Colors.orange),
      _StatItem(icon: Icons.timer_outlined, label: '今日', value: _formatDuration(_stats.todayDuration), color: colorScheme.primary),
      _StatItem(icon: Icons.menu_book, label: '生词', value: '${_stats.wordCount}', color: Colors.green),
      _StatItem(icon: Icons.check_circle_outline, label: '已学', value: '${_stats.resourceCount}', color: Colors.purple),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.surfaceElevated,
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学习数据',
            style: TextStyle(fontSize: ResponsiveSize.fontSize(context, AppTypography.fontSizeBase), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: stats.map((item) {
              return Expanded(
                child: Column(
                  children: [
                    Icon(item.icon, size: ResponsiveSize.icon(context), color: item.color),
                    SizedBox(height: 4),
                    Text(
                      item.value,
                      style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 14), fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                    ),
                    SizedBox(height: 2),
                    Text(item.label, style: TextStyle(fontSize: ResponsiveSize.fontSize(context, 11), color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${seconds ~/ 60}分钟';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '$h小时$m分钟';
  }
}

class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.icon, required this.label, required this.value, required this.color});
}
