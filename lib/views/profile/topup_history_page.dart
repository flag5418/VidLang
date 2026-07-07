import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

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
        title: Text('充值明细', style: TextStyle(fontSize: Adaptive.sp(context, 16))),
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
              padding: EdgeInsets.all(Adaptive.w(context, 16)),
              children: [
                // 累计充值卡片
                _buildTotalCard(colorScheme),
                SizedBox(height: Adaptive.h(context, 16)),

                // 充值记录列表
                _buildSectionTitle('充值记录', colorScheme),
                SizedBox(height: Adaptive.h(context, 12)),
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
      padding: EdgeInsets.all(Adaptive.w(context, 20)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Adaptive.r(context, 16)),
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
                  fontSize: Adaptive.sp(context, 13),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: Adaptive.h(context, 4)),
              Text(
                '¥${_totalTopup.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 24),
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
        fontSize: Adaptive.sp(context, 15),
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
      margin: EdgeInsets.only(bottom: Adaptive.h(context, 12)),
      padding: EdgeInsets.all(Adaptive.w(context, 14)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
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
                    fontSize: Adaptive.sp(context, 16),
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: Adaptive.h(context, 4)),
                Text(
                  '$formattedTime',
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 12),
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
                  fontSize: Adaptive.sp(context, 13),
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: Adaptive.h(context, 4)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 8), vertical: Adaptive.h(context, 2)),
                decoration: BoxDecoration(
                  color: record.status == 'success'
                      ? Colors.green.withValues(alpha: 0.12)
                      : record.status == 'failed'
                          ? colorScheme.error.withValues(alpha: 0.12)
                          : colorScheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(Adaptive.r(context, 4)),
                ),
                child: Text(
                  record.statusLabel,
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 11),
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
            AppIcons.receiptLong,
            size: Adaptive.sp(context, 48),
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: Adaptive.h(context, 12)),
          Text(
            '暂无充值记录',
            style: TextStyle(
              fontSize: Adaptive.sp(context, 14),
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
        padding: EdgeInsets.all(Adaptive.w(context, 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.error, size: Adaptive.sp(context, 48), color: colorScheme.error),
            SizedBox(height: Adaptive.h(context, 12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Adaptive.sp(context, 14)),
            ),
            SizedBox(height: Adaptive.h(context, 12)),
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
