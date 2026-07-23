import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 页面配置类（声明式）
///
/// 集中管理页面的屏幕方向、状态栏样式、系统UI模式和屏幕常亮
///
/// **使用方式**：
/// ```dart
/// // 在 main.dart 中注册页面配置
/// AppRouterManager.registerPage(UnifiedPlayerPage, PageConfiguration.player());
/// AppRouterManager.registerPage(HomePage, PageConfiguration.normal());
/// ```
class PageConfiguration {
  /// 屏幕方向（null 表示不改变）
  final List<DeviceOrientation>? orientations;

  /// 状态栏样式（null 表示不改变）
  final SystemUiOverlayStyle? statusBarStyle;

  /// 系统UI模式（null 表示不改变）
  final SystemUiMode? systemUiMode;

  /// 系统UI覆盖层（null 表示不改变）
  final List<SystemUiOverlay>? systemUiOverlays;

  /// 是否保持屏幕常亮（null 表示不改变）
  final bool? keepScreenOn;

  const PageConfiguration({
    this.orientations,
    this.statusBarStyle,
    this.systemUiMode,
    this.systemUiOverlays,
    this.keepScreenOn,
  });

  /// 创建普通竖屏页面配置（默认配置）
  ///
  /// - 锁定竖屏（portraitUp）
  /// - 显示状态栏和导航栏
  /// - 关闭屏幕常亮
  factory PageConfiguration.normal() => const PageConfiguration(
    orientations: [DeviceOrientation.portraitUp],
    systemUiMode: SystemUiMode.edgeToEdge,
    systemUiOverlays: SystemUiOverlay.values,
    keepScreenOn: false,
  );

  /// 创建播放器页面配置
  ///
  /// - 允许所有方向旋转（portraitUp/Down + landscapeLeft/Right）
  /// - 沉浸式模式（隐藏状态栏和导航栏）
  /// - 开启屏幕常亮
  factory PageConfiguration.player() => const PageConfiguration(
    orientations: [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ],
    systemUiMode: SystemUiMode.immersiveSticky,
    systemUiOverlays: [],
    keepScreenOn: true,
    statusBarStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  @override
  String toString() {
    return 'PageConfiguration('
        'orientations=$orientations, '
        'systemUiMode=$systemUiMode, '
        'keepScreenOn=$keepScreenOn)';
  }
}

/// 全局路由管理器（NavigatorObserver）
///
/// **核心功能**：
/// 1. 监听路由变化（didPush/didPop），自动应用页面的屏幕方向/UI配置
/// 2. 统一管理屏幕常亮（进入播放器开启，退出播放器关闭）
/// 3. 提供方向变化处理方法（仅切换沉浸式模式，不改变系统方向）
///
/// **架构优势**：
/// - ✅ 全局单例，避免每个页面手动管理方向
/// - ✅ 自动恢复：退出播放器时自动恢复竖屏+关闭常亮
/// - ✅ 去重机制：避免重复设置相同配置
/// - ✅ 可扩展：未来其他页面也可使用（如全屏图片查看器）
class AppRouterManager extends NavigatorObserver {
  // ==================== 单例 ====================

  static final AppRouterManager instance = AppRouterManager._();
  AppRouterManager._();

  // ==================== 页面配置映射表 ====================

  /// 页面配置映射表（使用 Widget 类型作为 key）
  static final Map<Type, PageConfiguration> _pageConfigMap = {};

  // ==================== 状态缓存（用于去重） ====================

  /// 最近一次应用的方向列表
  static List<DeviceOrientation>? _lastAppliedOrientations;

  /// 最近一次应用的 SystemUiMode
  static SystemUiMode? _lastSystemUiMode;

  /// 最近一次应用的 overlays
  static List<SystemUiOverlay>? _lastSystemUiOverlays;

  /// 是否已开启屏幕常亮
  static bool _isWakelockEnabled = false;

  // ==================== 公共 API ====================

  /// 注册页面配置到全局映射表
  ///
  /// **调用时机**：在 main.dart 中，runApp 之前注册所有特殊页面
  ///
  /// **示例**：
  /// ```dart
  /// AppRouterManager.registerPage(UnifiedPlayerPage, PageConfiguration.player());
  /// ```
  static void registerPage(Type widgetType, PageConfiguration configuration) {
    _pageConfigMap[widgetType] = configuration;
    debugPrint('📝 [AppRouterManager] 注册页面配置: $widgetType → $configuration');
  }

  /// 处理方向变化（核心方法！仅切换沉浸式模式，不改变系统方向）
  ///
  /// **参考代码**：deepenglish_app VideoPlayerBase._handleOrientationChange()
  ///
  /// **调用场景**：
  /// - native_device_orientation 检测到物理旋转
  /// - didChangeMetrics 检测到系统方向变化
  /// - 用户主动点击全屏按钮
  ///
  /// **逻辑**：
  /// - 横屏 → 隐藏状态栏和导航栏（immersiveSticky）
  /// - 竖屏 → 显示状态栏和导航栏（manual + all overlays）
  static void handleOrientationChange(Orientation orientation) {
    if (orientation == Orientation.landscape) {
      // 横屏：进入沉浸式模式（隐藏状态栏和导航栏）
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [], // 隐藏所有系统UI
      );
      _lastSystemUiMode = SystemUiMode.immersiveSticky;
      _lastSystemUiOverlays = [];
      debugPrint('📱 [AppRouterManager] 切换到横屏沉浸式模式');
    } else {
      // 竖屏：恢复正常模式（显示状态栏和导航栏）
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values, // 显示所有系统覆盖层
      );
      _lastSystemUiMode = SystemUiMode.manual;
      _lastSystemUiOverlays = List.from(SystemUiOverlay.values);
      debugPrint('📱 [AppRouterManager] 恢复到竖屏正常模式');
    }
  }

  // ==================== NavigatorObserver 生命周期 ====================

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);

    final fromName = _getRouteName(previousRoute);
    final toName = _getRouteName(route);
    debugPrint('🔀 [AppRouterManager] 路由 Push: $fromName → $toName');

    // 应用目标页面的配置
    _applyConfigForRoute(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);

    final fromName = _getRouteName(route);
    final toName = _getRouteName(previousRoute);
    debugPrint('🔙 [AppRouterManager] 路由 Pop: $fromName → $toName');

    if (previousRoute != null) {
      // 返回上一页面，恢复上一页面的配置
      _applyConfigForRoute(previousRoute);
    } else {
      // 返回到根页面（没有上一个路由），应用默认配置
      debugPrint('🏠 [AppRouterManager] 返回根页面，应用默认竖屏配置');
      _applyConfiguration(PageConfiguration.normal());
    }
  }

  // ==================== 内部方法 ====================

  /// 为指定路由应用对应的页面配置
  void _applyConfigForRoute(Route route) {
    // 跳过弹窗/对话框路由，不应用页面配置（弹窗不是页面）
    if (route is RawDialogRoute || route is DialogRoute) {
      return;
    }

    // 延迟一帧执行，确保路由已准备好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final widgetType = _getWidgetTypeFromRoute(route);
      if (widgetType != null) {
        // 从映射表中获取配置，如果没有则使用默认配置（竖屏）
        final config = _pageConfigMap[widgetType] ?? PageConfiguration.normal();
        _applyConfiguration(config);
      } else {
        // 无法识别的页面类型，使用默认配置
        debugPrint('⚠️ [AppRouterManager] 无法识别页面类型，使用默认配置');
        _applyConfiguration(PageConfiguration.normal());
      }
    });
  }

  /// 应用页面配置（内部核心方法）
  ///
  /// **执行流程**：
  /// 1. 屏幕方向（如果不同则更新）
  /// 2. 系统UI模式（沉浸式/正常）
  /// 3. 状态栏样式
  /// 4. 屏幕常亮（开启/关闭）
  void _applyConfiguration(PageConfiguration config) {
    debugPrint('┧ [AppRouterManager] 开始应用配置: $config');

    // 1. 屏幕方向
    if (config.orientations != null) {
      if (!_isSameOrientations(config.orientations)) {
        SystemChrome.setPreferredOrientations(config.orientations!);
        _lastAppliedOrientations = List.from(config.orientations!);
        debugPrint('✅ [AppRouterManager] 方向已设置: ${config.orientations}');
      } else {
        debugPrint('⏭️ [AppRouterManager] 方向未变化，跳过');
      }
    }

    // 2. 系统UI模式 + 覆盖层
    final targetMode = config.systemUiMode ?? SystemUiMode.edgeToEdge;
    final targetOverlays = config.systemUiOverlays ?? SystemUiOverlay.values;
    
    if (_lastSystemUiMode != targetMode || !_isSameOverlays(targetOverlays)) {
      SystemChrome.setEnabledSystemUIMode(targetMode, overlays: targetOverlays);
      _lastSystemUiMode = targetMode;
      _lastSystemUiOverlays = List.from(targetOverlays);
      debugPrint('✅ [AppRouterManager] UI模式已设置: $targetMode, overlays: $targetOverlays');
    }

    // 3. 状态栏样式
    if (config.statusBarStyle != null) {
      SystemChrome.setSystemUIOverlayStyle(config.statusBarStyle!);
    }

    // 4. 屏幕常亮（关键！只在需要时切换）
    if (config.keepScreenOn == true && !_isWakelockEnabled) {
      WakelockPlus.enable();
      _isWakelockEnabled = true;
      debugPrint('✅ [AppRouterManager] 屏幕常亮已开启');
    } else if (config.keepScreenOn == false && _isWakelockEnabled) {
      WakelockPlus.disable();
      _isWakelockEnabled = false;
      debugPrint('❌ [AppRouterManager] 屏幕常亮已关闭');
    }

    debugPrint('🎉 [AppRouterManager] 配置应用完成');
  }

  // ==================== 辅助方法 ====================

  /// 从路由获取 Widget 类型
  Type? _getWidgetTypeFromRoute(Route route) {
    // 处理 MaterialPageRoute（标准 Flutter 路由）
    if (route is MaterialPageRoute) {
      try {
        final context = route.navigator?.context;
        if (context != null) {
          final widget = route.builder(context);
          return widget.runtimeType;
        }
      } catch (e) {
        debugPrint('⚠️ [AppRouterManager] 获取 Widget 类型失败: $e');
      }
    }
    return null;
  }

  /// 获取路由名称（用于日志）
  String _getRouteName(Route? route) {
    if (route == null) return 'Root';
    
    if (route.settings.name != null && route.settings.name!.isNotEmpty) {
      return route.settings.name!;
    }
    
    final widgetType = _getWidgetTypeFromRoute(route);
    return widgetType?.toString() ?? route.runtimeType.toString();
  }

  /// 检查目标方向列表是否与当前已应用的一致（去重）
  bool _isSameOrientations(List<DeviceOrientation>? targetOrientations) {
    if (targetOrientations == null || targetOrientations.isEmpty) return false;
    if (_lastAppliedOrientations == null || _lastAppliedOrientations!.isEmpty) return false;

    // 简单比较：长度相同且包含相同元素
    if (targetOrientations.length != _lastAppliedOrientations!.length) {
      return false;
    }
    for (final o in targetOrientations) {
      if (!_lastAppliedOrientations!.contains(o)) return false;
    }
    return true;
  }

  /// 检查目标 overlays 是否与当前一致（去重）
  bool _isSameOverlays(List<SystemUiOverlay>? targetOverlays) {
    if (targetOverlays == null || targetOverlays.isEmpty) return false;
    if (_lastSystemUiOverlays == null || _lastSystemUiOverlays!.isEmpty) return false;

    if (targetOverlays.length != _lastSystemUiOverlays!.length) {
      return false;
    }
    for (final o in targetOverlays) {
      if (!_lastSystemUiOverlays!.contains(o)) return false;
    }
    return true;
  }
}
