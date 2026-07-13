# AI 计费体系与 Edge Function 架构设计

> 状态：草案（已精简确认，待实施）
> 更新：2026-06-07

---

## 一、设计原则

1. **预付费制**：无每月免费次数，仅靠初始赠送余额 + 充值消费
2. **规则表纯计费**：`pricing_rule` 只描述计费规则，不绑定运行场景
3. **运行时数据进消费表**：`scene/entry/action` 由客户端调用时传入，记录在 `usage_event`
4. **价格预设**：初始价格较低，方便多轮测试，后期通过修改规则表调整
5. **API Key 隐藏**：所有 AI API Key 存储在 Supabase Edge Function 环境变量 / `app_settings` 中

---

## 二、Supabase 数据库设计

> 精简原则：去掉派生字段、去掉初期用不到的表、充值记录合并到流水表。

最终 **5 张表**：

### 2.1 `pricing_rule` — 计费规则表

```sql
CREATE TABLE pricing_rule (
  id BIGSERIAL PRIMARY KEY,
  rule_code TEXT UNIQUE NOT NULL,         -- 规则唯一编码，如 'ai_definition'
  name_zh TEXT NOT NULL,                   -- 中文名称，如 'AI释义'
  description_zh TEXT NOT NULL,            -- 中文详细描述，App 计费说明页展示
  model TEXT NOT NULL,                     -- 调用模型：qwen-plus / qwen-tts / shengtong
  price_cny NUMERIC(10,4) NOT NULL,        -- 单次消费金额（元）
  status TEXT NOT NULL DEFAULT 'active',   -- active / inactive
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 2.2 `usage_event` — 消费记录表

```sql
CREATE TABLE usage_event (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  rule_code TEXT NOT NULL,                 -- 关联 pricing_rule.rule_code
  scene TEXT NOT NULL,                     -- 运行时模块：player / wordbook / test_single / test_folder
  entry TEXT NOT NULL,                     -- 运行时入口：subtitle_tap / trans_btn / tts_btn / follow_panel / wordbook_card / test_quiz
  request_id TEXT UNIQUE NOT NULL,         -- 幂等键（客户端生成 UUID）
  cost_cny NUMERIC(10,4) NOT NULL,         -- 本次实际扣费（与规则表一致）
  meta JSONB DEFAULT '{}',                -- 额外信息：word / sentence / token_usage 等
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 2.3 `wallet_ledger` — 余额流水表（合并充值 + 消费 + 调整）

```sql
CREATE TABLE wallet_ledger (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  type TEXT NOT NULL,                      -- topup / consume / adjust / refund
  amount_cny NUMERIC(10,4) NOT NULL,       -- 充值为正，消费为负
  balance_after NUMERIC(10,4) NOT NULL,    -- 操作后余额
  channel TEXT,                            -- 仅 type=topup 时填写：system_grant / iap / alipay
  paid_at TIMESTAMPTZ,                     -- 仅 type=topup 时填写
  ref_id BIGINT,                           -- type=consume 关联 usage_event.id
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

> `wallet_ledger` 已合并原 `topup_record` 表，通过 `type='topup'` 过滤即可查询充值历史。

### 2.4 `user_wallet` — 用户钱包表（纯余额）

```sql
CREATE TABLE user_wallet (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) UNIQUE NOT NULL,
  balance_cny NUMERIC(10,4) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

> `total_topup_cny` / `total_consumed_cny` 已移除。需要时从 `wallet_ledger` 按 `SUM(amount_cny)` 聚合查询即可，避免数据不一致。

### 2.5 `app_settings` — 应用设置表

```sql
CREATE TABLE app_settings (
  id BIGSERIAL PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**初始数据：**

| key | value | description |
|-----|-------|-------------|
| `qwen_api_key` | `sk-xxx` | 通义千问 API Key |
| `qwen_base_url` | `https://dashscope.aliyuncs.com/compatible-mode/v1` | Qwen API 地址 |
| `shengtong_api_key` | `xxx` | 声通发音评分 API Key |
| `shengtong_app_id` | `xxx` | 声通 App ID |
| `default_new_user_balance` | `10.00` | 新用户注册默认赠送余额（元） |

---

## 三、初始计费规则

| rule_code | name_zh | description_zh | model | price_cny |
|-----------|---------|---------------|-------|-----------|
| `ai_definition` | AI释义 | 查询单词的详细释义、例句、音标 | qwen-plus | ¥0.01 |
| `ai_translate` | AI翻译 | 调用通义千问进行句子/段落翻译 | qwen-plus | ¥0.03 |
| `ai_tts` | AI发音 | 调用通义千问 TTS 进行 AI 语音合成，朗读单词或句子 | qwen-tts | ¥0.02 |
| `ai_word_link` | AI词联 | 根据上下文联想关联词汇、近义词、反义词 | qwen-plus | ¥0.02 |
| `ai_evaluate` | AI评测 | 调用声通对跟读录音进行发音评分 | shengtong | ¥0.05 |

> 说明：`ai_word_link` 和 `ai_evaluate` 本次视频播放器改造暂不涉及，后续文章跟读、生词本等模块再启用。

---

## 四、Edge Function 架构

### 4.1 目录结构

```
supabase/functions/
├── ai-proxy/
│   ├── index.ts           -- 主入口：鉴权 / 计费预检 / 路由
│   ├── billing.ts         -- 计费公共逻辑：查余额、扣费、写记录
│   ├── clients/
│   │   ├── qwen-chat.ts   -- Qwen Chat API（翻译、释义、词联）
│   │   ├── qwen-tts.ts    -- Qwen TTS API（语音合成）
│   │   └── shengtong.ts   -- 声通发音评分 API
│   └── deno.json          -- 依赖配置（可选）
└── _shared/
    └── cors.ts             -- CORS 公共模块
```

### 4.2 调用协议

**客户端 → Edge Function：**

```json
{
  "rule_code": "ai_definition",
  "scene": "player",
  "entry": "subtitle_tap",
  "request_id": "uuid-v4",
  "params": {
    "word": "unprecedented",
    "sentence": "This warming is unprecedented in modern history."
  }
}
```

**Edge Function → 客户端响应（成功）：**

```json
{
  "ok": true,
  "rule_code": "ai_definition",
  "cost_cny": 0.01,
  "balance_after": 9.87,
  "result": {
    "word": "unprecedented",
    "phonetic_uk": "/ʌnˈpresɪdentɪd/",
    "phonetic_us": "/ʌnˈpresɪdentɪd/",
    "definitions": "adj. 史无前例的，空前的",
    "example": "an unprecedented success",
    "example_translation": "空前的成功"
  }
}
```

**Edge Function → 客户端响应（余额不足）：**

```json
{
  "ok": false,
  "error": "insufficient_balance",
  "message": "余额不足，当前余额 ¥0.02，本次需要 ¥0.03",
  "balance_cny": 0.02,
  "required_cny": 0.03
}
```

### 4.3 计费核心流程（billing.ts）

```
1. 从 JWT 提取 user_id
2. SELECT balance_cny FROM user_wallet WHERE user_id = ?
3. SELECT price_cny FROM pricing_rule WHERE rule_code = ? AND status = 'active'
4. IF balance < price → 返回余额不足错误
5. SELECT id FROM usage_event WHERE request_id = ? → 幂等检查
6. 调用 AI API
7. BEGIN 事务:
   a. INSERT usage_event (user_id, rule_code, scene, entry, request_id, cost_cny)
   b. INSERT wallet_ledger (type='consume', amount=-price, balance_after=new_balance, ref_id=usage_event.id)
   c. UPDATE user_wallet SET balance_cny = balance_cny - price, updated_at = NOW()
8. COMMIT → 返回结果
```

---

## 五、新用户注册赠送余额流程

```
Auth 触发器 on insert into auth.users
    ↓
读取 app_settings.default_new_user_balance (10.00)
    ↓
INSERT INTO user_wallet (user_id, balance_cny = 10.00)
    ↓
INSERT INTO wallet_ledger (
  user_id, type = 'topup', amount_cny = 10.00,
  balance_after = 10.00, channel = 'system_grant',
  note = '新用户注册赠送'
)
```

---

## 六、Flutter 端实施清单（本次仅视频播放器）

### 6.1 新建文件

| # | 文件 | 说明 |
|---|------|------|
| 1 | `lib/models/pricing_rule.dart` | 计费规则模型 + Supabase REST 查询 |
| 2 | `lib/models/word_card_data.dart` | 翻译弹窗数据模型 |
| 3 | `lib/services/ai_service.dart` | 统一调用 `ai-proxy` Edge Function |
| 4 | `lib/services/native_service.dart` | 原生翻译/TTS 封装（免费模式用） |
| 5 | `lib/widgets/word_card.dart` | 翻译弹窗组件（免费/付费共用 UI） |

### 6.2 修改文件

| # | 文件 | 改动 |
|---|------|------|
| 6 | `lib/views/player/player_page.dart` | 字幕按钮显隐 + 双模式功能路由 + 字幕点击 WordCard |
| 7 | `lib/providers/subscription_provider.dart` | 确保全局可读 `SubscriptionMode` |

### 6.3 按钮显隐规则

| 条件 | 显示 | 隐藏 |
|------|------|------|
| **有字幕** | `◀◀ ◀ ▶/⏸ ▶ ▶▶ x1.0 Tr Fol Quiz` | — |
| **无字幕** | `▶/⏸ x1.0 Tr` | `◀◀ ◀ ▶ ▶▶ Fol Quiz` |

### 6.4 功能路由

| 用户操作 | 免费模式 | 付费模式 | rule_code |
|---------|---------|---------|-----------|
| 点击字幕单词 | `NativeService.lookupWord()` → WordCard | `AiService.call('ai_definition')` → WordCard | `ai_definition` |
| 点击 Tr 翻译按钮 | `NativeService.translate()` → 切换显隐 | `AiService.call('ai_translate')` → 切换显隐 | `ai_translate` |
| 点击播放/TTS | `NativeService.ttsSpeak()` | `AiService.call('ai_tts')` → 播放 | `ai_tts` |
| 上一句/下一句 | 本地字幕切句（无计费） | 同左 | — |
| 调速 x0.5~x2.0 | 本地播放器控制 | 同左 | — |

---

## 七、消费流程完整示例

```
用户在视频播放器中点击字幕 "unprecedented"（付费模式）
    ↓
Flutter:
  AiService.callAiProxy(
    ruleCode: 'ai_definition',
    scene: 'player',
    entry: 'subtitle_tap',
    params: { word: 'unprecedented', sentence: 'This warming is unprecedented...' }
  )
    ↓
supabase.functions.invoke('ai-proxy', body: {
  rule_code: 'ai_definition',
  scene: 'player',
  entry: 'subtitle_tap',
  request_id: 'a1b2c3d4-...',
  params: { word: 'unprecedented', sentence: '...' }
})
    ↓
Edge Function:
  - JWT → user_id = 'xxx-xxx-xxx'
  - user_wallet.balance_cny = 9.87
  - pricing_rule: ai_definition → ¥0.01
  - balance (9.87) >= price (0.01) ✓
  - request_id 不存在 ✓
  - 调用 Qwen Chat API → 返回释义结果
  - 事务扣费:
    * INSERT usage_event (cost_cny=0.01)
    * INSERT wallet_ledger (type=consume, amount=-0.01, balance_after=9.86, ref_id=usage_event.id)
    * UPDATE user_wallet SET balance_cny = 9.86
  - 返回: { ok: true, cost_cny: 0.01, balance_after: 9.86, result: {...} }
    ↓
Flutter:
  - 弹出 WordCard(释义、音标、例句)
  - 可选：刷新顶部余额显示
```

---

## 八、后续扩展预留

| 模块 | 调用场景 | rule_code | 优先级 |
|------|---------|-----------|--------|
| 文章阅读器 | 点击单词查释义 | `ai_definition` | P1 |
| 文章阅读器 | 句子翻译 | `ai_translate` | P1 |
| 文章阅读器 | 跟读评分 | `ai_evaluate` | P1 |
| 生词本 | 单词释义查询 | `ai_definition` | P1 |
| 生词本 | 单词 AI 发音 | `ai_tts` | P1 |
| 生词本 | 词联扩展 | `ai_word_link` | P2 |
| 单元测试 | AI 生成题目 | 待新增规则 | P2 |
| 综合测试 | AI 混合出题 | 待新增规则 | P2 |
| 歌曲跟唱 | 发音评分 | `ai_evaluate` | P2 |

---

## 九、尚未确定事项

| 事项 | 状态 |
|------|------|
| `ai_evaluate` 发音评分是否用声通 | ✅ 确认用声通 |
| `ai_word_link` 本次是否实现 | ❌ 本次不做 |
| 充值/支付（IAP + 支付宝）页面 | ❌ 后续 |
| 文章/歌曲播放器改造 | ❌ 后续 |
| 收藏/生词本功能 | ❌ 后续 |
