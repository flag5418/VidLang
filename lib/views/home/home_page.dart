/// 首页 v8.0 — 全面优化
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/device_type_provider.dart';
import 'package:vidlang/providers/file_provider.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/learning_stats_service.dart';
import 'package:vidlang/services/stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/article/article_reader_page.dart';
import 'package:vidlang/views/audio_player/audio_player_page.dart';
import 'package:vidlang/views/growth/learning_history_page.dart';
import 'package:vidlang/views/player/player_page.dart';
import 'package:vidlang/utils/adaptive.dart';

class HomePage extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToTab;
  
  const HomePage({super.key, this.onNavigateToTab});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Map<String, List<VideoFolder>> _recentFolders = {};
  HomeStats _stats = const HomeStats();
  bool _loading = true;
  List<RecentResource> _recentResources = [];
  int _lastRefreshTick = 0; // 用于避免重复刷新

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次依赖变化（如从其他 Tab 切回首页）时检查是否需要刷新
    final currentIndex = ref.read(navigationIndexProvider);
    if (currentIndex == 0) {
      _refreshIfNeeded();
    }
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget 更新时也触发刷新检查
    _refreshIfNeeded();
  }

  /// 智能刷新：防止短时间内重复刷新（防抖）
  void _refreshIfNeeded() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRefreshTick < 2000) return; // 2秒内不重复刷新
    _lastRefreshTick = now;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        StatsService.getAllRecentFolders(),
        StatsService.getHomeStats(),
        LearningStatsService.instance.getRecentResources(limit: 5),
      ]);
      if (!mounted) return;
      setState(() {
        _recentFolders = results[0] as Map<String, List<VideoFolder>>;
        _stats = results[1] as HomeStats;
        _recentResources = results[2] as List<RecentResource>;
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
    // 使用回调触发页面跳转
    widget.onNavigateToTab?.call();
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
      }
    } catch (_) {}
  }

  AppDeviceType get _deviceType => ref.read(deviceTypeProvider);
  bool get _isIpad => _deviceType.isTablet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final surfaceColor = AppColors.getSurface(brightness: brightness);

    if (_isIpad) {
      return Scaffold(
        backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
        body: _buildIpadBody(colorScheme, brightness, surfaceColor),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildIphoneBody(colorScheme, brightness, surfaceColor),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // iPhone 布局
  // ═══════════════════════════════════════════════════════════════

  Widget _buildIphoneBody(
    ColorScheme colorScheme,
    Brightness brightness,
    Color surfaceColor,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Adaptive.w(context, 16), Adaptive.h(context, 16), Adaptive.w(context, 16), 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 品牌 + 学习统计（固定区域）
          _buildBrandStatsCard(colorScheme, brightness, surfaceColor),
          SizedBox(height: Adaptive.h(context, 14)),
          // 资源中心（固定区域）
          _buildResourceSection(colorScheme, brightness, surfaceColor),
          SizedBox(height: Adaptive.h(context, 14)),
          // 最近学习标题 + 查看更多（固定区域）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.only(left: Adaptive.w(context, 4)),
                child: Text(
                  '最近学习',
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 16),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LearningHistoryPage()),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '查看更多',
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, 13),
                        color: colorScheme.primary,
                      ),
                    ),
                    Icon(
                      AppIcons.chevronRight,
                      size: Adaptive.sp(context, 16),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Adaptive.h(context, 10)),
          // 最近学习列表（可滚动区域，占据剩余空间）
          Expanded(
            child: _buildRecentList(colorScheme, brightness, surfaceColor),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 品牌 + 学习统计（合并卡片）
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBrandStatsCard(
    ColorScheme colorScheme,
    Brightness brightness,
    Color surfaceColor,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部品牌区
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                // 大图标
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    AppIcons.schoolFill,
                    color: Colors.white,
                    size: Adaptive.sp(context, 30),
                  ),
                ),
                const SizedBox(width: 16),
                // 标题 + 副标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VidLang',
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 24),
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '看视频、听音乐、读文章，轻松学英语',
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 13),
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 底部统计区（白色背景）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                _buildStatItem(
                  icon: AppIcons.localFireDepartment,
                  value: '${_stats.streakDays}',
                  label: '连续',
                  color: const Color(0xFFFF6B35),
                  colorScheme: colorScheme,
                ),
                _buildStatDivider(colorScheme),
                _buildStatItem(
                  icon: AppIcons.apps,
                  value: '${_stats.resourceCount}',
                  label: '资源',
                  color: colorScheme.primary,
                  colorScheme: colorScheme,
                ),
                _buildStatDivider(colorScheme),
                _buildStatItem(
                  icon: AppIcons.menuBook,
                  value: '${_stats.wordCount}',
                  label: '单词',
                  color: const Color(0xFF22C55E),
                  colorScheme: colorScheme,
                ),
                _buildStatDivider(colorScheme),
                _buildStatItem(
                  icon: AppIcons.schedule,
                  value: _formatDurationCompact(_stats.todayDuration),
                  label: '时长',
                  color: const Color(0xFFA855F7),
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Adaptive.sp(context, 18), color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: Adaptive.sp(context, 15),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: Adaptive.sp(context, 11),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      height: 32,
      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }

  String _formatDurationCompact(int seconds) {
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${seconds ~/ 60}分';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return m > 0 ? '$h.$m时' : '$h时';
  }

  // ═══════════════════════════════════════════════════════════════
  // 资源中心
  // ═══════════════════════════════════════════════════════════════

  Widget _buildResourceSection(
    ColorScheme colorScheme,
    Brightness brightness,
    Color surfaceColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: Adaptive.w(context, 4)),
          child: Text(
            '资源中心',
            style: TextStyle(
              fontSize: Adaptive.sp(context, 16),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 三行横排卡片
        _buildResourceRow(
          type: 'video',
          title: '视频',
          icon: AppIcons.movie,
          color: AppColors.videoColor,
          colorScheme: colorScheme,
          surfaceColor: surfaceColor,
        ),
        const SizedBox(height: 8),
        _buildResourceRow(
          type: 'music',
          title: '音频',
          icon: AppIcons.musicNote,
          color: AppColors.audioColor,
          colorScheme: colorScheme,
          surfaceColor: surfaceColor,
        ),
        const SizedBox(height: 8),
        _buildResourceRow(
          type: 'article',
          title: '文章',
          icon: AppIcons.menuBook,
          color: AppColors.articleColor,
          colorScheme: colorScheme,
          surfaceColor: surfaceColor,
        ),
      ],
    );
  }

  Widget _buildResourceRow({
    required String type,
    required String title,
    required IconData icon,
    required Color color,
    required ColorScheme colorScheme,
    required Color surfaceColor,
  }) {
    final folders = _recentFolders[type] ?? [];
    final recentFolder = folders.isNotEmpty ? folders.first : null;
    final count = folders.fold<int>(0, (sum, f) => sum + f.videoCount);
    final hasFolders = folders.isNotEmpty;

    return GestureDetector(
      onTap: () => _goToResources(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: Adaptive.sp(context, 20), color: color),
            ),
            const SizedBox(width: 12),
            // 中间内容区
            Expanded(
              child: hasFolders
                  ? _buildResourceContent(
                      recentFolder: recentFolder,
                      colorScheme: colorScheme,
                    )
                  : _buildResourceEmpty(
                      title: title,
                      colorScheme: colorScheme,
                    ),
            ),
            // 右侧：数量 + 箭头
            if (hasFolders) ...[
              Text(
                '$count个',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 12),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              AppIcons.chevronRight,
              size: Adaptive.sp(context, 18),
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // 有资源时显示的内容
  Widget _buildResourceContent({
    required VideoFolder? recentFolder,
    required ColorScheme colorScheme,
  }) {
    if (recentFolder == null) {
      return Text(
        '暂无内容',
        style: TextStyle(
          fontSize: Adaptive.sp(context, 14),
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 文件夹名称
        Text(
          recentFolder.name,
          style: TextStyle(
            fontSize: Adaptive.sp(context, 14),
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: Adaptive.h(context, 2)),
        // 最后播放的资源名称
        FutureBuilder<String>(
          future: _getLastPlayTitleAsync(recentFolder),
          builder: (context, snapshot) {
            final t = snapshot.data ?? '暂无播放记录';
            return Text(
              t,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 11),
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
      ],
    );
  }

  // 没有资源时显示的内容
  Widget _buildResourceEmpty({
    required String title,
    required ColorScheme colorScheme,
  }) {
    return Text(
      '暂无$title资源，点击管理',
      style: TextStyle(
        fontSize: Adaptive.sp(context, 13),
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  Future<String> _getLastPlayTitleAsync(VideoFolder folder) async {
    if (folder.lastVideoCode == null || folder.lastVideoCode!.isEmpty) {
      return '暂无播放记录';
    }
    try {
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'code = ? AND is_deleted = 0',
        whereArgs: [folder.lastVideoCode],
        limit: 1,
      );
      if (videos.isNotEmpty) {
        return videos.first.name.isNotEmpty ? videos.first.name : '上次播放';
      }
    } catch (_) {}
    return '上次播放';
  }

  // ═══════════════════════════════════════════════════════════════
  // 最近学习列表（可滚动）
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRecentList(
    ColorScheme colorScheme,
    Brightness brightness,
    Color surfaceColor,
  ) {
    if (_recentResources.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 24)),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.historyToggleOff,
              size: Adaptive.sp(context, 32),
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            SizedBox(height: Adaptive.h(context, 6)),
            Text(
              '暂无学习记录',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 13),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _recentResources.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: Adaptive.h(context, 8)),
          child: _buildRecentItem(
            _recentResources[index],
            colorScheme,
            brightness,
            surfaceColor,
          ),
        );
      },
    );
  }

  Widget _buildRecentItem(
    RecentResource resource,
    ColorScheme colorScheme,
    Brightness brightness,
    Color surfaceColor,
  ) {
    final typeColor = AppColors.colorForType(
      resource.resourceType,
      brightness: brightness,
    );
    final icon = _iconForType(resource.resourceType);
    final timeAgo = _getTimeAgo(resource.lastStudiedAt);

    return GestureDetector(
      onTap: () => _openRecentResource(resource),
      child: Container(
        padding: EdgeInsets.all(Adaptive.w(context, 12)),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：图标 + 标题 + 时间
            Row(
              children: [
                Icon(icon, size: Adaptive.sp(context, 18), color: typeColor),
                SizedBox(width: Adaptive.w(context, 8)),
                Expanded(
                  child: Text(
                    _getResourceTitle(resource),
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 14),
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 11),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            SizedBox(height: Adaptive.h(context, 8)),
            // 第二行：详细信息
            _buildResourceDetail(resource, typeColor, colorScheme),
            SizedBox(height: Adaptive.h(context, 8)),
            // 第三行：进度条
            _buildProgressBar(resource, typeColor, colorScheme),
          ],
        ),
      ),
    );
  }

  // 资源详细信息（时长/段落等）
  Widget _buildResourceDetail(
    RecentResource resource,
    Color typeColor,
    ColorScheme colorScheme,
  ) {
    if (resource.resourceType == 'article') {
      return _buildArticleDetail(resource, colorScheme);
    } else {
      return _buildVideoDetail(resource, colorScheme);
    }
  }

  // 视频/音频详情
  Widget _buildVideoDetail(RecentResource resource, ColorScheme colorScheme) {
    return FutureBuilder<VideoInfo?>(
      future: _loadVideoInfo(resource.resourceCode),
      builder: (context, snapshot) {
        final video = snapshot.data;
        if (video == null) return const SizedBox.shrink();

        final currentPos = video.currentPosition > 0
            ? _formatDuration(video.currentPosition ~/ 1000)
            : '0:00';
        final totalDur = video.duration > 0
            ? _formatDuration(video.duration ~/ 1000)
            : '0:00';

        return Row(
          children: [
            Icon(
              AppIcons.playCircleOutline,
              size: Adaptive.sp(context, 14),
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: Adaptive.w(context, 4)),
            Text(
              '$currentPos / $totalDur',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 11),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  // 文章详情
  Widget _buildArticleDetail(RecentResource resource, ColorScheme colorScheme) {
    return FutureBuilder<Article?>(
      future: _loadArticleInfo(resource.resourceCode),
      builder: (context, snapshot) {
        final article = snapshot.data;
        if (article == null) return const SizedBox.shrink();

        return Row(
          children: [
            // 段落信息
            Icon(
              AppIcons.formatListNumbered,
              size: Adaptive.sp(context, 14),
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: Adaptive.w(context, 4)),
            Text(
              '${article.lastParagraphIndex}/${article.totalParagraphs}段',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 11),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: Adaptive.w(context, 12)),
            // 字数信息
            Icon(
              AppIcons.textFields,
              size: Adaptive.sp(context, 14),
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: Adaptive.w(context, 4)),
            Text(
              '${article.wordCount}字',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 11),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressBar(
    RecentResource resource,
    Color typeColor,
    ColorScheme colorScheme,
  ) {
    return FutureBuilder<double>(
      future: _getProgress(resource),
      builder: (context, snapshot) {
        final progress = snapshot.data ?? 0.0;
        final percentage = (progress * 100).toInt();
        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 4,
                  backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0 ? typeColor : colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            SizedBox(width: Adaptive.w(context, 8)),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 11),
                fontWeight: FontWeight.w600,
                color: typeColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Article?> _loadArticleInfo(String code) async {
    try {
      final articles = await DatabaseService.findByCondition(
        () => Article(),
        where: 'code = ? AND is_deleted = 0',
        whereArgs: [code],
        limit: 1,
      );
      return articles.isNotEmpty ? articles.first : null;
    } catch (_) {
      return null;
    }
  }

  Future<VideoInfo?> _loadVideoInfo(String code) async {
    try {
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'code = ? AND is_deleted = 0',
        whereArgs: [code],
        limit: 1,
      );
      return videos.isNotEmpty ? videos.first : null;
    } catch (_) {
      return null;
    }
  }

  Future<double> _getProgress(RecentResource resource) async {
    try {
      if (resource.resourceType == 'article') {
        final article = await _loadArticleInfo(resource.resourceCode);
        if (article != null && article.totalParagraphs > 0) {
          return (article.lastParagraphIndex / article.totalParagraphs)
              .clamp(0.0, 1.0);
        }
      } else {
        final video = await _loadVideoInfo(resource.resourceCode);
        if (video != null && video.duration > 0) {
          return (video.currentPosition / video.duration).clamp(0.0, 1.0);
        }
      }
    } catch (_) {}
    return 0.0;
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'article':
        return AppIcons.menuBook;
      case 'music':
        return AppIcons.musicNote;
      default:
        return AppIcons.movie;
    }
  }

  String _getResourceTitle(RecentResource resource) {
    if (resource.folderCode != null && resource.folderCode!.isNotEmpty) {
      final folders = _recentFolders[resource.resourceType] ?? [];
      final folder = folders.where((f) => f.code == resource.folderCode).firstOrNull;
      if (folder != null) {
        return folder.name;
      }
    }
    final shortCode = resource.resourceCode.length > 8
        ? resource.resourceCode.substring(0, 8)
        : resource.resourceCode;
    return '资源 $shortCode';
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dateTime.month}/${dateTime.day}';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${seconds ~/ 60}分钟';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return m > 0 ? '$h小时$m分' : '$h小时';
  }

  Future<void> _openRecentResource(RecentResource resource) async {
    if (resource.folderCode == null || resource.folderCode!.isEmpty) return;
    final folders = _recentFolders[resource.resourceType] ?? [];
    final folder = folders.where((f) => f.code == resource.folderCode).firstOrNull;
    if (folder == null) return;
    await _openFolder(folder);
  }

  // ═══════════════════════════════════════════════════════════════
  // iPad 布局
  // ═══════════════════════════════════════════════════════════════

  Widget _buildIpadBody(
    ColorScheme colorScheme,
    Brightness brightness,
    Color surfaceColor,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // iPad 使用与 iPhone 相同的单列布局，只是间距更大
    return Padding(
      padding: EdgeInsets.fromLTRB(Adaptive.w(context, 24), Adaptive.h(context, 24), Adaptive.w(context, 24), 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 品牌 + 学习统计（固定区域）
          _buildBrandStatsCard(colorScheme, brightness, surfaceColor),
          SizedBox(height: Adaptive.h(context, 20)),
          // 资源中心（固定区域）
          _buildResourceSection(colorScheme, brightness, surfaceColor),
          SizedBox(height: Adaptive.h(context, 20)),
          // 最近学习标题 + 查看更多（固定区域）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: EdgeInsets.only(left: Adaptive.w(context, 4)),
                child: Text(
                  '最近学习',
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 18),
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LearningHistoryPage()),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '查看更多',
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, 14),
                        color: colorScheme.primary,
                      ),
                    ),
                    Icon(
                      AppIcons.chevronRight,
                      size: Adaptive.sp(context, 18),
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Adaptive.h(context, 12)),
          // 最近学习列表（可滚动区域，占据剩余空间）
          Expanded(
            child: _buildRecentList(colorScheme, brightness, surfaceColor),
          ),
        ],
      ),
    );
  }
}
