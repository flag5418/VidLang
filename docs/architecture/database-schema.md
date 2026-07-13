# VidLang 数据库设计

> **版本**: V1.0 | **日期**: 2026-07-13
> **状态**: 当前有效 | **来源**: 合并自 `database-design.md` V2.0 + `15-database-schema.md`

---

## 一、数据库概述

| 项目 | 选择 | 说明 |
|------|------|------|
| **本地数据库** | SQLite (sqflite) | 轻量级、离线可用 |
| **云端数据库** | Supabase (PostgreSQL) | 跨设备同步、用户认证 |
| **全文检索** | FTS5 (SQLite) | 字幕/分词的模糊搜索 |
| **ORM 方式** | 手写 toMap/fromMap | 轻量级 |

### 数据同步策略

```
用户操作 → 先写本地 SQLite → 异步同步到 Supabase → 新设备登录时全量拉取
```

---

## 二、表结构总览（22 表）

### 2.1 实体关系图 (ERD)

```
┌─────────────────── 核心学习引擎 ───────────────────┐
│                                                      │
│  ┌─────────────┐       ┌─────────────┐             │
│  │ video_folder │──────<│  video_info │             │
│  │   (视频集)    │ 1:N  │   (视频)     │             │
│  └─────────────┘       └──────┬──────┘             │
│         │                     │                     │
│         │                     ▼                     │
│  ┌─────────────┐       ┌─────────────┐             │
│  │   config    │       │  subtitles  │◄────┐      │
│  │  (系统配置)  │       │   (字幕)FTS │     │      │
│  └─────────────┘       └──────┬──────┘     │      │
│                              │             │      │
│                              ▼             │      │
│                       ┌─────────────┐       │      │
│                       │  participle │       │      │
│                       │   (分词)FTS  │       │      │
│                       └─────────────┘       │      │
│                                                │      │
│  ┌─────────────────── 文章引擎 ───────────┐    │      │
│  │  article / article_paragraph /          │    │      │
│  │  article_sentence(FTS) / article_bookmark│    │      │
│  └─────────────────────────────────────────┘    │      │
│                                                │      │
│  ┌─────────────────── 学习记录 ────────────┐    │      │
│  │  study_record / recording_record /       │    │      │
│  │  test_session+item+eval / ai_eval_log   │    │      │
│  └─────────────────────────────────────────┘    │      │
│                                                │      │
│  ┌─────────────────── 单词本系统 ──────────┐    │      │
│  │  word_book / word_tag / word_book_tag /  │    │      │
│  │  word_card_data / word_detail           │    │      │
│  └─────────────────────────────────────────┘    │      │
│                                                │      │
│  ┌──────────────── 辅助表 ─────────────────┐    │      │
│  │  user / error_log / device_type /        │    │      │
│  │  playback_settings / conversation_* /    │    │      │
│  │  learning_resource / billing_summary /   │    │      │
│  │  pricing_rule / topup_config / ...       │    │      │
│  └──────────────────────────────────────────┘    │      │
└────────────────────────────────────────────────────────┘
```

### 2.2 表清单

| # | 表名 | 模型类 | 用途 | FTS5 |
|---|------|--------|------|------|
| **核心引擎** |
| 1 | `video_folder` | VideoFolder | 视频集/文件夹 | 否 |
| 2 | `video_info` | VideoInfo | 视频信息 | 否 |
| 3 | `subtitles` | Subtitles | 字幕行/歌词行 | ✅ |
| 4 | `participle` | Participle | 分词 | ✅ |
| **文章引擎** |
| 5 | `article` | Article | 文章 | 否 |
| 6 | `article_chapter` | ArticleChapter | 文章章节（旧版迁移中） | 否 |
| 7 | `article_paragraph` | ArticleParagraph | 文章段落 | 否 |
| 8 | `article_sentence` | ArticleSentence | 文章句子 | ✅ |
| 9 | `article_bookmark` | ArticleBookmark | 文章书签 | 否 |
| **学习记录** |
| 10 | `study_record` | StudyRecord | 学习记录（duration 单位：**秒**） | 已注册 |
| 11 | `recording_record` | RecordingRecord | 跟读录音记录 | 否 |
| **测试/评测** |
| 12 | `test_session` | TestSession | 测试主记录 | 否 |
| 13 | `test_item` | TestItem | 单题记录 | 否 |
| 14 | `test_evaluation` | TestEvaluation | AI评价报告 | 否 |
| 15 | `ai_evaluation_log` | AiEvaluationLog | AI评价日志 | 否 |
| **单词本** |
| 16 | `word_book` | WordBook | 单词本（learning/mastered 两档） | 否 |
| 17 | `word_tag` | WordTag | 单词标签 | 否 |
| 18 | `word_book_tag` | WordBookTag | 单词-标签关联 | 否 |
| **系统** |
| 19 | `config` | Config | 系统配置（KV） | 否 |
| 20 | `user` | User | 用户信息 | 否 |
| 21 | `error_log` | ErrorLog | 错误日志 | 否 |
| 22 | `device_type` | DeviceType | 设备类型 | 否 |

> **注**: 以上 22 个表均已在 `main.dart` 中通过 `DatabaseService.registerEntities()` 注册。

---

## 三、关键字段规范

### 3.1 时长单位（⚠️ 重要）

| 字段上下文 | 单位 | 示例 |
|-----------|------|------|
| 视频相关（`video_info.duration`, `current_position`） | **毫秒** | `7200000` (2小时) |
| 学习记录（`study_record.duration`） | **秒** | `3600` (1小时) |
| 录音记录（`recording_record.durationMs`） | **毫秒** | `5000` (5秒) |

### 3.2 审计字段（BaseEntity 标配）

所有表必须包含：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `is_deleted` | INTEGER | 软删除标记（0=未删除, 1=已删除） |
| `deleted_at` | TEXT | 删除时间（ISO8601） |
| `deleted_by` | TEXT | 删除操作人 code |
| `created_at` | TEXT | 创建时间（ISO8601） |
| `updated_at` | TEXT | 更新时间（ISO8601） |
| `created_by` | TEXT | 创建人 code |
| `updated_by` | TEXT | 更新人 code |
| `user_code` | TEXT | 用户标识 |

### 3.3 命名规范

| 场景 | 规范 | 示例 |
|------|------|------|
| 表名 | snake_case | `video_info`, `study_record` |
| 字段名 | snake_case | `folder_code`, `created_at` |
| 业务主键 | `code` | `TEXT UNIQUE`（UUID 格式） |
| 外键 | `{关联表}_code` | `folder_code`, `user_code` |
| 布尔字段 | `is_{形容词}` 或动词 | `is_deleted`, `has_subtitles` |
| 索引命名 | `idx_{表名}_{字段名}` | `idx_video_info_folder_code` |

---

## 四、核心表 DDL

### 4.1 video_folder（视频集）

```sql
CREATE TABLE IF NOT EXISTS video_folder (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT UNIQUE NOT NULL,
    name            TEXT NOT NULL DEFAULT '',
    type            INTEGER NOT NULL DEFAULT 0,    -- 0=虚拟集, 1=真实集
    path            TEXT,                          -- 外部路径（虚拟集）
    parent_code     TEXT,                          -- 父级 code（多级目录）
    video_count     INTEGER NOT NULL DEFAULT 0,
    completed_count INTEGER NOT NULL DEFAULT 0,
    cover           TEXT,
    thumbnail_time  INTEGER NOT NULL DEFAULT 15,   -- 封面截图时间点（秒）
    last_video_code TEXT,
    last_play_date  TEXT,
    last_play_duration INTEGER NOT NULL DEFAULT 0, -- 毫秒
    skip_opening            INTEGER NOT NULL DEFAULT 0,
    skip_opening_duration   INTEGER NOT NULL DEFAULT 0,
    skip_ending             INTEGER NOT NULL DEFAULT 0,
    skip_ending_duration    INTEGER NOT NULL DEFAULT 0,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    deleted_at      TEXT, deleted_by      TEXT,
    created_at      TEXT NOT NULL DEFAULT '',
    updated_at      TEXT NOT NULL DEFAULT '',
    created_by      TEXT NOT NULL DEFAULT '',
    updated_by      TEXT NOT NULL DEFAULT '',
    user_code       TEXT NOT NULL DEFAULT ''
);
```

### 4.2 video_info（视频）

```sql
CREATE TABLE IF NOT EXISTS video_info (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    code                TEXT UNIQUE NOT NULL,
    name                TEXT NOT NULL DEFAULT '',
    folder_code         TEXT NOT NULL,
    file_path           TEXT,
    duration            INTEGER NOT NULL DEFAULT 0,    -- 毫秒
    cover               TEXT,
    current_position    INTEGER NOT NULL DEFAULT 0,    -- 毫秒
    is_current_playing  INTEGER NOT NULL DEFAULT 0,
    has_subtitles       INTEGER NOT NULL DEFAULT 0,
    play_date           TEXT,
    play_count          INTEGER NOT NULL DEFAULT 0,
    total_play_duration INTEGER NOT NULL DEFAULT 0,    -- ⚠️ 秒
    sort_order          INTEGER NOT NULL DEFAULT 0,
    is_deleted          INTEGER NOT NULL DEFAULT 0,
    deleted_at TEXT, deleted_by TEXT,
    created_at TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL DEFAULT '',
    created_by TEXT NOT NULL DEFAULT '',
    updated_by TEXT NOT NULL DEFAULT '',
    user_code  TEXT NOT NULL DEFAULT ''
);
```

### 4.3 subtitles（字幕/歌词 - FTS5）

```sql
CREATE TABLE IF NOT EXISTS subtitles (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT UNIQUE NOT NULL,
    video_code      TEXT NOT NULL,
    content         TEXT NOT NULL,
    translation     TEXT,
    start_position  INTEGER NOT NULL DEFAULT 0,
    end_position    INTEGER NOT NULL DEFAULT 0,
    index           INTEGER NOT NULL DEFAULT 0,
    word_count      INTEGER NOT NULL DEFAULT 0,
    type            TEXT NOT NULL DEFAULT 'subtitle', -- 'subtitle' | 'lyric'
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT '',
    updated_at      TEXT NOT NULL DEFAULT '',
    user_code       TEXT NOT NULL DEFAULT ''
);

CREATE VIRTUAL TABLE IF NOT EXISTS subtitles_fts USING fts5(
    content, translation, content=subtitles, content_rowid=id
);
```

### 4.4 study_record（学习记录）

```sql
CREATE TABLE IF NOT EXISTS study_record (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT UNIQUE NOT NULL,
    user_code       TEXT NOT NULL,
    video_code      TEXT NOT NULL,
    date            TEXT NOT NULL,                   -- ISO8601（精确到天）
    start_time      TEXT NOT NULL,
    end_time        TEXT,
    duration        INTEGER NOT NULL DEFAULT 0,      -- ⚠️ 秒
    play_count      INTEGER NOT NULL DEFAULT 0,
    words_learned   INTEGER NOT NULL DEFAULT 0,
    test_score      REAL,
    test_type       TEXT,
    notes           TEXT,
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT '',
    updated_at      TEXT NOT NULL DEFAULT ''
);
```

### 4.5 word_book（单词本 — 两档记忆体系）

```sql
CREATE TABLE IF NOT EXISTS word_book (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT UNIQUE NOT NULL,
    word            TEXT NOT NULL,
    source_type     TEXT NOT NULL,                   -- 'video' | 'article' | 'music'
    source_code     TEXT NOT NULL,
    source_title    TEXT,
    segment_code    TEXT,
    context_sentence TEXT,
    screenshot_path TEXT,
    definitions_json TEXT,
    phonetic_uk     TEXT,
    phonetic_us     TEXT,
    morphology_json TEXT,
    mnemonic        TEXT,
    difficulty      INTEGER NOT NULL DEFAULT 0,      -- 1-5
    review_count    INTEGER NOT NULL DEFAULT 0,
    correct_count   INTEGER NOT NULL DEFAULT 0,
    last_review_at  TEXT,
    next_review_at  TEXT,
    mastery_level   TEXT NOT NULL DEFAULT 'learning', -- 'learning' | 'mastered'
    mastered_at     TEXT,
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    deleted_at TEXT, deleted_by TEXT,
    created_at TEXT NOT NULL DEFAULT '',
    updated_at TEXT NOT NULL DEFAULT '',
    created_by TEXT NOT NULL DEFAULT '',
    updated_by TEXT NOT NULL DEFAULT '',
    user_code  TEXT NOT NULL DEFAULT ''
);
```

**状态流转：**
```
收藏单词 → masteryLevel = 'learning'
点击认识 → masteryLevel = 'mastered'，记录 masteredAt
已掌握点击不认识 → masteryLevel = 'learning'，清空 masteredAt
已掌握点击删除 → isDeleted = true（软删除）
```

---

## 五、Supabase 云端计费表

> 以下为 Supabase PostgreSQL 中的计费相关表，不属于本地 SQLite。

### 5.1 pricing_rule（价格规则）

定义业务动作是否收费及单价：

| action_key | 默认收费 | 说明 |
|------------|---------|------|
| `ai_test_plan` | 免费 | AI 测试评价 |
| `ai_definition` | 免费 | AI 查词释义 |
| `ai_translate` | 免费 | AI 翻译 |
| `ai_tts` | 免费 | TTS 朗读 |
| `ai_conversation_question` | 收费 | AI 对话提问 |
| `ai_conversation_answer` | 收费 | AI 对话回答 |
| `st_pron_score` | 收费 | 发音/跟唱评分 |

### 5.2 usage_event（消费事件 — 账单真相源头）

`meta` JSON 字段结构：
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

### 5.3 账单统计层级

1. 业务动作汇总 → 2. 资源大类汇总 → 3. 文件夹汇总 → 4. 具体资源汇总 → 5. 单笔明细

### 5.4 前端展示原则

- 所有业务页不再展示费用文案
- 费用信息统一由"计费明细"模块展示
- 首页只展示汇总、趋势和分类入口

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
