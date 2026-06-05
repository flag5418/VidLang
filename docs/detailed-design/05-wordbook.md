# VidLang 详细设计 — 单词本

## 一、跨来源统一单词本

用户在视频/文章/歌曲中收藏的单词存储在同一个 WordBook 表中。

### 1.1 WordBook 模型

```dart
class WordBook extends BaseEntity {
  String word;                  // 单词
  String sourceType;            // 'video' / 'article' / 'music'
  String sourceCode;            // VideoInfo/Article/Song code
  String? sourceTitle;          // 来源标题（缓存，方便展示）
  String? segmentCode;          // 句子/字幕 code
  String contextSentence;       // 上下文句子原文

  // DeepSeek 查询结果（缓存）
  String? definitionsJson;      // 释义 JSON
  String? phoneticUk;           // 英式音标
  String? phoneticUs;           // 美式音标
  String? examplesJson;         // 例句 JSON

  // 学习状态
  int difficulty;               // 难度 1-5
  int reviewCount;              // 复习次数
  int correctCount;             // 答对次数
  DateTime? lastReviewAt;       // 最后复习时间
  DateTime? nextReviewAt;       // 下次复习时间（间隔重复）
  MasteryLevel masteryLevel;    // 掌握程度
}

enum MasteryLevel {
  learning,     // 学习中
  reviewing,    // 复习中
  mastered,     // 已掌握
}
```

### 1.2 收藏入口（各播放器统一）

在 WordCard（单词详情浮层）底部增加"收藏"按钮：

```
┌─────────────────────────────────────┐
│  unprecedented                      │
│  /ʌnˈpresɪdentɪd/    🔊UK  🔊US    │
│                                     │
│  adj. 史无前例的，空前的            │
│                                     │
│  "an unprecedented success"         │
│  空前的成功                         │
│                                     │
│  Source: Climate Change article     │
│  "This warming is unprecedented..." │
│                                     │
│  ☆ [Save to WordBook] [Share]      │ ← 收藏按钮
└─────────────────────────────────────┘
```

## 二、间隔复习系统

### 2.1 复习算法

```
首次收藏 → nextReviewAt = +1天
第1次复习（正确）→ nextReviewAt = +3天
第2次复习（正确）→ nextReviewAt = +7天
第3次复习（正确）→ nextReviewAt = +14天
第4次复习（正确）→ nextReviewAt = +30天

任何一次复习（错误）→ nextReviewAt = +1天（重置）
连续 5 次正确 → masteryLevel = mastered
```

### 2.2 复习界面

在 Words Tab 中以 Swipable Cards 形式展示：

```
┌─────────────────────────────────────┐
│  Word Review (5 remaining)          │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │     unprecedented           │   │ ← 正面：显示单词
│  │                             │   │
│  │   [Tap to reveal]           │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  I know it!  [✓]  Not yet  [✗]     │ ← 自评
│                                     │
│  ← Swipe to next word              │
└─────────────────────────────────────┘
```

点击翻转后展示释义：

```
┌─────────────────────────────────────┐
│  unprecedented                      │
│  /ʌnˈpresɪdentɪd/    🔊UK  🔊US    │
├─────────────────────────────────────┤
│  史无前例的，空前的                  │
│                                     │
│  "an unprecedented success"         │
│  空前的成功                         │
│                                     │
│  From: Climate Change article       │
│  ───────────────────────────────    │
│                                     │
│  [✓ I got it]  [✗ Not yet]         │
└─────────────────────────────────────┘
```
