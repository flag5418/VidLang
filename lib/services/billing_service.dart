import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/models/billing_summary.dart';
import 'package:vidlang/services/auth_service.dart';

/// 时间范围模式
enum TimeMode {
  day('day', '今日'),
  week('week', '本周'),
  month('month', '本月'),
  threeMonths('three_months', '近三月');

  final String value;
  final String label;
  const TimeMode(this.value, this.label);
}

class BillingService {
  static Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    AuthService.instance.ensureActiveSession();
    final client = sb.Supabase.instance.client;
    final response = await client.functions.invoke('billing-center', body: body);
    final data = response.data;
    if (data is! Map) {
      throw Exception('账单服务响应异常');
    }
    final map = Map<String, dynamic>.from(data);
    final ok = map['ok'] as bool? ?? false;
    if (!ok) {
      throw Exception(map['message'] as String? ?? map['error'] as String? ?? '账单服务调用失败');
    }
    return map;
  }

  /// 获取总览数据
  static Future<BillingOverview> fetchOverview({
    String? day,
    TimeMode timeMode = TimeMode.day,
    int trendDays = 7,
  }) async {
    final data = await _invoke({
      'op': 'overview',
      'time_mode': timeMode.value,
      if (day?.isNotEmpty ?? false) 'day': day,
      'trend_days': trendDays,
    });
    return BillingOverview.fromJson(data);
  }

  /// 按功能分类聚合
  static Future<BillingByCategoryResponse> fetchByCategory({
    String? day,
    TimeMode timeMode = TimeMode.day,
  }) async {
    final data = await _invoke({
      'op': 'by_category',
      'time_mode': timeMode.value,
      if (day?.isNotEmpty ?? false) 'day': day,
    });
    return BillingByCategoryResponse.fromJson(data);
  }

  /// 单功能详情
  static Future<BillingCategoryDetailResponse> fetchCategoryDetail({
    required String category,
    String? day,
    TimeMode timeMode = TimeMode.day,
  }) async {
    final data = await _invoke({
      'op': 'category_detail',
      'category': category,
      'time_mode': timeMode.value,
      if (day?.isNotEmpty ?? false) 'day': day,
    });
    return BillingCategoryDetailResponse.fromJson(data);
  }

  /// 按资源聚合
  static Future<BillingBySourceResponse> fetchBySource({
    String? day,
    TimeMode timeMode = TimeMode.day,
  }) async {
    final data = await _invoke({
      'op': 'by_source',
      'time_mode': timeMode.value,
      if (day?.isNotEmpty ?? false) 'day': day,
    });
    return BillingBySourceResponse.fromJson(data);
  }

  /// 单资源详情
  static Future<BillingSourceDetailResponse> fetchSourceDetail({
    required String sourceType,
    required String sourceCode,
    String? day,
    TimeMode timeMode = TimeMode.day,
  }) async {
    final data = await _invoke({
      'op': 'source_detail',
      'source_type': sourceType,
      'source_code': sourceCode,
      'time_mode': timeMode.value,
      if (day?.isNotEmpty ?? false) 'day': day,
    });
    return BillingSourceDetailResponse.fromJson(data);
  }

  /// 按action维度的详情
  static Future<BillingActionDetails> fetchActionDetails({
    required String actionKey,
    String? day,
    TimeMode timeMode = TimeMode.day,
  }) async {
    final data = await _invoke({
      'op': 'action_details',
      'action_key': actionKey,
      'time_mode': timeMode.value,
      if (day?.isNotEmpty ?? false) 'day': day,
    });
    return BillingActionDetails.fromJson(data);
  }

  /// 按资源类型的详情
  static Future<BillingResourceTypeDetails> fetchResourceTypeDetails({
    required String resourceType,
    String? day,
    TimeMode timeMode = TimeMode.day,
    String search = '',
  }) async {
    final data = await _invoke({
      'op': 'resource_type_details',
      'resource_type': resourceType,
      'time_mode': timeMode.value,
      if (day?.isNotEmpty ?? false) 'day': day,
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    return BillingResourceTypeDetails.fromJson(data);
  }

  /// 单资源详情（旧接口，保持兼容）
  static Future<BillingResourceDetails> fetchResourceDetails({
    required String resourceType,
    required String resourceCode,
    String? day,
    TimeMode timeMode = TimeMode.day,
  }) async {
    final data = await _invoke({
      'op': 'resource_details',
      'resource_type': resourceType,
      'resource_code': resourceCode,
      'time_mode': timeMode.value,
      if (day?.isNotEmpty ?? false) 'day': day,
    });
    return BillingResourceDetails.fromJson(data);
  }
}
