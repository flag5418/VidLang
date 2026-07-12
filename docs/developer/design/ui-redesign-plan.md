# VidLang UI 重构方案

> **基于 Pencil UI Design Skill 的工业级设计规范**  
> **版本**: v2.0  
> **日期**: 2026-06-27

---

## 一、设计理念升级

### 1.1 当前问题分析

通过分析现有代码和文档，发现以下主要问题：

| 问题类型 | 具体表现 | 影响 |
|---------|---------|------|
| **主题不一致** | `app_colors.dart` 与 `app_theme.dart` 断裂，深色主题未落地 | 60+ 编译错误 |
| **设计规范混乱** | 现有文档参考多邻国风格，但代码实现不统一 | 视觉体验差 |
| **组件复用性低** | 缺乏统一的设计令牌系统 | 维护成本高 |
| **响应式不足** | 仅针对 iPhone 设计，未考虑 iPad 等大屏设备 | 适配困难 |

### 1.2 新设计原则（基于 Pencil Skill）

根据 Pencil UI Design Skill 的最佳实践，采用以下核心原则：

#### 🎨 设计系统化
- **统一的设计令牌 (Design Tokens)**: 颜色、字体、间距、圆角、阴影全部系统化管理
- **组件库思维**: 所有 UI 元素都应作为可复用组件构建
- **主题一致性**: 亮色/暗色主题完整支持，使用 CSS 变量式管理

#### 📱 工业级标准
- **4px 基础网格**: 所有间距都是 4 的倍数
- **Material Symbols Rounded 图标**: 统一图标库（已部分实现）
- **Inter + Noto Sans SC 字体**: 中英文统一字体栈

#### ✨ 用户体验优先
- **清晰的视觉层级**: 通过颜色、大小、字重建立信息层级
- **一致的交互反馈**: 统一的点击、加载、错误状态处理
- **无障碍访问**: 符合 WCAG 2.1 AA 标准

---

## 二、色彩系统重构

### 2.1 语义化颜色体系

基于 Pencil Skill 的颜色规范，结合 VidLang 的品牌特性：

```dart
// lib/theme/app_colors.dart - 重构后的结构

class AppColors {
  AppColors._();
  
  // ========== 品牌色 ==========
  /// 主色调 - 翠绿色（保留原有品牌色）
  static const Color primary = Color(0xFF4ADE80);
  static const Color primaryLight = Color(0xFFDCFCE7);
  static const Color primaryDark = Color(0xFF22C55E);
  
  // ========== 语义色 ==========
  /// 成功状态
  static const Color success = Color(0xFF22C55E);
  /// 警告状态
  static const Color warning = Color(0xFFFBBF24);
  /// 错误状态
  static const Color error = Color(0xFFEF4444);
  /// 信息提示
  static const Color info = Color(0xFF3B82F6);
  
  // ========== 中性色（灰阶） ==========
  // 文本层级
  static const Color textPrimary = Color(0xFF18181B);    // 主要文本
  static const Color textSecondary = Color(0xFF71717A);   // 次要文本
  static const Color textTertiary = Color(0xFFA1A1AA);    // 辅助文本
  static const Color textDisabled = Color(0xFFD4D4D8);    // 禁用文本
  
  // 背景层级
  static const Color background = Color(0xFFFAFAFA);      // 页面背景
  static const Color surface = Color(0xFFFFFFFF);         // 卡片/容器背景
  static const Color surfaceSecondary = Color(0xFFF4F4F5);// 次要表面
  
  // 边框
  static const Color border = Color(0xFFE4E4E7);
  static const Color borderLight = Color(0xFFF4F4F5);
  
  // ========== 特殊用途 ==========
  /// 播放器覆盖层（始终深色）
  static const Color playerOverlay = Color(0xCC000000);
  /// 遮罩层
  static const Color scrim = Color(0x61000000);
}
```

### 2.2 暗色主题支持

```dart
// lib/theme/app_theme.dart - 完整的双主题支持

class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        // ... 完整定义
      ),
    );
  }
  
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,  // 主色调保持不变
        onPrimary: Color(0xFF18181B),
        surface: Color(0xFF18181B),  // 深色背景 #18181B
        onSurface: Color(0xFFFAFAFA),
        // ... 完整定义
      ),
    );
  }
}
```

---

## 三、字体层级系统

### 3.1 字体规范（基于 Pencil Skill）

| 层级 | 大小 | 字重 | 行高 | 用途 | Flutter 实现 |
|------|------|------|------|------|-------------|
| **Display** | 36px | 700 | 1.2 | 大标题（欢迎页） | `displayLarge` |
| **H1** | 24px | 600 | 1.3 | 页面标题 | `headlineMedium` |
| **H2** | 20px | 600 | 1.4 | 区块标题 | `titleLarge` |
| **H3** | 18px | 600 | 1.4 | 卡片标题 | `titleMedium` |
| **Body** | 14px | 400 | 1.5 | 正文 | `bodyMedium` |
| **Small** | 12px | 400 | 1.4 | 辅助文本 | `bodySmall` |
| **Caption** | 10px | 500 | 1.3 | 标签、徽章 | `labelSmall` |

### 3.2 字体家族配置

```dart
// lib/theme/app_typography.dart

class AppTypography {
  // 英文字体
  static const String fontEnglish = 'Inter';
  // 中文字体
  static const String fontChinese = 'Noto Sans SC';
  
  // 组合字体栈
  static TextStyle get displayLarge => TextStyle(
    fontFamily: fontEnglish,
    fontSize: 36.sp,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );
  
  // ... 其他层级
}
```

---

## 四、间距与圆角系统

### 4.1 4px 网格间距

```dart
// lib/theme/app_spacing.dart

class AppSpacing {
  AppSpacing._();
  
  // 基础值
  static const double base = 4.0;
  
  // 语义化间距
  static const double xs = 4.0;    // 极小间距
  static const double sm = 8.0;    // 小间距
  static const double md = 12.0;   // 中等间距
  static const double lg = 16.0;   // 大间距
  static const double xl = 24.0;   // 超大间距
  static const double xxl = 32.0;  // 特大间距
  static const double xxxl = 48.0; // 最大间距
  
  // 页面边距
  static const double pagePadding = 16.0;
  // 卡片内边距
  static const double cardPadding = 16.0;
  // 元素间距
  static const double elementSpacing = 8.0;
}
```

### 4.2 圆角规范

```dart
// lib/theme/app_radius.dart

class AppRadius {
  AppRadius._();
  
  static const double sm = 6.0;     // 小元素（Badge, Chip）
  static const double md = 8.0;     // 按钮、输入框
  static const double lg = 12.0;    // 卡片、弹窗
  static const double xl = 16.0;    // 大卡片
  static const double full = 9999.0; // 圆形（头像）
}
```

---

## 五、组件库设计

### 5.1 按钮组件

基于 Pencil Skill 的按钮规范：

#### Primary Button（主按钮）
```dart
// lib/components/buttons/primary_button.dart

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        // Pencil Skill: 按压效果
        overlayColor: MaterialStateProperty.all(AppColors.primaryDark),
      ),
      child: _buildChild(),
    );
  }
}
```

#### Secondary Button（次要按钮）
```dart
// 背景: #F4F4F5
// 边框: 1px #E4E4E7
// 文字: #18181B
// 圆角: 8px
```

#### Ghost Button（幽灵按钮）
```dart
// 透明背景
// Hover 时: fill="#F4F4F5"
```

### 5.2 卡片组件

```dart
// lib/components/cards/base_card.dart

class BaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
```

### 5.3 输入框组件

```dart
// lib/components/inputs/text_input_field.dart

class TextInputField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20.w) : null,
        suffixIcon: suffixIcon != null 
          ? IconButton(icon: Icon(suffixIcon, size: 20.w), onPressed: onSuffixTap)
          : null,
        // Pencil Skill: Focus 状态样式
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      ),
    );
  }
}
```

---

## 六、页面级重构方案

### 6.1 底部导航栏（MainPage）

**当前问题**:
- 导航项硬编码在文件中
- 图标大小和样式不统一
- 缺少动画过渡

**重构方案**:

```dart
// lib/views/main/main_page.dart - 重构后

class MainPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  late PageController _pageController;
  
  // 导航项配置（集中管理）
  static final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: '首页',
      page: HomePage(),
    ),
    NavigationItem(
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder_rounded,
      label: '视频集',
      page: FileListPage(),
    ),
    NavigationItem(
      icon: Icons.bookmark_outline,
      activeIcon: Icons.bookmark,
      label: '生词本',
      page: CollectionPage(),
    ),
    NavigationItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: '我的',
      page: ProfilePage(),
    ),
  ];
  
  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: ClampingScrollPhysics(),
        children: _navigationItems.map((item) => item.page).toList(),
      ),
      bottomNavigationBar: _buildBottomNav(currentIndex),
    );
  }
  
  Widget _buildBottomNav(int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: List.generate(_navigationItems.length, (index) {
            final item = _navigationItems[index];
            final isActive = index == currentIndex;
            
            return Expanded(
              child: _NavItem(
                item: item,
                isActive: isActive,
                onTap: () => _onTabTapped(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// 单独的导航项组件
class _NavItem extends StatelessWidget {
  final NavigationItem item;
  final bool isActive;
  final VoidCallback onTap;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 26.w,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
            ),
            SizedBox(height: 4.h),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 6.2 视频播放页（PlayerPage）

**当前问题**:
- 代码量过大（1277行），职责不清
- UI 与业务逻辑耦合严重
- 未遵循设计规范

**重构方案**:

#### 分离组件架构

```
lib/views/player/
├── player_page.dart           # 主页面（精简至 300 行内）
├── widgets/
│   ├── video_player_widget.dart       # 视频播放器封装
│   ├── subtitle_overlay.dart          # 字幕覆盖层
│   ├── control_bar.dart               # 控制条（播放/暂停/进度）
│   ├── speed_selector.dart            # 倍速选择器
│   ├── video_list_drawer.dart         # 视频列表抽屉
│   ├── word_popup.dart                # 单词弹窗
│   └── toolbar.dart                   # 顶部工具栏
├── providers/
│   └── player_provider.dart           # 播放状态管理
└── utils/
    └── player_utils.dart              # 工具函数
```

#### 关键 UI 改进

**1. 控制条重新设计**
```dart
// lib/views/player/widgets/control_bar.dart

class ControlBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final double playbackSpeed;
  final bool isPlaying;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onPlayPause;
  final ValueChanged<double>? onSpeedChange;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          _buildProgressBar(),
          SizedBox(height: 8.h),
          // 控制按钮行
          Row(
            children: [
              _buildSpeedButton(),
              Spacer(),
              _buildPlayPauseButton(),
              Spacer(),
              _buildFullscreenButton(),
            ],
          ),
        ],
      ),
    );
  }
}
```

**2. 字幕显示优化**
```dart
// lib/views/player/widgets/subtitle_overlay.dart

class SubtitleOverlay extends StatelessWidget {
  final SubtitleData currentSubtitle;
  final bool showTranslation;
  final Function(String)? onWordTap;
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16.w,
      right: 16.w,
      bottom: 100.h, // 控制条上方
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: SelectableText.rich(
          TextSpan(
            children: _buildSubtitleSpans(),
          ),
          style: TextStyle(
            fontSize: 18.sp,
            color: Colors.white,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
```

### 6.3 文件列表页（FileListPage）

**重构要点**:

1. **视频集卡片标准化**
   ```dart
   class VideoFolderCard extends StatelessWidget {
     final VideoFolder folder;
     final VoidCallback onTap;
     
     @override
     Widget build(BuildContext context) {
       return BaseCard(
         onTap: onTap,
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // 封面图
             ClipRRect(
               borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
               child: AspectRatio(
                 aspectRatio: 16 / 9,
                 child: _buildCoverImage(),
               ),
             ),
             Padding(
               padding: EdgeInsets.all(AppSpacing.sm),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // 标题
                   Text(
                     folder.name,
                     style: Theme.of(context).textTheme.titleMedium,
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                   SizedBox(height: 4.h),
                   // 进度和统计
                   Row(
                     children: [
                       Icon(Icons.play_circle_outline, size: 16.w, color: AppColors.textTertiary),
                       SizedBox(width: 4.w),
                       Text(
                         '${folder.completedCount}/${folder.videoCount}',
                         style: Theme.of(context).textTheme.bodySmall,
                       ),
                       Spacer(),
                       _buildProgressIndicator(),
                     ],
                   ),
                 ],
               ),
             ),
           ],
         ),
       );
     }
   }
   ```

2. **网格布局优化**
   - 使用 `GridView.builder` 替代固定布局
   - 支持 2 列（手机）/ 3 列（平板）自适应
   - 使用 `SliverGrid` 实现滚动性能优化

### 6.4 生词本页面（WordBook）

**重构要点**:

1. **单词卡片组件**
   ```dart
   class WordCard extends StatelessWidget {
     final WordEntry word;
     final VoidCallback? onTap;
     final VoidCallback? onPlayAudio;
     
     @override
     Widget build(BuildContext context) {
       return BaseCard(
         onTap: onTap,
         padding: EdgeInsets.all(AppSpacing.md),
         child: Row(
           children: [
             // 单词
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(word.word, style: Theme.of(context).textTheme.titleMedium),
                   if (word.phonetic != null)
                     Text(word.phonetic!, style: Theme.of(context).textTheme.bodySmall),
                   if (word.translation != null)
                     Text(word.translation!, 
                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                         color: AppColors.textSecondary,
                       ),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                 ],
               ),
             ),
             // 操作按钮
             IconButton(
               icon: Icon(Icons.volume_up, size: 24.w),
               onPressed: onPlayAudio,
             ),
           ],
         ),
       );
     }
   }
   ```

2. **搜索和筛选**
   - 顶部固定搜索栏
   - 支持按字母、日期、掌握程度筛选
   - 使用 `SearchDelegate` 实现全屏搜索

---

## 七、动画与交互规范

### 7.1 动画时长（Pencil Skill 标准）

| 类型 | 时长 | 缓动曲线 | 用途 |
|------|------|---------|------|
| 快速 | 150ms | easeOut | 按钮反馈、微交互 |
| 正常 | 300ms | easeInOutCubic | 页面切换、展开收起 |
| 慢速 | 500ms | easeInOut | 复杂转场、模态框 |

### 7.2 交互动效

**按钮点击效果**
```dart
// Pencil Skill: 心动效果（参考多邻国）
class AnimatedButton extends StatefulWidget {
  @override
  _AnimatedButtonState createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(_controller);
    _shadowAnimation = Tween<double>(begin: 6.0, end: 2.0).animate(_controller);
  }
  
  void _onTapDown(TapDownDetails details) {
    _controller.forward(); // 按下：缩小 + 减阴影
  }
  
  void _onTapUp(TapUpDetails details) {
    _controller.reverse(); // 抬起：恢复
  }
  
  @override
  Widget build(BuildContext context) {
     return GestureDetector(
       onTapDown: _onTapDown,
       onTapUp: _onTapUp,
       onTapCancel: () => _controller.reverse(),
       child: AnimatedBuilder(
         animation: _controller,
         builder: (context, child) {
           return Transform.scale(
             scale: _scaleAnimation.value,
             child: Container(
               decoration: BoxDecoration(
                 boxShadow: [
                   BoxShadow(
                     blurRadius: _shadowAnimation.value,
                     // ...
                   ),
                 ],
               ),
               child: child,
             ),
           );
         },
       ),
     );
  }
}
```

**列表项点击高亮**
```dart
InkWell(
  onTap: () {},
  splashColor: AppColors.primary.withOpacity(0.1),
  highlightColor: AppColors.primary.withOpacity(0.05),
  borderRadius: BorderRadius.circular(AppRadius.lg),
  child: /* ... */,
)
```

---

## 八、响应式设计策略

### 8.1 断点系统

```dart
// 基于 Pencil Skill 的断点配置

class ResponsiveBreakpoints {
  static const double xs = 0;      // 小型手机 (< 480px)
  static const double sm = 480;    // 大型手机 (≥ 480px)
  static const double md = 640;    // 平板竖屏 (≥ 640px)
  static const double lg = 768;    // 平板横屏 (≥ 768px)
  static const double xl = 1024;   // 小型笔记本 (≥ 1024px)
  static const double xxl = 1280;  // 大屏幕 (≥ 1280px)
}

// 使用示例
class ResponsiveLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.lg) {
          return _TabletLayout();
        } else {
          return _PhoneLayout();
        }
      },
    );
  }
}
```

### 8.2 自适应布局模式

| 设备类型 | 导航方式 | 卡片列数 | 字体缩放 |
|---------|---------|----------|---------|
| 手机（< 600dp） | 底部 TabBar | 2 列 | 1.0x |
| 大手机（600-840dp） | 底部 TabBar | 3 列 | 1.05x |
| 平板（≥ 840dp） | 侧边栏 + 内容区 | 4 列 | 1.1x |

---

## 九、实施路线图

### Phase 1: 基础设施（Week 1）

**目标**: 建立完整的设计系统和基础组件库

- [ ] 重构 `AppColors`，修复编译错误
- [ ] 完善 `AppTheme`，实现完整的双主题支持
- [ ] 创建 `DesignTokens` 统一入口
- [ ] 实现基础组件：
  - [ ] `PrimaryButton`
  - [ ] `SecondaryButton`
  - [ ] `GhostButton`
  - [ ] `BaseCard`
  - [ ] `TextInputField`
  - [ ] `Avatar`
  - [ ] `Badge`
- [ ] 配置字体（Inter + Noto Sans SC）

**验收标准**:
- 编译零错误
- 亮色/暗色主题可正常切换
- 所有基础组件可通过 Storybook 或 Demo 页面预览

### Phase 2: 核心页面重构（Week 2-3）

**目标**: 重构主要页面，应用新的设计系统

- [ ] **MainPage**:
  - [ ] 提取 `_NavItem` 为独立组件
  - [ ] 添加页面切换动画
  - [ ] 统一图标和间距
  
- [ ] **FileListPage**:
  - [ ] 实现 `VideoFolderCard` 组件
  - [ ] 优化网格布局（自适应列数）
  - [ ] 添加下拉刷新和加载更多
  
- [ ] **FolderDetailPage**:
  - [ ] 重构顶部大卡片
  - [ ] 优化九宫格布局
  - [ ] 添加播放状态指示器

- [ ] **ProfilePage**:
  - [ ] 统一设置项样式
  - [ ] 添加分组标题
  - [ ] 优化表单控件

**验收标准**:
- 所有页面视觉一致
- 无明显 UI bug
- 在 iPhone 和 iPad 上均可正常显示

### Phase 3: 功能页面优化（Week 4）

**目标**: 优化复杂功能页面的 UI 和 UX

- [ ] **PlayerPage**:
  - [ ] 拆分为多个子组件（目标 < 500 行/文件）
  - [ ] 重新设计控制条
  - [ ] 优化字幕显示
  - [ ] 改进手势操作
  
- [ ] **WordBook Pages**:
  - [ ] 统一单词卡片样式
  - [ ] 优化搜索和筛选
  - [ ] 添加空状态插画
  
- [ ] **Article Pages**:
  - [ ] 统一阅读界面样式
  - [ ] 优化排版和间距
  - [ ] 添加阅读进度指示

**验收标准**:
- PlayerPage 代码量减少 60%+
- 用户操作流程顺畅
- 加载状态和错误处理完善

### Phase 4: 打磨与细节（Week 5）

**目标**: 完善细节，提升整体品质

- [ ] 添加骨架屏加载态
- [ ] 统一 Toast/Snackbar 样式
- [ ] 优化所有动画和过渡效果
- [ ] 添加无障碍标签（semantics）
- [ ] 性能优化（减少 rebuild、使用 const 构造函数）
- [ ] 全面测试不同屏幕尺寸和主题

**验收标准**:
- Lighthouse 性能评分 > 90
- 无明显卡顿或掉帧
- 通过基本的无障碍检查

---

## 十、质量保证清单

### 10.1 视觉一致性检查

- [ ] 所有页面背景统一 (`#FAFAFA` / `#18181B`)
- [ ] 所有卡片有边框 (`1px outline`)
- [ ] 阴影效果一致 (blur 2-6px)
- [ ] 按钮圆角统一 (8px)
- [ ] 字体统一 (Inter / Noto Sans SC)
- [ ] 图标库统一 (Material Symbols Rounded)
- [ ] 字体层级正确 (10/12/14/16/18/20/24/36px)
- [ ] 间距遵循 4px 网格

### 10.2 交互一致性检查

- [ ] 所有可点击元素有明确的点击反馈
- [ ] 加载状态有明确指示（skeleton / spinner）
- [ ] 错误状态有友好提示
- [ ] 空状态有引导操作
- [ ] 下拉刷新和上拉加载行为一致
- [ ] 返回导航逻辑清晰

### 10.3 代码质量检查

- [ ] 组件高度可复用（props 清晰、职责单一）
- [ ] 使用 `const` 构造函数优化性能
- [ ] 避免深层嵌套（提取子组件）
- [ ] 状态管理清晰（Riverpod provider 合理拆分）
- [ ] 注释充分（特别是公共 API）

---

## 十一、附录

### A. 参考资源

- **Pencil UI Design Skill**: `.codex/skills/pencil-ui-design/SKILL.md`
- **Material Design 3**: https://m3.material.io/
- **Flutter 最佳实践**: https://docs.flutter.dev/ui/performance
- **现有项目文档**: `docs/AGENT_CONTEXT.md`, `docs/design-style-guide.md`

### B. 迁移指南

从旧代码迁移到新设计系统的步骤：

1. **不要一次性重写** - 逐个页面迁移
2. **保持向后兼容** - 新旧组件可以共存
3. **逐步替换** - 先替换基础组件，再替换页面
4. **持续验证** - 每次修改后都要在亮色/暗色主题下测试

### C. 常见问题

**Q: 是否需要完全按照 Pencil Skill 的规范？**  
A: 不需要。Pencil Skill 提供的是工业级标准和最佳实践参考，应根据 VidLang 的品牌特性和用户需求灵活调整。

**Q: 现有的多邻国风格是否要完全放弃？**  
A: 不需要。可以将多邻国的游戏化元素（如"心动"按钮效果）融入新的设计系统中。

**Q: 暗色主题是否必须实现？**  
A: 是的。根据 AGENT_CONTEXT.md 的要求，必须同时支持亮色和暗色两套主题。

---

## 版本历史

| 版本 | 日期 | 作者 | 更新内容 |
|------|------|------|---------|
| v1.0 | 2026-05-19 | Team | 初始版本，基于多邻国风格 |
| v2.0 | 2026-06-27 | AI Assistant | 基于 Pencil Skill 全面重构，引入工业级设计规范 |
