import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/models/topup_config.dart';
import 'package:vidlang/services/auth_service.dart';

/// 充值配置服务
class TopupService {
  static List<TopupConfig>? _cache;

  /// 获取充值档位配置（带内存缓存）
  static Future<List<TopupConfig>> getConfigs() async {
    if (_cache != null && _cache!.isNotEmpty) return _cache!;

    try {
      AuthService.instance.ensureActiveSession();
      final client = sb.Supabase.instance.client;
      final response = await client.functions.invoke('topup-config');
      final data = response.data;

      if (data is Map<String, dynamic> && data['ok'] == true) {
        final configs = (data['configs'] as List)
            .map((e) => TopupConfig.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _cache = configs;
        return configs;
      }
    } catch (_) {}

    // 降级：返回空列表，让 UI 走 loading 状态
    return [];
  }

  /// 强制刷新缓存
  static Future<List<TopupConfig>> refreshConfigs() async {
    _cache = null;
    return getConfigs();
  }

  /// 清除缓存
  static void clearCache() {
    _cache = null;
  }
}
