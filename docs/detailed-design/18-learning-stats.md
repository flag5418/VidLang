# VidLang 详细设计 — 学习统计体系

> 版本：v1.0  
> 更新日期：2026-06-13  
> 设计范围：学习天数 / 学习时长 / 学习记录排序 / 日历打卡 / 成就系统 / 测试错误分析 / AI 学习建议

---

## 一、现状诊断

### 1.1 已有基础

| 组件 | 状态 | 说明 |
|------|------|------|
| `StudyRecord` 模型 | ✅ 已存在 | 字段完备（resourceCode/type/duration/testScore等） |
| `StatsService` | ✅ 已存在 | 首页统计（streak/今日时长/生词数/已学资源数） |
| `HomePage` | ✅ 已存在 | 展示统计卡片 + 各类型资源列表 |
| `LearningStatsPage` | ✅ 骨架存在 | 有 Tab 切换（总览/视频/音频/文章），全是占位 0 |
| `WordBook` | ✅ 已存在 | 来源追踪完善（sourceType/sourceCode/sourceTitle） |
| `RecordingRecord` | ✅ 已存在 | 跟读评分记录 |
| `TestPage` | ✅ 已存在 | 题型配置 + AI 生成题目 |
| `ConversationMessage` | ✅ 已存在 | AI 对话消息模型 |

### 1.2 当前缺口

| # | 缺口 | 详细说明 |
|---|------|---------|
| 1 | **学习天数不完整** | `StatsService.calculateStreakDays()` 仅基于 `StudyRecord.date`，但 AI 对话、打开程序、单词本复习等行为没有写入 `StudyRecord`，无法计入"今天已学习" |
| 2 | **今日学习时长不完整** | 仅统计 `StudyRecord.duration`，AI 对话、单词本学习的时间没有被追踪 |
| 3 | **首页排序单一** | 用 `VideoFolder.lastPlayDate` 排序，文章/音频的播放记录未必写入，且未按最后学习时间统一倒序 |
| 4 | **学习统计页面** | 全是占位 0，没有任何真实数据的查询 |
| 5 | **日历打卡** | 无 |
| 6 | **成就系统** | 完全空白 |
| 7 | **测试错误统计** | 测试结果未持久化，无法分析薄弱点 |
| 8 | **AI 学习建议** | 无 |

---

## 二、核心设计决策

### 2.1 引入统一的 `learning_activity` 表

**问题**：现有 `StudyRecord` 只覆盖"进入播放页→退出"这一种行为。AI 对话、查词、单词本复习、打开程序等行为没有地方记录。

**方案**：新增 `learning_activity` 作为**统一的、轻量级的学习活动日志表**，每一个"学习动作"都写一条记录。

```
learning_activity（学习活动日志）
       │
       ├── 视频播放（退出播放器时写入）
       ├── 音频播放（退出播放器时写入）
       ├── 文章阅读（退出阅读器时写入）
       ├── AI 对话（结束对话时写入）
       ├── 跟读练习（完成跟读时写入）
       ├── 测试（完成测试时写入）
       ├── 查词（收藏单词时写入）
       ├── 单词复习（结束复习时写入）
       ├── 导入内容（导入完成时写入）
       └── 打开程序（App 进入前台时写入）
```

所有统计（学习天数、时长、日历、成就触发判断）统一从 `learning_activity` 聚合。

---

## 三、数据模型设计

### 3.1 新增表：`learning_activity`

```dart
/// 学习活动类型枚举
enum LearningActivityType {
  openApp,         // 打开程序
  playVideo,       // 播放视频
  playAudio,       // 播放音频
  readArticle,     // 阅读文章
  aiConversation,  // AI 对话
  followRead,      // 跟读练习
  test,            // 测试
  wordLookup,      // 查词
  wordReview,      // 单词复习
  importContent,   // 导入内容
}

/// 学习活动日志实体
class LearningActivity extends BaseEntity {
  /// 活动类型
  String activityType;

  /// 资源类型：video / article / music / null
  String? resourceType;

  /// 资源 code
  String? resourceCode;

  /// 资源标题（缓存展示用）
  String? resourceTitle;

  /// 所属文件夹 code
  String? folderCode;

  /// 活动时长（秒）
  int durationSeconds;

  /// 扩展信息 JSON，按活动类型存储不同字段
  /// 示例：
  /// - test: {"testScore":85, "totalQuestions":10, "correctCount":8}
  /// - aiConversation: {"rounds":5, "model":"qwen"}
  /// - followRead: {"overallScore":92, "scope":"sentence"}
  /// - wordReview: {"reviewCount":10, "correctCount":7}
  String? metadataJson;

  /// 活动开始时间
  DateTime startedAt;

  /// 活动结束时间
  DateTime? endedAt;

  /// 日期（分区字段，便于按天查询和统计）
  DateTime date;

  /// 是否计入学习天数统计
  /// open_app 类型默认为 true，其他类型仅当时长 >= 30 秒或活动确有成果时计入
  bool countsAsLearning;
}
```

**SQL 建表语句：**

```sql
CREATE TABLE IF NOT EXISTS learning_activity (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL,
  user_code TEXT,
  activity_type TEXT NOT NULL DEFAULT '',
  resource_type TEXT,
  resource_code TEXT,
  resource_title TEXT,
  folder_code TEXT,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  metadata_json TEXT,
  started_at TEXT NOT NULL,
  ended_at TEXT,
  date TEXT NOT NULL,
  counts_as_learning INTEGER NOT NULL DEFAULT 1,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_by TEXT,
  updated_by TEXT,
  deleted_by TEXT
);

CREATE INDEX IF NOT EXISTS idx_learning_activity_date
  ON learning_activity(date, activity_type);
CREATE INDEX IF NOT EXISTS idx_learning_activity_resource
  ON learning_activity(resource_type, resource_code);
```

### 3.2 `StudyRecord` 的去留

`StudyRecord` **保留**，用于视频/音频播放的详细进度记录（播放位置、字幕进度等精细数据）。`learning_activity` 是其上一层抽象，记录"用户做了一次什么学习活动"。

```
learning_activity   ← 统计、日历、成就的数据源（聚合层）
       │
       └── StudyRecord  ← 视频/音频播放进度细节（详情层）
```

### 3.3 注册到 main.dart

```dart
DatabaseService.registerEntities({
  // ... 现有注册保持不变 ...
  'learning_activity': EntityConfig(
    creator: () => LearningActivity(),
    description: '学习活动日志表',
  ),
});
```

---

## 四、"今天已学习"的定义

### 4.1 判断标准

> 当日至少有一条 `learning_activity` 记录，且 `counts_as_learning = true`

### 4.2 `counts_as_learning` 的判定规则

| activityType | 条件 | countsAsLearning |
|-------------|------|:---:|
| `open_app` | 当日首次打开（去重） | `true` |
| `play_video` | 播放时长 ≥ 30 秒 | `true` |
| `play_audio` | 播放时长 ≥ 30 秒 | `true` |
| `read_article` | 阅读时长 ≥ 30 秒 | `true` |
| `ai_conversation` | 有任意对话发生 | `true` |
| `follow_read` | 完成一次跟读 | `true` |
| `test` | 完成一次测试 | `true` |
| `word_lookup` | 查词 ≥ 1 个 | `true` |
| `word_review` | 复习 ≥ 3 个词 | `true` |
| `import_content` | 导入内容 | `true` |
| 任何类型 | 时长 < 30 秒且非成果型活动 | `false` |

### 4.3 参考案例

多邻国（Duolingo）的定义：
- 完成至少一堂课
- 至少花费 X 分钟
- 任意形式的互动（故事、练习、听力等）

我们的定义更宽松：**只要用户打开 app 就算今天学习了**，这符合"鼓励用户每日打开"的产品目标。

---

## 五、今日学习时长

### 5.1 计算公式

```
今日学习时长 = Σ learning_activity.duration_seconds
               WHERE date = 今天
               AND activity_type IN (
                 play_video, play_audio, read_article,
                 ai_conversation, follow_read, test, word_review
               )
```

### 5.2 按资源类型细分

```
今日视频时长 = Σ duration_seconds WHERE activity_type = 'play_video' AND date = 今天
今日音频时长 = Σ duration_seconds WHERE activity_type = 'play_audio' AND date = 今天
今日文章时长 = Σ duration_seconds WHERE activity_type = 'read_article' AND date = 今天
今日其他时长 = Σ duration_seconds WHERE activity_type IN (ai_conversation, follow_read, test, word_review) AND date = 今天
```

### 5.3 首页展示

```
┌──────────────────────────────────────┐
│  Today's Learning                    │
│  🎬 12min  🎵 8min  📖 5min        │
│  📝 Quiz 85%  ☆ 5 new words        │
│  ⏱ Total: 25min                    │
└──────────────────────────────────────┘
```

---

## 六、学习记录排序

### 6.1 首页"继续学习"区域

取每个 `(resource_type, resource_code)` 最新的一条 `learning_activity.started_at`，按时间倒序排列。

```sql
SELECT resource_type, resource_code, resource_title,
       MAX(started_at) AS last_studied_at
FROM learning_activity
WHERE resource_code IS NOT NULL
  AND resource_type IS NOT NULL
  AND is_deleted = 0
GROUP BY resource_type, resource_code
ORDER BY last_studied_at DESC
LIMIT 10
```

### 6.2 展示效果

```
Continue Learning                     ← "继续学习" 区域

┌──────────────────────────────────┐
│ 🎬 Friends S01E01     2h ago    │  ← 最后学习时间倒序
│ ████████░░░░░░ 45%              │
└──────────────────────────────────┘
┌──────────────────────────────────┐
│ 📖 Climate Change      5h ago   │
│ ███░░░░░░░░░░░░ 20%             │
└──────────────────────────────────┘
┌──────────────────────────────────┐
│ 🎵 Let It Be          1d ago    │
│ ████████████░░ 60%              │
└──────────────────────────────────┘
```

---

## 七、日历打卡

### 7.1 数据结构

从 `learning_activity` 按月聚合：

```
月视图数据 = {
  "2026-06-01": { learned: true,  totalDuration: 3600, activities: [...] },
  "2026-06-02": { learned: true,  totalDuration: 1800, activities: [...] },
  "2026-06-03": { learned: false, totalDuration: 0,    activities: [] },
  ...
}
```

### 7.2 UI 设计

```
📅 June 2026
 Mon  Tue  Wed  Thu  Fri  Sat  Sun
       1    2    3    4    5    6
  ✓    ✓    ·    ✓    ✓    ·    ·
 1h   30m       45m  2h

 7    8    9    10   11   12   13
 ✓    ✓    ✓    ✓    ✓   🔥   ·
30m   1h   20m  15m  3h   今天

图例：
  ✓ = 已学习（显示时长）
  · = 未学习
  🔥 = 今日
```

### 7.3 点击某日 → 详情

```
日期：2026-06-12（周四）
──────────────────────────
🎬 播放视频    Friends S01E01    45分钟
📖 阅读文章    Climate Change    20分钟
📝 跟读练习    5次  最佳分 92%
🎯 完成测试    85分  10题对8
🆕 收藏单词    3个
──────────────────────────
总计：1小时10分钟
```

---

## 八、成就系统

### 8.1 成就存储

本地 `config` 表中存 JSON（key: `achievements`）：

```json
{
  "unlocked": {
    "first_learn": "2026-06-01T10:00:00",
    "streak_3": "2026-06-03T10:00:00",
    "words_10": "2026-06-05T14:00:00"
  },
  "progress": {
    "streak_7": 5,
    "total_1h": 2700
  }
}
```

### 8.2 成就体系

```
🏆 初次成就
├── first_learn              首次学习
├── first_video_complete     首个视频学完
├── first_article_complete   首篇文章读完
├── first_song_complete      首支歌曲学完
├── first_follow             首次跟读
├── first_conversation       首次 AI 对话
└── first_test               首次测试

🔥 连续学习
├── streak_3                 连续学习 3 天
├── streak_7                 连续学习 7 天
├── streak_14                连续学习 14 天
├── streak_30                连续学习 30 天
├── streak_60                连续学习 60 天
└── streak_100               连续学习 100 天

⏱ 时长里程碑
├── total_1h                 累计学习 1 小时
├── total_10h                累计学习 10 小时
├── total_50h                累计学习 50 小时
├── total_100h               累计学习 100 小时
└── total_500h               累计学习 500 小时

📝 词汇
├── words_10                 收集 10 个单词
├── words_50                 收集 50 个单词
├── words_100                收集 100 个单词
├── words_500                收集 500 个单词
├── mastered_20              掌握 20 个单词
└── mastered_50              掌握 50 个单词

🎯 测试
├── tests_10                 完成 10 次测试
├── tests_50                 完成 50 次测试
├── perfect_test             首次满分
├── avg_score_80             近 10 次平均分 ≥ 80
└── avg_score_90             近 10 次平均分 ≥ 90

🎤 口语
├── follow_10                完成 10 次跟读
├── follow_50                完成 50 次跟读
├── follow_100               完成 100 次跟读
├── pron_90                  首次发音评分 ≥ 90
└── pron_95                  首次发音评分 ≥ 95
```

### 8.3 成就检查时机

每次写入 `learning_activity` 后，异步调用 `AchievementService.check()` 检查是否能解锁新成就。

### 8.4 成就 UI

```
🏆 成就
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐
│ 🔥7天 │ │ 📝50词│ │ 🎯10测│ │ ⏱10h │  ← 已解锁（彩色）
└──────┘ └──────┘ └──────┘ └──────┘
┌──────┐ ┌──────┐
│ 🔥30天│ │ 📝100│                                 ← 未解锁（灰色 + 进度条）
│ ██░░  │ │ █░░░ │
└──────┘ └──────┘
```

---

## 九、测试错误统计 + AI 学习建议

### 9.1 测试结果持久化

在 `metadata_json` 中记录每次测试的详细结果：

```json
{
  "testType": "unit",
  "resourceType": "video",
  "resourceCode": "xxx",
  "resourceTitle": "Friends S01E01",
  "totalQuestions": 10,
  "correctCount": 7,
  "score": 70,
  "durationSeconds": 480,
  "items": [
    {
      "type": "spelling",
      "prompt": "The ___ is blue.",
      "answerKey": "sky",
      "userAnswer": "ski",
      "isCorrect": false,
      "word": "sky",
      "errorType": "spelling"
    },
    {
      "type": "mcq",
      "prompt": "What does 'ubiquitous' mean?",
      "answerKey": "everywhere",
      "userAnswer": "rare",
      "isCorrect": false,
      "word": "ubiquitous",
      "errorType": "word_confusion"
    }
  ]
}
```

### 9.2 错误聚合分析

```sql
-- 错误最多的单词 Top 10
-- 从 learning_activity.metadata_json 中提取

-- 错误类型分布
-- spelling vs word_confusion vs grammar vs pronunciation

-- 各题型正确率趋势
-- 近 10 次测试的 spelling/reorder/mcq 正确率变化
```

### 9.3 AI 学习建议流程

```
用户完成一次测试
    ↓
客户端收集本次错题（上限 20 条）
    + 近 10 次测试的历史错误统计
    ↓
调用 ai-proxy Edge Function（rule_code: ai_study_advice）
    ↓
AI 接收上下文：
  1. 本次测试结果（题型分布、正确率、错题详情）
  2. 近 10 次错误趋势
  3. 用户当前已收集的生词列表（Top 50）
    ↓
AI 分析输出：
  1. 薄弱环节总结（"你的拼写错误占 60%，尤其元音字母混淆较多"）
  2. 针对性建议（"建议重点复习以下 5 个单词：sky, receive, ..."）
  3. 学习策略（"建议先从填空练习开始，再过渡到组句"）
  4. 推荐主题（"以下是 AI 为你生成的 3 个参考练习主题："）
    ↓
返回结构化 JSON
    ↓
展示在测试结果页 + 学习统计页 "AI 建议" 入口
```

### 9.4 AI 建议返回格式

```json
{
  "ok": true,
  "advice": {
    "summary": "Your spelling accuracy has been declining over the last 3 tests (80% → 65%). Vowel confusion is the main issue.",
    "weak_points": [
      {"area": "spelling", "accuracy": 0.60, "trend": "declining"},
      {"area": "word_confusion", "accuracy": 0.75, "trend": "stable"}
    ],
    "recommended_words": ["sky", "receive", "believe", "separate", "necessary"],
    "strategy": "Start with spelling drills for the 5 recommended words, then do a mixed review test.",
    "suggested_topics": [
      {"title": "Commonly Misspelled Words", "description": "Focus on ie/ei rules and silent letters."},
      {"title": "Homophone Distinction", "description": "Practice distinguishing words that sound alike but are spelled differently."}
    ]
  }
}
```

---

## 十、活动写入时机（埋点规划）

| 位置 | activityType | 写入时机 | 时长来源 |
|------|-------------|---------|---------|
| App 生命周期 `didChangeAppLifecycleState` | `open_app` | App 进入前台，当日首次 | 0 |
| `PlayerPage.dispose()` | `play_video` / `play_audio` | 退出播放器 | 播放器实际播放时长 |
| `ArticleReaderPage.dispose()` | `read_article` | 退出阅读器 | 阅读页面停留时长 |
| `ConversationPage` 对话结束 | `ai_conversation` | 用户主动结束或超时 | 对话持续时间 |
| 跟读面板完成评分 | `follow_read` | 录音评分完成 | 录音时长 |
| `TestPage._TestRunPage` 完成 | `test` | 完成全部题目 | 测试总用时 |
| `WordBookService` 收藏单词 | `word_lookup` | 收藏成功时 | 0 |
| `WordBookPage` 复习结束 | `word_review` | 退出复习模式 | 复习会话时长 |
| `FileProvider` 导入完成 | `import_content` | 文件夹导入成功 | 0 |

### 注意事项

1. **去重**：`open_app` 当日仅写入一次（检查 `learning_activity WHERE date = 今天 AND activity_type = 'open_app'`）
2. **最短时长**：`play_video`/`play_audio`/`read_article` 低于 30 秒不写入（用户可能误操作快速退出）
3. **异步写入**：所有 `recordActivity()` 调用均为异步，不阻塞 UI

---

## 十一、服务层设计

### 11.1 `LearningStatsService`（替代现有 `StatsService`）

```dart
class LearningStatsService {
  /// 写入一条活动日志
  static Future<void> recordActivity({...});

  /// 今天是否学习过
  static Future<bool> isTodayLearned();

  /// 连续学习天数
  static Future<int> getStreakDays();

  /// 今日总学习时长（秒）
  static Future<int> getTodayDuration();

  /// 今日各类型学习时长
  static Future<Map<String, int>> getTodayDurationByType();

  /// 获取某月日历打卡数据
  static Future<Map<String, DayStats>> getCalendarData(int year, int month);

  /// 获取某天的学习详情
  static Future<List<LearningActivity>> getDayDetail(DateTime date);

  /// 获取最近学习的资源列表（按最后学习时间倒序）
  static Future<List<RecentResource>> getRecentResources({int limit = 10});

  /// 各资源大类汇总统计
  static Future<ResourceTypeStats> getResourceTypeStats();

  /// 单个资源学习统计
  static Future<ResourceDetailStats> getResourceDetailStats(String resourceType, String resourceCode);

  /// 测试错误统计
  static Future<TestErrorStats> getTestErrorStats();

  /// 成就列表
  static Future<AchievementData> getAchievements();
}
```

### 11.2 `AchievementService`

```dart
class AchievementService {
  /// 定义所有成就的规则
  static final List<AchievementRule> rules = [...];

  /// 检查是否能解锁新成就
  static Future<List<AchievementRule>> check();
}
```

---

## 十二、页面升级计划

### 12.1 `LearningStatsPage`（重写）

原页面全部为占位数据，需完全重写为真实数据。

```
┌─────────────────────────────────────────┐
│  ← 学习统计                  [💡 AI建议]│
├─────────────────────────────────────────┤
│                                         │
│  🔥 连续 5 天    ⏱ 总时长 12h 35m      │
│                                         │
├─────────────────────────────────────────┤
│  [总览] [视频] [音频] [文章] [测试]     │
├─────────────────────────────────────────┤
│                                         │
│  📅 学习日历                             │
│  ┌──┬──┬──┬──┬──┬──┬──┐                │
│  │一│二│三│四│五│六│日│                │
│  ├──┼──┼──┼──┼──┼──┼──┤                │
│  │  │  │✓ │✓ │✓ │✓ │· │                │
│  │  │  │1h│30│45│2h│  │                │
│  └──┴──┴──┴──┴──┴──┴──┘                │
│                                         │
│  📊 学习趋势（近7天）                     │
│  ██  ████  ██  █████  █  ██  ████      │
│                                         │
│  🏆 成就                                 │
│  [🔥7天] [📝50词] [🎯10测] [⏱10h]      │
│  ─ ─ ─ 未解锁 ─ ─ ─                     │
│  [🔥30天 ██░░]  [📝100 █░░░]            │
│                                         │
│  📋 最近学习                              │
│  🎬 Friends S01E01      昨天  45min      │
│  📖 Climate Change      前天  20min      │
│  🎵 Let It Be          3天前  15min      │
│                                         │
│  📈 学习分布                              │
│  🎬 视频   60% ████████████             │
│  🎵 音频   25% █████                    │
│  📖 文章   15% ███                      │
└─────────────────────────────────────────┘
```

### 12.2 测试错误分析页（新增）

```
┌─────────────────────────────────────────┐
│  ← 测试分析                              │
├─────────────────────────────────────────┤
│                                         │
│  总体正确率：75%（近10次）               │
│  ┌────────────────────────────┐         │
│  │ 拼写    60% ████████░░     │         │
│  │ 选择    85% █████████████  │         │
│  │ 组句    70% █████████░░░   │         │
│  └────────────────────────────┘         │
│                                         │
│  📉 趋势                                 │
│  测试1  80% ████████                    │
│  测试2  75% ███████                     │
│  测试3  70% ██████                      │
│                                         │
│  ❌ 高频错误词                            │
│  sky      ×3次                          │
│  receive  ×2次                          │
│  believe  ×2次                          │
│                                         │
│  ┌────────────────────────────┐         │
│  │ 💡 AI 学习建议              │         │
│  │                             │         │
│  │ 你的拼写准确率持续下降，      │         │
│  │ 尤其元音混淆较多。            │         │
│  │ 建议重点复习这5个单词...      │         │
│  │                             │         │
│  │ [查看详细建议]               │         │
│  └────────────────────────────┘         │
└─────────────────────────────────────────┘
```

### 12.3 AI 学习建议页（新增）

```
┌─────────────────────────────────────────┐
│  ← AI 学习建议                           │
├─────────────────────────────────────────┤
│                                         │
│  📊 总体评估                              │
│  过去10次测试中，你的拼写准确率从80%      │
│  下降至65%。元音混淆是最主要的问题。       │
│                                         │
│  🎯 薄弱环节                              │
│  · 拼写（准确率 60%，↓ 趋势）             │
│  · 词汇混淆（准确率 75%，→ 稳定）         │
│                                         │
│  📝 建议重点复习的单词                     │
│  sky / receive / believe / separate      │
│                                         │
│  💡 学习策略                              │
│  建议先从填空练习开始，针对这5个单词      │
│  做专项训练，再进行综合复习测试。          │
│                                         │
│  🔖 AI 推荐练习主题                       │
│  · Commonly Misspelled Words             │
│  · Homophone Distinction                 │
│                                         │
│  [开始针对性练习]                         │
└─────────────────────────────────────────┘
```

---

## 十三、实施分期

### 第一期：核心统计打通

| # | 任务 | 涉及文件 |
|---|------|---------|
| 1 | 新增 `LearningActivity` 模型 | `lib/models/learning_activity.dart` |
| 2 | 注册到 `DatabaseService` | `lib/main.dart` |
| 3 | 升级 `StatsService` → `LearningStatsService` | `lib/services/learning_stats_service.dart` |
| 4 | 在关键位置插入 `recordActivity()` | `PlayerPage`, `TestPage`, `ConversationPage`, `WordBookService`, App 生命周期 |
| 5 | 重写 `LearningStatsPage`（总览 + 日历 + 最近学习） | `lib/views/profile/learning_stats_page.dart` |
| 6 | 首页"继续学习"改为从 `learning_activity` 聚合 | `lib/views/home/home_page.dart` |

### 第二期：成就 + 日历

| # | 任务 | 涉及文件 |
|---|------|---------|
| 7 | `AchievementService` 实现 | `lib/services/achievement_service.dart` |
| 8 | 成就 UI | `LearningStatsPage` 中新增成就区块 |
| 9 | 日历打卡详情页 | 新增 `DayDetailPage` 或 Dialog |
| 10 | 学习趋势图（简易柱状图） | `LearningStatsPage` 中新增趋势区块 |

### 第三期：测试分析 + AI 建议

| # | 任务 | 涉及文件 |
|---|------|---------|
| 11 | 测试结果 `metadata` 完善 | `TestPage._TestRunPage` |
| 12 | `ai_study_advice` Edge Function | `supabase/functions/ai-study-advice/` |
| 13 | 测试错误分析页 | 新增 `lib/views/profile/test_analysis_page.dart` |
| 14 | AI 学习建议页 | 新增 `lib/views/profile/ai_advice_page.dart` |

---

## 十四、与现有代码的融合点汇总

| 现有位置 | 变更内容 |
|---------|---------|
| `lib/main.dart` | 注册 `learning_activity` 实体，App 生命周期监听写入 `open_app` |
| `lib/models/study_record.dart` | 保持不变，作为播放详情层 |
| `lib/services/stats_service.dart` | 重构为 `learning_stats_service.dart`，所有统计从 `learning_activity` 驱动 |
| `lib/views/home/home_page.dart` | "继续学习"区域排序改为从 `learning_activity` 聚合；统计卡片对接新服务 |
| `lib/views/player/player_page.dart` | `dispose()` 时写入 `play_video` 活动 |
| `lib/views/test/test_page.dart` | `_TestRunPage` 完成时写入 `test` 活动 + 错题 metadata |
| `lib/views/conversation/conversation_page.dart` | 对话结束时写入 `ai_conversation` 活动 |
| `lib/services/word_book_service.dart` | 收藏单词时写入 `word_lookup` 活动 |
| `lib/views/word_book/word_book_page.dart` | 退出复习模式时写入 `word_review` 活动 |
| `lib/providers/file_provider.dart` | `createStudyRecord`/`completeStudyRecord` 改为同时写 `learning_activity` |
| `lib/views/profile/learning_stats_page.dart` | 完全重写，对接 `LearningStatsService` |

---

## 十五、关键设计原则

1. **一个数据源** — 所有统计（天数、时长、日历、成就）统一从 `learning_activity` 聚合，避免多表不一致
2. **异步写入** — 所有 `recordActivity()` 调用不阻塞 UI，静默失败不影响主功能
3. **宽松定义** — "今天已学习"的门槛很低（打开 app 就算），鼓励用户保持习惯
4. **渐进增强** — 分三期实施，核心统计先打通，成就和 AI 建议后续迭代
5. **可扩展** — `metadata_json` 字段支持各种活动类型自由扩展，不需要改表结构
