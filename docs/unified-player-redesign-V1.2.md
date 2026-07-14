# 统一播放器改造 — 最终 UI 布局设计文档

> **版本**: V1.2 | **日期**: 2026-07-14 | **状态**: ✅ 实施完成
> **基于**: 原 PlayerPage 截图 × 5 + 用户最终确认描述

---

## 一、设计原则

### 1.1 图标规范
- **主图标库**: `TDIcons`（TDesign Flutter 原生图标，`fontFamily: 'TDIcons'`）
- **辅助图标库**: Flutter 内置 `Icons`（Material Icons rounded 系列）
- **废弃**: `Hugeicons`（不再使用，需从 `AppIcons` 中移除相关引用）
- **使用方式**:
  ```dart
  // TDesign 图标
  Icon(TDIcons_chevron_left, size: 24.w)
  // Flutter Material 图标
  Icon(Icons.play_arrow_rounded, size: 24.w)
  ```

### 1.2 尺寸规范
- **必须严格遵循 Adaptive 规范**（AGENTS.md 9.1）
- 所有尺寸值使用 `adaptive.Adaptive.w/h/sp/r/icon(context, value)`
- iPad 上图标/触控区域自动放大 35%

### 1.3 弹窗规范
- 所有设置类操作（倍速、字号、循环模式等）统一使用 **TDesign 弹窗组件**:
  - `TDPopup` — 气泡弹出
  - `TDDialog` / `TDAlertDialog` — 对话框
  - `TDActionSheet` — 操作面板（底部弹出）

### 1.4 功能范围确认
- ❌ **不实现**: 定时关闭、按下一句自动播放
- ✅ **实现**: 跟读、清晰朗读、由慢到快、翻译开关、倍速、单句循环、单句暂停、字号

---

## 二、竖屏布局（Portrait）

### 2.1 整体结构

```
┌──────────────────────────────────────────────┐
│  TopBar (固定顶部)                            │
│  [◀返回]  [标题]              [☰列表]        │
├──────────────────────────────────────────────┤
│                                              │
│  MediaArea (占据中间 ~1/3 空间)               │
│  ┌──────────────────────────────────────┐    │
│  │  视频 (OmniPlayer)                   │    │
│  │  或                                  │    │
│  │  音频封面 + 字幕列表(占满空间)         │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  字幕覆盖层 (仅视频+有字幕时显示)      │    │ ← 可选字幕区域
│  └──────────────────────────────────────┘    │
│                                              │
├══════════════════════════════════════════════┤
│  BottomControls (固定底部)                    │
│                                              │
│  第1行 (始终显示):                           │
│  [👁字幕] [|◀上] [▶/⏸播] [▶|下] [⚙️设置]    │
│                                              │
│  第2行 (点击⚙️展开, 仅有字幕时显示):          │
│  [跟读] [清晰朗读] [由慢→快] [翻译]           │
│  [倍速] [单句循环] [单句暂停] [字号]          │
│                                              │
└──────────────────────────────────────────────┘
```

### 2.2 TopBar 详细设计

| 元素 | 图标/内容 | 来源 | 尺寸 | 说明 |
|------|----------|------|------|------|
| 返回按钮 | ◀ | `TDIcons.chevron_left` | 24.w | 圆角触控区 44×44 |
| 标题 | 文件名/BETA | Text | sp(16) | 居中或左对齐 |
| 列表按钮 | ☰ | `TDIcons.view_list` 或 `AppIcons.list` | 24.w | 打开侧边栏 |

**样式**:
- 高度: adaptive.h(context, 52)
- 背景: 半透明渐变 + BackdropFilter 毛玻璃 (sigmaX/Y: 12)
- padding: horizontal 16.w
- 无收藏/历史按钮（用户简化需求）

### 2.3 MediaArea 详细设计

#### 视频模式
- **OmniPlayer** 占据上部约 1/3 空间
- 有字幕时: 多行字幕覆盖层浮在视频下方 1/3 区域
- 字幕区域:
  - 背景: `Colors.black.withValues(alpha: 0.6)` + 圆角 r(10)
  - padding: horizontal 16.w, vertical 12.w
  - 当前句: 大字 sp(22), 白色
  - 翻译行: 小字 sp(14), 灰色
  - 完整句子: sp(14), 浅灰

#### 音频模式（无视频）
- **全部空间用于字幕显示**
- 封面图(可选) + 字幕列表
- 字幕列表:
  - 当前句高亮: primary 色 background
  - 历史句: 正常文本
  - 未来句: 灰色文本
  - 自动滚动到当前句

### 2.4 BottomControls 详细设计

#### 第1行 — 基础控制（始终显示）

```
┌────────────────────────────────────────────────┐
│  [👁]     [|◀]   [  ▶  ]   [▶|]     [⚙️]     │
│ 字幕显隐   上一句   播放暂停   下一句   设置     │
└────────────────────────────────────────────────┘
```

| 按钮 | 图标(TDIcons/Material) | 宽度 | 交互 |
|------|------------------------|------|------|
| 字幕显隐 | `AppIcons.visibility` / `AppIcons.visibilityOff` | 44.w | toggle, 无字幕时隐藏 |
| 上一句 | `AppIcons.skipPrevious` 或 `TDIcons.skip_previous` | 44.w | onTap |
| 播放/暂停 | `AppIcons.play` / `AppIcons.pause` | 56.w(大) | toggle |
| 下一句 | `AppIcons.skipNext` 或 `TDIcons.skip_next` | 44.w | onTap |
| 设置 | `TDIcons.setting` 或 `AppIcons.settings` | 44.w | toggle 展开第2行 |

**布局**: Row, mainAxisAlignment: MainAxisAlignment.spaceEvenly
**进度条**: 位于第1行上方（或集成在第1行中），高度 4pt(iPad 6pt)

#### 第2行 — 功能按钮（点击⚙️展开，仅**有字幕**时显示）

```
┌──────────────────────────────────────────────────────────────┐
│  [跟读]  [清晰朗读]  [由慢→快]  [翻译]                        │  ← 第1组: 学习功能
│  [倍速▾]  [单句循环]  [单句暂停]  [字号Aₐ]                    │  ← 第2组: 播放设置
└──────────────────────────────────────────────────────────────┘
```

| 按钮 | 类型 | 交互方式 | 弹窗组件 |
|------|------|---------|---------|
| **跟读** | 文字按钮(toggle) | 直接 toggle | — |
| **清晰朗读** | 文字按钮(toggle) | 直接 toggle (TTS) | — |
| **由慢→快** | 文字按钮(toggle) | 直接 toggle | — |
| **翻译** | 文字按钮(toggle) | 直接 toggle | — |
| **倍速** | 文字+箭头 | 点击 → TDPopup/TDActionSheet | 选项: 0.5X / 0.75X / 1.0X / 1.25X / 1.5X / 2.0X |
| **单句循环** | 文字按钮(toggle) | 直接 toggle | — |
| **单句暂停** | 文字按钮(toggle) | 直接 toggle | — |
| **字号** | 文字+图标 | 点击 → TDPopup Slider | 范围: 12 ~ 40 |

**布局**: Wrap 或 2 行 Row, spacing: 8.w
**动画**: AnimatedSize / AnimatedCrossFade 展开收起
**无字幕时**: 整个第2行隐藏，⚙️按钮也隐藏（或置灰不可点）

---

## 三、横屏布局（Landscape）

### 3.1 整体结构

```
┌──────────────────────────────────────────────────────────────────┐
│  TopBar (紧凑)                                                    │
│  [◀]  BETA 文件名                      [☰列表] [⚙️设置]       │
├────────────────────────────────────┬─────────────────────────────┤
│                                    │  [✏️编辑]  ← 右侧浮动按钮   │
│  MediaArea (左侧 ~75%)             │  [🎤跟读]     圆形黑底      │
│  ┌────────────────────────────┐    │  [🔊音量]     垂直排列      │
│  │  视频 (OmniPlayer)         │    │                             │
│  │                            │    │  ┌──────────┐              │
│  │                [cut]───────│────│──│ 浮动字幕条 │ 仅当前句    │
│  └────────────────────────────┘    │  └──────────┘  黑底白字    │
│                                    │                             │
├────────────────────────────────────┴─────────────────────────────┤
│  BottomControls (一行排开)                                        │
│  [|◀] [▶] [▶|]  00:02/00:27  [翻译][单句停][倍速▾] [⊞全屏]      │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 TopBar 详细设计

| 元素 | 内容 | 说明 |
|------|------|------|
| 返回 | ◀ | `TDIcons.chevron_left` |
| 标题 | "{文件名}" | 仅文件名，不含BETA前缀 |
| 列表 | ☰ | 打开侧边栏 |
| 设置 | ⚙️ | 打开侧边栏设置Tab |

**差异**: 比竖屏更紧凑，标题包含文件名

### 3.3 右侧浮动按钮组（仅横屏）

垂直排列在视频右侧边缘:

| 按钮 | 图标 | 用途 | 显示条件 |
|------|------|------|---------|
| 编辑 | `AppIcons.edit` | 编辑字幕 | 有字幕 |
| 跟读 | `AppIcons.mic` 或 `TDIcons.mic` | 进入跟读模式 | 有字幕 |
| 音量 | `AppIcons.volumeUp` | 音量调节 | 始终显示 |

**样式**:
- 容器: CircleAvatar, radius 22.w
- 背景: `Colors.black.withValues(alpha: 0.6)`
- 图标大小: 20.w
- 间距: vertical 12.w
- 位置: right 16.w, 垂直居中

### 3.4 浮动字幕条（仅横屏+有字幕）

- 位置: 视频区域底部偏上
- 样式: 黑底半透明圆角矩形
- 内容: 仅当前句文字（大字白色）
- 尺寸: width 自适应, height 40.w

### 3.5 BottomControls 详细设计（横屏一行版）

```
┌──────────────────────────────────────────────────────────────────────┐
│ [|◀] [ ▶ ] [▶|] │ 00:02/00:27 │ [翻译] [单句暂停] [1.0X▾] [⊞]     │
│  播放控制          时间           右侧功能(仅字幕)          全屏       │
└──────────────────────────────────────────────────────────────────────┘
```

| 按钮 | 类型 | 显示条件 |
|------|------|---------|
| 上一句 | 图标 | 始终 |
| 播放/暂停 | 大图标 | 始终 |
| 下一句 | 图标 | 始终 |
| 时间 | 文字 "MM:ss/MM:ss" | 始终 |
| **翻译** | 文字按钮 | **有字幕** |
| **单句暂停** | 文字按钮 | **有字幕** |
| **倍速** | 文字+弹窗 | **始终显示**（不受字幕影响） |
| 全屏 | 图标 | 始终 |

**注意**: 横屏底部栏的右侧功能按钮比竖屏少（跟读/清晰朗读/由慢→快/单句循环/字号 移到了右侧浮动按钮组或设置面板）

---

## 四、有无字幕差异（核心逻辑）

### 4.1 条件判断依据

```dart
// 判断是否有字幕
final hasSubtitle = currentSubtitle != null && 
                    currentSubtitle!.isNotEmpty &&
                    subtitleLines.isNotEmpty;
// 或者
final hasSubtitle = playerEngineState.subtitleController?.hasSubtitles ?? false;
```

### 4.2 按钮可见性矩阵

| 按钮 | 竖屏-有字幕 | 竖屏-无字幕 | 横屏-有字幕 | 横屏-无字幕 |
|------|:-----------:|:-----------:|:-----------:|:-----------:|
| **👁 字幕显隐** | ✅ | ❌ 隐藏 | ❌(不需要) | ❌ |
| **上一句** | ✅ | ✅ | ✅ | ✅ |
| **播放/暂停** | ✅ | ✅ | ✅ | ✅ |
| **下一句** | ✅ | ✅ | ✅ | ✅ |
| **⚙️ 设置** | ✅ | ❌ 隐藏 | ✅(→侧边栏) | ✅(→侧边栏) |
| **跟读** | ✅(设置面板内) | ❌ | ✅(右浮按钮) | ❌ |
| **清晰朗读** | ✅(设置面板内) | ❌ | ✅(右浮按钮) | ❌ |
| **由慢→快** | ✅(设置面板内) | ❌ | ✅(右浮按钮) | ❌ |
| **翻译** | ✅(设置面板内) | ❌ | ✅(底部栏) | ❌ |
| **倍速** | ✅(设置面板内) | ✅(保留) | ✅(底部栏) | ✅(保留) |
| **单句循环** | ✅(设置面板内) | ❌ | ❌(移除或放设置) | ❌ |
| **单句暂停** | ✅(设置面板内) | ❌ | ✅(底部栏) | ❌ |
| **字号** | ✅(设置面板内) | ❌ | ❌(移至侧边栏设置) | ❌ |
| **右浮-编辑** | ❌ | ❌ | ✅ | ❌ |
| **右浮-音量** | ❌ | ✅(可选) | ✅ | ✅ |
| **全屏** | ❌ | ❌ | ✅ | ✅ |

### 4.3 无字幕模式的竖屏布局

```
┌──────────────────────────────────────────────┐
│  [◀返回]  [标题]              [☰列表]        │
├──────────────────────────────────────────────┤
│                                              │
│  MediaArea                                   │
│  ┌──────────────────────────────────────┐    │
│  │  视频 (OmniPlayer) 占满空间           │    │
│  │  或                                  │    │
│  │  音频封面 + 专辑信息                  │    │
│  └──────────────────────────────────────┘    │
│                                              │
├══════════════════════════════════════════════┤
│  [|◀]    [  ▶  ]    [▶|]                   │
│   上一句    播放暂停    下一句                 │
└──────────────────────────────────────────────┘
```

**特点**:
- 底部只有 3 个播放控制按钮
- 无字幕显隐、无设置按钮
- 更简洁的布局
- 进度条仍然保留

---

## 五、侧边栏设计（SideDrawer）

### 5.1 结构

```
┌─────────────────────────────────┐
│  > 资源列表    |    播放设置    │  ← Tab 切换
├─────────────────────────────────┤
│                                 │
│  (Tab1: 资源列表内容)            │
│  ┌───────────────────────────┐  │
│  │ 🖼 [封面] 标题  ○●◎ 时长 │  │  ← 列表项
│  │ 🖼 [封面] 标题  ○●◎ 时长 │  │
│  │ ...                       │  │
│  └───────────────────────────┘  │
│                                 │
│  或                              │
│  (Tab2: 播放设置内容)            │
│  ┌───────────────────────────┐  │
│  │ 播放模式                  │  │
│  │ ○单集 ●列表 ○单曲 ○顺序  │  │  ← Radio
│  │                           │  │
│  │ 字号                      │  │
│  │ 小 ━━●━━━━━━ 大          │  │  ← Slider
│  │                           │  │
│  │ 循环模式                  │  │
│  │ [单集循环 ▾]              │  │  ← TDPopup
│  │                           │  │
│  │ 倍速                      │  │
│  │ [1.0X ▾]                  │  │  ← TDPopup
│  └───────────────────────────┘  │
│                                 │
└─────────────────────────────────┘
```

### 5.2 样式规范

| 属性 | 值 |
|------|-----|
| 宽度 | iPad: 400.w / 其他: 320.w |
| 背景 | `Colors.black.withValues(alpha: 0.72)` |
| 模糊 | `BackdropFilter(sigmaX: 20, sigmaY: 20)` |
| 左边框 | `BorderSide(color: Colors.white10, width: 0.5)` |
| 遮罩 | `Colors.black.withValues(alpha: 0.4)` |
| 动画 | `AnimatedSlide` + `AnimatedOpacity` (200ms) |

### 5.3 播放设置面板内容

| 设置项 | UI 组件 | TDesign 组件 | 选项 |
|--------|---------|-------------|------|
| 播放模式 | Radio 组 | `TDRadio` + 自定义 | 单集播放/列表循环/单集循环/顺序播放 |
| 字号 | Slider | `TDSlider` | 12 ~ 40 |
| 循环模式 | Popup | `TDPopup` 或 `TDPopup` | 选择循环类型 |
| 倍速 | Popup | `TDPopup` 或 `TDActionSheet` | 0.5X ~ 2.0X |

---

## 六、图标映射表

### 6.1 播放器专用图标（需新增到 AppIcons 或直接使用 TDIcons）

| 用途 | 推荐图标 (TDIcons) | 备选 (Material Icons) | 备注 |
|------|-------------------|---------------------|------|
| 返回 | `chevron_left` | `arrow_back_ios_new_rounded` | 已有 AppIcons |
| 列表 | `view_list` | `format_list_bulleted_rounded` | 已有 AppIcons |
| 设置 | `setting` | `settings_outlined` | 已有 AppIcons |
| 字幕显隐 | `browse_visibility` | `visibility/outlined` | 已有 AppIcons |
| 上一句 | `skip_previous` | `skip_previous_rounded` | 已有 AppIcons |
| 播放 | `play_filled` | `play_arrow_rounded` | 已有 AppIcons |
| 暂停 | `pause` | `pause_rounded` | 已有 AppIcons |
| 下一句 | `skip_next` | `skip_next_rounded` | 已有 AppIcons |
| 跟读/录音 | `mic` | `mic_rounded` | 已有 AppIcons |
| 清晰朗读/TTS | `sound` | `volume_up_rounded` | — |
| 由慢→快 | `fast_forward` | `fast_forward_rounded` | — |
| 翻译 | `translate` | `translate_outlined` | 已有 AppIcons |
| 倍速 | `speed_tools` | `speed` | 已有 AppIcons |
| 单句循环 | `repeat_once` | `repeat_one_rounded` | 已有 AppIcons |
| 单句暂停 | `pause_circle` | `pause_circle_rounded` | — |
| 字号 | `text_format` | `text_fields_rounded` | — |
| 全屏 | `full_screen` | `fullscreen_rounded` | 已有 AppIcons |
| 退出全屏 | `exit_full_screen` | `fullscreen_exit_rounded` | 已有 AppIcons |
| 编辑 | `edit` | `edit_outlined` | 已有 AppIcons |
| 音量 | `volume_up` | `volume_up_rounded` | 已有 AppIcons |
| 关闭 | `close` | `close_rounded` | 已有 AppIcons |

> **注**: 使用前需确认 TDIcons 中是否存在该图标名称。TDIcons 使用 snake_case 命名。

---

## 七、TDesign 弹窗使用规范

### 7.1 倍速选择弹窗

```dart
// 方案A: TDActionSheet (底部弹出)
TDActionSheet(
  title: '播放速度',
  items: [
    TDActionSheetItem(label: '0.5X', value: 0.5),
    TDActionSheetItem(label: '0.75X', value: 0.75),
    TDActionSheetItem(label: '1.0X', value: 1.0), // 默认
    TDActionSheetItem(label: '1.25X', value: 1.25),
    TDActionSheetItem(label: '1.5X', value: 1.5),
    TDActionSheetItem(label: '2.0X', value: 2.0),
  ],
  onSelected: (value) => setSpeed(value),
);

// 方案B: TDPopup (气泡弹出, 横屏推荐)
TDPopup(
  content: Column(... // 速度选项列表 ...),
  direction: TDPopupDirection.bottom,
)
```

### 7.2 字号调节弹窗

```dart
// TDPopup + TDSlider
TDPopup(
  content: Column(
    children: [
      Text('字号大小'),
      TDSlider(
        min: 12,
        max: 40,
        value: _currentFontSize,
        onChanged: (v) => setFontSize(v),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text('小'), Text('大')],
      ),
    ],
  ),
);
```

### 7.3 循环模式选择弹窗

```dart
// TDActionSheet
TDActionSheet(
  title: '循环模式',
  items: [
    TDActionSheetItem(label: '单集播放', value: 'single'),
    TDActionSheetItem(label: '列表循环', value: 'list_loop'), // 默认
    TDActionSheetItem(label: '单集循环', value: 'single_loop'),
    TDActionSheetItem(label: '顺序播放', value: 'order'),
  ],
  onSelected: (value) => setLoopMode(value),
);
```

---

## 八、文件修改清单

| 文件 | 改动类型 | 优先级 | 说明 |
|------|---------|:------:|------|
| `lib/theme/app_icons.dart` | **修改** | P0 | 移除 Hugeicons 依赖，新增 TDIcons 别名 |
| `widgets/bottom_controls.dart` | **重写** | P0 | 双行布局 + 条件渲染 + TDPopup |
| `widgets/media_area.dart` | **重写** | P0 | 视频1/3 + 音频全屏字幕 + 自适应 |
| `widgets/top_bar.dart` | **修改** | P1 | 简化为3元素 + BackdropFilter |
| `widgets/side_drawer.dart` | **重写** | P1 | 双Tab + TDRadio + TDSlider + TDPopup |
| `unified_player_page.dart` | **修改** | P1 | 适配新回调参数 |
| `unified_player_logic.dart` | **修改** | P2 | 新增设置相关方法 |

---

## 九、实施顺序

1. **P0 - 图标清理**: 修改 `app_icons.dart`，移除 Hugeicons，建立 TDIcons 映射
2. **P0 - BottomControls**: 重写，实现双行布局 + 展开/收起 + 有无字幕条件
3. **P0 - MediaArea**: 重写，实现视频1/3 + 音频全屏字幕
4. **P1 - TopBar**: 简化 + BackdropFilter
5. **P1 - SideDrawer**: 双Tab + 播放设置面板
6. **P1 - 主页面整合**: 连接所有组件
7. **P2 - 细节优化**: 动画过渡、边界情况、测试

---

**请确认以上最终设计方案，确认后开始按实施顺序编码。**
