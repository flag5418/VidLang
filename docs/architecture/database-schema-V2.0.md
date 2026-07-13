# VidLang 数据库设计

> **版本**: V2.0 | **日期**: 2026-07-13
> **状态**: 当前有效 | **变更**: 修复 device_type 定位、补充 Supabase 全部云端表、所有字段增加中文描述

---

## 一、数据库概述

| 项目 | 选择 | 说明 |
|------|------|------|
| **本地数据库** | SQLite (sqflite) | 轻量级、离线可用，20 个已注册实体 |
| **云端数据库** | Supabase (PostgreSQL) | 跨设备同步、用户认证、计费、论坛 |
| **全文检索** | FTS5 (SQLite) | 字幕/分词/句子的模糊搜索 |
| **ORM 方式** | 手写 toMap/fromMap（本地） / fromJson（云端 DTO） | 轻量级 |

### 运行时配置（非数据库）

| 配置项 | 存储方式 | 说明 |
|--------|---------|------|
| 设备类型 (`AppDeviceType`) | SharedPreferences | 枚举值：`iphone` / `ipad`，非数据库表 |
| 主题模式 | SharedPreferences | `system` / `light` / `dark` |


---

## 二、表结构总览

### 2.1 实体关系图 (ERD)

```
┌─────────────────── 本地 SQLite（20 表）─────────────────┐
│                                                          │
│  ┌─────────────── 核心学习引擎 ───────────────┐         │
│  │  video_folder(1:N)video_info              │         │
│  │    ├── subtitles(FTS5) ◄── participle(FTS5)│        │
│  │    └── config(KV存储)                      │         │
│  ├─────────────── 文章引擎 ───────────────────┤         │
│  │  article → article_paragraph               │         │
│  │         → article_sentence(FTS5)           │         │
│  │         → article_bookmark                 │         │
│  ├─────────────── 学习记录 ───────────────────┤         │
│  │  study_record / recording_record           │         │
│  │  test_session + test_item + test_evaluation│         │
│  │  ai_evaluation_log                         │         │
│  ├─────────────── 单词本系统 ─────────────────┤         │
│  │  word_book / word_tag / word_book_tag      │         │
│  └─────────────── 系统表 ─────────────────────┘         │
│     user / error_log                                 │
│                                                          │
└──────────────────────────────────────────────────────────┘

┌─────────────────── Supabase 云端（PostgreSQL）────────────┐
│                                                            │
│  ┌─────────────── 计费体系 ──────────────────┐            │
│  │  pricing_rule / usage_event               │            │
│  │  wallet_ledger / user_wallet / app_settings│            │
│  │  topup_config（充值档位，配置驱动）          │            │
│  ├─────────────── 对话/AI ────────────────────┤            │
│  │  conversation_session                     │            │
│  │  model_config / word_cache                 │            │
│  │  evaluation_storage                       │            │
│  ├─────────────── 论坛系统 ────────────────────┤            │
│  │  forum_categories / forum_posts            │            │
│  │  post_images / forum_likes                 │            │
│  │  forum_comments / comment_likes            │            │
│  │  user_favorites / forum_notifications      │            │
│  │  user_feedback / user_forum_preferences     │            │
│  │  forum_stats                               │            │
│  ├─────────────── 用户会话 ────────────────────┤            │
│  │  user_active_session / resource_status     │            │
│  └─────────────────────────────────────────────┘            │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### 2.2 本地 SQLite 表清单（20 表 — 已注册）

> 所有表均在 `lib/main.dart` 的 `DatabaseService.registerEntities()` 中注册。

| # | 表名 | 模型类 | 用途 | FTS5 |
|---|------|--------|------|:----:|
| **核心引擎** |||||
| 1 | `video_folder` | VideoFolder | 视频集/文件夹 | ❌ |
| 2 | `video_info` | VideoInfo | 视频信息 | ❌ |
| 3 | `subtitles` | Subtitles | 字幕行/歌词行 | ✅ |
| 4 | `participle` | Participle | 分词记录 | ✅ |
| **文章引擎** |||||
| 5 | `article` | Article | 文章元数据 | ❌ |
| 6 | `article_paragraph` | ArticleParagraph | 文章段落 | ❌ |
| 7 | `article_sentence` | ArticleSentence | 文章句子 | ✅ |
| 8 | `article_bookmark` | ArticleBookmark | 文章书签/收藏位置 | ❌ |
| **学习记录** |||||
| 9 | `study_record` | StudyRecord | 学习记录（duration 单位：**秒**） | ❌ |
| 10 | `recording_record` | RecordingRecord | 跟读录音记录 | ❌ |
| **测试/评测** |||||
| 11 | `test_session` | TestSession | 测试主记录（一次测试会话） | ❌ |
| 12 | `test_item` | TestItem | 单题记录（一道题的答案） | ❌ |
| 13 | `test_evaluation` | TestEvaluation | AI 评价报告 | ❌ |
| 14 | `ai_evaluation_log` | AiEvaluationLog | AI 学习评价日志 | ❌ |
| **单词本** |||||
| 15 | `word_book` | WordBook | 单词本（learning/mastered 两档） | ❌ |
| 16 | `word_tag` | WordTag | 单词标签 | ❌ |
| 17 | `word_book_tag` | WordBookTag | 单词-标签多对多关联 | ❌ |
| **系统** |||||
| 18 | `config` | Config | 系统键值配置（KV 存储） | ❌ |
| 19 | `user` | User | 用户信息 | ❌ |
| 20 | `error_log` | ErrorLog | 错误日志 | ❌ |

---

## 三、关键字段规范

### 3.1 时长单位（⚠️ 重要 — 混用会导致 Bug）

| 字段上下文 | 单位 | 示例 | 典型字段 |
|-----------|------|------|---------|
| 视频播放相关 | **毫秒** | `7200000` (2小时) | `video_info.duration`, `current_position`, `total_play_duration` ⚠️ |
| 学习记录 | **秒** | `3600` (1小时) | `study_record.duration` |
| 录音记录 | **毫秒** | `5000` (5秒) | `recording_record.duration_ms` |
| 对话会话 | **秒** | `300` (5分钟) | `conversation_session.duration_seconds` |

> ⚠️ `video_info.total_play_duration` 虽然在视频表中，但单位是**秒**（累计播放时长），与同表的 `duration`(毫秒) 不同！

### 3.2 审计字段（BaseEntity 标配 — 本地表）

所有继承 BaseEntity 的本地表均包含以下字段：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `is_deleted` | INTEGER | 软删除标记（0=未删除, 1=已删除） |
| `deleted_at` | TEXT | 删除时间（ISO8601 格式字符串） |
| `deleted_by` | TEXT | 删除操作人的用户 code |
| `created_at` | TEXT | 创建时间（ISO8601 格式字符串） |
| `updated_at` | TEXT | 更新时间（ISO8601 格式字符串） |
| `created_by` | TEXT | 创建人用户 code |
| `updated_by` | TEXT | 更新人用户 code |
| `user_code` | TEXT | 当前登录用户的唯一标识 |

### 3.3 命名规范

| 场景 | 规范 | 示例 |
|------|------|------|
| 本地表名 | snake_case | `video_info`, `study_record` |
| 云端表名 | snake_case | `forum_posts`, `pricing_rule` |
| 字段名 | snake_case | `folder_code`, `created_at` |
| 本地业务主键 | `code` | `TEXT UNIQUE`（UUID 格式） |
| 云端主键 | `id` | `BIGSERIAL` 或 `UUID` |
| 外键（本地） | `{关联表}_code` | `folder_code`, `user_code` |
| 外键（云端） | `{关联表}_id` | `category_id`, `user_id` |
| 布尔字段 | `is_{形容词}` | `is_deleted`, `has_subtitles`, `is_featured` |
| 索引命名 | `idx_{表名}_{字段名}` | `idx_video_info_folder_code` |

---

## 四、核心表 DDL（含字段中文描述）

### 4.1 video_folder（视频集/文件夹）

```sql
CREATE TABLE IF NOT EXISTS video_folder (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,  -- 自增主键
    code                TEXT UNIQUE NOT NULL,                -- 业务主键（UUID）
    name                TEXT NOT NULL DEFAULT '',            -- 文件夹名称
    type                INTEGER NOT NULL DEFAULT 0,          -- 类型：0=虚拟集 1=真实文件目录
    path                TEXT,                                -- 外部文件系统路径（仅真实目录有值）
    -- parent_code 已废弃：当前设计为扁平化结构，文件夹下直接挂载资源，无多级嵌套
    video_count         INTEGER NOT NULL DEFAULT 0,          -- 包含的视频数量
    completed_count     INTEGER NOT NULL DEFAULT 0,          -- 已看完的视频数量
    cover               TEXT,                                -- 封面图片路径（本地或远程 URL）
    thumbnail_time      INTEGER NOT NULL DEFAULT 15,         -- 封面截图时间点（单位：秒）
    last_video_code     TEXT,                                -- 最近播放的视频 code
    last_play_date      TEXT,                                -- 最近一次播放日期
    last_play_duration  INTEGER NOT NULL DEFAULT 0,          -- 最近一次播放时长（单位：毫秒）
    skip_opening        INTEGER NOT NULL DEFAULT 0,          -- 是否跳过片头：0=否 1=是
    skip_opening_duration INTEGER NOT NULL DEFAULT 0,       -- 片头跳过时长（单位：秒）
    skip_ending         INTEGER NOT NULL DEFAULT 0,          -- 是否跳过片尾：0=否 1=是
    skip_ending_duration INTEGER NOT NULL DEFAULT 0,        -- 片尾跳过时长（单位：秒）
    sort_order          INTEGER NOT NULL DEFAULT 0,          -- 排序权重（越小越靠前）
    -- 审计字段（BaseEntity 标配）
    is_deleted          INTEGER NOT NULL DEFAULT 0,
    deleted_at          TEXT,
    deleted_by          TEXT,
    created_at          TEXT NOT NULL DEFAULT '',
    updated_at          TEXT NOT NULL DEFAULT '',
    created_by          TEXT NOT NULL DEFAULT '',
    updated_by          TEXT NOT NULL DEFAULT '',
    user_code           TEXT NOT NULL DEFAULT ''
);
```

### 4.2 video_info（视频信息）

```sql
CREATE TABLE IF NOT EXISTS video_info (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,  -- 自增主键
    code                TEXT UNIQUE NOT NULL,                -- 业务主键（UUID）
    name                TEXT NOT NULL DEFAULT '',            -- 视频名称（含扩展名）
    folder_code         TEXT NOT NULL,                        -- 所属文件夹 code
    file_path           TEXT,                                -- 本地文件路径或远程 URL
    duration            INTEGER NOT NULL DEFAULT 0,          -- 视频总时长（单位：毫秒）
    cover               TEXT,                                -- 封面图片路径
    current_position    INTEGER NOT NULL DEFAULT 0,          -- 当前进度（单位：毫秒）
    is_current_playing  INTEGER NOT NULL DEFAULT 0,          -- 是否正在播放：0=否 1=是
    has_subtitles       INTEGER NOT NULL DEFAULT 0,          -- 是否有字幕文件：0=无 1=有
    play_date           TEXT,                                -- 最近一次播放日期
    play_count          INTEGER NOT NULL DEFAULT 0,          -- 累计播放次数
    total_play_duration INTEGER NOT NULL DEFAULT 0,          -- 累计播放时长（⚠️ 单位：秒！）
    sort_order          INTEGER NOT NULL DEFAULT 0,          -- 排序权重
    -- 审计字段
    is_deleted          INTEGER NOT NULL DEFAULT 0,
    deleted_at          TEXT, deleted_by          TEXT,
    created_at          TEXT NOT NULL DEFAULT '',
    updated_at          TEXT NOT NULL DEFAULT '',
    created_by          TEXT NOT NULL DEFAULT '',
    updated_by          TEXT NOT NULL DEFAULT '',
    user_code           TEXT NOT NULL DEFAULT ''
);
```

### 4.3 subtitles（字幕/歌词行 — 含 FTS5 全文检索）

```sql
-- 主表
CREATE TABLE IF NOT EXISTS subtitles (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,  -- 自增主键
    code            TEXT UNIQUE NOT NULL,                -- 业务主键（UUID）
    video_code      TEXT NOT NULL,                        -- 所属视频 code
    content         TEXT NOT NULL,                        -- 原文内容（外语）
    translation     TEXT,                                 -- 翻译译文（中文）
    start_position  INTEGER NOT NULL DEFAULT 0,          -- 开始时间（单位：毫秒）
    end_position    INTEGER NOT NULL DEFAULT 0,          -- 结束时间（单位：毫秒）
    index           INTEGER NOT NULL DEFAULT 0,          -- 序号（从 0 开始）
    word_count      INTEGER NOT NULL DEFAULT 0,          -- 词数
    type            TEXT NOT NULL DEFAULT 'subtitle',    -- 类型：'subtitle'=字幕 'lyric'=歌词
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT '',
    updated_at      TEXT NOT NULL DEFAULT '',
    user_code       TEXT NOT NULL DEFAULT ''
);

-- FTS5 虚拟表（全文检索索引）
CREATE VIRTUAL TABLE IF NOT EXISTS subtitles_fts USING fts5(
    content, translation, content=subtitles, content_rowid=id
);
```

### 4.4 study_record（学习记录）

```sql
CREATE TABLE IF NOT EXISTS study_record (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,  -- 自增主键
    code            TEXT UNIQUE NOT NULL,                -- 业务主键（UUID）
    user_code       TEXT NOT NULL,                        -- 用户标识
    video_code      TEXT NOT NULL,                        -- 关联视频 code
    date            TEXT NOT NULL,                        -- 学习日期（ISO8601，精确到天）
    start_time      TEXT NOT NULL,                        -- 开始时间（ISO8601）
    end_time        TEXT,                                 -- 结束时间（ISO8601）
    duration        INTEGER NOT NULL DEFAULT 0,          -- 本次学习时长（⚠️ 单位：秒）
    play_count      INTEGER NOT NULL DEFAULT 0,          -- 播放次数
    words_learned   INTEGER NOT NULL DEFAULT 0,          -- 学到的生词数
    test_score      REAL,                                 -- 测试得分（0-100）
    test_type       TEXT,                                 -- 测试类型
    notes           TEXT,                                 -- 备注
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT '',
    updated_at      TEXT NOT NULL DEFAULT ''
);
```

### 4.5 word_book（单词本 — 两档记忆体系）

```sql
CREATE TABLE IF NOT EXISTS word_book (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,  -- 自增主键
    code                TEXT UNIQUE NOT NULL,                -- 业务主键（UUID）
    word                TEXT NOT NULL,                        -- 单词原文
    source_type         TEXT NOT NULL,                        -- 来源类型：'video'=视频 'article'=文章 'music'=歌曲
    source_code         TEXT NOT NULL,                        -- 来源资源 code
    source_title        TEXT,                                 -- 来源资源标题
    segment_code        TEXT,                                 -- 来源字幕/句子 code
    context_sentence    TEXT,                                 -- 例句/上下文
    screenshot_path     TEXT,                                 -- 截图路径
    definitions_json    TEXT,                                 -- 释义 JSON（多词典合并）
    phonetic_uk         TEXT,                                 -- 英式音标
    phonetic_us         TEXT,                                 -- 美式音标
    morphology_json     TEXT,                                 -- 词形变化 JSON（时态/复数/比较级等）
    mnemonic            TEXT,                                 -- 助记法/联想记忆
    difficulty          INTEGER NOT NULL DEFAULT 0,          -- 难度等级（1-5）
    review_count        INTEGER NOT NULL DEFAULT 0,          -- 复习次数
    correct_count       INTEGER NOT NULL DEFAULT 0,          -- 正确次数
    last_review_at      TEXT,                                 -- 上次复习时间
    next_review_at      TEXT,                                 -- 下次复习时间（间隔重复算法计算）
    mastery_level       TEXT NOT NULL DEFAULT 'learning',    -- 掌握程度：'learning'=学习中 'mastered'=已掌握
    mastered_at         TEXT,                                 -- 变为"已掌握"的时间
    is_deleted          INTEGER NOT NULL DEFAULT 0,
    deleted_at          TEXT, deleted_by      TEXT,
    created_at          TEXT NOT NULL DEFAULT '',
    updated_at          TEXT NOT NULL DEFAULT '',
    created_by          TEXT NOT NULL DEFAULT '',
    updated_by          TEXT NOT NULL DEFAULT '',
    user_code           TEXT NOT NULL DEFAULT ''
);
```

**状态流转：**
```
收藏单词 → masteryLevel = 'learning'
点击认识   → masteryLevel = 'mastered'，记录 masteredAt
已掌握→不认识 → masteryLevel = 'learning'，清空 masteredAt
已掌握→删除   → isDeleted = true（软删除）
```

---

## 五、Supabase 云端表 DDL

> 以下表位于 Supabase PostgreSQL 中，通过 migration 脚本管理。
> 迁移脚本目录：`supabase/migrations/`
> Dart 层使用 `fromJson/toJson` 而非 `toMap/fromMap`。

### 5.1 计费体系（5 张表）

#### pricing_rule（计费规则 — ⚠️ 配置驱动，商务可随时调整）

```sql
CREATE TABLE IF NOT EXISTS public.pricing_rule (
    id              BIGSERIAL PRIMARY KEY,                 -- 自增主键
    rule_code       TEXT UNIQUE NOT NULL,                   -- 规则编码（如 ai_definition）
    name_zh         TEXT NOT NULL,                          -- 中文名称
    description_zh  TEXT NOT NULL,                          -- 中文描述
    model           TEXT NOT NULL,                          -- 使用的 AI 模型名称
    price_cny       NUMERIC(10,4) NOT NULL,                 -- 单价（人民币元）
    status          TEXT NOT NULL DEFAULT 'active',         -- 状态：'active'=启用 'disabled'=停用
    created_at      TIMESTAMPTZ DEFAULT NOW()                -- 创建时间
);
```

**当前有效规则**（来自 migration 脚本汇总）：

| rule_code | 中文名 | 模型 | 单价(¥) | 说明 |
|-----------|--------|------|---------|------|
| `ai_definition` | AI 释义 | qwen-turbo | 0.01 | 查询单词详细释义、例句、音标 |
| `ai_translate` | AI 翻译 | qwen-turbo | 0.03 | 通义千问句子/段落翻译 |
| `ai_tts` | AI 发音 | qwen3-tts-flash | 0.02 | TTS 语音合成 |
| `ai_word_link` | AI 词联 | qwen-turbo | 0.02 | 上下文联想近义词/反义词 |
| `ai_evaluate` | AI 评测 | shengtong | 0.05 | 声通发音评分 |
| `ai_chat` | AI 对话判分 | qwen-turbo | 0.02 | 评测判分和自定义对话 |
| `ai_conversation` | AI 对话(创建会话) | qwen3.5-omni-plus-realtime | 0.00 | 创建对话会话（免费） |
| `ai_conversation_question` | AI 对话(提问) | 同上 | 0.01 | 用户每次提问 |
| `ai_conversation_answer` | AI 对话(回答) | 同上 | 0.01 | AI 每次回答 |
| `ai_conversation_settle` | AI 对话(结算) | 同上 | 0.00 | 会话结束结算（免费） |

> 💡 **规则可通过 SQL UPDATE 动态调整价格和模型**，无需发版。

#### usage_event（消费事件 — 账单真相源头）

```sql
CREATE TABLE IF NOT EXISTS public.usage_event (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID REFERENCES auth.users(id) NOT NULL,  -- 消费用户
    rule_code       TEXT NOT NULL,                             -- 关联的计费规则编码
    scene           TEXT NOT NULL,                             -- 使用场景
    entry           TEXT NOT NULL,                             -- 入口页面
    request_id      TEXT UNIQUE NOT NULL,                      -- 请求 ID（防重）
    cost_cny        NUMERIC(10,4) NOT NULL,                    -- 本次消费金额（元）
    meta            JSONB DEFAULT '{}',                        -- 扩展元数据
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

**meta JSON 结构示例：**
```json
{
  "action_key": "ai_conversation",
  "action_label": "AI 对话",
  "resource_type": "video",
  "resource_code": "video_xxx",
  "resource_title": "Friends S01E01",
  "folder_code": "folder_xxx",
  "source_page": "conversation_page",
  "is_chargeable": true
}
```

#### wallet_ledger（余额流水 — 合并充值+消费+调整）

```sql
CREATE TABLE IF NOT EXISTS public.wallet_ledger (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID REFERENCES auth.users(id) NOT NULL,
    type            TEXT NOT NULL,             -- 流水类型：'topup'=充值 'consume'=消费 'refund'=退款 'adjust'=调整
    amount_cny      NUMERIC(10,4) NOT NULL,    -- 金额（正=入账 负=扣款）
    balance_after   NUMERIC(10,4) NOT NULL,     -- 交易后余额
    channel         TEXT,                       -- 渠道（充值时：alipay/wechat 等）
    paid_at         TIMESTAMPTZ,                -- 支付完成时间
    ref_id          BIGINT,                     -- 关联 ID（如 topup_config.id）
    note            TEXT,                       -- 备注
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

#### user_wallet（用户钱包 — 纯余额快照）

```sql
CREATE TABLE IF NOT EXISTS public.user_wallet (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID REFERENCES auth.users(id) UNIQUE NOT NULL,  -- 用户（唯一）
    balance_cny     NUMERIC(10,4) NOT NULL DEFAULT 0,                -- 当前余额（元）
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

#### app_settings（应用全局设置 — API Keys 等）

```sql
CREATE TABLE IF NOT EXISTS public.app_settings (
    id              BIGSERIAL PRIMARY KEY,
    key             TEXT UNIQUE NOT NULL,       -- 设置键
    value           TEXT NOT NULL,              -- 设置值
    description     TEXT,                       -- 说明
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

**初始数据：**

| key | value | description |
|-----|-------|-------------|
| `default_new_user_balance` | `10.00` | 新用户注册默认赠送余额（元） |
| `qwen_api_key` | *(已填充)* | 通义千问 API Key |
| `qwen_base_url` | `https://dashscope.aliyuncs.com/compatible-mode/v1` | Qwen API 地址 |
| `shengtong_api_key` | *(已填充)* | 声通发音评分 API Key |
| `shengtong_app_id` | *(已填充)* | 声通 App ID |

### 5.2 topup_config（充值档位配置 — ⚠️ 商务策略驱动，非硬编码）

```sql
CREATE TABLE IF NOT EXISTS public.topup_config (
    id              BIGSERIAL PRIMARY KEY,
    original_amount NUMERIC(10,2) NOT NULL,        -- 充值面值（展示用，元）
    actual_amount   NUMERIC(10,2) NOT NULL,        -- 用户实际支付金额（元）
    bonus_amount    NUMERIC(10,2) NOT NULL DEFAULT 0, -- 额外赠送金额（元）
    discount_rate   NUMERIC(5,4),                   -- 折扣率（1.0=无折扣，NULL 表示按 bonus 计算）
    label           TEXT,                           -- 展示标签："体验"/"热门"/"最划算"
    discount_label  TEXT,                           -- 折扣文案："打 9.5 折"/"送 ¥20"
    sort_order      INT NOT NULL DEFAULT 0,         -- 排序权重（越小越靠前）
    status          TEXT NOT NULL DEFAULT 'active', -- active / inactive
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

**当前档位配置**（来自 `20260707000001_create_topup_config.sql`）：

| 面值(¥) | 实付(¥) | 赠送(¥) | 到账(¥) | 标签 | 折扣文案 |
|---------|---------|---------|---------|------|---------|
| 10 | 10 | 0 | 10 | 体验 | — |
| 50 | 55 | 5 | **60** | 热门 | 送 ¥5 |
| 100 | 120 | 20 | **140** | 最划算 | 送 ¥20 |

> 💡 **商务调整方式**：直接在 Supabase Dashboard 或通过 Edge Function 修改 `topup_config` 表记录即可，客户端自动拉取最新配置。支持动态增删改档位、调整折扣率、修改标签。

**Dart 模型**: `lib/models/topup_config.dart`（fromJson + hasBonus + displayDiscount 计算属性）

### 5.3 对话/AI 相关表

#### conversation_session（对话会话）

```sql
CREATE TABLE IF NOT EXISTS public.conversation_session (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES auth.users(id),
    source_type         TEXT NOT NULL,              -- 来源类型：'video'/'article'/'music'
    source_code         TEXT NOT NULL,              -- 来源资源 code
    status              TEXT NOT NULL DEFAULT 'active', -- 'active'/'ended'/'error'
    turn_count          INTEGER NOT NULL DEFAULT 0, -- 对话轮次
    duration_seconds    INTEGER NOT NULL DEFAULT 0, -- 会话时长（秒）
    started_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at            TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### model_config（模型配置）

> 来自 `20260625000003_create_model_config.sql` — 存储 AI 模型的参数配置（温度、top_p 等），支持运行时调整。

#### word_cache（单词缓存）

> 来自 `20260615000001_create_word_cache_table.sql` + `20260629000002_extend_word_cache_for_v4.sql` — 缓存查词结果，避免重复调用 AI。

#### evaluation_storage（评测存储）

> 来自 `20260701000001_create_evaluation_storage_tables.sql` — 评测结果的云端持久化。

### 5.4 Forum 论坛系统（11 张表）

> 论坛功能开发中，表结构已就绪。

| # | 表名 | 用途 | 关键字段 |
|---|------|------|---------|
| 1 | `forum_categories` | 论坛分类 | name, slug, sort_order, is_active |
| 2 | `forum_posts` | 帖子 | title, content, category_id, author_id, post_type, status, view_count, like_count, comment_count |
| 3 | `post_images` | 帖子图片 | post_id, image_url, image_type(cover/content) |
| 4 | `forum_likes` | 帖子点赞 | user_id, post_id（UNIQUE 联合） |
| 5 | `forum_comments` | 评论 | post_id, user_id, parent_id(支持楼中楼), content, status |
| 6 | `comment_likes` | 评论点赞 | user_id, comment_id（UNIQUE 联合） |
| 7 | `user_favorites` | 用户收藏 | user_id, post_id（UNIQUE 联合） |
| 8 | `forum_notifications` | 通知 | user_id, type(like/comment/reply/mention), is_read |
| 9 | `user_feedback` | 反馈建议 | feedback_type(bug/feature/content/general), priority, status |
| 10 | `user_forum_preferences` | 用户论坛偏好 | email_notifications, push_notifications, bio, signature |
| 11 | `forum_stats` | 统计快照 | total_posts, total_comments, total_users, active_users_week/month |

**帖子状态机**: `draft` → `published` → (可选)`moderating` → `rejected` / `published`
**帖子类型**: `discussion`(讨论) / `resource`(资源分享) / `feedback`(反馈)

### 5.5 其他辅助表

| 表名 | 来源迁移 | 用途 |
|------|---------|------|
| `user_active_session` | `20260612000001` | 用户在线活跃会话（用于并发控制） |
| `resource_status` | `20260708000001` | 资源处理状态（如视频转码进度） |

---

## 六、数据迁移与维护

### 版本管理

```dart
// DatabaseService 中维护版本号
static const int _dbVersion = 1;
// _ensureTable 在每次 onOpen 时自动检测缺表并创建
// ALTER TABLE ADD COLUMN 用于新增列（可空或带默认值）
```

### 迁移操作类型

| 操作 | SQL | 注意事项 |
|------|-----|---------|
| 添加列 | `ALTER TABLE {表} ADD COLUMN {列} {类型}` | 可空或带默认值 |
| 删除列 | ❌ 不支持 | 需要重建表 |
| 添加表 | `CREATE TABLE IF NOT EXISTS` | 正常执行 |
| 添加索引 | `CREATE INDEX IF NOT EXISTS` | 正常执行 |

### 性能建议

- 使用 WAL 模式：`PRAGMA journal_mode=WAL`
- 批量操作使用事务（每批 500-1000 条）
- FTS5 搜索支持前缀匹配（`query*`）和短语匹配（`"hello world"`）
- Supabase 云端查询善用 RLS 策略减少数据传输量

---

## 附录 A：Migration 脚本索引

| 时间戳 | 文件名 | 创建/修改的表 |
|--------|--------|--------------|
| 20260607-000001 | create_billing_tables.sql | pricing_rule, usage_event, wallet_ledger, user_wallet, app_settings |
| 20260607-000002 | new_user_balance_trigger.sql | 新用户余额触发器 |
| 20260612-000001 | create_user_active_session.sql | user_active_session |
| 20260612-000002 | create_conversation_session.sql | conversation_session |
| 20260612-000003 | add_ai_conversation_pricing_rules.sql | pricing_rule 数据（4 条对话规则） |
| 20260614-000001 | create_test_evaluation_tables.sql | 评测相关表 |
| 20260615-000001 | create_word_cache_table.sql | word_cache |
| 20260616-000001 | add_shengtong_uid_and_audio_eval_rule.sql | 声通凭证更新 |
| 20260617-000001 | add_ai_translate_article_pricing_rule.sql | pricing_rule 数据 |
| 20260619-000001 | add_ai_chat_pricing_rule.sql | pricing_rule 数据（ai_chat） |
| 20260625-000001 | update_pricing_rule_models.sql | pricing_rule 模型更新 |
| 20260625-000002 | update_tts_model.sql | TTS 模型切换 |
| 20260625-000003 | create_model_config.sql | model_config |
| 20260628-000001 | word_cache_helpers.sql | word_cache 辅助函数 |
| 20260629-000001 | update_tts_to_sambert.sql | TTS 引擎切换 |
| 20260629-000002 | extend_word_cache_for_v4.sql | word_cache 扩展字段 |
| 20260629-000003 | update_shengtong_credentials.sql | 声通凭证更新 |
| 20260701-000001 | create_evaluation_storage_tables.sql | evaluation_storage |
| 20260704-000001 | create_forum_tables.sql | **论坛 11 张表** |
| 20260704-000002 | forum_functions.sql | 论坛函数 |
| 20260707-000001 | create_topup_config.sql | **topup_config + 初始档位数据** |
| 20260708-000001 | create_resource_status_table.sql | resource_status |
