/// Homepage - VidLang v4.3
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/stats_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_radius.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/views/article/article_reader_page.dart';
import 'package:vidlang/views/audio_player/audio_player_page.dart';
import 'package:vidlang/views/player/player_page.dart';

class _EntryData {
  final VideoFolder? folder;
  final String? cover;
  final String? playTitle;
  final int count;
  final String countLabel;
  final Color color;
  final IconData typeIcon;
  _EntryData({
    required this.folder,
    required this.cover,
    required this.playTitle,
    required this.count,
    required this.countLabel,
    required this.color,
    required this.typeIcon,
  });
}

class _LearningItem {
  final VideoFolder folder;
  final _ResourceDetail detail;
  _LearningItem({required this.folder, required this.detail});
}

class _ResourceDetail {
  final String? name;
  final int currentPosition;
  final int totalDuration;
  final double progress;
  final int totalParagraphs;
  final int wordCount;
  _ResourceDetail({
    this.name,
    this.currentPosition = 0,
    this.totalDuration = 0,
    this.progress = 0.0,
    this.totalParagraphs = 0,
    this.wordCount = 0,
  });
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  HomeStats _stats = const HomeStats();
  bool _loading = true;
  _EntryData? _videoEntry;
  _EntryData? _musicEntry;
  _EntryData? _articleEntry;
  List<_LearningItem> _recentLearningItems = [];

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
        StatsService.getRecentLearningFolders(limit: 8),
      ]);
      if (!mounted) return;
      final folders = results[0] as Map<String, List<VideoFolder>>;
      final stats = results[1] as HomeStats;
      final recentFolders = results[2] as List<VideoFolder>;
      _videoEntry = await _buildEntryData('video', folders['video']?.first, context.colors);
      _musicEntry = await _buildEntryData('music', folders['music']?.first, context.colors);
      _articleEntry = await _buildEntryData('article', folders['article']?.first, context.colors);
      _recentLearningItems = [];
      final Set<String> seenCodes = {};
      for (final folder in recentFolders) {
        if (folder.code == null || seenCodes.contains(folder.code)) continue;
        seenCodes.add(folder.code!);
        final detail = await _fetchResourceDetail(folder);
        _recentLearningItems.add(_LearningItem(folder: folder, detail: detail));
      }
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[HomePage] _loadData error: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<_EntryData?> _buildEntryData(String type, VideoFolder? folder, AppColorsData colors) async {
    if (folder == null) return null;
    String? cover;
    String? playTitle;
    final int count = folder.videoCount;
    if (type == 'video' || type == 'music') {
      final info = await _fetchLastVideo(folder.code);
      cover = info?.currentCover ?? folder.cover ?? info?.cover;
      playTitle = info?.name ?? folder.name;
    } else {
      final article = await _fetchLastArticle(folder.code);
      playTitle = article?.title ?? folder.name;
    }
    return _EntryData(
      folder: folder,
      cover: cover,
      playTitle: playTitle,
      count: count,
      countLabel: type == 'article' ? '篇' : '个',
      color: _typeColor(type, colors),
      typeIcon: _typeIcon(type),
    );
  }

  Color _typeColor(String type, AppColorsData colors) {
    switch (type) {
      case 'music':
        return colors.audioType;
      case 'article':
        return colors.articleType;
      default:
        return colors.videoType;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'music':
        return Icons.music_note;
      case 'article':
        return Icons.article_outlined;
      default:
        return Icons.movie_outlined;
    }
  }

  Future<VideoInfo?> _fetchLastVideo(String? folderCode) async {
    if (folderCode == null) return null;
    try {
      final items = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'folder_code = ? AND is_deleted = 0',
        whereArgs: [folderCode],
        orderBy: 'play_date DESC, order_index ASC',
      );
      if (items.isNotEmpty) {
        return items.firstWhere((v) => v.playDate != null, orElse: () => items.first);
      }
    } catch (_) {}
    return null;
  }

  Future<Article?> _fetchLastArticle(String? folderCode) async {
    if (folderCode == null) return null;
    try {
      final articles = await DatabaseService.findByCondition(
        () => Article(),
        where: 'folder_code = ? AND is_deleted = 0',
        whereArgs: [folderCode],
        orderBy: 'last_study_date DESC, updated_at DESC',
      );
      if (articles.isNotEmpty) {
        return articles.firstWhere((a) => a.lastStudyDate != null, orElse: () => articles.first);
      }
    } catch (_) {}
    return null;
  }

  Future<_ResourceDetail> _fetchResourceDetail(VideoFolder folder) async {
    final code = folder.code;
    if (code == null) return _ResourceDetail();
    if (folder.folderType == FolderContentType.article) {
      final article = await _fetchLastArticle(code);
      if (article != null) {
        return _ResourceDetail(
          name: article.title,
          progress: article.progress,
          totalParagraphs: article.totalParagraphs,
          wordCount: article.wordCount,
        );
      }
    } else {
      final video = await _fetchLastVideo(code);
      if (video != null) {
        return _ResourceDetail(
          name: video.name,
          currentPosition: video.currentPosition,
          totalDuration: video.duration > 0 ? video.duration : 1,
        );
      }
    }
    return _ResourceDetail(name: folder.name);
  }

  String _formatTimeMs(int ms) {
    if (ms <= 0) return '00:00';
    final totalSeconds = (ms / 1000).floor();
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final timeDay = DateTime(time.year, time.month, time.day);
    if (timeDay == yesterday) return '昨天';
    final days = today.difference(timeDay).inDays;
    if (days < 7) return '$days天前';
    return '${time.month}-${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                '加载中...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.md),
                _buildBrandCard(),
                const SizedBox(height: AppSpacing.lg),
                _buildTodayStats(),
                const SizedBox(height: AppSpacing.lg),
                _buildResourceEntries(),
                const SizedBox(height: AppSpacing.lg),
                _buildRecentLearning(),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Brand Card — 品牌卡片
  // ============================================================

  Widget _buildBrandCard() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary.withValues(alpha: 0.85),
              colors.primary.withValues(alpha: 0.65),
              colors.tertiary.withValues(alpha: 0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset('assets/app/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'VidLang',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '沉浸式语言学习平台',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Today Stats — 今日学习统计
  // ============================================================

  Widget _buildTodayStats() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日学习',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '连续',
                  '${_stats.streakDays}',
                  '天',
                  Icons.local_fire_department,
                  colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildStatCard(
                  '今日',
                  '${_stats.todayDuration ~/ 60}',
                  '分钟',
                  Icons.schedule,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildStatCard(
                  '单词',
                  '${_stats.wordCount}',
                  '个',
                  Icons.menu_book,
                  Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit, IconData icon, Color color) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Resource Entry Cards — 资源库入口
  // ============================================================

  Widget _buildResourceEntries() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '资源库',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildEntryCard(_videoEntry),
          const SizedBox(height: AppSpacing.md),
          _buildEntryCard(_musicEntry),
          const SizedBox(height: AppSpacing.md),
          _buildEntryCard(_articleEntry),
        ],
      ),
    );
  }

  Widget _buildEntryCard(_EntryData? data) {
    if (data == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _goToResources(data.folder),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: data.cover != null && data.cover!.isNotEmpty
                        ? (data.cover!.startsWith('/')
                            ? Image.file(
                                File(data.cover!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(data.typeIcon, color: data.color, size: 28),
                              )
                            : Image.asset(
                                data.cover!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(data.typeIcon, color: data.color, size: 28),
                              ))
                        : Icon(data.typeIcon, color: data.color, size: 28),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.playTitle ?? '未命名',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data.count}${data.countLabel}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToResources(VideoFolder? folder) {
    if (folder == null) return;
    final typeIndex = ['video', 'music', 'article'].indexOf(folder.folderType.name);
    if (typeIndex < 0) return;
    ref.read(resourceTabProvider.notifier).state = typeIndex;
    ref.read(navigationIndexProvider.notifier).setIndex(1);
  }

  // ============================================================
  // Recent Learning — 最近学习
  // ============================================================

  Widget _buildRecentLearning() {
    final colors = Theme.of(context).colorScheme;
    if (_recentLearningItems.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近学习',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._recentLearningItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildLearningCard(item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningCard(_LearningItem item) {
    final colors = Theme.of(context).colorScheme;
    final folder = item.folder;
    final detail = item.detail;
    final bool isArticle = folder.folderType == FolderContentType.article;
    final String displayTitle = detail.name ?? folder.name;
    final int totalDuration = detail.totalDuration;
    final int currentPosition = detail.currentPosition;
    final FolderContentType folderType = folder.folderType;
    final Color typeColor = _typeColor(
      folderType == FolderContentType.video
          ? 'video'
          : (folderType == FolderContentType.music ? 'music' : 'article'),
      context.colors,
    );
    final IconData typeIcon = _typeIcon(
      folderType == FolderContentType.video
          ? 'video'
          : (folderType == FolderContentType.music ? 'music' : 'article'),
    );

    final DateTime? lastActivity = folder.lastPlayDate;
    final double progress = isArticle
        ? detail.progress
        : (totalDuration > 0 ? currentPosition / totalDuration : 0.0);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _navigateToDetail(item),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(typeIcon, size: 20, color: typeColor),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (isArticle) ...[
                                Text(
                                  '阅读 ${detail.totalParagraphs}段',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  _formatTimeMs(currentPosition),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                Text(
                                  ' / ${_formatTimeMs(totalDuration)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (lastActivity != null) ...[
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: colors.onSurface.withValues(alpha: 0.4),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatRelativeTime(lastActivity),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: typeColor.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(typeColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(_LearningItem item) {
    final folder = item.folder;
    final code = folder.code;
    if (code == null) return;

    if (folder.folderType == FolderContentType.article) {
      _openArticleFolder(folder);
    } else if (folder.folderType == FolderContentType.music) {
      _openMediaFolder(folder, isMusic: true);
    } else {
      _openMediaFolder(folder, isMusic: false);
    }
  }

  Future<void> _openArticleFolder(VideoFolder folder) async {
    try {
      final articles = await DatabaseService.findByCondition(
        () => Article(),
        where: 'folder_code = ? AND is_deleted = 0',
        whereArgs: [folder.code],
        orderBy: 'last_study_date DESC, updated_at DESC',
      );
      if (articles.isNotEmpty && mounted) {
        final target = articles.firstWhere(
          (a) => a.lastStudyDate != null,
          orElse: () => articles.first,
        );
        if (target.code != null && target.code!.isNotEmpty) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArticleReaderPage(articleCode: target.code!),
            ),
          );
          if (mounted) await _loadData();
        }
      }
    } catch (e) {
      debugPrint('[HomePage] open article failed: $e');
    }
  }

  Future<void> _openMediaFolder(VideoFolder folder, {required bool isMusic}) async {
    try {
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'folder_code = ? AND is_deleted = 0',
        whereArgs: [folder.code],
        orderBy: 'order_index ASC, created_at ASC',
      );
      if (videos.isNotEmpty && mounted) {
        final firstVideo = videos.first;
        if (firstVideo.code != null && firstVideo.code!.isNotEmpty) {
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
          if (mounted) await _loadData();
        }
      }
    } catch (e) {
      debugPrint('[HomePage] open media failed: $e');
    }
  }
}
