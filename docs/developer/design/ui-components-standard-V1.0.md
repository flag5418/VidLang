# VidLang UI 组件标准规范

**版本**: V1.0
**日期**: 2026-07-15
**状态**: 生效中

---

## 一、概述

本文档定义了 `lib/components/ui/` 目录下标准组件的使用规范，确保项目 UI 代码的一致性和可维护性。

### 1.1 设计原则

- **渐进式统一**: 新代码必须使用标准组件，旧代码在重构时逐步迁移
- **语义化优先**: 组件命名和参数应清晰表达设计意图
- **主题自适应**: 所有组件支持亮色/暗色模式
- **响应式友好**: 使用 Adaptive 工具类适配不同屏幕尺寸

### 1.2 组件清单

| 组件 | 文件 | 用途 | 优先级 |
|------|------|------|--------|
| [BaseCard](#二basecard-基础卡片) | `base_card.dart` | 通用卡片容器 | ⭐⭐⭐ 必须 |
| [TitledCard](#三titledcard-带标题卡片) | `base_card.dart` | 带标题的卡片 | ⭐⭐⭐ 必须 |
| [EmptyState](#四emptystate-空状态) | `empty_state.dart` | 空数据占位 | ⭐⭐⭐ 必须 |
| [Avatar](#五avatar-头像) | `avatar.dart` | 用户头像 | ⭐⭐ 推荐 |
| [Badge](#六badge-徽章) | `badge.dart` | 状态标签 | ⭐⭐ 推荐 |

---

## 二、BaseCard 基础卡片

### 2.1 组件说明

统一的卡片容器组件，支持三种视觉变体：

```dart
import 'package:vidlang/components/ui/ui_components.dart';
```

### 2.2 三种变体

#### ✅ `BaseCard()` — 默认卡片

- 白色背景（跟随主题）
- 轻微阴影（无显式边框）
- 适用于：一般内容容器

```dart
BaseCard(
  padding: EdgeInsets.all(16),
  child: Text('内容'),
)
```

#### ✅ `BaseCard.outlined()` — 描边卡片

- 白色背景 + 细边框（0.5pt）
- 无阴影
- 适用于：设置项、表单区域、信息展示

```dart
BaseCard.outlined(
  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  child: Row(children: [...]),
)
```

**实际案例**: `user_settings_page.dart` 的用户卡片

#### ✅ `BaseCard.elevated()` — 阴影卡片

- 柔和双层阴影
- 可选边框
- 支持按压缩放动画
- 适用于：可点击卡片、悬浮卡片

```dart
BaseCard.elevated(
  onTap: () => print(' tapped'),
  enableScaleAnimation: true,
  child: Text('点击我'),
)
```

#### ✅ `BaseCard.filled()` — 实色背景卡片

- 自定义背景色
- 无边框无阴影
- 适用于：强调区域、品牌色背景

```dart
BaseCard.filled(
  backgroundColor: AppColors.primaryBrandLight,
  child: Text('重要提示'),
)
```

### 2.3 核心参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `child` | `Widget` | 必填 | 卡片内容 |
| `onTap` | `VoidCallback?` | null | 点击回调 |
| `padding` | `EdgeInsetsGeometry?` | null | 内边距（不强制） |
| `margin` | `EdgeInsetsGeometry?` | null | 外边距（不强制） |
| `showBorder` | `bool` | false | 是否显示边框 |
| `borderRadius` | `double?` | `AppRadius.card` | 圆角半径 |
| `backgroundColor` | `Color?` | null | 背景色（默认跟随主题） |
| `enableScaleAnimation` | `bool` | false | 按压缩放效果 |

### 2.4 使用边界

#### ✅ 应该使用 BaseCard 的场景

- 设置页选项卡片
- 表单区域容器
- 统计数据展示卡片
- 对话框内的内容区块
- 任何"白底+圆角+简单内容"的容器

#### ❌ 不应该使用 BaseCard 的场景

- **业务专用卡片**: VideoCard, FolderCard, AudioHeroCard, ArticleItemCard 等（内部有复杂 Stack 布局）
- **播放器控件**: 需要特殊交互的区域
- **高度定制化卡片**: 有复杂渐变、多层叠加效果的卡片

---

## 三、TitledCard 带标题卡片

### 3.1 组件说明

在 BaseCard 基础上增加标题行，适用于设置分组、统计面板等场景。

### 3.2 使用示例

```dart
TitledCard(
  title: '学习统计',
  subtitle: '本周数据',
  leadingIcon: Icons.bar_chart,
  actions: [
    IconButton(icon: Icon(Icons.refresh), onPressed: () {}),
  ],
  child: Column(
    children: [
      Text('统计内容...'),
    ],
  ),
)
```

### 3.3 核心参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `title` | `String` | 标题文字（必填） |
| `subtitle` | `String?` | 副标题 |
| `leadingIcon` | `IconData?` | 标题前图标 |
| `actions` | `List<Widget>?` | 标题后操作按钮 |
| `child` | `Widget` | 内容区域（必填） |

---

## 四、EmptyState 空状态

### 4.1 组件说明

标准的空数据占位组件，支持三种模式：
- **默认模式**: Center 包裹，适用于全屏空状态
- **紧凑模式** (`compact`): 无 Center，适用于 ListView/Column 内部
- **装饰图标模式** (`iconBackgroundColor`): 图标外层有圆形彩色背景

### 4.2 使用示例

```dart
// 基础用法（全屏空状态）
EmptyState(
  icon: AppIcons.inbox,
  title: '暂无数据',
  description: '点击刷新试试',
)

// 带操作按钮
EmptyState(
  icon: AppIcons.article,
  title: '暂无文章',
  description: '点击右下角按钮创建第一篇',
  actionLabel: '创建文章',
  onAction: () => _navigateToCreate(),
)

// 带圆形图标背景（文件夹、资源列表等场景）
EmptyState(
  icon: AppIcons.folderOpen,
  title: '暂无文件夹',
  description: '点击右上角 + 创建',
  iconBackgroundColor: Colors.blue.withValues(alpha: 0.08),  // 圆形背景色
  iconColor: Colors.blue.withValues(alpha: 0.6),              // 图标颜色
)

// 紧凑模式（用于 ListView/Column 内部）
ListView(
  children: [
    EmptyState.compact(
      icon: AppIcons.autoAwesome,
      title: '暂无AI点评',
      description: '跟读练习后点击请求点评',
      topPadding: 40,  // 顶部间距
    ),
  ],
)

// 自定义操作按钮（使用 TDButton 替代默认 OutlinedButton）
EmptyState(
  icon: AppIcons.forum,
  title: '暂无帖子',
  actionLabel: '发布第一个帖子',
  onAction: () => _navigateToCreate(),
  actionBuilder: (label, onPressed) => TDButton(
    text: label,
    onTap: onPressed,
    type: TDButtonType.fill,
    theme: TDButtonTheme.primary,
  ),
)
```

### 4.3 核心参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `icon` | `IconData` | 必填 | 图标 |
| `title` | `String` | 必填 | 标题文字 |
| `description` | `String?` | null | 描述文字 |
| `actionLabel` | `String?` | null | 按钮文字 |
| `onAction` | `VoidCallback?` | null | 按钮回调 |
| `iconSize` | `double?` | 48 | 图标大小 |
| `iconColor` | `Color?` | textWeak | 图标颜色 |
| `iconBackgroundColor` | `Color?` | null | 圆形背景色（设置后显示圆形背景） |
| `iconBackgroundPadding` | `double?` | 20 | 圆形背景内边距 |
| `titleStyle` | `TextStyle?` | null | 标题文字样式（覆盖默认） |
| `descriptionStyle` | `TextStyle?` | null | 描述文字样式（覆盖默认） |
| `compact` | `bool` | false | 紧凑模式（无 Center 包裹） |
| `actionBuilder` | `Widget Function?` | null | 自定义按钮构建器 |
| `topPadding` | `double?` | null | 紧凑模式的顶部间距 |

### 4.4 Factory 构造函数

| 构造函数 | 说明 | 适用场景 |
|---------|------|---------|
| `EmptyState()` | 默认模式，Center 包裹 | 全屏空状态 |
| `EmptyState.compact()` | 紧凑模式，无 Center | ListView/Column 内部 |

### 4.5 已替换的场景（9处）

| # | 页面 | 使用模式 | 特殊定制 |
|---|------|---------|----------|
| 1 | `collection_page.dart` | 默认模式 | 标准用法 |
| 2 | `article_list_page.dart` | 默认模式 | 标准用法 |
| 3 | `topup_page.dart` | 默认模式 | 标准用法 |
| 4 | `forum_home_page.dart` | 默认模式 + actionBuilder | 使用 TDButton |
| 5 | `folder_detail_page.dart` | 默认模式 + iconBackground | 圆形类型色背景 |
| 6 | `file_list_page.dart` | 默认模式 + iconBackground | 圆形类型色背景 + 条件描述 |
| 7 | `topup_history_page.dart` | 默认模式 | 标准用法 |
| 8 | `billing_rules_page.dart` | 默认模式 | 标准用法 |
| 9 | `ai_evaluation_sheet.dart` | compact 模式 | ListView 内部使用 |

---

## 五、Avatar 头像

### 5.1 组件说明

统一的头像组件，支持图片、文字、图标三种显示模式。

### 5.2 使用示例

```dart
// 图片头像
Avatar(
  imageUrl: 'https://example.com/avatar.jpg',
  size: AvatarSize.lg,
)

// 文字头像（自动提取首字母）
Avatar(
  text: '张三',
  size: AvatarSize.md,
)

// 可点击 + 编辑徽章
Avatar(
  text: '用户名',
  showEditBadge: true,
  onTap: () => _editAvatar(),
)
```

### 5.3 尺寸规格

| 枚举 | 值 (pt) | 字体大小 | 图标大小 | 适用场景 |
|------|---------|---------|---------|---------|
| `AvatarSize.xs` | 32 | 12 | 16 | 列表小头像 |
| `AvatarSize.sm` | 40 | 14 | 20 | 卡片内头像 |
| `AvatarSize.md` | 48 | 16 | 24 | 默认尺寸 |
| `AvatarSize.lg` | 64 | 20 | 32 | 详情页头像 |
| `AvatarSize.xl` | 80 | 24 | 40 | 大头像展示 |

### 5.4 核心参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `imageUrl` | `String?` | null | 图片 URL 或本地路径 |
| `text` | `String?` | null | 显示文字（自动提取首字母） |
| `icon` | `IconData?` | null | 显示图标 |
| `size` | `AvatarSize` | `md` | 尺寸 |
| `onTap` | `VoidCallback?` | null | 点击回调 |
| `showEditBadge` | `bool` | false | 显示编辑图标徽章 |
| `badge` | `Widget?` | null | 自定义徽章 |

### 5.5 迁移策略

**新代码**: 强制使用 Avatar 组件

**旧代码**: 
- ✅ 可以替换：纯展示型 CircleAvatar（无自定义颜色逻辑）
- ❌ 保持不变：有复杂自定义样式的 CircleAvatar（如 profile_page 的本地文件读取 + 条件颜色）

---

## 六、Badge 徽章

### 6.1 组件说明

状态标签组件，提供基础 Badge 和四个语义化子类。

### 6.2 使用示例

```dart
// 基础用法
Badge(
  text: '进行中',
  backgroundColor: AppColors.primaryBrandLight,
  icon: AppIcons.playCircle,
)

// 语义化子类
SuccessBadge(text: '已完成')
WarningBadge(text: '待处理')
ErrorBadge(text: '失败')
InfoBadge(text: '提示')
```

### 6.3 语义化子类规格

| 子类 | 背景色 | 文字色 | 图标 | 适用场景 |
|------|--------|--------|------|---------|
| `SuccessBadge` | `primaryBrandLight` | `primaryBrandDark` | `checkCircleOutline` | 成功状态 |
| `WarningBadge` | `#FEF3C7` | `#D97706` | `warning` | 警告状态 |
| `ErrorBadge` | `#FEE2E2` | `error` | `error` | 错误状态 |
| `InfoBadge` | `#DBEAFE` | `info` | `info` | 信息提示 |

---

## 七、开发规范

### 7.1 Import 规范

统一使用 barrel file 导入：

```dart
// ✅ 正确
import 'package:vidlang/components/ui/ui_components.dart';

// ❌ 错误（不要单独导入子文件）
import 'package:vidlang/components/ui/base_card.dart';
import 'package:vidlang/components/ui/avatar.dart';
```

### 7.2 新页面开发检查清单

- [ ] 卡片容器是否使用 BaseCard 及其变体？
- [ ] 空状态是否使用 EmptyState？
- [ ] 头像是否使用 Avatar？（避免手写 CircleAvatar）
- [ ] 状态标签是否使用 Badge 系列？
- [ ] 是否通过 ui_components.dart 统一导入？

### 7.3 旧代码迁移指南

当重构旧代码时，按以下优先级替换：

1. **P0 - 立即替换**: 手写空状态 → EmptyState（投入产出比最高）
2. **P1 - 逐步替换**: 手写卡片容器 → BaseCard（在相关重构时顺带处理）
3. **P2 - 新代码强制**: 新页面必须使用标准组件
4. **P3 - 保持不变**: 高度定制化的业务组件（VideoCard 等）

---

## 八、版本历史

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| V1.0 | 2026-07-15 | 初始版本，定义 BaseCard/EmptyState/Avatar/Badge 规范 |

---

**维护者**: AI Coding Assistant
**审核状态**: 待人工审核
