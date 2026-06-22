import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/billing_summary.dart';
import 'package:vidlang/services/billing_service.dart';
import 'package:vidlang/theme/theme.dart';

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  late Future<BillingOverview> _future;

  @override
  void initState() {
    super.initState();
    _future = BillingService.fetchOverview();
  }

  Future<void> _refresh() async {
    final future = BillingService.fetchOverview();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('计费明细', style: TextStyle(fontSize: 16.sp)),
      ),
      body: FutureBuilder<BillingOverview>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: '${snapshot.error}', onRetry: _refresh);
          }
          final overview = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _OverviewCard(overview: overview),
                SizedBox(height: 16.h),
                _SectionCard(
                  title: '近几日趋势',
                  child: _TrendChart(points: overview.trend),
                ),
                SizedBox(height: 16.h),
                _SectionCard(
                  title: 'AI 消费汇总',
                  child: Column(
                    children: [
                      for (final item in overview.actionSummary)
                        _SummaryTile(
                          icon: Icons.auto_awesome_outlined,
                          title: item.label,
                          subtitle: '${item.count} 次',
                          amount: item.total,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BillingActionDetailPage(day: overview.day, actionKey: item.key, actionLabel: item.label),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                _SectionCard(
                  title: '资源消费汇总',
                  child: Column(
                    children: [
                      for (final item in overview.resourceSummary)
                        _SummaryTile(
                          icon: _resourceIcon(item.key),
                          title: item.label,
                          subtitle: '${item.count} 次',
                          amount: item.total,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BillingResourceTypePage(day: overview.day, resourceType: item.key, resourceLabel: item.label),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                _SectionCard(
                  title: '计费规则',
                  child: Column(
                    children: [
                      for (final item in overview.pricingRules)
                        Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nameZh,
                                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      item.ruleCode,
                                      style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: item.isChargeable ? colorScheme.primary.withValues(alpha: 0.12) : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999.r),
                                ),
                                child: Text(
                                  item.isChargeable ? '¥${item.priceCny.toStringAsFixed(4)}' : '免费',
                                  style: TextStyle(fontSize: 12.sp, color: item.isChargeable ? colorScheme.primary : colorScheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _resourceIcon(String resourceType) {
    switch (resourceType) {
      case 'video':
        return Icons.movie_outlined;
      case 'music':
        return Icons.music_note_outlined;
      case 'article':
        return Icons.article_outlined;
      default:
        return Icons.folder_open_outlined;
    }
  }
}

class BillingActionDetailPage extends StatefulWidget {
  final String day;
  final String actionKey;
  final String actionLabel;

  const BillingActionDetailPage({super.key, required this.day, required this.actionKey, required this.actionLabel});

  @override
  State<BillingActionDetailPage> createState() => _BillingActionDetailPageState();
}

class _BillingActionDetailPageState extends State<BillingActionDetailPage> {
  late Future<BillingActionDetails> _future;

  @override
  void initState() {
    super.initState();
    _future = BillingService.fetchActionDetails(actionKey: widget.actionKey, day: widget.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.actionLabel, style: TextStyle(fontSize: 16.sp)),
      ),
      body: FutureBuilder<BillingActionDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: '${snapshot.error}',
              onRetry: () => setState(() {
                _future = BillingService.fetchActionDetails(actionKey: widget.actionKey, day: widget.day);
              }),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _DetailHeader(title: data.action.label, count: data.action.count, total: data.action.total),
              SizedBox(height: 16.h),
              for (final item in data.details) _DetailTile(item: item),
            ],
          );
        },
      ),
    );
  }
}

class BillingResourceTypePage extends StatefulWidget {
  final String day;
  final String resourceType;
  final String resourceLabel;

  const BillingResourceTypePage({super.key, required this.day, required this.resourceType, required this.resourceLabel});

  @override
  State<BillingResourceTypePage> createState() => _BillingResourceTypePageState();
}

class _BillingResourceTypePageState extends State<BillingResourceTypePage> {
  late Future<BillingResourceTypeDetails> _future;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = BillingService.fetchResourceTypeDetails(resourceType: widget.resourceType, day: widget.day);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = BillingService.fetchResourceTypeDetails(resourceType: widget.resourceType, day: widget.day, search: _search);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resourceLabel, style: TextStyle(fontSize: 16.sp)),
      ),
      body: FutureBuilder<BillingResourceTypeDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }
          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _DetailHeader(title: data.resourceLabel, count: data.count, total: data.total),
              SizedBox(height: 12.h),
              TextField(
                controller: _searchController,
                onSubmitted: (value) {
                  _search = value.trim();
                  _reload();
                },
                decoration: InputDecoration(
                  hintText: '搜索资源标题',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _search = '';
                      _reload();
                    },
                    icon: const Icon(Icons.close),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  isDense: true,
                ),
              ),
              SizedBox(height: 16.h),
              _SectionCard(
                title: '文件夹汇总',
                child: Column(
                  children: [
                    for (final item in data.folders)
                      _SummaryTile(icon: Icons.folder_outlined, title: item.label, subtitle: '${item.count} 次', amount: item.total),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _SectionCard(
                title: '资源汇总',
                child: Column(
                  children: [
                    for (final item in data.resources)
                      _SummaryTile(
                        icon: Icons.insert_drive_file_outlined,
                        title: item.label,
                        subtitle: item.folderTitle?.isNotEmpty == true ? item.folderTitle! : '${item.count} 次',
                        amount: item.total,
                        onTap: item.key.isEmpty
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BillingResourceDetailPage(
                                      day: data.day,
                                      resourceType: data.resourceType,
                                      resourceCode: item.key,
                                      resourceTitle: item.label,
                                    ),
                                  ),
                                );
                              },
                      ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                '搜索后会同时过滤文件夹和资源汇总',
                style: TextStyle(fontSize: 12.sp, color: colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

class BillingResourceDetailPage extends StatefulWidget {
  final String day;
  final String resourceType;
  final String resourceCode;
  final String resourceTitle;

  const BillingResourceDetailPage({
    super.key,
    required this.day,
    required this.resourceType,
    required this.resourceCode,
    required this.resourceTitle,
  });

  @override
  State<BillingResourceDetailPage> createState() => _BillingResourceDetailPageState();
}

class _BillingResourceDetailPageState extends State<BillingResourceDetailPage> {
  late Future<BillingResourceDetails> _future;

  @override
  void initState() {
    super.initState();
    _future = BillingService.fetchResourceDetails(resourceType: widget.resourceType, resourceCode: widget.resourceCode, day: widget.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resourceTitle, style: TextStyle(fontSize: 16.sp)),
      ),
      body: FutureBuilder<BillingResourceDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: '${snapshot.error}',
              onRetry: () => setState(() {
                _future = BillingService.fetchResourceDetails(resourceType: widget.resourceType, resourceCode: widget.resourceCode, day: widget.day);
              }),
            );
          }
          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _DetailHeader(title: data.resourceTitle, count: data.count, total: data.total, subtitle: data.folderTitle),
              SizedBox(height: 16.h),
              for (final item in data.details) _DetailTile(item: item),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final BillingOverview overview;

  const _OverviewCard({required this.overview});

  Color _panelColor(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.dark ? AppColors.surfaceElevated : AppColors.lightSurface;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日消费',
            style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 8.h),
          Text(
            '¥${overview.dayTotal.toStringAsFixed(4)}',
            style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6.h),
          Text(
            overview.day,
            style: TextStyle(fontSize: 12.sp, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final String title;
  final int count;
  final double total;
  final String? subtitle;

  const _DetailHeader({required this.title, required this.count, required this.total, this.subtitle});

  Color _panelColor(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.dark ? AppColors.surfaceElevated : AppColors.lightSurface;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
            ),
          ],
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  '次数：$count',
                  style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
                ),
              ),
              Text(
                '¥${total.toStringAsFixed(4)}',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final BillingDetailItem item;

  const _DetailTile({required this.item});

  Color _panelColor(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.dark ? AppColors.surfaceElevated : AppColors.lightSurface;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.resourceTitle.isNotEmpty ? item.resourceTitle : '未命名资源',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '¥${item.costCny.toStringAsFixed(4)}',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _chip(context, item.resourceLabel),
              if (item.folderTitle.isNotEmpty) _chip(context, item.folderTitle),
              if (item.sourcePage.isNotEmpty) _chip(context, item.sourcePage),
              if (item.actionName.isNotEmpty) _chip(context, item.actionName),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '页面：${item.scene}  操作：${item.entry}  时间：${item.createdAt.replaceFirst('T', ' ').split('.').first}',
            style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999.r)),
      child: Text(
        text,
        style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  Color _panelColor(ColorScheme colorScheme) {
    return colorScheme.brightness == Brightness.dark ? AppColors.surfaceElevated : AppColors.lightSurface;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12.h),
          child,
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double amount;
  final VoidCallback? onTap;

  const _SummaryTile({required this.icon, required this.title, required this.subtitle, required this.amount, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12.r)),
              child: Icon(icon, size: 20.sp, color: colorScheme.primary),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              '¥${amount.toStringAsFixed(4)}',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
            ),
            if (onTap != null) ...[SizedBox(width: 8.w), Icon(Icons.chevron_right, size: 18.sp, color: colorScheme.onSurfaceVariant)],
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<BillingTrendPoint> points;

  const _TrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 120.h,
        child: const Center(child: Text('暂无数据')),
      );
    }
    return SizedBox(
      height: 140.h,
      child: CustomPaint(
        painter: _TrendPainter(points: points, color: Theme.of(context).colorScheme.primary),
        child: Padding(
          padding: EdgeInsets.only(top: 112.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final point in points)
                Expanded(
                  child: Text(
                    point.date.substring(5),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.sp, color: Theme.of(context).colorScheme.outline),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          style: TextStyle(color: color, fontSize: 12.sp),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - 18));
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            SizedBox(height: 12.h),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: 12.h),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
