# VidLang 详细设计 — 学习统计体系 v2.0

> 版本：v2.0
> 更新日期：2026-06-28
> 变更说明：基于代码现实审查，重新设计统一学习记录机制。核心变更：(1) 复用 StudyRecord 替代新建 learning_activity 表；(2) 引入 LearningStatsService 统一服务层；(3) 修复时长计算 Bug；(4) 统一测试入口 TestScope；(5) 字幕云存储按文件夹组织。
> 设计范围：学习时长准确记录 / 统一会话管理 / 跟读&测试指标归集 / 测试体系（单元/综合/生词本） / 字幕云存储 / 连续学习天数 / 学习趋势

---

## 一、现状诊断（v1.0 → v2.0 审查结论）

### 1.1 已有基础

| 组件 | 状态 | v2.0 结论 |
|------|------|-----------|
| `StudyRecord` 模型 | ✅ 字段完备 | **复用为主**，补齐字段写入逻辑 |
| `StatsService` | ✅ 首页统计存在 | **重构为 `LearningStatsService`**，统一数据源 |
| `RecordingRecord` | ✅ 跟读评分明细 | **保持不变**，作为跟读详情层 |
| `TestSession` / `TestItem` | ✅ 测试主表+题目表 | **保持不变**，作为测试详情层 |
| `VideoInfo.lastFollowScore` | ✅ 缓存字段 | **收口到统一服务自动更新** |
| `PlayerEngineNotifier` | ⚠️ 时长计算 Bug | **修复**：position → 实际停留时间 |

### 1.2 v1.0 设计 vs 代码现实的差距

| # | v1.0 设计 | 代码现实 | v2.0 决策 |
|---|----------|---------|-----------|
| 1 | 新建 `learning_activity` 表 | 未实现，且 `StudyRecord` 已有相同字段 | **复用 `StudyRecord`**，避免空转和迁移风险 |
| 2 | 时长 ≥ 30s 才计入 | 无此门槛代码，且用户明确表示"1s 也合理" | **取消最小时长门槛**，打开即计时 |
| 3 | 文章延迟 30s 创建记录 | 代码中有此逻辑（`_articleTimer`） | **取消延迟**，统一为打开即 `beginSession` |
| 4 | 时长 = 播放器实际播放时长 | ❌ Bug：用的 `state.position`（播放位置） | **修复为 `now - startTime`**（实际停留时间） |
| 5 | `testScore` / `bestFollowScore` 写入 | 字段存在但**从未被写入**（`completeStudyRecord` 只写 duration） | **补齐写入逻辑** |
| 6 | 测试结果按资源归属 | `_recordWordResult` 只记了 `wordBookCode`，未关联 `resourceCode` | **补充 `source_video_code` 归属链路** |
| 7 | 单元测试 vs 综合测试分离 | 两者共用同一个 `TestPage`，仅 `videoCode` 不同 | **引入 `TestScope` 枚举**区分三种模式 |

---

## 二、核心设计决策

### 2.1 数据分层：汇总层 + 详情层

```
┌─────────────────────────────────────────────────────┐
│                  汇总层（用于 UI 渲染 & 统计）         │
│                                                     │
│   StudyRecord（每个资源一次学习会话的汇总）            │
│   ├── resourceCode, resourceType, folderCode        │
│   ├── duration（学习时长：实际停留秒数）               │
│   ├── bestFollowScore（最佳跟读分）                   │
│   ├── testScore（测试得分）                          │
│   ├── followCount（跟读次数）                         │
│   └── startTime, endTime, date                      │
│                                                     │
├─────────────────────────────────────────────────────┤
│                  详情层（用于回溯分析）                 │
│                                                     │
│   RecordingRecord（每次跟读的详细录音+评分）           │
│   TestSession + TestItem（每次测试的会话+逐题）       │
│   Subtitles（字幕内容）                              │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**原则**：
- **汇总层** (`StudyRecord`)：回答"这个资源学了多久、跟读最好多少分、测试得多少分"。用于列表页展示、统计聚合。
- **详情层** (`RecordingRecord` / `TestItem`)：回答"哪一句跟读了多少分、哪道题答错了"。用于学习分析、错误归因。
- **两者通过 `resourceCode` 关联**，由 `LearningStatsService` 统一协调写入。

### 2.2 统一会话管理（Session）

所有学习行为（视频/音频/文章播放、测试）都纳入统一的会话生命周期：

```
beginSession(resource) → [学习中: recordMetric × N] → endSession()
                                          ↘
                                    switchResource(newResource)
                                    = endSession() + beginSession()
```

**关键设计**：
- **打开即计时**：调用 `beginSession()` 立即开始记录 startTime
- **切换即结算**：调用 `switchResource()` 自动结束旧资源、开启新资源
- **退出即完成**：调用 `endSession()` 计算实际停留时长并写入
- **无最短门槛**：即使只看了 1 秒也记录（数据完整比过滤更重要）

### 2.3 测试体系：三种模式统一入口

```dart
enum TestScope {
  resource,    // 单元测试：针对单个资源的字幕内容出题
  folder,      // 综合测试：针对文件夹下所有资源的字幕混合出题
  wordBook,    // 生词本测试：针对选中的单词列表出题
}
```

三种模式共享同一个 `TestPage`，通过 `testScope` 区分行为：

| 模式 | testScope | 核心参数 | 出题来源 | 结果归属 |
|------|-----------|---------|---------|---------|
| 单元测试 | `resource` | `videoCode` | 该资源的字幕 | → `videoCode` |
| 综合测试 | `folder` | `videoCode`(代表) + `folderCode` | 文件夹内所有资源字幕混合 | → `item.source_video_code` |
| 生词本测试 | `wordBook` | `seedWords[]` | 选中的单词 | → 仅 `wordBookCode`（不归属到资源） |

### 2.4 字幕云存储：按文件夹组织

当前字幕上传到 Supabase Edge Function (`subtitle-storage`)，以 `video_code` 作为标识。v2.0 增加 `folder_code` 维度：

```
存储结构：
supabase storage (subtitle-storage Edge Function)
│
├── 上传时携带 folderCode:
│   { op: 'upload', video_code: 'v001', folder_code: 'f001', items: [...] }
│
├── 出题时按文件夹查询（综合测试）:
│   { test_scope: 'folder', folder_code: 'f001', config: {...} }
│   → 服务器返回 items，每道题带 source_video_code
│
└── 删除时同步清理:
    - 删除单个资源 → { op: 'delete', video_code: 'v001' }
    - 删除整个文件夹 → { op: 'delete_folder', folder_code: 'f001' }
```

**上传触发点（均需携带 folderCode）**：

| 入口 | 说明 | 当前状态 |
|------|------|---------|
| 文件夹详情页导入字幕 | 本地文件/SRT/LRC 解析后上传 | ✅ 已实现，需加 `folderCode` |
| WiFi 传字幕 | WiFi Transfer Service 导入后上传 | ✅ 已实现，需加 `folderCode` |
| 音频识别歌词 | 音频播放页语音识别后上传 | ✅ 已实现，需加 `folderCode` |
| 文章内容上传 | 文章创建/更新后上传（`article_` 前缀） | ✅ 已实现，需加 `folderCode` |

**同步注意事项**：
- 本地删除资源/文件夹时，需同步调用 `subtitle-storage` 清理云端
- WiFi 重新导入同一资源时，upsert 语义（覆盖旧版本）
- 文件夹重命名不影响存储（folderCode 不变）

---

## 三、统一服务层设计：LearningStatsService

### 3.1 接口定义

```dart
/// 统一学习统计服务
///
/// 所有学习行为的唯一写入入口。
/// 负责：会话管理 / 时长计算 / 指标归集 / 资源汇总更新
class LearningStatsService {

  // ════════════════════════════════════════════════
  //  会话管理（学习时长）
  // ════════════════════════════════════════════════

  /// 开始学习某个资源
  ///
  /// [resourceCode] 资源 code（video_info.code / article.code）
  /// [resourceType] 资源类型：video / article / music
  /// [folderCode] 所属文件夹 code
  Future<void> beginSession({
    required String resourceCode,
    required String resourceType,
    String? folderCode,
  });

  /// 结束当前学习会话
  ///
  /// 计算 duration = DateTime.now() - _sessionStartTime
  /// 写入 StudyRecord（duration / endTime）
  /// 更新 VideoInfo.totalPlayDuration（累加）
  Future<void> endSession();

  /// 原子操作：结束旧资源 + 开启新资源
  ///
  /// 用于切换视频/音频/文章时调用，确保无时长丢失
  Future<void> switchResource({
    required String resourceCode,
    required String resourceType,
    String? folderCode,
  });

  /// 获取当前正在学习的资源 code（如有）
  String? get currentResourceCode;

  /// 获取当前会话是否活跃
  bool get isSessionActive;

  // ════════════════════════════════════════════════
  //  行为指标（跟读 / 测试）
  // ════════════════════════════════════════════════

  /// 记录跟读评分
  ///
  /// 由 ShadowReaderComponent 评分回调中调用。
  /// 同时执行：
  ///   1. 写入 RecordingRecord（详情层，已有逻辑不变）
  ///   2. 更新 StudyRecord.bestFollowScore（取 max）
  ///   3. 更新 VideoInfo.lastFollowScore（取 max）
  ///   4. 累加 StudyRecord.followCount
  Future<void> recordFollowScore({
    required String resourceCode,
    required double score,
    required String sentenceCode,
    String? resourceType,
    Map<String, dynamic>? detail,
  });

  /// 记录单题测试结果
  ///
  /// 由 TestPage / TestSessionPage 提交答案时调用。
  /// 按 questionType 分类累加到 StudyRecord 的测试统计中。
  Future<void> recordQuizResult({
    required String resourceCode,
    required String questionType,
    required bool isCorrect,
    String? wordBookCode,
    double? score,
    String? resourceType,
  });

  /// 记录一次测试 session 完成
  ///
  /// 全部题目答完后调用，聚合计算该资源的 testScore。
  Future<void> completeTestSession({
    required String resourceCode,
    required int totalQuestions,
    required int correctCount,
    String? resourceType,
  });

  // ════════════════════════════════════════════════
  //  查询（供 UI 渲染使用）
  // ════════════════════════════════════════════════

  /// 获取某个资源的学习汇总（用于列表页展示）
  Future<ResourceLearningSummary> getSummary(String resourceCode);

  /// 今日学习总时长（秒）
  Future<int> getTodayTotalDuration();

  /// 连续学习天数
  Future<int> getStreakDays();

  /// 今日是否已学习
  Future<bool> isTodayLearned();

  /// 最近学习的资源列表（按最后学习时间倒序）
  Future<List<RecentResource>> getRecentResources({int limit = 10});

  /// 各资源类型今日时长分布
  Future<Map<String, int>> getTodayDurationByType();
}

/// 资源学习汇总（轻量级，用于 UI 展示）
class ResourceLearningSummary {
  final String resourceCode;
  final String resourceType;
  final int totalDurationSeconds;     // 累计学习时长（秒）
  final int sessionCount;             // 学习次数
  final double? bestFollowScore;      // 最佳跟读分
  final double? latestTestScore;      // 最近测试得分
  final int totalFollowCount;         // 总跟读次数
  final DateTime? lastStudiedAt;      // 最后学习时间
}

/// 最近学习的资源
class RecentResource {
  final String resourceCode;
  final String resourceType;
  final String? resourceTitle;
  final String? folderCode;
  final DateTime lastStudiedAt;
  final int lastDurationSeconds;
}
```

### 3.2 内部状态管理

```dart
class LearningStatsService {
  // 会话状态（内存中，不持久化）
  DateTime? _sessionStartTime;
  String? _sessionResourceCode;
  String? _sessionResourceType;
  String? _sessionFolderCode;
  bool _sessionActive = false;

  // 单例模式（或通过 Riverpod provider 提供）
  static final LearningStatsService instance = LearningStatsService._();
  LearningStatsService._();
}
```

---

## 四、时长计算修正（Bug Fix）

### 4.1 当前 Bug

**位置**：`lib/providers/player_engine_provider.dart` → `_completeCurrentStudyRecord()`

```dart
// ❌ 错误：用播放位置代替学习时长
final durationMs = state.position.inMilliseconds;
// 如果用户拖动进度条到 50 分钟处只看了 1 秒，
// durationMs 就会记录成 50 分钟！
```

### 4.2 修正方案

```dart
// ✅ 正确：用实际停留时间
Future<void> _completeCurrentStudyRecord() async {
  if (!_studyRecordCreated || _studyResourceCode == null || _closed) return;

  final endTime = DateTime.now();
  // ★ 核心修正：用实际经过的时间，而非播放位置
  final durationSeconds = _studyStartTime != null
      ? endTime.difference(_studyStartTime!).inSeconds
      : 0;

  try {
    await ref.read(fileProvider.notifier).completeStudyRecord(
      _studyResourceCode!,
      endTime,
      durationSeconds,  // ← 改为秒（整数），值为实际停留时间
      1,
    );
  } catch (_) {}
  // ... 重置状态
}
```

### 4.3 对齐 LearningStatsService

修正后的 `PlayerEngineNotifier` 应将学习记录委托给 `LearningStatsService`：

```dart
// openVideoByCode / openAudioByCode 中：
await learningStats.switchResource(
  resourceCode: videoCode,
  resourceType: resourceType,
  folderCode: folder.code,
);

// disposePlayer 中：
await learningStats.endSession();
```

---

## 五、各场景埋点规划

### 5.1 埋点总览

| 场景 | 触发时机 | 调用函数 | 备注 |
|------|---------|---------|------|
| 打开视频/音频/文章 | `openVideoByCode()` / `openAudioByCode()` | `learningStats.beginSession()` | 取消 30s 延迟 |
| 切换资源（上一首/下一部） | `switchToVideo()` / `switchToAudio()` / `_playNextInList()` | `learningStats.switchResource()` | 原子操作 |
| 退出播放器 | `disposePlayer()` / `dispose()` | `learningStats.endSession()` | 含 App 被 kill 的兜底（二期） |
| 跟读评分完成 | `ShadowReaderComponent._evaluateRecording()` 回调 | `learningStats.recordFollowScore()` | 同时更新 VideoInfo.lastFollowScore |
| 测试提交一题 | `TestPage._submit()` / `TestSessionPage.submitAnswer()` | `learningStats.recordQuizResult()` | 携带 source_video_code |
| 测试全部完成 | `TestPage._next()` 最后题 / `TestSessionPage` 完成 | `learningStats.completeTestSession()` | 聚合 testScore |
| App 进入前台 | `WidgetsBindingObserver.didChangeAppLifecycleState()` | `learningStats.beginSession(type: app_open)` | 二期实现 |

### 5.2 资源切换时的完整流程

```
用户点击"下一集"
    ↓
switchToVideo(nextCode)
    ↓
┌─── PlayerEngineNotifier ───┐
│  1. _player.pause()         │  暂停当前播放
│  2. learningStats           │  ★ 结算旧资源 + 开启新资源
│     .switchResource(        │
│       nextCode, 'video',    │
│       folderCode)           │
│  3. openVideoByCode(next)   │  加载新资源
│  4. reloadSubtitles(next)   │  加载新字幕
└─────────────────────────────┘
    ↓
switchResource 内部：
  ├─ endSession()
  │   ├─ 计算 duration = now - startTime
  │   ├─ UPDATE study_record SET duration=?, end_time=?
  │   └─ UPDATE video_info SET total_play_duration += ?
  └─ beginSession(nextCode)
      ├─ INSERT study_record (startTime=now, status='active')
      └─ _sessionStartTime = now
```

### 5.3 跟读评分的完整流程

```
用户在 ShadowReaderComponent 完成录音并评分
    ↓
_evaluateRecording() 得到 overall=85.0
    ↓
┌─── ShadowReaderComponent ─────────────┐
│  1. 写入 RecordingRecord              │  ← 详情层（现有逻辑不变）
│     (audioPath, scores, rawResult)    │
│  2. cfg.onScore?.call(overall: 85.0)  │  ← 回调通知
└────────────────────────────────────────┘
    ↓
onScore 回调（在 PlayerEngineProvider 中配置）
    ↓
┌─── LearningStatsService ──────────────┐
│  recordFollowScore(                   │
│    resourceCode: currentVideo.code,   │
│    score: 85.0,                       │
│    sentenceCode: subtitle.code,       │
│  )                                   │
│    ↓                                  │
│  ① UPDATE study_record               │
│     SET best_follow_score = MAX(?, 85)│
│     SET follow_count = follow_count+1 │
│  ② UPDATE video_info                 │
│     SET last_follow_score = MAX(?, 85)│
└────────────────────────────────────────┘
```

### 5.4 测试提交的完整流程

#### 单元测试（TestScope.resource）

```
TestPage(testScope: resource, videoCode: 'v001')
    ↓
_start() → Edge Function: ai-test-plan
  { test_scope: 'resource', video_code: 'v001', config: {...} }
    ↓
返回 items（每道题隐含属于 v001）
    ↓
_submit() → _recordWordResult(ok)
    ↓
learningStats.recordQuizResult(
  resourceCode: widget.videoCode!,  // ← 单元测试：直接用页面级 videoCode
  questionType: type,
  isCorrect: ok,
  wordBookCode: item['word_book_code'],
)
```

#### 综合测试（TestScope.folder）

```
TestPage(testScope: folder, videoCode: 'v001', folderCode: 'f001')
    ↓
_start() → Edge Function: ai-test-plan
  { test_scope: 'folder', folder_code: 'f001', config: {...} }
    ↓
Edge Function 根据 folder_code 找到该文件夹下所有已上传字幕
→ 混合出题，返回 items 携带 source_video_code
    ↓
_submit() → _recordWordResult(ok)
    ↓
learningStats.recordQuizResult(
  resourceCode: item['source_video_code'] ?? widget.videoCode!,
  // ↑ 综合测试：优先用题目级 source_video_code
  //   兜底用代表资源的 videoCode（兼容旧接口）
  questionType: type,
  isCorrect: ok,
  wordBookCode: item['word_book_code'],
)
```

#### 生词本测试（TestScope.wordBook）

```
TestPage(testScope: wordBook, seedWords: [...])
    ↓
_start() → Edge Function: ai-test-plan
  { test_scope: 'word_book', seed_words: [...], config: {...} }
    ↓
_submit() → _recordWordResult(ok)
    ↓
// 仅记录生词本粒度（wordBookCode）
// 不调用 recordQuizResult（没有明确的资源归属）
// 可选：记录独立的学习会话（resourceType: 'word_book'）
```

---

## 六、StudyRecord 字段补齐计划

### 6.1 当前未使用的字段

| 字段 | 类型 | 当前状态 | v2.0 计划 |
|------|------|---------|-----------|
| `testScore` | `double?` | 从未被写入 | 每次 `completeTestSession()` 后聚合写入 |
| `bestFollowScore` | `double?` | 从未被写入 | 每次 `recordFollowScore()` 后取 max 更新 |
| `followCount` | `int` | 从未被写入 | 每次 `recordFollowScore()` 后 +1 |
| `segmentsStudied` | `int` | 从未被写入 | 二期实现（记录学到了第几句） |
| `wordsSaved` | `int` | 从未被写入 | 二期实现（记录收藏了多少单词） |
| `endTime` | `DateTime?` | `completeStudyRecord` 中写入 | 保持不变 |
| `duration` | `int` | ⚠️ 用了 position（Bug） | **修正为实际停留秒数** |

### 6.2 completeStudyRecord 重构

```dart
/// FileProvider 中的完成方法（改造后）
Future<void> completeStudyRecord(
  String resourceCode,
  DateTime endTime,
  int durationSeconds,  // ← 参数语义变更：已经是正确的秒数
  int playCount,
) async {
  final records = await DatabaseService.findByCondition(
    () => StudyRecord(),
    where: 'resource_code = ? AND end_time IS NULL AND is_deleted = 0',
    whereArgs: [resourceCode],
    orderBy: 'start_time DESC',
  );

  if (records.isNotEmpty) {
    StudyRecord record = records.first;
    record.endTime = endTime;
    record.duration = durationSeconds;  // 直接使用传入的正确值
    record.playCount = playCount;
    // ★ 新增：如果有累计的指标数据，一并写入
    // （由 LearningStatsService 在 endSession 时预先计算好）
    await DatabaseService.update(record);
  }
}
```

---

## 七、与现有代码的融合点

### 7.1 文件变更清单

| 文件 | 变更类型 | 内容 |
|------|---------|------|
| `lib/services/learning_stats_service.dart` | **新增** | 统一学习统计服务（核心） |
| `lib/providers/player_engine_provider.dart` | **修改** | (1) 修复时长 Bug (2) 对接 LearningStatsService (3) 移除散落的学习记录逻辑 |
| `lib/providers/file_provider.dart` | **修改** | `createStudyRecord` / `completeStudyRecord` 委托给 LearningStatsService 或调整参数语义 |
| `lib/views/test/test_page.dart` | **修改** | (1) 增加 `TestScope` / `folderCode` 参数 (2) `_recordWordResult` 对接 `recordQuizResult` (3) `_next` 对接 `completeTestSession` |
| `lib/views/test/test_session_page.dart` | **修改** | 对接 `LearningStatsService.recordQuizResult` |
| `lib/widgets/shadow_reader/shadow_reader_component.dart` | **微调** | `onScore` 回调确保传递足够信息（已有 resourceCode/context） |
| `lib/views/files/folder_detail_page.dart` | **微调** | `_showComprehensiveTest` 传 `folderCode` 给 TestPage |
| `lib/services/conversation_service.dart` | **修改** | `uploadSubtitlesToCloud` / `uploadArticleContentToCloud` 增加 `folderCode` 参数 |
| `lib/main.dart` | **不变** | 不需要注册新实体（复用 StudyRecord） |
| `lib/models/study_record.dart` | **不变** | 字段已经完备，无需改模型 |

### 7.2 不变的文件（确认无侵入）

| 文件 | 原因 |
|------|------|
| `lib/models/recording_record.dart` | 详情层保持独立 |
| `lib/models/test_models.dart` | TestSession/TestItem 保持独立 |
| `lib/models/video_info.dart` | 已有 `lastFollowScore` / `totalPlayDuration`，无需改模型 |
| `lib/services/stats_service.dart` | 首期保留，后续被 LearningStatsService 替代 |
| `lib/services/database_service.dart` | 无需改表结构 |

---

## 八、Edge Function 接口契约（前后端对齐）

### 8.1 subtitle-storage（字幕存储）

#### 上传（增加 folderCode）

```json
// Request
{
  "op": "upload",
  "video_code": "v001",
  "folder_code": "f001",
  "title": "Lesson 1",
  "items": [
    {"start_position": 0, "end_position": 3000, "content": "Hello", "content_translate": "你好"}
  ]
}

// Response（不变）
{ "ok": true }
```

#### 删除（增加文件夹级别）

```json
// 删除单个资源
{ "op": "delete", "video_code": "v001" }

// 删除文件夹下所有字幕（★ 新增）
{ "op": "delete_folder", "folder_code": "f001" }
```

### 8.2 ai-test-plan（出题）

#### 单元测试（不变）

```json
{
  "test_scope": "resource",
  "video_code": "v001",
  "config": { "listen_choose_count": 2, ... }
}
```

#### 综合测试（★ 新增）

```json
{
  "test_scope": "folder",
  "folder_code": "f001",
  "config": { "listen_choose_count": 4, ... }
}
// Response items 中每道题增加：
// { ..., "source_video_code": "v003" }
```

#### 生词本测试（不变）

```json
{
  "test_scope": "word_book",
  "seed_words": [{"word": "unprecedented", "meaning": "史无前例的"}],
  "config": { ... }
}
```

---

## 九、实施分期

### 第一期：核心数据准确流通（当前）

> 目标：让学习时长、跟读分数、测试结果的记录和展示完全准确。

| # | 任务 | 涉及文件 | 验证标准 |
|---|------|---------|---------|
| 1 | 新建 `LearningStatsService` | `lib/services/learning_stats_service.dart` | beginSession/endSession/switchResource 可调用 |
| 2 | 修复 `PlayerEngineNotifier` 时长 Bug | `lib/providers/player_engine_provider.dart` | duration = 实际停留时间非播放位置 |
| 3 | `PlayerEngineNotifier` 对接 `LearningStatsService` | 同上 | open/switch/dispose 统一走 service |
| 4 | 补齐 `StudyRecord.testScore/bestFollowScore/followCount` 写入 | `LearningStatsService` + `FileProvider` | 跟读/测试后字段有值 |
| 5 | `ShadowReaderComponent` 对接 `recordFollowScore` | `lib/widgets/shadow_reader/` | 评分后 VideoInfo.lastFollowScore 自动更新 |
| 6 | `TestPage` 增加 `TestScope` + 归属逻辑 | `lib/views/test/test_page.dart` | 三种模式区分，quizResult 携带 resourceCode |
| 7 | `ConversationService.uploadXxx` 增加 `folderCode` | `lib/services/conversation_service.dart` | 上传时携带文件夹信息 |
| 8 | 首页统计对接 `LearningStatsService` | `lib/views/home/` + `lib/services/stats_service.dart` | 今日时长/连续天数来自真实数据 |

### 第二期：App 生命周期 & 异常恢复

| # | 任务 | 说明 |
|---|------|------|
| 9 | App 生命周期监听 | `didChangeAppLifecycleState` → `open_app` 记录 |
| 10 | Crash/Kill 恢复 | 启动时扫描 `status=active` 的 StudyRecord，补全 endTime |
| 11 | 文件夹删除同步清理云端 | 删除资源/文件夹时调用 `subtitle-storage delete` |

### 第三期：统计分析 & AI 建议

| # | 任务 | 说明 |
|---|------|------|
| 12 | `LearningStatsPage` 重写 | 日历打卡 / 学习趋势 / 成就系统 |
| 13 | 测试错误分析 | 错误聚合 / 薄弱环节 / AI 建议 |
| 14 | AchievementService | 成就解锁检测 |

---

## 十、关键设计原则（v2.0 更新）

1. **复用优于新建**：`StudyRecord` 字段已完备，不新建 `learning_activity` 表，降低迁移风险
2. **一个服务入口**：所有学习行为通过 `LearningStatsService` 统一协调，不再散落在各组件中
3. **实际停留时间**：时长 = `now - startTime`，不用播放位置、不用播放时长
4. **打开即计时**：无最短门槛，1s 也记录，数据完整性优先于过滤
5. **汇总+详情分离**：`StudyRecord` 做 UI 展示，`RecordingRecord`/`TestItem` 做分析回溯
6. **按资源精确归属**：特别是综合测试，每道题必须能追溯到具体 `source_video_code`
7. **渐进增强**：三期实施，首期聚焦数据准确流通
8. **前后端协同**：字幕云存储按 `folder_code` 组织，综合测试接口需要 Edge Function 配合

---

## 附录 A：v1.0 → v2.0 变更对照

| 维度 | v1.0 | v2.0 |
|------|------|------|
| 数据表 | 新建 `learning_activity` | 复用 `StudyRecord` |
| 服务层 | `LearningStatsService`（从零） | `LearningStatsService`（委托+协调现有逻辑） |
| 最小时长 | ≥30s 才计入 | 无门槛，1s 也记录 |
| 文章延迟 | Timer 30s 后创建 | 打开即 beginSession |
| 时长来源 | 播放器实际播放时长 | 实际停留时间（now - startTime） |
| 测试入口 | 单元/综合共用 TestPage（无区分） | `TestScope` 枚举明确区分三种模式 |
| 综合测试 | 传单个 video_code | 传 `folder_code`，返回 `source_video_code` |
| 字幕存储 | 按 `video_code` 扁平存储 | 按 `folder_code` 组织，支持文件夹级操作 |
| 跟读分数 | ShadowReader 直接写 DB + VideoInfo | 收口到 `recordFollowScore()` 统一处理 |
| 测试归属 | 仅记 `wordBookCode` | 同时记 `resourceCode`（精确到资源粒度） |

## 附录 B：遗留问题（后续讨论）

1. **AI 对话（conversation）的学习时长记录**：预留 `resourceType: 'conversation'`，首期不做
2. **单词复习（wordReview）的学习时长**：预留 `resourceType: 'word_book'`，首期仅做测试模式
3. **App kill/crash 的数据恢复**：依赖 `status=active` 扫描，二期实现
4. **Edge Function `ai-test-plan` 的 `folder_code` 混合出题能力**：需后端配合开发
