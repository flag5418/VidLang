/// 首页
///
/// 支持 iPhone/iPad 两套独立 UI 设计：
/// - iPhone: 单列布局，2列统计卡片，横向滚动文件夹
/// - iPad: 双列布局，左侧统计+资源概览，右侧推荐资源列表
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/components/folder_card.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/device_type_provider.dart';
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

  AppDeviceType get _deviceType => ref.read(deviceTypeProvider);
  bool get _isIpad => _deviceType.isTablet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    if (_isIpad) {
      return Scaffold(
        backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
        body: _buildIpadBody(colorScheme, brightness),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
      appBar: _buildIphoneAppBar(colorScheme),
      body: _buildIphoneBody(colorScheme, brightness),
    );
  }

  // ============================================================
  // iPhone 布局
  // ============================================================

  AppBar _buildIphoneAppBar(ColorScheme colorScheme) {
    return AppBar(
      title: Text(
        'VidLang',
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      elevation: 0,
      backgroundColor: AppColors.getSurfaceHighest(brightness: Theme.of(context).brightness),
      scrolledUnderElevation: 0.5,
    );
  }

  Widget _buildIphoneBody(ColorScheme colorScheme, Brightness brightness) {
    return RefreshIndicator(
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
                  _buildStatsSection(colorScheme, isIpad: false),
                  SizedBox(height: AppSpacing.lg),
                  _buildResourceSection(colorScheme, 'video', '视频', Icons.movie_outlined, isIpad: false),
                  SizedBox(height: AppSpacing.lg),
                  _buildResourceSection(colorScheme, 'music', '音频', Icons.music_note_outlined, isIpad: false),
                  SizedBox(height: AppSpacing.lg),
                  _buildResourceSection(colorScheme, 'article', '文章', Icons.menu_book_outlined, isIpad: false),
                  SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // iPad 布局 - 双栏
  // ============================================================

  Widget _buildIpadBody(ColorScheme colorScheme, Brightness brightness) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧栏：统计卡片 + 资源概览
          Expanded(
            flex: 4,
            child: _buildIpadLeftColumn(colorScheme, brightness),
          ),
          // 右侧栏：推荐资源列表
          Expanded(
            flex: 6,
            child: _buildIpadRightColumn(colorScheme, brightness),
          ),
        ],
      ),
    );
  }

  Widget _buildIpadLeftColumn(ColorScheme colorScheme, Brightness brightness) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 40.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 品牌区
          Row(
            children: [
              Icon(Icons.school_rounded, size: 36.w, color: colorScheme.primary),
              SizedBox(width: 12.w),
              Text(
                'VidLang',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 32.h),
          // 统计卡片 - 2x2 网格
          _buildStatsSection(colorScheme, isIpad: true),
          SizedBox(height: 32.h),
          // 资源快速入口
          _buildResourceSection(colorScheme, 'video', '视频', Icons.movie_outlined, isIpad: true),
          SizedBox(height: 24.h),
          _buildResourceSection(colorScheme, 'music', '音频', Icons.music_note_outlined, isIpad: true),
          SizedBox(height: 24.h),
          _buildResourceSection(colorScheme, 'article', '文章', Icons.menu_book_outlined, isIpad: true),
        ],
      ),
    );
  }

  Widget _buildIpadRightColumn(ColorScheme colorScheme, Brightness brightness) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.5),
        border: Border(left: BorderSide(color: colorScheme.outlineVariant, width: 1)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 40.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近访问',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 20.h),
            // 视频资源
            _buildIpadResourceGrid(colorScheme, 'video', '视频', Icons.movie_outlined, brightness),
            SizedBox(height: 24.h),
            // 音频资源
            _buildIpadResourceGrid(colorScheme, 'music', '音频', Icons.music_note_outlined, brightness),
            SizedBox(height: 24.h),
            // 文章资源
            _buildIpadResourceGrid(colorScheme, 'article', '文章', Icons.menu_book_outlined, brightness),
          ],
        ),
      ),
    );
  }

  Widget _buildIpadResourceGrid(ColorScheme colorScheme, String type, String title, IconData icon, Brightness brightness) {
    final folders = _recentFolders[type] ?? [];
    final typeColor = AppColors.colorForType(type, brightness: brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20.sp, color: typeColor),
            SizedBox(width: 8.w),
            Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _goToResources(type),
              child: Text('更多', style: TextStyle(fontSize: 14.sp, color: typeColor)),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (folders.isEmpty)
          _buildIpadEmptySection(colorScheme, icon, type, typeColor)
        else
          Wrap(
            spacing: 16.w,
            runSpacing: 16.w,
            children: folders.map((folder) {
              return SizedBox(
                width: 200.w,
                child: FolderCard(
                  folder: folder,
                  onTap: () => _openFolder(folder),
                  onLongPress: () {},
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildIpadEmptySection(ColorScheme colorScheme, IconData icon, String type, Color typeColor) {
    final brightness = Theme.of(context).brightness;
    final typeName = type == 'video' ? '视频' : type == 'article' ? '文章' : '音频';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: typeColor.withValues(alpha: brightness == Brightness.dark ? 0.08 : 0.05),
        border: Border.all(color: typeColor.withValues(alpha: brightness == Brightness.dark ? 0.15 : 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32.sp, color: typeColor.withValues(alpha: 0.5)),
          SizedBox(height: 12.h),
          Text(
            '暂无$typeName',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          SizedBox(height: 8.h),
          TextButton(
            onPressed: () => _goToResources(type),
            child: Text('点击添加', style: TextStyle(fontSize: 14.sp, color: typeColor)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 统计卡片（iPhone/iPad 共用）
  // ============================================================

  Widget _buildStatsSection(ColorScheme colorScheme, {required bool isIpad}) {
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

    final columns = isIpad ? 2 : 2;
    final spacing = isIpad ? 16.0.w : 10.w;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: isIpad ? 1.6 : 1.4,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _buildStatCard(stats[index], brightness, colorScheme, isIpad: isIpad),
    );
  }

  Widget _buildStatCard(_GridStatItem item, Brightness brightness, ColorScheme colorScheme, {required bool isIpad}) {
    final padding = isIpad ? 20.0.w : 14.w;
    final iconSize = isIpad ? 24.0.sp : 18.0.sp;
    final valueSize = isIpad ? 28.0.sp : 22.0.sp;
    final labelSize = isIpad ? 14.0.sp : 11.0.sp;

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
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isIpad ? 8.w : 6.w),
              decoration: BoxDecoration(
                color: item.gradient[0].withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(item.icon, size: iconSize, color: item.gradient[0]),
            ),
            SizedBox(height: isIpad ? 14.h : 10.h),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: item.value,
                    style: TextStyle(
                      fontSize: valueSize,
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
                        fontSize: isIpad ? 14.sp : 12.sp,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: isIpad ? 6.h : 4.h),
            Text(
              item.label,
              style: TextStyle(
                fontSize: labelSize,
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

  // ============================================================
  // 资源区块（iPhone 横向滚动 / iPad 共用 _buildResourceSection）
  // ============================================================

  Widget _buildResourceSection(
    ColorScheme colorScheme,
    String type,
    String title,
    IconData icon,
    {required bool isIpad}
  ) {
    final folders = _recentFolders[type] ?? [];
    final hasResources = folders.isNotEmpty;
    final brightness = Theme.of(context).brightness;
    final typeColor = AppColors.colorForType(type, brightness: brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                      Icon(Icons.chevron_right_rounded, size: 16.sp, color: typeColor),
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
    final typeName = type == 'video' ? '视频' : type == 'article' ? '文章' : '音频';
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
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: typeColor.withValues(alpha: brightness == Brightness.dark ? 0.12 : 0.08),
              ),
              child: Icon(icon, size: 26.sp, color: typeColor.withValues(alpha: 0.7)),
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
