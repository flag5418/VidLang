# iPad 自适应布局完善计划

## 一、问题分析

### 1.1 当前 iPad 检测逻辑

```dart
// lib/utils/adaptive.dart
bool isIPad(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;
```

**检测原理**：
- `shortestSide` 是屏幕较短边的长度（逻辑像素）
- iPad 竖屏：768×1024 → shortestSide=768 ≥ 600 ✓
- iPad 横屏：1024×768 → shortestSide=768 ≥ 600 ✓
- iPhone 竖屏：393×852 → shortestSide=393 < 600 ✗
- iPhone 横屏：852×393 → shortestSide=393 < 600 ✗

**优点**：
- 简单可靠，不受屏幕方向影响
- 适用于 iOS 设备（iPad 型号标准化）

**缺点**：
- Android 设备碎片化严重，无法准确区分手机和平板
- 部分大屏手机（如 6.7 寸）可能被误判为平板

### 1.2 按钮/输入框尺寸问题

**问题根源**：
插件的 `adaptive_extension.dart` 无法访问主应用的 ScreenUtil，导致缩放不一致。

**当前缩放系数**：
| 类型 | iPhone | iPad | 系数 |
|------|--------|------|------|
| font | 18sp | 18×1.38=24.84sp | 1.38 |
| width | 56pt | 56×1.30=72.8pt | 1.30 |
| height | 56pt | 56×1.30=72.8pt | 1.30 |
| radius | 12pt | 12×1.20=14.4pt | 1.20 |
| icon | 22pt | 22×1.28=28.16pt | 1.28 |

---

## 二、解决方案架构

```
┌─────────────────────────────────────────────────────────────┐
│                    自适应布局架构                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 设备类型来源                          │   │
│  │  (优先级: 手动选择 > 自动检测 > 默认值)              │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              DeviceTypeProvider                      │   │
│  │  - 存储: SharedPreferences                           │   │
│  │  - 提供: AppDeviceType (iphone/ipad)                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                 │
│           ┌───────────────┴───────────────┐                 │
│           ▼                               ▼                 │
│  ┌─────────────────┐           ┌─────────────────┐         │
│  │  主应用 Adaptive │           │  插件 Adaptive   │         │
│  │  (使用 ScreenUtil)│           │  (静态回调)      │         │
│  └─────────────────┘           └─────────────────┘         │
│           │                               │                 │
│           └───────────────┬───────────────┘                 │
│                           ▼                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 UI 组件                              │   │
│  │  - TDDialogScaffold                                 │   │
│  │  - TDDialogTitle                                    │   │
│  │  - TDDialogContent                                  │   │
│  │  - HorizontalTextButtons                            │   │
│  │  - TDInputDialog                                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 三、实施计划

### 阶段 1: 修复插件-应用通信机制

**目标**：让插件能够获取主应用的设备类型，而非硬编码检测。

**修改文件**：
1. `plugs/tdesign_flutter/lib/src/util/adaptive_extension.dart`

**实施方案**：

```dart
// adaptive_extension.dart
import 'package:flutter/material.dart';

/// 设备类型枚举（与主应用保持一致）
enum AppDeviceType {
  iphone,
  ipad;
  
  bool get isPhone => this == AppDeviceType.iphone;
  bool get isTablet => this == AppDeviceType.ipad;
}

/// 自适应尺寸工具类
class Adaptive {
  Adaptive._();
  
  // 静态回调，主应用注册提供设备类型
  static AppDeviceType Function(BuildContext)? _deviceTypeProvider;
  
  /// 注册设备类型提供者（主应用启动时调用）
  static void registerDeviceTypeProvider(
    AppDeviceType Function(BuildContext) provider,
  ) {
    _deviceTypeProvider = provider;
  }
  
  /// 获取设备类型（优先使用注册的提供者）
  static AppDeviceType getDeviceType(BuildContext context) {
    if (_deviceTypeProvider != null) {
      return _deviceTypeProvider!(context);
    }
    // 回退到自动检测
    return MediaQuery.of(context).size.shortestSide >= 600
        ? AppDeviceType.ipad
        : AppDeviceType.iphone;
  }
  
  /// 统一缩放逻辑
  static double _scale(BuildContext context, num value, String type) {
    if (getDeviceType(context).isTablet) {
      return value.toDouble() * DeviceScale.of(type);
    }
    return value.toDouble();
  }
  
  // ... 其他方法保持不变
}

// BuildContext 扩展
extension AdaptiveContext on BuildContext {
  bool get ipad => Adaptive.getDeviceType(this).isTablet;
  bool get iphone => Adaptive.getDeviceType(this).isPhone;
  // ... 其他扩展方法
}
```

**主应用注册回调**：

```dart
// lib/main.dart 或 lib/app.dart
import 'package:tdesign_flutter/src/util/adaptive_extension.dart' as plugin_adaptive;

// 在 main() 或 runApp() 之前
plugin_adaptive.Adaptive.registerDeviceTypeProvider((context) {
  // 从 DeviceTypeProvider 获取用户选择的设备类型
  final container = ProviderScope.containerOf(context);
  final deviceType = container.read(deviceTypeProvider);
  return plugin_adaptive.AppDeviceType.values.firstWhere(
    (e) => e.name == deviceType.name,
    orElse: () => plugin_adaptive.AppDeviceType.iphone,
  );
});
```

---

### 阶段 2: 修复按钮/输入框尺寸

**目标**：确保所有尺寸在 iPad 上正确缩放。

**修改文件**：
1. `plugs/tdesign_flutter/lib/src/components/dialog/td_dialog_widget.dart`
2. `plugs/tdesign_flutter/lib/src/components/dialog/td_input_dialog.dart`

**验证清单**：
- [ ] TDDialogScaffold 宽度计算正确
- [ ] TDDialogTitle 字体大小正确 (18→24.84sp)
- [ ] TDDialogContent 字体大小正确 (16→22.08sp)
- [ ] HorizontalTextButtons 按钮高度正确 (56→72.8pt)
- [ ] TDInputDialog 输入框 margin 正确 (24→31.2pt)
- [ ] 关闭按钮尺寸正确 (38→49.4pt)

**测试方法**：
1. 在 iPad 模拟器上运行应用
2. 打开"WiFi 传输端口"弹窗
3. 验证所有尺寸是否按比例放大

---

### 阶段 3: 添加 Android 设备类型选择 UI

**目标**：在个人中心页面添加设备类型选择功能。

**修改文件**：
1. `lib/views/profile/profile_page.dart` (添加设置项)
2. 新建 `lib/widgets/device_type_selector.dart` (选择器组件)

**UI 设计**：

```
┌─────────────────────────────────────────────────────────────┐
│  个人中心                                                    │
├─────────────────────────────────────────────────────────────┤
│  ...                                                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  设置                                                │   │
│  │  ┌───────────────────────────────────────────────┐  │   │
│  │  │  外观设置                    >                 │  │   │
│  │  ├───────────────────────────────────────────────┤  │   │
│  │  │  字幕设置                    >                 │  │   │
│  │  ├───────────────────────────────────────────────┤  │   │
│  │  │  AI 服务                     >                 │  │   │
│  │  ├───────────────────────────────────────────────┤  │   │
│  │  │  设备类型          [自动检测 ▾]                │  │   │  ← 新增
│  │  ├───────────────────────────────────────────────┤  │   │
│  │  │  WiFi 传输端口                >                 │  │   │
│  │  ├───────────────────────────────────────────────┤  │   │
│  │  │  子账号设置                  >                 │  │   │
│  │  └───────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**选择器弹窗**：

```
┌─────────────────────────────────────────┐
│  选择设备类型                            │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  ● 自动检测 (推荐)              │   │
│  │    根据屏幕尺寸自动判断          │   │
│  ├─────────────────────────────────┤   │
│  │  ○ 手机                         │   │
│  │    使用手机布局                  │   │
│  ├─────────────────────────────────┤   │
│  │  ○ 平板                         │   │
│  │    使用平板布局                  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  提示: 安卓设备建议手动选择以获得最佳    │
│        显示效果                          │
│                                         │
│          [取消]  [确定]                  │
└─────────────────────────────────────────┘
```

**代码实现**：

```dart
// lib/widgets/device_type_selector.dart
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
            value: AppDeviceType.iphone, // 默认使用手机布局
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

### 阶段 4: 更新 DeviceTypeProvider

**目标**：支持"自动检测"选项。

**修改文件**：
1. `lib/models/device_type.dart` (添加 auto 类型)
2. `lib/providers/device_type_provider.dart` (支持 auto 检测)

**修改 `AppDeviceType` 枚举**：

```dart
// lib/models/device_type.dart
enum AppDeviceType {
  auto,    // 自动检测
  iphone,  // 强制手机布局
  ipad;    // 强制平板布局

  bool get isPhone => this == AppDeviceType.iphone;
  bool get isTablet => this == AppDeviceType.ipad;
  bool get isAuto => this == AppDeviceType.auto;
}
```

**修改 `DeviceTypeNotifier`**：

```dart
// lib/providers/device_type_provider.dart
class DeviceTypeNotifier extends StateNotifier<AppDeviceType> {
  DeviceTypeNotifier() : super(AppDeviceType.auto) {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final override = prefs.getString(_kDeviceTypeKey);
      if (override != null && override.isNotEmpty) {
        state = AppDeviceType.values.firstWhere(
          (e) => e.name == override,
          orElse: () => AppDeviceType.auto,
        );
      }
    } catch (e) {
      debugPrint('[DeviceTypeProvider] init failed: $e');
      state = AppDeviceType.auto;
    }
  }

  /// 获取实际设备类型（用于 UI 布局）
  AppDeviceType getEffectiveType(BuildContext context) {
    if (state.isAuto) {
      // 自动检测
      return DeviceConfig.detectFromContext(context);
    }
    return state;
  }

  // ... 其他方法
}
```

---

## 四、执行步骤

### 步骤 1: 修复插件通信机制
1. 修改 `plugs/tdesign_flutter/lib/src/util/adaptive_extension.dart`
2. 添加静态回调机制
3. 在主应用注册回调

### 步骤 2: 验证按钮/输入框尺寸
1. 在 iPad 模拟器上测试
2. 验证所有尺寸是否正确缩放
3. 调整缩放因子（如需要）

### 步骤 3: 添加设备类型选择 UI
1. 创建 `lib/widgets/device_type_selector.dart`
2. 修改 `lib/views/profile/profile_page.dart` 添加设置项
3. 测试选择功能

### 步骤 4: 更新 DeviceTypeProvider
1. 修改 `lib/models/device_type.dart` 添加 auto 类型
2. 修改 `lib/providers/device_type_provider.dart` 支持 auto 检测
3. 更新所有使用 deviceTypeProvider 的代码

### 步骤 5: 文档更新
1. 更新 `docs/developer/design/design-style-guide.md`
2. 添加设备检测逻辑说明
3. 更新 AGENTS.md

---

## 五、测试清单

### 功能测试
- [ ] iOS 设备自动检测为 iPhone/iPad
- [ ] Android 设备默认自动检测
- [ ] 手动选择"手机"后使用手机布局
- [ ] 手动选择"平板"后使用平板布局
- [ ] 手动选择后重启应用保持选择

### UI 测试
- [ ] iPad 上弹窗宽度正确 (屏幕宽度×50%)
- [ ] iPad 上标题字体正确 (18×1.38=24.84sp)
- [ ] iPad 上按钮高度正确 (56×1.30=72.8pt)
- [ ] iPad 上输入框 margin 正确 (24×1.30=31.2pt)
- [ ] iPhone 上所有尺寸保持原值

### 兼容性测试
- [ ] 不同 iPad 型号（Pro、Air、mini）
- [ ] 不同 Android 设备（手机、平板）
- [ ] 屏幕旋转后布局正确

---

## 六、风险与注意事项

1. **插件通信**：确保主应用在使用插件组件前注册回调
2. **向后兼容**：保持现有 API 不变，仅添加新功能
3. **性能影响**：DeviceTypeProvider 读取 SharedPreferences 是异步操作，需处理加载状态
4. **Android 碎片化**：自动检测可能不准确，建议用户手动选择

---

**计划版本**: V1.0
**创建时间**: 2026-07-13
**状态**: 待确认后执行
