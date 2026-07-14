# 统一播放器改造 — 问题清单与改造方案

> **版本**: V1.0 | **日期**: 2026-07-14 | **状态**: 待确认

---

## 一、当前状态

新统一播放器 `UnifiedPlayerPage` 已创建骨架，可编译运行，但存在大量功能缺失和布局问题。

### 1.1 已完成的部分

| 模块 | 状态 | 说明 |
|------|------|------|
| 文件结构 | ✅ | `unified/` 目录 + 7 个 widget 文件 |
| 主页面骨架 | ✅ | ConsumerState + build 组装 |
| 业务逻辑层 | ✅ | UnifiedPlayerLogic（初始化/封面/TTS/单词/录音） |
| 媒体区域 | ⚠️ 骨架 | 视频/音频条件渲染，但缺少自适应 |
| 顶部栏 | ⚠️ 简化版 | 返回+标题+列表，缺少 BackdropFilter |
| 底部控制栏 | ❌ 严重缺失 | 仅 3 个按钮，应 10+ 个 |
| 侧边栏 | ⚠️ 基础版 | 列表OK，缺少设置面板 |
| 跟读面板 | ✅ | ShadowReaderComponent 封装 |
| 评分弹窗 | ✅ | ScoreResultDialog |
| 路由替换 | ✅ | 3 处引用已更新 |
| 原文件删除 | ✅ | player_page / audio_player_page 已删 |

### 1.2 编译状态

- **ERROR**: 0
- **WARNING**: 若干（unused field、unnecessary `!`）
- **INFO**: 若干（async context、deprecated withOpacity）

---

## 二、发现的问题清单

### 2.1 🔴 严重问题（功能缺失）

#### P1: 底部控制栏按钮大量缺失

**现状**: 当前 `BottomControls` 只有：
- 上一句 / 播放暂停 / 下一句（图标）
- 跟读 / 清晰朗读（图标）

**应有**（参考原 `PlayerPage._buildBottomArea`）：

| # | 按钮 | 类型 | 当前状态 |
|---|------|------|---------|
| 1 | 上一句 | 图标按钮 | ✅ 有 |
| 2 | 播放/暂停 | 大图标按钮 | ✅ 有 |
| 3 | 下一句 | 图标按钮 | ✅ 有 |
| 4 | **跟读** | 文字按钮(toggle) | ⚠️ 有但样式不同 |
| 5 | **清晰朗读** | 文字按钮(toggle) | ⚠️ 有但样式不同 |
| 6 | **字幕开关** | 文字按钮(toggle) | ❌ 缺失 |
| 7 | **翻译开关** | 文字按钮(toggle) | ❌ 缺失 |
| 8 | **单句暂停** | 文字按钮(toggle) | ❌ 缺失 |
| 9 | **由慢到快** | 文字按钮(toggle) | ❌ 缺失 |
| 10 | **循环模式** | PopupMenuButton | ❌ 缺失 |
| 11 | **字号设置** | 自定义 Overlay 选择器 | ❌ 缺失 |
| 12 | **倍速设置** | PopupMenuButton | ❌ 缺失 |

**原代码参考位置**: `PlayerPage._buildBottomArea()` (line 567~737)

**原按钮布局**:
```
竖屏（Portrait）:
  ┌─────────────────────────┐
  │     可选字幕行            │
  │   ─── 进度条 + 时间 ──   │
  │  [上一句] [▶] [下一句]    │
  │  [跟读][朗读][字幕][翻译]  │
  │  [单句][由慢到快][循环]    │
  │        [字号] [倍速]      │
  └─────────────────────────┘

横屏（Landscape）:
  ─── 进度条 + 时间 ──
  [上一句] [▶] [下一句]  [跟读][朗读][字幕][翻译][单句][由慢到快][循环][字号][倍速...]
```

#### P2: 字幕显示区域缺失

**现状**: `MediaArea` 中视频模式有字幕覆盖层，但：
- 缺少半透明黑色背景容器 (`Colors.black.withValues(alpha: 0.5)`)
- 缺少圆角 (`BorderRadius.circular(10)`)
- 缺少正确的 padding
- 音频模式的字幕列表样式未验证

**原代码参考**: `PlayerPage._buildSelectableSubtitle()` (line 918~990)

#### P3: 侧边栏缺少设置功能

**现状**: `SideDrawer` 只有列表，没有设置项

**应有**（用户之前讨论决定放入字幕设置中的）:
- ~~播放速度~~ → 已移到底部按钮
- ~~循环模式~~ → 已移到底部按钮
- **中文字幕注音开关** → 需要确认放在哪里
- 其他设置项？

### 2.2 🟡 中等问题（布局与样式）

#### P4: 所有尺寸未使用 Adaptive 规范

**影响范围**: 全部 widget 文件

**规范要求**（来自 AGENTS.md 9.1 Adaptive 使用原则）:
- 页面内边距 → ✅ 应缩放
- 卡片内部间距 → ❌ 不缩放（卡片已在外层容器中）
- 文字大小 → ✅ 应缩放
- 图标大小 → ✅ 应缩放
- 固定布局结构 → ❌ 不缩放

**当前问题**:
- `top_bar.dart`: 图标固定 `size: 22`，未使用 `adaptive.Adaptive.icon()`
- `bottom_controls.dart`: 几乎所有尺寸都是硬编码
- `media_area.dart`: padding 和字体大小硬编码
- `side_drawer.dart`: padding 和字体大小硬编码

**原代码 adaptive 使用示例**:
```dart
// 图标 - iPad 放大 35%
final actualSize = adaptive.isIPad(context) ? size * 1.35 : size;
final padding = adaptive.isIPad(context) ? 12.0 : 8.0;

// 文字
fontSize: adaptive.Adaptive.sp(context, 16),

// 宽高
width: adaptive.Adaptive.w(context, 44),
height: adaptive.Adaptive.h(context, 44),

// 圆角
borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 22)),
```

#### P5: 缺少 BackdropFilter 毛玻璃效果

**原代码** (line 316~404):
- 顶部栏: `BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12))` + 黑色半透明渐变
- 底部控制区: 同上
- 侧边栏: `BackdropFilter(sigmaX: 20, sigmaY: 20)` + 黑色半透明背景

**当前**: 纯色背景，无模糊效果

#### P6: 缺少控件自动隐藏

> 用户已确认：**不需要此功能**

#### P7: TopBar 样式过于简化

**原代码**:
- 返回按钮: 圆角矩形触控区域 (`borderRadius: 22`)，使用 `AppIcons.arrowBackIosNew`
- 列表按钮: 同样圆角触控区域，使用 `AppIcons.formatListBulleted`
- 有水平 margin 适配 safeArea

**当前**: 简单的 `Icon` + `GestureDetector`，无圆角触控区

#### P8: 进度条样式不正确

**原代码**:
- 高度: iPad 6pt / 非 iPad 4pt
- 热区高度: 20pt（`Container(height: 20)` 包裹实际的 `LinearProgressIndicator`）
- 手势: `onTapDown` + `onHorizontalDragUpdate` 直接操作 seek
- 样式: `LinearProgressIndicator` + 圆角 + primary 色

**当前**: 标准 `Slider` 组件，样式完全不同

#### P9: SideDrawer 样式需优化

**原代码**:
- 宽度: iPad 400 / 非 iPad 320
- 背景: `Colors.black.withValues(alpha: 0.72)`
- 左边框: `BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5)`
- 有 `BackdropFilter(sigmaX: 20, sigmaY: 20)`
- 关闭时有遮罩层 `Colors.black.withValues(alpha: 0.4)`

### 2.3 🟢 低优先级（优化项）

#### P10: 播放/暂停按钮尺寸

**原代码**:
- 竖屏: `size: 40`
- 横屏: `size: 32`
- iPad 上整体放大 35%

#### P11: 列表项样式

**原代码 `_VideoListItem`**:
- 有封面缩略图 (120×86 或 140×100)
- 有"播放中"标签（当正在播放时）
- 有字幕标记图标（当有字幕时）
- 入场动画: `TweenAnimationBuilder` + opacity + translate
- 选中态: primary 色 background + border

---

## 三、改造方案（待确认）

### 3.1 BottomControls 完整重写

参考原 `PlayerPage._buildBottomArea` + `_plainTextBtn` + `_smallCtrl` + `_buildLoopModePopup` + `_buildSpeedPopup` + `_buildFontSizePopupButton`，完整复刻以下按钮：

```
按钮优先级（从左到右，从上到下）:

第一行（播放控制）:
  [上一句] [▶/⏸] [下一句]

第二行（功能按钮 - 竖屏 Wrap / 横屏 Row+SingleChildScrollView）:
  [跟读] [清晰朗读] [字幕] [翻译] [单句暂停] [由慢到快] [循环▾] [字号A] [倍速1.0X]
```

每个按钮的交互:
- **跟读**: toggle → 进入/退出 ShadowReaderComponent 跟读模式
- **清晰朗读**: toggle → TTS 朗读当前句 / 停止
- **字幕**: toggle → `notifier.toggleSubtitleVisible()`
- **翻译**: toggle → `notifier.toggleTranslateVisible()`
- **单句暂停**: toggle → `notifier.toggleSingleSentencePause()`
- **由慢到快**: toggle → `notifier.toggleSlowToFastCurrentSentence()`
- **循环**: PopupMenuButton → 单集循环/列表循环/单集播放/顺序播放
- **字号**: GestureDetector → Overlay 竖向 Slider (12~40)
- **倍速**: PopupMenuButton → 0.5X/0.75X/1X/1.25X/1.5X/2X

### 3.2 MediaArea 补充

- 视频模式字幕: 半透明黑底 + 圆角 + 正确 padding
- 音频模式: 保持现有列表样式，验证正确性

### 3.3 TopBar 样式升级

- 添加 BackdropFilter 毛玻璃效果
- 使用 `AppIcons.arrowBackIosNew` 替代 `AppIcons.arrowBack`
- 圆角触控区域
- adaptive 尺寸

### 3.4 SideDrawer 样式升级

- BackdropFilter 毛玻璃
- 正确宽度和背景色
- 边框线
- 设置区域（如果需要）

### 3.5 全局 Adaptive 尺寸修复

所有文件统一使用:
```dart
adaptive.Adaptive.w(context, value)   // 宽度
adaptive.Adaptive.h(context, value)   // 高度
adaptive.Adaptive.sp(context, value)  // 字号
adaptive.Adaptive.r(context, value)   // 圆角
adaptive.Adaptive.icon(context, value) // 图标
adaptive.isIPad(context)             // iPad 检测
```

---

## 四、待确认事项

1. **中文字幕注音开关** — 放在侧边栏设置中？还是底部按钮区？还是字幕设置弹窗中？
2. **控件自动隐藏** — 确认不需要？
3. **音频模式** — 是否需要与视频模式完全一致的按钮布局？还是简化版？
4. **循环模式** — 音频模式下是否需要？原 AudioPlayerPage 是否有此功能？
5. **字号/倍速/循环等状态的持久化** — 是否需要记住用户上次选择？

---

## 五、文件修改清单

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `widgets/bottom_controls.dart` | **重写** | 补全 12 个按钮 + adaptive + 原样式 |
| `widgets/media_area.dart` | **修改** | 字幕区域样式 + adaptive |
| `widgets/top_bar.dart` | **修改** | BackdropFilter + adaptive + 原样式 |
| `widgets/side_drawer.dart` | **修改** | BackdropFilter + adaptive + 原样式 |
| `unified_player_page.dart` | **微调** | 传递新增回调参数 |
| `unified_player_logic.dart` | **可能微调** | 如需新增方法 |

---

**请确认以上问题和方案，确认后我将开始逐项实施改造。**
