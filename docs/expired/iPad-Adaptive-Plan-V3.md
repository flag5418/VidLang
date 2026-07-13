# iPad 自适应布局完善计划 (V3 - 简化版)

## 一、核心原则

1. **无 auto 类型**：只有 `iphone` 和 `ipad`，检测失败默认 `iphone`
2. **Storage-first**：启动时先读本地存储，无则检测并写入
3. **立即更新**：用户修改后立即写入并触发重新布局
4. **插件直接读存储**：无回调，无生命周期问题

---

## 二、生命周期详解

### 2.1 应用启动流程

```
main() 函数
    ↓
WidgetsFlutterBinding.ensureInitialized()
    ↓
SharedPreferences.getInstance()
    ↓
读取 'device_type' 键
    ↓
┌───┴───┐
│       │
有值    无值
│       │
↓       ↓
使用存储值  检测设备类型
│       │
│       ├─ iOS: device_info_plus (utsname.machine)
│       └─ Android: shortestSide >= 600
│       │
│       ↓
│    写入 SharedPreferences
│       │
└───┬───┘
    ↓
传递给 VidLangApp(initialDeviceType: ...)
    ↓
ScreenUtilInit 使用 designSize 初始化
    ↓
应用正常运行
```

### 2.2 用户修改流程

```
个人中心 → 设置 → 设备类型
    ↓
用户选择 "平板"
    ↓
写入 SharedPreferences ('device_type': 'ipad')
    ↓
更新 DeviceTypeProvider 状态
    ↓
ref.invalidate(deviceTypeProvider) 触发 rebuild
    ↓
MaterialApp 重建 (监听 deviceTypeProvider)
    ↓
ScreenUtilInit 重新初始化
    ↓
整个页面树使用新的设计尺寸
```

---

## 三、技术方案

### 3.1 依赖添加

```yaml
# pubspec.yaml
dependencies:
  device_info_plus: ^13.2.0  # iOS 设备检测
```

### 3.2 文件修改清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `pubspec.yaml` | 修改 | 添加 device_info_plus |
| `lib/models/device_type.dart` | 修改 | 删除 auto 类型 |
| `lib/services/device_info_service.dart` | 新建 | iOS 设备检测 |
| `lib/providers/device_type_provider.dart` | 修改 | Storage-first + 立即更新 |
| `plugs/tdesign_flutter/lib/src/util/adaptive_extension.dart` | 修改 | 直接读 SharedPreferences |
| `lib/main.dart` | 修改 | Storage-first 启动流程 |
| `lib/widgets/device_type_selector.dart` | 新建 | 设备类型选择器 |
| `lib/views/profile/profile_page.dart` | 修改 | 添加设置项 |

---

## 四、详细实施计划

### 阶段 1: 修改 AppDeviceType 枚举

**修改文件**: `lib/models/device_type.dart`

```dart
/// 设备平台类型枚举
///
/// 只有两种类型：
/// - iphone: 手机布局
/// - ipad: 平板布局
enum AppDeviceType {
  iphone,
  ipad;

  bool get isPhone => this == AppDeviceType.iphone;
  bool get isTablet => this == AppDeviceType.ipad;

  /// 是否为大屏设备 (iPad)
  bool get isLargeScreen => isTablet;

  /// 是否为小屏设备 (iPhone)
  bool get isSmallScreen => isPhone;
}
```

---

### 阶段 2: 创建 DeviceInfoService

**新建文件**: `lib/services/device_info_service.dart`

```dart
/// 设备信息服务
///
/// 负责检测设备类型：
/// - iOS: 使用 device_info_plus 获取 utsname.machine (100% 准确)
/// - Android: 使用 shortestSide >= 600 检测 (建议用户手动选择)
library;

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:vidlang/models/device_type.dart';

class DeviceInfoService {
  DeviceInfoService._();
  
  static final DeviceInfoService instance = DeviceInfoService._();
  
  /// 检测设备类型
  Future<AppDeviceType> detectDeviceType() async {
    if (kIsWeb) {
      return AppDeviceType.iphone; // Web 默认手机
    }
    
    if (Platform.isIOS) {
      return _detectIOS();
    } else if (Platform.isAndroid) {
      return _detectAndroid();
    }
    
    return AppDeviceType.iphone; // 其他平台默认手机
  }
  
  /// iOS 设备检测 (使用 utsname.machine)
  Future<AppDeviceType> _detectIOS() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      final machine = iosInfo.utsname.machine;
      
      debugPrint('[DeviceInfoService] iOS machine: $machine');
      
      // iPad 标识符以 "iPad" 开头
      if (machine.startsWith('iPad')) {
        return AppDeviceType.ipad;
      }
      
      // 其他情况默认手机
      return AppDeviceType.iphone;
    } catch (e) {
      debugPrint('[DeviceInfoService] iOS detection failed: $e');
      return AppDeviceType.iphone; // 检测失败默认手机
    }
  }
  
  /// Android 设备检测 (使用 shortestSide >= 600)
  Future<AppDeviceType> _detectAndroid() async {
    // Android 无法通过 API 准确判断设备类型
    // 返回默认值，由用户在设置中手动选择
    return AppDeviceType.iphone;
  }
}
```

---

### 阶段 3: 修改 DeviceTypeProvider

**修改文件**: `lib/providers/device_type_provider.dart`

```dart
/// 设备类型 Provider
///
/// 管理全局设备类型（iPhone / iPad），支持手动覆盖。
/// 启动时先读本地存储，无则检测并写入。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/services/device_info_service.dart';

const String _kDeviceTypeKey = 'device_type';

class DeviceTypeNotifier extends StateNotifier<AppDeviceType> {
  DeviceTypeNotifier() : super(AppDeviceType.iphone) {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kDeviceTypeKey);
      
      if (stored != null && stored.isNotEmpty) {
        // 有存储值，直接使用
        state = AppDeviceType.values.firstWhere(
          (e) => e.name == stored,
          orElse: () => AppDeviceType.iphone,
        );
        debugPrint('[DeviceTypeProvider] Loaded from storage: $state');
      } else {
        // 无存储值，检测并写入
        final detected = await DeviceInfoService.instance.detectDeviceType();
        state = detected;
        await _save(detected);
        debugPrint('[DeviceTypeProvider] Detected and saved: $state');
      }
    } catch (e) {
      debugPrint('[DeviceTypeProvider] init failed: $e');
      state = AppDeviceType.iphone; // 失败默认手机
    }
  }

  /// 手动设置设备类型
  ///
  /// 立即写入 SharedPreferences 并触发 rebuild
  Future<void> set(AppDeviceType type) async {
    state = type;
    await _save(type);
    debugPrint('[DeviceTypeProvider] Set to: $type');
  }

  /// 重置为自动检测
  Future<void> resetToAuto() async {
    final detected = await DeviceInfoService.instance.detectDeviceType();
    state = detected;
    await _save(detected);
    debugPrint('[DeviceTypeProvider] Reset to: $state');
  }

  Future<void> _save(AppDeviceType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDeviceTypeKey, type.name);
    } catch (e) {
      debugPrint('[DeviceTypeProvider] save failed: $e');
    }
  }
}

final deviceTypeProvider =
    StateNotifierProvider<DeviceTypeNotifier, AppDeviceType>(
  (ref) => DeviceTypeNotifier(),
);

extension DeviceTypeExtension on WidgetRef {
  AppDeviceType get deviceType => watch(deviceTypeProvider);
  AppDeviceType get deviceTypeWithoutWatch => read(deviceTypeProvider);
}
```

---

### 阶段 4: 修改插件 Adaptive 工具类

**修改文件**: `plugs/tdesign_flutter/lib/src/util/adaptive_extension.dart`

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════
// Plugin-local adaptive utilities
// ═══════════════════════════════════════════════════════════════

/// 设备类型枚举 (与主应用保持一致)
enum AppDeviceType {
  iphone,
  ipad;
  
  bool get isPhone => this == AppDeviceType.iphone;
  bool get isTablet => this == AppDeviceType.ipad;
}

/// 判断当前设备是否为 iPad (回退检测)
bool isIPad(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

/// iPad 缩放系数
class DeviceScale {
  DeviceScale._();

  static const Map<String, double> _scales = {
    'font': 1.38,
    'width': 1.30,
    'height': 1.30,
    'radius': 1.20,
    'icon': 1.28,
  };

  static double of(String type) => _scales[type] ?? 1.0;
}

/// 自适应尺寸工具类
///
/// iPhone：返回原始值 (逻辑像素)
/// iPad：返回缩放后的逻辑像素值 (value × scale)
class Adaptive {
  Adaptive._();
  
  // 缓存设备类型，避免重复读取 SharedPreferences
  static AppDeviceType? _cachedDeviceType;
  
  /// 从 SharedPreferences 读取设备类型
  ///
  /// 优先使用缓存，无缓存则读取存储
  static Future<AppDeviceType> _getDeviceTypeFromStorage() async {
    if (_cachedDeviceType != null) {
      return _cachedDeviceType!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('device_type');
      
      if (stored != null && stored.isNotEmpty) {
        _cachedDeviceType = AppDeviceType.values.firstWhere(
          (e) => e.name == stored,
          orElse: () => AppDeviceType.iphone,
        );
      } else {
        _cachedDeviceType = AppDeviceType.iphone; // 默认手机
      }
    } catch (e) {
      _cachedDeviceType = AppDeviceType.iphone; // 失败默认手机
    }
    
    return _cachedDeviceType!;
  }
  
  /// 同步获取设备类型 (用于 build 方法)
  ///
  /// 优先使用缓存，无缓存则使用回退检测
  static AppDeviceType getDeviceType(BuildContext context) {
    if (_cachedDeviceType != null) {
      return _cachedDeviceType!;
    }
    
    // 回退到尺寸检测
    return isIPad(context) ? AppDeviceType.ipad : AppDeviceType.iphone;
  }
  
  /// 初始化缓存 (应用启动时调用)
  static Future<void> initCache() async {
    await _getDeviceTypeFromStorage();
  }
  
  /// 更新缓存 (用户修改设备类型时调用)
  static void updateCache(AppDeviceType type) {
    _cachedDeviceType = type;
  }
  
  /// 统一缩放逻辑 (宽度/高度/间距)
  static double _scale(BuildContext context, num value, String type) {
    if (getDeviceType(context).isTablet) {
      return value.toDouble() * DeviceScale.of(type);
    }
    return value.toDouble();
  }

  /// 字体大小适配
  static double sp(BuildContext context, num value) =>
      _scale(context, value, 'font');

  /// 水平尺寸适配 (宽度)
  static double w(BuildContext context, num value) =>
      _scale(context, value, 'width');

  /// 垂直尺寸适配 (高度)
  static double h(BuildContext context, num value) =>
      _scale(context, value, 'height');

  /// 圆角半径适配
  static double r(BuildContext context, num value) =>
      _scale(context, value, 'radius');

  /// 图标尺寸适配
  static double icon(BuildContext context, num value) =>
      _scale(context, value, 'icon');
}

// ═══════════════════════════════════════════════════════════════
// BuildContext 扩展
// ═══════════════════════════════════════════════════════════════

extension AdaptiveContext on BuildContext {
  /// 文字尺寸 (font scale)
  double ts(num value) => Adaptive.sp(this, value);

  /// 通用尺寸 (width/height scale)
  double s(num value) => Adaptive.w(this, value);

  /// 圆角尺寸 (radius scale)
  double rs(num value) => Adaptive.r(this, value);

  /// 图标尺寸 (icon scale)
  double is_(num value) => Adaptive.icon(this, value);

  /// 是否为 iPad 设备
  bool get ipad => Adaptive.getDeviceType(this).isTablet;

  /// 是否为 iPhone 设备
  bool get iphone => Adaptive.getDeviceType(this).isPhone;
}
```

---

### 阶段 5: 修改 main.dart

**修改文件**: `lib/main.dart`

```dart
/// 应用入口函数
///
/// 在调用runApp之前完成所有初始化操作
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. 先读取本地存储的设备类型
      final deviceType = await _loadDeviceType();
      
      // 2. 根据设备类型设置屏幕方向
      _setOrientation(deviceType);

      // 3. 初始化插件缓存
      await _initAdaptiveCache(deviceType);

      // 4. 启动应用
      runApp(ProviderScope(child: VidLangApp(initialDeviceType: deviceType)));

      // 5. 后台异步初始化
      _initializeAsyncDependencies();
    },
    (error, stack) {
      GlobalErrorHandler.instance.handleZoneError(error, stack);
    },
  );
}

/// 从本地存储读取设备类型，无则检测并写入
Future<AppDeviceType> _loadDeviceType() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('device_type');
    
    if (stored != null && stored.isNotEmpty) {
      // 有存储值，直接使用
      final type = AppDeviceType.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => AppDeviceType.iphone,
      );
      debugPrint('[Main] Loaded device type from storage: $type');
      return type;
    }
    
    // 无存储值，检测并写入
    final detected = await DeviceInfoService.instance.detectDeviceType();
    await prefs.setString('device_type', detected.name);
    debugPrint('[Main] Detected and saved device type: $detected');
    return detected;
  } catch (e) {
    debugPrint('[Main] Failed to load device type: $e');
    return AppDeviceType.iphone; // 失败默认手机
  }
}

/// 根据设备类型设置屏幕方向
void _setOrientation(AppDeviceType deviceType) {
  if (deviceType.isTablet) {
    // iPad: 支持所有方向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    // iPhone: 仅竖屏
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
}

/// 初始化插件缓存
Future<void> _initAdaptiveCache(AppDeviceType deviceType) async {
  // 更新插件的缓存
  plugin_adaptive.Adaptive.updateCache(deviceType);
}
```

---

### 阶段 6: 修改 VidLangApp 支持重新布局

**修改文件**: `lib/main.dart`

```dart
class VidLangApp extends StatefulWidget {
  final AppDeviceType initialDeviceType;

  const VidLangApp({super.key, this.initialDeviceType = AppDeviceType.iphone});

  @override
  State<VidLangApp> createState() => _VidLangAppState();
}

class _VidLangAppState extends State<VidLangApp> {
  late final StreamSubscription<SessionHijackedException> _forceLogoutSub;
  late AppDeviceType _currentDeviceType;

  @override
  void initState() {
    super.initState();
    _currentDeviceType = widget.initialDeviceType;
    _forceLogoutSub = AuthService.instance.forceLogoutStream.listen((_) {
      _handleForceLogout();
    });
  }

  @override
  void didUpdateWidget(VidLangApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDeviceType != oldWidget.initialDeviceType) {
      setState(() {
        _currentDeviceType = widget.initialDeviceType;
      });
    }
  }

  @override
  void dispose() {
    _forceLogoutSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final designSize = DeviceConfig.getDesignSize(_currentDeviceType);

    return ScreenUtilInit(
      designSize: designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            // 监听设备类型变化，触发重建
            final deviceType = ref.watch(deviceTypeProvider);
            
            // 更新当前设备类型
            if (deviceType != _currentDeviceType) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _currentDeviceType = deviceType;
                });
                // 更新插件缓存
                plugin_adaptive.Adaptive.updateCache(deviceType);
              });
            }
            
            return MaterialApp(
              title: 'VidLang',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ref.watch(themeModeProvider).themeMode,
              debugShowCheckedModeBanner: false,
              routes: {
                '/login': (_) => const LoginPage(),
                '/audio-test': (_) => const AudioTestPage(),
                '/shengtong-http-test': (_) => const ShengtongHttpTestPage(),
              },
              navigatorKey: navigatorKey,
              home: const _AppEntry(),
            );
          },
        );
      },
    );
  }
}
```

---

### 阶段 7: 添加设备类型选择 UI

**新建文件**: `lib/widgets/device_type_selector.dart`

```dart
/// 设备类型选择器
///
/// 在个人中心页面显示，允许用户手动选择设备类型
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/providers/device_type_provider.dart';
import 'package:tdesign_flutter/src/util/adaptive_extension.dart' as plugin_adaptive;

class DeviceTypeSelector extends ConsumerWidget {
  const DeviceTypeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentType = ref.watch(deviceTypeProvider);
    
    return ListTile(
      leading: const Icon(Icons.devices),
      title: const Text('设备类型'),
      subtitle: Text(_getTypeLabel(currentType)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showSelectorDialog(context, ref, currentType),
    );
  }

  String _getTypeLabel(AppDeviceType type) {
    switch (type) {
      case AppDeviceType.iphone:
        return '手机';
      case AppDeviceType.ipad:
        return '平板';
    }
  }

  void _showSelectorDialog(
    BuildContext context,
    WidgetRef ref,
    AppDeviceType currentType,
  ) {
    showDialog(
      context: context,
      builder: (context) => _DeviceTypeDialog(
        currentType: currentType,
        onSelected: (type) async {
          // 1. 更新 Provider 状态
          await ref.read(deviceTypeProvider.notifier).set(type);
          
          // 2. 更新插件缓存
          plugin_adaptive.Adaptive.updateCache(type);
          
          // 3. 触发整个应用重建
          ref.invalidate(deviceTypeProvider);
          
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _DeviceTypeDialog extends StatefulWidget {
  final AppDeviceType currentType;
  final ValueChanged<AppDeviceType> onSelected;

  const _DeviceTypeDialog({
    required this.currentType,
    required this.onSelected,
  });

  @override
  State<_DeviceTypeDialog> createState() => _DeviceTypeDialogState();
}

class _DeviceTypeDialogState extends State<_DeviceTypeDialog> {
  late AppDeviceType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择设备类型'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<AppDeviceType>(
            title: const Text('手机'),
            subtitle: const Text('使用手机布局'),
            value: AppDeviceType.iphone,
            groupValue: _selectedType,
            onChanged: (value) {
              setState(() => _selectedType = value!);
            },
          ),
          RadioListTile<AppDeviceType>(
            title: const Text('平板'),
            subtitle: const Text('使用平板布局'),
            value: AppDeviceType.ipad,
            groupValue: _selectedType,
            onChanged: (value) {
              setState(() => _selectedType = value!);
            },
          ),
          const SizedBox(height: 8),
          const Text(
            '提示: 安卓设备建议手动选择以获得最佳显示效果',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => widget.onSelected(_selectedType),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
```

---

### 阶段 8: 修改个人中心页面

**修改文件**: `lib/views/profile/profile_page.dart`

在设置列表中添加设备类型选择项：

```dart
// 在 _buildSettingsCard 方法中添加
_SettingItem(
  icon: Icons.devices,
  title: '设备类型',
  subtitle: _getDeviceTypeLabel(), // 新增方法
  onTap: () => _showDeviceTypeSelector(),
),
```

新增辅助方法：

```dart
String _getDeviceTypeLabel() {
  final deviceType = ref.read(deviceTypeProvider);
  switch (deviceType) {
    case AppDeviceType.iphone:
      return '手机';
    case AppDeviceType.ipad:
      return '平板';
  }
}

void _showDeviceTypeSelector() {
  showDialog(
    context: context,
    builder: (context) => DeviceTypeSelector(),
  );
}
```

---

## 五、执行步骤

### 步骤 1: 添加依赖
```bash
flutter pub add device_info_plus
```

### 步骤 2: 修改 AppDeviceType 枚举
- 删除 `auto` 类型
- 只保留 `iphone` 和 `ipad`

### 步骤 3: 创建 DeviceInfoService
- 实现 iOS 设备检测 (utsname.machine)
- 实现 Android 检测 (尺寸检测)

### 步骤 4: 修改 DeviceTypeProvider
- Storage-first 逻辑
- 立即更新机制

### 步骤 5: 修改插件 Adaptive 工具类
- 直接读 SharedPreferences
- 缓存机制
- 无回调

### 步骤 6: 修改 main.dart
- Storage-first 启动流程
- 初始化插件缓存

### 步骤 7: 修改 VidLangApp
- 监听 deviceTypeProvider
- 支持重新布局

### 步骤 8: 添加设备类型选择 UI
- 创建 DeviceTypeSelector
- 修改个人中心页面

### 步骤 9: 测试验证
- iOS 设备检测
- Android 手动选择
- 重新布局功能

---

## 六、测试清单

### 功能测试
- [ ] iOS iPad 自动检测为 iPad
- [ ] iOS iPhone 自动检测为 iPhone
- [ ] Android 默认检测为手机
- [ ] 手动选择"手机"后使用手机布局
- [ ] 手动选择"平板"后使用平板布局
- [ ] 重启应用后保持用户选择

### UI 测试
- [ ] iPad 上弹窗宽度正确 (屏幕宽度×50%)
- [ ] iPad 上标题字体正确 (18×1.38=24.84sp)
- [ ] iPad 上按钮高度正确 (56×1.30=72.8pt)
- [ ] iPad 上输入框 margin 正确 (24×1.30=31.2pt)
- [ ] iPhone 上所有尺寸保持原值

### 重新布局测试
- [ ] 用户修改设备类型后页面立即重建
- [ ] ScreenUtil 重新初始化
- [ ] 所有组件使用新的设计尺寸

---

**计划版本**: V3.0 (简化版)
**创建时间**: 2026-07-13
**状态**: 待确认后执行
