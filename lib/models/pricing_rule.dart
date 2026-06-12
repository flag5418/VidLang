import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// 计费规则模型
class PricingRule {
  final int? id;
  final String ruleCode;
  final String nameZh;
  final String descriptionZh;
  final String model;
  final double priceCny;
  final String status;
  final DateTime? createdAt;

  const PricingRule({
    this.id,
    required this.ruleCode,
    this.nameZh = '',
    this.descriptionZh = '',
    this.model = '',
    this.priceCny = 0,
    this.status = 'active',
    this.createdAt,
  });

  factory PricingRule.fromJson(Map<String, dynamic> json) {
    return PricingRule(
      id: json['id'] as int?,
      ruleCode: json['rule_code'] as String? ?? '',
      nameZh: json['name_zh'] as String? ?? '',
      descriptionZh: json['description_zh'] as String? ?? '',
      model: json['model'] as String? ?? '',
      priceCny: (json['price_cny'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'rule_code': ruleCode,
    'name_zh': nameZh,
    'description_zh': descriptionZh,
    'model': model,
    'price_cny': priceCny,
    'status': status,
  };

  /// 获取所有活跃的计费规则
  static Future<List<PricingRule>> fetchActive() async {
    try {
      final client = sb.Supabase.instance.client;
      final response = await client.from('pricing_rule').select().eq('status', 'active');
      return (response as List).map((e) => PricingRule.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 按 ruleCode 获取单条规则
  static Future<PricingRule?> fetchByCode(String ruleCode) async {
    try {
      final client = sb.Supabase.instance.client;
      final response = await client.from('pricing_rule').select().eq('rule_code', ruleCode).single();
      return PricingRule.fromJson(response as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 获取多条规则
  static Future<List<PricingRule>> fetchByCodes(List<String> codes) async {
    try {
      final client = sb.Supabase.instance.client;
      final response = await client.from('pricing_rule').select().inFilter('rule_code', codes);
      return (response as List).map((e) => PricingRule.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
