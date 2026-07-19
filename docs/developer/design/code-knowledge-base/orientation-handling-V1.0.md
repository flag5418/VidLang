# 横竖屏方向处理知识库

> **版本**: V1.0 | **日期**: 2026-07-17
> **触发关键词**: 横屏, 竖屏, 方向, orientation, rotate, 旋转, 全屏, 沉浸式

---

## 一、核心原理

### 1.1 iOS 方向控制链路

```
Flutter SystemChrome.setPreferredOrientations()
  → FlutterEngine 通知 iOS
    → FlutterViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
      → iOS 询问 supportedInterfaceOrientations
        → 返回当前允许的方向掩码
          → iOS 执行旋转
```

### 1.2 关键约束

| 层级 | 控制方 | 说明 |
|------|--------|------|
| 系统级 | iOS 控制中心旋转锁定 | 全局开关，App 无法绕过 |
| App 级 | AppDelegate / SceneDelegate | 必须返回 Flutter 动态请求的方向 |
| Flutter 级 | `SystemChrome.setPreferredOrientations` | 设置允许的方向列表 |

---

## 二、iOS 原生配置（必须正确）

### 2.1 Info.plist

```xml
<!-- 支持的方向 -->
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>

<!-- iPad 额外支持倒置 -->
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

### 2.2 AppDelegate.swift（关键！）

**禁止覆盖** `application(_:supportedInterfaceOrientationsFor:)`。

`FlutterAppDelegate` 内部已实现动态方向管理：当 Flutter 调用 `setPreferredOrientations` 时，它会自动返回对应的方向掩码。覆盖此方法会导致 Flutter 的方向请求被忽略。

```swift
// ✅ 正确：不覆盖，让 FlutterAppDelegate 处理
@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

// ❌ 错误：覆盖方向方法，导致 Flutter 失效
override func application(_ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return .allButUpsideDown  // 始终返回固定值，Flutter 无法动态控制
}
```

### 2.3 SceneDelegate.swift（关键！）

**禁止覆盖** `scene(_:supportedInterfaceOrientationsFor:)`。

同理，`FlutterSceneDelegate` 已实现动态方向管理。

```swift
// ✅ 正确
class SceneDelegate: FlutterSceneDelegate {
    // 不覆盖方向方法
}

// ❌ 错误
class SceneDelegate: FlutterSceneDelegate {
    override func scene(_ scene: UIScene,
        supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .allButUpsideDown  // 导致 Flutter 失效
    }
}
```

---

## 三、Flutter 层实现

### 3.1 标准方向管理页面模板

```dart
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // 1. 注册生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // 2. 允许所有方向旋转
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // 3. 移除监听
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 4. 响应方向变化
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;

    // 延迟一帧，确保 MediaQuery 更新完成
    Future.microtask(() {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final orientation = MediaQuery.of(context).orientation;
        _handleOrientationChange(orientation);
      });
    });
  }

  void _handleOrientationChange(Orientation orientation) {
    if (orientation == Orientation.landscape) {
      // 横屏：沉浸式
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
    } else {
      // 竖屏：正常模式
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 5. 直接读取 MediaQuery 判断方向
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return _buildLandscapeLayout();
    } else {
      return _buildPortraitLayout();
    }
  }
}
```

### 3.2 强制方向切换

```dart
/// 强制横屏
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);

/// 强制竖屏
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
]);

/// 恢复所有方向
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);
```

### 3.3 退出页面时恢复方向

```dart
@override
void dispose() {
  // 恢复所有方向，避免影响其他页面
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
```

---

## 四、常见问题与排查

### 4.1 旋转无效果

| 检查项 | 说明 |
|--------|------|
| 控制中心旋转锁定 | 系统级锁定，App 无法绕过 |
| AppDelegate 是否覆盖了方向方法 | 必须删除覆盖，让 FlutterAppDelegate 处理 |
| SceneDelegate 是否覆盖了方向方法 | 同上 |
| Info.plist 是否声明了目标方向 | 必须包含 LandscapeLeft/Right |
| `didChangeMetrics` 是否触发 | 未触发说明 iOS 层未检测到变化 |

### 4.2 didChangeMetrics 未触发

原因：`AppDelegate` 或 `SceneDelegate` 覆盖了 `supportedInterfaceOrientationsFor`，始终返回固定值，iOS 认为方向未变化。

解决：删除两个覆盖方法。

### 4.3 横屏后 UI 未适配

原因：`build()` 未读取 `MediaQuery.of(context).orientation`，或未根据方向返回不同布局。

解决：在 `build()` 中直接判断方向并返回不同 Widget。

---

## 五、项目中的实现位置

| 文件 | 作用 |
|------|------|
| `ios/Runner/AppDelegate.swift` | 不覆盖方向方法，让 FlutterAppDelegate 处理 |
| `ios/Runner/SceneDelegate.swift` | 不覆盖方向方法，让 FlutterSceneDelegate 处理 |
| `ios/Runner/Info.plist` | 声明支持的方向 |
| `lib/views/player/unified/unified_player_page.dart` | 播放器方向管理 |
| `lib/views/test/orientation_test_page.dart` | 方向测试页面 |
| `lib/services/app_router_manager.dart` | 全局路由方向配置 |
| `lib/services/player_system_ui_service.dart` | 播放器系统 UI 服务（已废弃） |

---

## 六、与参考项目对比

deepenglish_app 的 `VideoPlayerBase` 实现了相同的方向管理模式：

- `initState` 中 `setPreferredOrientations([所有方向])`
- `WidgetsBinding.instance.addObserver(this)` 注册监听
- `didChangeMetrics()` 响应方向变化
- `build()` 中通过 `MediaQuery.of(context).orientation` 判断布局

本项目 `UnifiedPlayerPage` 采用完全一致的实现方式。

---

**文档版本**: V1.0
**更新时间**: 2026-07-17
