# TDDialog 弹窗组件硬编码尺寸修复计划

> **版本**: V1.0 | **日期**: 2026-07-13
> **问题**: iPad 弹窗尺寸不合适，未使用 adaptive.dart 自适应工具类

---

## 一、问题根源

项目中有完整的自适应工具类 `lib/utils/adaptive.dart`，但 TDDialog 系列组件未使用，导致：
- iPhone 上显示正常
- iPad 上弹窗太小、字体太小、比例失调

---

## 二、硬编码尺寸清单

### 2.1 TDDialogScaffold (td_dialog_widget.dart)

| 行号 | 硬编码值 | 说明 | 修复方式 |
|------|----------|------|----------|
| 43 | `width ?? 311` | 弹窗宽度 | 使用 `Adaptive.w()` 或根据屏幕宽度计算 |
| 61 | `width: 38` | 关闭按钮容器宽度 | 使用 `Adaptive.w()` |
| 62 | `height: 38` | 关闭按钮容器高度 | 使用 `Adaptive.h()` |
| 66 | `size: 22` | 关闭按钮图标大小 | 使用 `Adaptive.icon()` |

### 2.2 TDDialogTitle (td_dialog_widget.dart)

| 行号 | 硬编码值 | 说明 | 修复方式 |
|------|----------|------|----------|
| 102 | `Font(size: 18, lineHeight: 26)` | 标题字体大小和行高 | 使用 `Adaptive.sp()` |

### 2.3 TDDialogContent (td_dialog_widget.dart)

| 行号 | 硬编码值 | 说明 | 修复方式 |
|------|----------|------|----------|
| 128 | `Font(size: 16, lineHeight: 24)` | 内容字体大小和行高 | 使用 `Adaptive.sp()` |

### 2.4 TDDialogInfoWidget (td_dialog_widget.dart)

| 行号 | 硬编码值 | 说明 | 修复方式 |
|------|----------|------|----------|
| 145 | `EdgeInsets.fromLTRB(24, 32, 24, 0)` | 内边距 | 使用 `Adaptive.w()` 和 `Adaptive.h()` |
| 192 | `8.0` | 标题和内容间距 | 使用 `Adaptive.h()` |

### 2.5 HorizontalNormalButtons (td_dialog_widget.dart)

| 行号 | 硬编码值 | 说明 | 修复方式 |
|------|----------|------|----------|
| 234 | `EdgeInsets.fromLTRB(24, 0, 24, 24)` | 按钮区域内边距 | 使用 `Adaptive.w()` 和 `Adaptive.h()` |
| 258 | `height: 0.5` | 分割线高度 | 保持不变（0.5是合理的） |
| 259 | `width: 12` | 分割线宽度 | 保持不变（12是合理的） |

### 2.6 HorizontalTextButtons (td_dialog_widget.dart)

| 行号 | 硬编码值 | 说明 | 修复方式 |
|------|----------|------|----------|
| 306 | `height: 0.5` | 分割线高度 | 保持不变（0.5是合理的） |
| 319 | `height: 56` | 左按钮高度 | 使用 `Adaptive.h()` |
| 332 | `width: 0.5` | 分割线宽度 | 保持不变（0.5是合理的） |
| 332 | `height: 56` | 分割线高度 | 使用 `Adaptive.h()` |
| 342 | `height: 56` | 右按钮高度 | 使用 `Adaptive.h()` |

### 2.7 TDInputDialog (td_input_dialog.dart)

| 行号 | 硬编码值 | 说明 | 修复方式 |
|------|----------|------|----------|
| 19 | `radius = 12.0` | 圆角 | 使用 `Adaptive.r()` |
| 30 | `EdgeInsets.fromLTRB(24, 32, 24, 0)` | 内边距 | 使用 `Adaptive.w()` 和 `Adaptive.h()` |
| 106 | `EdgeInsets.fromLTRB(24, 16, 24, 24)` | 输入框外边距 | 使用 `Adaptive.w()` 和 `Adaptive.h()` |
| 112 | `EdgeInsets.symmetric(horizontal: 16)` | 输入框内边距 | 使用 `Adaptive.w()` |
| 141 | `height: 56` | 左按钮高度 | 使用 `Adaptive.h()` |
| 147 | `height: 56` | 右按钮高度 | 使用 `Adaptive.h()` |

### 2.8 TDDialogButton (td_dialog_widget.dart)

| 行号 | 硬编码值 | 说明 | 修复方式 |
|------|----------|------|----------|
| 372 | `height = 40.0` | 按钮默认高度 | 使用 `Adaptive.h()` |

---

## 三、修复优先级

### P0 - 必须修复（影响 iPad 显示）

1. **TDDialogScaffold.width** - 弹窗宽度（核心问题）
2. **TDDialogTitle.font** - 标题字体大小
3. **TDDialogContent.font** - 内容字体大小
4. **HorizontalTextButtons.height** - 按钮高度

### P1 - 应该修复（影响间距和内边距）

5. **TDDialogInfoWidget.padding** - 内边距
6. **TDDialogScaffold 关闭按钮** - 图标和容器尺寸
7. **TDInputDialog 输入框内边距** - 输入框外边距

### P2 - 建议修复（优化体验）

8. **TDDialogButton.height** - 按钮默认高度
9. **TDDialogScaffold.radius** - 圆角

---

## 四、修复方案

### 4.1 TDDialogScaffold 弹窗宽度

**原代码**：
```dart
width: width ?? 311,
```

**修复后**：
```dart
width: width ?? _calculateWidth(context),
```

**新增方法**：
```dart
double _calculateWidth(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  if (isIPad(context)) {
    // iPad：屏幕宽度的50%，最大400pt
    return (screenWidth * 0.5).clamp(300, 400);
  }
  // iPhone：固定311pt
  return 311;
}
```

### 4.2 TDDialogTitle 字体

**原代码**：
```dart
font: Font(size: 18, lineHeight: 26),
```

**修复后**：
```dart
font: Font(size: context.ts(18), lineHeight: context.ts(26)),
```

### 4.3 TDDialogContent 字体

**原代码**：
```dart
font: Font(size: 16, lineHeight: 24),
```

**修复后**：
```dart
font: Font(size: context.ts(16), lineHeight: context.ts(24)),
```

### 4.4 HorizontalTextButtons 按钮高度

**原代码**：
```dart
height: 56,
```

**修复后**：
```dart
height: context.s(56),
```

### 4.5 TDDialogInfoWidget 内边距

**原代码**：
```dart
this.padding = const EdgeInsets.fromLTRB(24, 32, 24, 0),
```

**修复后**：
```dart
this.padding, // 移除默认值，在build中动态计算
```

**build方法中**：
```dart
final effectivePadding = padding ?? EdgeInsets.fromLTRB(
  context.s(24),
  context.s(32),
  context.s(24),
  0,
);
```

### 4.6 TDInputDialog 圆角

**原代码**：
```dart
this.radius = 12.0,
```

**修复后**：
```dart
this.radius, // 移除默认值，在build中动态计算
```

**build方法中**：
```dart
final effectiveRadius = radius ?? context.rs(12);
```

---

## 五、依赖关系

修复顺序需要考虑组件间的依赖：

1. **先修复 TDDialogScaffold** - 基础组件，其他组件依赖它
2. **再修复 TDDialogTitle 和 TDDialogContent** - 文字组件
3. **然后修复 TDDialogInfoWidget** - 容器组件
4. **最后修复 HorizontalNormalButtons 和 HorizontalTextButtons** - 按钮组件
5. **最后修复 TDInputDialog** - 输入弹窗组件

---

## 六、测试验证

修复后需要验证：
1. iPhone 上显示正常（375-414pt 宽度）
2. iPad 上显示合适（768-1024pt 宽度）
3. 横屏和竖屏都正常
4. 键盘弹出时弹窗位置正确

---

## 七、设计规范更新

需要在 `docs/developer/design/design-style-guide.md` 中添加：

### 弹窗尺寸规范

| 设备 | 弹窗宽度 | 标题字体 | 内容字体 | 按钮高度 |
|------|----------|----------|----------|----------|
| iPhone | 311pt | 18sp | 16sp | 56pt |
| iPad | 屏幕50%（max 400pt） | 18×1.38≈25sp | 16×1.38≈22sp | 56×1.30≈73pt |

### 间距规范

| 元素 | iPhone | iPad | 说明 |
|------|--------|------|------|
| 弹窗内边距 | 24,32,24,0 | 24×1.30,32×1.30,24×1.30,0 | TDDialogInfoWidget |
| 输入框外边距 | 24,16,24,24 | 24×1.30,16×1.30,24×1.30,24×1.30 | TDInputDialog |
| 输入框内边距 | 16 | 16×1.30 | TDInputDialog |

---

**文档版本**：V1.0
**创建时间**：2026-07-13
