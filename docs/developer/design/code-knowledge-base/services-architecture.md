# VidLang - 服务层架构详解

> **版本**: V1.0 | **日期**: 2026-07-12  
> **状态**: 当前有效  
> **适用读者**: 后端开发者、架构师、AI 辅助工具

---

## 一、服务层概述

### 1.1 定位与职责

服务层（`lib/services/`）是 VidLang 的**业务逻辑核心层**，位于数据模型（Models）和状态管理（Providers）之间。

**核心职责：**
- 封装复杂业务逻辑
- 协调多个 Model 操作
- 处理异步任务和异常
- 与外部系统交互（文件系统、网络、AI、原生能力）
- 提供统一的接口给 Provider 层调用

### 1.2 设计原则

| 原则 | 说明 |
|------|------|
| **单一职责** | 每个服务只负责一个业务领域 |
| **依赖倒置** | 服务间通过接口依赖，避免循环依赖 |
| **错误隔离** | 每个服务独立处理异常，不向上抛出原始异常 |
| **可测试性** | 核心逻辑可通过 mock 进行单元测试 |
| **单例模式** | 全局共享的服务使用单例（如 DatabaseService） |

---

## 二、服务清单与分类

### 2.1 核心服务（必须）

| 序号 | 服务类 | 文件 | 职责 | 设计模式 |
|------|--------|------|------|----------|
| 1 | **DatabaseService** | `database_service.dart` | 数据库 CRUD、建表、迁移、FTS5 | 单例 + Repository |
| 2 | **AuthService** | `auth_service.dart` | 用户认证（Supabase Auth + 本地认证） | 单例 + Strategy |
| 3 | **FilePickerService** | `file_picker_service.dart` | 文件导入、扫描、字幕解析 | 单例 |
| 4 | **ThumbnailService** | `thumbnail_service.dart` | 视频缩略图生成 | 单例 |
| 5 | **LearningStatsService** | `learning_stats_service.dart` | 学习统计、会话管理、指标归集 | 单例 |
| 6 | **AppKeysService** | `app_keys_service.dart` | 配置管理、密钥管理、用户上下文 | 单例 |

### 2.2 AI 服务层（智能能力）

| 序号 | 服务类 | 文件 | 职责 | 依赖 |
|------|--------|------|------|------|
| 7 | **AiService** | `ai_service.dart` | AI 代理调用（Edge Function）、查词、翻译 | Supabase Functions |
| 8 | **NativeService** | `native_service.dart` | 原生翻译/TTS/词典封装（免费模式） | IosNativeFeatures, AiService |
| 9 | **LocalAiService** | `local_ai_service.dart` | 本地 AI 服务统一入口（TTS/STT/翻译） | LocalTtsService, LocalSttService |
| 10 | **TtsService** | `tts_service.dart` | 跨平台 TTS 朗读（免费/收费模式自动切换） | UnifiedTtsService, DashscopeTtsService |
| 11 | **LocalTtsService** | `local_tts_service.dart` | 本地 TTS 引擎（ONNX Runtime） | sherpa-onnx |
| 12 | **LocalSttService** | `local_stt_service.dart` | 本地 STT 引擎（已移除，保留兼容） | - |
| 13 | **LocalModelService** | `local_model_service.dart` | 本地模型下载、状态检查、版本管理 | 文件系统 |

### 2.3 业务服务（功能模块）

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 14 | **FileManagerService** | `file_manager_service.dart` | 物理文件 CRUD（目录创建/删除/重命名） | ✅ 已实现 |
| 15 | **SyncService** | `sync_service.dart` | 云端同步（Supabase Realtime） | 🚧 开发中 |
| 16 | **TopupService** | `topup_service.dart` | 充值服务（余额管理、订单） | ✅ 已实现 |
| 17 | **SubscriptionService** | `subscription_service.dart` | 订阅模式管理（免费/收费切换） | ✅ 已实现 |

### 2.4 平台特定服务

| 序号 | 服务类 | 文件 | 职责 | 平台 |
|------|--------|------|------|------|
| 18 | **IosNativeFeatures** | `ios_native_features.dart` | iOS 原生能力（MLTranslation、词典查询） | iOS only |

---

## 三、核心服务详解

### 3.1 DatabaseService（数据库服务）⭐⭐⭐

**文件**: `lib/services/database_service.dart`

#### 职责
- 数据库初始化和连接管理
- 实体注册与自动建表
- 通用 CRUD 操作（insert/update/delete/query）
- FTS5 全文检索支持
- 数据库版本管理和迁移

#### 关键 API

```dart
class DatabaseService {
  // 单例
  static final DatabaseService instance = DatabaseService._internal();
  
  // 初始化
  Future<Database> get database async {...}
  
  // 实体注册（在 main.dart 中调用）
  Future<void> registerEntities(List<BaseEntity> entities) async {...}
  
  // 通用 CRUD
  Future<int> insert(BaseEntity entity) async {...}
  Future<int> update(BaseEntity entity) async {...}
  Future<int> softDelete(BaseEntity entity) async {...}
  Future<List<T>> findByCondition<T extends BaseEntity>(
    T entityFactory(), {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  ) async {...}
  
  // FTS5 全文检索
  Future<List<T>> searchFTS<T extends BaseEntity>(
    T entityFactory(),
    String table,
    String query, {
    String? where,
    List<dynamic>? whereArgs,
  ) async {...}
  
  // 用户过滤
  static void setCurrentUser(String userCode) {...}
  static String? get currentUserCode => _currentUserCode;
}
```

#### 使用示例

```dart
// 1. 查询所有视频集（当前用户，未删除）
final folders = await DatabaseService.findByCondition(
  () => VideoFolder(),
  where: 'user_code = ? AND is_deleted = 0',
  whereArgs: [DatabaseService.currentUserCode!],
  orderBy: 'last_play_date DESC',
);

// 2. 插入新记录
final videoInfo = VideoInfo(
  name: 'example.mp4',
  folderCode: folder.code,
)..code = generateUuid();
await DatabaseService.insert(videoInfo);

// 3. 全文搜索字幕
final results = await DatabaseService.searchFTS(
  () => Subtitles(),
  'subtitles',
  'hello world',  // 搜索关键词
  where: 'video_code = ?',
  whereArgs: [videoCode],
);
```

#### 注意事项
- ⚠️ 必须在 `main.dart` 中先调用 `registerEntities()` 才能使用
- ⚠️ 所有查询默认带 `user_code` 过滤（多用户支持）
- ⚠️ 软删除使用 `softDelete()` 而非物理删除
- ⚠️ FTS5 表需要特殊配置触发器（见 database-design.md）

---

### 3.2 AuthService（认证服务）⭐⭐

**文件**: `lib/services/auth_service.dart`

#### 职责
- 用户登录/注册/登出
- 密码修改/重置
- 会话管理（Session Watchdog）
- Supabase Auth 集成
- 本地用户认证（离线模式）
- 安全存储（凭证加密保存）

#### 认证模式

```
┌─────────────────────────────────────────────┐
│              AuthService                     │
├─────────────────┬───────────────────────────┤
│  Supabase Auth  │     本地 Auth             │
│  (云端)         │     (离线)                │
├─────────────────┼───────────────────────────┤
│ • Email+Password│ • 用户名+密码            │
│ • OAuth (Apple) │ • 无需网络               │
│ • OAuth (Google)│ • 数据存在本地 SQLite     │
│ • Magic Link    │                          │
└─────────────────┴───────────────────────────┘
```

#### 关键 API

```dart
class AuthService {
  static final AuthService instance = AuthService._();
  
  // Supabase 登录
  Future<User> signInWithEmail({required String email, required String password}) async {...}
  Future<User> signInWithApple() async {...}
  Future<User> signInWithGoogle() async {...}
  
  // 本地登录
  Future<local.User> signInLocal({required String username, required String password}) async {...}
  
  // 注册
  Future<User> signUp({required String email, required String password}) async {...}
  
  // 登出
  Future<void> signOut() async {...}
  
  // 密码管理
  Future<void> changePassword(String newPassword) async {...}
  
  // 会话监控
  Future<void> startSessionWatch() async {...}  // 监控会话过期
  void _stopSessionWatch() {...}
  
  // 当前用户
  User? get currentUser => AppKeysService.currentUser;
  bool get isLoggedIn => currentUser != null;
  bool get isSupabaseUser => currentUser?.authProvider == 'supabase';
}
```

#### 使用示例

```dart
try {
  final user = await AuthService.instance.signInWithEmail(
    email: 'test@example.com',
    password: 'password123',
  );
  print('登录成功: ${user.displayName}');
} on AuthException catch (e) {
  showErrorDialog('登录失败: ${e.message}');
}
```

#### 安全机制
- 🔒 凭证存储在 iOS Keychain / Android Keystore（通过 flutter_secure_storage）
- 🔄 Session Watchdog 自动刷新 Supabase Token（每 20 分钟检查一次）
- 🚫 登出时清除所有本地缓存和安全存储

---

### 3.3 AiService（AI 代理服务）⭐⭐⭐

**文件**: `lib/services/ai_service.dart`

#### 职责
- 统一调用 Supabase Edge Function (`ai-proxy`)
- AI 查词（单词释义、音标、例句）
- AI 翻译（英→中 / 中→英）
- 计费集成（每次调用返回 cost_cny 和 balance_after）
- 缓存管理（本地缓存常用查询结果）
- 本地/云端模式自动切换

#### 架构设计

```
AiService
    │
    ├── callAiProxy()          ← 核心调用方法
    │   ├── preferLocal: true  → 尝试本地模型（iOS MLTranslation）
    │   └── preferLocal: false → 走云端 Edge Function
    │
    ├── getDefinition()        ← 查单词释义
    │   └── 返回 WordDetail
    │
    └── translateText()         ← 翻译文本
        └── 返回 TranslationResult
```

#### Edge Function 返回格式

```json
{
  "ok": true,
  "rule_code": "ai_translate",
  "cost_cny": 0.01,
  "balance_after": 9.99,
  "result": {
    "word": "hello",
    "phonetic": "/həˈloʊ/",
    "translation": "你好",
    "examples": ["Hello, how are you?", "Say hello to him."]
  }
}
```

#### 关键 API

```dart
class AiService {
  static const _functionName = 'ai-proxy';
  static const _cacheVersion = 2;  // 缓存版本号
  
  /// 核心调用方法
  static Future<WordDetail> callAiProxy({
    required String ruleCode,      // 规则码：ai_translate / ai_definition
    required String scene,          // 场景：video / article / music
    required String entry,          // 入口：word_lookup / sentence_translate
    required String word,           // 查询词
    String? sourceType,
    String? sourceCode,
    Map<String, dynamic> params = const {},
    Map<String, dynamic>? billing,
    bool preferLocal = false,       // 是否优先本地模型
  }) async {...}
  
  /// 查单词释义（快捷方法）
  static Future<WordDetail> getDefinition({
    required String word,
    String? contextSentence,
    String? sourceType,
    String? sourceCode,
  }) async {
    return callAiProxy(
      ruleCode: 'ai_definition',
      scene: sourceType ?? 'unknown',
      entry: 'word_lookup',
      word: word,
      params: {'context_sentence': contextSentence},
    );
  }
  
  /// 翻译文本（快捷方法）
  static Future<WordDetail> translateText({
    required String text,
    String? sourceType,
  }) async {
    return callAiProxy(
      ruleCode: 'ai_translate',
      scene: sourceType ?? 'unknown',
      entry: 'sentence_translate',
      word: text,
    );
  }
}
```

#### 错误处理

```dart
// 余额不足
if (detail.isInsufficientBalance) {
  showRechargeDialog(
    requiredCny: detail.costCny,
    currentBalance: detail.balanceAfter,
  );
}

// 其他错误
if (!detail.success) {
  showErrorToast(detail.error ?? 'AI 查询失败');
}
```

#### 缓存策略
- 缓存位置：SQLite 或内存（LRU）
- 缓存 Key：`${ruleCode}:${word}:${_cacheVersion}`
- 缓存失效：当 `_cacheVersion` 递增时，旧缓存全部失效
- 缓存时间：常用词永久缓存，非常用词 7 天过期

---

### 3.4 LearningStatsService（学习统计服务）⭐⭐

**文件**: `lib/services/learning_stats_service.dart`

#### 职责
- **所有学习行为的唯一写入入口**
- 会话管理（开始/结束/切换资源）
- 时长计算（精确到秒）
- 指标归集（跟读评分、测试得分）
- 资源汇总更新（VideoInfo.lastFollowScore 等）

#### 设计原则
```
复用 StudyRecord 作为汇总层，不新建表
        ↓
详情层（RecordingRecord / TestItem）保持独立
        ↓
由各业务组件自行写入详情
        ↓
本服务统一协调汇总数据的读写一致性
```

#### 会话生命周期

```
beginSession(resourceCode, resourceType)
    ↓
[学习进行中...]
    ↓
recordFollowScore(score)  ← 可多次调用
recordTestScore(score)    ← 可多次调用
    ↓
endSession()              ← 写入 StudyRecord
    ↓
switchResource(newCode)   ← 原子操作：end + begin
```

#### 关键 API

```dart
class LearningStatsService {
  static final LearningStatsService instance = LearningStatsService._();
  
  // ════════════════════════════════════
  //  会话管理
  // ════════════════════════════════════
  
  /// 开始学习某个资源
  Future<void> beginSession({
    required String resourceCode,    // video_info.code / article.code
    required String resourceType,    // video / article / music
    String? folderCode,              // 所属文件夹 code
  }) async {...}
  
  /// 结束当前会话（写入 StudyRecord）
  Future<void> endSession() async {...}
  
  /// 切换资源（原子操作：结束旧 + 开启新）
  Future<void> switchResource({
    required String resourceCode,
    required String resourceType,
    String? folderCode,
  }) async {...}
  
  // ════════════════════════════════════
  //  行为指标
  // ════════════════════════════════════
  
  /// 记录跟读评分
  Future<void> recordFollowScore({
    required String resourceCode,
    required double score,            // 0-100
    required String sentenceCode,
    String? resourceType,
  }) async {...}
  
  /// 记录测试得分
  Future<void> recordTestScore({
    required String resourceCode,
    required double score,
    required TestType testType,       // fill / dictation / quiz
    Map<String, dynamic>? detail,
  }) async {...}
  
  // ════════════════════════════════════
  //  查询统计
  // ════════════════════════════════════
  
  /// 获取今日学习时长（秒）
  Future<int> getTodayStudyDuration() async {...}
  
  /// 获取本周学习统计
  Future<WeeklyStats> getWeeklyStats() async {...}
}
```

#### 使用示例（在播放器页面中）

```dart
class PlayerPageState extends State<PlayerPage> {
  @override
  void initState() {
    super.initState();
    // 开始学习会话
    LearningStatsService.instance.beginSession(
      resourceCode: widget.video.code,
      resourceType: 'video',
      folderCode: widget.folderCode,
    );
  }
  
  @override
  void dispose() {
    // 结束学习会话
    LearningStatsService.instance.endSession();
    super.dispose();
  }
  
  void _onFollowScore(double score) {
    // 记录跟读评分
    LearningStatsService.instance.recordFollowScore(
      resourceCode: widget.video.code,
      score: score,
      sentenceCode: currentSentence.code,
    );
  }
  
  void _onSwitchVideo(VideoInfo newVideo) {
    // 切换视频（原子操作）
    LearningStatsService.instance.switchResource(
      resourceCode: newVideo.code,
      resourceType: 'video',
      folderCode: widget.folderCode,
    );
  }
}
```

#### 数据写入流程

```
endSession() 被调用
    ↓
计算 duration = DateTime.now() - _sessionStartTime
    ↓
创建 StudyRecord 对象：
  - resource_code = _sessionResourceCode
  - resource_type = _sessionResourceType
  - folder_code = _sessionFolderCode
  - start_time = _sessionStartTime
  - end_time = DateTime.now()
  - duration = duration.inSeconds  ← ⚠️ 单位是秒！
  - best_follow_score = _bestFollowScore
  - follow_count = _followCount
  - best_test_score = _bestTestScore
  - test_count = _testCount
    ↓
DatabaseService.insert(studyRecord)
    ↓
更新 VideoInfo/Article 统计字段：
  - total_play_duration += duration
  - last_follow_score = max(last_follow_score, score)
    ↓
_resetSession()  ← 清理会话状态
```

---

### 3.5 TtsService（TTS 朗读服务）⭐⭐

**文件**: `lib/services/tts_service.dart`

#### 职责
- 跨平台文本转语音
- 免费/收费模式自动切换
- 音频缓存（基于 SHA256 hash）
- 事件回调（loading/playing/completed/error）
- 预加载支持（提前合成下一句）

#### 模式切换逻辑

```
speakClarity(text, mode?)
    ↓
mode == null ? → 检查 SubscriptionProvider.currentMode
    ↓
mode == SubscriptionMode.free ?
    → UnifiedTtsService.speakSystem(text)  ← iOS AVSpeechSynthesizer
    ↓
mode == SubscriptionMode.premium ?
    → DashscopeTtsService.speak(text)       ← 阿里云 TTS PCM 流
    ↓
onEvent 回调通知 UI 状态变化
```

#### 关键 API

```dart
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  
  bool get isSpeaking => _isSpeaking;
  
  /// 朗读文本（自动选择模式）
  Future<void> speakClarity({
    required String text,
    SubscriptionMode? mode,        // 可选，不传则自动检测
    void Function(TtsEvent)? onEvent,  // 事件回调
    VoidCallback? onComplete,       // 完成回调（兼容旧接口）
  }) async {...}
  
  /// 停止朗读
  Future<void> stop() async {...}
  
  /// 预加载（提前合成下一句）
  Future<void> prefetch(String text) async {...}
  
  /// 释放资源
  void dispose() {...}
}
```

#### 事件回调示例

```dart
TtsService().speakClarity(
  text: 'Hello, how are you?',
  onEvent: (event) {
    switch (event.type) {
      case TtsEventType.loading:
        showLoadingIndicator();  // 显示加载动画
        break;
      case TtsEventType.playing:
        hideLoadingIndicator();  // 开始播放
        break;
      case TtsEventType.completed:
        enableNextButton();      // 播放完成，允许下一步
        break;
      case TtsEventType.error:
        showErrorToast(event.message ?? 'TTS 错误');
        break;
    }
  },
);
```

#### 缓存机制
- 缓存路径：`Documents/tts_cache/`
- 缓存文件名：`sha256(text).pcm`
- 缓存命中：同一句话重复点击秒开（无需重新合成）
- 缓存清理：应用退出时可清理（可选保留）

---

### 3.6 AppKeysService（配置与密钥管理）⭐

**文件**: `lib/services/app_keys_service.dart`

#### 职责
- 统一管理应用配置和密钥
- 静态常量（Supabase URL、声通地址等基础配置）
- 动态密钥（Qwen API Key、声通 AppKey，从服务端加载）
- 当前用户上下文（全局共享）

#### 配置分类

```dart
class AppKeysService {
  static final AppKeysService instance = AppKeysService._();
  
  // ════════════════════════════════════
  // ① 静态常量 —— 基础连接信息
  // ════════════════════════════════════
  static const String supabaseUrl = 'https://xxx.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_xxx';
  
  // ════════════════════════════════════
  // ② 声通语音评测 —— 基础配置
  // ════════════════════════════════════
  static const String shengtongWsUrl = 'ws://api.stkouyu.com:8080';
  static const String shengtongWssUrl = 'wss://api.stkouyu.com:8443';
  static const bool shengtongUseSSL = false;
  
  // ════════════════════════════════════
  // ③ 运行时状态 —— 当前用户
  // ════════════════════════════════════
  static User? currentUser;  // 全局共享
  
  // ════════════════════════════════════
  // ④ 动态密钥 —— 从服务端加载
  // ════════════════════════════════════
  String? _qwenApiKey;              // 通义千问 API Key
  String? _shengtongAppId;          // 声通 App ID
  String? _shengtongApiKey;         // 声通 API Key
  
  /// 从 app_settings 表加载动态密钥
  Future<void> loadDynamicKeys() async {
    final response = await supabase
      .from('app_settings')
      .select()
      .eq('key', ['qwen_api_key', 'shengtong_app_id', 'shengtong_api_key']);
    
    for (var row in response) {
      switch (row['key']) {
        case 'qwen_api_key':
          _qwenApiKey = row['value'];
          break;
        case 'shengtong_app_id':
          _shengtongAppId = row['value'];
          break;
        case 'shengtong_api_key':
          _shengtongApiKey = row['value'];
          break;
      }
    }
  }
}
```

#### 使用场景

```dart
// 在任何地方获取当前用户
final user = AppKeysService.currentUser;
if (user != null) {
  print('Hello, ${user.displayName}');
}

// 获取 Supabase URL
final url = AppKeysService.supabaseUrl;

// 获取动态密钥（需先调用 loadDynamicKeys）
await AppKeysService.instance.loadDynamicKeys();
final qwenKey = AppKeysService.instance.qwenApiKey;
```

---

## 四、服务间依赖关系图

```
                    ┌─────────────────────┐
                    │   AppKeysService    │ ← 配置中心
                    │  (静态常量+动态密钥)  │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  DatabaseService │  │   AuthService   │  │    AiService    │
│  (数据库 CRUD)   │  │  (用户认证)      │  │  (AI 代理调用)   │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                     │
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ LearningStats   │  │  FilePicker     │  │  NativeService  │
│ Service         │  │  Service        │  │  (免费模式封装)  │
│ (学习统计)       │  │  (文件导入)      │  │                 │
└─────────────────┘  └─────────────────┘  └────────┬─────────┘
                                                   │
                              ┌────────────────────┤
                              │                    │
                              ▼                    ▼
                   ┌─────────────────┐  ┌─────────────────┐
                   │  LocalAiService │  │   TtsService    │
                   │  (本地 AI 统一)  │  │  (跨平台 TTS)   │
                   └────────┬────────┘  └────────┬─────────┘
                            │                     │
              ┌─────────────┼─────────────┐       │
              ▼             ▼             ▼       ▼
     ┌────────────┐ ┌────────────┐ ┌──────────┐ ┌──────────┐
     │LocalTtsSvc │ │LocalSttSvc │ │LocalModel│ │Dashscope │
     │(本地 TTS)  │ │(已移除)     │ │ Service  │ │ Tts Svc  │
     └────────────┘ └────────────┘ └──────────┘ └──────────┘
```

---

## 五、服务层最佳实践

### 5.1 创建新服务的模板

```dart
/// {服务名} 服务
///
/// {服务描述}
///
/// 职责：
/// - {职责1}
/// - {职责2}
///
/// 使用示例：
/// ```dart
/// final result = await {ServiceName}.instance.{method}();
/// ```
class {ServiceName} {
  // 单例模式
  static final {ServiceName} instance = {ServiceName}._();
  {ServiceName}._();
  
  // 私有状态
  bool _isInitialized = false;
  
  // 初始化（如有需要）
  Future<void> initialize() async {
    if (_isInitialized) return;
    // ... 初始化逻辑
    _isInitialized = true;
  }
  
  // 核心方法
  Future<{ReturnType}> {methodName}({
    required {ParamType} {param},
  }) async {
    try {
      // ... 业务逻辑
      return result;
    } catch (e) {
      // 统一错误处理
      throw {CustomException}('{友好错误信息}: $e');
    }
  }
  
  // 释放资源
  void dispose() {
    _isInitialized = false;
  }
}
```

### 5.2 异步操作标准模式

```dart
Future<ResultType> doSomethingAsync() async {
  // 1. 参数校验
  if (param == null || param!.isEmpty) {
    throw ArgumentError('参数不能为空');
  }
  
  // 2. 执行业务逻辑
  try {
    final data = await _dependency.fetchData(param!);
    
    // 3. 数据转换/验证
    if (data.isEmpty) {
      return ResultType.empty();
    }
    
    return ResultType.fromData(data);
    
  } on SocketException {
    // 网络异常
    throw ServiceException('网络异常，请检查网络连接');
  } on TimeoutException {
    // 超时
    throw ServiceException('请求超时，请稍后重试');
  } catch (e) {
    // 其他未知错误
    throw ServiceException('操作失败: $e');
  }
}
```

### 5.3 错误处理规范

| 错误类型 | 处理方式 | 示例 |
|----------|----------|------|
| **参数错误** | 抛出 `ArgumentError` | `throw ArgumentError('param 不能为空')` |
| **网络错误** | 抛出自定义 `ServiceException` | `throw ServiceException('网络异常')` |
| **认证错误** | 抛出 `AuthException` | `throw AuthException('Token 过期')` |
| **余额不足** | 返回特殊标记（非异常） | `WordDetail.error(isInsufficientBalance: true)` |
| **数据不存在** | 返回空集合或 null | `return []` 或 `return null` |

### 5.4 日志规范

```dart
import 'dart:developer' as dev;

// 使用结构化日志
dev.log(
  '🚀 [ServiceName] MethodName START: param=$param',
  name: 'ServiceName',  // 服务名作为日志 tag
);

dev.log(
  '✅ [ServiceName] MethodName SUCCESS: result=$result',
  name: 'ServiceName',
);

dev.log(
  '❌ [ServiceName] MethodName ERROR: $error',
  name: 'ServiceName',
  error: error,  // 传入 error 对象，便于调试
  stackTrace: stackTrace,
);
```

---

## 六、常见问题排查

### Q1: DatabaseService 未初始化？

**症状**: `Null check operator used on a null value`

**解决方案**:
1. 检查 `main.dart` 是否调用了 `registerEntities()`
2. 确保在使用前访问了 `DatabaseService.instance.database`
3. 不要在 `main()` 函数的顶层直接调用 DB 操作

### Q2: AiService 返回余额不足？

**排查步骤**:
1. 检查 `detail.isInsufficientBalance` 是否为 true
2. 显示充值弹窗：`showRechargeDialog(requiredCny: detail.costCny)`
3. 检查 Supabase Edge Function 日志确认扣费逻辑

### Q3: TtsService 无法播放？

**可能原因**:
- 免费模式：检查 iOS 系统是否支持 MLTranslation（需 iOS 17.4+）
- 收费模式：检查 Qwen API Key 是否已加载（`AppKeysService.loadDynamicKeys()`）
- 缓存问题：清除 `Documents/tts_cache/` 目录后重试

### Q4: LearningStatsService 会话未正确结束？

**注意事项**:
- 必须在 Widget 的 `dispose()` 中调用 `endSession()`
- 切换资源时使用 `switchResource()` 而非手动 end + begin
- 不要在多个地方同时调用 `beginSession()`（会导致会话冲突）

### Q5: AuthService Token 过期？

**自动处理机制**:
- Session Watchdog 每 20 分钟检查一次 Token 有效性
- Token 即将过期时自动刷新
- 如果刷新失败，抛出 `SessionHijackedException`
- UI 层应捕获此异常并引导用户重新登录

---

## 七、性能优化建议

### 7.1 数据库操作优化

```dart
// ❌ 避免：N+1 查询问题
for (var folder in folders) {
  final videos = await DatabaseService.findByCondition(...);  // N 次查询
}

// ✅ 推荐：批量查询或 JOIN
final allVideos = await DatabaseService.findByCondition(
  () => VideoInfo(),
  where: 'folder_code IN (${folders.map((f) => '?').join(',')})',
  whereArgs: folders.map((f) => f.code).toList(),
);
```

### 7.2 并发控制

```dart
// ❌ 避免：无限制并发
for (var video in videos) {
  await processVideo(video);  // 串行执行，慢
}

// ✅ 推荐：有限并发（如 3 个并发）
await Future.wait(
  videos.map((video) => processVideo(video)),
).catchError((e) => handleError(e));
```

### 7.3 内存管理

```dart
// 大列表分页加载
Future<List<VideoInfo>> loadVideosPaginated(int page) async {
  return await DatabaseService.findByCondition(
    () => VideoInfo(),
    limit: 50,  // 每页 50 条
    offset: page * 50,
  );
}

// 及时释放大对象
void _processLargeData() {
  List<BigObject> data = fetchLargeData();
  // ... 处理
  data.clear();  // 手动清空引用，帮助 GC
  data = [];
}
```

---

## 八、服务层统计（截至 2026-07-12）

| 类别 | 数量 | 总代码行数（约） |
|------|------|------------------|
| 核心服务 | 6 | ~2500 |
| AI 服务 | 7 | ~3000 |
| 业务服务 | 4 | ~1500 |
| 平台特定服务 | 1 | ~200 |
| **总计** | **18** | **~7200** |

---

**最后更新**: 2026-07-12  
**维护者**: VidLang 开发团队  
**相关文档**: 
- [README.md](./README.md) - 知识库入口
- [Flutter 代码结构详解](./flutter-code-structure.md) - 整体代码组织
- [数据库设计](./database-design.md) - 数据模型和表结构
- [状态管理指南](./state-management-guide.md) - Provider 层如何调用 Services
