# VidLang 详细设计 — 跟读与评分体系

## 一、统一跟读框架

### 1.1 核心抽象

三种内容类型的跟读可以抽象为统一模式：

```dart
abstract class FollowEngine {
  /// 播放原声（视频/音频/TTS）
  Future<void> playOriginal(SegmentScope scope);

  /// 开始录音
  Future<void> startRecording();

  /// 停止录音，返回音频文件路径
  Future<String?> stopRecording();

  /// 回放录音
  Future<void> playRecording(String path);

  /// 获取评分
  Future<ScoreResult?> getScore(String recordingPath, String referenceText);

  /// 暂停
  Future<void> pause();

  /// 停止
  Future<void> stop();
}

/// 跟读范围
enum SegmentScope {
  fullContent,  // 全文/全视频
  chapter,      // 章节/段落
  segment,      // 单句/单条字幕
}
```

### 1.2 跟读 GUI 组件复用

```
              ┌──────────────────────────────┐
              │    FollowPanel (通用组件)      │
              ├──────────────────────────────┤
              │  Scope: [Full] [Chapter] [Sentence] │
              │                              │
              │  [🔊 Original]  [🎤 Record]  │
              │  [▶ Playback]  [📊 Score]    │
              │                              │
              │  Score: 85%                  │
              │  ┌────────────────────────┐  │
              │  │ ████████████░░░░░░░ 85%│  │ ← 总分
              │  │ ██████████░░░░░░░░ 78%│  │ ← 流利度
              │  │ ██████████████░░░░ 92%│  │ ← 准确度
              │  └────────────────────────┘  │
              │                              │
              │  Word-level feedback:        │
              │  unprecedented ✓             │
              │  modern      ✓               │
              │  his·to·ry   ✗ → history     │ ← 逐词纠错
              └──────────────────────────────┘
```

此组件可嵌入 PlayerPage（视频）、ArticleReaderPage（文章）、SongPlayerPage（歌曲）。

### 1.3 评分引擎策略

| 内容类型 | 评分引擎 | 评分维度 | 参考文本 |
|---------|---------|---------|---------|
| 视频跟读 | 声通英文评分 | 发音/流利度/完整度 | 当前字幕句子 |
| 文章跟读 | 声通英文评分 | 发音/流利度/完整度 | 当前句子/章节 |
| 歌曲跟唱 | 声通英文评分 | 发音/流利度/完整度 | 当前歌词句子 |

**注意**：歌曲跟唱不使用音乐评分（音准/节奏），因为有人声干扰。统一使用英文发音评分。

---

## 二、录音体系

### 2.1 录音数据流

```
用户点击录音按钮
    ↓
PlayerEngine 将视频/音频音量调低到 50%（避免回授啸叫）
    ↓
MethodChannel → iOS: AVAudioRecorder / Android: MediaRecorder
    ↓
录音保存在 App 缓存目录 /recordings/{uuid}.wav
    ↓
停止录音
    ↓
恢复视频/音频音量到 100%
    ↓
（可选的）上传到 Supabase Storage
    ↓
准备评分或回放
```

### 2.2 录音文件管理

```dart
class RecordingService {
  /// 录音目录
  static String get _recordingsDir =>
      '${(await getApplicationCacheDirectory()).path}/recordings';

  /// 开始录音，返回文件路径
  static Future<String> startRecording() async {
    final dir = Directory(_recordingsDir);
    await dir.create(recursive: true);
    final path = '${dir.path}/${Uuid().v4().replaceAll("-", "")}.wav';
    // MethodChannel 调用原生录音
    await _channel.invokeMethod('startRecording', {'path': path});
    return path;
  }

  /// 停止录音
  static Future<void> stopRecording() async {
    await _channel.invokeMethod('stopRecording');
  }

  /// 播放录音文件
  static Future<void> playRecording(String path) async {
    await _channel.invokeMethod('playRecording', {'path': path});
  }
}
```

**录音保留策略**：App 本地只保留最后一次录音文件，每次新录音覆盖旧文件。历史录音不保留，节省存储空间。

---

## 三、评分体系

### 3.1 评分集成架构（HTTP 模式）

```
录音文件（WAV/PCM）
    ↓
VidLang App → 声通 HTTP API（直接调用）
    ↓
返回 ScoreResult
    ↓
存入本地 SQLite + 异步同步到云端（Edge Function）
    ↓
（可选）用户手动触发 → AI 深度分析（qwen-turbo）
```

> **架构变更说明**：
> - **V1 方案**：App → Supabase Edge Function → 声通 WebSocket（间接调用，延迟高）
> - **V2 方案（当前）**：App 直接调用声通 HTTP API，Edge Function 仅用于云端存储和 AI 分析
>   - 优势：减少一次网络跳转，降低延迟；声通 HTTP 模式更稳定
>   - 劣势：App 端需维护声通签名逻辑（已封装为 `ShengtongHttpEvaluator`）

### 3.2 声通 HTTP 评测服务

```dart
class ShengtongHttpEvaluator {
  /// 统一评测接口 — 根据文本长度自动选择评测类型
  /// - 无空格且 ≤50 字符：word.eval（单词评测）
  /// - ≤100 字符：sent.eval（句子评测）
  /// - >100 字符：para.eval（段落评测）
  Future<Map<String, dynamic>> evaluateAuto({
    required String refText,
    required String audioPath,
    String userId = 'guest',
    String audioType = 'wav',
    int sampleRate = 16000,
    // ... 更多参数见下方
  });

  /// 精确评测接口 — 手动指定 coreType
  Future<Map<String, dynamic>> evaluate({
    required String coreType,      // word.eval / sent.eval / para.eval
    required String refText,       // 参考文本
    required String audioPath,   // 音频文件路径
    // ... 评测参数
  });
}
```

#### 声通 HTTP API 参数说明

| 参数 | 类型 | 中文含义 | 默认值 | 说明 |
|------|------|---------|--------|------|
| `coreType` | String | 评测内核类型 | 必填 | `word.eval` 单词、`sent.eval` 句子、`para.eval` 段落 |
| `refText` | String | 评测参考文本 | 必填 | 用户需要朗读的文本 |
| `audioPath` | String | 音频文件路径 | 必填 | 录音文件（wav/mp3/opus/m4a） |
| `userId` | String | 用户唯一标识 | `guest` | 用于声通签名 |
| `audioType` | String | 音频格式 | `wav` | wav / mp3 / opus / m4a |
| `sampleRate` | int | 采样率 | 16000 | 音频采样率 |
| `agegroup` | int | 年龄段（打分标准） | null | 1=幼儿园(3-6岁), 2=小学(6-12岁), 3=初中及以上(>12岁) |
| `slack` | double | 打分松紧度 | 0 | 范围[-1, 1]，正数更宽松，负数更严格 |
| `scale` | int | 分制 | 100 | 取值范围(0, 100] |
| `precision` | double | 得分精度 | 1 | 0.1=1位小数, 0.01=2位小数 |
| `dictType` | String | 返回音素类型 | `KK` | CMU / KK / IPA88 |
| `dictDialect` | String | 发音限定 | null | `en_br` 英式、`en_us` 美式 |
| `phonemeOutput` | int | 是否返回音素维度 | 1 | 1开启，0关闭 |
| `readtypeDiagnosis` | int | 是否显示重复读/漏读 | 0 | 1开启（sent.eval 专用） |
| `sentenceNeedWordStress` | int | 是否显示单词重读音节 | 0 | 1开启（sent.eval 专用） |
| `paragraphNeedWordScore` | int | 是否返回单词维度 | 0 | 1开启（para.eval 专用） |
| `attachAudioUrl` | int | 是否返回音频下载地址 | 0 | 1开启（保留7天） |
| `realtimeFeedback` | int | 是否实时反馈中间结果 | 0 | 1开启 |

### 3.3 评分回调数据模型

```dart
class ScoreResult {
  double overallScore;        // 总分 0-100
  double fluencyScore;        // 流利度
  double accuracyScore;       // 准确度
  double completenessScore;   // 完整度
  List<WordScore> wordScores; // 逐词得分

  /// 逐词评分
  /// WordScore.word: 原始单词
  /// WordScore.score: 0-100
  /// WordScore.isCorrect: 是否发音正确
  /// WordScore.phonemeBreakdown: 音素级反馈
}

// 存储到数据库
class RecordingRecord extends BaseEntity {
  String resourceCode;        // VideoInfo/Article/Song code
  SegmentScope scope;         // full/chapter/sentence
  String? segmentCode;        // 句子/chapter code（scope 为 full 时为 null）
  String audioPath;
  int durationMs;
  double? overallScore;
  double? fluencyScore;
  double? accuracyScore;
  double? completenessScore;
  String? wordScoresJson;     // List<WordScore> 序列化
  String? rawResultJson;      // 声通原始返回
  DateTime recordedAt;
}
```

---

## 四、云端存储架构（Edge Function）

### 4.1 设计目标

- 本地 SQLite 保留**全量**评测记录（历史回溯）
- 云端每种评测类型仅保留**最近 50 条**详细记录（节省存储）
- 云端维护**统计摘要**（用于 AI 分析时提供历史上下文）
- 云端同步为**异步非阻塞**操作（使用 `unawaited`）

### 4.2 数据库表结构

```sql
-- 评测详细记录表（云端存储，每种类型最多50条）
CREATE TABLE public.evaluation_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  evaluation_type TEXT NOT NULL CHECK (evaluation_type IN ('word', 'sentence', 'paragraph')),
  
  -- 资源信息
  resource_type TEXT,      -- 资源类型: video / article / music
  resource_code TEXT,      -- 资源编码
  resource_title TEXT,     -- 资源标题
  ref_text TEXT,           -- 参考文本
  
  -- 评分维度
  overall_score NUMERIC(5,2),
  fluency_score NUMERIC(5,2),
  integrity_score NUMERIC(5,2),
  accuracy_score NUMERIC(5,2),
  pronunciation_score NUMERIC(5,2),
  
  -- 详细结果（JSONB 存储完整声通返回）
  raw_result JSONB DEFAULT '{}',
  
  -- 单词级摘要（快速查询用）
  word_summary JSONB DEFAULT '[]',
  
  -- 薄弱维度
  weak_dimensions JSONB DEFAULT '[]',
  
  -- 元数据
  duration_ms INTEGER,     -- 录音时长（毫秒）
  language TEXT DEFAULT 'en',
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 评测类型摘要表（按类型汇总统计）
CREATE TABLE public.evaluation_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  evaluation_type TEXT NOT NULL CHECK (evaluation_type IN ('word', 'sentence', 'paragraph')),
  
  total_count INTEGER DEFAULT 0,
  avg_overall NUMERIC(5,2),
  avg_fluency NUMERIC(5,2),
  avg_accuracy NUMERIC(5,2),
  avg_integrity NUMERIC(5,2),
  avg_pronunciation NUMERIC(5,2),
  
  recent_scores JSONB DEFAULT '[]',      -- 最近 10 次评分
  weak_dimensions JSONB DEFAULT '[]',    -- 薄弱维度汇总
  frequent_errors JSONB DEFAULT '[]',    -- 常错单词 TOP10
  
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, evaluation_type)
);
```

### 4.3 Edge Function：`evaluation-storage`

**接口**：

| Action | 方法 | 说明 |
|--------|------|------|
| `save` | POST | 保存评测结果，自动淘汰旧记录，更新摘要 |
| `history` | POST | 获取历史记录（支持分页） |
| `summary` | POST | 获取用户评测摘要（用于 AI 分析） |

**自动淘汰逻辑**：

```typescript
const MAX_RECORDS_PER_TYPE = 50;

async function pruneOldRecords(supabase, userId, evalType) {
  // 获取该用户该类型的所有记录 ID（按时间倒序）
  const { data: records } = await supabase
    .from('evaluation_records')
    .select('id')
    .eq('user_id', userId)
    .eq('evaluation_type', evalType)
    .order('created_at', { ascending: false });

  if (!records || records.length <= MAX_RECORDS_PER_TYPE) return;

  // 删除超出限制的旧记录
  const idsToDelete = records.slice(MAX_RECORDS_PER_TYPE).map(r => r.id);
  await supabase.from('evaluation_records').delete().in('id', idsToDelete);
}
```

**摘要更新逻辑**：每次保存后重新计算该类型的统计数据（平均分、趋势、薄弱维度、常错单词）。

### 4.4 Flutter 端调用封装

```dart
class EvaluationStorageService {
  /// 保存评测结果到云端（异步，不阻塞 UI）
  static Future<Map<String, dynamic>> saveEvaluation({
    required String evaluationType,    // 'word' | 'sentence' | 'paragraph'
    required ShengtongEvaluationResult result,
    String? resourceType,              // video / article / music
    String? resourceCode,
    String? resourceTitle,
    String? refText,
    int? durationMs,
    String? language,
  });

  /// 获取历史评测记录
  static Future<Map<String, dynamic>> getHistory({
    String? evaluationType,
    int limit = 10,
    int offset = 0,
  });

  /// 获取用户评测摘要（用于 AI 分析时提供历史上下文）
  static Future<Map<String, dynamic>> getSummary({
    String? evaluationType,
  });

  /// 检测评测类型（根据参考文本自动判断）
  static String detectEvaluationType(String? refText) {
    if (refText == null || refText.trim().isEmpty) return 'sentence';
    final trimmed = refText.trim();
    if (!trimmed.contains(' ') && trimmed.length <= 50) return 'word';
    if (trimmed.length <= 100) return 'sentence';
    return 'paragraph';
  }
}
```

**调用时机**：评测完成后立即调用，使用 `unawaited` 确保不阻塞用户操作：

```dart
// 评测完成后，异步保存到云端（不阻塞 UI）
unawaited(
  EvaluationStorageService.saveEvaluation(
    evaluationType: evalType,
    result: evaluationResult,
    resourceType: widget.resourceType,
    resourceCode: widget.resourceCode,
    resourceTitle: widget.resourceTitle,
    refText: currentText,
  ).catchError((e) {
    dev.log('⚠️ 云端保存失败（非致命）: $e', name: 'ShadowReader');
  }),
);
```

---

## 五、AI 深度分析

### 5.1 设计原则

- **手动触发**：用户点击按钮后才发起 AI 分析，避免自动扣费
- **高性价比模型**：使用千问 `qwen-turbo`（输入 0.0003元/千Token，输出 0.0006元/千Token）
- **上下文感知**：结合当前评测结果 + 历史摘要，提供个性化建议
- **计费透明**：通过 `ai-proxy` Edge Function 统一计费，扣费前检查余额

### 5.2 AI 分析流程

```
用户点击「AI 分析」按钮
    ↓
检查用户余额（ai-proxy 自动处理）
    ↓
获取历史评测摘要（evaluation-storage/summary）
    ↓
构建 AI Prompt（当前结果 + 历史上下文）
    ↓
调用 qwen-turbo 生成分析
    ↓
返回结构化结果（整体评价 + 建议 + 重点练习区域 + 练习单词）
    ↓
弹窗展示 AI 分析结果
```

### 5.3 Edge Function：`ai-proxy` 路由

`ai-proxy` 已新增 `ai_audio_evaluation` 路由：

```typescript
// ai-proxy/index.ts 路由表
const ROUTES = {
  ai_audio_evaluation: (key, url, p, model) =>
    analyzePronunciation(key, url, {
      overall_score: p.overall_score,
      fluency_score: p.fluency_score,
      integrity_score: p.integrity_score,
      accuracy_score: p.accuracy_score,
      pronunciation_score: p.pronunciation_score,
      weak_dimensions: p.weak_dimensions,
      error_words: p.error_words,
      missing_words: p.missing_words,
      stress_errors: p.stress_errors,
      phoneme_errors: p.phoneme_errors,
      total_words: p.total_words,
      correct_words: p.correct_words,
      ref_text: p.ref_text,
      history_summary: p.history_summary,  // 历史上下文
    }, model),
  // ... 其他路由
};
```

### 5.4 AI 分析 Prompt 设计

Prompt 构建逻辑（`qwen-chat.ts` 中的 `buildPronunciationAnalysisPrompt`）：

1. **当前评测数据**：总分、流利度、完整度、准确度、发音得分、总单词数、正确单词数
2. **薄弱维度**：各维度得分最低的项
3. **发音错误单词**：得分低于阈值的单词列表
4. **漏读单词**：未读出的单词
5. **重音错误**：重音位置错误的单词
6. **音素错误**：具体音素级别的错误
7. **历史表现**：累计评测次数、历史平均分、长期薄弱维度

**返回格式**：

```json
{
  "analysis": "整体评价（2-3句话，指出主要问题和亮点）",
  "suggestions": [
    "具体改进建议1",
    "具体改进建议2",
    "具体改进建议3"
  ],
  "focus_areas": [
    {"area": "需要重点练习的维度", "priority": "high/medium/low"}
  ],
  "practice_words": [
    {"word": "建议重点练习的单词", "reason": "为什么需要练习"}
  ]
}
```

### 5.5 Flutter 端 AI 分析服务

```dart
class AiEvaluationService {
  /// 手动触发 AI 发音分析
  /// 
  /// [evaluationResult] 声通评测结构化结果
  /// [resourceTitle] 资源标题
  /// [refText] 参考文本
  /// [language] 语言，默认 'en'
  /// 
  /// 返回 AI 分析结果，失败返回 null
  static Future<AiAnalysisResult?> analyzePronunciation({
    required ShengtongEvaluationResult evaluationResult,
    required String resourceTitle,
    String? refText,
    String? language,
  });
}

/// AI 分析结果模型
class AiAnalysisResult {
  final String analysis;              // 整体评价（2-3句话）
  final List<String> suggestions;     // 具体改进建议列表
  final List<FocusArea> focusAreas; // 重点练习区域
  final List<PracticeWord> practiceWords; // 建议重点练习的单词
}

class FocusArea {
  final String area;
  final String priority; // high / medium / low
}

class PracticeWord {
  final String word;
  final String reason;
}
```

---

## 六、UI 交互设计

### 6.1 评测结果展示（弹窗形式）

简化后的弹窗布局：

```
┌─────────────────────────────────────┐
│  📊 评测结果              [✕]       │
├─────────────────────────────────────┤
│                                     │
│  总分: 85  🟢                       │
│  ████████████░░░░░░░ 85%            │
│                                     │
│  流利度: 78  🟡                     │
│  准确度: 92  🟢                     │
│  完整度: 85  🟢                     │
│                                     │
│  ─────────────────────              │
│  单词表现:                          │
│  ✓ unprecedented                    │
│  ✓ modern                           │
│  ✗ history (67分)                 │
│                                     │
│  [🎵 播放录音]  [🔄 重新跟读]       │
│                                     │
│  [🤖 AI 深度分析]  ← 手动触发       │
│                                     │
└─────────────────────────────────────┘
```

### 6.2 AI 分析结果展示

点击「AI 深度分析」后，在弹窗内展示加载状态，完成后展示：

```
┌─────────────────────────────────────┐
│  🤖 AI 发音分析           [✕]       │
├─────────────────────────────────────┤
│                                     │
│  💬 整体评价                        │
│  你的发音整体不错，流利度还有提升...  │
│                                     │
│  📋 改进建议                        │
│  1. 注意单词 history 的 /ɪ/ 发音    │
│  2. 句子末尾的语调可以更加自然        │
│  3. 适当放慢语速，提高清晰度          │
│                                     │
│  🎯 重点练习区域                      │
│  • 元音发音 (high)                  │
│  • 语调自然度 (medium)              │
│                                     │
│  📚 建议练习单词                      │
│  • history — 短元音 /ɪ/ 发音不准    │
│  • unprecedented — 重音位置错误      │
│                                     │
└─────────────────────────────────────┘
```

### 6.3 不同评测类型的差异化展示

| 类型 | 展示重点 | 特殊维度 |
|------|---------|---------|
| 单词 | 音素得分、发音对比 | 音素级反馈、重音位置 |
| 句子 | 流利度、完整度、逐词得分 | 重复读/漏读诊断、语调 |
| 段落 | 整体流畅性、长句完整度 | 句子级得分、语速变化 |

---

## 七、计费规则

| 规则编码 | 名称 | 模型 | 单价 | 说明 |
|---------|------|------|------|------|
| `ai_audio_evaluation` | AI 发音分析 | qwen-turbo | ¥0.01 | 手动触发，含历史上下文分析 |
| `evaluation_storage` | 评测存储 | internal | ¥0 | 内部服务，免费 |
| `st_pron_score` | 声通评分 | 声通 HTTP | 按声通计费 | 直接调用声通 API |

---

## 八、文件清单

### 新增文件

| 文件 | 说明 |
|------|------|
| `lib/services/shengtong_http_evaluator.dart` | 声通 HTTP 评测封装（含完整参数中文注释） |
| `lib/services/evaluation_storage_service.dart` | 云端存储服务封装 |
| `lib/services/ai_evaluation_service.dart` | AI 发音分析服务 |
| `supabase/functions/evaluation-storage/index.ts` | 云端存储 Edge Function |
| `supabase/migrations/20260701000001_create_evaluation_storage_tables.sql` | 数据库建表 + 计费规则 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `supabase/functions/ai-proxy/clients/qwen-chat.ts` | 新增 `analyzePronunciation` 函数 |
| `supabase/functions/ai-proxy/index.ts` | 新增 `ai_audio_evaluation` 路由 |
| `lib/widgets/shadow_reader/shadow_reader_component.dart` | 集成评测、云端保存、AI 分析触发 |

---

## 九、学习记录

### 9.1 StudyRecord 扩展

现有的 StudyRecord 基本可用，只需要增加 sourceType：

```dart
class StudyRecord extends BaseEntity {
  String resourceCode;        // 资源 code（video/article/song）
  String resourceType;        // 'video' / 'article' / 'music'
  String folderCode;          // 所属文件夹 code
  DateTime date;
  DateTime startTime;
  DateTime? endTime;
  int durationSeconds;
  int segmentsStudied;        // 本此学习了多少句
  int wordsSaved;             // 收藏了多少单词
  double? testScore;          // 测试得分
  int followCount;            // 跟读次数
  double? bestFollowScore;    // 最佳跟读分数
}
```

### 9.2 学习统计 Dashboard

```
┌──────────────────────────────────────┐
│  Today's Stats                       │
│                                      │
│  🎬 Video: 15min  (2 videos)        │
│  📖 Article: 8min   (1 article)      │
│  🎵 Music: 5min    (1 song)          │
│  ─────────────────────               │
│  Total: 28min                        │
│                                      │
│  Words saved today: 8                │
│  Tests completed: 2                  │
│  Best follow score: 92%              │
│                                      │
│  ┌──────────────────────────┐       │
│  │  Weekly Activity         │       │
│  │  Mon ████░░  12min       │       │
│  │  Tue ██████░ 18min       │       │
│  │  Wed ███████ 22min       │       │
│  │  Thu ██░░░░░  6min       │       │ ← 今天
│  │  Fri ░░░░░░░  0min       │       │
│  │  Sat ░░░░░░░  0min       │       │
│  │  Sun ░░░░░░░  0min       │       │
│  └──────────────────────────┘       │
└──────────────────────────────────────┘
```
