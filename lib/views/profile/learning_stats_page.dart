/// 学习统计详情页面
///
/// 显示详细的学习数据统计，支持按类别切换查看。
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/theme/theme.dart';

enum _StatsTab { overview, video, audio, article }

class LearningStatsPage extends StatefulWidget {
  const LearningStatsPage({super.key});

  @override
  State<LearningStatsPage> createState() => _LearningStatsPageState();
}

class _LearningStatsPageState extends State<LearningStatsPage> {
  _StatsTab _currentTab = _StatsTab.overview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '学习统计',
          style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface),
        ),
      ),
      body: Column(
        children: [
          // Tab 切换
          _buildTabBar(colorScheme),
          // 内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _buildTabContent(colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _tabButton('总览', _StatsTab.overview, colorScheme),
          _tabButton('视频', _StatsTab.video, colorScheme),
          _tabButton('音频', _StatsTab.audio, colorScheme),
          _tabButton('文章', _StatsTab.article, colorScheme),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _StatsTab tab, ColorScheme colorScheme) {
    final isActive = _currentTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.onPrimary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ColorScheme colorScheme) {
    switch (_currentTab) {
      case _StatsTab.overview:
        return _buildOverview(colorScheme);
      case _StatsTab.video:
        return _buildPlaceholder('视频学习', Icons.video_library, colorScheme);
      case _StatsTab.audio:
        return _buildPlaceholder('音频学习', Icons.music_note, colorScheme);
      case _StatsTab.article:
        return _buildPlaceholder('文章学习', Icons.article, colorScheme);
    }
  }

  Widget _buildOverview(ColorScheme colorScheme) {
    return Column(
      children: [
        SizedBox(height: 16),
        // 总览统计卡片
        Row(
          children: [
            _statBox('学习天数', '0', Icons.calendar_today, colorScheme),
            SizedBox(width: 10),
            _statBox('总时长', '0h', Icons.timer, colorScheme),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            _statBox('视频数', '0', Icons.video_library, colorScheme),
            SizedBox(width: 10),
            _statBox('音频数', '0', Icons.music_note, colorScheme),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            _statBox('文章数', '0', Icons.article, colorScheme),
            SizedBox(width: 10),
            _statBox('生词数', '0', Icons.book, colorScheme),
          ],
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, IconData icon, ColorScheme colorScheme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppColors.surfaceElevated,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: colorScheme.primary.withValues(alpha: 0.7)),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title, IconData icon, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '暂无学习数据',
              style: TextStyle(
                fontSize: 14.sp,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
