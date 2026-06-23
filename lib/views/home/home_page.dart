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
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/components/folder_card.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/file_provider.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/article/article_reader_page.dart';
import 'package:vidlang/views/audio_player/audio_player_page.dart';
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

    if (folder.folderType == FolderContentType.article) {
      try {
        final articles = await DatabaseService.findByCondition(
          () => Article(),
          where: 'folder_code = ? AND is_deleted = 0',
          whereArgs: [code],
          orderBy: 'last_study_date DESC, updated_at DESC',
        );
        if (articles.isNotEmpty && mounted) {
          Article target = articles.firstWhere((a) => a.lastStudyDate != null, orElse: () => articles.first);
          if (!mounted) return;
          await Navigator.push(context, MaterialPageRoute(builder: (_) => ArticleReaderPage(articleCode: target.code!)));
          if (!mounted) return;
          await _loadData();
          return;
        }
      } catch (_) {}
    }

    if (folder.lastVideoCode != null && folder.lastVideoCode!.isNotEmpty) {
      try {
        final videos = await DatabaseService.findByCondition(
          () => VideoInfo(),
          where: 'folder_code = ? AND is_deleted = 0',
          whereArgs: [code],
          orderBy: 'order_index ASC, created_at ASC',
        );
        if (videos.isNotEmpty && mounted) {
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
          final isMusic = folder.folderType == FolderContentType.music;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => isMusic
                  ? AudioPlayerPage(videoCode: targetVideo!.code!, folderVideos: videos, audioType: 'music')
                  : PlayerPage(videoCode: targetVideo!.code!, folderVideos: videos),
            ),
          );
          if (!mounted) return;
          await _loadData();
          return;
        }
      } catch (_) {}
    }

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
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
      appBar: AppBar(
        title: Text(
          'VidLang',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        ),
        elevation: 0,
        backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
        scrolledUnderElevation: 0.5,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding, vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsSection(colorScheme),
                    SizedBox(height: AppSpacing.lg),
                    _buildResourceSection(colorScheme, 'video', '视频', Icons.movie_outlined),
                    SizedBox(height: AppSpacing.lg),
                    _buildResourceSection(colorScheme, 'music', '音频', Icons.music_note_outlined),
                    SizedBox(height: AppSpacing.lg),
                    _buildResourceSection(colorScheme, 'article', '文章', Icons.menu_book_outlined),
                    SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsSection(ColorScheme colorScheme) {
    final stats = [
      _StatItem(icon: Icons.local_fire_department, label: '连续', value: '${_stats.streakDays} 天', color: Colors.orange),
      _StatItem(icon: Icons.timer_outlined, label: '今日', value: _formatDuration(_stats.todayDuration), color: colorScheme.primary),
      _StatItem(icon: Icons.book, label: '生词', value: '${_stats.wordCount}', color: Colors.green),
      _StatItem(icon: Icons.check_circle_outline, label: '已学', value: '${_stats.resourceCount}', color: Colors.purple),
    ];

    return Container(
      padding: EdgeInsets.all(AppSpacing.space5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AppColors.getSurface(brightness: Theme.of(context).brightness),
      ),
      child: Row(
        children: stats.map((item) {
          return Expanded(
            child: Column(
              children: [
                Icon(item.icon, size: 20.sp, color: item.color),
                SizedBox(height: 6.h),
                Text(
                  item.value,
                  style: TextStyle(fontSize: AppTypography.fontSizeLarge, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                SizedBox(height: 2.h),
                Text(
                  item.label,
                  style: TextStyle(fontSize: AppTypography.fontSizeXSmall, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResourceSection(ColorScheme colorScheme, String type, String title, IconData icon) {
    final folders = _recentFolders[type] ?? [];
    final hasResources = folders.isNotEmpty;
    final typeColor = AppColors.colorForType(type, brightness: Theme.of(context).brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20.sp, color: typeColor),
            SizedBox(width: 8.w),
            Text(
              title,
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
            const Spacer(),
            InkWell(
              onTap: () => _goToResources(type),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '更多',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
                    ),
                    SizedBox(width: 2.w),
                    Icon(Icons.chevron_right_rounded, size: 16.sp, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
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
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24.sp, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            SizedBox(height: AppSpacing.sm),
            Text(
              '暂无$typeName',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: AppTypography.fontSizeSmall),
            ),
            SizedBox(height: 4),
            Text(
              '点击进入资源页创建第一个$typeName',
              style: TextStyle(fontSize: AppTypography.fontSizeXSmall, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderRow(ColorScheme colorScheme, List<VideoFolder> folders) {
    return SizedBox(
      height: 170.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: folders.length,
        separatorBuilder: (_, _) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final folder = folders[index];
          return SizedBox(
            width: 154.w,
            height: 170.h,
            child: FolderCard(folder: folder, onTap: () => _openFolder(folder), onLongPress: () {}),
          );
        },
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
