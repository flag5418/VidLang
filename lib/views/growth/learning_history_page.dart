/// 学习记录页面 — 按时间范围 + 资源类型筛选的学习历史
///
/// 布局策略：
/// - iPhone：顶部筛选栏（时间 + 类型水平排列）+ 下方列表
/// - iPad：左侧资源类型导航栏 + 右侧时间筛选 + 列表
library;

import 'package:flutter/material.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/player/unified/unified_player_page.dart';
import 'package:vidlang/views/article/article_reader_page.dart';

/// 时间范围枚举
enum TimeRange {
  day('今天'),
  week('近7天'),
  month('近30天'),
  custom('自定义');

  final String label;
  const TimeRange(this.label);
}

/// 资源类型筛选
enum ResourceTypeFilter {
  all('全部', AppIcons.apps),
  video('视频', AppIcons.movie),
  music('音频', AppIcons.musicNote),
  article('文章', AppIcons.menuBook);

  final String label;
  final IconData icon;
  const ResourceTypeFilter(this.label, this.icon);

  /// 对应 StudyRecord 的 resourceType 值，all 返回 null
  String? get dbValue {
    switch (this) {
      case ResourceTypeFilter.all:
        return null;
      case ResourceTypeFilter.video:
        return 'video';
      case ResourceTypeFilter.music:
        return 'music';
      case ResourceTypeFilter.article:
        return 'article';
    }
  }
}

class LearningHistoryPage extends StatefulWidget {
  const LearningHistoryPage({super.key});

  @override
  State<LearningHistoryPage> createState() => _LearningHistoryPageState();
}

class _LearningHistoryPageState extends State<LearningHistoryPage> {
  TimeRange _selectedTimeRange = TimeRange.week;
  ResourceTypeFilter _selectedType = ResourceTypeFilter.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  List<LearningHistoryRecord> _records = [];
  bool _isLoading = true;

  bool get _isIpad => adaptive.isIPad();

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // ════════════════════════════════════════════════
  //  数据加载
  // ════════════════════════════════════════════════

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final range = _getDateRange();
    final records = await LearningStatsService.instance.getLearningHistory(
      startDate: range.$1,
      endDate: range.$2,
      resourceType: _selectedType.dbValue,
    );
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  (DateTime, DateTime) _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedTimeRange) {
      case TimeRange.day:
        return (today, today.add(const Duration(days: 1)));
      case TimeRange.week:
        return (
          today.subtract(const Duration(days: 6)),
          today.add(const Duration(days: 1)),
        );
      case TimeRange.month:
        return (
          today.subtract(const Duration(days: 29)),
          today.add(const Duration(days: 1)),
        );
      case TimeRange.custom:
        final start =
            _customStartDate ?? today.subtract(const Duration(days: 6));
        final end =
            _customEndDate?.add(const Duration(days: 1)) ??
            start.add(const Duration(days: 7));
        return (start, end);
    }
  }

  /// 使用居中 Dialog 弹窗选择自定义日期范围
  void _pickCustomDateRange() {
    final now = DateTime.now();
    final initialStart =
        _customStartDate ?? now.subtract(const Duration(days: 6));
    final initialEnd = _customEndDate ?? now;

    var tempStart = initialStart;
    var tempEnd = initialEnd;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) {
          final colorScheme = Theme.of(builderContext).colorScheme;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                adaptive.Adaptive.r( 16),
              ),
            ),
            child: Container(
              width: MediaQuery.of(builderContext).size.width * 0.85,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(builderContext).size.height * 0.6,
              ),
              padding: EdgeInsets.fromLTRB(
                adaptive.Adaptive.w( 24),
                adaptive.Adaptive.h( 24),
                adaptive.Adaptive.w( 24),
                adaptive.Adaptive.h( 20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '选择日期范围',
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp( 17),
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: adaptive.Adaptive.h( 20)),
                  // 开始日期
                  _buildDatePickerRow(
                    pickerContext: dialogContext,
                    scaffoldContext: builderContext,
                    label: '开始日期',
                    value: tempStart,
                    lastDate: tempEnd,
                    onChanged: (d) => setDialogState(() => tempStart = d),
                    colorScheme: colorScheme,
                  ),
                  SizedBox(height: adaptive.Adaptive.h( 12)),
                  // 结束日期
                  _buildDatePickerRow(
                    pickerContext: dialogContext,
                    scaffoldContext: builderContext,
                    label: '结束日期',
                    value: tempEnd,
                    firstDate: tempStart,
                    lastDate: now,
                    onChanged: (d) => setDialogState(() => tempEnd = d),
                    colorScheme: colorScheme,
                  ),
                  SizedBox(height: adaptive.Adaptive.h( 24)),
                  // 底部按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
                            ),
                          ),
                          child: Text(
                            '取消',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp( 15),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: adaptive.Adaptive.w( 12)),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (tempStart.isAfter(tempEnd)) {
                              final swap = tempStart;
                              tempStart = tempEnd;
                              tempEnd = swap;
                            }
                            Navigator.pop(dialogContext);
                            Future.microtask(() {
                              if (!mounted) return;
                              setState(() {
                                _customStartDate = tempStart;
                                _customEndDate = tempEnd;
                                _selectedTimeRange = TimeRange.custom;
                              });
                              _loadRecords();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
                            ),
                          ),
                          child: Text(
                            '确定',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp( 15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 单行日期选择器：标签 + 显示值 + 点击弹出原生日期选择
  Widget _buildDatePickerRow({
    required BuildContext pickerContext,
    required BuildContext scaffoldContext,
    required String label,
    required DateTime value,
    DateTime? firstDate,
    DateTime? lastDate,
    required ValueChanged<DateTime> onChanged,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: pickerContext,
          initialDate: value,
          firstDate: firstDate ?? DateTime(2025, 1, 1),
          lastDate: lastDate ?? DateTime.now(),
          locale: const Locale('zh', 'CN'),
          helpText: '选择$label',
          cancelText: '取消',
          confirmText: '确定',
          fieldLabelText: label,
          builder: (pickerContext, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: colorScheme.primary,
                  brightness: Brightness.light,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      borderRadius: BorderRadius.circular(adaptive.Adaptive.r( 10)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w( 16),
          vertical: adaptive.Adaptive.h( 14),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r( 10)),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.calendarToday,
              size: adaptive.Adaptive.sp( 20),
              color: colorScheme.primary,
            ),
            SizedBox(width: adaptive.Adaptive.w( 12)),
            Text(
              label,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp( 14),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '${value.year}-${_pad(value.month)}-${_pad(value.day)}',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp( 15),
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(width: adaptive.Adaptive.w( 6)),
            Icon(
              Icons.chevron_right,
              size: adaptive.Adaptive.sp( 20),
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  void _onTimeRangeTap(TimeRange range) {
    if (range == TimeRange.custom) {
      _pickCustomDateRange();
    } else {
      setState(() => _selectedTimeRange = range);
      _loadRecords();
    }
  }

  String _getTimeRangeLabel(TimeRange range) => range.label;

  // ════════════════════════════════════════════════
  //  UI 入口
  // ════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _isIpad
        ? _buildIpadLayout(colorScheme)
        : _buildIphoneLayout(colorScheme);
  }

  // ════════════════════════════════════════════════
  //  iPhone 布局
  // ════════════════════════════════════════════════

  Widget _buildIphoneLayout(ColorScheme colorScheme) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: adaptive.Adaptive.sp(18)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '学习记录',
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(17),
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildIphoneFilterBar(colorScheme),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(child: _buildBody(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildIphoneFilterBar(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(12),
      ),
      child: Column(
        children: [
          // 时间范围
          Row(
            children: [
              Text('时间', style: _labelStyle(colorScheme)),
              SizedBox(width: adaptive.Adaptive.w(10)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TimeRange.values.map((r) {
                      return Padding(
                        padding: EdgeInsets.only(right: adaptive.Adaptive.w(8)),
                        child: GestureDetector(
                          onTap: () => _onTimeRangeTap(r),
                          child: _buildChip(
                            label: _getTimeRangeLabel(r),
                            isSelected: _selectedTimeRange == r,
                            colorScheme: colorScheme,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(10)),
          // 资源类型
          Row(
            children: [
              Text('类型', style: _labelStyle(colorScheme)),
              SizedBox(width: adaptive.Adaptive.w(10)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ResourceTypeFilter.values.map((t) {
                      return Padding(
                        padding: EdgeInsets.only(right: adaptive.Adaptive.w(8)),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedType = t);
                            _loadRecords();
                          },
                          child: _buildChip(
                            label: t.label,
                            isSelected: _selectedType == t,
                            colorScheme: colorScheme,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  iPad 布局：左侧类型导航 + 右侧内容
  // ════════════════════════════════════════════════

  Widget _buildIpadLayout(ColorScheme colorScheme) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Row(
        children: [
          // 左侧导航栏（包含返回按钮）
          _buildIpadSideNav(colorScheme),
          // 分割线
          Container(
            width: 0.5,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          // 右侧内容区
          Expanded(
            child: Container(
              color: colors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部标题 + 返回按钮
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      MediaQuery.of(context).padding.top + 8,
                      24,
                      12,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new, size: adaptive.Adaptive.sp(20)),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        SizedBox(width: adaptive.Adaptive.w(12)),
                        Text(
                          '学习记录',
                          style: TextStyle(
                            fontSize: adaptive.Adaptive.sp(20),
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 时间筛选栏
                  _buildIpadHeader(colorScheme),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  // 学习记录列表
                  Expanded(child: _buildBody(colorScheme)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpadSideNav(ColorScheme colorScheme) {
    final colors = context.colors;
    return Container(
      width: 220,
      decoration: BoxDecoration(color: colors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: adaptive.Adaptive.h(80)),
          // 筛选项列表
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: ResourceTypeFilter.values.map((type) {
                return _buildSideNavItem(type, colorScheme);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavItem(ResourceTypeFilter type, ColorScheme colorScheme) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedType = type);
        _loadRecords();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(8), vertical: adaptive.Adaptive.h(3)),
        padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(12), vertical: adaptive.Adaptive.h(10)),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
        ),
        child: Row(
          children: [
            Icon(
              type.icon,
              size: adaptive.Adaptive.sp(20),
              color: isSelected
                  ? Colors.white
                  : colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: adaptive.Adaptive.w(8)),
            Text(
              type.label,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(15),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpadHeader(ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(adaptive.Adaptive.w(32), adaptive.Adaptive.h(12), adaptive.Adaptive.w(24), adaptive.Adaptive.h(12)),
      child: Row(
        children: [
          // 时间范围 Chip 行
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TimeRange.values.map((range) {
                  final isSelected = _selectedTimeRange == range;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _onTimeRangeTap(range),
                      child: _buildChip(
                        label: _getTimeRangeLabel(range),
                        isSelected: isSelected,
                        colorScheme: colorScheme,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  //  通用组件
  // ════════════════════════════════════════════════

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.historyToggleOff,
              size: adaptive.Adaptive.sp(48),
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            SizedBox(height: adaptive.Adaptive.h(12)),
            Text(
              '暂无学习记录',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(15),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView.separated(
        padding: EdgeInsets.all(adaptive.Adaptive.w(_isIpad ? 28 : 16)),
        itemCount: _records.length,
        separatorBuilder: (_, _) => SizedBox(height: adaptive.Adaptive.h(10)),
        itemBuilder: (context, index) =>
            _buildRecordCard(_records[index], colorScheme),
      ),
    );
  }

  /// 筛选 Chip 组件
  Widget _buildChip({
    required String label,
    required bool isSelected,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(14),
        vertical: adaptive.Adaptive.h(6),
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      // 使用 Flexible 让长文本自适应宽度，外层 Row 已在 SingleChildScrollView 中
      child: Text(
        label,
        style: TextStyle(
          fontSize: adaptive.Adaptive.sp(13),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  TextStyle _labelStyle(ColorScheme colorScheme) => TextStyle(
    fontSize: adaptive.Adaptive.sp(13),
    fontWeight: FontWeight.w600,
    color: colorScheme.onSurfaceVariant,
  );

  // ════════════════════════════════════════════════
  //  记录卡片
  // ════════════════════════════════════════════════

  /// 卡片布局：对齐首页「最近学习」样式
  /// 第一行：图标 + 标题 + 时间 ago | 第二行：详情 | 第三行：进度条 + 百分比
  Widget _buildRecordCard(
    LearningHistoryRecord record,
    ColorScheme colorScheme,
  ) {
    final brightness = Theme.of(context).brightness;
    final typeColor = AppColors.colorForType(
      record.resourceType,
      brightness: brightness,
    );
    final icon = _iconForType(record.resourceType);

    return GestureDetector(
      onTap: () => _navigateToResource(record),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：图标 + 标题 + 时间
            Row(
              children: [
                Icon(icon, size: adaptive.Adaptive.sp(18), color: typeColor),
                SizedBox(width: adaptive.Adaptive.w(8)),
                Expanded(
                  child: Text(
                    record.resourceTitle ?? '未知资源',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(14),
                      fontWeight: FontWeight.w600,
                      color: record.isDeleted
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                      decoration: record.isDeleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (record.isDeleted)
                  Container(
                    margin: EdgeInsets.only(left: adaptive.Adaptive.w(8)),
                    padding: EdgeInsets.symmetric(
                      horizontal: adaptive.Adaptive.w(6),
                      vertical: adaptive.Adaptive.h(2),
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(adaptive.Adaptive.r(4)),
                    ),
                    child: Text(
                      '已删除',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(10),
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Text(
                    _timeAgo(record.startTime),
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(11),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            SizedBox(height: adaptive.Adaptive.h(8)),
            // 第二行：详细信息（带图标）
            _buildDetailRow(record, colorScheme),
            SizedBox(height: adaptive.Adaptive.h(8)),
            // 第三行：进度条 + 百分比
            _buildProgressBar(record, typeColor, colorScheme),
          ],
        ),
      ),
    );
  }

  /// 第二行：资源详细信息（对齐首页样式）
  Widget _buildDetailRow(
    LearningHistoryRecord record,
    ColorScheme colorScheme,
  ) {
    switch (record.resourceType) {
      case 'article':
        return FutureBuilder<Widget>(
          future: _buildArticleDetail(record.resourceCode, colorScheme),
          builder: (_, snap) => snap.data ?? const SizedBox.shrink(),
        );
      case 'video':
      case 'music':
        return FutureBuilder<Widget>(
          future: _buildVideoDetail(
            record.resourceCode,
            record.durationSeconds,
            colorScheme,
          ),
          builder: (_, snap) => snap.data ?? const SizedBox.shrink(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// 视频/音频详情行：播放图标 + 最后学习进度 / 总时长
  Future<Widget> _buildVideoDetail(
    String resourceCode,
    int studiedSeconds,
    ColorScheme colorScheme,
  ) async {
    try {
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'code = ?',
        whereArgs: [resourceCode],
        limit: 1,
      );
      if (videos.isEmpty) {
        return _simpleDetail('🕐 $studiedSeconds秒', colorScheme);
      }
      final video = videos.first;
      final totalMs = video.duration;
      if (totalMs <= 0) {
        return _simpleDetail('🕐 $studiedSeconds秒', colorScheme);
      }
      final totalSec = totalMs ~/ 1000;
      // 使用最后播放位置作为学习进度
      final lastPositionSec = video.currentPosition ~/ 1000;
      return Row(
        children: [
          Icon(
            AppIcons.playCircleOutline,
            size: adaptive.Adaptive.sp(14),
            color: colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: adaptive.Adaptive.w(4)),
          Text(
            '${_fmtDur(lastPositionSec)} / ${_fmtDur(totalSec)}',
            style: _detailStyle(colorScheme),
          ),
        ],
      );
    } catch (_) {
      return _simpleDetail('🕐 $studiedSeconds秒', colorScheme);
    }
  }

  /// 文章详情行：段落图标 + 段落数 | 字数图标 + 字数
  Future<Widget> _buildArticleDetail(
    String resourceCode,
    ColorScheme colorScheme,
  ) async {
    try {
      final articles = await DatabaseService.findByCondition(
        () => Article(),
        where: 'code = ?',
        whereArgs: [resourceCode],
        limit: 1,
      );
      if (articles.isEmpty) return _simpleDetail('📄 文章', colorScheme);
      final article = articles.first;
      final paras = article.totalParagraphs;
      final words = article.wordCount;
      return Row(
        children: [
          Icon(
            AppIcons.formatListNumbered,
            size: adaptive.Adaptive.sp(14),
            color: colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: adaptive.Adaptive.w(4)),
          Text('$paras段', style: _detailStyle(colorScheme)),
          if (words > 0) ...[
            SizedBox(width: adaptive.Adaptive.w(12)),
            Icon(
              AppIcons.textFields,
              size: adaptive.Adaptive.sp(14),
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: adaptive.Adaptive.w(4)),
            Text('${_fmtNum(words)}字', style: _detailStyle(colorScheme)),
          ],
        ],
      );
    } catch (_) {
      return _simpleDetail('📄 文章', colorScheme);
    }
  }

  Widget _simpleDetail(String text, ColorScheme colorScheme) => Row(
    children: [
      Icon(
        Icons.info_outline,
        size: adaptive.Adaptive.sp(14),
        color: colorScheme.onSurfaceVariant,
      ),
      SizedBox(width: adaptive.Adaptive.w(4)),
      Text(text, style: _detailStyle(colorScheme)),
    ],
  );

  /// 第三行：进度条 + 百分比
  Widget _buildProgressBar(
    LearningHistoryRecord record,
    Color typeColor,
    ColorScheme colorScheme,
  ) {
    return FutureBuilder<double>(
      future: _calcProgress(record),
      builder: (_, snap) {
        final progress = snap.data ?? 0.0;
        final pct = (progress * 100).toInt();
        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(2)),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 4,
                  backgroundColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.2,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0
                        ? typeColor
                        : colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            SizedBox(width: adaptive.Adaptive.w(8)),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(11),
                fontWeight: FontWeight.w600,
                color: typeColor,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 计算学习进度（0.0 ~ 1.0）
  Future<double> _calcProgress(LearningHistoryRecord record) async {
    try {
      switch (record.resourceType) {
        case 'video':
        case 'music':
          final videos = await DatabaseService.findByCondition(
            () => VideoInfo(),
            where: 'code = ?',
            whereArgs: [record.resourceCode],
            limit: 1,
          );
          if (videos.isEmpty) return 0.0;
          final video = videos.first;
          final totalMs = video.duration;
          if (totalMs <= 0) return 0.0;
          final totalSec = totalMs ~/ 1000;
          if (totalSec <= 0) return 0.0;
          // 使用最后播放位置作为进度
          final lastPositionSec = video.currentPosition ~/ 1000;
          return (lastPositionSec / totalSec).clamp(0.0, 1.0);
        default:
          return 0.0;
      }
    } catch (_) {
      return 0.0;
    }
  }

  String _timeAgo(DateTime startTime) {
    final diff = DateTime.now().difference(startTime);
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}h前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min前';
    return '刚刚';
  }

  TextStyle _detailStyle(ColorScheme cs) =>
      TextStyle(fontSize: adaptive.Adaptive.sp(11), color: cs.onSurfaceVariant);

  /// 点击卡片跳转到对应播放器/阅读器
  void _navigateToResource(LearningHistoryRecord record) {
    if (record.isDeleted) return;
    switch (record.resourceType) {
      case 'video':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UnifiedPlayerPage(
              videoCode: record.resourceCode,
              folderVideos: [],
            ),
          ),
        );
        break;
      case 'music':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UnifiedPlayerPage(
              videoCode: record.resourceCode,
              folderVideos: [],
              audioType: 'music',
            ),
          ),
        );
        break;
      case 'article':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArticleReaderPage(
              articleCode: record.resourceCode,
            ),
          ),
        );
        break;
    }
  }

  static String _fmtDur(int seconds) {
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${seconds ~/ 60}分${seconds % 60}秒';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return m > 0 ? '$h时$m分' : '$h小时';
  }

  static String _fmtNum(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return n.toString();
  }

  // ════════════════════════════════════════════════
  //  辅助方法
  // ════════════════════════════════════════════════

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
}
