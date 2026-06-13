class BillingTrendPoint {
  final String date;
  final double total;

  const BillingTrendPoint({required this.date, required this.total});

  factory BillingTrendPoint.fromJson(Map<String, dynamic> json) {
    return BillingTrendPoint(
      date: json['date'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
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
      count: (json['count'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      folderCode: json['folder_code'] as String?,
      folderTitle: json['folder_title'] as String?,
    );
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
      priceCny: (json['price_cny'] as num?)?.toDouble() ?? 0,
      isChargeable: json['is_chargeable'] as bool? ?? false,
    );
  }
}

class BillingOverview {
  final String day;
  final double dayTotal;
  final List<BillingTrendPoint> trend;
  final List<BillingSummaryItem> actionSummary;
  final List<BillingSummaryItem> resourceSummary;
  final List<BillingRuleItem> pricingRules;

  const BillingOverview({
    required this.day,
    required this.dayTotal,
    required this.trend,
    required this.actionSummary,
    required this.resourceSummary,
    required this.pricingRules,
  });

  factory BillingOverview.fromJson(Map<String, dynamic> json) {
    return BillingOverview(
      day: json['day'] as String? ?? '',
      dayTotal: (json['day_total'] as num?)?.toDouble() ?? 0,
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
      costCny: (json['cost_cny'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] as String? ?? '',
    );
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
      count: (summary['count'] as num?)?.toInt() ?? 0,
      total: (summary['total'] as num?)?.toDouble() ?? 0,
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
      count: (resource['count'] as num?)?.toInt() ?? 0,
      total: (resource['total'] as num?)?.toDouble() ?? 0,
      details: ((json['details'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => BillingDetailItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
