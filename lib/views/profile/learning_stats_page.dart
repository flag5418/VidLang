/// 学习统计详情页面
///
/// 单页面可滚动布局，自上而下 6 个区域：
/// 1. 荣誉墙（12 个徽章横向滚动）
/// 2. 学习日历（TDCalendar 展示学习记录）
/// 3. 核心指标（4 项卡片 2×2，带时间段筛选）
/// 4. AI 学习建议区（有数据时显示）
library;

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/components/time_range_selector.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/profile/widgets/duration_detail_page.dart';
import 'package:vidlang/views/profile/widgets/follow_detail_page.dart';
import 'package:vidlang/views/profile/widgets/test_detail_page.dart';
import 'package:vidlang/views/profile/widgets/word_detail_page.dart';

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
  List<AiSuggestion> _aiSuggestions = [];
  bool _aiLoading = true;
  bool _loading = true;

  // 日历数据
  List<CalendarDayData> _calendarData = [];
  DateTime _calendarMonth = DateTime.now();

  // 跟读/评测综合得分
  double? _followAvgScore;
  double? _testAvgScore;

  // 当日收藏单词数
  int _todayWordCount = 0;

  // 时间段筛选
  String _timeRange = '30d';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        StatsService.getDetailOverview(),
        LearningStatsService.getCalendarData(_calendarMonth.year, _calendarMonth.month),
        LearningStatsService.getFollowMetrics(_timeRange),
        LearningStatsService.getTestMetrics(_timeRange),
        LearningStatsService.getWordCountToday(),
      ]);
      if (!mounted) return;
      final followMetrics = results[2] as FollowMetrics;
      final testMetrics = results[3] as TestMetrics;
      setState(() {
        _overview = results[0] as DetailOverview;
        _calendarData = results[1] as List<CalendarDayData>;
        _followAvgScore = followMetrics.totalCount > 0 ? followMetrics.avgScore : null;
        _testAvgScore = testMetrics.totalCount > 0 ? testMetrics.avgScore : null;
        _todayWordCount = results[4] as int;
        _loading = false;
      });
      debugPrint('[LearningStats] 加载成功: overview=${_overview?.totalDays}天, calendar=${_calendarData.length}条');
      // 异步加载 AI 建议（不阻塞主界面）
      _loadAiSuggestions();
    } catch (e, stack) {
      debugPrint('[LearningStats] 加载失败: $e');
      debugPrint(stack.toString());
      if (!mounted) return;
      setState(() {
        _overview = null;
        _calendarData = [];
        _loading = false;
      });
    }
  }

  Future<void> _reloadMetrics() async {
    try {
      final results = await Future.wait([
        LearningStatsService.getFollowMetrics(_timeRange),
        LearningStatsService.getTestMetrics(_timeRange),
      ]);
      if (!mounted) return;
      setState(() {
        _followAvgScore = (results[0] as FollowMetrics).totalCount > 0 ? (results[0] as FollowMetrics).avgScore : null;
        _testAvgScore = (results[1] as TestMetrics).totalCount > 0 ? (results[1] as TestMetrics).avgScore : null;
      });
    } catch (_) {}
  }

  Future<void> _loadCalendarData() async {
    try {
      final data = await LearningStatsService.getCalendarData(_calendarMonth.year, _calendarMonth.month);
      if (!mounted) return;
      setState(() => _calendarData = data);
      debugPrint('[LearningStats] 日历数据加载: ${_calendarMonth.year}-${_calendarMonth.month}, 共${data.length}条');
      for (final d in data) {
        debugPrint('  - ${d.date}: 时长=${d.durationSeconds}s, 跟读=${d.followCount}, 评测=${d.testCount}, 单词=${d.wordCount}');
      }
    } catch (e, stack) {
      debugPrint('[LearningStats] 日历数据加载失败: $e');
      debugPrint(stack.toString());
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
          icon: Icon(AppIcons.arrowBackIos, color: colorScheme.onSurface, size: adaptive.Adaptive.icon(20)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '学习统计',
          style: TextStyle(fontSize: adaptive.Adaptive.sp(17), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(adaptive.Adaptive.w(AppSpacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHonorWall(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildCalendar(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildOverview(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildAiSuggestion(colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(32)),
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
        SizedBox(height: adaptive.Adaptive.h(12)),
        SizedBox(
          height: adaptive.Adaptive.h(100),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _badges.length,
            separatorBuilder: (_, _) => SizedBox(width: adaptive.Adaptive.w(16)),
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
        width: adaptive.Adaptive.w(72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: adaptive.Adaptive.w(56),
              height: adaptive.Adaptive.w(56),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface,
                boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.03), blurRadius: adaptive.Adaptive.w(8), offset: const Offset(0, 2))],
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(badge.icon, size: adaptive.Adaptive.sp(26), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
            SizedBox(height: adaptive.Adaptive.h(6)),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: adaptive.Adaptive.sp(12), fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(_BadgeDef badge) {
    final colorScheme = Theme.of(context).colorScheme;
    Navigator.of(context).push(
      TDSlidePopupRoute(
        slideTransitionFrom: SlideTransitionFrom.bottom,
        builder: (popupContext) => Container(
          padding: EdgeInsets.fromLTRB(adaptive.Adaptive.w(24), adaptive.Adaptive.h(16), adaptive.Adaptive.w(24), MediaQuery.of(popupContext).padding.bottom + adaptive.Adaptive.h(24)),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(adaptive.Adaptive.r(24))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: adaptive.Adaptive.w(40),
                height: adaptive.Adaptive.h(4),
                margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(24)),
                decoration: BoxDecoration(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(adaptive.Adaptive.r(2))),
              ),
              Container(
                width: adaptive.Adaptive.w(64),
                height: adaptive.Adaptive.w(64),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.surface,
                  boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.05), blurRadius: adaptive.Adaptive.w(10), offset: const Offset(0, 2))],
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2), width: 1),
                ),
                child: Icon(badge.icon, size: adaptive.Adaptive.sp(30), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              ),
              SizedBox(height: adaptive.Adaptive.h(16)),
              Text(
                badge.name,
                style: TextStyle(fontSize: adaptive.Adaptive.sp(20), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              SizedBox(height: adaptive.Adaptive.h(8)),
              Text(
                badge.description,
                style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: adaptive.Adaptive.h(24)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(16), vertical: adaptive.Adaptive.h(12)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.info, size: adaptive.Adaptive.sp(16), color: colorScheme.onSurfaceVariant),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    Expanded(
                      child: Text(
                        '解锁条件：${badge.condition}',
                        style: TextStyle(fontSize: adaptive.Adaptive.sp(13), color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: adaptive.Adaptive.h(16)),
              Text(
                '尚未解锁',
                style: TextStyle(fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 区域 2: 核心指标卡片（点击下钻） ───

  Widget _buildOverview(ColorScheme colorScheme) {
    final ov = _overview;
    if (ov == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('核心指标', AppIcons.dashboard, colorScheme),
          SizedBox(height: adaptive.Adaptive.h(12)),
          Container(
            padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(AppIcons.info, color: colorScheme.primary),
                SizedBox(width: adaptive.Adaptive.w(8)),
                Expanded(
                  child: Text(
                    '数据加载失败，请下拉刷新重试',
                    style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final durationText = _formatDuration(ov.totalDurationSeconds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('核心指标', AppIcons.dashboard, colorScheme),
            // 时间段筛选下拉
            TimeRangeSelector(
              currentValue: _timeRange,
              onSelected: (value) {
                if (_timeRange != value) {
                  setState(() => _timeRange = value);
                  _reloadMetrics();
                }
              },
            ),
          ],
        ),
        SizedBox(height: adaptive.Adaptive.h(12)),
        Row(
          children: [
            _overviewCard(
              '总学习时长',
              durationText,
              '',
              AppIcons.timer,
              colorScheme,
              onTap: () => _navigateToDurationDetail(context),
            ),
            SizedBox(width: adaptive.Adaptive.w(10)),
            _overviewCard(
              '跟读评分',
              _followAvgScore != null ? _followAvgScore!.toStringAsFixed(1) : '0.0',
              '分',
              AppIcons.mic,
              colorScheme,
              valueColor: _followAvgScore != null ? const Color(0xFF30D158) : null,
              onTap: () => _navigateToDetail(context, FollowDetailPage(timeRange: _timeRange)),
            ),
          ],
        ),
        SizedBox(height: adaptive.Adaptive.h(10)),
        Row(
          children: [
            _overviewCard(
              '评测成绩',
              _testAvgScore != null ? _testAvgScore!.toStringAsFixed(1) : '0.0',
              '分',
              AppIcons.rule,
              colorScheme,
              valueColor: _testAvgScore != null ? const Color(0xFFFFCC00) : null,
              onTap: () => _navigateToDetail(context, TestDetailPage(timeRange: _timeRange)),
            ),
            SizedBox(width: adaptive.Adaptive.w(10)),
            _overviewCard(
              '单词收藏',
              '$_todayWordCount',
              '个',
              AppIcons.book,
              colorScheme,
              onTap: () => _navigateToDetail(context, WordDetailPage(timeRange: _timeRange)),
            ),
          ],
        ),
      ],
    );
  }

  void _navigateToDetail(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _navigateToDurationDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DurationDetailPage(timeRange: _timeRange)),
    );
  }

  Widget _overviewCard(String label, String value, String suffix, IconData icon, ColorScheme colorScheme, {Color? valueColor, VoidCallback? onTap}) {
    Widget card = Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
        color: colorScheme.surface,
        boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: adaptive.Adaptive.w(10), offset: const Offset(0, 4))],
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(adaptive.Adaptive.w(8)),
            decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, size: adaptive.Adaptive.w(20), color: colorScheme.primary),
          ),
          SizedBox(height: adaptive.Adaptive.h(16)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(26), fontWeight: FontWeight.bold, color: valueColor ?? colorScheme.onSurface, height: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (suffix.isNotEmpty) ...[
                SizedBox(width: adaptive.Adaptive.w(4)),
                Padding(
                  padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(2)),
                  child: Text(
                    suffix,
                    style: TextStyle(fontSize: adaptive.Adaptive.sp(13), color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(6)),
          Text(
            label,
            style: TextStyle(fontSize: adaptive.Adaptive.sp(12), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    return Expanded(child: card);
  }

  // ─── 区域 2: 学习日历 ───

  Widget _buildCalendar(ColorScheme colorScheme) {
    final dayMap = <String, CalendarDayData>{};
    for (final d in _calendarData) {
      dayMap[d.date] = d;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('学习日历', AppIcons.calendarToday, colorScheme),
            // 月份切换
            Row(
              children: [
                IconButton(
                  icon: Icon(AppIcons.arrowBack, size: adaptive.Adaptive.sp(18), color: colorScheme.onSurfaceVariant),
                  onPressed: () {
                    setState(() {
                      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                    });
                    _loadCalendarData();
                  },
                ),
                Text(
                  '${_calendarMonth.year}年${_calendarMonth.month}月',
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                IconButton(
                  icon: Icon(AppIcons.arrowForward, size: adaptive.Adaptive.sp(18), color: colorScheme.onSurfaceVariant),
                  onPressed: () {
                    setState(() {
                      _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                    });
                    _loadCalendarData();
                  },
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: adaptive.Adaptive.h(12)),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
            color: colorScheme.surface,
            boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: adaptive.Adaptive.w(10), offset: const Offset(0, 4))],
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
          ),
          child: TDCalendar(
            key: ValueKey(_calendarMonth), // 强制月份变化时重新构建日历
            anchorDate: _calendarMonth,
            firstDayOfWeek: 1,
            height: adaptive.Adaptive.h(380),
            cellHeight: adaptive.Adaptive.h(50),
            value: [DateTime.now().millisecondsSinceEpoch],
            type: CalendarType.single,
            // 允许查看过去12个月到未来3个月
            minDate: DateTime.now().subtract(const Duration(days: 365)).millisecondsSinceEpoch,
            maxDate: DateTime.now().add(const Duration(days: 90)).millisecondsSinceEpoch,
            // 主题自适应样式（修复暗黑模式下日历明亮问题）
            style: TDCalendarStyle(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(adaptive.Adaptive.r(14)),
                ),
              ),
              weekdayStyle: TextStyle(
                fontSize: adaptive.Adaptive.sp(12),
                color: colorScheme.onSurfaceVariant,
              ),
              monthTitleStyle: TextStyle(
                fontSize: adaptive.Adaptive.sp(14),
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            // 自定义月份标题（确保暗黑模式颜色正确）
            monthTitleBuilder: (context, monthDate) {
              return Center(
                child: Text(
                  '${monthDate.year}年${monthDate.month}月',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(14),
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              );
            },
            onMonthChange: (date) {
              // 避免与外部切换重复刷新
              if (date.year != _calendarMonth.year || date.month != _calendarMonth.month) {
                setState(() => _calendarMonth = date);
                _loadCalendarData();
              }
            },
            cellWidget: (context, tdate, selectType) {
              final dateStr = '${tdate.date.year}-${tdate.date.month.toString().padLeft(2, '0')}-${tdate.date.day.toString().padLeft(2, '0')}';
              final dayData = dayMap[dateStr];
              final hasData = dayData != null && (dayData.durationSeconds > 0 || dayData.followCount > 0 || dayData.testCount > 0 || dayData.wordCount > 0);

                      return GestureDetector(
                        onTap: hasData ? () => _showDayDetail(dateStr, dayData, colorScheme) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: hasData ? colorScheme.primary.withValues(alpha: 0.1) : null,
                    borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${tdate.date.day}',
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(14),
                          fontWeight: FontWeight.w500,
                          color: selectType == DateSelectType.selected
                              ? colorScheme.primary
                              : hasData
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (hasData) ...[
                        SizedBox(height: adaptive.Adaptive.h(2)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (dayData.durationSeconds > 0)
                              _calendarDot(colorScheme.primary),
                            if (dayData.followCount > 0)
                              _calendarDot(const Color(0xFF30D158)),
                            if (dayData.testCount > 0)
                              _calendarDot(const Color(0xFFFFCC00)),
                            if (dayData.wordCount > 0)
                              _calendarDot(const Color(0xFFFF3B30)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: adaptive.Adaptive.h(8)),
        // 图例
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _calendarLegend('学习', colorScheme.primary),
            SizedBox(width: adaptive.Adaptive.w(12)),
            _calendarLegend('跟读', const Color(0xFF30D158)),
            SizedBox(width: adaptive.Adaptive.w(12)),
            _calendarLegend('评测', const Color(0xFFFFCC00)),
            SizedBox(width: adaptive.Adaptive.w(12)),
            _calendarLegend('收藏', const Color(0xFFFF3B30)),
          ],
        ),
      ],
    );
  }

  Widget _calendarDot(Color color) {
    return Container(
      width: adaptive.Adaptive.w(4),
      height: adaptive.Adaptive.w(4),
      margin: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(1)),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _calendarLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: adaptive.Adaptive.w(6),
          height: adaptive.Adaptive.w(6),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: adaptive.Adaptive.w(4)),
        Text(label, style: TextStyle(fontSize: adaptive.Adaptive.sp(11), color: AppColors.textSecondary)),
      ],
    );
  }

  // ─── AI 学习建议区 ───

  Widget _buildAiSuggestion(ColorScheme colorScheme) {
    // 无数据时自动隐藏（包括加载中和空数据）
    if (_aiLoading || _aiSuggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('AI 学习建议', AppIcons.psychology, colorScheme),
        SizedBox(height: adaptive.Adaptive.h(12)),
        ..._aiSuggestions.map((s) => _aiSuggestionCard(s, colorScheme)),
      ],
    );
  }

  Widget _aiSuggestionCard(AiSuggestion suggestion, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(10)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
        color: colorScheme.surface,
        boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: adaptive.Adaptive.w(10), offset: const Offset(0, 4))],
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(adaptive.Adaptive.w(10)),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(suggestion.icon, size: adaptive.Adaptive.sp(22), color: colorScheme.primary),
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(15), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                SizedBox(height: adaptive.Adaptive.h(4)),
                Text(
                  suggestion.description,
                  style: TextStyle(fontSize: adaptive.Adaptive.sp(13), color: colorScheme.onSurfaceVariant, height: 1.4),
                ),
                if (suggestion.actionText != null) ...[
                  SizedBox(height: adaptive.Adaptive.h(10)),
                  GestureDetector(
                    onTap: () => _handleSuggestionAction(suggestion),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(14), vertical: adaptive.Adaptive.h(7)),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
                        color: colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        suggestion.actionText!,
                        style: TextStyle(fontSize: adaptive.Adaptive.sp(12), fontWeight: FontWeight.w600, color: colorScheme.primary),
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
    // 根据建议标题关键词判断类型并跳转
    final title = suggestion.title;
    if (title.contains('跟读') || title.contains('发音')) {
      // 跳转到跟读详情页
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FollowDetailPage()));
    } else if (title.contains('评测') || title.contains('测试') || title.contains('正确率')) {
      // 跳转到评测详情页
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TestDetailPage()));
    } else if (title.contains('时长') || title.contains('习惯') || title.contains('学习时段')) {
      // 跳转到学习时长详情页
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DurationDetailPage()));
    } else if (title.contains('单词') || title.contains('收藏')) {
      // 跳转到单词收藏详情页
      Navigator.push(context, MaterialPageRoute(builder: (_) => const WordDetailPage()));
    } else {
      // 默认提示
      debugPrint('[LearningStats] AI suggestion action: $title');
    }
  }

  // ─── 当日学习详情弹窗 ───

  void _showDayDetail(String dateStr, CalendarDayData dayData, ColorScheme colorScheme) {
    final durationMin = dayData.durationSeconds ~/ 60;
    Navigator.of(context).push(
      TDSlidePopupRoute(
        slideTransitionFrom: SlideTransitionFrom.bottom,
        builder: (popupContext) => TDPopupBottomDisplayPanel(
          title: '$dateStr 学习记录',
          titleLeft: true,
          closeClick: () => Navigator.maybePop(popupContext),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(adaptive.Adaptive.w(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dayData.durationSeconds > 0)
                    _dayDetailItem(AppIcons.timer, '学习时长', '$durationMin 分钟', colorScheme.primary, colorScheme),
                  if (dayData.followCount > 0)
                    _dayDetailItem(AppIcons.mic, '跟读次数', '${dayData.followCount} 次', const Color(0xFF30D158), colorScheme),
                  if (dayData.testCount > 0)
                    _dayDetailItem(AppIcons.rule, '评测次数', '${dayData.testCount} 次', const Color(0xFFFFCC00), colorScheme),
                  if (dayData.wordCount > 0)
                    _dayDetailItem(AppIcons.book, '收藏单词', '${dayData.wordCount} 个', const Color(0xFFFF3B30), colorScheme),
                  SizedBox(height: adaptive.Adaptive.h(16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayDetailItem(IconData icon, String label, String value, Color color, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(adaptive.Adaptive.w(8)),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8))),
            child: Icon(icon, size: adaptive.Adaptive.sp(18), color: color),
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurface)),
          ),
          Text(value, style: TextStyle(fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
        ],
      ),
    );
  }

  // ─── 通用组件 ───

  /// 格式化学习时长
  /// - 小于 1 小时：显示 xx分钟
  /// - 1-24 小时：显示 xx.xx小时
  /// - 大于 24 小时：显示 xx.xx天
  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 3600) {
      // 小于1小时，显示分钟
      return '${totalSeconds ~/ 60}分钟';
    } else if (totalSeconds < 86400) {
      // 小于1天，显示小时（保留2位小数）
      final hours = totalSeconds / 3600;
      return '${hours.toStringAsFixed(2)}小时';
    } else {
      // 大于1天，显示天（保留2位小数）
      final days = totalSeconds / 86400;
      return '${days.toStringAsFixed(2)}天';
    }
  }

  Widget _sectionTitle(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: adaptive.Adaptive.sp(18), color: colorScheme.primary),
        SizedBox(width: adaptive.Adaptive.w(6)),
        Text(
          title,
          style: TextStyle(fontSize: adaptive.Adaptive.sp(16), fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
      ],
    );
  }
}
