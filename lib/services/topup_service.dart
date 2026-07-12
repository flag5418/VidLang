import 'package:flutter/foundation.dart';

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
    } catch (_) {
      debugPrint('[TopupService] 加载充值配置失败，使用兜底数据');
    }

    // 降级：返回硬编码兜底档位
    return _fallbackConfigs();
  }

  /// 硬编码兜底档位（当后端不可用时使用）
  static List<TopupConfig> _fallbackConfigs() {
    return [
      TopupConfig(
        id: -1, originalAmount: 10, actualAmount: 10,
        bonusAmount: 0, label: '体验',
      ),
      TopupConfig(
        id: -2, originalAmount: 50, actualAmount: 55,
        bonusAmount: 5, label: '热门', discountLabel: '送 ¥5',
      ),
      TopupConfig(
        id: -3, originalAmount: 100, actualAmount: 120,
        bonusAmount: 20, label: '最划算', discountLabel: '送 ¥20',
      ),
    ];
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
