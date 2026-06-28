# VidLang UI 设计系统 - 基于 Pencil Skill

> **版本**: v2.0  
> **日期**: 2026-06-27  
> **基于**: Pencil UI Design Skill 工业级规范

---

## 📁 设计文件结构

```
docs/designs/
├── README.md                          # 本文件（设计说明）
├── vidlang-ui-design-system.pen       # 设计令牌（颜色、字体、间距等）
├── main-page.pen                      # 主页面（底部导航栏）
├── file-list-page.pen                 # 文件列表页（视频集管理）
├── player-page.pen                    # 视频播放页
├── word-book-page.pen                 # 生词本页面
└── ui-components.pen                  # 基础组件库
```

---

## 🎨 设计系统概览

### 1. 颜色系统

| 类别 | 变量名 | Light Mode | Dark Mode | 用途 |
|------|--------|------------|-----------|------|
| **品牌色** | `primaryBrand` | `#4ADE80` | `#4ADE80` | 主操作、强调元素 |
| **文本主色** | `textPrimary` | `#18181B` | `#FAFAFA` | 标题、重要文字 |
| **文本次要** | `textSecondary` | `#71717A` | `#A1A1AA` | 辅助文字、描述 |
| **页面背景** | `backgroundLight` | `#FAFAFA` | `#18181B` | 页面背景色 |
| **卡片背景** | `surfaceLight` | `#FFFFFF` | `#18181B` | 卡片/容器背景 |
| **次要表面** | `surfaceSecondaryLight` | `#F4F4F5` | `#27272A` | 次要区域背景 |
| **边框色** | `borderLight` | `#E4E4E7` | `#27272A` | 分隔线、边框 |

### 2. 字体层级

| 层级 | 大小 | 字重 | 行高 | 用途 |
|------|------|------|------|------|
| Display | 36px | 700 | 1.2 | 大标题（极少使用） |
| H1 | 24px | 600 | 1.3 | 页面标题 |
| H2 | 20px | 600 | 1.4 | 区块标题 |
| H3 | 18px | 600 | 1.4 | 卡片标题 |
| Body | 14px | 400 | 1.5 | 正文内容 |
| Small | 12px | 400 | 1.4 | 辅助信息 |
| Caption | 10px | 500 | 1.3 | 标签、徽章 |

### 3. 间距系统（4px 网格）

| 变量名 | 值 | 用途 |
|--------|-----|------|
| `xs` | 4px | 微小间距 |
| `sm` | 8px | 小间距、图标与文字 |
| `md` | 12px | 中等间距、内边距 |
| `lg` | 16px | 大间距、卡片外边距 |
| `xl` | 24px | 区块间距 |
| `2xl` | 32px | 页面边距 |
| `3xl` | 48px | 大区块间距 |

### 4. 圆角规范

| 变量名 | 值 | 用途 |
|--------|-----|------|
| `radius-sm` | 6px | 徽章、标签 |
| `radius-md` | 8px | 按钮、输入框 |
| `radius-lg` | 12px | 卡片、弹窗 |
| `radius-xl` | 16px | 大卡片 |
| `radius-full` | 9999px | 圆形头像、胶囊标签 |

---

## 📱 页面设计说明

### 1. 主页面 (MainPage)

**文件**: `main-page.pen`

**核心要素**:
- 底部导航栏：4 个 Tab（首页、视频集、收藏、我的）
- 导航项高度：80px（含安全区域）
- 图标大小：26px
- 文字大小：11px
- 选中状态：品牌色 `#4ADE80`
- 未选中状态：三级文本色 `#A1A1AA`
- 顶部边框：`outlineVariant` 色 `#E4E4E7`

**交互特性**:
- 支持 AnimatedContainer 动画（200ms）
- 点击反馈效果
- 安全区域适配

### 2. 文件列表页 (FileListPage)

**文件**: `file-list-page.pen`

**核心要素**:
- 导航栏：标题 + 添加按钮（圆形，品牌色）
- 搜索栏：44px 高度，圆角 8px
- 卡片网格：2 列布局，间距 12px
- 卡片圆角：12px，阴影 blur 4px
- 进度徽章：语义化颜色（成功/警告）

**状态变体**:
- 有数据状态：显示文件夹卡片网格
- 空数据状态：显示引导提示 + 新建按钮
- 加载状态：显示 Skeleton 占位符

### 3. 视频播放页 (PlayerPage)

**文件**: `player-page.pen`

**核心要素**:
- 背景：始终深色 `#000000`
- 视频区域：16:9 比例
- 字幕区域：半透明黑色背景 + 圆角
- 主操作按钮：56px，品牌色背景
- 进度条：品牌色填充
- 控制按钮层级：
  - 主按钮：56px
  - 操作按钮：32px
  - 辅助按钮：28px

**特殊处理**:
- 翻译文字使用金黄色 `#FFE082`
- 时间显示使用等宽字体 (SF Mono)
- 支持横屏模式

### 4. 生词本页面 (WordBookPage)

**文件**: `word-book-page.pen`

**核心要素**:
- 统计徽章：胶囊形状，品牌色系
- 搜索框：标准输入框样式
- 筛选标签：胶囊形状，选中深色背景
- 单词卡片：水平布局（信息 + 操作）
- 单词文本：16px + 600 字重
- 音标：等宽字体 + 灰色

**筛选选项**:
- 全部（默认选中）
- 未掌握
- 学习中
- 已掌握

---

## 🧩 基础组件库

**文件**: `ui-components.pen`

### 可复用组件清单

| 组件名 | 类型 | 尺寸 | 说明 |
|--------|------|------|------|
| **PrimaryButton** | 按钮 | 48px 高 | 主操作按钮，品牌色背景 |
| **SecondaryButton** | 按钮 | 48px 高 | 次要操作按钮，浅色背景 |
| **BaseCard** | 卡片 | 自适应 | 基础卡片容器 |
| **TitledCard** | 卡片 | 自适应 | 带标题行的卡片 |
| **TextInputField** | 输入框 | 48px 高 | 文本输入框，支持 Focus 状态 |
| **Badge** | 徽章 | 22px 高 | 默认徽章 |
| **SuccessBadge** | 徽章 | 22px 高 | 成功状态徽章 |
| **WarningBadge** | 徽章 | 22px 高 | 警告状态徽章 |
| **ErrorBadge** | 徽章 | 22px 高 | 错误状态徽章 |
| **Avatar** | 头像 | 多尺寸 | 圆形头像，支持图片/文字/图标 |

### 组件使用方式

所有组件都标记为 `reusable: true`，可通过以下方式复用：

```javascript
// 使用 ref 引用已定义的组件
myButton = I(parent, {type: "ref", ref: "PrimaryButton"})
```

---

## 🎯 设计原则

### 1. 一致性
- 所有页面遵循相同的设计令牌
- 统一的间距、圆角、阴影规范
- 一致的交互反馈模式

### 2. 层级清晰
- 通过颜色、大小、字重建立视觉层级
- 重要信息突出显示
- 次要信息适当弱化

### 3. 品牌识别
- 使用翠绿色 (`#4ADE80`) 作为主品牌色
- 在关键操作和强调元素上应用
- 保持与多邻国风格的延续性

### 4. 无障碍访问
- 足够的颜色对比度（符合 WCAG 2.1 AA 标准）
- 清晰的文字大小（最小 10px）
- 合理的点击区域（最小 40x40px）

---

## 🔧 实现指南

### 从设计到代码的转换步骤

1. **读取设计文件**
   ```bash
   # 使用 Pencil MCP 工具打开 .pen 文件
   ```

2. **提取设计令牌**
   - 从 `vidlang-ui-design-system.pen` 提取颜色、字体、间距值
   - 映射到 Flutter 的 `AppColors`, `AppTypography`, `AppSpacing` 等

3. **实现组件**
   - 按照 `ui-components.pen` 中的定义实现每个组件
   - 使用 `flutter_screenutil` 进行屏幕适配
   - 添加交互动画和状态管理

4. **构建页面**
   - 参考各页面的 `.pen` 设计文件构建页面
   - 使用已实现的组件进行组合
   - 处理各种状态（加载、空数据、错误等）

5. **测试验证**
   - 在亮色/暗色主题下验证视觉效果
   - 测试不同屏幕尺寸的适配
   - 验证交互行为的正确性

---

## 📊 与现有代码的映射关系

| 设计文件 | 对应代码文件 | 状态 |
|----------|-------------|------|
| `vidlang-ui-design-system.pen` | `lib/theme/*.dart` | ✅ 已实现 |
| `main-page.pen` | `lib/views/main/main_page.dart` | ✅ 已实现 |
| `file-list-page.pen` | `lib/views/file_list_page.dart` | ⏳ 待实现 |
| `player-page.pen` | `lib/views/player/player_page.dart` | ⏳ 待实现 |
| `word-book-page.pen` | `lib/views/word_book_page.dart` | ⏳ 待实现 |
| `ui-components.pen` | `lib/components/ui/*.dart` | ✅ 已实现 |

---

## 🔄 版本历史

| 版本 | 日期 | 更新内容 |
|------|------|---------|
| v1.0 | 2026-05-19 | 初始版本，基于多邻国风格 |
| v2.0 | 2026-06-27 | 基于 Pencil Skill 全面重构，引入工业级设计规范 |

---

## 📚 相关资源

- **Pencil UI Design Skill**: `.codex/skills/pencil-ui-design/SKILL.md`
- **现有项目文档**: `docs/AGENT_CONTEXT.md`, `docs/design-style-guide.md`
- **旧版设计文件**: `docs/pages/files-v2.pen`, `docs/pages/files-components.pen`
