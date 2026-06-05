# VidLang 文章学习（Article Study）功能设计文档

> 设计版本：v1.0  
> 设计日期：2026-06-04  
> 设计范围：从"视频+字幕"扩展到"纯英文文章+智能字幕"学习模式

---

## 1. 功能概述

### 1.1 目标

将 VidLang 从**视频驱动**的英语学习工具，升级为**视频 + 纯英文文章双引擎**学习平台。用户可以通过**粘贴英文原文**或**截图 OCR 识别**，导入雅思文章、外刊新闻等任意英文文本，系统自动将其切分为"字幕条目"，模拟视频播放的学习体验——逐句高亮、TTS朗读、跟读、收藏单词、发音评测、内容测试。

### 1.2 用户场景

| 场景 | 输入方式 | 学习需求 |
|------|----------|----------|
| 雅思阅读文章 | 粘贴全文 | 精读 → 逐句听读 → 收藏生词 → 完成测试 |
| 外刊新闻（The Guardian / BBC） | 截图 OCR | 快速识别 → 逐段学习 → 跟读评分 |
| 英文小说/散文片段 | 粘贴 | 沉浸式阅读 + 即时查词 + 语感训练 |
| 英文演讲稿/美文 | 粘贴 | 逐句 TTS 播放 → 跟读模仿 → 发音评分 |

### 1.3 核心学习闭环

```
获取文章（粘贴/OCR）→ AI智能分句 → 存入"文章字幕"
    ↓
阅读/播放学习（TTS逐句播放 / 手动翻句）
    ↓
逐句跟读（录音 → 回放对比 → AI发音评分）
    ↓
单词深度查询（DeepSeek三阶段 → 释义/例句/词联网络）
    ↓
收藏生词（加入单词本 → 间隔复习）
    ↓
内容测试（填空/听写/选择题 → 检验掌握度）
    ↓
学习记录（进度同步、学习时长统计）
```

---

## 2. 整体架构变化

### 2.1 底部导航扩展

**现在（2 tabs）：**

```
MainPage BottomNav:  视频 | 我的
```

**改后（3 tabs）：**

```
MainPage BottomNav:  视频 | 文章 | 我的
```

新增"文章"（Reading）tab，作为文章学习的入口。

### 2.2 新增文件/目录结构

```
lib/
├── models/
│   ├── article.dart            ← 新增：文章实体
│   ├── article_sentence.dart   ← 新增：文章句子实体
│   ├── word_book.dart          ← 新增：单词本/收藏实体
│   └── ... (现有模型不变)
├── views/
│   ├── reading/
│   │   ├── article_list_page.dart     ← 新增：文章列表页
│   │   ├── article_create_page.dart   ← 新增：文章创建（粘贴/OCR）
│   │   ├── article_reader_page.dart   ← 新增：文章阅读播放器
│   │   ├── article_test_page.dart     ← 新增：文章测试页
│   │   └── word_book_page.dart        ← 新增：单词本页面
│   └── ... (现有视图不变)
├── providers/
│   ├── article_provider.dart          ← 新增：文章状态管理
│   ├── reader_engine_provider.dart    ← 新增：阅读引擎状态
│   └── ... (现有 provider 不变)
├── services/
│   ├── text_processor.dart            ← 新增：文本分割/时长估算
│   ├── tts_service.dart               ← 新增：TTS 朗读服务
│   ├── speech_evaluation_service.dart ← 新增：发音评分服务
│   └── ... (现有服务不变)
└── widgets/
    ├── word_card.dart                 ← 新增：单词详情卡片（复用 DeepSeek 数据）
    └── ... (现有组件不变)
```

### 2.3 注册新实体到 DatabaseService

在 `main.dart` 的 `DatabaseService.registerEntities(...)` 中新增：

```dart
'article': EntityConfig(creator: () => Article(), description: '文章表'),
'article_sentence': EntityConfig(creator: () => ArticleSentence(), description: '文章句子表（支持全文检索）'),
'word_book': EntityConfig(creator: () => WordBook(), description: '单词本表'),
```

---

## 3. 数据模型设计

### 3.1 Article（文章）

类比 `VideoFolder`，代表一篇文章。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int? | 主键 |
| `code` | String? | UUID 唯一标识 |
| `user_code` | String? | 用户标识（多用户隔离） |
| `title` | String | 文章标题（自动生成或用户指定） |
| `content_raw` | String | 原文全文（未分割） |
| `source_type` | String | 来源：`clipboard` / `camera` / `manual` |
| `language` | String | 语言，默认 `en` |
| `sentence_count` | int | 句子总数 |
| `estimated_duration_ms` | int | 估算总时长（毫秒） |
| `word_count` | int | 单词总数 |
| `progress` | double | 学习进度（0.0 ~ 1.0） |
| `last_sentence_index` | int | 最后学习到的句子索引 |
| `last_study_date` | DateTime? | 最后学习时间 |
| `study_count` | int | 学习次数 |
| `order_index` | int | 排序索引 |
| 审计字段 | ... | 继承 BaseEntity |

### 3.2 ArticleSentence（文章句子）

类比 `Subtitles`，代表文章中的一个句子及其"字幕时间轴"。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int? | 主键 |
| `code` | String? | UUID 唯一标识 |
| `article_code` | String | 所属文章 code |
| `sequence_index` | int | 句子序号（从 0 开始） |
| `content` | String | 句子原文 |
| `content_translate` | String? | 中文翻译 |
| `start_position_ms` | int | 在"阅读时间线"上的开始位置（毫秒） |
| `end_position_ms` | int | 在"阅读时间线"上的结束位置（毫秒） |
| `word_count` | int | 该句单词数 |
| `paragraph_index` | int? | 所属段落索引（可选） |
| `tts_audio_path` | String? | 预生成的 TTS 音频路径（可选缓存） |
| `is_collected` | bool | 是否被收藏/标记 |
| `difficulty` | int? | 难度评估（1-5） |

**时间轴说明：** 无视频时间线，需人为构造"阅读时间线"。  
每条句子的 `start_position_ms` 和 `end_position_ms` 根据 TTS 朗读时长 + 句间间隔计算：

```
sentence[i].start_position_ms = sum(sentence[0..i-1].tts_duration) + i * pause_interval
sentence[i].end_position_ms = sentence[i].start_position_ms + sentence[i].tts_duration
```

- `tts_duration` 估算：`word_count * (60s / words_per_minute) * 1000`
  - 正常语速：`150 wpm` → `word_count * 400ms`
  - 慢速：`100 wpm` → `word_count * 600ms`
- `pause_interval`：句间停顿，建议 `500ms`

### 3.3 WordBook（单词本）

类比 `Participle`，但跨来源（视频/文章均可收藏）。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | int? | 主键 |
| `code` | String? | UUID 唯一标识 |
| `user_code` | String? | 用户标识 |
| `word` | String | 单词 |
| `source_type` | String | 来源：`article` / `video` |
| `source_code` | String | 来源实体 code |
| `sentence_code` | String? | 来源句子 code |
| `sentence_context` | String? | 上下文句子原文 |
| `definitions_json` | String? | DeepSeek 查询结果的 JSON 缓存 |
| `difficulty` | int | 难度评级（1-5，默认 3） |
| `review_count` | int | 复习次数 |
| `correct_count` | int | 复习正确次数 |
| `next_review_at` | DateTime? | 下次复习时间（间隔重复） |
| `last_review_at` | DateTime? | 最后复习时间 |
| `is_mastered` | bool | 是否已掌握 |

### 3.4 ArticleStudyRecord

扩展 `StudyRecord`，增加 `source_type` 区分视频与文章学习。

建议在现有 `StudyRecord` 中新增字段 `source_type`（`video` / `article`）和 `source_code`（视频 code 或文章 code），或创建新的表。**推荐方案：复用 `StudyRecord`，加字段区分来源。**

---

## 4. 文章输入流程

### 4.1 入口：文章列表页 → FAB "新建文章"

```
┌────────────────────────────────┐
│  我的文章           [+ 新建]   │
├────────────────────────────────┤
│ 文章卡片 1                      │
│ ├── title                      │
│ ├── 进度条 + "5/23 句"        │
│ └── last_study_date            │
├────────────────────────────────┤
│ 文章卡片 2                      │
│ ...                            │
├────────────────────────────────┤
│          [FAB: + 新建]          │
└────────────────────────────────┘
```

### 4.2 新建文章底部弹窗

```
┌────────────────────────────────┐
│  新建文章                       │
├────────────────────────────────┤
│  📋 粘贴文本    ← 首选         │
│    从剪贴板粘贴英文原文         │
├────────────────────────────────┤
│  📷 拍照识别    ← 截图 OCR    │
│    拍照或从相册选择图片        │
├────────────────────────────────┤
│  ✏️ 手动输入                   │
│    手动输入英文文章            │
└────────────────────────────────┘
```

### 4.3 粘贴文本模式

```
┌────────────────────────────────┐
│ [←]  新建文章                  │
├────────────────────────────────┤
│  标题（可选自动生成）          │
│  ┌──────────────────────┐     │
│  │  在此粘贴英文原文...  │     │
│  │                      │     │
│  └──────────────────────┘     │
│                                │
│  [  预览并处理  ]             │
└────────────────────────────────┘
```

### 4.4 OCR 识别模式

利用已有 `IosNativeFeatures.extractTextFromCamera()`，拍照后提取文字，自动填入文本编辑框。

### 4.5 智能文本处理管线

```
原始文本输入
    ↓
Step 1: 文本清洗
    - 去除多余空格、换行符规范化
    - 修复引号、破折号等 Unicode 字符
    - 中英文混合文本分离
    ↓
Step 2: 智能分句
    - 规则分句：按 . ! ? 分割，处理缩写（Mr. Dr. U.S. 等）
    - 可选：DeepSeek AI 辅助分句（处理长段落、引号嵌套）
    - 合并过短片段（< 3 words 合并到前一句）
    - 分割超长句子（> 40 words 按从句/连接词拆分）
    ↓
Step 3: 生成 "字幕时间轴"
    - 遍历每个句子，按 word_count 估算 TTS 时长
    - 计算 cumulative start/end 位置（毫秒）
    - 总时长 ≈ sum(TTS时长) + 句数 × 500ms 间隔
    ↓
Step 4: 翻译（可选）
    - 批量或逐句调用 DeepSeek API 翻译
    - 或使用 iOS 原生翻译（IosNativeFeatures.translate）
    ↓
Step 5: 保存
    - 创建 Article 记录
    - 批量插入 ArticleSentence 记录
    - 跳转到阅读播放器页面
```

---

## 5. 阅读播放器（ArticleReaderPage）

这是整个功能的**核心页面**，需精心设计 UX。设计理念：复用视频播放器（PlayerPage）的"逐句高亮 + 控制栏"范式，但适配阅读场景。

### 5.1 页面布局

```
┌──────────────────────────────────────┐
│ [←]  文章标题        [设置] [单词本] │  ← 顶部栏
├──────────────────────────────────────┤
│  ████████████░░░░░░░░░░░  9/23      │  ← 进度条
├──────────────────────────────────────┤
│                                      │
│  ┌──────────────────────────────┐   │
│  │  ...上一句（小字、灰色）...  │   │  ← 历史上下文
│  │                              │   │
│  │  ▸ 当前句子（大字、白色）   │   │  ← 当前焦点句
│  │    翻译（小字、灰色）       │   │
│  │                              │   │
│  │  ...下一句（小字、灰色）...  │   │  ← 预览上下文
│  └──────────────────────────────┘   │
│                                      │
├──────────────────────────────────────┤
│ ⏪  ⏸  ⏩  [速度1.0x]  [朗读]      │  ← 底部控制栏
│ [单词]  [跟读]  [测试]  [列表]      │
└──────────────────────────────────────┘
```

### 5.2 两种阅读模式

| 模式 | 触发方式 | 行为 |
|------|----------|------|
| **手动模式**（手动翻句） | 默认 | 用户点击/滑动切换句子，无自动播放 |
| **自动模式**（TTS 播放） | 点击 ▶ 按钮 | TTS 按"字幕时间轴"逐句朗读，当前句高亮跟随 |

### 5.3 交互细节

#### 句子切换

- **手动翻句**：上滑/点击下半屏 → 下一句；下滑/点击上半屏 → 上一句
- **左右滑动切换**：左滑下一句，右滑上一句
- **底部控制栏**：⏪ 上一句、⏸ 暂停/开始自动播放、⏩ 下一句

#### 速度控制

- 点击速度按钮（1.0x）→ 弹出速度选择器（0.5x / 0.75x / 1.0x / 1.25x / 1.5x / 2.0x）
- 速度影响 TTS 朗读速率和"字幕时间轴"总时长

#### 单词查询

- 长按或双击句子中的单词 → 弹出 WordCard 浮层（复用 DeepSeek 查询）
  - 发音（UK/US）、音标、释义、例句、词联网络
  - 底部按钮："收藏单词"、"替换句子中的词"
- 收起浮层后，该单词高亮标记

#### 跟读（Dub）面板

复用 PlayerPage 的 Dub 面板逻辑：

```
┌────────────────────────────────┐
│         跟读面板                │
├────────────────────────────────┤
│  🔊 听原文                      │
│  🎤 录音（对比跟读）            │
│  ▶ 回放我的录音                │
│  ○ 发音评分（AI 对比评估）     │
└────────────────────────────────┘
```

**发音评分方案**（两阶段）：

| 阶段 | 方案 | 说明 |
|------|------|------|
| 短中期 | 使用 iOS `SFSpeechRecognition` | 听写准确率评估 |
| 长期 | 接入 DeepSeek API 语音评估 | 更专业的音素级评分 |

#### 全文操作

- 进度条可拖拽：跳到任意句子的"时间点"
- 底部"列表"按钮 → 展开句子索引列表（scrollable），显示每句前几个字
- "测试"按钮 → 进入该文章的测试模式

---

## 6. 测试模式（ArticleTestPage）

### 6.1 三种测试题型

| 题型 | 说明 | 实现 |
|------|------|------|
| **完形填空** | 随机删除句子中的部分单词，用户输入补全 | 提前用 `_` 替换选中的词 |
| **听写** | TTS 朗读句子，用户打字写出原文 | TTS + 输入框对照 |
| **选择题** | 针对文章内容出理解题 | DeepSeek 根据文章生成题干 + 选项 |
| **影子跟读** | 用户跟读并录音，AI 评发音和流利度 | TTS + 录音 + 语音评估 |

### 6.2 测试界面

```
┌────────────────────────────────┐
│ [←]  测试模式   第 3/20 题    │
├────────────────────────────────┤
│                                │
│  "The _____ of the research   │  ← 填空模式
│   was to _____ new insights"  │
│                                │
│  ┌──────────────────────────┐ │
│  │  [输入答案...]           │ │
│  └──────────────────────────┘ │
│                                │
│  ○ purpose  ○ propose         │  ← 或选择题
│  ○ purposed ○ purposeful      │
│                                │
│  [  下一题  ]  [  跳过  ]    │
└────────────────────────────────┘
```

### 6.3 测试结果

测试完成后展示报告：
- 正确率
- 错误单词/句子汇总
- 建议重点复习的单词
- 自动将这些单词添加到单词本

---

## 7. 单词本（WordBookPage）

### 7.1 页面设计

```
┌────────────────────────────────┐
│  单词本          [筛选] [排序] │
├────────────────────────────────┤
│  📚 全部 (42)                  │
│  ⭐ 待复习 (15)                │
│  ✅ 已掌握 (27)                │
├────────────────────────────────┤
│  ┌───────────┐ ┌───────────┐  │
│  │ profound  │ │ endeavor  │  │  ← 卡片式展示
│  │ ⭐⭐⭐     │ │ ⭐⭐      │  │
│  │ 深刻的     │ │ 努力      │  │
│  └───────────┘ └───────────┘  │
│  ┌───────────┐ ┌───────────┐  │
│  │ envisage  │ │ ...       │  │
│  └───────────┘ └───────────┘  │
└────────────────────────────────┘
```

### 7.2 间隔复习

| 复习次数 | 间隔 |
|----------|------|
| 第 1 次 | 1 天 |
| 第 2 次 | 3 天 |
| 第 3 次 | 7 天 |
| 第 4 次 | 14 天 |
| 第 5 次 | 30 天 |

- 每次复习展示：单词 → 用户回想释义 → 点击显示答案 → 自评正确/错误
- 正确 → 延长间隔；错误 → 缩短间隔

### 7.3 单词详情

点击单词跳转详细卡片（复用现有 DeepSeek 三阶段查询结果）：

```
┌────────────────────────────────┐
│  profound                      │
│  /prəˈfaʊnd/     🔊 UK  🔊 US │
├────────────────────────────────┤
│  adj. 深刻的，意义深远的       │
│  "a profound effect"           │
│  "a profound insight"          │
├────────────────────────────────┤
│  例句                          │
│  The book had a profound       │
│  impact on my thinking.        │
│  这本书对我的思想产生了深远    │
│  影响。                        │
├────────────────────────────────┤
│  词联                          │
│  同义：deep, intense           │
│  词族：profoundly, profundity │
│  易混：profuse, proffer       │
├────────────────────────────────┤
│  [来源句子]                     │
│  "This requires a profound    │
│   understanding of the field." │
├────────────────────────────────┤
│  [标记已掌握]  [删除]          │
└────────────────────────────────┘
```

---

## 8. 关键技术实现

### 8.1 TTS 朗读

**当前已有能力：** `IosNativeFeatures.speak()` 使用 iOS `AVSpeechSynthesizer`

**增强方案：**

| 需求 | 方案 |
|------|------|
| 逐句朗读 | 按 `ArticleSentence` 列表逐句调用 `speak()`，句间回调触发下一句 |
| 速度控制 | 使用 `AVSpeechUtterance.rate` 参数（0.0 ~ 1.0） |
| 避免句间中断 | 使用 `AVSpeechSynthesizerDelegate` 监听 `didFinish` 回调 |
| 拖动进度条 | 停止当前 TTS，跳转到目标句，继续播 |
| 预生成音频缓存 | 可选：将 TTS 音频预渲染到本地缓存，确保播放流畅 |

### 8.2 阅读引擎状态管理

新建 `ReaderEngineNotifier`（StateNotifier），类比 `PlayerEngineNotifier`：

```dart
class ReaderEngineState {
  String? articleCode;
  String title;
  List<ArticleSentence> sentences;
  int currentSentenceIndex;
  bool isPlaying;        // TTS 是否在播放
  bool isManualMode;     // true=手动翻句，false=TTS自动
  double speed;          // 0.5 ~ 2.0
  bool showTranslate;
  double progress;       // 0.0 ~ 1.0
  ReaderMode mode;       // reading / listening
  // 跟读相关
  bool dubPanelVisible;
  String? recordedAudioPath;
  // 状态
  bool isLoading;
  String? errorMessage;
}

enum ReaderMode { reading, listening }
```

### 8.3 文本智能分句服务（TextProcessor）

```dart
class TextProcessor {
  /// 清洗原始文本
  static String cleanRawText(String raw);

  /// 将文本分割为句子列表
  static List<String> splitSentences(String text);

  /// 估算句子的 TTS 时长（毫秒）
  static int estimateTtsDuration(String sentence, {double speed = 1.0});

  /// 完整处理管线：清洗 → 分句 → 生成时间轴
  static Future<List<ProcessedSentence>> process({
    required String rawText,
    double speed = 1.0,
    bool translate = false,
  });
}
```

分句规则：

```
1. 按 . ! ? 分割
2. 排除缩写：Mr. Mrs. Dr. Prof. St. Ave. U.S. U.K. etc. i.e. e.g.
3. 排除数字缩写：1st. 2nd. 3rd. 4th.
4. 引号闭合检查：引号内的句点不分割
5. 合并过短片段（< 3 words）
6. 拆分超长句子（> 40 words，按 and/but/or/；拆分）
```

### 8.4 DeepSeek 集成增强

现有 `DeepSeekApi` 已具备单词查询能力（三阶段），新功能中需要：

1. **批量翻译句子**：新增 `translateSentences(List<String> sentences)` 方法
2. **根据文章生成测试题**：新增 `generateQuiz(String articleText, String questionType)` 方法
3. **发音评估**：后续接入语音 API

### 8.5 学习记录扩展

在 `StudyRecord` 中新增字段（或创建新方案）：

```dart
class ExtendedStudyRecord extends BaseEntity {
  // 现有字段不变
  String sourceType;    // 'video' | 'article'
  String? sourceCode;   // video_code 或 article_code
  int sentencesStudied; // 本文学习了多少句
  int wordsCollected;   // 本次收藏了多少词
  double? testScore;    // 测试成绩（百分比）
}
```

---

## 9. UI/UX 设计规范

### 9.1 文章列表页（ArticleListPage）

- **设计风格**：与 FileListPage 一致，卡片网格布局
- **卡片内容**：文章标题、摘要（首句），进度条，更新日期，句子数
- **排序**：最近学习 > 标题字母 > 创建时间
- **空状态**：引导用户粘贴或拍照导入第一篇
- **交互**：点击进入阅读器；长按弹出菜单（重命名/删除/分享）

### 9.2 阅读播放器（ArticleReaderPage）

- **深色背景**（与 PlayerPage 一致），确保文字高亮清晰
- **句子大小**：当前句 18sp，上下文 13sp（半透明）
- **进度条**：细条位于顶部，可拖拽
- **控制栏**：半透明底栏，自动隐藏（手势点击显示）
- **翻译**：默认显示在句子下方，可点击"翻译"按钮切换显隐
- **点击单词**：弹出浮层卡片，背景模糊

### 9.3 动画过渡

- 句子切换：上滑动画（当前句上移淡出，新句从下方移入）
- 进度更新：平滑动画
- 单词卡片：底部弹入（类似 Apple Music 歌词卡片）

---

## 10. 实施阶段规划

### 第一阶段：基础框架（核心可用）

| 任务 | 预估工作量 |
|------|-----------|
| 新增 `Article` + `ArticleSentence` + `WordBook` 模型 | 1-2 天 |
| 在 `main.dart` 注册新实体 | 0.5 天 |
| 新增底部导航"文章"tab | 0.5 天 |
| 实现 `TextProcessor` 基本分句 | 1 天 |
| 实现 `ArticleListPage` 列表展示 | 1 天 |
| 实现粘贴文本创建文章 | 1 天 |
| 实现 `ArticleReaderPage` 基础版（手动翻句） | 2-3 天 |
| 注册到 DatabaseService，添加基础 CRUD | 0.5 天 |

### 第二阶段：TTS 与跟读

| 任务 | 预估工作量 |
|------|-----------|
| 实现 `TtsService` 逐句朗读 | 2 天 |
| 实现阅读引擎自动播放模式 | 1 天 |
| 实现速度控制 | 0.5 天 |
| 实现跟读面板（录音 + 回放） | 1-2 天 |
| 实现发音评估（初步） | 1-2 天 |

### 第三阶段：单词与测试

| 任务 | 预估工作量 |
|------|-----------|
| 点击单词查询（复用 DeepSeekApi） | 1 天 |
| `WordBookPage` 单词本列表 | 1 天 |
| 单词收藏功能 + 间隔复习 | 2 天 |
| 完形填空测试模式 | 2 天 |
| 听写测试模式 | 1 天 |
| 测试结果统计页面 | 1 天 |

### 第四阶段：AI 增强与优化

| 任务 | 预估工作量 |
|------|-----------|
| DeepSeek 辅助智能分句 | 1 天 |
| DeepSeek 生成选择题 | 1-2 天 |
| 截图 OCR 导入（复用现有 `IosNativeFeatures`） | 1 天 |
| 学习记录对接（StudyRecord 扩展） | 1 天 |
| 性能优化、空状态、错误处理 | 2 天 |

### 总共预估：20-30 人天

---

## 11. 数据模型迁移注意事项

### 11.1 数据库版本升级

当前 `DatabaseService._databaseVersion = 1`，新增表后**无需升级版本**（`DatabaseService` 的 `_ensureTable` 在 `onOpen` 中自动检测缺表并创建）。

### 11.2 现有模型的兼容性

- `Subtitles` 不变，视频功能完全不受影响
- `Participle` 保留，新功能使用 `WordBook`（更灵活：跨来源收藏）
- `StudyRecord` 建议增加 `source_type` / `source_code` 字段（若不做新表）
- `Config` 表无需改动

### 11.3 全文检索

- `ArticleSentence.content` 需启用 FTS5（在注册时设 `enableFullTextSearch: true`）
- 支持句子内容的关键词搜索

---

## 12. 与现有系统的交互关系图

```
                    Article + ArticleSentence
                           ↑
                    ┌──────┴──────┐
                    │             │
              TextProcessor    DeepSeekApi
              (分句+时间轴)    (翻译+测试题)
                    │             │
                    └──────┬──────┘
                           ↓
                 ArticleReaderPage
                    │    │    │
                    │    │    └──→ ArticleTestPage
                    │    │
                    │    └──────→ WordBookPage ↔ WordCard (DeepSeek)
                    │
                    └──────────→ StudyRecord
                           │
                           ↓
                    统计/进度同步
```

---

## 13. 关键风险与解决策略

| 风险 | 影响 | 应对 |
|------|------|------|
| TTS 朗读句间断点不精确 | 体验不流畅 | 句间插入 200ms 停顿 + delegate 回调精准控制 |
| 分句规则对复杂文本不完美 | 分句错误 | 第一阶段用规则，第二阶段引入 DeepSeek AI 分句 |
| iOS TTS 在不同系统版本表现差异 | 速度/音质不一致 | 提供多级速度选项，用户可微调 |
| 长文章 TTS 总时长过长 | 用户耐心不足 | 默认手动翻句模式，TTS 只是辅助选项 |
| 单词本数据量大后性能 | 查询慢 | 分页加载，建立索引 |
| 离线场景 TTS 无法使用 | 功能受限 | 提示需网络，降级为手动阅读 |

---

## 14. 设计决策记录

| 决策 | 选项 | 选择 | 理由 |
|------|------|------|------|
| 底部导航 | 2 tab → 3 tab | 新增"文章"tab | 清晰隔离视频/文章学习模式 |
| 阅读时间轴 | 真实 TTS 时长 vs 估算 | 估算（首版）+ 真实 TTS（后续） | 估算无需预渲染，即时可用 |
| 翻译方案 | DeepSeek vs iOS Native | 首版 DeepSeek，iOS Native 做备选 | DeepSeek 翻译质量更高且可批量 |
| 测试题生成 | 预设规则 vs AI 生成 | 规则（首版）+ AI（后续） | 规则简单可靠，AI 更灵活 |
| 单词本 | 复用 Participle vs 新建 | 新建 WordBook | 跨来源、间隔复习、更丰富字段 |
| 学习记录 | 扩展 StudyRecord vs 新建表 | 扩展 StudyRecord（加字段） | 减少表数，统计统一 |

---

> **下一步建议：**  
> 审阅此设计文档后，确认第一阶段实施的具体范围和优先级，然后开始编码实现。
