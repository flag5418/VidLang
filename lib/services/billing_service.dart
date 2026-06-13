import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/models/billing_summary.dart';
import 'package:vidlang/services/auth_service.dart';

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

  static Future<BillingOverview> fetchOverview({String? day, int trendDays = 7}) async {
    final data = await _invoke({'op': 'overview', if (day?.isNotEmpty ?? false) 'day': day, 'trend_days': trendDays});
    return BillingOverview.fromJson(data);
  }

  static Future<BillingActionDetails> fetchActionDetails({required String actionKey, required String day}) async {
    final data = await _invoke({'op': 'action_details', 'action_key': actionKey, 'day': day});
    return BillingActionDetails.fromJson(data);
  }

  static Future<BillingResourceTypeDetails> fetchResourceTypeDetails({required String resourceType, required String day, String search = ''}) async {
    final data = await _invoke({
      'op': 'resource_type_details',
      'resource_type': resourceType,
      'day': day,
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    return BillingResourceTypeDetails.fromJson(data);
  }

  static Future<BillingResourceDetails> fetchResourceDetails({
    required String resourceType,
    required String resourceCode,
    required String day,
  }) async {
    final data = await _invoke({'op': 'resource_details', 'resource_type': resourceType, 'resource_code': resourceCode, 'day': day});
    return BillingResourceDetails.fromJson(data);
  }
}
