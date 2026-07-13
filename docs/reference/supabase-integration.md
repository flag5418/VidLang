# Supabase 后端集成知识库

> **版本**: v1.0.0
> **最后更新**: 2026-07-12
> **状态**: ✅ 已启用 - 项目唯一后端服务（Auth + Database + Edge Functions + Realtime）
> **官方文档**: https://supabase.com/docs

---

## 📋 目录

1. [核心原则](#核心原则)
2. [架构概览](#架构概览)
3. [安装与初始化](#安装与初始化)
4. [认证系统 (Auth)](#认证系统-auth)
5. [数据库操作 (Database)](#数据库操作-database)
6. [Edge Functions (云函数)](#edge-functions-云函数)
7. [Realtime 实时订阅](#realtime-实时订阅)
8. [存储 (Storage)](#存储-storage)
9. [安全与权限](#安全与权限)
10. [错误处理模式](#错误处理模式)
11. [最佳实践](#最佳实践)
12. [常见问题排查](#常见问题排查)

---

## 核心原则

### ⚠️ 强制规范

> **Supabase 是本项目唯一的后端服务**，所有远程数据交互必须通过 Supabase 进行。

**核心能力**:
- ✅ **Authentication**: 用户注册/登录/登出、Session 管理、排他性登录
- ✅ **Database**: PostgreSQL 数据库 CRUD 操作（用户配置、学习记录同步等）
- ✅ **Edge Functions**: AI 服务代理（翻译、查词、TTS 等）
- ✅ **Realtime**: 实时数据同步（多设备登录检测等）
- ✅ **Storage**: 文件存储（可选，当前主要使用本地存储）

**禁止行为**:
- ❌ 直接调用第三方 API（如 DeepSeek API）—— 必须通过 Edge Functions 代理
- ❌ 使用 Firebase/Auth0/Cognito 等其他认证服务
- ❌ 使用 REST API 直接访问数据库 —— 必须通过 Supabase Client SDK
- ❌ 在客户端硬编码数据库连接字符串或 Service Role Key

---

## 架构概览

### 整体架构图

```
┌─────────────────────────────────────────────────────┐
│                  VidLang App (Flutter)               │
│                                                     │
│  ┌───────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │ AuthService│  │ AiService │  │ BillingService   │ │
│  │ (认证管理)  │  │ (AI 代理) │  │ (支付/订阅)      │ │
│  └─────┬──────┘  └────┬─────┘  └────────┬─────────┘ │
│        │               │                   │         │
│  ┌─────▼───────────────▼───────────────────▼────────┐ │
│  │              Supabase Client SDK                  │ │
│  └─────────────────────┬─────────────────────────────┘ │
└────────────────────────┼──────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
  ┌──────────────┐ ┌──────────┐ ┌──────────────┐
  │  Postgres    │ │  Edge    │ │  Realtime    │
  │  Database    │ │Functions │ │  Engine      │
  ├──────────────┤ ├──────────┤ ├──────────────┤
  │ • users      │ │• ai-proxy│ │ • 用户在线   │
  │ • user_      │ │• register│ │   状态       │
  │   active_    │ │  -session│ │ • 数据变更   │
  │   session    │ │• topup   │ │   推送       │
  │ • billing_   │ │• billing │ │              │
  │   records    │ │  -webhook│ │              │
  │ • forum_*    │ │          │ │              │
  └──────────────┘ └──────────┘ └──────────────┘
```

### 数据流向

```
用户操作 → Flutter UI → Service 层 → Supabase Client
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    ▼                     ▼                     ▼
              认证请求 (Auth)        数据查询 (DB)           函数调用 (Edge)
                    │                     │                     │
                    ▼                     ▼                     ▼
              JWT Token             PostgreSQL            Deno Runtime
                    │                     │                     │
                    └─────────────────────┴─────────────────────┘
                                          │
                                    统一响应处理
                                          │
                                    更新本地 State (Riverpod)
```

---

## 安装与初始化

### 依赖配置

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.x.x  # Supabase Flutter SDK
```

### 初始化流程

**文件位置**: `lib/main.dart`

```dart
Future<void> _initializeAsyncDependencies() async {
  try {
    // 1️⃣ 初始化 Supabase Client
    await Supabase.initialize(
      url: AppKeysService.supabaseUrl,       // 从安全配置读取
      anonKey: AppKeysService.supabaseAnonKey, // 从安全配置读取
    );

    // 2️⃣ 初始化本地数据库（SQLite）
    await DatabaseService.registerEntities({...});

    print('✅ Supabase 初始化成功');
  } catch (e) {
    print('❌ Supabase 初始化失败: $e');
    // 应用可离线运行，但云端功能不可用
  }
}
```

### 安全密钥管理

**禁止在代码中硬编码密钥！**

```dart
// ✅ 正确：使用 AppKeysService 集中管理
class AppKeysService {
  static String get supabaseUrl => _getEnvOrFallback(
    'SUPABASE_URL',
    'https://your-project.supabase.co',
  );

  static String get supabaseAnonKey => _getEnvOrFallback(
    'SUPABASE_ANON_KEY',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  );
}

// ❌ 错误：硬编码密钥
await Supabase.initialize(
  url: 'https://xxxx.supabase.co',  // ⚠️ 危险！
  anonKey: 'eyJhbGci...',            // ⚠️ 危险！
);
```

---

## 认证系统 (Auth)

### AuthService（项目标准实现）

**文件位置**: `lib/services/auth_service.dart`

#### 核心功能

| 功能 | 方法 | 说明 |
|------|------|------|
| 注册 | `signUp(email, password)` | 创建新账户 |
| 登录 | `signIn(email, password)` | 邮箱密码登录 |
| 登出 | `signOut()` | 清除 Session |
| 获取当前用户 | `currentUser` | 返回 User 对象 |
| 检查登录状态 | `isLoggedIn` | bool |
| 监听认证变化 | `authStateChanges` | Stream<AuthState> |

#### 基础用法

```dart
final authService = AuthService.instance;

// 1️⃣ 注册
try {
  await authService.signUp(email: 'user@example.com', password: 'password123');
  TDToast.showSuccess('注册成功，请查收验证邮件', context: context);
} on AuthException catch (e) {
  TDToast.showError(e.message, context: context);
}

// 2️⃣ 登录
try {
  await authService.signIn(email: 'user@example.com', password: 'password123');
  
  // ✅ 登录成功后必须注册 Session（排他性登录）
  await authService.registerSessionAndWatch();
  
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainPage()));
} on AuthException catch (e) {
  TDToast.showError(e.message, context: context);
} on SessionHijackedException catch (e) {
  TDToast.showWarning(e.message, context: context);
}

// 3️⃣ 登出
await authService.signOut();
Navigator.pushAndRemoveUntil(context, LoginPage.route, (route) => false);

// 4️⃣ 监听认证状态变化（用于全局路由守卫）
authService.authStateChanges.listen((authState) {
  if (authState == AuthState.unauthenticated) {
    // 跳转到登录页
    navigatorKey.currentState?.pushAndRemoveUntil(
      LoginPage.route,
      (route) => false,
    );
  }
});
```

#### 排他性登录（单设备登录）

**核心机制**: 确保同一账号只能在一个设备上在线。

**工作原理**:
1. 登录成功后生成 UUID 作为 `localSessionId`
2. 调用 `register-session` Edge Function 上报到服务器
3. 通过 Realtime 订阅 `user_active_session` 表变更
4. 当检测到其他设备的 session ID 时，触发强制登出

```dart
// 自动处理（AuthService 内部封装）
await authService.signIn(email, password);
await authService.registerSessionAndWatch();  // ✅ 必须调用

// 监听被顶号事件
authService.forceLogoutStream.listen((exception) {
  TDToast.showWarning(exception.message, context: context);
  Future.delayed(Duration(seconds: 2), () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      LoginPage.route,
      (route) => false,
    );
  });
});
```

#### Session 持久化

```dart
// AuthService 内部自动处理：
// 1. 使用 FlutterSecureStorage 加密存储邮箱和密码
// 2. App 重启时自动恢复 Session（静默登录）
// 3. 如果 Session 过期，提示用户重新登录

static final _secureStorage = FlutterSecureStorage();
static const _kSupabaseEmail = 'supabase_email';
static const _kSupabasePassword = 'supabase_password';
```

---

## 数据库操作 (Database)

### Supabase Client 获取

```dart
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// 获取单例 Client
final client = sb.Supabase.instance.client;
```

### CRUD 操作示例

#### 1. 查询 (SELECT)

```dart
// 基础查询
final data = await client
  .from('users')
  .select()
  .eq('id', userId)
  .single();

// 条件查询
final users = await client
  .from('users')
  .select('id, email, display_name, created_at')
  .eq('role', 'premium')  // WHERE role = 'premium'
  .order('created_at', ascending: false)
  .range(0, 19);  // LIMIT 20 OFFSET 0

// 关联查询（JOIN）
final userWithProfile = await client
  .from('users')
  .select('''
    id,
    email,
    profiles (
      avatar_url,
      bio
    )
  ''')
  .eq('id', userId)
  .single();

// 模糊搜索（使用 PostGIS 或 pg_trgm 扩展）
final results = await client
  .from('word_book')
  .select('*')
  .ilike('word', '%$query%');  // ILIKE 不区分大小写
```

#### 2. 插入 (INSERT)

```dart
// 单条插入
await client.from('study_records').insert({
  'user_id': userId,
  'video_code': videoCode,
  'duration_seconds': duration.inSeconds,
  'watched_at': DateTime.now().toIso8601String(),
});

// 批量插入（upsert：存在则更新，不存在则插入）
await client.from('word_book').upsert([
  {'word': 'hello', 'translation': '你好', 'user_id': userId},
  {'word': 'world', 'translation': '世界', 'user_id': userId},
], onConflict: 'user_id,word');  // 冲突键
```

#### 3. 更新 (UPDATE)

```dart
// 条件更新
await client
  .from('users')
  .update({'display_name': 'New Name'})
  .eq('id', userId);

// 更新并返回更新后的数据
final updatedUser = await client
  .from('users')
  .update({'last_login_at': DateTime.now().toIso8601String()})
  .eq('id', userId)
  .select()
  .single();
```

#### 4. 删除 (DELETE)

```dart
// 条件删除
await client
  .from('notifications')
  .delete()
  .eq('user_id', userId)
  .lt('created_at', thirtyDaysAgo);  // 删除30天前的通知
```

#### 5. 事务（批量操作）

```dart
// Supabase 不支持客户端事务，需使用 RPC（数据库函数）
final result = await client.rpc('batch_update_study_records', {
  'records': [
    {'video_code': 'v1', 'duration': 120},
    {'video_code': 'v2', 'duration': 300},
  ],
});
```

### Realtime 实时订阅

#### 基础订阅

```dart
// 订阅表变更
final channel = client
  .channel('my-channel')  // 通道名称（唯一标识）
  .onPostgresChanges(
    event: PostgresChangeEvent.all,  // all / insert / update / delete
    schema: 'public',
    table: 'users',
    callback: (payload, [ref]) {
      switch (payload.eventType) {
        case PostgresChangeEvent.insert:
          print('新增用户: ${payload.newRecord}');
          break;
        case PostgresChangeEvent.update:
          print('用户更新: ${payload.oldRecord} → ${payload.newRecord}');
          break;
        case PostgresChangeEvent.delete:
          print('删除用户: ${payload.oldRecord}');
          break;
      }
    },
  )
  .subscribe();

// 取消订阅
client.removeChannel(channel);
```

#### 高级过滤

```dart
// 只监听特定用户的变更
channel.onPostgresChanges(
  event: PostgresChangeEvent.update,
  schema: 'public',
  table: 'user_active_session',
  filter: PostgresChangeFilter(
    type: PostgresChangeFilterType.eq,
    column: 'user_id',
    value: currentUserId,
  ),
  callback: (payload, [ref]) {
    final newSessionId = payload.newRecord?['session_id'];
    if (newSessionId != localSessionId) {
      // 检测到其他设备登录
      _handleSessionHijacked();
    }
  },
)
```

---

## Edge Functions (云函数)

### 项目使用的 Edge Functions

| Function Name | 用途 | 触发方式 |
|---------------|------|----------|
| `ai-proxy` | AI 服务统一代理（翻译、查词、TTS） | HTTP POST |
| `register-session` | 注册/更新用户活跃 Session | HTTP POST |
| `topup` | 充值/支付处理 | HTTP POST |
| `billing-webhook` | 支付回调（Apple/Google） | Webhook |

### ai-proxy（核心函数）⭐⭐⭐

**统一 AI 服务入口**，所有 AI 相关功能都通过此函数代理。

#### 请求格式

```dart
final response = await client.functions.invoke(
  'ai-proxy',
  body: {
    'rule_code': 'ai_translate',  // 功能规则码
    'scene': 'subtitle',          // 使用场景
    'entry': 'word',              // 词条类型
    'request_id': uuid.v4(),      // 请求 ID（用于日志追踪）
    'params': {                   // 业务参数
      'text': 'Hello World',
      'source_lang': 'en',
      'target_lang': 'zh-CN',
    },
    'source_type': 'video',       // 来源类型（可选）
    'source_code': 'video_123',   // 来源标识（可选）
    'billing': {                  // 计费信息（可选）
      'cost_center': 'ai_translate',
    },
  },
);
```

#### rule_code 列表

| rule_code | 功能 | 说明 |
|-----------|------|------|
| `ai_translate` | 句子翻译 | 字幕翻译、文章翻译 |
| `ai_word_lookup` | 单词查词 | 释义、音标、例句 |
| `ai_tts` | 文本转语音 | 发音生成 |
| `ai_pronunciation_score` | 发音评分 | 跟读评分 |
| `ai_grammar_check` | 语法检查 | 写作批改 |

#### 响应格式

```json
{
  "ok": true,
  "rule_code": "ai_translate",
  "cost_cny": 0.01,
  "balance_after": 9.99,
  "result": {
    "translation": "你好世界",
    "confidence": 0.98
  }
}
```

#### 错误响应

```json
{
  "ok": false,
  "error": {
    "code": "INSUFFICIENT_BALANCE",
    "message": "余额不足"
  },
  "balance_after": 0.00
}
```

### 调用示例（AiService 封装）

```dart
class AiService {
  /// 调用 AI 代理
  static Future<WordDetail> callAiProxy({
    required String ruleCode,
    required String scene,
    required String entry,
    required String word,
    Map<String, dynamic> params = const {},
    bool preferLocal = false,
  }) async {
    // 1. 检查是否优先使用本地模型
    if (preferLocal && canUseLocalModels) {
      return await _callLocalModel(ruleCode: ruleCode, word: word, params: params);
    }

    // 2. 确保 Session 有效
    AuthService.instance.ensureActiveSession();

    // 3. 调用 Edge Function
    final client = sb.Supabase.instance.client;
    final response = await client.functions.invoke(
      'ai-proxy',
      body: {
        'rule_code': ruleCode,
        'scene': scene,
        'entry': entry,
        'request_id': _uuid.v4(),
        'params': params,
      },
    );

    // 4. 解析响应
    final data = response.data as Map<String, dynamic>;
    
    if (data['ok'] == true) {
      return WordDetail.fromJson(data['result']);
    } else {
      // 处理余额不足等业务错误
      if (_isInsufficientBalance(data)) {
        return WordDetail.error(word, isInsufficientBalance: true);
      }
      return WordDetail.error(word, data['error']['message']);
    }
  }
}
```

---

## 存储 (Storage)

### 当前使用情况

项目目前**主要使用本地存储**（SQLite + 文件系统），Supabase Storage 用于：

- [ ] 用户头像（待实现）
- [ ] 学习记录备份（待实现）
- [ ] 云端词书同步（待实现）

### 基础用法（预留）

```dart
// 上传文件
final file = File('/path/to/avatar.png');
await client.storage.from('avatars').upload(
  'user_$userId.png',
  file,
  fileOptions: FileOptions(cacheControl: '3600', upsert: true),
);

// 下载文件
final imageUrl = client.storage.from('avatars').getPublicUrl('user_$userId.png');

// 删除文件
await client.storage.from('avatars').remove(['user_$userId.png']);
```

---

## 安全与权限

### Row Level Security (RLS)

**所有表都必须启用 RLS！**

#### 示例策略

```sql
-- 只有本人可以查看/修改自己的数据
CREATE POLICY "Users can view own data"
ON study_records FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own data"
ON study_records FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own data"
ON study_records FOR UPDATE
USING (auth.uid() = user_id);
```

### 权限层级

| Key 类型 | 权限范围 | 使用场景 |
|----------|----------|----------|
| `anon` key | 公开 + RLS 限制 | 客户端初始化 |
| `service_role` key | 完全权限（绕过 RLS） | Edge Functions、后台任务 |

**⚠️ 禁止在客户端代码中使用 service_role key！**

---

## 错误处理模式

### 统一错误处理

```dart
try {
  final result = await someSupabaseOperation();
  return result;
} on sb.AuthException catch (e) {
  // 认证错误（Token 过期、密码错误等）
  throw AuthException(e.message ?? '认证失败');
} on sb.PostgrestException catch (e) {
  // 数据库错误（约束违反、权限不足等）
  if (e.code == '23505') {
    // 唯一约束冲突
    throw BusinessException('数据已存在');
  }
  throw DatabaseException(e.message);
} on sb.FunctionsException catch (e) {
  // Edge Function 错误
  if (_isInsufficientBalance(e)) {
    throw InsufficientBalanceException();
  }
  throw AiServiceException(e.message);
} on SocketException catch (e) {
  // 网络错误
  throw NetworkException('网络连接失败，请检查网络');
} catch (e) {
  // 未预期错误
  throw UnknownException(e.toString());
}
```

### UI 层错误展示

```dart
// 使用 TDesign 组件展示错误
catch (e) {
  if (mounted) {
    TDToast.showError(
      e is AuthException ? e.message : '操作失败，请重试',
      context: context,
    );
  }
}
```

---

## 最佳实践

### ✅ 必须遵守的规范

#### 1. Session 管理

```dart
// ✅ 在每次调用 Edge Function 前确保 Session 有效
Future<void> _callAiApi() async {
  await AuthService.instance.ensureActiveSession();  // 自动刷新 Token
  
  final response = await client.functions.invoke('ai-proxy', body: {...});
}
```

#### 2. 离线优先策略

```dart
// ✅ 先写入本地 SQLite，再异步同步到云端
Future<void> saveStudyRecord(StudyRecord record) async {
  // 1. 本地保存（立即）
  await DatabaseService.instance.insert(record);
  
  // 2. 云端同步（异步，失败不阻塞）
  try {
    await client.from('study_records').insert(record.toMap());
  } catch (e) {
    // 标记为待同步，下次联网时重试
    record.syncStatus = SyncStatus.pending;
    await DatabaseService.instance.update(record);
  }
}
```

#### 3. 请求去重与缓存

```dart
// ✅ 使用缓存避免重复请求
static final Map<String, WordDetail> _cache = {};

static Future<WordDetail> lookupWord(String word) async {
  if (_cache.containsKey(word)) {
    return _cache[word]!;  // 缓存命中
  }
  
  final result = await callAiProxy(ruleCode: 'ai_word_lookup', word: word);
  _cache[word] = result;  // 写入缓存
  
  return result;
}
```

#### 4. 分页加载

```dart
// ✅ 使用 range 实现分页
Future<List<WordBook>> fetchWordBooks({int page = 1, int pageSize = 20}) async {
  final offset = (page - 1) * pageSize;
  
  final response = await client
    .from('word_book')
    .select()
    .eq('user_id', currentUser!.id)
    .order('created_at', ascending: false)
    .range(offset, offset + pageSize - 1);
  
  return List<WordBook>.from(response.map((json) => WordBook.fromJson(json)));
}
```

### ⚠️ 性能优化建议

#### 1. 减少 Realtime 订阅数量

```dart
// ❌ 错误：每个页面都创建新的订阅
class SomePage extends StatefulWidget {
  void initState() {
    super.initState();
    _subscription = client.channel('unique-$hashCode').subscribe(...);
  }
}

// ✅ 正确：全局统一订阅，按需过滤
class GlobalRealtimeService {
  static final _channel = client.channel('global-changes');
  
  static void init() {
    _channel.onPostgresChanges(...).subscribe();
  }
}
```

#### 2. Edge Function 批量调用

```dart
// ❌ 错误：循环调用
for (final word in words) {
  await AiService.callAiProxy(ruleCode: 'ai_word_lookup', word: word);
}

// ✅ 正确：批量接口（如果支持）
await AiService.batchLookup(words: words);
```

#### 3. 使用 Select 投影减少数据传输

```dart
// ❌ 错误：查询所有字段
client.from('users').select()

// ✅ 正确：只查询需要的字段
client.from('users').select('id, email, display_name, avatar_url')
```

---

## 常见问题排查

### Q1: Supabase 初始化失败？

**排查步骤**:
1. 检查网络连接
2. 验证 URL 和 Anon Key 是否正确
3. 查看 Dashboard → Settings → API 确认项目状态
4. 检查是否有 IP 白名单限制

```dart
try {
  await Supabase.initialize(url: url, anonKey: anonKey);
} catch (e) {
  print('❌ 初始化失败: $e');
  // 应用仍可运行（离线模式），但标记云端功能不可用
  _isCloudAvailable = false;
}
```

### Q2: Auth Token 过期？

**现象**: API 返回 401 Unauthorized。

**解决方案**: 
- Supabase SDK 会自动刷新 Token（refresh_token 机制）
- 如手动调用，使用 `session.refresh()`:

```dart
final session = client.auth.currentSession;
if (session != null && session.isExpired) {
  await client.auth.refreshSession();
}
```

### Q3: Edge Function 超时？

**默认超时**: 5 秒（可在 supabase.json 中配置）。

**解决方案**:
- 对于耗时操作（如 TTS 生成），考虑异步模式：
  1. 提交任务 → 返回 task_id
  2. 轮询或 Realtime 通知结果

### Q4: Realtime 连接断开？

**原因**: App 进入后台、网络切换等。

**解决方案**: Supabase SDK 会自动重连。如需手动处理：

```dart
channel.subscribe(
  realtimeChannelStatus: RealtimeSubscribeStatus.once,  // 只接收一次
  // 或监听连接状态
);

channel.onChannelStatus((status, [_ref]) {
  print('Realtime status: $status');
  if (status == RealtimeConnectivity.disconnected) {
    // 显示离线提示
  }
});
```

### Q5: 如何调试 Edge Function？

**方法 1**: 本地运行
```bash
cd supabase/functions/ai-proxy
supabase functions serve --env ./env
```

**方法 2**: 查看日志
```bash
supabase functions logs ai-proxy --follow
```

**方法 3**: 在代码中添加详细日志
```dart
final response = await client.functions.invoke('ai-proxy', body: {...});
print('Response status: ${response.status}');
print('Response data: ${response.data}');
```

---

## 📚 相关文档

- [Supabase 官方文档](https://supabase.com/docs)
- [Supabase Flutter SDK](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [AuthService 实现](../../../lib/services/auth_service.dart)
- [AiService 实现](../../../lib/services/ai_service.dart)
- [AppKeysService 密钥管理](../../../lib/services/app_keys_service.dart)
- [AI 计费体系设计](../../AI 计费体系与 Edge Function 架构设计.md)
- [TDesign 组件库](./tdesign-components.md) — 用于错误提示 UI

---

## 🔄 版本历史

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0.0 | 2026-07-12 | 初版建立，完整的集成指南与 API 参考 | AI Assistant |

---

## ✅ 检查清单（后续扩展参考）

### 安全性
- [ ] 所有表已启用 RLS
- [ ] 无客户端代码使用 service_role key
- [ ] 密钥通过 AppKeysService 管理（非硬编码）
- [ ] 敏感操作需要重新验证（如修改密码）
- [ ] API Rate Limiting 已配置

### 性能
- [ ] 数据库查询使用了索引
- [ ] Edge Function 响应时间 < 2s（P95）
- [ ] Realtime 订阅数量合理（< 10 个/用户）
- [ ] 大文件上传使用分片上传
- [ ] 图片使用 CDN 加速

### 可靠性
- [ ] Edge Function 有降级方案（本地模型）
- [ ] 离线模式可用（核心功能不依赖网络）
- [ ] 断线重连机制完善
- [ ] 错误日志上报到 Sentry/类似服务
- [ ] 关键操作有重试机制

### 功能完整性
- [ ] 用户注册/登录/登出流程完整
- [ ] Session 持久化和恢复正常
- [ ] 排他性登录工作正常
- [ ] AI 服务计费准确
- [ ] 支付流程完整（iOS IAP / Android Google Pay）
