class BillingTrendPoint {
  final String date;
  final double total;

  const BillingTrendPoint({required this.date, required this.total});

  factory BillingTrendPoint.fromJson(Map<String, dynamic> json) {
    return BillingTrendPoint(
      date: json['date'] as String? ?? '',
      total: _toDouble(json['total']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class BillingSummaryItem {
  final String key;
  final String label;
  final int count;
  final double total;
  final String? folderCode;
  final String? folderTitle;

  const BillingSummaryItem({
    required this.key,
    required this.label,
    required this.count,
    required this.total,
    this.folderCode,
    this.folderTitle,
  });

  factory BillingSummaryItem.fromJson(Map<String, dynamic> json) {
    return BillingSummaryItem(
      key: (json['key'] ?? json['resource_code'] ?? json['folder_code'] ?? '').toString(),
      label: (json['label'] ?? json['resource_title'] ?? json['folder_title'] ?? '').toString(),
      count: _toInt(json['count']) ?? 0,
      total: _toDouble(json['total']) ?? 0,
      folderCode: json['folder_code'] as String?,
      folderTitle: json['folder_title'] as String?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class BillingRuleItem {
  final String ruleCode;
  final String nameZh;
  final double priceCny;
  final bool isChargeable;

  const BillingRuleItem({
    required this.ruleCode,
    required this.nameZh,
    required this.priceCny,
    required this.isChargeable,
  });

  factory BillingRuleItem.fromJson(Map<String, dynamic> json) {
    return BillingRuleItem(
      ruleCode: json['rule_code'] as String? ?? '',
      nameZh: json['name_zh'] as String? ?? '',
      priceCny: _toDouble(json['price_cny']) ?? 0,
      isChargeable: json['is_chargeable'] as bool? ?? false,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class BillingOverview {
  final String timeLabel;
  final double totalCost;
  final int totalCount;
  final List<BillingTrendPoint> trend;
  final List<BillingSummaryItem> actionSummary;
  final List<BillingSummaryItem> resourceSummary;
  final List<BillingRuleItem> pricingRules;

  const BillingOverview({
    required this.timeLabel,
    required this.totalCost,
    required this.totalCount,
    required this.trend,
    required this.actionSummary,
    required this.resourceSummary,
    required this.pricingRules,
  });

  factory BillingOverview.fromJson(Map<String, dynamic> json) {
    return BillingOverview(
      timeLabel: json['time_label'] as String? ?? '',
      totalCost: _toDouble(json['total_cost']) ?? 0,
      totalCount: _toInt(json['total_count']) ?? 0,
      trend: ((json['trend'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingTrendPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      actionSummary: ((json['action_summary'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingSummaryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      resourceSummary: ((json['resource_summary'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingSummaryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pricingRules: ((json['pricing_rules'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingRuleItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class BillingDetailItem {
  final String id;
  final String ruleCode;
  final String ruleName;
  final String actionKey;
  final String actionLabel;
  final String resourceType;
  final String resourceLabel;
  final String resourceCode;
  final String resourceTitle;
  final String folderCode;
  final String folderTitle;
  final String scene;
  final String entry;
  final String sourcePage;
  final String actionName;
  final double costCny;
  final String createdAt;

  const BillingDetailItem({
    required this.id,
    required this.ruleCode,
    required this.ruleName,
    required this.actionKey,
    required this.actionLabel,
    required this.resourceType,
    required this.resourceLabel,
    required this.resourceCode,
    required this.resourceTitle,
    required this.folderCode,
    required this.folderTitle,
    required this.scene,
    required this.entry,
    required this.sourcePage,
    required this.actionName,
    required this.costCny,
    required this.createdAt,
  });

  factory BillingDetailItem.fromJson(Map<String, dynamic> json) {
    return BillingDetailItem(
      id: json['id'].toString(),
      ruleCode: json['rule_code'] as String? ?? '',
      ruleName: json['rule_name'] as String? ?? '',
      actionKey: json['action_key'] as String? ?? '',
      actionLabel: json['action_label'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? '',
      resourceLabel: json['resource_label'] as String? ?? '',
      resourceCode: json['resource_code'] as String? ?? '',
      resourceTitle: json['resource_title'] as String? ?? '',
      folderCode: json['folder_code'] as String? ?? '',
      folderTitle: json['folder_title'] as String? ?? '',
      scene: json['scene'] as String? ?? '',
      entry: json['entry'] as String? ?? '',
      sourcePage: json['source_page'] as String? ?? '',
      actionName: json['action_name'] as String? ?? '',
      costCny: _toDouble(json['cost_cny']) ?? 0,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class BillingActionDetails {
  final String day;
  final BillingSummaryItem action;
  final List<BillingDetailItem> details;

  const BillingActionDetails({
    required this.day,
    required this.action,
    required this.details,
  });

  factory BillingActionDetails.fromJson(Map<String, dynamic> json) {
    final actionJson = Map<String, dynamic>.from((json['action'] as Map?) ?? const {});
    return BillingActionDetails(
      day: json['day'] as String? ?? '',
      action: BillingSummaryItem.fromJson(actionJson),
      details: ((json['details'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingDetailItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class BillingResourceTypeDetails {
  final String day;
  final String resourceType;
  final String resourceLabel;
  final int count;
  final double total;
  final List<BillingSummaryItem> folders;
  final List<BillingSummaryItem> resources;

  const BillingResourceTypeDetails({
    required this.day,
    required this.resourceType,
    required this.resourceLabel,
    required this.count,
    required this.total,
    required this.folders,
    required this.resources,
  });

  factory BillingResourceTypeDetails.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from((json['summary'] as Map?) ?? const {});
    return BillingResourceTypeDetails(
      day: json['day'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? '',
      resourceLabel: json['resource_label'] as String? ?? '',
      count: _toInt(summary['count']) ?? 0,
      total: _toDouble(summary['total']) ?? 0,
      folders: ((json['folders'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingSummaryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      resources: ((json['resources'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingSummaryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class BillingResourceDetails {
  final String day;
  final String resourceType;
  final String resourceLabel;
  final String resourceCode;
  final String resourceTitle;
  final String folderCode;
  final String folderTitle;
  final int count;
  final double total;
  final List<BillingDetailItem> details;

  const BillingResourceDetails({
    required this.day,
    required this.resourceType,
    required this.resourceLabel,
    required this.resourceCode,
    required this.resourceTitle,
    required this.folderCode,
    required this.folderTitle,
    required this.count,
    required this.total,
    required this.details,
  });

  factory BillingResourceDetails.fromJson(Map<String, dynamic> json) {
    final resource = Map<String, dynamic>.from((json['resource'] as Map?) ?? const {});
    return BillingResourceDetails(
      day: json['day'] as String? ?? '',
      resourceType: resource['resource_type'] as String? ?? '',
      resourceLabel: resource['resource_label'] as String? ?? '',
      resourceCode: resource['resource_code'] as String? ?? '',
      resourceTitle: resource['resource_title'] as String? ?? '',
      folderCode: resource['folder_code'] as String? ?? '',
      folderTitle: resource['folder_title'] as String? ?? '',
      count: _toInt(resource['count']) ?? 0,
      total: _toDouble(resource['total']) ?? 0,
      details: ((json['details'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingDetailItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 按功能分类聚合 - 规则项
class BillingCategoryRuleItem {
  final String ruleCode;
  final String nameZh;
  final double costCny;
  final int count;

  const BillingCategoryRuleItem({
    required this.ruleCode,
    required this.nameZh,
    required this.costCny,
    required this.count,
  });

  factory BillingCategoryRuleItem.fromJson(Map<String, dynamic> json) {
    return BillingCategoryRuleItem(
      ruleCode: json['rule_code'] as String? ?? '',
      nameZh: json['name_zh'] as String? ?? '',
      costCny: _toDouble(json['cost_cny'] ?? json['cost']) ?? 0,
      count: _toInt(json['count']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 按功能分类聚合 - 资源项
class BillingCategorySourceItem {
  final String sourceType;
  final String sourceCode;
  final String sourceTitle;
  final double costCny;
  final int count;

  const BillingCategorySourceItem({
    required this.sourceType,
    required this.sourceCode,
    required this.sourceTitle,
    required this.costCny,
    required this.count,
  });

  factory BillingCategorySourceItem.fromJson(Map<String, dynamic> json) {
    return BillingCategorySourceItem(
      sourceType: json['source_type'] as String? ?? '',
      sourceCode: json['source_code'] as String? ?? '',
      sourceTitle: json['source_title'] as String? ?? '',
      costCny: _toDouble(json['cost_cny'] ?? json['cost']) ?? 0,
      count: _toInt(json['count']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 按功能分类聚合 - 分类项
class BillingCategoryItem {
  final String category;
  final String nameZh;
  final double totalCostCny;
  final int totalCount;
  final List<BillingCategoryRuleItem> byRule;
  final List<BillingCategorySourceItem> bySource;

  const BillingCategoryItem({
    required this.category,
    required this.nameZh,
    required this.totalCostCny,
    required this.totalCount,
    required this.byRule,
    required this.bySource,
  });

  factory BillingCategoryItem.fromJson(Map<String, dynamic> json) {
    return BillingCategoryItem(
      category: json['category'] as String? ?? '',
      nameZh: json['name_zh'] as String? ?? '',
      totalCostCny: _toDouble(json['total_cost_cny'] ?? json['total']) ?? 0,
      totalCount: _toInt(json['total_count'] ?? json['count']) ?? 0,
      byRule: ((json['by_rule'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingCategoryRuleItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      bySource: ((json['by_source'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingCategorySourceItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 按功能分类聚合响应
class BillingByCategoryResponse {
  final String timeLabel;
  final double totalCost;
  final int totalCount;
  final List<BillingCategoryItem> categories;

  const BillingByCategoryResponse({
    required this.timeLabel,
    required this.totalCost,
    required this.totalCount,
    required this.categories,
  });

  factory BillingByCategoryResponse.fromJson(Map<String, dynamic> json) {
    return BillingByCategoryResponse(
      timeLabel: json['time_label'] as String? ?? '',
      totalCost: _toDouble(json['total_cost']) ?? 0,
      totalCount: _toInt(json['total_count']) ?? 0,
      categories: ((json['categories'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingCategoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 单功能详情 - 日聚合
class BillingDailyItem {
  final String date;
  final double costCny;
  final int count;

  const BillingDailyItem({
    required this.date,
    required this.costCny,
    required this.count,
  });

  factory BillingDailyItem.fromJson(Map<String, dynamic> json) {
    return BillingDailyItem(
      date: json['date'] as String? ?? '',
      costCny: _toDouble(json['cost_cny'] ?? json['cost']) ?? 0,
      count: _toInt(json['count']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 单功能详情响应
class BillingCategoryDetailResponse {
  final String timeLabel;
  final String category;
  final String nameZh;
  final double totalCostCny;
  final int totalCount;
  final List<BillingCategoryRuleItem> byRule;
  final List<BillingCategorySourceItem> bySource;
  final List<BillingDailyItem> daily;

  const BillingCategoryDetailResponse({
    required this.timeLabel,
    required this.category,
    required this.nameZh,
    required this.totalCostCny,
    required this.totalCount,
    required this.byRule,
    required this.bySource,
    required this.daily,
  });

  factory BillingCategoryDetailResponse.fromJson(Map<String, dynamic> json) {
    return BillingCategoryDetailResponse(
      timeLabel: json['time_label'] as String? ?? '',
      category: json['category'] as String? ?? '',
      nameZh: json['name_zh'] as String? ?? '',
      totalCostCny: _toDouble(json['total_cost_cny'] ?? json['total']) ?? 0,
      totalCount: _toInt(json['total_count'] ?? json['count']) ?? 0,
      byRule: ((json['by_rule'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingCategoryRuleItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      bySource: ((json['by_source'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingCategorySourceItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      daily: ((json['daily'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingDailyItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 按资源聚合 - 资源项
class BillingSourceItem {
  final String sourceCode;
  final String sourceTitle;
  final double costCny;
  final int count;

  const BillingSourceItem({
    required this.sourceCode,
    required this.sourceTitle,
    required this.costCny,
    required this.count,
  });

  factory BillingSourceItem.fromJson(Map<String, dynamic> json) {
    return BillingSourceItem(
      sourceCode: json['source_code'] as String? ?? '',
      sourceTitle: json['source_title'] as String? ?? '未命名资源',
      costCny: _toDouble(json['cost_cny'] ?? json['cost']) ?? 0,
      count: _toInt(json['count']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 按资源聚合 - 资源类型组
class BillingSourceTypeGroup {
  final String sourceType;
  final String sourceTypeZh;
  final List<BillingSourceItem> items;
  final double subtotalCny;

  const BillingSourceTypeGroup({
    required this.sourceType,
    required this.sourceTypeZh,
    required this.items,
    required this.subtotalCny,
  });

  factory BillingSourceTypeGroup.fromJson(Map<String, dynamic> json) {
    return BillingSourceTypeGroup(
      sourceType: json['source_type'] as String? ?? '',
      sourceTypeZh: json['source_type_zh'] as String? ?? '',
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingSourceItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      subtotalCny: _toDouble(json['subtotal_cny']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// 按资源聚合响应
class BillingBySourceResponse {
  final String timeLabel;
  final double totalCost;
  final int totalCount;
  final List<BillingSourceTypeGroup> sources;
  final double unknownSourceCostCny;

  const BillingBySourceResponse({
    required this.timeLabel,
    required this.totalCost,
    required this.totalCount,
    required this.sources,
    required this.unknownSourceCostCny,
  });

  factory BillingBySourceResponse.fromJson(Map<String, dynamic> json) {
    return BillingBySourceResponse(
      timeLabel: json['time_label'] as String? ?? '',
      totalCost: _toDouble(json['total_cost']) ?? 0,
      totalCount: _toInt(json['total_count']) ?? 0,
      sources: ((json['sources'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingSourceTypeGroup.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      unknownSourceCostCny: _toDouble(json['unknown_source_cost_cny']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 单资源详情 - 功能分类聚合
class BillingSourceCategoryItem {
  final String category;
  final String nameZh;
  final double costCny;
  final int count;

  const BillingSourceCategoryItem({
    required this.category,
    required this.nameZh,
    required this.costCny,
    required this.count,
  });

  factory BillingSourceCategoryItem.fromJson(Map<String, dynamic> json) {
    return BillingSourceCategoryItem(
      category: json['category'] as String? ?? '',
      nameZh: json['name_zh'] as String? ?? '',
      costCny: _toDouble(json['cost_cny'] ?? json['cost']) ?? 0,
      count: _toInt(json['count']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// 单资源详情响应
class BillingSourceDetailResponse {
  final String timeLabel;
  final String sourceType;
  final String sourceCode;
  final String sourceTitle;
  final double totalCostCny;
  final int totalCount;
  final List<BillingSourceCategoryItem> byCategory;
  final List<BillingDailyItem> daily;

  const BillingSourceDetailResponse({
    required this.timeLabel,
    required this.sourceType,
    required this.sourceCode,
    required this.sourceTitle,
    required this.totalCostCny,
    required this.totalCount,
    required this.byCategory,
    required this.daily,
  });

  factory BillingSourceDetailResponse.fromJson(Map<String, dynamic> json) {
    return BillingSourceDetailResponse(
      timeLabel: json['time_label'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? '',
      sourceCode: json['source_code'] as String? ?? '',
      sourceTitle: json['source_title'] as String? ?? '未命名资源',
      totalCostCny: _toDouble(json['total_cost_cny'] ?? json['total']) ?? 0,
      totalCount: _toInt(json['total_count'] ?? json['count']) ?? 0,
      byCategory: ((json['by_category'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingSourceCategoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      daily: ((json['daily'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingDailyItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

