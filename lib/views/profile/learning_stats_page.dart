/// 学习统计详情页面
///
/// 单页面可滚动布局，自上而下 5 个区域：
/// 1. 荣誉墙（8 个徽章横向滚动）
/// 2. 总览数据区（4 项卡片 2×2）
/// 3. 分类详情区（视频/音频/文章各一张卡片）
/// 4. 学习趋势区（近 7 天简易柱状图）
/// 5. AI 学习建议区（占位）
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/services/stats_service.dart';
import 'package:vidlang/theme/theme.dart';

// ─── 荣誉徽章定义 ───
class _BadgeDef {
  final String name;
  final IconData icon;
  final String description;
  final String condition;
  const _BadgeDef(this.name, this.icon, this.description, this.condition);
}

const List<_BadgeDef> _badges = [
  _BadgeDef('初次学习', Icons.play_circle_outline, '完成第一次学习', '完成任意资源的学习记录'),
  _BadgeDef('连续7天', Icons.local_fire_department, '连续学习 7 天', '连续 7 天都有学习记录'),
  _BadgeDef('学习达人', Icons.emoji_events, '累计学习 30 天', '累计学习天数达到 30 天'),
  _BadgeDef('百时战士', Icons.shield, '累计学习 100 小时', '总学习时长超过 100 小时'),
  _BadgeDef('全栈学者', Icons.language, '三类资源各学完 5 个', '视频、音频、文章各完成 5 个资源'),
  _BadgeDef('词库达人', Icons.book, '收藏 100 个单词', '单词本收藏数量达到 100 个'),
  _BadgeDef('完播王者', Icons.check_circle, '完整播放 50 次', '完整播放次数累计达到 50 次'),
  _BadgeDef('自我超越', Icons.trending_up, '综合评分达到 80', '综合评分达到 80 分'),
];

class LearningStatsPage extends StatefulWidget {
  const LearningStatsPage({super.key});

  @override
  State<LearningStatsPage> createState() => _LearningStatsPageState();
}

class _LearningStatsPageState extends State<LearningStatsPage> {
  DetailOverview? _overview;
  List<TypeStats> _typeStats = [];
  List<DailyTrend> _weeklyTrend = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([StatsService.getDetailOverview(), StatsService.getDetailByType(), StatsService.getWeeklyTrend()]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as DetailOverview;
        _typeStats = results[1] as List<TypeStats>;
        _weeklyTrend = results[2] as List<DailyTrend>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

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
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.md.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHonorWall(colorScheme),
                  SizedBox(height: 24.h),
                  _buildOverview(colorScheme),
                  SizedBox(height: 24.h),
                  _buildCategoryDetails(colorScheme),
                  SizedBox(height: 24.h),
                  _buildWeeklyTrend(colorScheme),
                  SizedBox(height: 24.h),
                  _buildAiSuggestion(colorScheme),
                  SizedBox(height: 32.h),
                ],
              ),
            ),
    );
  }

  // ─── 区域 1: 荣誉墙 ───

  Widget _buildHonorWall(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('荣誉墙', Icons.emoji_events, colorScheme),
        SizedBox(height: 12.h),
        SizedBox(
          height: 100.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _badges.length,
            separatorBuilder: (_, _) => SizedBox(width: 16.w),
            itemBuilder: (context, index) {
              final badge = _badges[index];
              return _badgeItem(badge, colorScheme);
            },
          ),
        ),
      ],
    );
  }

  Widget _badgeItem(_BadgeDef badge, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _showBadgeDetail(badge),
      child: SizedBox(
        width: 72.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(badge.icon, size: 26.sp, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
            SizedBox(height: 6.h),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(_BadgeDef badge) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, MediaQuery.of(context).padding.bottom + 24.h),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 24.h),
                decoration: BoxDecoration(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2.r)),
              ),
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surface,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2), width: 1),
                ),
                child: Icon(badge.icon, size: 30.sp, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              ),
              SizedBox(height: 16.h),
              Text(
                badge.name,
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              SizedBox(height: 8.h),
              Text(
                badge.description,
                style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: 24.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16.sp, color: colorScheme.onSurfaceVariant),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '解锁条件：${badge.condition}',
                        style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                '尚未解锁',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 区域 2: 总览数据区 ───

  Widget _buildOverview(ColorScheme colorScheme) {
    final ov = _overview;
    if (ov == null) return const SizedBox.shrink();

    final hours = ov.totalDurationSeconds ~/ 3600;
    final minutes = (ov.totalDurationSeconds % 3600) ~/ 60;
    final durationText = ov.totalDurationSeconds >= 3600 ? '$hours小时$minutes分钟' : '$minutes分钟';

    final String gradeLabel;
    final Color gradeColor;
    if (ov.compositeScore >= 80) {
      gradeLabel = '优秀';
      gradeColor = const Color(0xFF30D158);
    } else if (ov.compositeScore >= 60) {
      gradeLabel = '良好';
      gradeColor = const Color(0xFFFFCC00);
    } else if (ov.compositeScore >= 30) {
      gradeLabel = '入门';
      gradeColor = const Color(0xFFFF8E53);
    } else {
      gradeLabel = '新手';
      gradeColor = colorScheme.onSurfaceVariant;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('总览数据', Icons.dashboard, colorScheme),
        SizedBox(height: 12.h),
        Row(
          children: [
            _overviewCard('累计学习天数', '${ov.totalDays}', '天', Icons.calendar_today, colorScheme),
            SizedBox(width: 10.w),
            _overviewCard('总学习时长', durationText, '', Icons.timer, colorScheme),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            _overviewCard('已学资源数', '${ov.learnedResources}', '个', Icons.play_circle_outline, colorScheme),
            SizedBox(width: 10.w),
            _overviewCard('综合评分', ov.compositeScore.toStringAsFixed(0), gradeLabel, Icons.auto_awesome, colorScheme, valueColor: gradeColor),
          ],
        ),
      ],
    );
  }

  Widget _overviewCard(String label, String value, String suffix, IconData icon, ColorScheme colorScheme, {Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          color: colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 20.w, color: colorScheme.primary),
            ),
            SizedBox(height: 16.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold, color: valueColor ?? colorScheme.onSurface, height: 1.1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (suffix.isNotEmpty) ...[
                  SizedBox(width: 4.w),
                  Padding(
                    padding: EdgeInsets.only(bottom: 2.h),
                    child: Text(
                      suffix,
                      style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 区域 3: 分类详情区 ───

  Widget _buildCategoryDetails(ColorScheme colorScheme) {
    if (_typeStats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('分类详情', Icons.category, colorScheme),
        SizedBox(height: 12.h),
        ..._typeStats.map(
          (ts) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: _typeCard(ts, colorScheme),
          ),
        ),
      ],
    );
  }

  Widget _typeCard(TypeStats ts, ColorScheme colorScheme) {
    final progress = ts.total > 0 ? (ts.learned / ts.total).clamp(0.0, 1.0) : 0.0;
    final durationHours = ts.totalDurationSeconds ~/ 3600;
    final durationMins = (ts.totalDurationSeconds % 3600) ~/ 60;
    final durationText = ts.totalDurationSeconds >= 3600 ? '$durationHours小时$durationMins分钟' : '$durationMins分钟';

    final iconData = ts.icon == 'video_library'
        ? Icons.video_library_rounded
        : ts.icon == 'music_note'
        ? Icons.music_note_rounded
        : Icons.article_rounded;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        color: colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10.r)),
                child: Icon(iconData, size: 20.w, color: colorScheme.primary),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ts.label,
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '已完成 ${ts.learned} / 共 ${ts.total}',
                      style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6.h,
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              _typeStatChip(Icons.timer_outlined, durationText, colorScheme),
              SizedBox(width: 16.w),
              _typeStatChip(Icons.access_time_rounded, ts.lastStudyTime != null ? _formatTimeAgo(ts.lastStudyTime!) : '暂无', colorScheme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeStatChip(IconData icon, String text, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14.sp, color: colorScheme.onSurfaceVariant),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// 友好时间格式：x天前 / x小时前 / 今天
  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '刚刚';
      }
      return '${diff.inHours}小时前';
    }
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${diff.inDays ~/ 30}个月前';
  }

  // ─── 区域 4: 学习趋势区 ───

  Widget _buildWeeklyTrend(ColorScheme colorScheme) {
    if (_weeklyTrend.isEmpty) return const SizedBox.shrink();

    // 计算最大值用于柱状图比例
    final maxMinutes = _weeklyTrend.fold<int>(0, (m, t) => t.minutes > m ? t.minutes : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('学习趋势（近7天）', Icons.show_chart_rounded, colorScheme),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            color: colorScheme.surface,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Column(
            children: [
              // 柱状图
              SizedBox(
                height: 140.h, // 增加高度容纳文字和柱子
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _weeklyTrend.map((t) {
                    final ratio = maxMinutes > 0 ? t.minutes / maxMinutes : 0.0;
                    final barHeight = (80.h * ratio).clamp(4.h, 80.h); // 缩小柱子最大高度以留出空间
                    // 从日期中提取星期
                    final dateStr = t.date.substring(5); // MM-DD
                    final weekday = _getWeekdayLabel(t.date);

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (t.minutes > 0) ...[
                              Text(
                                '${t.minutes}',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorScheme.primary),
                              ),
                              SizedBox(height: 4.h),
                            ],
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(4.r)),
                                gradient: t.minutes > 0
                                    ? LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [colorScheme.primary.withValues(alpha: 0.6), colorScheme.primary],
                                      )
                                    : null,
                                color: t.minutes > 0 ? null : colorScheme.outlineVariant.withValues(alpha: 0.2),
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(weekday, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                            SizedBox(height: 2.h),
                            Text(dateStr, style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 12.h),
              Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              SizedBox(height: 8.h),
              // 汇总行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '本周总计',
                    style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '${_weeklyTrend.fold<int>(0, (s, t) => s + t.minutes)} 分钟',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getWeekdayLabel(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[dt.weekday - 1];
  }

  // ─── AI 学习建议区 ───

  Widget _buildAiSuggestion(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('AI 学习建议', Icons.psychology_rounded, colorScheme),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            color: colorScheme.surface,
            boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15), width: 1),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: Icon(Icons.auto_awesome_rounded, size: 28.sp, color: colorScheme.primary),
              ),
              SizedBox(height: 16.h),
              Text(
                '更多学习数据累积后，AI 将为你生成个性化学习建议',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9), height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 通用组件 ───

  Widget _sectionTitle(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 18.sp, color: colorScheme.primary),
        SizedBox(width: 6.w),
        Text(
          title,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
      ],
    );
  }
}
