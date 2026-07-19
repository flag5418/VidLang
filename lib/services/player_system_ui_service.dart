import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 播放器系统 UI 管理服务
///
/// ⚠️ **已废弃 (Deprecated)** - 推荐使用 [AppRouterManager]
///
/// **迁移说明**：
/// - `enterPlayer()` / `exitPlayer()` → 由 `AppRouterManager` 的 `NavigatorObserver` 自动处理
/// - `toggleFullscreen()` → 使用 `AppRouterManager.handleOrientationChange()`
/// - 屏幕常亮 → 由 `AppRouterManager` 的 `PageConfiguration.keepScreenOn` 自动管理
///
/// **为什么废弃**：
/// 1. 每个页面手动调用 enterPlayer/exitPlayer 容易遗漏
/// 2. 无法统一管理屏幕常亮（wakelock）
/// 3. 与路由生命周期耦合不够紧密
///
/// **新架构优势**：
/// - ✅ 全局单例 + NavigatorObserver，自动监听路由变化
/// - ✅ 声明式配置（PageConfiguration），集中管理方向/UI/常亮
/// - ✅ 自动恢复：退出播放器时自动恢复竖屏+关闭常亮
/// - ✅ 可扩展：未来其他页面也可使用（如全屏图片查看器）
///
/// **参考**：[AppRouterManager] (`lib/services/app_router_manager.dart`)
@Deprecated('Use AppRouterManager instead. See migration guide in class doc.')
class PlayerSystemUIService {
  PlayerSystemUIService._();

  static final PlayerSystemUIService instance = PlayerSystemUIService._();

  // ─── 去重缓存 ──────────────────────────────────────

  /// 最近一次应用的方向列表
  static List<DeviceOrientation>? _lastAppliedOrientations;

  /// 最近一次应用的 SystemUiMode
  static SystemUiMode? _lastSystemUiMode;

  // ─── 状态查询 ────────────────────────────────────────

  /// 是否处于沉浸式模式
  bool get isImmersive => _lastSystemUiMode == SystemUiMode.immersiveSticky;

  // ─── 核心方法（已废弃，保留兼容性）───────────────────

  /// 进入播放器模式
  ///
  /// ⚠️ 已废弃：由 AppRouterManager.didPush() 自动处理
  @Deprecated('Use AppRouterManager.registerPage() with PageConfiguration.player()')
  Future<void> enterPlayer() async {
    // 允许所有方向
    await setOrientationAll();
    // 进入沉浸式
    await applyImmersive();
  }

  /// 退出播放器模式
  ///
  /// ⚠️ 已废弃：由 AppRouterManager.didPop() 自动处理
  @Deprecated('Use AppRouterManager (NavigatorObserver auto-handles this)')
  Future<void> exitPlayer() async {
    // 锁定竖屏
    await setOrientationPortrait();
    // 恢复正常 UI 模式
    await restoreToNormal();
  }

  /// 切换全屏/非全屏
  ///
  /// ⚠️ 已废弃：使用 AppRouterManager.handleOrientationChange()
  @Deprecated('Use AppRouterManager.handleOrientationChange()')
  Future<void> toggleFullscreen({required bool isLandscape}) async {
    if (isLandscape) {
      await setOrientationLandscape();
      // 横屏时重新应用沉浸式（方向切换后系统可能会重置）
      Future.delayed(const Duration(milliseconds: 300), () {
        applyImmersive();
      });
    } else {
      await setOrientationPortrait();
    }
  }

  // ─── 方向控制（底层方法，仍可用）────────────────────

  /// 允许所有方向旋转
  Future<void> setOrientationAll() async {
    const orientations = [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];

    if (_isSameOrientations(orientations)) return;

    await SystemChrome.setPreferredOrientations(orientations);
    _lastAppliedOrientations = orientations;
  }

  /// 锁定竖屏
  Future<void> setOrientationPortrait() async {
    const orientations = [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ];

    if (_isSameOrientations(orientations)) return;

    await SystemChrome.setPreferredOrientations(orientations);
    _lastAppliedOrientations = orientations;
  }

  /// 锁定横屏
  Future<void> setOrientationLandscape() async {
    const orientations = [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];

    if (_isSameOrientations(orientations)) return;

    await SystemChrome.setPreferredOrientations(orientations);
    _lastAppliedOrientations = orientations;
  }

  // ─── 系统UI模式（底层方法，仍可用）──────────────────

  /// 进入沉浸式模式（完全隐藏状态栏和导航栏）
  Future<void> applyImmersive() async {
    if (_lastSystemUiMode == SystemUiMode.immersiveSticky) return;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    _lastSystemUiMode = SystemUiMode.immersiveSticky;
  }

  /// 恢复正常 UI 模式（显示状态栏和导航栏）
  Future<void> restoreToNormal() async {
    if (_lastSystemUiMode == null ||
        _lastSystemUiMode == SystemUiMode.manual) return;

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _lastSystemUiMode = SystemUiMode.manual;
  }

  // ─── 内部方法 ───────────────────────────────────────

  /// 检查目标方向列表是否与当前已应用的一致（去重）
  bool _isSameOrientations(List<DeviceOrientation>? targetOrientations) {
    if (targetOrientations == null || targetOrientations.isEmpty) return false;
    if (_lastAppliedOrientations == null) return false;

    if (targetOrientations.length != _lastAppliedOrientations!.length) {
      return false;
    }
    for (final o in targetOrientations) {
      if (!_lastAppliedOrientations!.contains(o)) return false;
    }
    return true;
  }
}
