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
import 'package:vidlang/services/stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

// ─── 荣誉徽章定义 ───
class _BadgeDef {
  final String name;
  final IconData icon;
  final String description;
  final String condition;
  const _BadgeDef(this.name, this.icon, this.description, this.condition);
}

const List<_BadgeDef> _badges = [
  _BadgeDef('初次学习', AppIcons.playCircleOutline, '完成第一次学习', '完成任意资源的学习记录'),
  _BadgeDef('连续7天', AppIcons.localFireDepartment, '连续学习 7 天', '连续 7 天都有学习记录'),
  _BadgeDef('学习达人', AppIcons.emojiEvents, '累计学习 30 天', '累计学习天数达到 30 天'),
  _BadgeDef('百时战士', AppIcons.shield, '累计学习 100 小时', '总学习时长超过 100 小时'),
  _BadgeDef('全栈学者', AppIcons.language, '三类资源各学完 5 个', '视频、音频、文章各完成 5 个资源'),
  _BadgeDef('词库达人', AppIcons.book, '收藏 100 个单词', '单词本收藏数量达到 100 个'),
  _BadgeDef('完播王者', AppIcons.checkCircle, '完整播放 50 次', '完整播放次数累计达到 50 次'),
  _BadgeDef('自我超越', AppIcons.trendingUp, '综合评分达到 80', '综合评分达到 80 分'),
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
  List<AiSuggestion> _aiSuggestions = [];
  bool _aiLoading = true;
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
      // 异步加载 AI 建议（不阻塞主界面）
      _loadAiSuggestions();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAiSuggestions() async {
    try {
      final suggestions = await StatsService.getAiLearningSuggestions();
      if (!mounted) return;
      setState(() {
        _aiSuggestions = suggestions;
        _aiLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
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
          icon: Icon(AppIcons.arrowBackIos, color: colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '学习统计',
          style: TextStyle(fontSize: Adaptive.sp(context, 17), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(Adaptive.w(context, AppSpacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHonorWall(colorScheme),
                  SizedBox(height: Adaptive.h(context, 24)),
                  _buildOverview(colorScheme),
                  SizedBox(height: Adaptive.h(context, 24)),
                  _buildCategoryDetails(colorScheme),
                  SizedBox(height: Adaptive.h(context, 24)),
                  _buildWeeklyTrend(colorScheme),
                  SizedBox(height: Adaptive.h(context, 24)),
                  _buildAiSuggestion(colorScheme),
                  SizedBox(height: Adaptive.h(context, 32)),
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
        _sectionTitle('荣誉墙', AppIcons.emojiEvents, colorScheme),
        SizedBox(height: Adaptive.h(context, 12)),
        SizedBox(
          height: Adaptive.h(context, 100),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _badges.length,
            separatorBuilder: (_, _) => SizedBox(width: Adaptive.w(context, 16)),
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
        width: Adaptive.w(context, 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: Adaptive.w(context, 56),
              height: Adaptive.w(context, 56),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface,
                boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(badge.icon, size: Adaptive.sp(context, 26), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
            SizedBox(height: Adaptive.h(context, 6)),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Adaptive.sp(context, 12), fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
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
          padding: EdgeInsets.fromLTRB(Adaptive.w(context, 24), Adaptive.h(context, 16), Adaptive.w(context, 24), MediaQuery.of(context).padding.bottom + Adaptive.h(context, 24)),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(Adaptive.r(context, 24))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: Adaptive.w(context, 40),
                height: Adaptive.h(context, 4),
                margin: EdgeInsets.only(bottom: Adaptive.h(context, 24)),
                decoration: BoxDecoration(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(Adaptive.r(context, 2))),
              ),
              Container(
                width: Adaptive.w(context, 64),
                height: Adaptive.w(context, 64),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surface,
                  boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2), width: 1),
                ),
                child: Icon(badge.icon, size: Adaptive.sp(context, 30), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              ),
              SizedBox(height: Adaptive.h(context, 16)),
              Text(
                badge.name,
                style: TextStyle(fontSize: Adaptive.sp(context, 20), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              SizedBox(height: Adaptive.h(context, 8)),
              Text(
                badge.description,
                style: TextStyle(fontSize: Adaptive.sp(context, 14), color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: Adaptive.h(context, 24)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 16), vertical: Adaptive.h(context, 12)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.info, size: Adaptive.sp(context, 16), color: colorScheme.onSurfaceVariant),
                    SizedBox(width: Adaptive.w(context, 8)),
                    Expanded(
                      child: Text(
                        '解锁条件：${badge.condition}',
                        style: TextStyle(fontSize: Adaptive.sp(context, 13), color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Adaptive.h(context, 16)),
              Text(
                '尚未解锁',
                style: TextStyle(fontSize: Adaptive.sp(context, 14), fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
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
        _sectionTitle('总览数据', AppIcons.dashboard, colorScheme),
        SizedBox(height: Adaptive.h(context, 12)),
        Row(
          children: [
            _overviewCard('累计学习天数', '${ov.totalDays}', '天', AppIcons.calendarToday, colorScheme),
            SizedBox(width: Adaptive.w(context, 10)),
            _overviewCard('总学习时长', durationText, '', AppIcons.timer, colorScheme),
          ],
        ),
        SizedBox(height: Adaptive.h(context, 10)),
        Row(
          children: [
            _overviewCard('已学资源数', '${ov.learnedResources}', '个', AppIcons.playCircleOutline, colorScheme),
            SizedBox(width: Adaptive.w(context, 10)),
            _overviewCard('综合评分', ov.compositeScore.toStringAsFixed(0), gradeLabel, AppIcons.autoAwesome, colorScheme, valueColor: gradeColor),
          ],
        ),
      ],
    );
  }

  Widget _overviewCard(String label, String value, String suffix, IconData icon, ColorScheme colorScheme, {Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(Adaptive.w(context, 16)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Adaptive.r(context, 14)),
          color: colorScheme.surface,
          boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(Adaptive.w(context, 8)),
              decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: Adaptive.w(context, 20), color: colorScheme.primary),
            ),
            SizedBox(height: Adaptive.h(context, 16)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: Adaptive.sp(context, 26), fontWeight: FontWeight.bold, color: valueColor ?? colorScheme.onSurface, height: 1.1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (suffix.isNotEmpty) ...[
                  SizedBox(width: Adaptive.w(context, 4)),
                  Padding(
                    padding: EdgeInsets.only(bottom: Adaptive.h(context, 2)),
                    child: Text(
                      suffix,
                      style: TextStyle(fontSize: Adaptive.sp(context, 13), color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: Adaptive.h(context, 6)),
            Text(
              label,
              style: TextStyle(fontSize: Adaptive.sp(context, 12), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
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
        _sectionTitle('分类详情', AppIcons.category, colorScheme),
        SizedBox(height: Adaptive.h(context, 12)),
        ..._typeStats.map(
          (ts) => Padding(
            padding: EdgeInsets.only(bottom: Adaptive.h(context, 10)),
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
        ? AppIcons.movie
        : ts.icon == 'music_note'
        ? AppIcons.musicNote
        : AppIcons.articleRound;

    return Container(
      padding: EdgeInsets.all(Adaptive.w(context, 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Adaptive.r(context, 14)),
        color: colorScheme.surface,
        boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(Adaptive.w(context, 8)),
                decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Adaptive.r(context, 10))),
                child: Icon(iconData, size: Adaptive.w(context, 20), color: colorScheme.primary),
              ),
              SizedBox(width: Adaptive.w(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ts.label,
                      style: TextStyle(fontSize: Adaptive.sp(context, 16), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    SizedBox(height: Adaptive.h(context, 2)),
                    Text(
                      '已完成 ${ts.learned} / 共 ${ts.total}',
                      style: TextStyle(fontSize: Adaptive.sp(context, 12), color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Adaptive.h(context, 16)),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(Adaptive.r(context, 4)),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: Adaptive.h(context, 6),
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
          SizedBox(height: Adaptive.h(context, 16)),
          Row(
            children: [
              _typeStatChip(AppIcons.timer, durationText, colorScheme),
              SizedBox(width: Adaptive.w(context, 16)),
              _typeStatChip(AppIcons.accessTime, ts.lastStudyTime != null ? _formatTimeAgo(ts.lastStudyTime!) : '暂无', colorScheme),
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
        Icon(icon, size: Adaptive.sp(context, 14), color: colorScheme.onSurfaceVariant),
        SizedBox(width: Adaptive.w(context, 4)),
        Text(
          text,
          style: TextStyle(fontSize: Adaptive.sp(context, 12), color: colorScheme.onSurfaceVariant),
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
        _sectionTitle('学习趋势（近7天）', AppIcons.showChart, colorScheme),
        SizedBox(height: Adaptive.h(context, 12)),
        Container(
          padding: EdgeInsets.all(Adaptive.w(context, 16)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Adaptive.r(context, 14)),
            color: colorScheme.surface,
            boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Column(
            children: [
              // 柱状图
              SizedBox(
                height: Adaptive.h(context, 140), // 增加高度容纳文字和柱子
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _weeklyTrend.map((t) {
                    final ratio = maxMinutes > 0 ? t.minutes / maxMinutes : 0.0;
                    final barHeight = (Adaptive.h(context, 80) * ratio).clamp(Adaptive.h(context, 4), Adaptive.h(context, 80)); // 缩小柱子最大高度以留出空间
                    // 从日期中提取星期
                    final dateStr = t.date.substring(5); // MM-DD
                    final weekday = _getWeekdayLabel(t.date);

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 3)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (t.minutes > 0) ...[
                              Text(
                                '${t.minutes}',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colorScheme.primary),
                              ),
                              SizedBox(height: Adaptive.h(context, 4)),
                            ],
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(Adaptive.r(context, 4))),
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
                            SizedBox(height: Adaptive.h(context, 6)),
                            Text(weekday, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                            SizedBox(height: Adaptive.h(context, 2)),
                            Text(dateStr, style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: Adaptive.h(context, 12)),
              Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              SizedBox(height: Adaptive.h(context, 8)),
              // 汇总行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '本周总计',
                    style: TextStyle(fontSize: Adaptive.sp(context, 13), color: colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '${_weeklyTrend.fold<int>(0, (s, t) => s + t.minutes)} 分钟',
                    style: TextStyle(fontSize: Adaptive.sp(context, 14), fontWeight: FontWeight.bold, color: colorScheme.onSurface),
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
        _sectionTitle('AI 学习建议', AppIcons.psychology, colorScheme),
        SizedBox(height: Adaptive.h(context, 12)),
        if (_aiLoading)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 32)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Adaptive.r(context, 14)),
              color: colorScheme.surface,
              boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15), width: 1),
            ),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary)),
          )
        else if (_aiSuggestions.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(Adaptive.w(context, 20)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Adaptive.r(context, 14)),
              color: colorScheme.surface,
              boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15), width: 1),
            ),
            child: Column(
              children: [
                Icon(AppIcons.lightbulbOutline, size: Adaptive.sp(context, 36), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                SizedBox(height: Adaptive.h(context, 12)),
                Text(
                  '继续学习后这里将显示个性化建议',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: Adaptive.sp(context, 14), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                ),
              ],
            ),
          )
        else
          ..._aiSuggestions.map((s) => _aiSuggestionCard(s, colorScheme)),
      ],
    );
  }

  Widget _aiSuggestionCard(AiSuggestion suggestion, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: Adaptive.h(context, 10)),
      padding: EdgeInsets.all(Adaptive.w(context, 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Adaptive.r(context, 14)),
        color: colorScheme.surface,
        boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(Adaptive.w(context, 10)),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(suggestion.icon, size: Adaptive.sp(context, 22), color: colorScheme.primary),
          ),
          SizedBox(width: Adaptive.w(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: TextStyle(fontSize: Adaptive.sp(context, 15), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                SizedBox(height: Adaptive.h(context, 4)),
                Text(
                  suggestion.description,
                  style: TextStyle(fontSize: Adaptive.sp(context, 13), color: colorScheme.onSurfaceVariant, height: 1.4),
                ),
                if (suggestion.actionText != null) ...[
                  SizedBox(height: Adaptive.h(context, 10)),
                  GestureDetector(
                    onTap: () => _handleSuggestionAction(suggestion),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 14), vertical: Adaptive.h(context, 7)),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 8)),
                        color: colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        suggestion.actionText!,
                        style: TextStyle(fontSize: Adaptive.sp(context, 12), fontWeight: FontWeight.w600, color: colorScheme.primary),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSuggestionAction(AiSuggestion suggestion) {
    // TODO: 根据建议类型跳转到对应页面或执行操作
    // 例如：'开始学习' -> 首页推荐资源；'今日目标' -> 显示今日目标弹窗
    debugPrint('[LearningStats] AI suggestion action: ${suggestion.title}');
  }

  // ─── 通用组件 ───

  Widget _sectionTitle(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: Adaptive.sp(context, 18), color: colorScheme.primary),
        SizedBox(width: Adaptive.w(context, 6)),
        Text(
          title,
          style: TextStyle(fontSize: Adaptive.sp(context, 16), fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
      ],
    );
  }
}
