import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/services/settings_service.dart';

/// 订阅模式
enum SubscriptionMode {
  /// 免费模式
  /// iOS：使用系统原生翻译/OCR/TTS
  /// Android：仅基础播放，无翻译/TTS/OCR
  free,

  /// 付费模式
  /// 使用 DeepSeek AI + 声通评分 + 阿里云TTS
  premium,
}

/// 功能可用性配置
class FeatureAvailability {
  /// 是否显示翻译弹窗
  final bool canTranslate;

  /// 是否可以使用清晰朗读（TTS）
  final bool canTts;

  /// 是否可以OCR识别
  final bool canOcr;

  /// 是否可以跟读评分
  final bool canScoring;

  /// 是否可以使用AI释义
  final bool canAiAnalysis;

  /// 是否可以云同步
  final bool canCloudSync;

  const FeatureAvailability({
    required this.canTranslate,
    required this.canTts,
    required this.canOcr,
    required this.canScoring,
    required this.canAiAnalysis,
    required this.canCloudSync,
  });

  bool get hasAnyPremiumFeature => canScoring || canAiAnalysis || canCloudSync;
}

/// 订阅状态
class SubscriptionState {
  /// 当前模式
  final SubscriptionMode mode;

  /// 付费模式下的余额（分/厘）
  final double balance;

  /// 当前平台
  final bool isIOS;

  /// 功能可用性（由 mode + platform 计算得出）
  FeatureAvailability get features {
    if (mode == SubscriptionMode.premium) {
      return const FeatureAvailability(canTranslate: true, canTts: true, canOcr: true, canScoring: true, canAiAnalysis: true, canCloudSync: true);
    }

    // 免费模式：iOS有原生功能，Android没有
    if (isIOS) {
      return const FeatureAvailability(
        canTranslate: true, // iOS 原生翻译
        canTts: true, // AVSpeechSynthesizer
        canOcr: true, // Vision 框架
        canScoring: false, // 需要声通
        canAiAnalysis: false, // 需要DeepSeek
        canCloudSync: false,
      );
    }

    // Android 免费：几乎只有基础播放
    return const FeatureAvailability(canTranslate: false, canTts: false, canOcr: false, canScoring: false, canAiAnalysis: false, canCloudSync: false);
  }

  const SubscriptionState({this.mode = SubscriptionMode.free, this.balance = 0, this.isIOS = false});

  SubscriptionState copyWith({SubscriptionMode? mode, double? balance, bool? isIOS}) {
    return SubscriptionState(mode: mode ?? this.mode, balance: balance ?? this.balance, isIOS: isIOS ?? this.isIOS);
  }
}

/// 订阅/付费状态管理 Provider
/// 
/// 现在使用 SettingsService 持久化到 config 表，支持多用户隔离。
/// 应用重启后会自动恢复上次的模式设置。
final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier() : super(SubscriptionState(isIOS: Platform.isIOS)) {
    _loadFromStorage(); // 初始化时从持久化存储加载
  }

  /// 从 config 表加载订阅模式
  Future<void> _loadFromStorage() async {
    try {
      final modeStr = await SettingsService.getSubscriptionMode();
      final mode = modeStr == 'premium' ? SubscriptionMode.premium : SubscriptionMode.free;
      if (state.mode != mode) {
        state = state.copyWith(mode: mode);
      }
    } catch (_) {
      // 加载失败时使用默认值
    }
  }

  /// 切换免费/付费模式（自动持久化）
  Future<void> setMode(SubscriptionMode mode) async {
    state = state.copyWith(mode: mode);
    await SettingsService.setSubscriptionMode(mode.name); // 持久化到 config 表
  }

  /// 更新余额
  void setBalance(double balance) {
    state = state.copyWith(balance: balance);
  }

  /// 消耗余额（付费模式下）
  /// 返回是否消耗成功
  bool deductBalance(double amount) {
    if (state.mode != SubscriptionMode.premium) return false;
    if (state.balance < amount) return false;
    state = state.copyWith(balance: state.balance - amount);
    return true;
  }

  /// 刷新余额（从 Supabase user_wallet 拉取）
  Future<void> refreshBalance() async {
    try {
      final client = sb.Supabase.instance.client;
      final data = await client.from('user_wallet').select('balance_cny').single();
      final balance = (data['balance_cny'] as num?)?.toDouble() ?? state.balance;
      state = state.copyWith(balance: balance);
    } catch (_) {
      // 静默失败，保持当前余额
    }
  }
}
