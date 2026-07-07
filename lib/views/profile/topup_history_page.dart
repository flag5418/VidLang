import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/theme/theme.dart';

/// 充值记录项
class TopupRecord {
  final String id;
  final double amountCny;
  final String channel;
  final String status;
  final String createdAt;

  const TopupRecord({
    required this.id,
    required this.amountCny,
    required this.channel,
    required this.status,
    required this.createdAt,
  });

  factory TopupRecord.fromJson(Map<String, dynamic> json) {
    return TopupRecord(
      id: json['id'].toString(),
      amountCny: (json['amount_cny'] as num?)?.toDouble() ?? 0,
      channel: (json['channel'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  String get channelLabel {
    switch (channel) {
      case 'system_grant':
        return '系统赠送';
      case 'iap':
        return 'Apple IAP';
      case 'alipay':
        return '支付宝';
      default:
        return channel;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'success':
        return '成功';
      case 'pending':
        return '处理中';
      case 'failed':
        return '失败';
      default:
        return status;
    }
  }
}

class TopupHistoryPage extends StatefulWidget {
  const TopupHistoryPage({super.key});

  @override
  State<TopupHistoryPage> createState() => _TopupHistoryPageState();
}

class _TopupHistoryPageState extends State<TopupHistoryPage> {
  late Future<List<TopupRecord>> _future;
  double _totalTopup = 0;

  @override
  void initState() {
    super.initState();
    _future = _fetchTopupHistory();
  }

  Future<List<TopupRecord>> _fetchTopupHistory() async {
    AuthService.instance.ensureActiveSession();
    final client = sb.Supabase.instance.client;

    final data = await client
        .from('wallet_ledger')
        .select('id, amount_cny, channel, status, created_at')
        .eq('type', 'topup')
        .order('created_at', ascending: false);

    final records = (data as List)
        .map((e) => TopupRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // 计算累计充值
    _totalTopup = records.fold(0.0, (sum, r) => sum + r.amountCny);

    return records;
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
        title: Text('充值明细', style: TextStyle(fontSize: 16.sp)),
      ),
      body: FutureBuilder<List<TopupRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(colorScheme, '${snapshot.error}');
          }

          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return _buildEmptyState(colorScheme);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _fetchTopupHistory();
              });
            },
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                // 累计充值卡片
                _buildTotalCard(colorScheme),
                SizedBox(height: 16.h),

                // 充值记录列表
                _buildSectionTitle('充值记录', colorScheme),
                SizedBox(height: 12.h),
                ...records.map((record) => _buildRecordItem(colorScheme, record)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalCard(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '累计充值',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '¥${_totalTopup.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildRecordItem(ColorScheme colorScheme, TopupRecord record) {
    // 格式化时间
    String formattedTime = record.createdAt;
    if (record.createdAt.contains('T')) {
      formattedTime = record.createdAt
          .replaceFirst('T', ' ')
          .split('.')
          .first
          .substring(0, 16);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // 金额
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¥${record.amountCny.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '$formattedTime',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // 渠道和状态
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record.channelLabel,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: record.status == 'success'
                      ? Colors.green.withValues(alpha: 0.12)
                      : record.status == 'failed'
                          ? colorScheme.error.withValues(alpha: 0.12)
                          : colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  record.statusLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: record.status == 'success'
                        ? Colors.green
                        : record.status == 'failed'
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48.sp,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: 12.h),
          Text(
            '暂无充值记录',
            style: TextStyle(
              fontSize: 14.sp,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: colorScheme.error),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            FilledButton(
              onPressed: () {
                setState(() {
                  _future = _fetchTopupHistory();
                });
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
