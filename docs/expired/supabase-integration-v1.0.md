# Supabase 后端集成知识库

> **版本**: V1.1 | **日期**: 2026-07-13
> **状态**: ✅ 当前有效
> **适用读者**: 后端开发者、架构师、AI 辅助工具

---

## 一、核心原则

### 1.1 定位

Supabase 是 VidLang 的**唯一后端服务**，提供以下能力：

| 能力 | 模块 | 说明 |
|------|------|------|
| ✅ Authentication | 用户注册/登录/登出、Session 管理、排他性登录 | |
| ✅ Database (PostgreSQL) | 用户配置、计费记录、论坛、对话、充值配置等云端数据 | |
| ✅ Edge Functions (Deno) | AI 代理、计费、评测存储、论坛等 18 个云函数 | |
| ✅ Realtime | 会话劫持检测（`user_active_session` 表变更订阅） | |
| ✅ Storage | 字幕文件云端备份（`subtitles` bucket） | |

### 1.2 多通道 AI 调用架构

> **重要**: VidLang 的 AI 调用**并非全部走 Edge Function 代理**，而是根据场景选择不同通道：

| 场景 | 通道 | 说明 |
|------|------|------|
| 查词释义（ai_definition） | **Edge Function** (`ai-proxy`) | 统一计费 + 缓存 |
| 单词关联（ai_word_link） | **Edge Function** (`ai-proxy`) | 统一计费 + 缓存 |
| 句子翻译（ai_translate） | **Edge Function** (`ai-proxy`) | 统一计费 + 缓存 |
| 发音评测（ai_audio_evaluation） | **Edge Function** (`ai-proxy`) | 统一计费 |
| 文章翻译（ai_translate_article） | **Edge Function** (`ai-proxy`) | 统一计费 |
| 对话翻译（ai_translate_conversation） | **Edge Function** (`ai-proxy`) | 统一计费 |
| AI 通用问答（ai_chat） | **Edge Function** (`ai-proxy`) | 统一计费 |
| TTS 语音合成 | **DashScope HTTP SSE 直连** | 流式合成，首包延迟低，本地缓存 |
| STT 语音识别 | **声通 WebSocket 直连** | 带发音评分，App 端处理 |
| AI 实时对话 | **Qwen WebSocket 直连** | 全双工实时对话流 |

### 1.3 数据存储策略

- **核心学习数据**（视频、字幕、文章、单词本、学习记录）→ **本地 SQLite**
- **用户配置 / 计费 / 论坛 / 对话** → **Supabase PostgreSQL**
- **字幕文件** → 本地优先 + Supabase Storage 备份（`subtitle-storage` Edge Function）
- **评测结果** → App 端本地 + 云端归档（`evaluation-storage` Edge Function）

---

## 二、架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                    VidLang App (Flutter)                     │
│                                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────┐  │
│  │AuthService│ │AiService │ │BillingSvc│ │ConversationSvc│  │
│  │ (认证管理) │ │(AI代理)  │ │(计费)    │ │(AI对话会话)   │  │
│  └─────┬─────┘ └────┬─────┘ └────┬─────┘ └──────┬────────┘  │
│        │            │           │               │            │
│  ┌─────▼────────────▼───────────▼───────────────▼────────┐   │
│  │              Supabase Client SDK                       │   │
│  └──────────────────────────┬────────────────────────────┘   │
└─────────────────────────────┼────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
  ┌──────────────┐  ┌────────────────┐  ┌──────────────────┐
  │  Postgres     │  │  Edge Functions│  │  Realtime Engine │
  │  Database     │  │  (18个函数)    │  │                  │
  ├──────────────┤  ├────────────────┤  ├──────────────────┤
  │ • users       │  │ • ai-proxy     │  │ • user_active_   │
  │ • billing_*   │  │ • ai-conversation│  │   session 变更   │
  │ • forum_*     │  │ • billing-center│  │   订阅（顶号检测）│
  │ • conversation│  │ • topup-config  │  │                  │
  │ • topup_config│  │ • ai-test-plan  │  │                  │
  │ • evaluation_*│  │ • evaluation-   │  │                  │
  │ • word_cache  │  │   storage      │  │                  │
  │              │  │ • extract-article│  │                  │
  │              │  │ • forum-service │  │                  │
  │              │  │ • forum-admin   │  │                  │
  │              │  │ • model-config  │  │                  │
  │              │  │ • resource-status│  │                  │
  │              │  │ • subtitle-storage│ │                  │
  │              │  │ • usage_event   │  │                  │
  │              │  │ • word-cache    │  │                  │
  │              │  │ • ai-audio-     │  │                  │
  │              │  │   recognize     │  │                  │
  │              │  │ • ai-learning-  │  │                  │
  │              │  │   suggestion    │  │                  │
  │              │  │ • register-     │  │                  │
  │              │  │   session       │  │                  │
  └──────────────┘  └────────────────┘  └──────────────────┘

  ┌──────────────────────────────────────────────────────┐
  │              第三方直连通道（不经过 Edge Function）    │
  │                                                      │
  │  DashScope TTS ──HTTP SSE──▶ 阿里云 qwen3-tts-flash  │
  │  声通 STT   ──WebSocket──▶ api.stkouyu.com           │
  │  Qwen 对话  ──WebSocket──▶ 通义千问 Realtime API      │
  └──────────────────────────────────────────────────────┘
```

---

## 三、安装与初始化

### 依赖配置

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.x.x
```

### 初始化流程

**文件位置**: `lib/main.dart`

```dart
Future<void> _initializeAsyncDependencies() async {
  try {
    // 1️⃣ 初始化 Supabase Client
    await Supabase.initialize(
      url: AppKeysService.supabaseUrl,
      anonKey: AppKeysService.supabaseAnonKey,
    );

    // 2️⃣ 初始化本地数据库（SQLite）
    await DatabaseService.registerEntities({...});
  } catch (e) {
    // 应用可离线运行，但云端功能不可用
    _isCloudAvailable = false;
  }
}
```

### 安全密钥管理

**禁止在代码中硬编码密钥！**

```dart
// ✅ 正确：使用 AppKeysService 集中管理
class AppKeysService {
  static String get supabaseUrl => _getEnvOrFallback('SUPABASE_URL', '...');
  static String get supabaseAnonKey => _getEnvOrFallback('SUPABASE_ANON_KEY', '...');
}
```

---

## 四、认证系统 (Auth)

### AuthService

**文件位置**: `lib/services/auth_service.dart`

#### 核心功能

| 功能 | 方法 | 说明 |
|------|------|------|
| 注册 | `signUp(email, password)` | 创建新账户 |
| 登录 | `signIn(email, password)` | 邮箱密码登录 |
| 登出 | `signOut()` | 清除 Session |
| 获取当前用户 | `currentUser` | 返回 User 对象 |
| 排他性登录 | `registerSessionAndWatch()` | 注册 Session + Realtime 监听顶号 |

#### 排他性登录（单设备登录）

**工作原理**:
1. 登录成功后生成 UUID 作为 `localSessionId`
2. 调用 `register-session` Edge Function 上报到服务器
3. 通过 Realtime 订阅 `user_active_session` 表变更
4. 当检测到其他设备的 session ID 时，触发强制登出

```dart
// 使用方式
await authService.signIn(email, password);
await authService.registerSessionAndWatch();  // ✅ 必须调用

// 监听被顶号事件
authService.forceLogoutStream.listen((exception) {
  TDToast.showWarning(exception.message, context: context);
});
```

---

## 五、Edge Functions 完整清单（18 个）

### 5.1 AI 核心服务

| Function | 用途 | 调用方 | 计费 |
|----------|------|--------|------|
| **ai-proxy** | AI 服务统一代理（查词/翻译/评测/问答） | `AiService` | ✅ 统一扣费 |
| **ai-conversation** | 创建/结算 AI 对话会话（返回 Qwen WebSocket 连接参数） | `ConversationService` | ✅ |
| **ai-audio-recognize** | 音频识别 + 发音评分（STT 收费模式） | `UnifiedSttService` | ✅ |
| **ai-test-plan** | 自动出题（V4 Agent 出题系统，含缓存优化） | `TestGenerator` | ✅ |
| **ai-learning-suggestion** | 根据学习统计生成个性化建议 | Stats 相关 | ✅ |

### 5.2 ai-proxy 路由表（7 条规则）

通过 `rule_code` 字段路由到不同的 AI 能力：

| rule_code | 功能 | 参数关键字 | 说明 |
|-----------|------|-----------|------|
| `ai_definition` | 单词查词（释义、音标、例句） | `word`, `sentence` | 替代旧 `ai_word_lookup` |
| `ai_word_link` | 单词关联（同根词、搭配等） | `word`, `sentence` | 新增 |
| `ai_translate` | 句子翻译 | `text`, `target_language` | |
| `ai_translate_article` | 文章逐句/段落翻译 | `prompt` | 新增 |
| `ai_translate_conversation` | 对话响应翻译 | `text` | 新增 |
| `ai_chat` | 通用 AI 问答 | `prompt`/`text`, `system_prompt` | |
| `ai_audio_evaluation` | 发音评测（多维度打分） | `overall_score`, `fluency_score`, ... | 替代旧 `ai_pronunciation_score` |

**统一响应格式**：
```json
{
  "ok": true,
  "rule_code": "ai_definition",
  "cost_cny": 0.01,
  "balance_after": 9.99,
  "result": { ... }
}
```

### 5.3 计费服务

| Function | 用途 | 接口 | 调用方 |
|----------|------|------|--------|
| **billing-center** | 计费中心（消费记录查询/总览/分类统计） | `op`: overview / by_category / category_detail / by_source / source_detail / action_details | `BillingService` |
| **topup-config** | 充值配置读取（优惠策略，如充50送55） | GET: 返回 `topup_config` 表 active 记录 | `TopupService` |

> **注意**: 旧文档中的 `topup` 和 `billing-webhook` 已不存在，功能合并到 `billing-center` 和 `topup-config`。

### 5.4 内容与资源服务

| Function | 用途 | 说明 |
|----------|------|------|
| **extract-article** | 网页文章提取（Mozilla Readability 算法） | 输入 URL，返回标题+正文 |
| **subtitle-storage** | 字幕文件云端 CRUD + 物理删除 | 备份到 Supabase Storage `subtitles` bucket |
| **resource-status** | 资源删除状态标记（逻辑删除双重保障） | `op`: mark_deleted / mark_active / batch_check |
| **evaluation-storage** | 评测结果云端存储/历史/摘要 | 自动淘汰旧记录（每类型保留 50 条） |

### 5.5 论坛服务

| Function | 用途 | 说明 |
|----------|------|------|
| **forum-service** | 论坛 CRUD（帖子/评论/点赞） | 基于 Supabase `forum_*` 表 |
| **forum-admin** | 论坛管理（审核/置顶/删帖） | 需管理员权限 |

### 5.6 基础设施服务

| Function | 用途 | 说明 |
|----------|------|------|
| **register-session** | 注册/更新用户活跃 Session | 用于排他性登录 |
| **model-config** | 本地模型下载配置（地址/版本/镜像） | 支持 HuggingFace 镜像 |
| **word-cache** | 全局单词缓存管理（预填充/统计/预热/刷新） | V4 支持 synonyms/antonyms/category 刷新 |
| **usage_event** | 使用事件上报（echo 模式，预留扩展） | 当前为 echo 响应 |

---

## 六、直连第三方服务（非 Edge Function）

以下服务**直接连接第三方 API**，不经过 Supabase Edge Function：

### 6.1 TTS — DashScope HTTP SSE

**服务**: `DashScopeTtsService`  
**协议**: HTTP POST + SSE 流式响应  
**模型**: `qwen3-tts-flash`（阿里云 DashScope）

```dart
// 调用链：TtsService → UnifiedTtsService → DashScopeTtsService
// DashScopeTtsService 直接 POST 到：
// https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation
// Header: Authorization: Bearer {api_key}, X-DashScope-SSE: enable
// 响应: SSE data 行，output.audio.data 含 base64 PCM 音频
```

**API Key 来源**: 从 Supabase `app_settings` 表动态查询（`qwen_api_key`），非硬编码。

### 6.2 STT — 声通 WebSocket

**服务**: `ShengtongEvaluator`（App 端评测器）  
**协议**: WebSocket（`wss://api.stkouyu.com:8443`）  
**用途**: 跟读发音评分（免费模式不可用，仅收费模式）

### 6.3 AI 实时对话 — Qwen WebSocket

**服务**: `QwenRealtimeService`  
**协议**: WebSocket（通义千问 Realtime API）  
**会话创建**: 先调 `ai-conversation` Edge Function 获取 WebSocket URL + API Key，再直连

---

## 七、Realtime 实时订阅

### 当前用途：排他性登录检测

Realtime 在项目中**仅用于**监听 `user_active_session` 表变更，实现单设备登录：

```dart
// 只监听特定用户的 session 变更
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
      _handleSessionHijacked();  // 检测到其他设备登录
    }
  },
)
```

> **注意**: Realtime **不用于**通用数据同步或学习记录同步。

---

## 八、存储 (Storage)

### 当前使用情况

| Bucket | 用途 | 状态 |
|--------|------|------|
| `subtitles` | 字幕文件云端备份 | ✅ 通过 `subtitle-storage` Edge Function 管理 |

### 待规划

- [ ] 用户头像上传
- [ ] 学习记录云端备份
- [ ] 云端词书同步

---

## 九、安全与权限

### Row Level Security (RLS)

**所有云端表必须启用 RLS。**

```sql
-- 示例：只有本人可查看/修改自己的数据
CREATE POLICY "Users can view own data" ON billing_records FOR SELECT
USING (auth.uid() = user_id);
```

### 权限层级

| Key 类型 | 权限范围 | 使用场景 |
|----------|----------|----------|
| `anon` key | 公开 + RLS 限制 | 客户端初始化 |
| `service_role` key | 完全权限（绕过 RLS） | Edge Functions 内部 |

**⚠️ 禁止在客户端代码中使用 service_role key！**

---

## 十、错误处理模式

```dart
try {
  final result = await someSupabaseOperation();
  return result;
} on sb.AuthException catch (e) {
  throw AuthException(e.message ?? '认证失败');
} on sb.PostgrestException catch (e) {
  throw DatabaseException(e.message);
} on sb.FunctionsException catch (e) {
  if (_isInsufficientBalance(e)) {
    throw InsufficientBalanceException();
  }
  throw AiServiceException(e.message);
} on SocketException catch (e) {
  throw NetworkException('网络连接失败，请检查网络');
} catch (e) {
  throw UnknownException(e.toString());
}
```

---

## 十一、最佳实践

### 11.1 Session 管理

```dart
// 每次调用 Edge Function 前确保 Session 有效
Future<void> _callAiApi() async {
  await AuthService.instance.ensureActiveSession();
  final response = await client.functions.invoke('ai-proxy', body: {...});
}
```

### 11.2 请求缓存

```dart
// AiService 内置缓存（版本化失效机制）
static const _cacheVersion = 2;  // Edge Function prompt 更新时递增
static final Map<String, WordDetail> _cache = {};
```

### 11.3 分页加载

```dart
final response = await client
  .from('billing_records')
  .select()
  .eq('user_id', userId)
  .order('created_at', ascending: false)
  .range(offset, offset + pageSize - 1);
```

---

## 十二、常见问题排查

### Q1: Supabase 初始化失败？

1. 检查网络连接
2. 验证 URL 和 Anon Key
3. 应用仍可离线运行（标记 `_isCloudAvailable = false`）

### Q2: Edge Function 调用返回余额不足？

1. 检查响应体 `ok == false` + 错误码
2. 显示充值弹窗
3. 检查 `billing-center` 日志确认扣费记录

### Q3: TTS 无法播放？

- 免费模式：检查 iOS 系统是否支持 MLTranslation（iOS 17.4+）
- 收费模式：检查 DashScope API Key 是否已从 `app_settings` 加载
- 清除 `Documents/tts_cache/` 后重试

### Q4: Realtime 连接断开？

Supabase SDK 自动重连。如需手动处理：

```dart
channel.onChannelStatus((status, [_ref]) {
  if (status == RealtimeConnectivity.disconnected) {
    // 显示离线提示
  }
});
```

### Q5: 如何调试 Edge Function？

```bash
# 本地运行
cd supabase/functions/ai-proxy && supabase functions serve --env ./env

# 查看日志
supabase functions logs ai-proxy --follow
```

---

## 十三、版本历史

| 版本 | 日期 | 变更内容 |
|------|------|----------|
| v1.0 | 2026-07-12 | 初版建立（仅 4 个 Edge Function，单通道架构描述） |
| V1.1 | 2026-07-13 | **全面重写**：修正为多通道 AI 调用架构；Edge Functions 从 4→18 个完整清单；新增 ai-proxy 路由表（7条规则）；移除过时的「禁止直连第三方」和「先本地后云端同步」描述；补充 TTS/STT/对话的直连说明；更新计费服务（billing-center + topup-config 替代旧的 topup + billing-webhook） |

---

**最后更新**: 2026-07-13
**维护者**: VidLang 开发团队

**相关文档**:
- [架构总览](../architecture/overview-V1.1.md) - 产品架构与技术栈
- [数据库设计](../architecture/database-schema-V2.0.md) - SQLite + Supabase 表结构
- [服务层架构](./services-architecture.md) - 52 个服务详解
- [AI 服务集成](./ai-service-integration.md) - AI 服务详细说明
- [计费系统设计](../modules/billing-redesign.md) - 充值/扣费/优惠策略
