/// 学习统计二级详情页基础组件
///
/// 提供统一的页面结构、时间筛选器、趋势图、统计卡片等共享组件。
library;

import 'package:flutter/material.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

// ============================================================
// 时间范围枚举
// ============================================================

enum TimeRange {
  sevenDays('7d', '近7天'),
  thirtyDays('30d', '近30天'),
  ninetyDays('90d', '近90天'),
  year('year', '今年'),
  all('all', '全部');

  final String value;
  final String label;

  const TimeRange(this.value, this.label);

  static TimeRange fromValue(String value) {
    return TimeRange.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TimeRange.sevenDays,
    );
  }
}

// ============================================================
// 统一详情页框架
// ============================================================

abstract class StatsDetailPage extends StatefulWidget {
  final String title;
  final IconData icon;
  final String timeRange;

  const StatsDetailPage({
    super.key,
    required this.title,
    required this.icon,
    this.timeRange = '7d',
  });
}

abstract class StatsDetailPageState<T extends StatsDetailPage> extends State<T> {
  late String _currentTimeRange;
  bool _isLoading = true;

  String get currentTimeRange => _currentTimeRange;
  bool get isLoading => _isLoading;

  @override
  void initState() {
    super.initState();
    _currentTimeRange = widget.timeRange;
    loadData();
  }

  Future<void> loadData() async {
    setState(() => _isLoading = true);
    try {
      await fetchData(_currentTimeRange);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> fetchData(String timeRange);

  void onTimeRangeChanged(String value) {
    if (_currentTimeRange == value) return;
    setState(() => _currentTimeRange = value);
    loadData();
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: adaptive.Adaptive.sp(18), color: colorScheme.primary),
            SizedBox(width: adaptive.Adaptive.w(8)),
            Text(
              widget.title,
              style: TextStyle(fontSize: adaptive.Adaptive.sp(17), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
          ],
        ),
        actions: [
          _buildTimeRangeSelector(colorScheme),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(adaptive.Adaptive.w(AppSpacing.md)),
              child: buildContent(context, colorScheme),
            ),
    );
  }

  Widget buildContent(BuildContext context, ColorScheme colorScheme);

  Widget _buildTimeRangeSelector(ColorScheme colorScheme) {
    return PopupMenuButton<String>(
      initialValue: _currentTimeRange,
      onSelected: onTimeRangeChanged,
      offset: Offset(0, adaptive.Adaptive.h(40)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12))),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              TimeRange.fromValue(_currentTimeRange).label,
              style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.primary, fontWeight: FontWeight.w500),
            ),
            SizedBox(width: adaptive.Adaptive.w(4)),
            Icon(AppIcons.expandMore, size: adaptive.Adaptive.sp(16), color: colorScheme.primary),
          ],
        ),
      ),
      itemBuilder: (context) => TimeRange.values.map((range) {
        final isSelected = range.value == _currentTimeRange;
        return PopupMenuItem<String>(
          value: range.value,
          child: Row(
            children: [
              if (isSelected)
                Icon(AppIcons.check, size: adaptive.Adaptive.sp(16), color: colorScheme.primary)
              else
                SizedBox(width: adaptive.Adaptive.w(16)),
              SizedBox(width: adaptive.Adaptive.w(8)),
              Text(
                range.label,
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(14),
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================
// 共享组件
// ============================================================

/// 区域标题
Widget sectionTitle(String title, IconData icon, ColorScheme colorScheme) {
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

/// 统计卡片容器
Widget statsCard({required Widget child, ColorScheme? colorScheme}) {
  final cs = colorScheme;
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
      color: cs?.surface ?? Colors.white,
      boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: adaptive.Adaptive.w(10), offset: const Offset(0, 4))],
      border: Border.all(color: (cs?.outlineVariant ?? Colors.grey).withValues(alpha: 0.3), width: 0.5),
    ),
    child: child,
  );
}

/// 单个统计项
Widget statItem(String label, String value, ColorScheme colorScheme, {String? suffix, Color? valueColor}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: adaptive.Adaptive.sp(12), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
      ),
      SizedBox(height: adaptive.Adaptive.h(4)),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: adaptive.Adaptive.sp(22), fontWeight: FontWeight.bold, color: valueColor ?? colorScheme.onSurface, height: 1.1),
          ),
          if (suffix != null && suffix.isNotEmpty) ...[
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
    ],
  );
}

/// 横向统计行（4列）
Widget statsRow(List<Widget> children, ColorScheme colorScheme) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
      color: colorScheme.surface,
      boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.02), blurRadius: adaptive.Adaptive.w(10), offset: const Offset(0, 4))],
      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Row(
      children: children.map((child) => Expanded(child: child)).toList(),
    ),
  );
}

/// 柱状图（用于时长/单词趋势）
Widget barChart({
  required Map<String, int> data,
  required ColorScheme colorScheme,
  String? unit,
  double maxHeight = 120,
}) {
  if (data.isEmpty) {
    return SizedBox(
      height: adaptive.Adaptive.h(maxHeight + 40),
      child: Center(
        child: Text('暂无数据', style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant)),
      ),
    );
  }

  final sortedEntries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final maxValue = sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

  return SizedBox(
    height: adaptive.Adaptive.h(maxHeight + 40),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: sortedEntries.map((entry) {
        final ratio = maxValue > 0 ? entry.value / maxValue : 0.0;
        final barHeight = (adaptive.Adaptive.h(maxHeight) * ratio).clamp(adaptive.Adaptive.h(4), adaptive.Adaptive.h(maxHeight));
        final dateStr = entry.key.substring(5); // MM-DD

        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (entry.value > 0) ...[
                  Text(
                    unit != null ? '${entry.value}$unit' : '${entry.value}',
                    style: TextStyle(fontSize: adaptive.Adaptive.sp(9), fontWeight: FontWeight.w600, color: colorScheme.primary),
                  ),
                  SizedBox(height: adaptive.Adaptive.h(4)),
                ],
                Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(adaptive.Adaptive.r(4))),
                    gradient: entry.value > 0
                        ? LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [colorScheme.primary.withValues(alpha: 0.6), colorScheme.primary],
                          )
                        : null,
                    color: entry.value > 0 ? null : colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(6)),
                Text(dateStr, style: TextStyle(fontSize: adaptive.Adaptive.sp(9), color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );
}

/// 折线图（用于跟读/评测趋势）
Widget lineChart({
  required Map<String, double> data,
  required ColorScheme colorScheme,
  String? unit,
  double maxHeight = 120,
}) {
  if (data.isEmpty) {
    return SizedBox(
      height: adaptive.Adaptive.h(maxHeight + 40),
      child: Center(
        child: Text('暂无数据', style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant)),
      ),
    );
  }

  final sortedEntries = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final maxValue = sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
  final minValue = sortedEntries.map((e) => e.value).reduce((a, b) => a < b ? a : b);
  final range = (maxValue - minValue).clamp(1.0, double.infinity);

  return SizedBox(
    height: adaptive.Adaptive.h(maxHeight + 40),
    child: CustomPaint(
      size: Size(double.infinity, adaptive.Adaptive.h(maxHeight + 40)),
      painter: _LineChartPainter(
        data: sortedEntries,
        maxValue: maxValue,
        minValue: minValue,
        range: range,
        color: colorScheme.primary,
        gridColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
        textColor: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _LineChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  final double maxValue;
  final double minValue;
  final double range;
  final Color color;
  final Color gridColor;
  final Color textColor;

  _LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.minValue,
    required this.range,
    required this.color,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final padding = 8.0;
    final chartHeight = size.height - 30;
    final chartWidth = size.width - padding * 2;
    final stepX = chartWidth / (data.length - 1);

    // 绘制网格线
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (int i = 0; i <= 3; i++) {
      final y = chartHeight * i / 3;
      canvas.drawLine(Offset(padding, y), Offset(size.width - padding, y), gridPaint);
    }

    // 绘制折线
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = padding + stepX * i;
      final normalizedValue = (data[i].value - minValue) / range;
      final y = chartHeight - (normalizedValue * chartHeight * 0.8 + chartHeight * 0.1);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // 绘制数据点
      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 3, pointPaint);

      // 绘制数值标签
      final textPainter = TextPainter(
        text: TextSpan(
          text: data[i].value.toStringAsFixed(0),
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 16));
    }

    fillPath.lineTo(padding + stepX * (data.length - 1), chartHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // 绘制X轴标签
    for (int i = 0; i < data.length; i++) {
      final x = padding + stepX * i;
      final dateStr = data[i].key.substring(5);
      final textPainter = TextPainter(
        text: TextSpan(text: dateStr, style: TextStyle(color: textColor, fontSize: 9)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 资源排行列表项
Widget resourceRankingItem({
  required String title,
  required String subtitle,
  required String trailing,
  required IconData icon,
  required ColorScheme colorScheme,
  String? aiInsight,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(10)),
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(adaptive.Adaptive.w(8)),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
                ),
                child: Icon(icon, size: adaptive.Adaptive.w(18), color: colorScheme.primary),
              ),
              SizedBox(width: adaptive.Adaptive.w(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(15), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: adaptive.Adaptive.h(2)),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(12), color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                trailing,
                style: TextStyle(fontSize: adaptive.Adaptive.sp(14), fontWeight: FontWeight.bold, color: colorScheme.primary),
              ),
            ],
          ),
          if (aiInsight != null && aiInsight.isNotEmpty) ...[
            SizedBox(height: adaptive.Adaptive.h(10)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(12), vertical: adaptive.Adaptive.h(8)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
                color: colorScheme.primary.withValues(alpha: 0.05),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.lightbulb, size: adaptive.Adaptive.sp(14), color: colorScheme.primary.withValues(alpha: 0.7)),
                  SizedBox(width: adaptive.Adaptive.w(6)),
                  Expanded(
                    child: Text(
                      aiInsight,
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(12), color: colorScheme.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// 习惯分析项
Widget habitAnalysisItem(String text, ColorScheme colorScheme) {
  return Padding(
    padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: adaptive.Adaptive.w(6),
          height: adaptive.Adaptive.w(6),
          margin: EdgeInsets.only(top: adaptive.Adaptive.h(6)),
          decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
        ),
        SizedBox(width: adaptive.Adaptive.w(10)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: adaptive.Adaptive.sp(13), color: colorScheme.onSurfaceVariant, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

/// 空状态
Widget emptyState(String message, ColorScheme colorScheme) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(48)),
    child: Column(
      children: [
        Icon(AppIcons.showChart, size: adaptive.Adaptive.sp(48), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
        SizedBox(height: adaptive.Adaptive.h(16)),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
        ),
      ],
    ),
  );
}
