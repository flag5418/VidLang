import 'dart:math' as math;

import 'package:flutter/material.dart';import 'package:vidlang/models/billing_summary.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/services/billing_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/profile/billing_rules_page.dart';


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
  late Future<BillingOverview> _overviewFuture;
  late Future<BillingByCategoryResponse> _categoryFuture;
  late Future<BillingBySourceResponse> _sourceFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _overviewFuture = BillingService.fetchOverview(timeMode: _timeMode);
    _categoryFuture = BillingService.fetchByCategory(timeMode: _timeMode);
    _sourceFuture = BillingService.fetchBySource(timeMode: _timeMode);
  }

  Future<void> _refresh() async {
    _loadData();
    setState(() {});
  }

  void _changeTimeMode(TimeMode mode) {
    setState(() {
      _timeMode = mode;
      _loadData();
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
      appBar: AppBar(
        title: Text('消费明细', style: TextStyle(fontSize: 16)),
        actions: [
          // 计费规则入口
          IconButton(
            icon: Icon(AppIcons.rule, size: 20),
            tooltip: '计费规则',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BillingRulesPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 时间范围选择器
          _buildTimeRangeSelector(colorScheme),
          // 视图模式切换
          _buildViewModeSelector(colorScheme),
          // 内容区域
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildContent(colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(context, 16), vertical: adaptive.Adaptive.h(context, 8)),
      child: Row(
        children: TimeMode.values.map((mode) {
          final isSelected = mode == _timeMode;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changeTimeMode(mode),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(context, 4)),
                padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(context, 8)),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 8)),
                ),
                child: Text(
                  mode.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
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
      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(context, 16), vertical: adaptive.Adaptive.h(context, 4)),
      child: Row(
        children: BillingViewMode.values.map((mode) {
          final isSelected = mode == _viewMode;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changeViewMode(mode),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(context, 4)),
                padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(context, 6)),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      mode.icon,
                      size: 16,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: 4),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
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

  Widget _buildContent(ColorScheme colorScheme) {
    return ListView(
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
      children: [
        // 总览卡片
        FutureBuilder<BillingOverview>(
          future: _overviewFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildErrorCard(colorScheme, '${snapshot.error}');
            }
            final overview = snapshot.data!;
            return _buildOverviewCard(colorScheme, overview);
          },
        ),
        SizedBox(height: 16),

        // 根据视图模式显示内容
        if (_viewMode == BillingViewMode.category)
          _buildCategoryView(colorScheme)
        else
          _buildResourceView(colorScheme),
      ],
    );
  }

  Widget _buildOverviewCard(ColorScheme colorScheme, BillingOverview overview) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 16)),
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
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
              Text(
                '${overview.totalCount} 次',
                style: TextStyle(fontSize: 12, color: colorScheme.outline),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '¥${overview.totalCost.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          // 趋势图
          if (overview.trend.isNotEmpty) _buildTrendChart(colorScheme, overview.trend),
        ],
      ),
    );
  }

  Widget _buildTrendChart(ColorScheme colorScheme, List<BillingTrendPoint> points) {
    if (points.isEmpty) {
      return SizedBox(height: 100, child: const Center(child: Text('暂无数据')));
    }
    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: _TrendPainter(points: points, color: colorScheme.primary),
        child: Padding(
          padding: EdgeInsets.only(top: adaptive.Adaptive.h(context, 92)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final point in points)
                Expanded(
                  child: Text(
                    point.date.substring(5),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: colorScheme.outline),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryView(ColorScheme colorScheme) {
    return FutureBuilder<BillingByCategoryResponse>(
      future: _categoryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorCard(colorScheme, '${snapshot.error}');
        }
        final data = snapshot.data!;
        if (data.categories.isEmpty) {
          return _buildEmptyCard(colorScheme, '暂无消费记录');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('功能分类', colorScheme),
            SizedBox(height: 8),
            ...data.categories.map((cat) => _buildCategoryCard(colorScheme, cat)),
          ],
        );
      },
    );
  }

  Widget _buildCategoryCard(ColorScheme colorScheme, BillingCategoryItem category) {
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
        margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 12)),
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 14)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
          color: _panelColor(colorScheme),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
              ),
              child: Icon(icon, size: 20, color: colorScheme.primary),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.nameZh,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${category.totalCount} 次',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              '¥${category.totalCostCny.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 8),
            Icon(AppIcons.chevronRight, size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildResourceView(ColorScheme colorScheme) {
    return FutureBuilder<BillingBySourceResponse>(
      future: _sourceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorCard(colorScheme, '${snapshot.error}');
        }
        final data = snapshot.data!;
        if (data.sources.isEmpty && data.unknownSourceCostCny <= 0) {
          return _buildEmptyCard(colorScheme, '暂无消费记录');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('资源统计', colorScheme),
            SizedBox(height: 8),
            ...data.sources.map((group) => _buildSourceTypeGroup(colorScheme, group)),
            if (data.unknownSourceCostCny > 0)
              _buildUnknownSourceCard(colorScheme, data.unknownSourceCostCny),
          ],
        );
      },
    );
  }

  Widget _buildSourceTypeGroup(ColorScheme colorScheme, BillingSourceTypeGroup group) {
    final typeIcons = {
      'video': AppIcons.movie,
      'music': AppIcons.musicNote,
      'article': AppIcons.article,
    };
    final icon = typeIcons[group.sourceType] ?? AppIcons.folder;

    return GestureDetector(
      onTap: () => _navigateToSourceDetail(group),
      child: Container(
        margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 12)),
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 14)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
          color: _panelColor(colorScheme),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
              ),
              child: Icon(icon, size: 20, color: colorScheme.primary),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${group.sourceTypeZh} (${group.items.length}个)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${group.items.take(2).map((e) => e.sourceTitle).join("、")}${group.items.length > 2 ? "..." : ""}',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '¥${group.subtotalCny.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 8),
            Icon(AppIcons.chevronRight, size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildUnknownSourceCard(ColorScheme colorScheme, double cost) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 12)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 14)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Icon(AppIcons.help, size: 20, color: colorScheme.onSurfaceVariant),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '未关联资源',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
            ),
          ),
          Text(
            '¥${cost.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildErrorCard(ColorScheme colorScheme, String message) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 20)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
        color: colorScheme.errorContainer.withValues(alpha: 0.3),
      ),
      child: Column(
        children: [
          Icon(AppIcons.error, size: 32, color: colorScheme.error),
          SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colorScheme.onErrorContainer),
          ),
          SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _refresh,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(ColorScheme colorScheme, String message) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 40)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
        color: _panelColor(colorScheme),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.receiptLong,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
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
  State<BillingCategoryDetailPage> createState() => _BillingCategoryDetailPageState();
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
      appBar: AppBar(
        title: Text('${widget.categoryName} · ${widget.timeMode.label}', style: TextStyle(fontSize: 16)),
      ),
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
                  SizedBox(height: 12),
                  FilledButton(onPressed: () => setState(() {}), child: const Text('重试')),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
            children: [
              // 总览
              _buildOverviewCard(colorScheme, data),
              SizedBox(height: 16),
              // 按规则
              if (data.byRule.isNotEmpty) ...[
                _buildSectionTitle('按规则', colorScheme),
                SizedBox(height: 8),
                ...data.byRule.map((rule) => _buildRuleItem(colorScheme, rule)),
                SizedBox(height: 16),
              ],
              // 按资源
              if (data.bySource.isNotEmpty) ...[
                _buildSectionTitle('按资源', colorScheme),
                SizedBox(height: 8),
                ...data.bySource.map((source) => _buildSourceItem(colorScheme, source)),
                SizedBox(height: 16),
              ],
              // 每日明细
              if (data.daily.isNotEmpty) ...[
                _buildSectionTitle('每日明细', colorScheme),
                SizedBox(height: 8),
                ...data.daily.map((day) => _buildDailyItem(colorScheme, day)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(ColorScheme colorScheme, BillingCategoryDetailResponse data) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 16)),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data.timeLabel}消费',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 8),
          Text(
            '¥${data.totalCostCny.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            '共 ${data.totalCount} 次',
            style: TextStyle(fontSize: 12, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
    );
  }

  Widget _buildRuleItem(ColorScheme colorScheme, BillingCategoryRuleItem rule) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 10)),
        color: _panelColor(colorScheme),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.nameZh, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                SizedBox(height: 2),
                Text('${rule.count} 次', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text('¥${rule.costCny.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSourceItem(ColorScheme colorScheme, BillingCategorySourceItem source) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 10)),
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
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text('${source.count} 次', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text('¥${source.costCny.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDailyItem(ColorScheme colorScheme, BillingDailyItem day) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 10)),
        color: _panelColor(colorScheme),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(day.date, style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
          ),
          Text(
            '${day.count} 次',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(width: 12),
          Text(
            '¥${day.costCny.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
      appBar: AppBar(
        title: Text('$sourceTypeZh · ${timeMode.label}', style: TextStyle(fontSize: 16)),
      ),
      body: ListView(
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
        children: [
          // 总览
          Container(
            padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 16)),
              color: _panelColor(colorScheme),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '共 ${items.length} 个资源',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
                SizedBox(height: 8),
                Text(
                  '¥${items.fold(0.0, (sum, item) => sum + item.costCny).toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // 资源列表
          ...items.map((item) => _buildResourceItem(context, colorScheme, item)),
        ],
      ),
    );
  }

  Widget _buildResourceItem(BuildContext context, ColorScheme colorScheme, BillingSourceItem item) {
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
        margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 12)),
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 14)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
          color: _panelColor(colorScheme),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sourceTitle,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${item.count} 次',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              '¥${item.costCny.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 8),
            Icon(AppIcons.chevronRight, size: 18, color: colorScheme.onSurfaceVariant),
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
  State<BillingSourceDetailPage> createState() => _BillingSourceDetailPageState();
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
      appBar: AppBar(
        title: Text(widget.sourceTitle, style: TextStyle(fontSize: 16)),
      ),
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
                  SizedBox(height: 12),
                  FilledButton(onPressed: () => setState(() {}), child: const Text('重试')),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
            children: [
              // 总览
              _buildOverviewCard(colorScheme, data),
              SizedBox(height: 16),
              // 按功能分类
              if (data.byCategory.isNotEmpty) ...[
                _buildSectionTitle('按功能', colorScheme),
                SizedBox(height: 8),
                ...data.byCategory.map((cat) => _buildCategoryItem(colorScheme, cat)),
                SizedBox(height: 16),
              ],
              // 每日明细
              if (data.daily.isNotEmpty) ...[
                _buildSectionTitle('每日明细', colorScheme),
                SizedBox(height: 8),
                ...data.daily.map((day) => _buildDailyItem(colorScheme, day)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(ColorScheme colorScheme, BillingSourceDetailResponse data) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 16)),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data.timeLabel}消费',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 8),
          Text(
            '¥${data.totalCostCny.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            '共 ${data.totalCount} 次',
            style: TextStyle(fontSize: 12, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
    );
  }

  Widget _buildCategoryItem(ColorScheme colorScheme, BillingSourceCategoryItem cat) {
    final categoryIcons = {
      'translate': AppIcons.translate,
      'tts': AppIcons.volumeUp,
      'conversation': AppIcons.chat,
      'lookup': AppIcons.search,
      'evaluate': AppIcons.quiz,
    };
    final icon = categoryIcons[cat.category] ?? AppIcons.autoAwesome;

    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 10)),
        color: _panelColor(colorScheme),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.nameZh, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                SizedBox(height: 2),
                Text('${cat.count} 次', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text('¥${cat.costCny.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDailyItem(ColorScheme colorScheme, BillingDailyItem day) {
    return Container(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(context, 8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 10)),
        color: _panelColor(colorScheme),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(day.date, style: TextStyle(fontSize: 13, color: colorScheme.onSurface)),
          ),
          Text(
            '${day.count} 次',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(width: 12),
          Text(
            '¥${day.costCny.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
    final maxValue = math.max(0.0001, points.map((e) => e.total).fold<double>(0, math.max));
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
      final x = points.length == 1 ? size.width / 2 : (size.width / (points.length - 1)) * i;
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
          style: TextStyle(color: color, fontSize: 10),
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
