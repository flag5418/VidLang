# VidLang - 服务层架构详解

> **版本**: V2.0 | **日期**: 2026-07-13
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

## 二、服务清单与分类（完整版）

### 2.1 核心基础设施服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 1 | **DatabaseService** | `database_service.dart` | 数据库 CRUD、建表、FTS5 全文检索 | ✅ 核心 |
| 2 | **GlobalErrorHandler** | `global_error_handler.dart` | 全局错误处理（Zone Error + Navigator） | ✅ 已实现 |
| 3 | **AppKeysService** | `app_keys_service.dart` | 配置管理、密钥管理、用户上下文 | ✅ 已实现 |
| 4 | **SettingsService** | `settings_service.dart` | 应用设置读写（播放设置等） | ✅ 已实现 |

### 2.2 文件/媒体服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 5 | **FilePickerService** | `file_picker_service.dart` | 文件导入、扫描、字幕解析(.srt/.vtt/.ass/.lrc) | ✅ 已实现 |
| 6 | **FileManagerService** | `file_manager_service.dart` | 物理文件 CRUD（目录创建/删除/重命名） | ✅ 已实现 |
| 7 | **ThumbnailService** | `thumbnail_service.dart` | 视频缩略图生成 | ✅ 已实现 |
| 8 | **InitialLetterCover** | `initial_letter_cover.dart` | 首字母封面生成（无缩略图时） | ✅ 已实现 |
| 9 | **FolderStatsService** | `folder_stats_service.dart` | 文件夹统计信息聚合 | ✅ 已实现 |
| 10 | **WifiTransferService** | `wifi_transfer_service.dart` | WiFi 文件传输 | ✅ 已实现 |
| 11 | **ID3Parser** | `id3_parser.dart` | 音频 ID3 标签解析（歌曲引擎） | ✅ 已实现 |
| 12 | **LrcParser** | `lrc_parser.dart` | LRC 歌词解析（歌曲引擎） | ✅ 已实现 |

### 2.3 AI 服务层（智能能力）

| 序号 | 服务类 | 文件 | 职责 | 依赖 |
|------|--------|------|------|------|
| 13 | **AiService** | `ai_service.dart` | AI 代理调用（Edge Function）、查词、翻译 | Supabase Functions |
| 14 | **LocalAiService** | `local_ai_service.dart` | 本地 AI 服务统一入口（TTS/STT/翻译初始化） | LocalTts/Stt, HuggingFace |
| 15 | **NativeService** | `native_service.dart` | 原生通道封装（iOS 特有能力） | IosNativeFeatures |
| 16 | **IosNativeFeatures** | `ios_native_features.dart` | iOS 原生能力（MLTranslation、词典查询） | iOS only |
| 17 | **DictionaryService** | `dictionary_service.dart` | 查词服务（本地词典 + AI） | AiService |
| 18 | **TranslationService** | `translation_service.dart` | 翻译服务入口 | UnifiedTranslation |
| 19 | **UnifiedTranslationService** | `unified_translation_service.dart` | 统一翻译（本地/云端自动切换） | HuggingFace, AiService |
| 20 | **HuggingfaceTranslationService** | `huggingface_translation_service.dart` | HuggingFace 本地翻译模型 | ONNX Runtime |
| 21 | **TranslationInitService** | `translation_init_service.dart` | 翻译服务懒加载初始化 | - |

### 2.4 TTS（文字转语音）服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 22 | **TtsService** | `tts_service.dart` | TTS 入口（免费/收费模式自动切换） | ✅ 已实现 |
| 23 | **UnifiedTtsService** | `unified_tts_service.dart` | 统一 TTS（系统/本地/云端路由） | ✅ 已实现 |
| 24 | **DashscopeTtsService** | `dashscope_tts_service.dart` | 阿里云 TTS PCM 流（收费模式） | ✅ 已实现 |
| 25 | **LocalTtsService** | `local_tts_service.dart` | 本地 TTS 引擎（ONNX + sherpa-onnx） | ✅ 已实现 |

### 2.5 STT（语音转文字）服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 26 | **SpeechToTextService** | `speech_to_text_service.dart` | STT 入口 | ✅ 已实现 |
| 27 | **UnifiedSttService** | `unified_stt_service.dart` | 统一 STT（本地/云端路由） | ✅ 已实现 |
| 28 | **LocalSttService** | `local_stt_service.dart` | 本地 STT 引擎 | ✅ 已实现 |
| 29 | **AudioRecognitionService** | `audio_recognition_service.dart` | 音频识别（跟读评分输入） | ✅ 已实现 |

### 2.6 评测服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 30 | **EvaluationService** | `evaluation_service.dart` | 发音评测协调器 | ✅ 已实现 |
| 31 | **EvaluationApi** | `evaluation_api.dart` | 评测 API 封装 | ✅ 已实现 |
| 32 | **EvaluationStorageService** | `evaluation_storage_service.dart` | 评测结果存储 | ✅ 已实现 |
| 33 | **AiEvaluationService** | `ai_evaluation_service.dart` | AI 学习评价 | ✅ 已实现 |
| 34 | **ScoreService** | `score_service.dart` | 评分计算 | ✅ 已实现 |
| 35 | **ShengtongEvaluator** | `shengtong_evaluator.dart` | 声通评测器（基类/协调） | ✅ 已实现 |
| 36 | **ShengtongEvaluatorManual** | `shengtong_evaluator_manual.dart` | 声通手动模式评测 | ✅ 已实现 |
| 37 | **ShengtongHttpEvaluator** | `shengtong_http_evaluator.dart` | 声通 HTTP 模式评测 | ✅ 已实现 |

### 2.7 用户/认证/计费服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 38 | **AuthService** | `auth_service.dart` | 认证（Supabase Auth + 本地 Auth） | ✅ 已实现 |
| 39 | **BillingService** | `billing_service.dart` | 计费/余额/扣费 | ✅ 已实现 |
| 40 | **TopupService** | `topup_service.dart` | 充值服务 | ✅ 已实现 |

### 2.8 数据统计服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 41 | **StatsService** | `stats_service.dart` | 统计服务入口 | ✅ 已实现 |
| 42 | **LearningStatsService** | `learning_stats_service.dart` | 学习统计、会话管理、指标归集 | ✅ 已实现 |

### 2.9 对话/AI 实时服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 43 | **ConversationService** | `conversation_service.dart` | AI 对话管理 | ✅ 已实现 |
| 44 | **QwenRealtimeService** | `qwen_realtime_service.dart` | 通义千问实时语音对话 | ✅ 已实现 |

### 2.10 内容解析服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 45 | **ArticleParser** | `article_parser.dart` | 文章内容解析（文章引擎） | ✅ 已实现 |

### 2.11 单词本服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 46 | **WordBookService** | `word_book_service.dart` | 单词本 CRUD | ✅ 已实现 |
| 47 | **WordTagService** | `word_tag_service.dart` | 单词标签管理 | ✅ 已实现 |

### 2.12 本地模型服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 48 | **LocalModelService** | `local_model_service.dart` | 本地模型下载、状态检查、版本管理 | ✅ 已实现 |
| 49 | **ModelPathService** | `model_path_service.dart` | 模型路径管理 | ✅ 已实现 |

### 2.13 测试服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 50 | **TestGenerator** | `test_generator.dart` | 测试题目生成 | ✅ 已实现 |

### 2.14 论坛服务

| 序号 | 服务类 | 文件 | 职责 | 状态 |
|------|--------|------|------|------|
| 51 | **ForumService** | `forum/forum_service.dart` | 论坛 CRUD（基于 Supabase） | ✅ 已实现 |

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
  // 静态访问方式（非传统单例）
  static Future<Database> get database async {...}
  static void registerEntities(Map<String, EntityConfig> entities) {...}
  
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
  }) async {...}
  
  // FTS5 全文检索
  Future<List<T>> searchFTS<T extends BaseEntity>(
    T entityFactory(),
    String table,
    String query, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {...}
  
  // 用户过滤
  static void setCurrentUser(String userCode) {...}
  static String? get currentUserCode => _currentUserCode;
}
```

> **注意**: DatabaseService 在 V2 中已从传统单例改为静态方法访问模式，实体注册使用 `Map<String, EntityConfig>` 而非 `List<BaseEntity>`。

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

---

### 3.4 LearningStatsService（学习统计服务）⭐⭐

**文件**: `lib/services/learning_stats_service.dart`

#### 职责
- **所有学习行为的唯一写入入口**
- 会话管理（开始/结束/切换资源）
- 时长计算（精确到秒）
- 指标归集（跟读评分、测试得分）
- 资源汇总更新（VideoInfo.lastFollowScore 等）

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
    → UnifiedTtsService.speakSystem(text)  ← iOS AVSpeechSynthesizer / Android TTS
    ↓
mode == SubscriptionMode.premium ?
    → DashscopeTtsService.speak(text)       ← 阿里云 TTS PCM 流
    ↓
onEvent 回调通知 UI 状态变化
```

---

### 3.6 AppKeysService（配置与密钥管理）⭐

**文件**: `lib/services/app_keys_service.dart`

#### 职责
- 统一管理应用配置和密钥
- 静态常量（Supabase URL、声通地址等基础配置）
- 动态密钥（Qwen API Key、声通 AppKey，从服务端加载）
- 当前用户上下文（全局共享）

---

## 四、服务间依赖关系图

```
                    ┌─────────────────────┐
                    │   AppKeysService    │ ← 配置中心
                    │  (静态常量+动态密钥)  │
                    └──────────┬──────────┘
                               │
          ┌────────────────────┼────────────────────┬──────────────────┐
          │                    │                    │                  │
          ▼                    ▼                    ▼                  ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐
│  DatabaseService │  │   AuthService   │  │    AiService    │  │ LocalAiSvc   │
│  (数据库 CRUD)   │  │  (用户认证)      │  │  (AI 代理调用)   │  │ (本地AI入口) │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘  └──────┬───────┘
         │                     │                     │                    │
         │                     │                     │                    ├──→ LocalTtsService
         │                     │                     │                    ├──→ LocalSttService
         │                     │                     │                    └──→ HuggingFaceTrans
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
                   │   TtsService    │  │ EvaluationSvc   │
                   │  (跨平台 TTS)   │  │  (发音评测)      │
                   └────────┬────────┘  └────────┬────────┘
                            │                     │
              ┌─────────────┼─────────────┐       │
              ▼             ▼             ▼       ▼
     ┌────────────┐ ┌────────────┐ ┌──────────┐ ┌──────────────┐
     │DashscopeTTS│ │ System TTS │ │LocalModel│ │ShengtongEval │
     │(阿里云TTS) │ │(系统TTS)   │ │ Service  │ │(声通评测)     │
     └────────────┘ └────────────┘ └──────────┘ └──────────────┘
```

---

## 五、新增的重要服务（V1 → V2 新增）

以下服务在 V1 文档中未记录，但已在代码中实现：

| 服务 | 说明 |
|------|------|
| **GlobalErrorHandler** | 全局错误捕获，Zone-level 错误处理 + 导航到错误页 |
| **StatsService** | 统计服务入口，聚合各类学习数据 |
| **ConversationService** | AI 对话管理（多轮对话上下文） |
| **QwenRealtimeService** | 通义千问实时语音对话（WebSocket） |
| **WordBookService** | 单词本完整 CRUD（收藏、标签、复习） |
| **ForumService** | 论坛模块的 Supabase 数据操作 |
| **WifiTransferService** | WiFi 局域网文件传输 |
| **EvaluationService 系列** | 7 个评测相关服务（声通/手动/HTTP/AI） |
| **ArticleParser** | 文章内容解析（EPUB/TXT 等） |
| **BillingService / TopupService** | 会员计费与充值 |

---

## 六、服务层最佳实践

### 6.1 创建新服务的模板

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
      throw ServiceException('{友好错误信息}: $e');
    }
  }
  
  // 释放资源
  void dispose() {
    _isInitialized = false;
  }
}
```

### 6.2 异步操作标准模式

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
    throw ServiceException('网络异常，请检查网络连接');
  } on TimeoutException {
    throw ServiceException('请求超时，请稍后重试');
  } catch (e) {
    throw ServiceException('操作失败: $e');
  }
}
```

### 6.3 错误处理规范

| 错误类型 | 处理方式 | 示例 |
|----------|----------|------|
| **参数错误** | 抛出 `ArgumentError` | `throw ArgumentError('param 不能为空')` |
| **网络错误** | 抛出自定义 `ServiceException` | `throw ServiceException('网络异常')` |
| **认证错误** | 抛出 `AuthException` | `throw AuthException('Token 过期')` |
| **余额不足** | 返回特殊标记（非异常） | `WordDetail.error(isInsufficientBalance: true)` |
| **数据不存在** | 返回空集合或 null | `return []` 或 `return null` |

---

## 七、常见问题排查

### Q1: DatabaseService 未初始化？

**症状**: `Null check operator used on a null value`

**解决方案**:
1. 检查 `main.dart` 是否调用了 `DatabaseService.registerEntities({...})`
2. 确保在使用前访问了 `DatabaseService.database`（触发初始化）
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
- 如果刷新失败，通过 GlobalErrorHandler 导航回登录页

---

## 八、服务层统计（截至 2026-07-13）

| 类别 | 数量 | 说明 |
|------|------|------|
| 核心基础设施 | 4 | DB、ErrorHandler、AppKeys、Settings |
| 文件/媒体 | 8 | 文件导入、缩略图、WiFi传输、歌词/ID3解析 |
| AI 服务 | 9 | AI查询、本地AI、翻译、词典、原生通道 |
| TTS 服务 | 4 | TTS入口、统一TTS、阿里云TTS、本地TTS |
| STT 服务 | 4 | STT入口、统一STT、本地STT、音频识别 |
| 评测服务 | 7 | 评测协调、API、存储、AI评价、声通(x3) |
| 用户/计费 | 3 | Auth、Billing、Topup |
| 数据统计 | 2 | Stats、LearningStats |
| 对话/AI实时 | 2 | Conversation、QwenRealtime |
| 内容解析 | 1 | ArticleParser |
| 单词本 | 2 | WordBook、WordTag |
| 本地模型 | 2 | LocalModel、ModelPath |
| 测试 | 1 | TestGenerator |
| 论坛 | 1 | ForumService |
| **总计** | **~51** | （含 forum 子目录） |

---

## 九、版本更新记录

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| V1.0 | 2026-07-12 | 初始版本，仅覆盖 18 个核心服务 |
| V2.0 | 2026-07-13 | **重大更新**：服务清单从 18 个扩展至 51 个；补充评测服务族(7)、TTS/STT 服务族(各4)、论坛/单词本/WiFi传输等服务；更新 DatabaseService API 为静态方法模式；新增服务间依赖关系图 |

---

**最后更新**: 2026-07-13
**维护者**: VidLang 开发团队
**相关文档**:
- [AGENT_CONTEXT.md](../AGENT_CONTEXT.md) - 项目核心认知
- [Flutter 代码结构详解](./flutter-code-structure.md) - 整体代码组织
- [数据库设计](./database-design.md) - 数据模型和表结构
- [OmniPlayer 集成指南](./omni-player-integration.md) - 播放器集成
- [AI 服务集成](./ai-service-integration.md) - AI 服务详细说明
