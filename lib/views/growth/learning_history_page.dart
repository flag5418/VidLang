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
import 'package:vidlang/services/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

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

  bool get _isIpad => isIPad(context);

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
                Adaptive.r(builderContext, 20),
              ),
            ),
            child: Container(
              width: MediaQuery.of(builderContext).size.width * 0.85,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(builderContext).size.height * 0.6,
              ),
              padding: EdgeInsets.fromLTRB(
                Adaptive.w(builderContext, 24),
                Adaptive.h(builderContext, 24),
                Adaptive.w(builderContext, 24),
                Adaptive.h(builderContext, 20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          '取消',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: Adaptive.sp(builderContext, 15),
                          ),
                        ),
                      ),
                      Text(
                        '选择日期范围',
                        style: TextStyle(
                          fontSize: Adaptive.sp(builderContext, 17),
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // 先更新状态再关闭弹窗
                          if (tempStart.isAfter(tempEnd)) {
                            final swap = tempStart;
                            tempStart = tempEnd;
                            tempEnd = swap;
                          }
                          Navigator.pop(dialogContext);
                          // 使用 Future.microtask 确保 dialog 完全关闭后再 setState
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
                        child: Text(
                          '确定',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: Adaptive.sp(builderContext, 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Adaptive.h(builderContext, 20)),
                  // 开始日期 — 使用 dialogContext 弹出日期选择器
                  _buildDatePickerRow(
                    pickerContext: dialogContext,
                    scaffoldContext: builderContext,
                    label: '开始日期',
                    value: tempStart,
                    lastDate: tempEnd,
                    onChanged: (d) => setDialogState(() => tempStart = d),
                    colorScheme: colorScheme,
                  ),
                  SizedBox(height: Adaptive.h(builderContext, 12)),
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
                  SizedBox(height: Adaptive.h(builderContext, 16)),
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
      borderRadius: BorderRadius.circular(Adaptive.r(scaffoldContext, 10)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Adaptive.w(scaffoldContext, 16),
          vertical: Adaptive.h(scaffoldContext, 14),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Adaptive.r(scaffoldContext, 10)),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.calendarToday,
              size: Adaptive.sp(scaffoldContext, 20),
              color: colorScheme.primary,
            ),
            SizedBox(width: Adaptive.w(scaffoldContext, 12)),
            Text(
              label,
              style: TextStyle(
                fontSize: Adaptive.sp(scaffoldContext, 14),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '${value.year}-${_pad(value.month)}-${_pad(value.day)}',
              style: TextStyle(
                fontSize: Adaptive.sp(scaffoldContext, 15),
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(width: Adaptive.w(scaffoldContext, 6)),
            Icon(
              Icons.chevron_right,
              size: Adaptive.sp(scaffoldContext, 20),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: Adaptive.sp(context, 18)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '学习记录',
          style: TextStyle(
            fontSize: Adaptive.sp(context, 17),
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
        horizontal: Adaptive.w(context, 16),
        vertical: Adaptive.h(context, 12),
      ),
      child: Column(
        children: [
          // 时间范围
          Row(
            children: [
              Text('时间', style: _labelStyle(colorScheme)),
              SizedBox(width: Adaptive.w(context, 10)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TimeRange.values.map((r) {
                      return Padding(
                        padding: EdgeInsets.only(right: Adaptive.w(context, 8)),
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
          SizedBox(height: Adaptive.h(context, 10)),
          // 资源类型
          Row(
            children: [
              Text('类型', style: _labelStyle(colorScheme)),
              SizedBox(width: Adaptive.w(context, 10)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ResourceTypeFilter.values.map((t) {
                      return Padding(
                        padding: EdgeInsets.only(right: Adaptive.w(context, 8)),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: Adaptive.sp(context, 20)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '学习记录',
          style: TextStyle(
            fontSize: Adaptive.sp(context, 19),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Row(
        children: [
          _buildIpadSideNav(colorScheme),
          Container(
            width: 0.5,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIpadHeader(colorScheme),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                Expanded(child: _buildBody(colorScheme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpadSideNav(ColorScheme colorScheme) {
    return Container(
      width: Adaptive.w(context, 180),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerLow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              Adaptive.w(context, 24),
              Adaptive.h(context, MediaQuery.of(context).padding.top + 20),
              Adaptive.w(context, 24),
              Adaptive.h(context, 8),
            ),
            child: Text(
              '资源类型',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 15),
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(height: Adaptive.h(context, 12)),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(
          horizontal: Adaptive.w(context, 8),
          vertical: Adaptive.h(context, 3),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: Adaptive.w(context, 12),
          vertical: Adaptive.h(context, 10),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Adaptive.r(context, 8)),
          border: Border(
            left: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              type.icon,
              size: Adaptive.sp(context, 20),
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: Adaptive.w(context, 8)),
            Text(
              type.label,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 15),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpadHeader(ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Adaptive.w(context, 32),
        Adaptive.h(context, MediaQuery.of(context).padding.top + 16),
        Adaptive.w(context, 24),
        Adaptive.h(context, 12),
      ),
      child: Row(
        children: [
          // 时间范围 Chip 行（标题已在 AppBar 中显示）
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TimeRange.values.map((range) {
                  final isSelected = _selectedTimeRange == range;
                  return Padding(
                    padding: EdgeInsets.only(right: Adaptive.w(context, 8)),
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
              size: Adaptive.sp(context, 48),
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            SizedBox(height: Adaptive.h(context, 12)),
            Text(
              '暂无学习记录',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 15),
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
        padding: EdgeInsets.all(Adaptive.w(context, _isIpad ? 28 : 16)),
        itemCount: _records.length,
        separatorBuilder: (_, _) => SizedBox(height: Adaptive.h(context, 10)),
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
        horizontal: Adaptive.w(context, 14),
        vertical: Adaptive.h(context, 6),
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
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
          fontSize: Adaptive.sp(context, 13),
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
    fontSize: Adaptive.sp(context, 13),
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
        padding: EdgeInsets.all(Adaptive.w(context, 12)),
        decoration: BoxDecoration(
          color: Colors.white,
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
                    record.resourceTitle ?? '未知资源',
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 14),
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
                    margin: EdgeInsets.only(left: Adaptive.w(context, 8)),
                    padding: EdgeInsets.symmetric(
                      horizontal: Adaptive.w(context, 6),
                      vertical: Adaptive.h(context, 2),
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '已删除',
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, 10),
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Text(
                    _timeAgo(record.startTime),
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 11),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            SizedBox(height: Adaptive.h(context, 8)),
            // 第二行：详细信息（带图标）
            _buildDetailRow(record, colorScheme),
            SizedBox(height: Adaptive.h(context, 8)),
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

  /// 视频/音频详情行：播放图标 + 已学时长 / 总时长
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
      if (videos.isEmpty)
        return _simpleDetail('🕐 $studiedSeconds秒', colorScheme);
      final video = videos.first;
      final totalMs = video.duration;
      if (totalMs <= 0)
        return _simpleDetail('🕐 $studiedSeconds秒', colorScheme);
      final totalSec = totalMs ~/ 1000;
      return Row(
        children: [
          Icon(
            AppIcons.playCircleOutline,
            size: Adaptive.sp(context, 14),
            color: colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: Adaptive.w(context, 4)),
          Text(
            '${_fmtDur(studiedSeconds)} / ${_fmtDur(totalSec)}',
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
            size: Adaptive.sp(context, 14),
            color: colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: Adaptive.w(context, 4)),
          Text('$paras段', style: _detailStyle(colorScheme)),
          if (words > 0) ...[
            SizedBox(width: Adaptive.w(context, 12)),
            Icon(
              AppIcons.textFields,
              size: Adaptive.sp(context, 14),
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: Adaptive.w(context, 4)),
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
        size: Adaptive.sp(context, 14),
        color: colorScheme.onSurfaceVariant,
      ),
      SizedBox(width: Adaptive.w(context, 4)),
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
                borderRadius: BorderRadius.circular(2),
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
            SizedBox(width: Adaptive.w(context, 8)),
            Text(
              '$pct%',
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
          final totalMs = videos.first.duration;
          if (totalMs <= 0) return 0.0;
          final totalSec = totalMs ~/ 1000;
          if (totalSec <= 0) return 0.0;
          return (record.durationSeconds / totalSec).clamp(0.0, 1.0);
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
      TextStyle(fontSize: Adaptive.sp(context, 11), color: cs.onSurfaceVariant);

  /// 点击卡片跳转到对应播放器/阅读器
  void _navigateToResource(LearningHistoryRecord record) {
    if (record.isDeleted) return;
    switch (record.resourceType) {
      case 'video':
      case 'music':
        Navigator.pushNamed(
          context,
          '/player',
          arguments: {
            'code': record.resourceCode,
            'type': record.resourceType,
            'title': record.resourceTitle,
          },
        );
        break;
      case 'article':
        Navigator.pushNamed(
          context,
          '/articleReader',
          arguments: {
            'code': record.resourceCode,
            'title': record.resourceTitle,
          },
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
