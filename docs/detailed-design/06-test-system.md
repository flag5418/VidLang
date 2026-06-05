# VidLang 详细设计 — 双层测试体系

## 一、两层测试结构

### 1.1 层级定义

```
第一层：单资源测试（Unit Test）
├── 基于单个资源的片段（字幕/句子/歌词）出题
├── 入口：播放器内的 [Quiz] 按钮
└── 题型：填空 / 听写 / 选择题

第二层：文件夹综合测试（Folder Test）
├── 基于文件夹内所有资源的随机片段出题
├── 入口：文件夹详情页的 [综合测试] 按钮
├── 支持按类型筛选（仅视频/仅文章/混合）
└── 题型：填空 / 听写 / 选择题
```

### 1.2 统一测试引擎

```dart
class TestEngine {
  /// 生成题目列表
  /// segments: 数据源（字幕/句子/歌词列表）
  /// config: 测试配置（题型/数量/难度）
  /// folderContext: 可选，整体测试时使用
  static List<TestQuestion> generateQuestions({
    required List<SegmentEntity> segments,
    TestConfig config = const TestConfig(),
  });

  /// 评分
  static TestResult evaluate({
    required List<TestQuestion> questions,
    required List<UserAnswer> answers,
  });
}

class TestConfig {
  int questionCount;          // 题目数
  List<QuestionType> types;   // 允许的题型
  double difficulty;          // 0.0-1.0（影响删除词的选择策略）
  // 整体测试配置
  String? folderCode;
  List<String>? resourceCodes; // 指定要测试的资源
}

enum QuestionType {
  fillInBlank,   // 完形填空
  dictation,     // 听写
  multipleChoice,// 选择题
}
```

## 二、三种题型

### 2.1 完形填空（Fill-in-the-Blank）

```
随机从句子中删除一个词（非冠词/介词，选实词）
提供 4 个选项（1 正确 + 3 干扰词）
```

```
┌─────────────────────────────────────┐
│  Fill in the blank · 3/15          │
├─────────────────────────────────────┤
│                                     │
│  "This warming is _____ in          │
│   modern history."                  │
│                                     │
│  ┌─────────────────────────────┐   │
│  │  A. unprecedented        ●  │   │
│  │  B. unbelievable         ○  │   │
│  │  C. uncomfortable        ○  │   │
│  │  D. unavoidable          ○  │   │
│  └─────────────────────────────┘   │
│                                     │
│         [Next Question]             │
└─────────────────────────────────────┘
```

干扰词生成策略：
- 从当前文件夹其他资源中抽取同长度/同词性单词
- DeepSeek 辅助（Phase 2 可接入）

### 2.2 听写（Dictation）

```
播放句子音频（视频原声/TTS），用户打字写出
```

```
┌─────────────────────────────────────┐
│  Dictation · 5/15                  │
│  🔊 [Play Audio] (Tap to replay)   │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │  Type what you hear:       │   │
│  │                             │   │
│  │  [________________________] │   │
│  └─────────────────────────────┘   │
│                                     │
│         [Check Answer]              │
├─────────────────────────────────────┤
│  Result:                            │
│  This warming is ✓ unprecedented    │
│  in ✗ (typed: in) modern ✓ history  │
│                                     │
│  Score: 80%                         │
│  ───                                  │
│  Missed words: unprecedented        │
└─────────────────────────────────────┘
```

### 2.3 选择题（Multiple Choice——基于内容理解）

```
基于句子或段落内容出理解题
需要 DeepSeek 辅助生成（或使用固定模板）
```

```
┌─────────────────────────────────────┐
│  Reading Comprehension · 10/15     │
├─────────────────────────────────────┤
│                                     │
│  "Global temperatures have risen    │
│   by an average of 1.2°C since      │
│   the pre-industrial era."          │
│                                     │
│  What has increased by 1.2°C?       │
│                                     │
│  ○ A. Sea levels                    │
│  ● B. Global temperatures           │ ← 正确
│  ○ C. Carbon emissions              │
│  ○ D. Population                    │
│                                     │
│         [Next Question]             │
└─────────────────────────────────────┘
```

## 三、测试流程

### 3.1 单资源测试入口

```
在播放器/阅读器中：
底部控制栏 → [Quiz] 按钮
    ↓
弹出对话框：选择测试范围
├── Current chapter only（当前章节）
├── Entire content（全部内容）
└── X questions（数量）
    ↓
生成题目 → TestPage
    ↓
答题 → 自动评分
    ↓
显示结果 → 错词建议收藏到 WordBook
```

### 3.2 文件夹整体测试入口

```
在文件夹详情页：
顶部 → [综合测试 Folder Test] 按钮
    ↓
弹出对话框：配置测试
├── 题量：10 / 20 / 30 / 50
├── 题型：☑ 填空 ☑ 听写 ☐ 选择
├── 范围：
│   ├── 所有资源
│   ├── 仅视频
│   ├── 仅文章
│   └── 仅歌曲
└── [开始测试]
    ↓
从选中的资源中随机抽取句子
    ↓
生成题目 → 进入 TestPage
```

### 3.3 测试结果页面

```
┌─────────────────────────────────────┐
│  Test Complete!                     │
├─────────────────────────────────────┤
│                                     │
│         Score: 85%                  │
│                                     │
│  ████████████████░░░░░░             │
│                                     │
│  Correct: 13/15     Time: 4:32     │
│                                     │
│  ┌─ Video ──────────────────────┐  │
│  │ Friends S01E01:  3/4 correct │  │ ← 按资源分组
│  └──────────────────────────────┘  │
│  ┌─ Article ───────────────────┐  │
│  │ Climate Change: 8/9 correct │  │
│  └──────────────────────────────┘  │
│  ┌─ Song ──────────────────────┐  │
│  │ Let It Be:        2/2 correct│  │
│  └──────────────────────────────┘  │
│                                     │
│  Words to review:                   │
│  unprecedented (missed 2x)         │
│  pressing (missed 1x)              │
│                                     │
│  [Add missed words to WordBook]     │
│  [Review incorrect answers]         │
│  [Test Again]  [Back to Folder]    │
└─────────────────────────────────────┘
```

## 四、FolderDetailPage 改造

文件夹详情页从仅支持视频，扩展为支持三种类型：

```dart
class FolderDetailPage extends ConsumerWidget {
  final String folderCode;

  // 根据 folder.folderType 决定：
  // video → 显示视频网格（现有 UI）
  // article → 显示文章列表
  // music → 显示歌曲列表
}
```

### 4.1 文章文件夹详情页

```
┌──────────────────────────────────────┐
│ [←] My Reading    [Folder Test]      │
├──────────────────────────────────────┤
│  ┌──────────────────────────────┐   │
│  │  [当前文章大卡片]            │   │ ← 最后阅读的文章
│  │  Climate Change and...      │   │
│  │  Progress: ████░░ 45%       │   │
│  │  5 chapters · 48 sentences  │   │
│  └──────────────────────────────┘   │
│                                      │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐  │
│  │Article│ │Article│ │ [+  │ │     │  │
│  │  1   │ │  2   │ │Import│ │     │  │ ← 文章网格
│  └─────┘ └─────┘ └─────┘ └─────┘  │
└──────────────────────────────────────┘
```

### 4.2 文章入口的快速导入按钮

```
[+ Import]
├── Paste text / Markdown
├── Scan from camera (OCR)
└── Import .md file
```

### 4.3 综合测试按钮位置

文件夹详情页顶部新增 `[Folder Test]` 按钮，在 "导入" 按钮旁边。
