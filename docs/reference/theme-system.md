# 主题系统知识库

> **版本**: v3.0 (设计升级版)
> **最后更新**: 2026-07-12
> **状态**: ✅ 已启用 - 完整的亮色/暗色双主题 + TDesign 集成
> **核心文件**: `lib/theme/`

---

## 📋 目录

1. [核心原则](#核心原则)
2. [架构概览](#架构概览)
3. [Design Tokens 设计令牌](#design-tokens-设计令牌)
4. [颜色系统 (AppColors)](#颜色系统-appcolors)
5. [字体排版 (AppTypography)](#字体排版-apptypography)
6. [间距规范 (AppSpacing)](#间距规范-appspacing)
7. [圆角规范 (AppRadius)](#圆角规范-appradius)
8. [ThemeData 配置 (AppTheme)](#themedata-配置-apptheme)
9. [TDesign 主题集成](#tdesign-主题集成)
10. [使用示例](#使用示例)
11. [最佳实践](#最佳实践)

---

## 核心原则

### ⚠️ 强制规范

> **所有 UI 组件必须使用 Design Tokens，禁止硬编码颜色值、字号、间距。**

**设计体系**:
- ✅ **Design Tokens**: 颜色、字体、间距、圆角的统一命名
- ✅ **双模式支持**: 亮色 (Light) / 暗色 (Dark) 自动切换
- ✅ **Context 扩展**: `context.colors` / `context.text` 快速访问
- ✅ **向后兼容**: 保留旧 API，渐进式迁移

**禁止行为**:
- ❌ 硬编码颜色值：`Color(0xFF3B6EFF)` → 用 `AppColors.primary`
- ❌ 硬编码字号：`fontSize: 16` → 用 `AppTypography.fontSizeBase`
- ❌ 硬编码间距：`padding: EdgeInsets.all(16)` → 用 `AppSpacing.md`
- ❌ 忽略暗色模式适配

---

## 架构概览

### 文件结构

```
lib/theme/
├── app_colors.dart        # 颜色系统（核心）
├── app_typography.dart    # 字体排版
├── app_spacing.dart       # 间距规范
├── app_radius.dart        # 圆角规范
├── app_theme.dart         # ThemeData 配置
├── design_tokens.dart     # Design Tokens 汇总（可选）
└── app_icons.dart         # 项目图标
```

### 数据流向

```
MaterialApp(
  theme: AppTheme.lightTheme,      // 亮色主题
  darkTheme: AppTheme.darkTheme,   // 暗色主题
  themeMode: themeModeProvider,   // 主题模式（system/light/dark）
)
     │
     ▼
BuildContext (Widget 树中的任意位置)
     │
     ├── context.colors      → AppColorsData (自动根据 brightness 切换)
     ├── Theme.of(context)   → Flutter 原生 ThemeData
     └── TDTheme.of(context) → TDesign 主题数据
```

---

## Design Tokens 设计令牌

### Token 命名规范

```
{类别}{属性}{状态?}{变体?}

示例：
- primaryBrand          # 品牌主色
- textPrimary           # 主要文字
- surfaceDark           # 暗色表面
- borderLightLight      # 亮色模式的浅边框
- radiusLg              # 大圆角
- space5                # 5级间距
- fontSizeBase          # 基础字号
```

### Token 分类

| 类别 | 前缀 | 示例 |
|------|------|------|
| 颜色 | `{color}{Name}` | `primaryBrand`, `error`, `surface` |
| 字体 | `font{Name}` | `fontSizeBase`, `fontWeightSemibold` |
| 间距 | `space{n}` | `space1`, `space2`, ..., `space10` |
| 圆角 | `radius{Name}` | `radiusSm`, `radiusMd`, `radiusLg` |

---

## 颜色系统 (AppColors)

### AppColorsData（运行时颜色容器）

```dart
class AppColorsData {
  // === 背景层级 ===
  final Color background;      // 页面背景（最底层）
  final Color surface;         // 卡片/面板背景
  final Color surfaceElevated; // 浮层背景（弹窗、下拉）
  final Color surfaceHighest;  // 最高层级（输入框、分割线）

  // === 文字色 ===
  final Color textPrimary;     // 主要文字（标题）
  final Color textSecondary;   // 次要文字（正文）
  final Color textWeak;        // 辅助文字（说明、占位符）
  final Color textDisabled;    // 禁用文字

  // === 品牌色 ===
  final Color primary;         // 主色调（按钮、链接）
  final Color primaryDark;     // 主色调深色（按下状态）
  final Color primaryLight;    // 主色调浅色（悬停、背景）

  // === 语义色 ===
  final Color error;           // 错误（删除、警告）
  final Color success;         // 成功（确认、完成）
  final Color warning;         // 警告（注意、提示）
  final Color info;            // 信息（帮助、链接）

  // === 资源类型色 ===
  final Color videoType;       // 视频标识色
  final Color articleType;     // 文章标识色
  final Color audioType;       // 音频标识色
}
```

### 亮色/暗色定义

#### 亮色模式 (Light)

```
Background:  #F8FAFC (极浅灰)
Surface:     #FFFFFF (纯白)
TextPrimary: #0F172A (近黑)
Primary:     #3B6EFF (品牌蓝)
Error:       #EF4444 (红色)
Success:     #22C55E (绿色)
Warning:     #F59E0B (橙色)
Border:      #E2E8F0 (浅灰边框)
```

#### 暗色模式 (Dark)

```
Background:  #09090B (近黑)
Surface:     #18181B (深灰)
TextPrimary: #FAFAFA (近白)
Primary:     #60A5FA (亮蓝)
Error:       #F87171 (浅红)
Success:     #4ADE80 (亮绿)
Warning:     #FBBF24 (亮橙)
Border:      #27272A (深灰边框)
```

### 使用方式

#### 方式 1：Context 扩展（推荐）✅

```dart
@override
Widget build(BuildContext context) {
  final colors = context.colors;

  return Container(
    color: colors.background,
    child: Text(
      'Hello',
      style: TextStyle(color: colors.textPrimary),
    ),
  );
}
```

#### 方式 2：静态 API（向后兼容）

```dart
// 需要手动传入 brightness
Container(
  color: AppColors.getSurface(brightness: Brightness.dark),
)

// 或直接使用固定值（不推荐，无法自动切换暗色）
Container(
  color: AppColors.surfaceLight,  // ⚠️ 仅亮色
)
```

#### 方式 3：Flutter ThemeData

```dart
// 通过 Theme.of(context) 获取
Theme.of(context).colorScheme.primary
Theme.of(context).scaffoldBackgroundColor
```

### 背景层级规范

| 层级 | Light Token | Dark Token | 使用场景 |
|------|-------------|------------|----------|
| Level 0 | `background` | `background` | Scaffold 背景 |
| Level 1 | `surface` | `surface` | 卡片、列表项 |
| Level 2 | `surfaceElevated` | `surfaceElevated` | 弹窗、抽屉、下拉菜单 |
| Level 3 | `surfaceHighest` | `surfaceHighest` | 输入框、分割线、禁用状态 |

---

## 字体排版 (AppTypography)

### 字号阶梯

```dart
class AppTypography {
  // === 字号 ===
  static const double fontSizeXs = 10;    // 超小（标签、角标）
  static const double fontSizeSm = 12;    // 小（说明文字、辅助信息）
  static const double fontSizeBase = 14;  // 基础（正文、按钮）
  static const double fontSizeMd = 16;    // 中等（子标题）
  static const double fontSizeLg = 18;    // 大（页面标题）
  static const double fontSizeXl = 20;    // 超大（大标题）
  static const double fontSize2xl = 24;   // 2倍大（展示标题）
  static const double fontSize3xl = 30;   // 3倍大（数字展示）

  // === 字重 ===
  static const fontWeightRegular = FontWeight.w400;
  static const fontWeightMedium = FontWeight.w500;
  static const fontWeightSemibold = FontWeight.w600;
  static const fontWeightBold = FontWeight.w700;

  // === 行高 ===
  static const lineHeightTight = 1.25;   // 紧凑（标题）
  static const lineHeightNormal = 1.5;   // 正常（正文）
  static const lineHeightRelaxed = 1.75; // 宽松（长文本）

  // === 字体族 ===
  static const String fontFamilySans = 'SF Pro Text';  // iOS
  static const String fontFamilyMono = 'SF Mono';      // 代码/数字
}
```

### 排版规范

| 元素 | 字号 | 字重 | 行高 | 示例 |
|------|------|------|------|------|
| 大标题 (H1) | 30 (3xl) | Bold | Tight | "视频学习" |
| 页面标题 (H2) | 24 (2xl) | Bold | Tight | "资源管理" |
| 区块标题 (H3) | 18 (Lg) | Semibold | Normal | "我的文件夹" |
| 子标题 (H4) | 16 (Md) | Medium | Normal | "英语学习" |
| 正文 (Body) | 14 (Base) | Regular | Normal | "这是一段正文内容" |
| 说明 (Caption) | 12 (Sm) | Regular | Relaxed | "点击查看详情" |
| 标签 (Label) | 10 (Xs) | Medium | Normal | "VIP" |

### 使用示例

```dart
Text(
  '页面标题',
  style: TextStyle(
    fontSize: AppTypography.fontSizeLg,
    fontWeight: AppTypography.fontWeightSemibold,
    color: context.colors.textPrimary,
    height: AppTypography.lineHeightTight,
  ),
)
```

---

## 间距规范 (AppSpacing)

### 间距阶梯 (8pt 基准网格)

```dart
class AppSpacing {
  static const double space1 = 4;    // 极小（图标与文字间距）
  static const double space2 = 8;    // 特小（紧密元素）
  static const double space3 = 12;   // 小（相关元素组内）
  static const double space4 = 16;   // 中（标准间距）⭐ 最常用
  static const double space5 = 20;   //中大（区块间距）
  static const double space6 = 24;   // 大（卡片内边距）
  static const double space7 = 28;   // 特大（区块间分隔）
  static const double space8 = 32;   // 超大（页面边距）
  static const double space9 = 36;   // 2倍大
  static const double space10 = 40;  // 3倍大

  // === 特殊间距 ===
  static const double inputPadding = 16;  // 输入框内边距
  static const double cardPadding = 16;   // 卡片内边距
  static const double modalPadding = 24;  // 弹窗内边距
  static const double pagePadding = 16;   // 页面水平边距
}
```

### 使用场景

| 场景 | Token | 值 | 示例 |
|------|-------|-----|------|
| 图标+文字 | `space1` | 4px | 图标与文字同行 |
| 按钮内边距 | `space5 × space4` | 20×16px | 水平×垂直 |
| 列表项间距 | `space3` | 12px | ListTile 之间 |
| 卡片内边距 | `cardPadding` | 16px | Card 内容区 |
| 区块间距 | `space6` | 24px | Section 之间 |
| 页面边距 | `pagePadding` | 16px | 左右留白 |
| 弹窗外边距 | `modalPadding` | 24px | Dialog 内容区 |

### 使用示例

```dart
Padding(
  padding: EdgeInsets.all(AppSpacing.md),  // 16px
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('标题'),
      SizedBox(height: AppSpacing.sm),  // 8px
      Text('内容'),
      SizedBox(height: AppSpacing.lg),  // 16px
      Button(...),
    ],
  ),
)
```

---

## 圆角规范 (AppRadius)

### 圆角阶梯

```dart
class AppRadius {
  static const double xs = 4;    // 极小（标签、Badge）
  static const double sm = 6;    // 小（按钮、Input）
  static const double md = 8;    // 中（卡片、Chip）⭐ 最常用
  static const double lg = 12;   // 大（弹窗、Sheet）
  static const double xl = 16;   // 特大（Modal、Card）
  static const double xxl = 24;  // 超大（全屏圆角）
  static const double full = 999; // 全圆角（Avatar、Pill）

  // === 语义化别名 ===
  static const double button = sm;    // 按钮: 6px
  static const double input = sm;     // 输入框: 6px
  static const double card = md;      // 卡片: 8px
  static const double chip = xs;      // 标签: 4px
  static const double modal = xl;     // 弹窗: 16px
  static const double bottomSheet = lg; // 底部弹窗: 12px
}
```

### 使用场景

| 元素 | Token | 值 | 示例 |
|------|-------|-----|------|
| Badge/Tag | `xs` | 4px | 未读数角标 |
| Button | `button` (sm) | 6px | TDButton |
| Input | `input` (sm) | 6px | TDInput |
| Card | `card` (md) | 8px | 文件夹卡片 |
| Dialog | `modal` (xl) | 16px | TDDialog |
| BottomSheet | `bottomSheet` (lg) | 12px | TDActionSheet |
| Avatar | `full` | 999px | 圆形头像 |

### 使用示例

```dart
Container(
  decoration: BoxDecoration(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(AppRadius.card),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
  ),
  child: ...,
)
```

---

## ThemeData 配置 (AppTheme)

### 亮色主题 (lightTheme)

```dart
static ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: AppColors.lightColorScheme,
  
  // 全局字体
  fontFamily: AppTypography.fontFamilySans,
  
  // Scaffold 背景
  scaffoldBackgroundColor: AppColors.lightBackground,
  
  // AppBar 主题
  appBarTheme: AppBarTheme(
    elevation: 0,
    backgroundColor: AppColors.lightSurface,
    foregroundColor: AppColors.lightOnSurface,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.lightOnSurface,
    ),
  ),
  
  // Card 主题
  cardTheme: CardThemeData(
    elevation: 2,
    color: AppColors.lightSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
  ),
  
  // 按钮主题（注意：项目应优先使用 TDButton）
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
    ),
  ),
  
  // 输入框主题
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurfaceElevated,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.input),
      borderSide: BorderSide.none,
    ),
  ),
  
  // ... 更多组件主题配置
);
```

### 暗色主题 (darkTheme)

```dart
static ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: AppColors.darkColorScheme,
  
  scaffoldBackgroundColor: AppColors.backgroundDark,
  
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.surfaceDark,
    foregroundColor: AppColors.darkOnSurface,
    systemOverlayStyle: SystemUiOverlayStyle.light,
  ),
  
  cardTheme: CardThemeData(
    color: AppColors.surfaceDark,
    elevation: 1,  // 暗色模式下降低阴影
  ),
  
  // ... 其他配置类似 lightTheme，但使用 dark tokens
);
```

### 主题切换

```dart
// Riverpod Provider 控制
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// MaterialApp 中使用
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ref.watch(themeModeProvider),
);

// 切换方法
void _toggleTheme() {
  final current = ref.read(themeModeProvider);
  ref.read(themeModeProvider.notifier).state = 
    current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
}
```

---

## TDesign 主题集成

### 与 TDesign 协同工作

项目同时使用 **Flutter ThemeData** 和 **TDTheme**，需确保两者配色一致。

#### 颜色映射关系

| VidLang Token | TDesign Token | 说明 |
|--------------|---------------|------|
| `AppColors.primary` | `TDTheme.of(context).brandNormalColor` | 品牌主色 |
| `AppColors.error` | `TDTheme.of(context).errorNormalColor` | 错误色 |
| `context.colors.textPrimary` | `TDTheme.of(context).fontGyColor1` | 主要文字 |
| `context.colors.textSecondary` | `TDTheme.of(context).fontGyColor2` | 次要文字 |
| `context.colors.background` | `TDTheme.of(context).bgColorWhite` | 背景色 |

#### 统一使用建议

```dart
// ✅ 推荐：在 TDesign 组件中使用 TDTheme
TDButton(
  text: '确定',
  theme: TDButtonTheme.primary,
  onTap: () {},
)

// ✅ 在自定义组件中使用 AppColors
Container(
  color: context.colors.surface,
  child: Text('自定义组件', style: TextStyle(color: context.colors.textPrimary)),
)

// ⚠️ 避免：混用导致不一致
// 不要在自定义组件中硬编码 TDTheme 的颜色值
```

### 自定义 TDesign 主题（可选）

如需修改 TDesign 默认配色以匹配 VidLang 品牌：

```dart
// 生成自定义主题 JSON（参考 tdesign-components.md）
String vidlangThemeConfig = '''
{
  "vidlang": {
    "color": {
      "brandNormalColor": "#3B6EFF",  // VidLang 品牌蓝
      "errorNormalColor": "#EF4444"
    }
  }
}
''';

MaterialApp(
  theme: ThemeData(
    extensions: [
      TDThemeData.fromJson('vidlang', vidlangThemeConfig)!,
      ...AppTheme.lightTheme.extensions,
    ],
  ),
);
```

---

## 使用示例

### 完整页面模板

```dart
class ExamplePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      
      appBar: AppBar(
        title: Text(
          '示例页面',
          style: TextStyle(
            fontSize: AppTypography.fontSizeLg,
            fontWeight: AppTypography.fontWeightSemibold,
            color: colors.textPrimary,
          ),
        ),
      ),

      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              '区块标题',
              style: TextStyle(
                fontSize: AppTypography.fontSizeMd,
                fontWeight: AppTypography.fontWeightMedium,
                color: colors.textPrimary,
              ),
            ),
            
            SizedBox(height: AppSpacing.sm),

            // 卡片列表
            ...List.generate(3, (index) => _buildCard(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(AppColorsData colors) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md),
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.videoType,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '卡片标题 $index',
                  style: TextStyle(
                    fontSize: AppTypography.fontSizeBase,
                    fontWeight: AppTypography.fontWeightMedium,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  '这是卡片的描述文字',
                  style: TextStyle(
                    fontSize: AppTypography.fontSizeSm,
                    color: colors.textWeak,
                  ),
                ),
              ],
            ),
          ),
          TDButton(
            text: '操作',
            size: TDButtonSize.small,
            type: TDButtonType.fill,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
```

---

## 最佳实践

### ✅ 必须遵守的规范

#### 1. 使用 Context 扩展获取颜色

```dart
// ✅ 正确：自动适配亮/暗色
final colors = context.colors;
Container(color: colors.background)

// ⚠️ 可接受：手动传入 brightness（当无法访问 context 时）
Container(color: AppColors.getSurface(brightness: widget.brightness))

// ❌ 错误：硬编码颜色值
Container(color: Color(0xFFFFFFFF))
```

#### 2. 语义化使用颜色

```dart
// ✅ 正确：使用语义化名称
Text('错误信息', style: TextStyle(color: colors.error))

// ❌ 错误：使用原始色值
Text('错误信息', style: TextStyle(color: Color(0xFFEF4444)))
```

#### 3. 保持对比度可访问性

```dart
// ✅ 正确：文字与背景对比度 ≥ 4.5:1 (AA 标准)
Container(
  color: colors.background,
  child: Text('正文', style: TextStyle(color: colors.textPrimary)),
)

// ❌ 错误：对比度不足
Container(
  color: colors.background,
  child: Text('正文', style: TextStyle(color: colors.textWeak)),  // 太浅
)
```

#### 4. 间距使用偶数基准

```dart
// ✅ 正确：基于 8pt 网格
SizedBox(height: AppSpacing.space4)  // 16px

// ❌ 错误：奇数值
SizedBox(height: 17)  // 不符合网格
```

### ⚠️ 常见陷阱

#### 1. 忘记处理暗色模式

```dart
// ❌ 错误：只考虑亮色
Container(color: Colors.white)

// ✅ 正确：使用 token
Container(color: context.colors.surface)
```

#### 2. 直接使用 ThemeData 而非 Design Tokens

```dart
// ⚠️ 可以但不推荐（耦合 Flutter 具体实现）
Theme.of(context).colorScheme.primary

// ✅ 推荐（解耦，易于迁移）
context.colors.primary
```

#### 3. 新增样式时未更新 Token

**正确流程**:
1. 在 `app_colors.dart` / `app_typography.dart` 等文件中添加新 Token
2. 更新本文档的使用表格
3. 确保亮/暗色双模式都有对应值

---

## 📚 相关文档

- [AppColors 实现](../../../lib/theme/app_colors.dart)
- [AppTypography 实现](../../../lib/theme/app_typography.dart)
- [AppSpacing 实现](../../../lib/theme/app_spacing.dart)
- [AppRadius 实现](../../../lib/theme/app_radius.dart)
- [AppTheme 实现](../../../lib/theme/app_theme.dart)
- [TDesign 组件库](./tdesign-components.md) — TDesign 主题集成
- [项目全局规则](../../PROJECT_RULES.md) — 设计规范总则

---

## 🔄 版本历史

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v3.0 | 2026-07-12 | 设计升级 v3.0，完整 Design Tokens 体系 | AI Assistant |

---

## ✅ 检查清单（UI 开发自查）

### 颜色
- [ ] 无硬编码颜色值（Hex/RGB）
- [ ] 所有颜色来自 `context.colors` 或 `AppColors`
- [ ] 亮色/暗色模式均已测试
- [ ] 文字与背景对比度达标（≥ 4.5:1）

### 字体
- [ ] 字号来自 `AppTypography.fontSize*`
- [ ] 字重来自 `AppTypography.fontWeight*`
- [ ] 行高已设置（非默认）

### 间距
- [ ] 间距来自 `AppSpacing.space*` 或 `AppSpacing.*Padding`
- [ ] 符合 8pt 网格系统
- [ ] 无奇数值间距

### 圆角
- [ ] 圆角来自 `AppRadius.*`
- [ ] 同类组件圆角一致

### TDesign 集成
- [ ] 所有按钮使用 `TDButton`
- [ ] 所有弹窗使用 `TDDialog`
- [ ] 所有提示使用 `TDToast`
- [ ] TDesign 颜色与 AppColors 一致
