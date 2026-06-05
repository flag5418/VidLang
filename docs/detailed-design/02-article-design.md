# VidLang 详细设计 — 文章学习功能

## 一、核心约束

1. 文章必须以 **Markdown** 格式存储原文
2. 显示时保留 Markdown 格式（标题、段落、列表、加粗、引用等）
3. 阅读布局：**大纲侧边栏（左）+ 内容区（右）+ 底部控制栏**
4. 跟读支持三种粒度：**全文跟读 / 章节跟读 / 单句跟读**
5. 长按跳章节：**短按=上/下一句，长按=上/下一章**
6. 文章必须归属于一个叶子文件夹（FolderType.article）

---

## 二、数据模型

### 2.1 Article（文章）

```dart
class Article extends BaseEntity {
  String folderCode;            // 所属文件夹 code
  String title;                 // 文章标题
  String contentMarkdown;       // 原文 Markdown 格式存储（全文）
  String? coverUrl;             // 文章封面图
  String language;              // 语言，默认 'en'
  String? author;               // 作者
  String? sourceUrl;            // 原文来源 URL

  // 结构信息（导入时自动解析）
  int totalChapters;            // 总章节数
  int totalSentences;           // 总句子数
  int wordCount;                // 总单词数

  // 学习进度
  double progress;              // 0.0 ~ 1.0
  int lastChapterIndex;         // 最后学习章节索引
  int lastSentenceIndex;        // 最后学习句子索引
  DateTime? lastStudyDate;
  int studyCount;

  // 跟读录音
  String? fullRecordingPath;    // 全文跟读录音路径
  int orderIndex;
}
```

### 2.2 ArticleChapter（章节）

```dart
class ArticleChapter extends BaseEntity {
  String articleCode;           // 所属文章 code
  int chapterIndex;             // 章节序号（从0开始）
  String title;                 // 章节标题（如 "## Introduction"）
  String markdown;              // 该章节 Markdown 原文
  int startSentenceIndex;       // 起始句子索引
  int sentenceCount;            // 包含句子数
  String? recordingPath;        // 章节跟读录音路径
  double? lastScore;            // 最后跟读评分
}
```

### 2.3 ArticleSentence（句子）

```dart
class ArticleSentence extends BaseEntity {
  String articleCode;
  int chapterIndex;             // 所属章节索引
  int sequenceIndex;            // 句子序号（全局）
  String content;               // 句子原文
  String? contentTranslate;     // 翻译

  // 阅读时间轴（用于自动播放模式）
  int startPositionMs;          // 累计起始位置
  int endPositionMs;            // 累计结束位置

  int wordCount;
  bool isKeySentence;           // 是否被标记
}
```

---

## 三、文章导入流程

```
用户操作
    ↓
选择导入方式
├── 粘贴文本 → 自动检测转为 Markdown
├── 粘贴 Markdown → 直接存储
├── 拍照 OCR → 转为 Markdown
└── 导入 .md 文件
    ↓
智能解析
├── 按 # ## ### 提取章节
├── 保留段落结构
├── 按 . ! ? 分句（排除缩写）
├── 计算总章节数 / 句子数 / 单词数
└── 生成句子时间轴（TTS估算时长：wordCount × 400ms）
    ↓
保存
├── Article（全文 Markdown）
├── ArticleChapter 列表
└── ArticleSentence 列表
    ↓
进入阅读器（默认 Sentence 模式，定位到上次学习位置）
```

---

## 四、阅读器布局（最终方案：大纲侧边栏）

### 4.1 整体布局

```
┌──────────────────────────────────────────────────────────────────┐
│  [←]  Article Title                      [≡]  [⋮]  [Quiz]      │
├────────────┬─────────────────────────────────────────────────────┤
│            │                                                      │
│  Outline   │  ## Chapter Title                                   │
│            │                                                      │
│  ☰ Article │  Chapter content rendered as Markdown...           │
│  Title     │                                                     │
│            │  This is the **current sentence** being played.    │
│  ├─ 🌡️     │                                                     │
│  │ Chapter │  Next sentence of current chapter...                │
│  │ 1  ▶ 🎤 │                                                     │
│  │         │  > Blockquote rendering                             │
│  │  ○ S1   │                                                     │
│  │  ● S2   │  - List item 1                                     │
│  │  ○ S3   │  - List item 2                                     │
│  │  ○ S4   │                                                     │
│  │         │  Next chapter begins...                             │
│  ├─ 📊     │  ──────────────────────────────────────────────     │
│  │ Chapter │                                                     │
│  │ 2       │                                                     │
│  │         │                                                     │
│  ├─ 🏭     │                                                     │
│  │ Chapter │                                                     │
│  │ 3       │                                                     │
│  │         │                                                     │
│  └─ 🌍     │                                                     │
│    Chapter │                                                     │
│    4       │                                                     │
│            │                                                     │
├────────────┴─────────────────────────────────────────────────────┤
│  ◀◀  ◀  Sentence 12/48  ▶  ▶▶    x1.0  [Tr] [Fol] [Outline]  │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 大纲侧边栏三层结构

```
第1层：☰ Article Title                  ← 点击回到全文顶部
│
├─ 第2层：🌡️ Chapter 1  ▶ 🎤          ← 当前展开章节
│  │                                     ▶=播放本章 🎤=跟读本章
│  ├─ 第3层：○ S1  First sentence...    ← ○=未学习
│  ├─ 第3层：● S2  Current sentence..   ← ●=当前播放句
│  ├─ 第3层：○ S3  Third sentence...   
│  ├─ 第3层：✓ S4  Fourth sentence..   ← ✓=已学完
│  └─ 第3层：○ S5  Fifth sentence...   
│
├─ 第2层：📊 Chapter 2                  ← 收起状态
├─ 第2层：🏭 Chapter 3
└─ 第2层：🌍 Chapter 4
```

### 4.3 展开/收起规则

| 触发 | 行为 |
|------|------|
| 播放到某章节 | 自动展开该章节 → 显示该章节所有句子 |
| 用户点击某章节 | 展开点击的章节，其他章节收起 |
| 用户点击某句子 | 展开所属章节，跳转到该句 |
| 默认 | 只显示文章名 + 所有章节标题 |

### 4.4 视觉标记

| 节点 | 状态 | 显示 |
|------|------|------|
| 当前章节 | 展开中 | `▶` 图标 + 背景高亮 |
| 当前句子 | 播放中 | `●` 圆点 + 行高亮 |
| 已学完句子 | 已完成 | `✓` 标记 |
| 未学句子 | 未学习 | `○` 标记 |

---

## 五、右侧内容区渲染

### 5.1 三种颜色层级

| 层级 | 文本色 | 背景 | 说明 |
|------|--------|------|------|
| **当前句** | `#FFFFFF` 纯白 | `rgba(255,255,255,0.12)` | 正在播放/学习的句子 |
| **当前章节** | `#E0E0E0` 亮灰 | 无 | 当前章节内其他句子 |
| **上下文** | `#9E9E9E` 灰色 | 无 | 非当前章节内容 |

### 5.2 划词（点击查词）

用户点击句子中的单词 → 弹出 WordCard 浮层（复用 DeepSeek 查询）

```dart
// 将句子文本拆分为可点击的单词
Widget _buildSelectableSentence(String sentence) {
  final words = sentence.split(' ');
  return Wrap(
    children: words.map((word) {
      return GestureDetector(
        onTap: () => _showWordCard(word, sentence),
        child: Text('$word '),
      );
    }).toList(),
  );
}
```

---

## 六、底部控制栏

### 6.1 按钮布局

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│  ◀◀     ◀       ▶/⏸       ▶     ▶▶     x1.0  Tr  Fol  Quiz │
│  Prev    Prev    Play/Pause Next   Next                        │
│  Chap    Sent               Sent   Chap                        │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### 6.2 交互规则

| 按钮 | 短按 | 长按 |
|------|------|------|
| `◀◀` | 上一章节 | — |
| `◀` | 上一句 | 上一章节 |
| `▶/⏸` | 播放/暂停 TTS | — |
| `▶` | 下一句 | 下一章节 |
| `▶▶` | 下一章节 | — |
| `x1.0` | 速度选择（0.5x ~ 2.0x） | — |
| `Tr` | 翻译显隐 | — |
| `Fol` | 跟读面板 | — |
| `Quiz` | 测试模式 | — |

---

## 七、跟读多粒度

### 7.1 三种跟读粒度

```dart
enum FollowMode {
  perSentence,  // 逐句跟读（当前句）
  perChapter,   // 逐章跟读（当前章节）
  fullPassage,  // 全文跟读（整篇文章）
}
```

### 7.2 跟读面板（复用视频 Dub 面板）

```
┌──────────────────────────────────────────────┐
│  Follow — Sentence 12/48                     │
├──────────────────────────────────────────────┤
│  "This warming is unprecedented..."          │
│                                               │
│  🔊 [Listen]  🎤 [Record]  ▶ [Playback]     │
│                                               │
│  Score: 85/100                                │
│  Accuracy: 90%  Fluency: 78%                 │
│                                               │
│  ◀ Sentence 12/48 ▶                          │
│                                               │
│     [Scope: Sentence | Chapter | Full]        │
└──────────────────────────────────────────────┘
```

---

## 八、移动端适配

| 屏幕宽度 | 布局 |
|---------|------|
| >= 768px (iPad) | 大纲侧边栏固定左侧 260px，内容区右侧 |
| < 768px (iPhone) | 大纲侧边栏以抽屉形式从左侧滑入（≡ 按钮触发） |

```dart
if (width >= 768) {
  Row(children: [
    SizedBox(width: 260, child: OutlineSidebar()),
    Expanded(child: ContentArea()),
  ]);
} else {
  Stack(children: [
    ContentArea(),
    if (_showOutline)
      Positioned(left: 0, width: 280, child: OutlineSidebar()),
  ]);
}
```

---

## 九、进入阅读器的完整流程

```
ArticleListPage
├── 点击"继续学习"卡片
│   → 打开上次退出的章节和句子位置
├── 点击文章卡片
│   → 默认进入，定位到上次学习的章节/句子
│   → 从未学习过则从第1章第1句开始
└── 新建文章
    → 粘贴/OCR/导入 → 处理后进入阅读器
```
