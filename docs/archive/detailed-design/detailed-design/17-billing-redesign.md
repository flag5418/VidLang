# VidLang 计费体系改造设计

> 状态：设计文档（待确认实施）
> 更新：2026-06-13

---

## 一、改造目标

### 1.1 核心原则

1. **记录精细、展示聚合**：后端 `usage_event` 保持逐次记录，前端账单通过聚合查询呈现
2. **双维度聚合**：按 AI 功能分类 + 按学习资源分类，支持三层下钻
3. **资源可追溯**：每条消费记录必须关联到具体的学习资源（视频/文章/音频），支持按资源维度统计
4. **最小改动**：不改现有表结构和扣费逻辑，仅在调用链路中补齐资源标识

### 1.2 不改动的部分

| 组件 | 状态 |
|------|------|
| `pricing_rule` 表结构 | **不改** |
| `usage_event` 表结构 | **不改**（`meta` JSONB 已支持扩展） |
| `wallet_ledger` 表结构 | **不改** |
| `user_wallet` 表结构 | **不改** |
| `billing.ts` 扣费逻辑 | **不改** |
| 逐次扣费行为 | **不改** |

---

## 二、现状问题：资源 ID 缺失分析

### 2.1 各调用链路资源 ID 传递现状

| 调用链路 | Flutter 端 | Edge Function | `usage_event.meta` 中的资源信息 | 能否按资源统计 |
|---------|-----------|---------------|-------------------------------|-------------|
| `ai-proxy` → 释义 | `AiService.getDefinition(word)` | 存 `meta: {word, sentence}` | **无资源 ID** | ❌ |
| `ai-proxy` → 翻译 | `AiService.translateText(text)` | 存 `meta: {text}` | **无资源 ID** | ❌ |
| `ai-proxy` → TTS | `AiService.getTtsAudio(text)` | 存 `meta: {text}` | **无资源 ID** | ❌ |
| `ai-proxy` → 词联 | `ai_word_link` | 存 `meta: {word}` | **无资源 ID** | ❌ |
| `ai-proxy` → 对话翻译 | `translateConversationText(text)` | 存 `meta: {text}` | **无资源 ID** | ❌ |
| `ai-proxy` → 对话计费 | `billTurn(conversationId, turnIndex)` | 存 `meta: {conversation_id, turn_index}` | **仅有 conversation_id** | ⚠️ 间接（需关联查询） |
| `ai-conversation` → 创建会话 | `createSession(sourceType, sourceCode)` | 无 usage_event（创建免费） | — | — |
| `ai-test-plan` → 出卷 | 传 `video_code` | 存 `meta: {video_code, title, config}` | **有 video_code** ✅ | ✅ |

**结论**：10 个收费点中，仅 `ai_test_plan` 记录了资源 ID，其余 9 个均缺失。

### 2.2 Flutter 端 `scene` 字段硬编码问题

当前 `AiService` 中 `scene` 全部硬编码为 `'player'`：

```dart
// ai_service.dart
scene: 'player',    // getDefinition - 硬编码
scene: 'player',    // translateText - 硬编码
scene: 'player',    // getTtsAudio - 硬编码
scene: 'conversation', // translateConversationText - 硬编码
```

实际上同一个 AI 释义功能可能在视频播放器、文章阅读器、生词本等多个场景中使用。

---

## 三、资源类型命名统一

### 3.1 现状不一致问题

当前系统中资源类型命名存在混乱：

| 模块 | 资源类型字段 | 视频的取值 | 文章的取值 | 音频的取值 |
|------|------------|----------|----------|----------|
| `FolderContentType` 枚举 | `folderType.name` | `video` | `article` | `music` |
| `WordBook.sourceType` | string | `video` | `article` | `music` |
| `file_list_page._resourceTypes` | string list | `video` | `article` | `music` |
| `ConversationPage.sourceType` | string | **`subtitle`** ⚠️ | `article` | — |
| `ai-conversation` Edge Function | `source_type` | **`subtitle`** ⚠️ | `article` | — |
| `ai-test-plan` Edge Function | meta 中 | `video_code`（字段名不统一） | — | — |

**核心问题**：`ConversationPage` 和 `ai-conversation` Edge Function 中用 `subtitle` 表示视频资源，而系统其他地方统一用 `video`。

### 3.2 统一方案

**计费体系中的 `source_type` 统一使用三类资源名**，与 `FolderContentType` 保持一致：

| source_type 值 | 含义 | 对应资源模型 | 唯一编码字段 |
|---------------|------|------------|-------------|
| `video` | 视频 | `VideoInfo` | `code` |
| `article` | 文章 | `Article` | `code` |
| `music` | 音频/歌曲 | `VideoInfo`（folderType=music） | `code` |

**对 ConversationPage 的处理**：
- `ConversationPage.sourceType` 仍保留 `subtitle` / `article`（这是对话引擎类型，不改动）
- 在调用 AI 计费时，**将 `subtitle` 映射为 `video`**，统一写入 `usage_event.meta.source_type`

```dart
// conversation_service.dart - billTurn 中
String _mapSourceType(String conversationSourceType) {
  switch (conversationSourceType) {
    case 'subtitle': return 'video';
    default: return conversationSourceType; // article 保持不变
  }
}
```

**对 ai-test-plan 的处理**：
- 现有 `video_code` 字段保留不动
- 在 meta 中补充统一的 `source_type: 'video'` 和 `source_code` 字段

### 3.3 额外场景的 source_type

除三大资源外，以下场景也需要标记来源：

| source_type 值 | 含义 | source_code |
|---------------|------|-------------|
| `wordbook` | 生词本中查词 | 单词的 source_code（追溯到原资源） |
| `test` | 测试中产生 | 关联的视频/文章 code |

这些属于"衍生场景"，source_code 仍指向原始资源，统计时归入原始资源。

---

## 四、调用协议与 Edge Function 改造

### 4.1 调用协议增强

**在请求体中新增 `source_type` 和 `source_code` 两个可选字段**，取值统一使用 §3.2 定义：

```json
{
  "rule_code": "ai_definition",
  "scene": "player",
  "entry": "subtitle_tap",
  "request_id": "uuid-v4",
  "source_type": "video",              // 新增：资源类型
  "source_code": "friends_s01e01",     // 新增：资源编码
  "params": {
    "word": "unprecedented",
    "sentence": "This warming is unprecedented in modern history."
  }
}
```

**字段定义**：

| 字段 | 类型 | 必填 | 说明 | 可选值 |
|------|------|------|------|--------|
| `source_type` | string | 否 | 学习资源类型（统一命名） | `video` / `article` / `music` / `wordbook` / `test` |
| `source_code` | string | 否 | 资源唯一编码 | 视频 code / 文章 code / 会话 ID 等 |

**为什么设为可选**：部分场景（如生词本中查一个收藏的单词）可能没有明确的资源上下文，不强制要求传入。

### 4.2 Edge Function 改造

#### 4.2.1 `ai-proxy/index.ts` 改造

在解析请求体时提取 `source_type` 和 `source_code`，写入 `usage_event.meta`：

```typescript
// 解析请求体（新增 source_type, source_code）
const {
  rule_code: ruleCode,
  scene,
  entry,
  request_id: requestId,
  source_type: sourceType,    // 新增
  source_code: sourceCode,    // 新增
  params = {},
} = body

// 扣费时 meta 合并资源标识
const meta = {
  word: params.word,
  sentence: params.sentence,
  text: params.text,
  source_type: sourceType,    // 新增
  source_code: sourceCode,    // 新增
}
```

**改动范围**：仅 `deduct()` 调用处增加 `source_type` / `source_code` 到 meta。
**对现有逻辑零影响**：meta 是 JSONB 类型，新增字段不影响已有查询。

#### 4.2.2 `ai-proxy/index.ts` — 对话计费路由改造

对话的 question/answer/settle 路由中，meta 已有 `conversation_id`，需要补充 `source_type`：

```typescript
// 对话计费路由
const newBalance = await deduct(
  userId, ruleCode, scene, entry, requestId, rule.priceCny, balance,
  {
    conversation_id: params.conversation_id,
    turn_index: params.turn_index,
    turn_count: params.turn_count,
    duration_seconds: params.duration_seconds,
    source_type: sourceType,    // 新增
    source_code: sourceCode,    // 新增
  },
)
```

#### 4.2.3 `ai-conversation/index.ts` 改造

创建会话时已有 `source_type` 和 `source_code`，如果创建会话计费（当前价格为 0），需要将资源信息写入 meta：

```typescript
// 预扣费（当 createCost > 0 时）
const balanceAfter = createCost > 0
  ? await deductPrepay(userId, 'ai_conversation', createCost, balance, conversationId, {
      source_type: sourceType,     // 新增
      source_code: sourceCode,     // 新增
    })
  : balance
```

#### 4.2.4 `ai-test-plan/index.ts`

已有 `video_code`，只需在 meta 中统一字段命名：

```typescript
// 现有 meta 已有 video_code，补充 source_type
meta: {
  video_code: videoCode,           // 保留现有
  source_type: 'video',            // 新增统一字段
  source_code: videoCode,          // 新增统一字段
  title: storage.title,
  config: { ... },
  item_count: items.length,
}
```

### 4.3 Flutter 端改造

#### 4.3.1 `AiService` 改造

**核心改动**：所有方法增加 `sourceType` 和 `sourceCode` 参数，调用时传入。

```dart
/// 统一调用 ai-proxy Edge Function
static Future<WordCardData> callAiProxy({
  required String ruleCode,
  required String scene,
  required String entry,
  String? sourceType,        // 新增
  String? sourceCode,        // 新增
  Map<String, dynamic> params = const {},
}) async {
  // ...
  final body = {
    'rule_code': ruleCode,
    'scene': scene,
    'entry': entry,
    'request_id': requestId,
    'params': params,
    if (sourceType != null) 'source_type': sourceType,     // 新增
    if (sourceCode != null) 'source_code': sourceCode,     // 新增
  };
  // ...
}

/// 调用 AI 释义
static Future<WordCardData> getDefinition({
  required String word,
  String? sentence,
  String? sourceType,     // 新增
  String? sourceCode,     // 新增
}) async {
  return callAiProxy(
    ruleCode: 'ai_definition',
    scene: sourceType == 'article' ? 'reader' : 'player',
    entry: 'subtitle_tap',
    sourceType: sourceType,
    sourceCode: sourceCode,
    params: {'word': word, if (sentence != null) 'sentence': sentence},
  );
}

/// 调用 AI 翻译
static Future<WordCardData> translateText({
  required String text,
  String sourceLanguage = 'en',
  String targetLanguage = 'zh-Hans',
  String? sourceType,     // 新增
  String? sourceCode,     // 新增
}) async {
  return callAiProxy(
    ruleCode: 'ai_translate',
    scene: sourceType == 'article' ? 'reader' : 'player',
    entry: 'trans_btn',
    sourceType: sourceType,
    sourceCode: sourceCode,
    params: {'text': text, 'source_language': sourceLanguage, 'target_language': targetLanguage},
  );
}

/// 调用 AI TTS
static Future<Map<String, dynamic>?> getTtsAudio({
  required String text,
  String language = 'en-US',
  String? sourceType,     // 新增
  String? sourceCode,     // 新增
}) async {
  // ...
  body: {
    'rule_code': 'ai_tts',
    'scene': sourceType == 'article' ? 'reader' : 'player',
    'entry': 'tts_btn',
    'request_id': requestId,
    if (sourceType != null) 'source_type': sourceType,
    if (sourceCode != null) 'source_code': sourceCode,
    'params': {'text': text, 'language': language},
  },
  // ...
}
```

#### 4.3.2 `translateConversationText` 改造

```dart
static Future<String?> translateConversationText({
  required String text,
  String? sourceType,     // 新增
  String? sourceCode,     // 新增
}) async {
  // ...
  body: {
    'rule_code': 'ai_translate_conversation',
    'scene': 'conversation',
    'entry': 'translate_reply',
    'request_id': requestId,
    if (sourceType != null) 'source_type': sourceType,
    if (sourceCode != null) 'source_code': sourceCode,
    'params': {'text': text},
  },
  // ...
}
```

#### 4.3.3 `ConversationService` 改造

对话计费（`billTurn`）需要传入资源信息：

```dart
static Future<void> billTurn({
  required String conversationId,
  required int turnIndex,
  required bool isQuestion,
  String? sourceType,     // 新增
  String? sourceCode,     // 新增
}) async {
  // ...
  body: {
    'rule_code': ruleCode,
    'scene': 'conversation',
    'entry': isQuestion ? 'question' : 'answer',
    'request_id': requestId,
    if (sourceType != null) 'source_type': sourceType,
    if (sourceCode != null) 'source_code': sourceCode,
    'params': {'conversation_id': conversationId, 'turn_index': turnIndex},
  },
  // ...
}
```

#### 4.3.4 调用方（播放器/阅读器）改造

播放器页面调用 AI 时，传入当前视频的 code：

```dart
// player_page.dart

/// 付费模式：AI 释义
Future<WordCardData> _lookupWordPremium(String word) async {
  return AiService.getDefinition(
    word: word,
    sourceType: 'video',
    sourceCode: widget.videoCode,   // 传入视频编码
  );
}

/// 单词朗读
Future<void> _speakSelectedWord(String word) async {
  // ...
  final result = await AiService.getTtsAudio(
    text: word,
    sourceType: 'video',
    sourceCode: widget.videoCode,   // 传入视频编码
  );
  // ...
}

/// 清晰朗读
Future<void> _speakClarityPremium(String text, ...) async {
  final result = await AiService.getTtsAudio(
    text: text,
    sourceType: 'video',
    sourceCode: widget.videoCode,   // 传入视频编码
  );
  // ...
}
```

文章阅读器、生词本等其他调用方同理。

---

## 五、AI 功能分类体系

### 4.1 分类定义

| 分类编码 | 用户展示名 | 图标建议 | 包含的 rule_code | 说明 |
|---------|----------|---------|-----------------|------|
| `translate` | 翻译 | 🌐 | `ai_translate`, `ai_translate_conversation` | 句子翻译、对话翻译 |
| `tts` | AI 发音 | 🔊 | `ai_tts` | AI 语音合成朗读 |
| `conversation` | AI 对话 | 💬 | `ai_conversation`, `ai_conversation_question`, `ai_conversation_answer`, `ai_conversation_settle` | 口语练习对话 |
| `lookup` | 智能查词 | 🔍 | `ai_definition`, `ai_word_link` | 单词释义 + 词联网络 |
| `evaluate` | 评测与测试 | 📝 | `ai_evaluate`, `ai_test_plan` | 发音评分 + AI 出卷 |

### 4.2 分类映射表（服务端配置）

在 `app_settings` 中新增一条配置，供前端查询用于展示分组：

```sql
INSERT INTO app_settings (key, value, description) VALUES
('billing_category_map', '{
  "translate":    {"name_zh": "翻译",     "rule_codes": ["ai_translate", "ai_translate_conversation"]},
  "tts":          {"name_zh": "AI 发音",  "rule_codes": ["ai_tts"]},
  "conversation": {"name_zh": "AI 对话",  "rule_codes": ["ai_conversation", "ai_conversation_question", "ai_conversation_answer", "ai_conversation_settle"]},
  "lookup":       {"name_zh": "智能查词", "rule_codes": ["ai_definition", "ai_word_link"]},
  "evaluate":     {"name_zh": "评测与测试","rule_codes": ["ai_evaluate", "ai_test_plan"]}
}', '账单功能分类映射表');
```

---

## 六、聚合统计 Edge Function 设计

### 5.1 新增函数：`usage-stats`

```
supabase/functions/usage-stats/index.ts
```

**功能**：根据用户 ID、时间范围、聚合维度，查询 `usage_event` 并返回统计结果。

### 5.2 请求协议

```json
{
  "mode": "overview" | "by_source" | "by_category" | "source_detail" | "category_detail",
  "from": "2026-06-01T00:00:00Z",
  "to": "2026-06-30T23:59:59Z",
  "source_type": "video",          // 仅 source_detail / by_source 时需要
  "source_code": "friends_s01e01", // 仅 source_detail 时需要
  "category": "translate"          // 仅 category_detail 时需要
}
```

### 5.3 各模式返回格式

#### mode=overview（总览）

按功能分类聚合，用于饼图/柱状图：

```json
{
  "ok": true,
  "total_cost_cny": 45.20,
  "total_count": 1230,
  "categories": [
    {"category": "translate",    "name_zh": "翻译",     "cost_cny": 15.82, "count": 527, "percentage": 35.0},
    {"category": "tts",          "name_zh": "AI 发音",  "cost_cny": 9.04,  "count": 452, "percentage": 20.0},
    {"category": "conversation", "name_zh": "AI 对话",  "cost_cny": 11.30, "count": 113, "percentage": 25.0},
    {"category": "lookup",       "name_zh": "智能查词", "cost_cny": 5.44,  "count": 98,  "percentage": 12.0},
    {"category": "evaluate",     "name_zh": "评测与测试","cost_cny": 3.60,  "count": 40,  "percentage": 8.0}
  ],
  "daily_trend": [
    {"date": "2026-06-01", "cost_cny": 1.50},
    {"date": "2026-06-02", "cost_cny": 2.30}
  ]
}
```

#### mode=by_source（按资源聚合）

按资源类型 → 具体资源列出消费：

```json
{
  "ok": true,
  "sources": [
    {
      "source_type": "video",
      "source_type_zh": "视频",
      "items": [
        {"source_code": "friends_s01e01", "source_title": "Friends S01E01", "cost_cny": 8.35, "count": 230},
        {"source_code": "ted_how_to_speak", "source_title": "TED - How to speak", "cost_cny": 5.20, "count": 145}
      ],
      "subtotal_cny": 13.55
    },
    {
      "source_type": "article",
      "source_type_zh": "文章",
      "items": [
        {"source_code": "economist_ai", "source_title": "The Economist - AI", "cost_cny": 3.80, "count": 95}
      ],
      "subtotal_cny": 3.80
    }
  ],
  "unknown_source_cost_cny": 0.50
}
```

#### mode=source_detail（单资源详情）

查看某个资源下各功能花费：

```json
{
  "ok": true,
  "source_type": "video",
  "source_code": "friends_s01e01",
  "source_title": "Friends S01E01",
  "total_cost_cny": 8.35,
  "total_count": 230,
  "by_category": [
    {"category": "translate",    "name_zh": "翻译",      "cost_cny": 1.38, "count": 46},
    {"category": "tts",          "name_zh": "AI 发音",   "cost_cny": 0.64, "count": 32},
    {"category": "conversation", "name_zh": "AI 对话",   "cost_cny": 3.00, "count": 30},
    {"category": "lookup",       "name_zh": "智能查词",  "cost_cny": 1.55, "count": 85},
    {"category": "evaluate",     "name_zh": "评测与测试", "cost_cny": 0.80, "count": 12}
  ],
  "daily": [
    {"date": "2026-06-10", "cost_cny": 2.10, "count": 58},
    {"date": "2026-06-11", "cost_cny": 3.50, "count": 95},
    {"date": "2026-06-13", "cost_cny": 2.75, "count": 77}
  ]
}
```

#### mode=by_category（按功能分类聚合）

```json
{
  "ok": true,
  "categories": [
    {
      "category": "translate",
      "name_zh": "翻译",
      "total_cost_cny": 15.82,
      "total_count": 527,
      "by_source": [
        {"source_type": "video", "source_code": "friends_s01e01", "source_title": "Friends S01E01", "cost_cny": 3.20, "count": 106},
        {"source_type": "video", "source_code": "ted_how_to_speak", "source_title": "TED", "cost_cny": 2.10, "count": 70}
      ]
    }
  ]
}
```

#### mode=category_detail（单功能详情）

```json
{
  "ok": true,
  "category": "translate",
  "name_zh": "翻译",
  "total_cost_cny": 15.82,
  "total_count": 527,
  "by_rule": [
    {"rule_code": "ai_translate", "name_zh": "AI翻译", "cost_cny": 14.40, "count": 480},
    {"rule_code": "ai_translate_conversation", "name_zh": "对话翻译", "cost_cny": 1.42, "count": 47}
  ],
  "daily": [
    {"date": "2026-06-01", "cost_cny": 0.45, "count": 15},
    {"date": "2026-06-02", "cost_cny": 0.72, "count": 24}
  ]
}
```

### 5.4 核心 SQL 查询

```sql
-- overview 模式：按功能分类聚合
SELECT
  ue.rule_code,
  pr.name_zh,
  COUNT(*) as count,
  SUM(ue.cost_cny) as cost_cny
FROM usage_event ue
LEFT JOIN pricing_rule pr ON pr.rule_code = ue.rule_code
WHERE ue.user_id = $1
  AND ue.created_at >= $2
  AND ue.created_at <= $3
GROUP BY ue.rule_code, pr.name_zh;

-- by_source 模式：按资源聚合
SELECT
  ue.meta->>'source_type' as source_type,
  ue.meta->>'source_code' as source_code,
  COUNT(*) as count,
  SUM(ue.cost_cny) as cost_cny
FROM usage_event ue
WHERE ue.user_id = $1
  AND ue.created_at >= $2
  AND ue.created_at <= $3
  AND ue.meta->>'source_code' IS NOT NULL
GROUP BY ue.meta->>'source_type', ue.meta->>'source_code';

-- source_detail 模式：单资源下按功能分类
SELECT
  ue.rule_code,
  pr.name_zh,
  COUNT(*) as count,
  SUM(ue.cost_cny) as cost_cny
FROM usage_event ue
LEFT JOIN pricing_rule pr ON pr.rule_code = ue.rule_code
WHERE ue.user_id = $1
  AND ue.created_at >= $2
  AND ue.created_at <= $3
  AND ue.meta->>'source_code' = $4
GROUP BY ue.rule_code, pr.name_zh;
```

---

## 七、前端账单页面设计

### 6.1 页面结构

```
Profile（我的）
└── 消费明细页面
    ├── 时间范围选择器（本周 / 本月 / 近三月 / 自定义）
    ├── Tab 1：功能维度
    │   ├── 总览（饼图 + 总额 + 日趋势柱状图）
    │   └── 各功能卡片（点击 → 功能详情列表）
    └── Tab 2：资源维度
        ├── 按资源大类折叠列表（视频 / 文章 / 音频）
        │   └── 各资源卡片（名称 + 金额）
        └── 点击资源 → 资源详情（各功能花费 + 日明细 + 合计）
```

### 6.2 总览页 UI 布局

```
┌──────────────────────────────────┐
│  ← 消费明细            [本月 ▾]  │
├──────────────────────────────────┤
│                                  │
│  本月消费                         │
│  ¥45.20                         │
│                                  │
│  ┌──── 饼图 ────┐                │
│  │ 翻译 35%     │                │
│  │ TTS 20%      │                │
│  │ 对话 25%     │                │
│  │ 查词 12%     │                │
│  │ 评测 8%      │                │
│  └──────────────┘                │
│                                  │
│  ┌──── 日趋势柱状图 ────┐        │
│  │ ▌▌  ▌▌▌  ▌▌  ▌     │        │
│  │ 1  2  3  4  5  ...  │        │
│  └──────────────────────┘        │
│                                  │
├──────────────────────────────────┤
│  功能分类                        │
│  ┌─────────────────────────────┐ │
│  │ 🌐 翻译          ¥15.82  > │ │
│  │ 💬 AI 对话       ¥11.30  > │ │
│  │ 🔊 AI 发音        ¥9.04  > │ │
│  │ 🔍 智能查词       ¥5.44  > │ │
│  │ 📝 评测与测试     ¥3.60  > │ │
│  └─────────────────────────────┘ │
│                                  │
│  资源统计                        │
│  ┌─────────────────────────────┐ │
│  │ 📹 视频 (3个)    ¥13.55  > │ │
│  │ 📖 文章 (2篇)     ¥3.80  > │ │
│  │ ⚠️ 未关联         ¥0.50    │ │
│  └─────────────────────────────┘ │
└──────────────────────────────────┘
```

### 6.3 资源详情页 UI 布局

```
┌──────────────────────────────────┐
│  ← Friends S01E01               │
├──────────────────────────────────┤
│                                  │
│  累计消费              ¥8.35     │
│                                  │
│  ┌─────────────────────────────┐ │
│  │ 🌐 翻译     46次    ¥1.38   │ │
│  │ 🔊 AI 发音  32次    ¥0.64   │ │
│  │ 💬 AI 对话  3次会话 ¥3.00   │ │
│  │ 🔍 智能查词 85次    ¥1.55   │ │
│  │ 📝 评测     12次    ¥0.80   │ │
│  ├─────────────────────────────┤ │
│  │ 合计      178次    ¥8.35   │ │
│  └─────────────────────────────┘ │
│                                  │
│  每日明细                        │
│  6月10日  翻译15次 查词20次 ¥1.05│
│  6月11日  对话1次 翻译23次 ¥3.69│
│  6月13日  查词12次 TTS8次  ¥0.76│
└──────────────────────────────────┘
```

---

## 八、`source_title` 的获取策略

### 7.1 问题

`usage_event.meta` 中只存 `source_code`（编码），但展示时需要显示资源标题（如 "Friends S01E01"）。

### 7.2 方案：在 `usage-stats` Edge Function 中关联查询

```sql
-- 视频标题：从 video_info 表查询
SELECT code, name FROM video_info WHERE code = ANY($1);

-- 文章标题：从 article 表查询
SELECT code, title FROM article WHERE code = ANY($1);

-- 对话标题：从 conversation_session 关联查询
SELECT id, source_type, source_code FROM conversation_session WHERE id = ANY($1);
```

**优点**：不冗余存储标题，始终取最新值。
**缺点**：需要额外关联查询，但数据量不大，性能可接受。

### 7.3 备选方案：meta 中冗余存储标题

如果后续发现关联查询性能不足，可以在 `deduct()` 时将标题写入 meta：

```typescript
meta: {
  source_type: sourceType,
  source_code: sourceCode,
  source_title: sourceTitle,    // 冗余存储（快照）
  // ...
}
```

**建议初期用关联查询方案**，后续视性能情况再决定是否冗余。

---

## 九、Profile 页面账单入口设计

### 9.1 位置：模式切换卡片内

账单入口与会员模式放在一起，避免产生割裂感。付费模式下，模式切换卡片增加“今日消费”展示：

**付费模式下的卡片布局：**

```
┌──────────────────────────────────────────┐
│  🏆 会员模式                         [切换] │
│  余额：¥9.87                              │
│                                            │
│  今日消费  ¥1.25            [详情 >] │
│                                            │
│  [充值]                                    │
└──────────────────────────────────────────┘
```

**免费模式下的卡片布局：**

```
┌──────────────────────────────────────────┐
│  👤 免费模式                         [切换] │
│                                            │
│  使用系统原生能力，不产生费用      │
└──────────────────────────────────────────┘
```

### 9.2 实现方式

在现有 `_buildModeSwitch` 方法中，付费模式下增加一行“今日消费”：

```dart
// 模式切换卡片内，付费模式额外显示
if (isPremium) ...[
  // 余额行（已有）
  Text('余额：¥${subState.balance.toStringAsFixed(2)}'),

  // 新增：今日消费行
  Row(
    children: [
      Text('今日消费'),
      Spacer(),
      Text('¥${todayCost.toStringAsFixed(2)}'),
      SizedBox(width: 8),
      GestureDetector(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const BillingDetailPage())),
        child: Text('详情', style: TextStyle(color: Colors.amber)),
      ),
      Icon(Icons.chevron_right, color: Colors.amber, size: 16),
    ],
  ),
],
```

“今日消费”数据来源：启动时或切换到付费模式时，调用 `usage-stats` 接口查询当天消费总额。

### 9.3 Profile 页面完整布局（付费模式）

```
┌──────────────────────────────────┐
│  我的                                    │
├──────────────────────────────────┤
│  👤 昵称                                    │
│     登录名                              >│
│                                          │
│  ┌─────────────────────────────────┐  │
│  │ 🏆 会员模式                 [切换] │  │
│  │ 余额：¥9.87                          │  │
│  │ 今日消费 ¥1.25        [详情 >] │  │
│  │ [充值]                              │  │
│  └─────────────────────────────────┘  │
│                                          │
│  学习统计                              │
│  [学习天数] [视频] [音频] [文章]  >│
│                                          │
│  设置                                    │
│  🎨 外观设置           跟随系统      >│
│  ⚡ 学习难度           中级          >│
│  👥 用户设置           密码修改      >│
│  ⚙️ 播放设置           跳过片头      >│
│  🌐 翻译与TTS          配置翻译      >│
│  📝 测试设置           题目类型      >│
├──────────────────────────────────┤
│  ℹ️ 关于                 VidLang v1.0 >│
│  🚪 退出登录                                │
└──────────────────────────────────┘
```

---

## 十、账单详情页设计

### 10.1 页面入口与默认行为

| 入口 | 默认时间范围 | 说明 |
|------|------------|------|
| Profile → 模式切换卡片 → “详情” | **今日** | 快捷入口，看当天消费 |
| Profile → 充值按钮 → 充值明细 | **全部** | 充值记录列表 |

### 10.2 计费规则入口

在消费明细页面顶部增加“计费规则”入口，用户可随时查看各项 AI 功能的单价，自行估算消费是否准确：

```
┌──────────────────────────────────┐
│  ← 消费明细       [今日 ▾] [功能|资源] │
│  计费规则 >                           │
├──────────────────────────────────┤
│  ...                                  │
└──────────────────────────────────┘
```

### 10.3 账单详情页布局

默认显示当日消费，支持切换时间范围和功能/资源两种视图：

```
┌──────────────────────────────────┐
│  ← 消费明细       [今日 ▾] [功能|资源] │
├──────────────────────────────────┤
│                                          │
│  今日消费                                │
│  ¥1.25                                    │
│                                          │
│  ┌──── 饼图/柱状图 ────┐          │
│  │  查词 45% 翻译 30%    │          │
│  │  TTS 15%  对话 10%   │          │
│  └──────────────────────┘          │
│                                          │
│  ─── 功能维度视图 ───                │
│  ┌─────────────────────────────────┐  │
│  │ 🔍 智能查词   38次   ¥0.56     │  │
│  │ 🌐 翻译          22次   ¥0.38     │  │
│  │ 🔊 AI 发音     12次   ¥0.12     │  │
│  │ 💬 AI 对话     1次    ¥0.02     │  │
│  │ 📝 评测          2次    ¥0.10     │  │
│  ├─────────────────────────────────┤  │
│  │ 合计           75次   ¥1.25     │  │
│  └─────────────────────────────────┘  │
└──────────────────────────────────┘
```

### 10.4 时间范围切换

| 选项 | 说明 |
|------|------|
| 今日 | 当天消费（默认） |
| 本周 | 本周一至今 |
| 本月 | 本月 1 日至今 |
| 近三月 | 最近 90 天 |
| 自定义 | 选择开始/结束日期 |

### 10.5 视图切换

#### 功能维度视图（默认）

按五大 AI 功能分类展示，点击某功能可下钻：

```
功能列表 → 点击“翻译” → 翻译功能详情
┌──────────────────────────────────┐
│  ← 翻译 · 今日                         │
├──────────────────────────────────┤
│  翻译消费      ¥0.38                   │
│                                          │
│  按规则：                                │
│  AI翻译        20次   ¥0.30         │
│  对话翻译     2次    ¥0.08         │
│                                          │
│  按资源：                                │
│  Friends S01E01  12次  ¥0.18      │
│  TED Talk           8次   ¥0.12       │
│  未关联              2次   ¥0.08      │
│                                          │
│  时间明细：                              │
│  09:15  AI翻译  Friends S01E01  ¥0.03│
│  09:18  AI翻译  Friends S01E01  ¥0.03│
│  10:30  对话翻译 TED Talk         ¥0.04│
│  ...                                       │
└──────────────────────────────────┘
```

#### 资源维度视图

按资源大类折叠，展开后显示各资源：

```
┌──────────────────────────────────┐
│  📹 视频 (3个)               ¥0.98  │
│    Friends S01E01         ¥0.56   │
│    TED Talk                  ¥0.30   │
│    BBC News                 ¥0.12   │
│                                          │
│  📖 文章 (1篇)              ¥0.20  │
│    The Economist           ¥0.20   │
│                                          │
│  ⚠️ 未关联                   ¥0.07  │
│                                          │
│  ────────────────────────          │
│  合计                              ¥1.25  │
└──────────────────────────────────┘
```

点击某个资源，显示该资源下各功能消费交叉统计：

```
┌──────────────────────────────────┐
│  ← Friends S01E01                     │
├──────────────────────────────────┤
│  累计消费      ¥0.56                   │
│                                          │
│  🔍 智能查词   20次   ¥0.28       │
│  🌐 翻译          12次   ¥0.18       │
│  🔊 AI 发音     5次    ¥0.05       │
│  💬 AI 对话     0次    ¥0.00       │
│  📝 评测          1次    ¥0.05       │
│  ────────────────────────          │
│  合计           38次   ¥0.56       │
└──────────────────────────────────┘
```

---

## 十一、计费规则页设计

### 11.1 入口位置

计费规则页可从两个地方进入，确保用户随时可查看：

| 入口 | 场景 |
|------|------|
| 消费明细页 → 顶部“计费规则 >” | 查看消费后想核实单价 |
| 充值页面 → 底部“计费规则 >” | 充值前想了解消费水平 |

### 11.2 页面布局

直接从 `pricing_rule` 表读取数据（status=active），按功能分类展示：

```
┌──────────────────────────────────┐
│  ← 计费规则                            │
├──────────────────────────────────┤
│                                          │
│  以下为各项 AI 功能的单次使用费用：  │
│                                          │
│  ─── 智能查词 ───                │
│  AI释义      查单词释义/音标  ¥0.01/次│
│  AI词联      联想相关词汇     ¥0.02/次│
│                                          │
│  ─── 翻译 ───                      │
│  AI翻译      句子/段落翻译   ¥0.03/次│
│  对话翻译   对话中翻译回复   ¥0.03/次│
│                                          │
│  ─── AI 发音 ───                    │
│  AI发音      AI语音合成朗读 ¥0.02/次│
│                                          │
│  ─── AI 对话 ───                    │
│  创建会话   创建口语对话   ¥0.00/次│
│  提问          用户每次提问   ¥0.01/次│
│  回答          AI每次回答     ¥0.01/次│
│  结算          会话结束结算   ¥0.00/次│
│                                          │
│  ─── 评测与测试 ───              │
│  AI评测      发音评分          ¥0.05/次│
│  AI出卷      生成测试卷子   ¥0.10/次│
│                                          │
│  ℹ️ 价格可能调整，以实际扣费为准  │
└──────────────────────────────────┘
```

### 11.3 数据来源

```dart
/// 从 Supabase 查询计费规则
final response = await supabase
    .from('pricing_rule')
    .select('rule_code, name_zh, description_zh, price_cny')
    .eq('status', 'active')
    .order('price_cny', ascending: true);
```

前端按功能分类（复用 `billing_category_map` 配置）分组展示。

### 11.4 设计要点

1. **只读展示**：用户只能查看，不能编辑
2. **实时数据**：从 `pricing_rule` 表实时查询，后台调价后自动反映
3. **简洁直观**：每条规则显示名称 + 简要描述 + 单价，不需要复杂的表格
4. **底部提示**：说明价格可能调整，以实际扣费为准

---

## 十二、充值与内购设计

> **本期仅实现 UI 界面，不对接实际支付。** 充值涉及平台税、折扣规则等复杂逻辑，后续单独实施。

### 12.1 充值入口

充值功能放在 Profile 页面的模式切换卡片中（现有“充值”按钮位置不变）。

点击充值后进入**充值页面**，包含：
1. 当前余额展示
2. 充值档位选择（含优惠标签）
3. 充值按钮（本期为 UI 占位，不对接 IAP）
4. 充值明细入口
5. 计费规则入口

```
┌──────────────────────────────────┐
│  ← 充值                                    │
├──────────────────────────────────┤
│  当前余额     ¥9.87                    │
│                                          │
│  选择充值金额：                          │
│  ┌─────────────────────────────────┐  │
│  │ ¥10                                     │  │
│  └─────────────────────────────────┘  │
│  ┌─────────────────────────────────┐  │
│  │ ¥50            热门          │  │
│  └─────────────────────────────────┘  │
│  ┌─────────────────────────────────┐  │
│  │ ¥100    打 9.5 折 实付 ¥95│  │
│  └─────────────────────────────────┘  │
│                                          │
│  [确认充值 ¥50]                        │
│                                          │
│  充值明细 >                            │
│  计费规则 >                            │
└──────────────────────────────────┘
```

### 12.2 充值规则（后续实现）

充值将做成规则化配置，包含以下维度：

| 配置项 | 说明 | 示例 |
|------|------|------|
| `original_amount` | 充值面值 | ¥100 |
| `discount_rate` | 折扣率（1.0 = 无折扣） | 0.95（打 9.5 折） |
| `actual_amount` | 用户实际支付金额 | ¥95 |
| `bonus_amount` | 额外赠送金额 | ¥0 |
| `platform_tax_rate` | 平台税率（苹果税 30% / Google 15-30%） | 0.30 |
| `net_amount` | 实际到账金额（扣除平台税后） | ¥66.50 |
| `label` | 展示标签 | “热门” / “最划算” / “限时赠送” |
| `status` | 状态 | active / inactive |

**示例配置：**

| 面值 | 折扣 | 实付 | 赠送 | 平台税(30%) | 实际到账 | 标签 |
|------|------|------|------|------------|----------|------|
| ¥10 | 1.0 | ¥10 | ¥0 | ¥3 | ¥7 | 体验 |
| ¥50 | 1.0 | ¥50 | ¥0 | ¥15 | ¥35 | 热门 |
| ¥100 | 0.95 | ¥95 | ¥0 | ¥28.5 | ¥66.5 | 最划算 |

> 具体折扣策略、赠送规则待确定，本期先做 UI 界面，规则配置后续实现。

### 12.3 平台支付策略

| 平台 | 支付方式 | 实现 |
|------|---------|------|
| iOS | StoreKit IAP | `in_app_purchase` 插件，Apple 强制走 IAP |
| Android (Google Play) | Google Play Billing | `in_app_purchase` 插件，Google 强制走 Play Billing |
| Android (APK 侧载) | 支付宝 H5 | Edge Function 中转，备选方案 |

### 12.4 充值明细页

充值明细作为充值页面的子页面，不与消费明细混在一起：

```
┌──────────────────────────────────┐
│  ← 充值明细                            │
├──────────────────────────────────┤
│  累计充值     ¥60.00                   │
│                                          │
│  2026-06-13 10:30                     │
│  ¥50.00    Apple IAP    ✅ 成功  │
│                                          │
│  2026-06-07 14:20                     │
│  ¥10.00    系统赠送    ✅ 新用户  │
│                                          │
└──────────────────────────────────┘
```

数据来源：`wallet_ledger` 表中 `type = 'topup'` 的记录。

### 12.5 充值流程（后续实现）

```
Flutter 用户点击充值
    ↓
调用 in_app_purchase 发起购买
（iOS: StoreKit / Android: Google Play Billing）
    ↓
支付成功，拿到 purchaseToken / receipt
    ↓
supabase.functions.invoke('verify_purchase', {
  platform: 'app_store' | 'google_play',
  productId: 'topup_50',
  token: purchaseToken,
})
    ↓
Edge Function 向 Apple/Google 服务器验证收据
    ↓
验证通过 →
  INSERT wallet_ledger (type='topup', amount=50, channel='iap')
  UPDATE user_wallet SET balance_cny = balance_cny + 50
    ↓
返回成功 → Flutter 刷新余额 UI
```

### 12.6 充值相关的 Edge Function（后续实现）

新增 `verify-purchase` Edge Function：

```
supabase/functions/verify-purchase/index.ts
```

职责：
1. 接收客户端传入的 `platform`、`productId`、`token`
2. 向 Apple/Google 服务器验证收据真实性
3. 幂等校验（同一 token 不重复入账）
4. 写入 `wallet_ledger` + 更新 `user_wallet` 余额
5. 返回入账结果

---

## 十二、改造实施清单

### 12.1 Edge Function 改造

| # | 文件 | 改动内容 | 优先级 | 难度 |
|---|------|---------|------|------|
| 1 | `ai-proxy/index.ts` | 提取 `source_type`/`source_code`，写入 deduct meta | P0 | 低 |
| 2 | `ai-proxy/index.ts` — 对话路由 | 对话计费 meta 补充 `source_type`/`source_code` | P0 | 低 |
| 3 | `ai-conversation/index.ts` | 预扣费 meta 补充资源信息（当前价格为 0，暂不急） | P1 | 低 |
| 4 | `ai-test-plan/index.ts` | meta 中统一 `source_type`/`source_code` 字段 | P0 | 低 |
| 5 | **新增** `usage-stats/index.ts` | 聚合查询接口（5 种模式） | P1 | 中 |
| 6 | **新增** `verify-purchase/index.ts` | 充值收据验证 + 入账 | P2 | 中 |

### 12.2 Flutter 端改造

| # | 文件 | 改动内容 | 优先级 | 难度 |
|---|------|---------|------|------|
| 7 | `lib/services/ai_service.dart` | 所有方法增加 `sourceType`/`sourceCode` 参数 | P0 | 低 |
| 8 | `lib/services/conversation_service.dart` | `billTurn` 增加资源参数，添加 sourceType 映射 | P0 | 低 |
| 9 | `lib/views/player/player_page.dart` | 调用 AI 时传入 `widget.videoCode` | P0 | 低 |
| 10 | 文章阅读器（待实现） | 调用 AI 时传入 `articleCode` | P2 | 低 |
| 11 | 生词本（待实现） | 调用 AI 时传入资源来源信息 | P2 | 低 |
| 12 | **修改** `lib/views/profile/profile_page.dart` | 模式切换卡片增加“今日消费”展示 | P1 | 低 |
| 13 | **新增** `lib/models/usage_stats.dart` | 统计结果数据模型 | P1 | 低 |
| 14 | **新增** `lib/services/usage_stats_service.dart` | 调用 usage-stats Edge Function | P1 | 低 |
| 15 | **新增** 消费明细页面 | 饼图/柱状图 + 功能/资源双视图 + 下钻 | P1 | 中 |
| 16 | **新增** 充值页面 | 档位选择 + IAP 调用 | P2 | 中 |
| 17 | **新增** 充值明细页面 | wallet_ledger 充值记录列表 | P2 | 低 |

### 12.3 数据库改造

| # | 内容 | 优先级 | 说明 |
|---|------|------|------|
| 18 | `app_settings` 插入 `billing_category_map` | P1 | 功能分类映射配置 |
| 19 | **无需改表结构** | — | `usage_event.meta` JSONB 天然支持扩展 |

### 12.4 实施优先级

```
P0（立即 - 资源标识补齐）：
├── #1-2  Edge Function 补齐 source_type/source_code
├── #4    ai-test-plan 统一字段
├── #7-9  Flutter 端补齐资源参数传递
└── 预期效果：新产生的 usage_event 均包含资源标识

P1（近期 - 账单展示）：
├── #5    新增 usage-stats Edge Function
├── #12   Profile 模式切换卡片增加今日消费
├── #13-14 统计模型与服务
├── #15   消费明细页面
├── #18   插入功能分类配置
└── 预期效果：用户可查看消费明细（双维度聚合）

P2（后续 - 充值与完善）：
├── #3    ai-conversation 预扣费补充资源信息
├── #6    新增 verify-purchase Edge Function
├── #10-11 文章阅读器、生词本接入资源参数
├── #16-17 充值页面与充值明细
└── 预期效果：完整的充值 + 消费闭环
```

---

## 十三、向后兼容

### 13.1 历史数据处理

改造前产生的 `usage_event` 记录中 `meta` 没有 `source_type`/`source_code`，在统计中会归类为“未关联”资源。

**展示处理**：账单页面的资源列表中增加一个“未关联”分类，显示无法归类的消费金额。随着时间推移，未关联的比例会自然降低。

### 13.2 接口兼容

- `source_type` 和 `source_code` 为可选参数，旧版本客户端不传不影响扣费
- `usage-stats` 为新增接口，不影响现有功能

---

## 十四、总结

本改造方案的核心思路是 **“只加不改”**：

1. **不改表结构**：利用现有 `meta` JSONB 字段扩展
2. **不改扣费逻辑**：`billing.ts` 完全不动
3. **不改现有接口协议**：新增字段为可选，向后兼容
4. **资源命名统一**：计费体系统一使用 `video`/`article`/`music`，与 FolderContentType 一致
5. **只加资源标识传递**：从 Flutter → Edge Function → usage_event.meta 全链路打通
6. **只加展示层**：账单入口嵌入 Profile 模式切换卡片，不单独开页面
7. **充值独立闭环**：充值明细与消费明细分开，通过 Profile 充值按钮进入

改动量低、风险可控、体验统一。
