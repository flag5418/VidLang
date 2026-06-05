# VidLang 文章原型设计 — 完整界面原型

> 本文用 ASCII 示意图展示文章阅读器 ArticleReaderPage 的全部界面和交互流程。
> 
> 最终方案：**大纲侧边栏（左） + 内容区（右） + 底部控制栏 + 长按跳段**
> 
> 详见 [11-outline-reader-prototype.md](./11-outline-reader-prototype.md) 的完整原型

---

## 一、原型速览

```
文章功能 = 3个页面 + 大纲侧边栏布局
├── ArticleListPage（文章列表）
│   └── 点击文章 →
├── ArticleReaderPage（文章阅读器）
│   ├── 左：OutlineSidebar（大纲侧边栏）
│   │   ├── 第1层：文章标题
│   │   ├── 第2层：章节（带 ▶播放 🎤跟读）
│   │   └── 第3层：句子（当前章节展开时显示）
│   │
│   ├── 右：ContentArea（内容区）
│   │   ├── 当前句高亮（白色）
│   │   ├── 当前章节内容（亮灰）
│   │   └── 其他内容（灰色淡出）
│   │
│   └── 底：ControlBar
│       ├── ◀◀ ◀ ▶ ▶▶（短按=句 长按=章）
│       ├── 速度 / 翻译 / 跟读 / 测试
│       └── 划词 → WordCard
│
└── ArticleTestPage（文章测试）
    └── 复用统一测试引擎
```

---

## 二、文章列表页 ArticleListPage

### 2.1 有文章时的状态

```
┌──────────────────────────────────────────────┐
│  [←]  My Reading              [+ New]        │
├──────────────────────────────────────────────┤
│                                               │
│  ┌────────────────────────────────────────┐  │
│  │  Climate Change and Its Impact         │  │
│  │  5 chapters · 1,284 words             │  │
│  │  ████████████░░░░░░░  Last: Ch.3 ✅  │  │
│  │  [▶ Continue Reading]  [Folder Test]  │  │
│  └────────────────────────────────────────┘  │
│                                               │
│  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐        │
│  │📄   │  │📄   │  │📄   │  │  +  │        │
│  │The  │  │A.I. │  │Space│  │New  │        │
│  │Future│  │Ethic│  │Expl.│  │     │        │
│  │60%  │  │30%  │  │ 0%  │  │     │        │
│  └─────┘  └─────┘  └─────┘  └─────┘        │
│                                               │
├──────────────────────────────────────────────┤
│  Learn │ Words │ Profile                     │
└──────────────────────────────────────────────┘
```

### 2.2 空状态

```
┌──────────────────────────────────────────────┐
│  [←]  My Reading                             │
├──────────────────────────────────────────────┤
│                                               │
│         📖 Welcome to Reading!               │
│                                               │
│    Start by adding your first article.        │
│                                               │
│    ┌──────────────────────────────────┐      │
│    │  📋  Paste Text or Markdown      │      │
│    └──────────────────────────────────┘      │
│    ┌──────────────────────────────────┐      │
│    │  📷  Scan from Camera (OCR)      │      │
│    └──────────────────────────────────┘      │
│    ┌──────────────────────────────────┐      │
│    │  📁  Import .md File             │      │
│    └──────────────────────────────────┘      │
│                                               │
├──────────────────────────────────────────────┤
│  Learn │ Words │ Profile                     │
└──────────────────────────────────────────────┘
```

---

## 三、文章阅读器核心布局（最终方案）

### 3.1 整体布局（iPad/大屏）

```
┌──────────────────────────────────────────────────────────────────┐
│  [←]  Climate Change and Its Impact          [≡]  [⋮]  [Quiz]  │
├────────────┬─────────────────────────────────────────────────────┤
│            │                                                      │
│  Outline   │  ## Rising Temperatures                              │
│            │                                                      │
│  ☰ Climate │  Global temperatures have risen by an average of    │
│  Change    │  1.2°C since the pre-industrial era. This **warming │
│            │  is unprecedented** in modern history.              │
│  ├─ 🌡️     │                                                      │
│  │ Rising  │  Scientists warn that without immediate action,     │
│  │ Temps ▶ │  temperatures could rise by another **1.5°C**...   │
│  │         │                                                      │
│  │  ○ S1   │  > "This is a critical moment"                      │
│  │  ● S2   │                                                      │
│  │  ○ S3   │  ### Evidence                                       │
│  │  ○ S4   │                                                      │
│  │  ○ S5   │  - Sea levels: +3.4mm/year                         │
│  │         │  - CO2 levels: 420ppm                               │
│  ├─ 📊 Key │                                                      │
│  │ Stats   │  The data is clear...                               │
│  │         │                                                      │
│  ├─ 🏭     │                                                      │
│  │ Human   │                                                      │
│  │ Impact  │                                                      │
│  │         │                                                      │
│  └─ 🌍     │                                                      │
│    Sol...  │                                                      │
│            │                                                      │
├────────────┴─────────────────────────────────────────────────────┤
│  ◀◀  ◀  Sentence 18/48  ▶  ▶▶    x1.0  [Tr] [Fol] [Outline]   │
│  ——— 短按=上/下一句，长按=上/下一章 ———                           │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 大纲侧边栏（OutlineSidebar）三层结构

```
☰ Climate Change and Its Impact          ← 第1层：文章
│
├─ 🌡️ Rising Temperatures               ← 第2层：章节（当前展开）
│  │  ▶ 播放本章  🎤 跟读本章
│  │
│  ├─ S1  Climate change is one of...    ← 第3层：句子（展开时显示）
│  ├─ ●S2  This warming is unprece...    ← ● = 当前播放句
│  ├─ S3  Scientists warn that wi...
│  ├─ S4  The rate of warming is...
│  └─ S5  According to NASA data...
│
├─ 📊 Key Statistics                     ← 收起状态
├─ 🏭 Human Impact
└─ 🌍 Solutions and Hope
```

**展开/收起规则：**
- 默认只显示第1层 + 第2层（所有章节标题）
- 自动展开**当前播放的章节**
- 点击其他章节 → 展开点击的，收起之前的
- 其他章节保持收起

**每节点操作：**
| 层级 | 点击 | 按钮 |
|------|------|------|
| 文章 | 回到全文顶部 | — |
| 章节 | 跳转章节 | ▶播放本章 🎤跟读本章 |
| 句子 | 跳转句子 | （无额外按钮，点击即跳转） |

**视觉标记：**
- 当前章节：`▶` 图标 + 背景高亮
- 当前句子：`●` 圆点 + 行高亮
- 已学完句子：`✓` 标记
- 未学习句子：`○` 标记

---

## 四、右侧内容区（ContentArea）

### 4.1 内容渲染

```
┌────────────────────────────────────────────────────┐
│  ## Rising Temperatures                             │ ← 章节标题（大号）
│                                                     │
│  Global temperatures have risen by an average of   │
│  1.2°C since the pre-industrial era. This          │
│  warming is unprecedented in modern history.       │ ← 当前章节内容
│                                                     │
│  Scientists warn that without immediate action,    │
│  temperatures could rise by another 1.5°C by 2050. │
│                                                     │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐   │
│  │  > "This is a critical moment for humanity"   │   │ ← 引用块
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘   │
│                                                     │
│  ### Evidence                                       │ ← 子标题
│                                                     │
│  - Sea levels: +3.4mm/year                          │
│  - CO2 levels: 420ppm                               │ ← 列表
│  - Arctic ice: -13%/decade                          │
│                                                     │
│  The data is clear...                               │ ← 下一章开头（淡出）
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │ ← 章节分隔线
│                                                     │
└────────────────────────────────────────────────────┘
```

### 4.2 三种颜色层级

| 层级 | 文本色 | 背景 | 说明 |
|------|--------|------|------|
| **当前句** | `#FFFFFF` 纯白 | `rgba(255,255,255,0.12)` 半透明高亮 | 正在播放/学习的句子 |
| **当前章节** | `#E0E0E0` 亮灰 | 无 | 当前章节内其他句子 |
| **上下文** | `#9E9E9E` 灰色 | 无 | 非当前章节内容 |

### 4.3 划词交互（点击查词）

```
用户点击句子中的单词 "unprecedented"
    ↓
该单词下出现下划线高亮
    ↓
弹出 WordCard 浮层：
    ┌─────────────────────────────────────┐
    │  unprecedented                       │
    │  /ʌnˈpresɪdentɪd/    🔊UK  🔊US    │
    │                                      │
    │  adj. 史无前例的，空前的             │
    │                                      │
    │  "an unprecedented success"          │
    │                                      │
    │  ☆ [Save to WordBook]               │
    └─────────────────────────────────────┘
    ↓
点击空白处关闭
```

---

## 五、底部控制栏

### 5.1 按钮布局

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                   │
│  ◀◀     ◀       ▶/⏸       ▶     ▶▶     x1.0  Tr  Fol  Quiz   │
│  Prev    Prev    Play/Pause Next   Next                          │
│  Chap    Sent               Sent   Chap                          │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 所有按钮交互

| 按钮 | 短按 | 长按 |
|------|------|------|
| `◀◀` | 上一章节 | — |
| `◀` | 上一句 | 上一章节 |
| `▶/⏸` | 播放/暂停（TTS） | — |
| `▶` | 下一句 | 下一章节 |
| `▶▶` | 下一章节 | — |
| `x1.0` | 弹出速度选择器（0.5x ~ 2.0x） | — |
| `Tr` | 切换翻译显隐 | — |
| `Fol` | 展开跟读面板 | — |
| `Quiz` | 进入测试模式 | — |
| `≡ / Outline` | 展开/收起大纲侧边栏（移动端） | — |

**长按的交互反馈：** 给予 HapticFeedback（震动）+ 屏幕短暂提示 "跳转到 Chapter 3"。

---

## 六、移动端适配（iPhone 竖屏）

```
竖屏：大纲侧边栏以抽屉形式从左侧滑入（≡ 按钮触发）
┌────────────────────────────────────┐
│  [←] Climate Change     [≡] [⋮]  │
├────────────────────────────────────┤
│                                    │
│  ## Rising Temperatures            │
│                                    │
│  Global temperatures...            │
│  This warming is unprecedented     │
│  in modern history.                │
│                                    │
│  Scientists warn that...           │
│                                    │
├────────────────────────────────────┤
│  ◀  ▶/⏸  ▶  x1.0  [Tr] [Fol]    │
└────────────────────────────────────┘

≡ 点击后侧边栏展开（覆盖层）：
┌─────────┬──────────────────────────┐
│ Outline │  (内容区半透明遮挡)      │
│          │                          │
│ ☰ Clim.. │                          │
│ ├─ 🌡️.. │                          │
│ │  ○ S1  │                          │
│ │  ● S2  │                          │
│ │  ○ S3  │                          │
│ ├─ 📊..  │                          │
│ ├─ 🏭..  │                          │
│ └─ 🌍..  │                          │
│          │                          │
│ [Close]  │                          │
└─────────┴──────────────────────────┘
```

### 响应式布局规则

```dart
if (width >= 768) {
  // iPad / 大屏：大纲侧边栏固定
  Row(
    children: [
      SizedBox(width: 260, child: OutlineSidebar()),
      Expanded(child: ContentArea()),
    ],
  );
} else {
  // iPhone：大纲侧边栏以抽屉形式滑入
  Stack(
    children: [
      ContentArea(),
      if (_showOutline)
        Positioned(left: 0, top: 0, bottom: 0, width: 280, 
          child: OutlineSidebar()),
    ],
  );
}
```

---

## 七、跟读面板

所有跟读面板和视频 Dub 面板一致，根据当前模式自动切换粒度：

```
当前在逐句模式 → 跟读当前句
当前在章节模式 → 跟读当前章节
```

```
┌──────────────────────────────────────────────┐
│  Follow Along — Sentence 12/48               │
├──────────────────────────────────────────────┤
│                                               │
│  "This warming is unprecedented in            │
│   modern history."                           │
│                                               │
│  🔊 [Listen]  🎤 [Record]  ▶ [Playback]     │
│                                               │
│  Score: 85                                    │
│  ████████████████████░░  Accuracy: 90%       │
│  ██████████████░░░░░░░░  Fluency: 78%        │
│  ██████████████████░░░░  Completeness: 85%   │
│                                               │
│  ◀ Sentence 12/48 ▶                          │
│                                               │
│     [Scope: This Sentence | This Chapter]     │
└──────────────────────────────────────────────┘
```

---

## 八、文章阅读器的 Flutter 组件树

```dart
ArticleReaderPage
├── AppBar
│   ├── BackButton
│   ├── Title
│   ├── OutlineToggleButton (移动端 ≡)
│   └── SettingsMenu (⋮)
│
├── Body
│   ├── OutlineSidebar (左，条件显示)
│   │   ├── ArticleNode (第1层)
│   │   ├── ChapterNode (第2层 × N)
│   │   │   ├── PlayButton (▶)
│   │   │   └── FollowButton (🎤)
│   │   └── SentenceNode (第3层，当前章节展开时 × N)
│   │       └── StatusIcon (●/○/✓)
│   │
│   └── ContentArea (右)
│       ├── ChapterTitle
│       ├── MarkdownBody (章节内容)
│       │   ├── 引用块
│       │   ├── 列表
│       │   └── SelectableWord (划词)
│       ├── WordCard (条件显示，点击单词弹出)
│       └── ChapterDivider
│
├── BottomControlBar
│   ├── PrevChapterButton (◀◀)
│   ├── PrevSentenceButton (◀)
│   ├── PlayPauseButton (▶/⏸)
│   ├── NextSentenceButton (▶)
│   ├── NextChapterButton (▶▶)
│   ├── SpeedSelector (x1.0)
│   ├── TranslateToggle (Tr)
│   ├── FollowButton (Fol)
│   └── QuizButton (Quiz)
│
└── FollowPanel (条件显示)
    ├── ReferenceText
    ├── ListenButton / RecordButton / PlaybackButton
    └── ScoreDisplay
```
