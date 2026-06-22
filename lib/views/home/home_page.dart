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
          Article target = articles.firstWhere(
            (a) => a.lastStudyDate != null,
            orElse: () => articles.first,
          );
          if (!mounted) return;
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => ArticleReaderPage(articleCode: target.code!),
          ));
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(AppSpacing.pagePadding),
                  child: Column(
                    spacing: AppSpacing.lg,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBanner(colorScheme),
                      _buildStatsSection(colorScheme),
                      _buildResourceSection(colorScheme, 'video', '视频', Icons.movie),
                      _buildResourceSection(colorScheme, 'music', '音频', Icons.music_note),
                      _buildResourceSection(colorScheme, 'article', '文章', Icons.menu_book),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBanner(ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: Container(
        height: 170,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            colors: [colorScheme.primary, const Color(0xFF6366F1), const Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.6, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(top: -20, right: -20, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
            Positioned(bottom: -30, left: -30, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)))),
            Positioned(top: 20, right: 30, child: Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2)))),
            Positioned(bottom: 30, left: 40, child: Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15)))),
            Positioned(
              top: 30,
              left: 20,
              child: Container(
                width: 3,
                height: 40,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.space5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.2)),
                      child: Icon(Icons.school_rounded, size: 32.sp, color: Colors.white),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.white, Colors.white.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        'VidLang',
                        style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '看视频、听英语，读文章、轻松学英语',
                      style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500),
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

  Widget _buildResourceSection(ColorScheme colorScheme, String type, String title, IconData icon) {
    final folders = _recentFolders[type] ?? [];
    final hasResources = folders.isNotEmpty;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: AppTypography.fontSizeLarge, fontWeight: FontWeight.w600, color: colorScheme.onSurface, letterSpacing: 0.3),
              ),
              TextButton(
                onPressed: () => _goToResources(type),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  '更多',
                  style: TextStyle(fontSize: AppTypography.fontSizeSmall, color: colorScheme.primary),
                ),
              ),
            ],
          ),
          if (!hasResources) _buildEmptySection(colorScheme, icon, type) else _buildFolderRow(colorScheme, folders),
        ],
      ),
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
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: folders.length,
        separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final folder = folders[index];
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + index * 80),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset((1 - value) * 20, 0),
                  child: child,
                ),
              );
            },
            child: SizedBox(
              width: 150,
              height: 140,
              child: Stack(
                children: [
                  FolderCard(folder: folder, onTap: () => _openFolder(folder), onLongPress: () {}),
                ],
              ),
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

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.space5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '学习数据',
              style: TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.w600, color: colorScheme.onSurface, letterSpacing: 0.3),
            ),
            SizedBox(height: AppSpacing.md),
            Row(
              children: stats.map((item) {
                return Expanded(
                  child: Column(
                    children: [
                      Icon(item.icon, size: 22.sp, color: item.color),
                      SizedBox(height: 4),
                      Text(
                        item.value,
                        style: TextStyle(fontSize: AppTypography.fontSizeBase, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                      SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(fontSize: AppTypography.fontSizeXSmall, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
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
