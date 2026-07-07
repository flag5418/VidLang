import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 计费规则项
class BillingRule {
  final String ruleCode;
  final String nameZh;
  final String descriptionZh;
  final double priceCny;
  final String category;

  const BillingRule({
    required this.ruleCode,
    required this.nameZh,
    required this.descriptionZh,
    required this.priceCny,
    required this.category,
  });

  factory BillingRule.fromJson(Map<String, dynamic> json) {
    return BillingRule(
      ruleCode: (json['rule_code'] ?? '').toString(),
      nameZh: (json['name_zh'] ?? '').toString(),
      descriptionZh: (json['description_zh'] ?? '').toString(),
      priceCny: (json['price_cny'] as num?)?.toDouble() ?? 0,
      category: _mapCategory(json['rule_code'] as String? ?? ''),
    );
  }

  static String _mapCategory(String ruleCode) {
    if (ruleCode.contains('definition') || ruleCode.contains('word_link')) {
      return '智能查词';
    } else if (ruleCode.contains('translate')) {
      return '翻译';
    } else if (ruleCode.contains('tts')) {
      return 'AI 发音';
    } else if (ruleCode.contains('conversation')) {
      return 'AI 对话';
    } else if (ruleCode.contains('evaluate') || ruleCode.contains('test')) {
      return '评测与测试';
    }
    return '其他';
  }
}

/// 分类分组
class BillingCategory {
  final String name;
  final List<BillingRule> rules;

  const BillingCategory({required this.name, required this.rules});
}

class BillingRulesPage extends StatefulWidget {
  const BillingRulesPage({super.key});

  @override
  State<BillingRulesPage> createState() => _BillingRulesPageState();
}

class _BillingRulesPageState extends State<BillingRulesPage> {
  late Future<List<BillingRule>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchBillingRules();
  }

  Future<List<BillingRule>> _fetchBillingRules() async {
    AuthService.instance.ensureActiveSession();
    final client = sb.Supabase.instance.client;

    final data = await client
        .from('pricing_rule')
        .select('rule_code, name_zh, description_zh, price_cny')
        .eq('status', 'active')
        .order('price_cny', ascending: true);

    return (data as List)
        .map((e) => BillingRule.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<BillingCategory> _groupByCategory(List<BillingRule> rules) {
    final map = <String, List<BillingRule>>{};
    for (final rule in rules) {
      map.putIfAbsent(rule.category, () => []).add(rule);
    }
    // 按固定顺序排列
    final order = ['智能查词', '翻译', 'AI 发音', 'AI 对话', '评测与测试', '其他'];
    final result = <BillingCategory>[];
    for (final name in order) {
      if (map.containsKey(name)) {
        result.add(BillingCategory(name: name, rules: map[name]!));
      }
    }
    return result;
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
        title: Text('计费规则', style: TextStyle(fontSize: Adaptive.sp(context, 16))),
      ),
      body: FutureBuilder<List<BillingRule>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(colorScheme, '${snapshot.error}');
          }

          final rules = snapshot.data ?? [];
          if (rules.isEmpty) {
            return _buildEmptyState(colorScheme);
          }

          final categories = _groupByCategory(rules);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = _fetchBillingRules();
              });
            },
            child: ListView(
              padding: EdgeInsets.all(Adaptive.w(context, 16)),
              children: [
                // 说明文字
                _buildDescriptionCard(colorScheme),
                SizedBox(height: Adaptive.h(context, 16)),

                // 按分类展示
                for (final category in categories) ...[
                  _buildCategorySection(colorScheme, category),
                  SizedBox(height: Adaptive.h(context, 12)),
                ],

                // 底部提示
                _buildFooterNote(colorScheme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDescriptionCard(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.all(Adaptive.w(context, 14)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          Icon(AppIcons.info, size: Adaptive.sp(context, 18), color: colorScheme.primary),
          SizedBox(width: Adaptive.w(context, 10)),
          Expanded(
            child: Text(
              '以下为各项 AI 功能的单次使用费用，价格可能调整，以实际扣费为准。',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 13),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(ColorScheme colorScheme, BillingCategory category) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
        color: _panelColor(colorScheme),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分类标题
          Padding(
            padding: EdgeInsets.only(left: Adaptive.w(context, 16), top: Adaptive.h(context, 14), right: Adaptive.w(context, 16)),
            child: Text(
              '── ${category.name} ──',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 14),
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
          SizedBox(height: Adaptive.h(context, 8)),

          // 规则列表
          for (final rule in category.rules)
            _buildRuleItem(colorScheme, rule),
        ],
      ),
    );
  }

  Widget _buildRuleItem(ColorScheme colorScheme, BillingRule rule) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 16), vertical: Adaptive.h(context, 10)),
      child: Row(
        children: [
          // 规则信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.nameZh,
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 14),
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (rule.descriptionZh.isNotEmpty) ...[
                  SizedBox(height: Adaptive.h(context, 2)),
                  Text(
                    rule.descriptionZh,
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 12),
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: Adaptive.w(context, 12)),
          // 价格
          Container(
            padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 10), vertical: Adaptive.h(context, 4)),
            decoration: BoxDecoration(
              color: rule.priceCny > 0
                  ? colorScheme.primary.withValues(alpha: 0.1)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Adaptive.r(context, 6)),
            ),
            child: Text(
              rule.priceCny > 0 ? '¥${rule.priceCny.toStringAsFixed(2)}/次' : '免费',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 13),
                fontWeight: FontWeight.w600,
                color: rule.priceCny > 0
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNote(ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.only(top: Adaptive.h(context, 8), bottom: Adaptive.h(context, 24)),
      child: Text(
        '价格可能调整，以实际扣费为准。',
        style: TextStyle(
          fontSize: Adaptive.sp(context, 12),
          color: colorScheme.outline,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.rule,
            size: Adaptive.sp(context, 48),
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: Adaptive.h(context, 12)),
          Text(
            '暂无计费规则',
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
                  _future = _fetchBillingRules();
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
