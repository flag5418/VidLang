# 文章阅读器 — 最终设计方案

> 版本: v3.0 | 日期: 2026-06-14 | 三轮设计迭代收敛

---

## 一、定位与约束

VidLang 的核心价值是「视频 + 文章 + 歌曲 → 统一学习闭环」。文章阅读器不是要做成 Kindle 或蒙哥，而是：

> 让用户能把任意英文文本导入后，流畅阅读、遇到生词能查能收藏、想翻译时能翻译，最终通过测试检验学习效果。

**三个约束**：
- 不做写作/编辑器：文章创建用简单输入框 + WiFi 粘贴
- 不做社交/打卡：测试结果可看，不做海报/分享
- 最大化复用现有能力：WordCard、TTS引擎、测试引擎、生词本

---

## 二、功能矩阵

```
阅读 → 查词/翻译 → 收藏 → 测试
```

| 用户动作 | 功能 | 实现方式 | Phase |
|---------|------|---------|-------|
| 阅读 | 看文章 | Markdown 渲染 + 字体调节 + 进度条 | 1 |
| 阅读 | 导航 | 侧边栏浮层（段落列表 + 跳转） | 1 |
| 阅读 | 断点续读 | 书签（自动记忆 + 手动标记） | 1 |
| 查词 | 理解单词/短语 | 划词 → 横向轻量菜单 [释义][朗读][收藏][翻译] | 1 |
| 查词 | 段落级理解 | 点击段落 → [释义]（tooltip） | 2 |
| 翻译 | 全文/段落翻译 | 翻译弹窗（上下布局，英文+TTS+中文） | 2 |
| 朗读 | 段落朗读 | TTS 逐句 + 单词级高亮 + 自动滚动 | 2 |
| 收藏 | 单词→生词本 | 复用 WordBook，content_type='word' | 1 |
| 收藏 | 句子→知识库 | 复用 WordBook，content_type='sentence' | 3 |
| 测试 | 检验效果 | 复用 TestEngine（填空/听写/选择） | 3 |

---

## 三、核心设计决策

### 3.1 划词菜单（非模态）

划词后出现横向 toolbar，不阻断阅读：

```
┌──────────────────────────────────┐
│ [释义] [🔊朗读] [⭐收藏] [📖翻译]  │  ← 半透明横向菜单
└──────────────────────────────────┘
  The quick [brown fox] jumps over...
```

- **[释义]**：在当前句下方插入 tooltip 中文释义，可收起
- **[朗读]**：TTS 朗读选中文本，仅发声
- **[收藏]**：单词→生词本(等级标签)，多词→知识库(自定义标签)
- **[翻译]**：打开翻译弹窗

### 3.2 翻译弹窗（统一下布局）

所有翻译场景共用同一弹窗组件：

```
┌──────────────────────────────┐
│ 翻译                     [×] │
├──────────────────────────────┤
│ 英文原文（可滚动）             │  ← TTS逐句朗读+高亮
│ [🔊 朗读英文]                 │
├──────────────────────────────┤
│ 中文译文（可滚动）             │
├──────────────────────────────┤
│            [关闭]             │
└──────────────────────────────┘
```

- 弹窗高度 70%~80%，宽度 90%
- 英文区 TTS 逐句朗读 + 单词级高亮
- 触发源：划词菜单[翻译]、全文翻译悬浮按钮

### 3.3 段落 = 操作锚点，句子 = 高亮单元

- 段落：侧边栏导航 + 段落选择 + 全文翻译分段
- 句子：TTS 朗读单元 + 高亮单元 + 收藏上下文
- 不用 Chapter 层级，Markdown 标题自然渲染

### 3.4 书签 = 自动记忆 + 手动标记

- **自动**：退出时保存 `last_paragraph_index / last_sentence_index`，下次打开提示「是否继续」
- **手动**：侧边栏长按段落 → [标记书签]，存入 `article_bookmark` 表

### 3.5 TTS 单词级高亮

```
"This is a wonderful sentence to learn."
 ~~~~ ~~~~ ~ ~~~~~~~~~ ~~~~~~~~ ~~ ~~~~~
 已读  已读  当前词(加粗+蓝)  未读(正常)
```

利用 `flutter_tts.setProgressHandler` 回调逐词着色，精度不够则降级为计时器模拟。

### 3.6 词汇状态色（Phase 3）

渲染时查询 WordBook，已收藏单词着色（灰色/蓝色下划线），降低认知负荷。

---

## 四、数据模型

### 4.1 新增表

```sql
article（文章主表）
├── code              TEXT PK
├── title             TEXT
├── content_markdown  TEXT        Markdown全文
├── total_paragraphs  INTEGER     段落总数
├── total_sentences   INTEGER     句子总数
├── word_count        INTEGER     总词数
├── progress          REAL        学习进度0.0~1.0
├── last_paragraph_index INTEGER  上次阅读段落
├── last_sentence_index  INTEGER  上次阅读句子
├── folder_code       TEXT FK     所属文件夹
├── created_at        TEXT
└── updated_at        TEXT

article_paragraph（段落表）
├── code              TEXT PK
├── article_code      TEXT FK
├── paragraph_index   INTEGER     段落序号
├── content_markdown  TEXT        段落Markdown
├── content_plain     TEXT        纯文本（TTS用）
├── translation       TEXT        译文缓存
├── start_sentence_idx INTEGER  起始句子索引
└── end_sentence_idx  INTEGER     结束句子索引

article_sentence（句子表，FTS5）
├── code              TEXT PK
├── article_code      TEXT FK
├── paragraph_index   INTEGER     所属段落
├── sentence_index    INTEGER     句子序号
├── content           TEXT        句子原文
├── start_position_ms INTEGER    TTS时间轴起点
└── end_position_ms   INTEGER    TTS时间轴终点

article_bookmark（书签表）
├── code              TEXT PK
├── article_code      TEXT FK
├── paragraph_index   INTEGER
├── sentence_index    INTEGER
├── note              TEXT        备注
└── created_at        TEXT
```

### 4.2 word_book 扩展

```sql
ALTER TABLE word_book ADD COLUMN content_type TEXT DEFAULT 'word';
-- 'word'=生词本 | 'sentence'=知识库 | 'phrase'=短语本

ALTER TABLE word_book ADD COLUMN source_text TEXT;
ALTER TABLE word_book ADD COLUMN source_translation TEXT;
ALTER TABLE word_book ADD COLUMN source_type TEXT;
-- 'article' | 'video' | 'audio'
```

---

## 五、阅读器布局

```
┌──────────────────────────────┐
│ [←] 文章标题       [≡][🔖][⋮] │  AppBar
├──────────────────────────────┤
│                              │
│  Paragraph 1                 │  Markdown渲染
│  The quick brown fox...      │
│                              │
│  Paragraph 2                 │
│  Lorem ipsum dolor sit...    │
│                              │
├──────────────────────────────┤
│ ██████████░░░░░░░░  38%      │  进度条
│ 预估8分钟 · 已读365/960词     │
└──────────────────────────────┘

侧边栏（≡唤出，浮层）：
┌──────────────────────┐
│ ☰ 段落导航            │
│ 已学12句/共48句       │  ← 进度仪表盘
│ 掌握38个单词          │
├──────────────────────┤
│ 🔖 Paragraph 2       │  ← 书签标记
│ Lorem ipsum...       │
│ ● Paragraph 3        │  ← 当前段落
│ Duis aute irure...   │
│   Paragraph 4        │
│ Excepteur sint...    │
└──────────────────────┘
```

---

## 六、组件树

```dart
ArticleReaderPage
├── AppBar [返回] [标题] [书签标记🔖] [侧边栏≡] [菜单⋮]
├── body: Stack
│   ├── MarkdownContent
│   │   └── ParagraphWidget × N
│   │       ├── GestureDetector（点击段落）
│   │       ├── ParagraphToolbar [释义][朗读]（选中段落时）
│   │       ├── SelectableText.rich（Markdown渲染）
│   │       └── WordTooltip（释义tooltip，条件显示）
│   │
│   ├── WordActionToolbar（划词横向菜单）
│   │   └── [释义][朗读][收藏][翻译]
│   │
│   └── FloatingTranslateFab（右下角悬浮，Phase 2）
│
├── bottomBar: ReadingProgressBar
│
├── TranslateDialog（翻译弹窗，showDialog）
│   ├── EnglishSection（TTS逐句+高亮）
│   └── ChineseSection（译文）
│
├── OutlineDrawer（侧边栏浮层）
│   ├── ProgressDashboard
│   └── ParagraphList（含书签标记）
│
├── CollectionSheet（收藏底部弹窗）
│   ├── WordForm（等级标签）
│   └── SentenceForm（标签输入）
│
└── FontSizeSheet（字体设置）
```

---

## 七、Phase 1 MVP 范围

| # | 事项 | 说明 |
|---|------|------|
| 1 | 数据模型 | article/paragraph/sentence/bookmark 表 + DAO |
| 2 | 底部导航 | 新增「文章」Tab + ArticleListPage 卡片列表 |
| 3 | 文章创建 | 标题+粘贴→解析段落句子→入库 |
| 4 | 阅读器基础 | Markdown渲染+字体调节+进度条 |
| 5 | 侧边栏 | 浮层段落列表+点击跳转 |
| 6 | 划词菜单 | 横向toolbar [释义tooltip][朗读][收藏][翻译入口] |
| 7 | 书签 | 自动记忆退出位置+手动标记 |

Phase 1 不做：翻译弹窗组件、TTS全文朗读、段落选择按钮、全文翻译悬浮按钮、知识库管理。

---

## 八、实施计划

| Phase | 内容 | 工作量 |
|-------|------|--------|
| 1 | 基础阅读MVP（7项） | 7-8天 |
| 2 | 翻译弹窗+TTS朗读+段落操作 | 5-6天 |
| 3 | 收藏体系+知识库+测试 | 6-7天 |
| 4 | 收集工作台+WiFi导入+词汇状态色 | 5-7天 |
