# VidLang 学习统计分析设计文档

> **版本**: V2.1 | **日期**: 2026-07-22
> **状态**: 当前有效
> **设计范围**: 学习统计首页 + 二级详情页 + 荣誉系统 + AI 分析

---

## 一、页面架构

### 1.1 首页（LearningStatsPage）— 一屏完整

```
┌─────────────────────────────────────────┐
│  ← 学习统计        [ 近7天 ▼ ]          │  ← 顶部固定栏
├─────────────────────────────────────────┤
│  🏆 荣誉墙（横向滚动，12个荣誉卡片）       │  ← 区域1
│  ┌────┐┌────┐┌────┐┌────┐...           │
│  │📹  ││🎵  ││📄  ││🎤  ││📝  ││📚  ││🤖  ││🔥  │
│  │Lv.3││Lv.2││Lv.1││Lv.4││Lv.2││Lv.3││Lv.1││Lv.5│
│  │23/50│12/20│8/20 │156/200│8/50│42/200│5/50│156/365│
│  └────┘└────┘└────┘└────┘...           │
├─────────────────────────────────────────┤
│  📅 2026年7月              >  >         │  ← 区域2：日历墙
│  日  一  二  三  四  五  六             │
│          1   2   3   4   5              │
│          ●   ●●  ●   ●●  ●●             │  ← 微型图标点亮
│  ...                                    │
├─────────────────────────────────────────┤
│  📊 核心指标（点击下钻 → 详细分析页）      │  ← 区域3：2×2卡片
│  ┌───────────┐  ┌───────────┐           │
│  │ ⏱ 学习时长  │  │ 🎤 跟读    │           │
│  │  12h 30m   │  │  156次    │           │
│  │  +23% ↑   │  │  平均78分  │           │
│  └───────────┘  └───────────┘           │
│  ┌───────────┐  ┌───────────┐           │
│  │ 📝 评测    │  │ 📚 单词收藏 │           │
│  │  85分      │  │  42个     │           │
│  │  3次测试   │  │  +5本周   │           │
│  └───────────┘  └───────────┘           │
├─────────────────────────────────────────┤
│  🤖 AI 学习洞察                          │  ← 区域4
│  ┌─────────────────────────────────┐    │
│  │ 📊 习惯分析                      │    │
│  │ 本周学习活跃，但缺少跟读练习。    │    │
│  │ 建议每天跟读 10 句巩固发音。      │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │ 🎬 Friends S01E01               │    │
│  │ 跟读得分偏低(62分)，建议重点     │    │
│  │ 练习第12-15句，近7天已练3次      │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │ 📰 BBC News 0720                │    │
│  │ 评测正确率仅 45%，填空题型薄弱   │    │
│  │ 建议复习该资源字幕后重新测试      │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### 1.2 二级页面（指标详情页）— 统一结构

以"跟读详情"为例，其他指标（时长/评测/单词）结构相同：

```
┌─────────────────────────────────────────┐
│  ← 跟读详情                              │
├─────────────────────────────────────────┤
│  [📈 折线图：周期内每天平均跟读分趋势]      │
├─────────────────────────────────────────┤
│  📊 综合统计                             │
│  • 总跟读次数：156次                      │
│  • 平均分：78分                          │
│  • 最高分：95分                          │
│  • 最低分：52分                          │
├─────────────────────────────────────────┤
│  📚 资源跟读排行（按平均分从低到高）        │
│  ┌─────────────────────────────────┐    │
│  │ 🎬 Friends S01E01               │    │
│  │ 跟读 23次 │ 平均 82分 │ 最高 95分  │    │
│  │ AI: 流利度优秀，注意第12句准确度  │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │ 📰 BBC News 0720                │    │
│  │ 跟读 18次 │ 平均 65分 │ 最高 78分  │    │
│  │ AI: 整体偏低，建议放慢语速练习    │    │
│  └─────────────────────────────────┘    │
├─────────────────────────────────────────┤
│  📈 学习习惯分析                         │
│  • 最佳跟读时段：晚上 8-10点             │
│  • 平均每次跟读 8 句                     │
│  • 周末跟读频率比工作日高 30%            │
└─────────────────────────────────────────┘
```

---

## 二、荣誉墙设计（12 个荣誉）

### 2.1 荣誉配置（云端下发）

| # | 荣誉名称 | 图标(TDesign) | 维度 | Lv.1 | Lv.2 | Lv.3 | Lv.4 | Lv.5 |
|---|---------|--------------|------|------|------|------|------|------|
| 1 | 视频探索者 | `TDIcons.video` | 数量 | 5个 | 20个 | 50个 | 100个 | 200个 |
| 2 | 视频达人 | `TDIcons.film` | 时长 | 1h | 10h | 50h | 100h | 500h |
| 3 | 音频探索者 | `TDIcons.audio` | 数量 | 5个 | 20个 | 50个 | 100个 | 200个 |
| 4 | 音频达人 | `TDIcons.music` | 时长 | 1h | 10h | 50h | 100h | 500h |
| 5 | 文章探索者 | `TDIcons.article` | 数量 | 5篇 | 20篇 | 50篇 | 100篇 | 200篇 |
| 6 | 文章达人 | `TDIcons.book_open` | 时长 | 1h | 10h | 50h | 100h | 500h |
| 7 | 跟读之星 | `TDIcons.microphone` | 次数 | 50次 | 200次 | 500次 | 1000次 | 2000次 |
| 8 | 评测之星 | `TDIcons.fact_check` | 次数 | 10次 | 50次 | 100次 | 300次 | 500次 |
| 9 | 词汇收藏家 | `TDIcons.heart` | 数量 | 50个 | 200个 | 500个 | 1000个 | 2000个 |
| 10 | AI 对话者 | `TDIcons.user_talk` | 次数 | 10次 | 50次 | 100次 | 300次 | 500次 |
| 11 | 学习坚持者 | `TDIcons.calendar` | 天数 | 7天 | 30天 | 100天 | 365天 | 1000天 |
| 12 | 学习时长王 | `TDIcons.time` | 时长 | 10h | 100h | 500h | 1000h | 5000h |

### 2.2 云端配置 JSON 结构

```json
{
  "version": 1,
  "badges": [
    {
      "id": "video_explorer",
      "name": "视频探索者",
      "icon": "video",
      "dimension": "count",
      "resource_type": "video",
      "levels": [
        {"level": 1, "name": "初探", "threshold": 5},
        {"level": 2, "name": "入门", "threshold": 20},
        {"level": 3, "name": "进阶", "threshold": 50},
        {"level": 4, "name": "精通", "threshold": 100},
        {"level": 5, "name": "大师", "threshold": 200}
      ]
    },
    {
      "id": "video_master",
      "name": "视频达人",
      "icon": "film",
      "dimension": "duration",
      "resource_type": "video",
      "levels": [
        {"level": 1, "name": "初探", "threshold": 3600},
        {"level": 2, "name": "入门", "threshold": 36000},
        {"level": 3, "name": "进阶", "threshold": 180000},
        {"level": 4, "name": "精通", "threshold": 360000},
        {"level": 5, "name": "大师", "threshold": 1800000}
      ]
    }
  ]
}
```

### 2.3 荣誉检测逻辑

- **数量维度**：`StudyRecord.resourceCode` 去重计数
- **时长维度**：`StudyRecord.duration` 按 `resourceType` 累加（秒）
- **次数维度**：`RecordingRecord` / `TestSession` / `Conversation` 表计数
- **天数维度**：`StudyRecord.date` 去重计数

---

## 三、日历墙设计

### 3.1 展示规则

- 月历视图，左右滑动切换月份
- 每天格子：日期数字 + 下方微型图标行
- 有数据的日期用主色调高亮背景

### 3.2 微型图标定义

| 图标 | TDesign | 点亮条件 |
|------|---------|---------|
| 学习 | `TDIcons.time` | 当天 `StudyRecord.duration > 0` |
| 跟读 | `TDIcons.microphone` | 当天有 `RecordingRecord` |
| 评测 | `TDIcons.fact_check` | 当天有 `TestSession` |
| 单词 | `TDIcons.heart` | 当天有新增 `word_book` |

### 3.3 点击交互

点击日期 → 底部弹出面板，显示当天详细数据：
- 学习时长
- 跟读次数 + 平均分
- 评测次数 + 平均分
- 单词收藏数

---

## 四、核心指标卡片

### 4.1 四个卡片定义

| 卡片 | 指标 | 显示内容 | 数据来源 |
|------|------|---------|---------|
| 学习时长 | `duration` | 总时长 + 日均时长 + 环比 | `StudyRecord.duration` |
| 跟读 | `follow` | 总次数 + 平均分 + 最佳分 | `RecordingRecord` |
| 评测 | `test` | 平均分 + 测试次数 + 及格率 | `TestSession` |
| 单词收藏 | `word` | 总数 + 本周新增 + 已掌握 | `word_book` |

### 4.2 下钻规则

点击卡片 → 进入对应指标的二级详情页，携带当前时间段参数。

---

## 五、AI 学习洞察设计

### 5.1 技术架构：本地规则引擎 + LLM 增强（分层策略）

> **核心原则**：能用本地规则解决的，不调用 LLM；仅在需要自然语言生成时调用 LLM，且必须带缓存。

```
┌─────────────────────────────────────────────┐
│  首页 AI 建议区域                              │
│  ┌─────────────┐ ┌─────────────┐ ┌────────┐ │
│  │ 习惯分析     │ │ 跟读薄弱    │ │评测薄弱│ │
│  │ (规则引擎)   │ │ (规则引擎)  │ │(规则)  │ │
│  └─────────────┘ └─────────────┘ └────────┘ │
│         ↑ 纯本地 SQL 聚合 + Dart 计算         │
│         ↓ 仅复杂场景触发                      │
│  ┌─────────────────────────────────────────┐ │
│  │  LLM 服务（可选增强层）                  │ │
│  │  • 输入：结构化分析数据                   │ │
│  │  • 输出：自然语言建议文案                 │ │
│  │  • 触发条件：规则引擎标记为「需深度分析」  │ │
│  └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

#### 第一层：本地规则引擎（必选，已实现）

| 分析类别 | 实现方式 | 延迟 | 是否已落地 |
|---------|---------|------|-----------|
| 习惯分析（时段/频率/异常） | SQL 聚合 + Dart 计算 | <50ms | ✅ |
| 薄弱点检测（最低分资源） | SQL ORDER BY + LIMIT | <50ms | ✅ |
| 同期趋势对比 | 双周期查询 + 差值计算 | <100ms | ✅ |
| 建议文案（模板化） | 预定义模板 + 变量替换 | <1ms | ✅ |

**模板化文案示例**：
```dart
// 习惯异常模板
"本周有 {studyDays} 天学习记录，但缺少 {missingActivity} 练习。建议每天 {suggestion}。"

// 薄弱点模板
"《{resourceTitle}》{activity}得分偏低({score}分)，建议 {action}。"
```

#### 第二层：LLM 增强（可选，未来扩展）

**触发条件**（满足任一即触发）：
1. 用户手动点击「刷新建议」按钮
2. 规则引擎检测到「复杂模式」（如连续 3 周期下滑）
3. 用户首次进入页面且本地缓存过期

**输入输出设计**：
```dart
// 输入：结构化数据（非原始记录）
class LlmInsightRequest {
  final String habitSummary;      // "工作日学习多，周末少"
  final String weaknessSummary;   // "跟读平均分65，最低资源Friends S01E01"
  final String trendSummary;      // "较上周期下降12%"
}

// 输出：自然语言建议
class LlmInsightResponse {
  final String habitAdvice;       // "你晚上8-10点跟读得分最高..."
  final String weaknessAdvice;    // "Friends S01E01 第12句准确度低..."
  final String actionPlan;        // "建议本周重点练习..."
}
```

**缓存策略**：
- Key: `ai_insights_{userId}_{timeRange}_{hash(结构化数据)}`
- TTL: 24 小时（同周期不重复调用）
- 降级：LLM 失败时回退到模板文案

### 5.2 分析类别

#### 类别 1：学习习惯分析

- 周期内平均每天学习时长
- 学习时间段分布（早/中/晚/深夜）
- 学习频率（工作日 vs 周末）
- 资源类型偏好占比
- **异常检测**：如"本周只有学习，没有跟读和评测"

#### 类别 2：薄弱点分析

- **跟读薄弱资源**：找周期内跟读平均分最低的资源，分析具体句子
- **评测薄弱资源**：找周期内评测平均分最低的资源，分析薄弱题型
- **同期趋势**：与上个周期对比进步/退步

#### 类别 3：补充建议

基于习惯分析 + 薄弱点分析，生成 actionable 建议：
- "你晚上 8-10 点跟读得分最高，建议把重点资源安排在这个时段"
- "《XXX》连续 3 次测试低于 60 分，建议先降低难度或增加学习时长"

### 5.3 AI 建议卡片结构

首页展示 3 张卡片：
1. **习惯分析卡片**（1 条）
2. **跟读薄弱资源卡片**（1 条，找最差资源）
3. **评测薄弱资源卡片**（1 条，找最差资源）

### 5.4 LLM 调用策略（待决策）

| 维度 | 当前方案 | 未来方案 |
|------|---------|---------|
| 调用时机 | 不使用 LLM | 手动刷新 + 复杂模式自动触发 |
| 调用频率 | 0 次/页面 | ≤1 次/页面（批量生成 3 张卡片） |
| 缓存策略 | 无 | SharedPreferences 24h TTL |
| 失败降级 | 无 | 回退到模板文案 |
| 费用控制 | 无 | 用户主动刷新才调 LLM |

**建议**：当前阶段保持纯规则引擎，待用户量增长后再引入 LLM 增强。规则引擎已能满足 80% 场景。

---

## 六、二级详情页设计

### 6.1 统一页面结构

所有指标详情页采用统一结构：

```
┌─────────────────────────────────────────┐
│  ← {指标名称}详情                        │
├─────────────────────────────────────────┤
│  [趋势图：周期内该指标的变化趋势]          │
├─────────────────────────────────────────┤
│  📊 综合统计（该周期内的汇总数据）          │
├─────────────────────────────────────────┤
│  📚 资源排行（按该指标排序的资源列表）       │
│  └── 每个资源带 AI 简要分析               │
├─────────────────────────────────────────┤
│  📈 学习习惯分析                          │
└─────────────────────────────────────────┘
```

### 6.2 各指标详情页差异

| 指标 | 趋势图 | 综合统计 | 资源排行排序 | AI 分析维度 |
|------|--------|---------|-------------|------------|
| 学习时长 | 柱状图（每天时长） | 总时长/日均/最长单次 | 按总时长降序 | 学习时段偏好 |
| 跟读 | 折线图（每天平均分） | 总次数/平均/最高/最低 | 按平均分升序（突出薄弱） | 句子级薄弱点 |
| 评测 | 折线图（每次得分） | 总次数/平均/及格率 | 按平均分升序 | 题型正确率 |
| 单词 | 柱状图（每天新增） | 总数/本周新增/已掌握 | 按收藏数降序 | 来源分布 |

---

## 七、数据模型

### 7.1 荣誉配置模型（本地缓存）

```dart
class BadgeConfig {
  final String id;
  final String name;
  final String icon;
  final String dimension; // 'count' | 'duration' | 'times' | 'days'
  final String? resourceType; // 'video' | 'music' | 'article' | null
  final List<BadgeLevel> levels;
}

class BadgeLevel {
  final int level;
  final String name;
  final int threshold; // 数量/次数/天数，或秒数（时长）
}
```

### 7.2 用户荣誉进度模型

```dart
class UserBadgeProgress {
  final String badgeId;
  final int currentLevel; // 当前等级（0=未解锁）
  final int currentValue; // 当前进度值
  final int nextThreshold; // 下一级阈值
  final double progress; // 进度百分比（0.0-1.0）
}
```

### 7.3 日历数据模型

```dart
class CalendarDayData {
  final String date; // ISO8601 yyyy-MM-dd
  final int durationSeconds; // 学习时长
  final int followCount; // 跟读次数
  final int testCount; // 评测次数
  final int wordCount; // 单词收藏数
}
```

### 7.4 AI 建议模型

```dart
class AiInsight {
  final String type; // 'habit' | 'follow_weakness' | 'test_weakness'
  final String title;
  final String description;
  final String? resourceCode; // 关联资源（薄弱点类型）
  final String? resourceTitle;
}
```

---

## 八、服务层接口

### 8.1 LearningStatsService 新增接口

```dart
// 荣誉系统
Future<List<BadgeConfig>> fetchBadgeConfigs(); // 从云端拉取
Future<List<UserBadgeProgress>> calculateBadgeProgress(String timeRange);

// 日历数据
Future<List<CalendarDayData>> getCalendarData(int year, int month);

// 核心指标
Future<DurationMetrics> getDurationMetrics(String timeRange);
Future<FollowMetrics> getFollowMetrics(String timeRange);
Future<TestMetrics> getTestMetrics(String timeRange);
Future<WordMetrics> getWordMetrics(String timeRange);

// AI 建议
Future<List<AiInsight>> generateAiInsights(String timeRange);

// 二级页面数据
Future<List<ResourceDurationDetail>> getResourceDurationRanking(String timeRange);
Future<List<ResourceFollowDetail>> getResourceFollowRanking(String timeRange);
Future<List<ResourceTestDetail>> getResourceTestRanking(String timeRange);

// 学习习惯
Future<LearningHabitAnalysis> analyzeLearningHabits(String timeRange);
```

---

## 九、文件清单

### 9.1 页面文件

| 文件 | 说明 |
|------|------|
| `lib/views/profile/learning_stats_page.dart` | 学习统计首页 |
| `lib/views/profile/widgets/duration_detail_page.dart` | 学习时长详情页 |
| `lib/views/profile/widgets/follow_detail_page.dart` | 跟读详情页 |
| `lib/views/profile/widgets/test_detail_page.dart` | 评测详情页 |
| `lib/views/profile/widgets/word_detail_page.dart` | 单词收藏详情页 |

### 9.2 服务层文件

| 文件 | 说明 |
|------|------|
| `lib/services/learning/learning_stats_service.dart` | 统一学习统计服务（含数据模型） |

---

## 十、实现计划

### Phase 1：数据层 ✅
1. 新增荣誉配置模型和本地缓存
2. 实现 LearningStatsService 数据查询方法
3. 实现云端配置拉取

### Phase 2：首页 UI ✅
1. 荣誉墙横向滚动组件
2. 日历墙组件（支持滑动切月）
3. 核心指标卡片（2×2，点击可下钻）
4. AI 建议区域

### Phase 3：二级页面 ✅
1. 统一详情页框架
2. 时长详情页（DurationDetailPage）
3. 跟读详情页（FollowDetailPage）
4. 评测详情页（TestDetailPage）
5. 单词详情页（WordDetailPage）

### Phase 4：AI 分析 ✅
1. 习惯分析规则引擎
2. 薄弱点检测算法
3. 建议生成器

---

## 十一、变更记录

### V2.1 (2026-07-22)
- **调整**：荣誉阈值校准（学习时长王 Lv5 从 5000h→2000h，视频/音频/文章达人 Lv5 从 500h→300h，学习坚持者 Lv5 从 1000天→730天）
- **移除**：`ai_talker` 荣誉（ConversationRecord 实体未注册，暂禁用）
- **文档**：补充 AI/LLM 调用策略分层架构（本地规则引擎 + 可选 LLM 增强）

### V2.0 (2026-07-22)
- **新增**：4 个二级详情页（时长/跟读/评测/单词）
- **调整**：首页核心指标卡片支持点击跳转对应详情页
- **移除**：综合评分卡片的等级标签（优秀/良好/入门/新手）
- **优化**：荣誉系统扩展至 12 个，引入时间维度
- **优化**：AI 分析增加薄弱点分析和针对性建议

---

## 十二、需要手动处理的逻辑

1. **云端荣誉配置表**：需要在 Supabase 创建 `badge_configs` 表或 Edge Function
2. **AI 对话次数统计**：当前 `conversation_session` 表是否有学习时长/次数记录？
3. **单词收藏"当天新增"**：需要按 `created_at` 日期分组查询
4. **日历数据性能**：整月数据建议一次性查询，避免 30 次单天查询
5. **环比计算**：需要缓存上个周期的数据，或每次查询两个周期
6. **资源标题解析**：二级页面中资源排行目前显示 resourceCode，需接入 `_resolveResourceTitle` 获取真实标题
