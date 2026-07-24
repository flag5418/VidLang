import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vidlang/models/billing_summary.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/services/billing/billing_service.dart';
import 'package:vidlang/theme/theme.dart';

/// 消费明细页面数据聚合类
class _BillingData {
  final BillingOverview overview;
  final BillingByCategoryResponse category;
  final BillingBySourceResponse source;

  const _BillingData({
    required this.overview,
    required this.category,
    required this.source,
  });
}

/// 视图模式
enum BillingViewMode {
  category('功能', AppIcons.category),
  resource('资源', AppIcons.folder);

  final String label;
  final IconData icon;
  const BillingViewMode(this.label, this.icon);
}

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  TimeMode _timeMode = TimeMode.day;
  BillingViewMode _viewMode = BillingViewMode.category;

  /// 统一的数据加载 Future，避免多个 FutureBuilder 各自显示 loading
  late Future<_BillingData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_BillingData> _loadData() async {
    final overview = await BillingService.fetchOverview(timeMode: _timeMode);
    final category = await BillingService.fetchByCategory(timeMode: _timeMode);
    final source = await BillingService.fetchBySource(timeMode: _timeMode);
    return _BillingData(
      overview: overview,
      category: category,
      source: source,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  void _changeTimeMode(TimeMode mode) {
    setState(() {
      _timeMode = mode;
      _dataFuture = _loadData();
    });
  }

  void _changeViewMode(BillingViewMode mode) {
    setState(() => _viewMode = mode);
  }

  Color _panelColor(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.dark
        ? AppColors.surfaceElevated
        : AppColors.lightSurface;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppNavBar(title: '消费明细'),
      body: FutureBuilder<_BillingData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.error,
                    size: adaptive.Adaptive.icon(48),
                    color: colorScheme.error,
                  ),
                  SizedBox(height: adaptive.Adaptive.h(12)),
                  Text(
                    '加载失败: ${snapshot.error}',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(14),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(16)),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;

          return Column(
            children: [
              // 时间范围选择器
              _buildTimeRangeSelector(colorScheme),
              // 视图模式切换
              _buildViewModeSelector(colorScheme),
              // 内容区域
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
                    children: [
                      _buildOverviewCard(colorScheme, data.overview),
                      SizedBox(height: adaptive.Adaptive.h(16)),
                      if (_viewMode == BillingViewMode.category)
                        _buildCategoryView(colorScheme, data.category)
                      else
                        _buildResourceView(colorScheme, data.source),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeRangeSelector(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(8),
      ),
      child: Row(
        children: TimeMode.values.map((mode) {
          final isSelected = mode == _timeMode;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changeTimeMode(mode),
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: adaptive.Adaptive.w(4),
                ),
                padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(8)),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
                ),
                child: Text(
                  mode.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(13),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildViewModeSelector(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(4),
      ),
      child: Row(
        children: BillingViewMode.values.map((mode) {
          final isSelected = mode == _viewMode;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changeViewMode(mode),
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: adaptive.Adaptive.w(4),
                ),
                padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(6)),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      mode.icon,
                      size: adaptive.Adaptive.icon(16),
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: adaptive.Adaptive.w(4)),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(13),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverviewCard(ColorScheme colorScheme, BillingOverview overview) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${overview.timeLabel}消费',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(13),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${overview.totalCount} 次',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(12),
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Text(
            '¥${overview.totalCost.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(28),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(12)),
          // 趋势图
          if (overview.trend.isNotEmpty)
            _buildTrendChart(colorScheme, overview.trend),
        ],
      ),
    );
  }

  Widget _buildTrendChart(
    ColorScheme colorScheme,
    List<BillingTrendPoint> points,
  ) {
    if (points.isEmpty) {
      return SizedBox(
        height: adaptive.Adaptive.h(100),
        child: const Center(child: Text('暂无数据')),
      );
    }
    return SizedBox(
      height: adaptive.Adaptive.h(120),
      child: CustomPaint(
        painter: _TrendPainter(points: points, color: colorScheme.primary),
        child: Padding(
          padding: EdgeInsets.only(top: adaptive.Adaptive.h(92)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final point in points)
                Expanded(
                  child: Text(
                    point.date.substring(5),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(10),
                      color: colorScheme.outline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryView(
    ColorScheme colorScheme,
    BillingByCategoryResponse data,
  ) {
    if (data.categories.isEmpty) {
      return _buildEmptyCard(colorScheme, '暂无消费记录');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('功能分类', colorScheme),
        SizedBox(height: adaptive.Adaptive.h(8)),
        ...data.categories.map(
          (cat) => _buildCategoryCard(colorScheme, cat),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    ColorScheme colorScheme,
    BillingCategoryItem category,
  ) {
    final categoryIcons = {
      'translate': AppIcons.translate,
      'tts': AppIcons.volumeUp,
      'conversation': AppIcons.chat,
      'lookup': AppIcons.search,
      'evaluate': AppIcons.quiz,
    };
    final icon = categoryIcons[category.category] ?? AppIcons.autoAwesome;

    return GestureDetector(
      onTap: () => _navigateToCategoryDetail(category),
      child: Container(
        margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
        padding: EdgeInsets.all(adaptive.Adaptive.w(14)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          color: _panelColor(colorScheme),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: adaptive.Adaptive.w(40),
              height: adaptive.Adaptive.w(40),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
              ),
              child: Icon(
                icon,
                size: adaptive.Adaptive.icon(20),
                color: colorScheme.primary,
              ),
            ),
            SizedBox(width: adaptive.Adaptive.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.nameZh,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(4)),
                  Text(
                    '${category.totalCount} 次',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(12),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '¥${category.totalCostCny.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(14),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: adaptive.Adaptive.w(8)),
            Icon(
              AppIcons.chevronRight,
              size: adaptive.Adaptive.icon(18),
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceView(
    ColorScheme colorScheme,
    BillingBySourceResponse data,
  ) {
    if (data.sources.isEmpty && data.unknownSourceCostCny <= 0) {
      return _buildEmptyCard(colorScheme, '暂无消费记录');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('资源统计', colorScheme),
        SizedBox(height: adaptive.Adaptive.h(8)),
        ...data.sources.map(
          (group) => _buildSourceTypeGroup(colorScheme, group),
        ),
        if (data.unknownSourceCostCny > 0)
          _buildUnknownSourceCard(colorScheme, data.unknownSourceCostCny),
      ],
    );
  }

  Widget _buildSourceTypeGroup(
    ColorScheme colorScheme,
    BillingSourceTypeGroup group,
  ) {
    final typeIcons = {
      'video': AppIcons.movie,
      'music': AppIcons.musicNote,
      'article': AppIcons.article,
    };
    final icon = typeIcons[group.sourceType] ?? AppIcons.folder;

    return GestureDetector(
      onTap: () => _navigateToSourceDetail(group),
      child: Container(
        margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
        padding: EdgeInsets.all(adaptive.Adaptive.w(14)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          color: _panelColor(colorScheme),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: adaptive.Adaptive.w(40),
              height: adaptive.Adaptive.w(40),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
              ),
              child: Icon(
                icon,
                size: adaptive.Adaptive.icon(20),
                color: colorScheme.primary,
              ),
            ),
            SizedBox(width: adaptive.Adaptive.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${group.sourceTypeZh} (${group.items.length}个)',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(4)),
                  Text(
                    '${group.items.take(2).map((e) => e.sourceTitle).join("、")}${group.items.length > 2 ? "..." : ""}',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(12),
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '¥${group.subtotalCny.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(14),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: adaptive.Adaptive.w(8)),
            Icon(
              AppIcons.chevronRight,
              size: adaptive.Adaptive.icon(18),
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnknownSourceCard(ColorScheme colorScheme, double cost) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(14)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            AppIcons.help,
            size: adaptive.Adaptive.icon(20),
            color: colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          Expanded(
            child: Text(
              '未关联资源',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(14),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            '¥${cost.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: adaptive.Adaptive.sp(15),
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildEmptyCard(ColorScheme colorScheme, String message) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(40)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
        color: _panelColor(colorScheme),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.receiptLong,
            size: adaptive.Adaptive.icon(48),
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: adaptive.Adaptive.h(12)),
          Text(
            message,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCategoryDetail(BillingCategoryItem category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillingCategoryDetailPage(
          timeMode: _timeMode,
          category: category.category,
          categoryName: category.nameZh,
        ),
      ),
    );
  }

  void _navigateToSourceDetail(BillingSourceTypeGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BillingSourceGroupDetailPage(
          timeMode: _timeMode,
          sourceType: group.sourceType,
          sourceTypeZh: group.sourceTypeZh,
          items: group.items,
        ),
      ),
    );
  }
}

/// 功能分类详情页
class BillingCategoryDetailPage extends StatefulWidget {
  final TimeMode timeMode;
  final String category;
  final String categoryName;

  const BillingCategoryDetailPage({
    super.key,
    required this.timeMode,
    required this.category,
    required this.categoryName,
  });

  @override
  State<BillingCategoryDetailPage> createState() =>
      _BillingCategoryDetailPageState();
}

class _BillingCategoryDetailPageState extends State<BillingCategoryDetailPage> {
  late Future<BillingCategoryDetailResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = BillingService.fetchCategoryDetail(
      category: widget.category,
      timeMode: widget.timeMode,
    );
  }

  Color _panelColor(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.dark
        ? AppColors.surfaceElevated
        : AppColors.lightSurface;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
appBar: AppNavBar(title: '${widget.categoryName} · ${widget.timeMode.label}'),
      body: FutureBuilder<BillingCategoryDetailResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}'),
                  SizedBox(height: adaptive.Adaptive.h(12)),
                  FilledButton(
                    onPressed: () => setState(() {}),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
            children: [
              // 总览
              _buildOverviewCard(colorScheme, data),
              SizedBox(height: adaptive.Adaptive.h(16)),
              // 按规则
              if (data.byRule.isNotEmpty) ...[
                _buildSectionTitle('按规则', colorScheme),
                SizedBox(height: adaptive.Adaptive.h(8)),
                ...data.byRule.map((rule) => _buildRuleItem(colorScheme, rule)),
                SizedBox(height: adaptive.Adaptive.h(16)),
              ],
              // 按资源
              if (data.bySource.isNotEmpty) ...[
                _buildSectionTitle('按资源', colorScheme),
                SizedBox(height: adaptive.Adaptive.h(8)),
                ...data.bySource.map(
                  (source) => _buildSourceItem(colorScheme, source),
                ),
                SizedBox(height: adaptive.Adaptive.h(16)),
              ],
              // 每日明细
              if (data.daily.isNotEmpty) ...[
                _buildSectionTitle('每日明细', colorScheme),
                SizedBox(height: adaptive.Adaptive.h(8)),
                ...data.daily.map((day) => _buildDailyItem(colorScheme, day)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(
    ColorScheme colorScheme,
    BillingCategoryDetailResponse data,
  ) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data.timeLabel}消费',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(13),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Text(
            '¥${data.totalCostCny.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(28),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(4)),
          Text(
            '共 ${data.totalCount} 次',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(12),
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: adaptive.Adaptive.sp(15),
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildRuleItem(ColorScheme colorScheme, BillingCategoryRuleItem rule) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
        color: _panelColor(colorScheme),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.nameZh,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(2)),
                Text(
                  '${rule.count} 次',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(12),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${rule.costCny.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceItem(
    ColorScheme colorScheme,
    BillingCategorySourceItem source,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
        color: _panelColor(colorScheme),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.sourceTitle.isNotEmpty ? source.sourceTitle : '未命名资源',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(14),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: adaptive.Adaptive.h(2)),
                Text(
                  '${source.count} 次',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(12),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${source.costCny.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyItem(ColorScheme colorScheme, BillingDailyItem day) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
        color: _panelColor(colorScheme),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day.date,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(13),
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '${day.count} 次',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(12),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          Text(
            '¥${day.costCny.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 资源类型组详情页
class BillingSourceGroupDetailPage extends StatelessWidget {
  final TimeMode timeMode;
  final String sourceType;
  final String sourceTypeZh;
  final List<BillingSourceItem> items;

  const BillingSourceGroupDetailPage({
    super.key,
    required this.timeMode,
    required this.sourceType,
    required this.sourceTypeZh,
    required this.items,
  });

  Color _panelColor(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.dark
        ? AppColors.surfaceElevated
        : AppColors.lightSurface;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
appBar: AppNavBar(title: '$sourceTypeZh · ${timeMode.label}'),
      body: ListView(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        children: [
          // 总览
          Container(
            padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
              color: _panelColor(colorScheme),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '共 ${items.length} 个资源',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(13),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(8)),
                Text(
                  '¥${items.fold(0.0, (sum, item) => sum + item.costCny).toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(28),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(16)),
          // 资源列表
          ...items.map(
            (item) => _buildResourceItem(context, colorScheme, item),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceItem(
    BuildContext context,
    ColorScheme colorScheme,
    BillingSourceItem item,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BillingSourceDetailPage(
              timeMode: timeMode,
              sourceType: sourceType,
              sourceCode: item.sourceCode,
              sourceTitle: item.sourceTitle,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
        padding: EdgeInsets.all(adaptive.Adaptive.w(14)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          color: _panelColor(colorScheme),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sourceTitle,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(14),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: adaptive.Adaptive.h(4)),
                  Text(
                    '${item.count} 次',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(12),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '¥${item.costCny.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(14),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: adaptive.Adaptive.w(8)),
            Icon(
              AppIcons.chevronRight,
              size: adaptive.Adaptive.icon(18),
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 单资源详情页
class BillingSourceDetailPage extends StatefulWidget {
  final TimeMode timeMode;
  final String sourceType;
  final String sourceCode;
  final String sourceTitle;

  const BillingSourceDetailPage({
    super.key,
    required this.timeMode,
    required this.sourceType,
    required this.sourceCode,
    required this.sourceTitle,
  });

  @override
  State<BillingSourceDetailPage> createState() =>
      _BillingSourceDetailPageState();
}

class _BillingSourceDetailPageState extends State<BillingSourceDetailPage> {
  late Future<BillingSourceDetailResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = BillingService.fetchSourceDetail(
      sourceType: widget.sourceType,
      sourceCode: widget.sourceCode,
      timeMode: widget.timeMode,
    );
  }

  Color _panelColor(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.dark
        ? AppColors.surfaceElevated
        : AppColors.lightSurface;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
appBar: AppNavBar(title: widget.sourceTitle),
      body: FutureBuilder<BillingSourceDetailResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}'),
                  SizedBox(height: adaptive.Adaptive.h(12)),
                  FilledButton(
                    onPressed: () => setState(() {}),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
            children: [
              // 总览
              _buildOverviewCard(colorScheme, data),
              SizedBox(height: adaptive.Adaptive.h(16)),
              // 按功能分类
              if (data.byCategory.isNotEmpty) ...[
                _buildSectionTitle('按功能', colorScheme),
                SizedBox(height: adaptive.Adaptive.h(8)),
                ...data.byCategory.map(
                  (cat) => _buildCategoryItem(colorScheme, cat),
                ),
                SizedBox(height: adaptive.Adaptive.h(16)),
              ],
              // 每日明细
              if (data.daily.isNotEmpty) ...[
                _buildSectionTitle('每日明细', colorScheme),
                SizedBox(height: adaptive.Adaptive.h(8)),
                ...data.daily.map((day) => _buildDailyItem(colorScheme, day)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(
    ColorScheme colorScheme,
    BillingSourceDetailResponse data,
  ) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data.timeLabel}消费',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(13),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Text(
            '¥${data.totalCostCny.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(28),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(4)),
          Text(
            '共 ${data.totalCount} 次',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(12),
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: adaptive.Adaptive.sp(15),
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildCategoryItem(
    ColorScheme colorScheme,
    BillingSourceCategoryItem cat,
  ) {
    final categoryIcons = {
      'translate': AppIcons.translate,
      'tts': AppIcons.volumeUp,
      'conversation': AppIcons.chat,
      'lookup': AppIcons.search,
      'evaluate': AppIcons.quiz,
    };
    final icon = categoryIcons[cat.category] ?? AppIcons.autoAwesome;

    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
        color: _panelColor(colorScheme),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: adaptive.Adaptive.icon(20),
            color: colorScheme.primary,
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.nameZh,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(2)),
                Text(
                  '${cat.count} 次',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(12),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${cat.costCny.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyItem(ColorScheme colorScheme, BillingDailyItem day) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
        color: _panelColor(colorScheme),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day.date,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(13),
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '${day.count} 次',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(12),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          Text(
            '¥${day.costCny.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(13),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
/// 趋势图绘制器
// ═══════════════════════════════════════════════════════════════
class _TrendPainter extends CustomPainter {
  final List<BillingTrendPoint> points;
  final Color color;

  _TrendPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = math.max(
      0.0001,
      points.map((e) => e.total).fold<double>(0, math.max),
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final path = Path();
    final fillPath = Path();
    final chartHeight = size.height - 28;

    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : (size.width / (points.length - 1)) * i;
      final y = chartHeight - (points[i].total / maxValue) * (chartHeight - 10);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = color);
      final tp = TextPainter(
        text: TextSpan(
          text: points[i].total.toStringAsFixed(2),
          style: TextStyle(color: color, fontSize: adaptive.Adaptive.sp(10)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - 16));
    }

    fillPath.lineTo(size.width, chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
