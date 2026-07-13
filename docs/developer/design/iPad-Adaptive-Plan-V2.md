# iPad 自适应布局完善计划 (V2)

## 一、问题分析与解决方案

### 1.1 当前问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 按钮/输入框尺寸不正确 | 插件无法访问 ScreenUtil | 使用静态回调机制获取设备类型 |
| iPad 检测不准确 | 仅使用 shortestSide >= 600 | iOS 使用 device_info_plus，Android 使用尺寸检测 |
| Android 设备碎片化 | 无法自动识别所有平板 | 支持用户手动选择设备类型 |

### 1.2 设备检测策略

```
┌─────────────────────────────────────────────────────────────┐
│                    设备检测策略                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  iOS 设备 (100% 准确)                                       │
│    └─ 使用 device_info_plus 获取 utsname.machine            │
│    └─ iPad: "iPad14,1", "iPad13,8" 等                     │
│    └─ iPhone: "iPhone14,2", "iPhone15,4" 等                │
│                                                             │
│  Android 设备 (尺寸检测 + 用户手动选择)                     │
│    └─ 默认: shortestSide >= 600 判定为平板                  │
│    └─ 用户可在设置中手动选择: 自动检测/手机/平板            │
│    └─ 手动选择优先级高于自动检测                            │
│                                                             │
│  全局策略                                                   │
│    └─ 应用启动时检测一次                                    │
│    └─ 结果存储到 SharedPreferences                          │
│    └─ 插件通过静态回调获取设备类型                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、技术方案

### 2.1 依赖添加

```yaml
# pubspec.yaml
dependencies:
  device_info_plus: ^13.2.0  # 新增：iOS 设备检测
```

### 2.2 核心组件架构

```
┌─────────────────────────────────────────────────────────────┐
│                    核心组件架构                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  DeviceInfoService (新增)                           │   │
│  │  - detectDeviceType() → AppDeviceType               │   │
│  │  - iOS: 使用 utsname.machine 检测                   │   │
│  │  - Android: 使用 shortestSide >= 600 检测           │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  DeviceTypeProvider (修改)                          │   │
│  │  - 优先级: 手动选择 > 自动检测 > 默认值             │   │
│  │  - 存储: SharedPreferences                           │   │
│  │  - getEffectiveType(context) → AppDeviceType        │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Adaptive 工具类 (修改)                             │   │
│  │  - 注册静态回调: registerDeviceTypeProvider()       │   │
│  │  - 主应用启动时注册回调                             │   │
│  │  - 插件通过回调获取设备类型                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  UI 组件                                            │   │
│  │  - TDDialogScaffold                                 │   │
│  │  - TDDialogTitle                                    │   │
│  │  - HorizontalTextButtons                            │   │
│  │  - TDInputDialog                                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 三、详细实施计划

### 阶段 1: 添加 device_info_plus 依赖

**文件**: `pubspec.yaml`

```yaml
dependencies:
  device_info_plus: ^13.2.0
```

**执行命令**:
```bash
flutter pub add device_info_plus
```

---

### 阶段 2: 创建 DeviceInfoService

**新建文件**: `lib/services/device_info_service.dart`

```dart
/// 设备信息服务
///
/// 负责检测设备类型：
/// - iOS: 使用 device_info_plus 获取 utsname.machine (100% 准确)
/// - Android: 使用 shortestSide >= 600 检测 (需要用户手动选择支持)
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
  ///
  /// iPad 标识符以 "iPad" 开头 (如 "iPad14,1", "iPad13,8")
  /// iPhone 标识符以 "iPhone" 开头 (如 "iPhone14,2", "iPhone15,4")
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
      
      // iPhone 标识符以 "iPhone" 开头
      if (machine.startsWith('iPhone')) {
        return AppDeviceType.iphone;
      }
      
      // iPod touch 标识符以 "iPod" 开头
      if (machine.startsWith('iPod')) {
        return AppDeviceType.iphone;
      }
      
      // 模拟器 (i386, x86_64, arm64) - 根据屏幕尺寸判断
      if (machine == 'i386' || machine == 'x86_64' || machine == 'arm64') {
        return AppDeviceType.iphone; // 模拟器默认手机
      }
      
      return AppDeviceType.iphone;
    } catch (e) {
      debugPrint('[DeviceInfoService] iOS detection failed: $e');
      return AppDeviceType.iphone;
    }
  }
  
  /// Android 设备检测 (使用 shortestSide >= 600)
  ///
  /// 注意: Android 设备碎片化严重，此方法可能不准确
  /// 建议用户在设置中手动选择设备类型
  Future<AppDeviceType> _detectAndroid() async {
    // Android 无法通过 API 准确判断设备类型
    // 返回默认值，由用户在设置中手动选择
    return AppDeviceType.iphone;
  }
  
  /// 获取设备信息 (用于调试)
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (kIsWeb) {
      return {'platform': 'web'};
    }
    
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return {
        'platform': 'ios',
        'machine': iosInfo.utsname.machine,
        'name': iosInfo.name,
        'model': iosInfo.model,
        'systemVersion': iosInfo.systemVersion,
      };
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'platform': 'android',
        'brand': androidInfo.brand,
        'model': androidInfo.model,
        'product': androidInfo.product,
        'display': androidInfo.display,
      };
    }
    
    return {'platform': 'unknown'};
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
/// 启动时自动检测，用户可在设置中手动切换。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/models/device_type.dart';
import 'package:vidlang/services/device_info_service.dart';

const String _kDeviceTypeKey = 'device_type_override';

class DeviceTypeNotifier extends StateNotifier<AppDeviceType> {
  DeviceTypeNotifier() : super(AppDeviceType.auto) {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final override = prefs.getString(_kDeviceTypeKey);
      
      if (override != null && override.isNotEmpty) {
        // 用户手动选择
        state = AppDeviceType.values.firstWhere(
          (e) => e.name == override,
          orElse: () => AppDeviceType.auto,
        );
        debugPrint('[DeviceTypeProvider] Loaded override: $state');
      } else {
        // 首次启动，自动检测
        final detected = await DeviceInfoService.instance.detectDeviceType();
        state = detected;
        await _save(detected);
        debugPrint('[DeviceTypeProvider] Auto-detected: $state');
      }
    } catch (e) {
      debugPrint('[DeviceTypeProvider] init failed: $e');
      state = AppDeviceType.iphone;
    }
  }

  /// 获取实际设备类型 (用于 UI 布局)
  ///
  /// 优先级: 手动选择 > 自动检测 > 默认值
  AppDeviceType getEffectiveType(BuildContext context) {
    if (state.isAuto) {
      // 自动检测模式，根据平台判断
      if (MediaQuery.of(context).size.shortestSide >= 600) {
        return AppDeviceType.ipad;
      }
      return AppDeviceType.iphone;
    }
    return state;
  }

  /// 手动设置设备类型
  Future<void> set(AppDeviceType type) async {
    state = type;
    await _save(type);
    debugPrint('[DeviceTypeProvider] Set to: $type');
  }

  /// 重置为自动检测
  Future<void> resetToAuto() async {
    state = AppDeviceType.auto;
    await _save(AppDeviceType.auto);
    debugPrint('[DeviceTypeProvider] Reset to auto');
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

### 阶段 4: 修改 AppDeviceType 枚举

**修改文件**: `lib/models/device_type.dart`

```dart
/// 设备平台类型枚举
///
/// 支持三种模式：
/// - auto: 自动检测 (默认)
/// - iphone: 强制手机布局
/// - ipad: 强制平板布局
enum AppDeviceType {
  auto,    // 自动检测
  iphone,  // 强制手机布局
  ipad;    // 强制平板布局

  bool get isPhone => this == AppDeviceType.iphone;
  bool get isTablet => this == AppDeviceType.ipad;
  bool get isAuto => this == AppDeviceType.auto;

  /// 是否为大屏设备 (iPad)
  bool get isLargeScreen => isTablet;

  /// 是否为小屏设备 (iPhone)
  bool get isSmallScreen => isPhone;
}
```

---

### 阶段 5: 修改插件 Adaptive 工具类

**修改文件**: `plugs/tdesign_flutter/lib/src/util/adaptive_extension.dart`

```dart
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// Plugin-local adaptive utilities
// ═══════════════════════════════════════════════════════════════

/// 设备类型枚举 (与主应用保持一致)
enum AppDeviceType {
  auto,
  iphone,
  ipad;
  
  bool get isPhone => this == AppDeviceType.iphone;
  bool get isTablet => this == AppDeviceType.ipad;
  bool get isAuto => this == AppDeviceType.auto;
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
  
  // 静态回调，主应用注册提供设备类型
  static AppDeviceType Function(BuildContext)? _deviceTypeProvider;
  
  /// 注册设备类型提供者 (主应用启动时调用)
  static void registerDeviceTypeProvider(
    AppDeviceType Function(BuildContext) provider,
  ) {
    _deviceTypeProvider = provider;
    debugPrint('[Adaptive] DeviceTypeProvider registered');
  }
  
  /// 获取设备类型 (优先使用注册的提供者)
  static AppDeviceType getDeviceType(BuildContext context) {
    if (_deviceTypeProvider != null) {
      final type = _deviceTypeProvider!(context);
      debugPrint('[Adaptive] DeviceType from provider: $type');
      return type;
    }
    
    // 回退到自动检测
    final detected = MediaQuery.of(context).size.shortestSide >= 600
        ? AppDeviceType.ipad
        : AppDeviceType.iphone;
    debugPrint('[Adaptive] DeviceType auto-detected: $detected');
    return detected;
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

### 阶段 6: 主应用注册回调

**修改文件**: `lib/main.dart`

```dart
// 在 main() 或 runApp() 之前
import 'package:tdesign_flutter/src/util/adaptive_extension.dart' as plugin_adaptive;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... 其他初始化 ...
  
  // 注册设备类型提供者到插件
  _registerDeviceTypeProvider();
  
  runApp(const ProviderScope(child: VidLangApp()));
}

void _registerDeviceTypeProvider() {
  plugin_adaptive.Adaptive.registerDeviceTypeProvider((context) {
    // 从 DeviceTypeProvider 获取用户选择的设备类型
    final container = ProviderScope.containerOf(context);
    final deviceType = container.read(deviceTypeProvider);
    
    // 映射到插件的 AppDeviceType
    return plugin_adaptive.AppDeviceType.values.firstWhere(
      (e) => e.name == deviceType.name,
      orElse: () => plugin_adaptive.AppDeviceType.auto,
    );
  });
}
```

---

### 阶段 7: 添加 Android 设备类型选择 UI

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
      case AppDeviceType.auto:
        return '自动检测';
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
        onSelected: (type) {
          ref.read(deviceTypeProvider.notifier).set(type);
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
            title: const Text('自动检测'),
            subtitle: const Text('根据屏幕尺寸自动判断'),
            value: AppDeviceType.auto,
            groupValue: _selectedType,
            onChanged: (value) {
              setState(() => _selectedType = value!);
            },
          ),
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
    case AppDeviceType.auto:
      return '自动检测';
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

## 四、执行步骤

### 步骤 1: 添加依赖
```bash
flutter pub add device_info_plus
```

### 步骤 2: 创建 DeviceInfoService
- 新建 `lib/services/device_info_service.dart`
- 实现 iOS 设备检测 (utsname.machine)
- 实现 Android 检测 (尺寸检测)

### 步骤 3: 修改 DeviceTypeProvider
- 添加 `auto` 类型支持
- 实现 `getEffectiveType(context)` 方法
- 支持自动检测和手动选择

### 步骤 4: 修改 AppDeviceType 枚举
- 添加 `auto` 类型
- 更新 `isPhone`、`isTablet`、`isAuto` 属性

### 步骤 5: 修改插件 Adaptive 工具类
- 添加静态回调机制
- 实现 `registerDeviceTypeProvider()` 方法
- 实现 `getDeviceType()` 方法

### 步骤 6: 主应用注册回调
- 在 `main.dart` 中注册设备类型提供者
- 确保在使用插件组件前完成注册

### 步骤 7: 添加设备类型选择 UI
- 创建 `lib/widgets/device_type_selector.dart`
- 修改 `lib/views/profile/profile_page.dart`
- 添加设置项和选择弹窗

### 步骤 8: 测试验证
- iOS 设备: 验证 iPad/iPhone 检测准确
- Android 设备: 验证手动选择功能
- iPad 弹窗: 验证按钮/输入框尺寸正确

---

## 五、测试清单

### 功能测试
- [ ] iOS iPad 自动检测为 iPad
- [ ] iOS iPhone 自动检测为 iPhone
- [ ] Android 默认自动检测
- [ ] 手动选择"手机"后使用手机布局
- [ ] 手动选择"平板"后使用平板布局
- [ ] 重启应用后保持用户选择

### UI 测试
- [ ] iPad 上弹窗宽度正确 (屏幕宽度×50%)
- [ ] iPad 上标题字体正确 (18×1.38=24.84sp)
- [ ] iPad 上按钮高度正确 (56×1.30=72.8pt)
- [ ] iPad 上输入框 margin 正确 (24×1.30=31.2pt)
- [ ] iPhone 上所有尺寸保持原值

### 兼容性测试
- [ ] 不同 iPad 型号 (Pro、Air、mini)
- [ ] 不同 Android 设备 (手机、平板)
- [ ] 屏幕旋转后布局正确

---

## 六、风险与注意事项

1. **插件通信**: 确保主应用在使用插件组件前注册回调
2. **向后兼容**: 保持现有 API 不变，仅添加新功能
3. **性能影响**: DeviceInfoService 异步检测，需处理加载状态
4. **Android 碎片化**: 自动检测可能不准确，建议用户手动选择
5. **iOS 模拟器**: 模拟器的 machine 标识符可能不准确，需特殊处理

---

**计划版本**: V2.0
**创建时间**: 2026-07-13
**状态**: 待确认后执行
