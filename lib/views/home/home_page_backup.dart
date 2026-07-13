/// 首页 — VidLang 设计升级 v3.0
///
/// iPhone: 继续学习横幅 + 三列统计 + 分类Tab + 内容网格
/// iPad: 双栏布局，左侧入口，右侧内容面板

library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/file_provider.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
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
  int _selectedTabIndex = 0;

  // 继续学习
  VideoFolder? _continueFolder;

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

      final folders = results[0] as Map<String, List<VideoFolder>>;
      final stats = results[1] as HomeStats;

      VideoFolder? mostRecent;
      for (final typeFolders in folders.values) {
        for (final f in typeFolders) {
          if (f.lastPlayDate != null) {
            if (mostRecent == null ||
                f.lastPlayDate!.isAfter(mostRecent.lastPlayDate!)) {
              mostRecent = f;
            }
          }
        }
      }

      setState(() {
        _recentFolders = folders;
        _stats = stats;
        _continueFolder = mostRecent;
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
              builder: (_) => ArticleReaderPage(articleCode: target.code ?? ''),
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
                : PlayerPage(videoCode: firstVideo.code!, folderVideos: videos),
          ),
        );
        if (!mounted) return;
        await _loadData();
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final ipad = isIPad(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (ipad) {
      return _buildIpadLayout();
    }
    return _buildIphoneLayout();
  }

  // ═══════════════════════════════════════════════
  // iPhone 布局
  // ═══════════════════════════════════════════════

  Widget _buildIphoneLayout() {
    final colors = context.colors;
    final todayMin = _stats.todayDuration ~/ 60;

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildHeader(colors, todayMin),
                  const SizedBox(height: 24),
                  if (_continueFolder != null) ...[
                    _buildContinueBanner(colors),
                    const SizedBox(height: 24),
                  ],
                  _buildStatsRow(colors),
                  const SizedBox(height: 24),
                  _buildCategoryTabs(colors),
                  const SizedBox(height: 16),
                  _buildContentGrid(colors),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 标题行 ──
  Widget _buildHeader(AppColorsData colors, int todayMin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '你好，老板',
              style: context.textStyles.title.copyWith(
                color: colors.textPrimary,
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppIcons.search,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    AppIcons.person,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '今日学习 $todayMin 分钟',
          style: context.textStyles.body.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  // ── 继续学习横幅 ──
  Widget _buildContinueBanner(AppColorsData colors) {
    final folder = _continueFolder!;
    final hasProgress = folder.videoCount > 0;
    final progress = hasProgress
        ? (folder.completedCount / folder.videoCount).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).toInt();

    // 获取封面路径
    final cover = folder.cover;

    return GestureDetector(
      onTap: () => _openFolder(folder),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: cover != null && cover.isNotEmpty
              ? DecorationImage(
                  image: FileImage(File(cover)),
                  fit: BoxFit.cover,
                  onError: (_, _) {},
                )
              : null,
          color: cover == null || cover.isEmpty
              ? colors.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '继续学习',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                folder.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    AppIcons.playCircleFill,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '已播放 $progressPercent%',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1.5),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 三列统计 ──
  Widget _buildStatsRow(AppColorsData colors) {
    final todayMin = _stats.todayDuration ~/ 60;
    final streakDays = _stats.streakDays;
    final wordCount = _stats.wordCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学习概览',
          style: context.textStyles.heading.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCell('$streakDays', '连续', '学习', colors)),
            const SizedBox(width: 10),
            Expanded(child: _statCell('$todayMin', '分钟', '今日', colors)),
            const SizedBox(width: 10),
            Expanded(child: _statCell('$wordCount', '单词', '积累', colors)),
          ],
        ),
      ],
    );
  }

  Widget _statCell(
    String number,
    String label1,
    String label2,
    AppColorsData colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            number,
            style: context.textStyles.hero.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 2),
          Text(
            label1,
            style: context.textStyles.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
          Text(
            label2,
            style: context.textStyles.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 分类 Tab 栏 ──
  Widget _buildCategoryTabs(AppColorsData colors) {
    const tabs = ['视频', '文章', '音频'];
    final tabWidth =
        (MediaQuery.of(context).size.width - AppSpacing.pageH * 2) / 3;

    return Column(
      children: [
        Row(
          children: List.generate(tabs.length, (i) {
            final isSelected = _selectedTabIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = i),
              child: Container(
                width: tabWidth,
                height: 40,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      tabs[i],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 24 : 0,
                      height: 2,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Divider(height: 1, color: colors.border),
      ],
    );
  }

  // ── 内容网格 ──
  Widget _buildContentGrid(AppColorsData colors) {
    const tabTypes = ['video', 'article', 'music'];
    final type = tabTypes[_selectedTabIndex];
    final folders = _recentFolders[type] ?? [];

    if (folders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(AppIcons.folderOpen, size: 48, color: colors.textWeak),
              const SizedBox(height: 12),
              Text(
                '暂无内容',
                style: context.textStyles.body.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: folders.length,
      itemBuilder: (_, i) => _buildGridCard(folders[i], colors),
    );
  }

  Widget _buildGridCard(VideoFolder folder, AppColorsData colors) {
    final typeColor = AppColors.colorForType(
      folder.folderType == FolderContentType.music
          ? 'music'
          : folder.folderType == FolderContentType.article
          ? 'article'
          : 'video',
      brightness: Theme.of(context).brightness,
    );
    final cover = folder.cover;

    return GestureDetector(
      onTap: () => _openFolder(folder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border, width: 0.5),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: cover != null && cover.isNotEmpty
                    ? Image.file(
                        File(cover),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _gridPlaceholder(colors, typeColor, folder),
                      )
                    : _gridPlaceholder(colors, typeColor, folder),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 标题
          Text(
            folder.name,
            style: context.textStyles.body.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // 时长/数量
          Text(
            '${folder.videoCount} 个内容',
            style: context.textStyles.caption.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridPlaceholder(
    AppColorsData colors,
    Color typeColor,
    VideoFolder folder,
  ) {
    final icon = folder.folderType == FolderContentType.music
        ? AppIcons.musicNote
        : folder.folderType == FolderContentType.article
        ? AppIcons.menuBook
        : AppIcons.movie;
    return Container(
      color: typeColor.withValues(alpha: 0.08),
      child: Center(
        child: Icon(icon, size: 36, color: typeColor.withValues(alpha: 0.4)),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // iPad 布局
  // ═══════════════════════════════════════════════

  Widget _buildIpadLayout() {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final todayMin = _stats.todayDuration ~/ 60;
    final ctx = context;

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧栏
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: Adaptive.w(ctx, AppSpacing.pageHiPad),
                  vertical: Adaptive.h(ctx, 24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 品牌
                    Row(
                      children: [
                        Icon(
                          AppIcons.schoolFill,
                          size: Adaptive.sp(ctx, 36),
                          color: colors.primary,
                        ),
                        SizedBox(width: Adaptive.w(ctx, 12)),
                        Text(
                          'VidLang',
                          style: TextStyle(
                            fontSize: Adaptive.sp(ctx, 28),
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: Adaptive.h(ctx, 20)),
                    // 统计行
                    Text(
                      '今日学习 $todayMin 分钟',
                      style: textStyles.body.copyWith(
                        color: colors.textSecondary,
                        fontSize: Adaptive.sp(ctx, 15),
                      ),
                    ),
                    SizedBox(height: Adaptive.h(ctx, 24)),
                    // 继续学习
                    if (_continueFolder != null) ...[
                      _buildContinueBanner(colors),
                      SizedBox(height: Adaptive.h(ctx, 24)),
                    ],
                    // 三列统计
                    _buildStatsRow(colors),
                    SizedBox(height: Adaptive.h(ctx, 32)),
                    // 快速入口
                    _buildIpadQuickEntry('video', '视频', AppIcons.movie, colors),
                    SizedBox(height: Adaptive.h(ctx, 20)),
                    _buildIpadQuickEntry(
                      'music',
                      '音频',
                      AppIcons.musicNote,
                      colors,
                    ),
                    SizedBox(height: Adaptive.h(ctx, 20)),
                    _buildIpadQuickEntry(
                      'article',
                      '文章',
                      AppIcons.menuBook,
                      colors,
                    ),
                  ],
                ),
              ),
            ),
            // 分割线
            Container(width: 0.5, color: colors.border),
            // 右侧内容面板
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: Adaptive.w(ctx, AppSpacing.pageHiPad),
                  vertical: Adaptive.h(ctx, 24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryTabs(colors),
                    const SizedBox(height: 16),
                    _buildIpadContentGrid(colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpadQuickEntry(
    String type,
    String title,
    IconData icon,
    AppColorsData colors,
  ) {
    final folders = _recentFolders[type] ?? [];
    final typeColor = AppColors.colorForType(
      type,
      brightness: Theme.of(context).brightness,
    );
    final ctx = context;

    return GestureDetector(
      onTap: () => _goToResources(type),
      child: Container(
        padding: EdgeInsets.all(Adaptive.w(ctx, 16)),
        decoration: BoxDecoration(
          color: typeColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: typeColor.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: Adaptive.sp(ctx, 22), color: typeColor),
            SizedBox(width: Adaptive.w(ctx, 12)),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: Adaptive.sp(ctx, 16),
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Text(
              '${folders.length}',
              style: TextStyle(
                fontSize: Adaptive.sp(ctx, 14),
                color: colors.textSecondary,
              ),
            ),
            SizedBox(width: Adaptive.w(ctx, 4)),
            Icon(
              AppIcons.chevronRight,
              size: Adaptive.sp(ctx, 18),
              color: colors.textWeak,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpadContentGrid(AppColorsData colors) {
    const tabTypes = ['video', 'article', 'music'];
    final type = tabTypes[_selectedTabIndex];
    final folders = _recentFolders[type] ?? [];

    if (folders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(AppIcons.folderOpen, size: 48, color: colors.textWeak),
              const SizedBox(height: 12),
              Text(
                '暂无内容',
                style: context.textStyles.body.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: folders.length,
      itemBuilder: (_, i) => _buildGridCard(folders[i], colors),
    );
  }
}
