/// 首页
///
/// 顶部：2×2 统计九宫格（连续/今日/生词/已学）
/// 中段：3段资源快速启动（视频/文章/音频）
///   - 每段显示标题 + "更多"按钮
///   - 显示最近文件夹横向列表，第一个为"正在播放"
///   - 无资源时显示缺省引导
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
      final results = await Future.wait([
        StatsService.getAllRecentFolders(),
        StatsService.getHomeStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _recentFolders = results[0] as Map<String, List<VideoFolder>>;
        _stats = results[1] as HomeStats;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[HomePage] _loadData failed: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _goToResources(String folderType) {
    final typeIndex = ['video', 'music', 'article'].indexOf(folderType);
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
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArticleReaderPage(articleCode: target.code!),
            ),
          );
          if (!mounted) return;
          await _loadData();
          return;
        }
      } catch (_) {}
    }

    // 播放第一个资源（按 order_index 排序）
    try {
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'folder_code = ? AND is_deleted = 0',
        whereArgs: [code],
        orderBy: 'order_index ASC, created_at ASC',
      );
      if (videos.isNotEmpty && mounted) {
        final firstVideo = videos.first;
        await ref.read(fileProvider.notifier).loadVideos(code);
        if (!mounted) return;
        final isMusic = folder.folderType == FolderContentType.music;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isMusic
                ? AudioPlayerPage(
                    videoCode: firstVideo.code!,
                    folderVideos: videos,
                    audioType: 'music',
                  )
                : PlayerPage(
                    videoCode: firstVideo.code!,
                    folderVideos: videos,
                  ),
          ),
        );
        if (!mounted) return;
        await _loadData();
        return;
      }
    } catch (_) {}
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
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
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
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsSection(colorScheme),
                    SizedBox(height: AppSpacing.lg),
                    _buildResourceSection(
                      colorScheme,
                      'video',
                      '视频',
                      Icons.movie_outlined,
                    ),
                    SizedBox(height: AppSpacing.lg),
                    _buildResourceSection(
                      colorScheme,
                      'music',
                      '音频',
                      Icons.music_note_outlined,
                    ),
                    SizedBox(height: AppSpacing.lg),
                    _buildResourceSection(
                      colorScheme,
                      'article',
                      '文章',
                      Icons.menu_book_outlined,
                    ),
                    SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatsSection(ColorScheme colorScheme) {
    final brightness = Theme.of(context).brightness;
    final stats = [
      _GridStatItem(
        icon: Icons.local_fire_department_rounded,
        label: '连续学习',
        value: '${_stats.streakDays}',
        unit: '天',
        gradient: const [Color(0xFFFF6B35), Color(0xFFFF8E53)],
        bgAlpha: brightness == Brightness.dark ? 0.15 : 0.08,
      ),
      _GridStatItem(
        icon: Icons.schedule_rounded,
        label: '今日时长',
        value: _formatDuration(_stats.todayDuration),
        unit: '',
        gradient: const [Color(0xFF4284FC), Color(0xFF5B9FFF)],
        bgAlpha: brightness == Brightness.dark ? 0.15 : 0.08,
      ),
      _GridStatItem(
        icon: Icons.menu_book_rounded,
        label: '生词本',
        value: '${_stats.wordCount}',
        unit: '词',
        gradient: const [Color(0xFF22C55E), Color(0xFF4ADE80)],
        bgAlpha: brightness == Brightness.dark ? 0.15 : 0.08,
      ),
      _GridStatItem(
        icon: Icons.task_alt_rounded,
        label: '已学资源',
        value: '${_stats.resourceCount}',
        unit: '个',
        gradient: const [Color(0xFFA855F7), Color(0xFFC084FC)],
        bgAlpha: brightness == Brightness.dark ? 0.15 : 0.08,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10.w,
        crossAxisSpacing: 10.w,
        childAspectRatio: 1.4,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _buildStatCard(stats[index], brightness, colorScheme),
    );
  }

  Widget _buildStatCard(_GridStatItem item, Brightness brightness, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [item.gradient[0].withValues(alpha: item.bgAlpha), item.gradient[1].withValues(alpha: item.bgAlpha * 0.6)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: item.gradient[0].withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.12),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: item.gradient[0].withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(item.icon, size: 18.sp, color: item.gradient[0]),
            ),
            SizedBox(height: 10.h),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: item.value,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (item.unit.isNotEmpty)
                    TextSpan(
                      text: ' ${item.unit}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceSection(
    ColorScheme colorScheme,
    String type,
    String title,
    IconData icon,
  ) {
    final folders = _recentFolders[type] ?? [];
    final hasResources = folders.isNotEmpty;
    final brightness = Theme.of(context).brightness;
    final typeColor = AppColors.colorForType(type, brightness: brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行：带图标背景胶囊 + 标题 + 更多按钮
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(7.w),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: brightness == Brightness.dark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18.sp, color: typeColor),
            ),
            SizedBox(width: 10.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: InkWell(
                onTap: () => _goToResources(type),
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '更多',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16.sp,
                        color: typeColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),
        if (!hasResources)
          _buildEmptySection(colorScheme, icon, type, typeColor)
        else
          _buildFolderRow(colorScheme, folders),
      ],
    );
  }

  Widget _buildEmptySection(
    ColorScheme colorScheme,
    IconData icon,
    String type,
    Color typeColor,
  ) {
    final typeName = type == 'video'
        ? '视频'
        : type == 'article'
        ? '文章'
        : '音频';
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      onTap: () => _goToResources(type),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 20.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: typeColor.withValues(alpha: brightness == Brightness.dark ? 0.08 : 0.05),
          border: Border.all(
            color: typeColor.withValues(alpha: brightness == Brightness.dark ? 0.15 : 0.1),
            width: 1,
          ),
          // 虚线边框效果用 dashed 模拟
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: typeColor.withValues(alpha: brightness == Brightness.dark ? 0.12 : 0.08),
              ),
              child: Icon(
                icon,
                size: 26.sp,
                color: typeColor.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              '暂无$typeName',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '点击添加$typeName资源',
              style: TextStyle(
                fontSize: 12.5.sp,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
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
            child: FolderCard(
              folder: folder,
              onTap: () => _openFolder(folder),
              onLongPress: () {},
            ),
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

class _GridStatItem {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final List<Color> gradient;
  final double bgAlpha;

  const _GridStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.gradient,
    required this.bgAlpha,
  });
}
