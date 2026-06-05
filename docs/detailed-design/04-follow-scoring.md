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

## 三、评分体系

### 3.1 评分集成架构

```
录音文件（WAV/PCM）
    ↓
VidLang App → Supabase Edge Function
    ↓
Edge Function 调用声通评分 WebSocket
    ↓
返回 ScoreResult
    ↓
存入本地 RecordingRecord 表 + 同步到 Supabase
```

### 3.2 评分回调数据模型

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

### 3.3 和 deepeng 声通评分的关系

直接复用 deepeng 的 `ShengtongScoreService` 和 `RecordingScoreHelper` 代码逻辑，在 VidLang 中通过 Supabase Edge Function 包装：

```dart
// VidLang 中不直接使用 WebSocket
// 改为通过 Supabase Edge Function 调用声通
class ScoringService {
  static Future<ScoreResult> evaluateScore({
    required String audioPath,
    required String referenceText,
  }) async {
    // 1. 读取录音文件
    // 2. 上传到 Supabase Edge Function
    // 3. Edge Function 调用声通 WebSocket 评分
    // 4. 返回结果
    final supabase = Supabase.instance.client;
    final audioBytes = await File(audioPath).readAsBytes();
    final response = await supabase.functions.invoke('evaluate-pronunciation', body: {
      'audio': base64Encode(audioBytes),
      'referenceText': referenceText,
    });
    return ScoreResult.fromJson(response.data);
  }
}
```

## 四、学习记录

### 4.1 StudyRecord 扩展

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

### 4.2 学习统计 Dashboard

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
