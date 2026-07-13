# VidLang - 数据库设计

> **版本**: V2.0 | **日期**: 2026-07-13
> **状态**: 当前有效
> **适用读者**: 后端开发者、数据库管理员、AI 辅助工具

---

## 一、数据库概述

### 1.1 技术选型

| 项目 | 选择 | 说明 |
|------|------|------|
| **本地数据库** | SQLite (sqflite) | 轻量级、离线可用、Flutter 原生支持 |
| **云端数据库** | Supabase (PostgreSQL) | 跨设备同步、用户认证、实时功能 |
| **全文检索** | FTS5 (SQLite) | 字幕/分词的模糊搜索 |
| **ORM 方式** | 手写 toMap/fromMap | 轻量级，避免重型 ORM |

### 1.2 数据库名称和路径

| 平台 | 数据库路径 |
|------|-----------|
| iOS | `{应用Documents}/vidlang.db` |
| Android | `{应用Documents}/vidlang.db` |
| macOS/Linux | `~/.local/share/vidlang/vidlang.db` |

### 1.3 数据同步策略

```
用户操作
    ↓
先写本地 SQLite（离线可用，低延迟）
    ↓
异步同步到 Supabase（云端持久化，跨设备）
    ↓
登录新设备 → 从 Supabase 拉取全量数据到本地 SQLite
```

---

## 二、表结构设计

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
│  │                                          │    │      │
│  │  ┌─────────┐  ┌──────────────┐         │    │      │
│  │  │ article │<>│article_chapter│(旧版)   │    │      │
│  │  │ (文章)  │ 1:N              │         │    │      │
│  │  └────┬────┘  └──────────────┘         │    │      │
│  │       │1:N                             │    │      │
│  │  ┌────▼──────────┬──────────────┐      │    │      │
│  │  │article_       │article_      │      │    │      │
│  │  │paragraph      │sentence (FTS)│      │    │      │
│  │  └───────┬───────┴──────┬───────┘      │    │      │
│  │          │               │              │    │      │
│  │          ▼               ▼              │    │      │
│  │  ┌──────────────┐ ┌──────────────┐     │    │      │
│  │  │article_      │ │article_      │     │    │      │
│  │  │bookmark      │ │translation   │     │    │      │
│  │  └──────────────┘ └──────────────┘     │    │      │
│  └──────────────────────────────────────────┘    │      │
│                                                │      │
│  ┌─────────────────── 学习记录 ────────────┐    │      │
│  │                                          │    │      │
│  │  ┌─────────┐     ┌──────────────────┐   │    │      │
│  │  │  user   │<────│   study_record   │   │    │      │
│  │  │ (用户)  │ 1:N │   (学习记录)     │   │    │      │
│  │  └─────────┘     └────────┬─────────┘   │    │      │
│  │                           │              │    │      │
│  │                ┌──────────┼──────────┐    │    │      │
│  │                ▼          ▼          ▼    │    │      │
│  │  ┌─────────────┐ ┌──────────┐ ┌───────────┐│    │      │
│  │  │recording_   │ │test_     │ │ai_eval_   ││    │      │
│  │  │record       │ │session+  │ │uation_log ││    │      │
│  │  │(跟读录音)    │ │item+eval │ │(AI评价日志)││    │      │
│  │  └─────────────┘ └──────────┘ └───────────┘│    │      │
│  └──────────────────────────────────────────────┘    │      │
│                                                        │      │
│  ┌─────────────────── 单词本系统 ─────────────┐       │      │
│  │                                               │       │      │
│  │  ┌─────────┐     ┌──────────┐              │       │      │
│  │  │word_book│<────│word_book_ │              │       │      │
│  │  │(单词本)  │ N:M │tag        │              │       │      │
│  │  └────┬────┘     └─────┬────┘              │       │      │
│  │       │               │                    │       │      │
│  │       ▼               │                    │       │      │
│  │  ┌──────────┐    ┌────▼────┐               │       │      │
│  │  │ word_tag │    │word_    │               │       │      │
│  │  │(单词标签) │    │card_data│               │       │      │
│  │  │          │    │word_    │               │       │      │
│  │  └──────────┘    │detail   │               │       │      │
│  │                   └─────────┘               │       │      │
│  └───────────────────────────────────────────────┘       │      │
│                                                                │      │
│  ┌──────────────── 辅助表 ──────────────────┐                 │      │
│  │                                            │                 │      │
│  │  error_log / device_type / playback_settings /            │      │
│  │  conversation_message / conversation_record /             │      │
│  │  learning_resource / billing_summary / pricing_rule /     │      │
│  │  topup_config / evaluation_models / shengtong_*           │      │
│  └────────────────────────────────────────────────────────────┘      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 表清单（完整版，共 20 个已注册实体）

| 序号 | 表名 | 模型类 | 用途 | FTS5 |
|------|------|--------|------|------|
| **核心引擎** |
| 1 | `video_folder` | VideoFolder | 视频集/文件夹 | 否 |
| 2 | `video_info` | VideoInfo | 视频信息 | 否 |
| 3 | `subtitles` | Subtitles | 字幕行 | ✅ 是 |
| 4 | `participle` | Participle | 分词 | ✅ 是 |
| **文章引擎** |
| 5 | `article` | Article | 文章 | 否 |
| 6 | `article_chapter` | ArticleChapter | 文章章节（旧版迁移中） | 否 |
| 7 | `article_paragraph` | ArticleParagraph | 文章段落 | 否 |
| 8 | `article_sentence` | ArticleSentence | 文章句子 | ✅ 是 |
| 9 | `article_bookmark` | ArticleBookmark | 文章书签 | 否 |
| **学习记录** |
| 10 | `study_record` | StudyRecord | 学习记录 | ✅ 已注册 |
| 11 | `recording_record` | RecordingRecord | 跟读录音记录 | 否 |
| **测试/评测** |
| 12 | `test_session` | TestSession | 测试主记录 | 否 |
| 13 | `test_item` | TestItem | 单题记录 | 否 |
| 14 | `test_evaluation` | TestEvaluation | AI评价报告 | 否 |
| 15 | `ai_evaluation_log` | AiEvaluationLog | AI学习评价日志 | 否 |
| **单词本** |
| 16 | `word_book` | WordBook | 单词本 | 否 |
| 17 | `word_tag` | WordTag | 单词标签 | 否 |
| 18 | `word_book_tag` | WordBookTag | 单词-标签关联 | 否 |
| **系统** |
| 19 | `config` | Config | 系统配置（KV） | 否 |
| 20 | `user` | User | 用户信息 | 否 |
| 21 | `error_log` | ErrorLog | 错误日志 | 否 |
| **设备** |
| 22 | `device_type` | DeviceType | 设备类型 | 否 |

> **注**: 以上 22 个表中，前 20 个已在 `main.dart` 中通过 `DatabaseService.registerEntities()` 注册。`error_log` 和 `device_type` 也已导入并注册。

---

## 三、详细表结构

### 3.1 video_folder（视频集）

**用途**：存储视频集（文件夹）的元数据和播放配置。

```sql
CREATE TABLE IF NOT EXISTS video_folder (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT UNIQUE NOT NULL,          -- 业务主键（UUID）
    
    -- 业务字段
    name            TEXT NOT NULL DEFAULT '',      -- 视频集名称
    type            INTEGER NOT NULL DEFAULT 0,    -- 类型：0=虚拟集, 1=真实集
    path            TEXT,                          -- 绑定的外部路径（虚拟集）
    parent_code     TEXT,                          -- 父级视频集 code（多级目录）
    
    -- 统计字段
    video_count     INTEGER NOT NULL DEFAULT 0,    -- 视频总数
    completed_count INTEGER NOT NULL DEFAULT 0,    -- 已完成数
    
    -- 封面相关
    cover           TEXT,                          -- 文件夹封面路径
    thumbnail_time  INTEGER NOT NULL DEFAULT 15,   -- 封面截图时间点（秒）
    last_video_code TEXT,                          -- 最后播放的视频 code
    
    -- 播放进度
    last_play_date  TEXT,                          -- 最后播放时间（ISO8601）
    last_play_duration INTEGER NOT NULL DEFAULT 0, -- 最后播放时长（毫秒）
    
    -- 片头片尾跳过
    skip_opening            INTEGER NOT NULL DEFAULT 0,  -- 是否跳过片头（0/1）
    skip_opening_duration   INTEGER NOT NULL DEFAULT 0,  -- 片头跳过时长（秒）
    skip_ending             INTEGER NOT NULL DEFAULT 0,  -- 是否跳过片尾（0/1）
    skip_ending_duration    INTEGER NOT NULL DEFAULT 0,  -- 片尾跳过时长（秒）
    
    -- 排序和显示
    sort_order      INTEGER NOT NULL DEFAULT 0,    -- 排序权重
    
    -- 审计字段（BaseEntity）
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    deleted_at      TEXT,
    deleted_by      TEXT,
    created_at      TEXT NOT NULL DEFAULT '',
    updated_at      TEXT NOT NULL DEFAULT '',
    created_by      TEXT NOT NULL DEFAULT '',
    updated_by      TEXT NOT NULL DEFAULT '',
    user_code       TEXT NOT NULL DEFAULT ''
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_video_folder_user_code ON video_folder(user_code);
CREATE INDEX IF NOT EXISTS idx_video_folder_parent_code ON video_folder(parent_code);
CREATE INDEX IF NOT EXISTS idx_video_folder_last_play_date ON video_folder(last_play_date DESC);
CREATE INDEX IF NOT EXISTS idx_video_folder_is_deleted ON video_folder(is_deleted);
```

**Dart 模型映射：**

```dart
class VideoFolder extends BaseEntity {
  String name = '';
  VideoFolderType type = VideoFolderType.virtual;
  String? path;                    // 外部路径（虚拟集）
  String? parentCode;              // 父级 code
  
  int videoCount = 0;
  int completedCount = 0;
  
  String? cover;
  int thumbnailTime = 15;          // 截图时间点（秒）
  String? lastVideoCode;
  
  DateTime? lastPlayDate;
  int lastPlayDuration = 0;        // 毫秒
  
  bool skipOpening = false;
  int skipOpeningDuration = 0;     // 秒
  bool skipEnding = false;
  int skipEndingDuration = 0;      // 秒
  
  int sortOrder = 0;
  
  @override
  String get tableName => 'video_folder';
  
  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.index,
      'path': path,
      'parent_code': parentCode,
      'video_count': videoCount,
      'completed_count': completedCount,
      'cover': cover,
      'thumbnail_time': thumbnailTime,
      'last_video_code': lastVideoCode,
      'last_play_date': lastPlayDate?.toIso8601String(),
      'last_play_duration': lastPlayDuration,
      'skip_opening': skipOpening ? 1 : 0,
      'skip_opening_duration': skipOpeningDuration,
      'skip_ending': skipEnding ? 1 : 0,
      'skip_ending_duration': skipEndingDuration,
      'sort_order': sortOrder,
      ...super.toMap(),
    };
  }
}
```

### 3.2 video_info（视频）

**用途**：存储单个视频的元数据、播放进度、学习统计。

```sql
CREATE TABLE IF NOT EXISTS video_info (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    code                TEXT UNIQUE NOT NULL,          -- 业务主键（UUID）
    
    -- 基本信息
    name                TEXT NOT NULL DEFAULT '',      -- 视频名称
    folder_code         TEXT NOT NULL,                 -- 所属视频集 code
    file_path           TEXT,                          -- 视频文件路径 ✅ 已实现
    
    -- 时长和进度
    duration            INTEGER NOT NULL DEFAULT 0,    -- 总时长（毫秒）
    cover               TEXT,                          -- 视频封面路径
    current_cover       TEXT,                          -- 当前播放截图
    current_position    INTEGER NOT NULL DEFAULT 0,    -- 当前播放位置（毫秒）
    
    -- 播放状态
    is_current_playing  INTEGER NOT NULL DEFAULT 0,    -- 是否正在播放（0/1）
    has_subtitles       INTEGER NOT NULL DEFAULT 0,    -- 是否有字幕（0/1）
    
    -- 统计信息
    play_date           TEXT,                          -- 最后播放时间（ISO8601）
    play_count          INTEGER NOT NULL DEFAULT 0,    -- 总播放次数
    total_play_duration INTEGER NOT NULL DEFAULT 0,    -- 总学习时长（⚠️ 单位：秒）
    
    -- 排序
    sort_order          INTEGER NOT NULL DEFAULT 0,
    
    -- 审计字段
    is_deleted          INTEGER NOT NULL DEFAULT 0,
    deleted_at          TEXT,
    deleted_by          TEXT,
    created_at          TEXT NOT NULL DEFAULT '',
    updated_at          TEXT NOT NULL DEFAULT '',
    created_by          TEXT NOT NULL DEFAULT '',
    updated_by          TEXT NOT NULL DEFAULT '',
    user_code           TEXT NOT NULL DEFAULT ''
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_video_info_folder_code ON video_info(folder_code);
CREATE INDEX IF NOT EXISTS idx_video_info_user_code ON video_info(user_code);
CREATE INDEX IF NOT EXISTS idx_video_info_is_deleted ON video_info(is_deleted);
CREATE INDEX IF NOT EXISTS idx_video_info_play_date ON video_info(play_date DESC);
```

**重要说明 - 时长单位：**
- `duration`: **毫秒**（视频总时长）
- `current_position`: **毫秒**（当前播放位置）
- `total_play_duration`: **秒**（累计学习时长，与 StudyRecord.duration 保持一致）

### 3.3 subtitles（字幕）- FTS5 全文检索

**用途**：存储视频/文章/歌曲的字幕行，支持全文搜索。

```sql
-- 主表
CREATE TABLE IF NOT EXISTS subtitles (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT UNIQUE NOT NULL,
    
    -- 关联和内容
    video_code      TEXT NOT NULL,                   -- 所属视频 code
    content         TEXT NOT NULL,                   -- 字幕原文
    translation     TEXT,                            -- 翻译文本
    
    -- 时间轴（毫秒）
    start_position  INTEGER NOT NULL DEFAULT 0,      -- 开始时间
    end_position    INTEGER NOT NULL DEFAULT 0,      -- 结束时间
    
    -- 序号和元数据
    index           INTEGER NOT NULL DEFAULT 0,      -- 行号
    word_count      INTEGER NOT NULL DEFAULT 0,      -- 词数
    
    -- 审计字段
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT '',
    updated_at      TEXT NOT NULL DEFAULT '',
    user_code       TEXT NOT NULL DEFAULT ''
);

-- FTS5 全文检索虚拟表
CREATE VIRTUAL TABLE IF NOT EXISTS subtitles_fts USING fts5(
    content,
    translation,
    content=subtitles,
    content_rowid=id
);

-- 触发器：插入时同步到 FTS
CREATE TRIGGER IF NOT EXISTS subtitles_ai AFTER INSERT ON subtitles BEGIN
    INSERT INTO subtitles_fts(rowid, content, translation)
    VALUES (new.id, new.content, new.translation);
END;

-- 触发器：删除时从 FTS 移除
CREATE TRIGGER IF NOT EXISTS subtitles_ad AFTER DELETE ON subtitles BEGIN
    INSERT INTO subtitles_fts(subtitles_fts, rowid, content, translation)
    VALUES ('delete', old.id, old.content, old.translation);
END;

-- 更新触发器（先删后插）
CREATE TRIGGER IF NOT EXISTS subtitles_au AFTER UPDATE ON subtitles BEGIN
    INSERT INTO subtitles_fts(subtitles_fts, rowid, content, translation)
    VALUES ('delete', old.id, old.content, old.translation);
    INSERT INTO subtitles_fts(rowid, content, translation)
    VALUES (new.id, new.content, new.translation);
END;

-- 索引
CREATE INDEX IF NOT EXISTS idx_subtitles_video_code ON subtitles(video_code);
CREATE INDEX IF NOT EXISTS idx_subtitles_user_code ON subtitles(user_code);
```

**FTS5 查询示例：**

```dart
// 搜索包含 "hello" 的字幕行
final results = await databaseService.searchFTS(
  () => Subtitles(),
  'subtitles',
  'hello',  // 搜索关键词
  where: 'video_code = ?',
  whereArgs: [videoCode],
);
```

### 3.4 participle（分词）- FTS5 全文检索

**用途**：存储字幕的分词结果，用于单词级别的搜索和学习。

```sql
-- 主表
CREATE TABLE IF NOT EXISTS participle (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT UNIQUE NOT NULL,
    
    -- 关联
    subtitle_code   TEXT NOT NULL,                   -- 所属字幕行 code
    video_code      TEXT NOT NULL,                   -- 所属视频 code
    
    -- 分词内容
    word            TEXT NOT NULL,                   -- 单词原文
    lemma           TEXT,                            // 词元（原形）
    pos_tag         TEXT,                            // 词性标签（NN/VB/等）
    phonetic        TEXT,                            // 音标
    translation     TEXT,                            // 中文释义
    
    -- 位置信息
    start_char      INTEGER NOT NULL DEFAULT 0,      -- 在字幕中的起始字符位置
    end_char        INTEGER NOT NULL DEFAULT 0,      -- 在字幕中的结束字符位置
    
    -- 审计字段
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT '',
    user_code       TEXT NOT NULL DEFAULT ''
);

-- FTS5 虚拟表
CREATE VIRTUAL TABLE IF NOT EXISTS participle_fts USING fts5(
    word,
    lemma,
    translation,
    content=participle,
    content_rowid=id
);

-- 触发器（同 subtitles，略）
...
```

### 3.5 config（系统配置）

**用途**：存储全局配置项，采用 Key-Value 模式。

```sql
CREATE TABLE IF NOT EXISTS config (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT UNIQUE NOT NULL,
    
    -- KV 结构
    category        TEXT NOT NULL DEFAULT '',        -- 配置分类（system/playback/ui/...）
    key             TEXT NOT NULL DEFAULT '',        -- 配置键名
    value           TEXT,                            -- 配置值
    value_type      TEXT NOT NULL DEFAULT 'string',  -- 值类型：string/int/bool/double/json
    
    -- 描述
    description     TEXT,                            -- 配置说明
    
    -- 审计字段
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT '',
    updated_at      TEXT NOT NULL DEFAULT '',
    user_code       TEXT NOT NULL DEFAULT ''
);

-- 唯一约束：同一分类下 key 唯一
CREATE UNIQUE INDEX IF NOT EXISTS idx_config_category_key ON config(category, key);
```

**预置配置项示例：**

| category | key | value | value_type | 说明 |
|----------|-----|-------|------------|------|
| system | current_user_code | uuid | string | 当前用户 ID |
| system | current_token | token | string | 认证 Token |
| playback | skip_opening_enabled | true | bool | 默认跳过片头 |
| playback | skip_opening_seconds | 30 | int | 默认片头秒数 |
| playback | skip_ending_enabled | false | bool | 默认跳过片尾 |
| playback | skip_ending_seconds | 10 | int | 默认片尾秒数 |
| playback | thumbnail_time_seconds | 15 | int | 默认封面截图时间点 |
| ui | theme_mode | system | string | 主题模式：light/dark/system |
| ui | language | en | string | UI 语言 |

### 3.6 user（用户）

**用途**：存储用户基本信息。

```sql
CREATE TABLE IF NOT EXISTS user (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT UNIQUE NOT NULL,
    
    -- 基本信息
    email           TEXT,
    phone           TEXT,
    display_name    TEXT NOT NULL DEFAULT '',      -- 显示名称
    avatar_url      TEXT,                          -- 头像 URL
    
    -- Supabase 关联
    supabase_uid    TEXT,                          -- Supabase Auth UID
    
    -- 统计
    total_study_minutes INTEGER NOT NULL DEFAULT 0, -- 累计学习分钟数
    streak_days     INTEGER NOT NULL DEFAULT 0,    -- 连续学习天数
    
    -- 审计字段
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT '',
    updated_at      TEXT NOT NULL DEFAULT ''
);
```

### 3.7 study_record（学习记录）✅ 已注册

**用途**：记录每次学习的详细信息，用于统计和分析。

```sql
-- ✅ 此表已在 main.dart 中注册
CREATE TABLE IF NOT EXISTS study_record (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT UNIQUE NOT NULL,
    
    -- 关联
    user_code       TEXT NOT NULL,
    video_code      TEXT NOT NULL,                   -- 视频 code
    
    -- 时间信息
    date            TEXT NOT NULL,                   -- 学习日期（ISO8601，只精确到天）
    start_time      TEXT NOT NULL,                   -- 开始时间
    end_time        TEXT,                            -- 结束时间
    
    -- 学习数据
    duration        INTEGER NOT NULL DEFAULT 0,      -- ⚠️ 学习时长（单位：秒）
    play_count      INTEGER NOT NULL DEFAULT 0,      -- 完整播放次数
    words_learned   INTEGER NOT NULL DEFAULT 0,      -- 新学单词数
    test_score      REAL,                            -- 测试得分（0-100）
    test_type       TEXT,                            -- 测试类型：fill/dictation/quiz
    
    -- 额外信息
    notes           TEXT,                            -- 学习笔记
    
    -- 审计字段
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT '',
    updated_at      TEXT NOT NULL DEFAULT ''
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_study_record_user_code ON study_record(user_code);
CREATE INDEX IF NOT EXISTS idx_study_record_video_code ON study_record(video_code);
CREATE INDEX IF NOT EXISTS idx_study_record_date ON study_record(date DESC);
```

---

## 四、字段命名规范

### 4.1 基本规则

| 场景 | 规范 | 示例 |
|------|------|------|
| **表名** | snake_case | `video_info`, `study_record` |
| **字段名** | snake_case | `folder_code`, `created_at` |
| **主键** | `id` | `INTEGER PRIMARY KEY AUTOINCREMENT` |
| **业务主键** | `code` | `TEXT UNIQUE`（UUID 格式） |
| **外键** | `{关联表}_code` | `folder_code`, `user_code` |
| **布尔字段** | `is_{形容词}` 或动词 | `is_deleted`, `has_subtitles`, `skip_opening` |
| **时间字段** | ISO8601 字符串 | `2026-07-12T10:30:00Z` |
| **时长字段** | 明确单位注释 | 视频用毫秒，学习记录用秒 |

### 4.2 审计字段（BaseEntity 标配）

所有表必须包含以下审计字段：

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `is_deleted` | INTEGER | 软删除标记（0=未删除, 1=已删除） |
| `deleted_at` | TEXT | 删除时间（ISO8601） |
| `deleted_by` | TEXT | 删除操作人 code |
| `created_at` | TEXT | 创建时间（ISO8601） |
| `updated_at` | TEXT | 更新时间（ISO8601） |
| `created_by` | TEXT | 创建人 code |
| `updated_by` | TEXT | 更新人 code |
| `user_code` | TEXT | 用户标识（多用户支持） |

---

## 五、索引设计原则

### 5.1 必须创建索引的场景

1. **外键字段**：如 `folder_code`, `user_code`, `video_code`
2. **查询条件字段**：经常出现在 WHERE 子句中
3. **排序字段**：经常出现在 ORDER BY 中
4. **软删除字段**：`is_deleted`（几乎所有查询都需要过滤）
5. **时间字段**：按时间范围查询时

### 5.2 索引命名规范

```
idx_{表名}_{字段名}[_{方向}]
```

示例：
- `idx_video_info_folder_code`
- `idx_video_folder_last_play_date_DESC`
- `idx_study_record_user_code`

### 5.3 复合索引使用场景

当多个字段经常同时作为查询条件时：

```sql
-- 例：查询某用户在某日期范围内的学习记录
CREATE INDEX IF NOT EXISTS idx_study_record_user_date 
ON study_record(user_code, date DESC);
```

---

## 六、数据迁移策略

### 6.1 版本管理

```dart
// DatabaseService 中维护版本号
static const int _dbVersion = 1;

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // V1 → V2：添加新字段
    await db.execute('ALTER TABLE video_info ADD COLUMN file_path TEXT');
  }
  if (oldVersion < 3) {
    // V2 → V3：添加新表
    await _createTable(StudyRecord());
  }
}
```

### 6.2 迁移操作类型

| 操作类型 | SQL 语句 | 注意事项 |
|----------|----------|----------|
| 添加列 | `ALTER TABLE {表} ADD COLUMN {列} {类型}` | 可空或带默认值 |
| 删除列 | ❌ SQLite 不支持 | 需要重建表 |
| 修改列类型 | ❌ SQLite 不支持 | 需要重建表 |
| 添加表 | `CREATE TABLE IF NOT EXISTS` | 正常执行 |
| 删除表 | `DROP TABLE IF EXISTS` | ⚠️ 会丢失数据 |
| 添加索引 | `CREATE INDEX IF NOT EXISTS` | 正常执行 |

### 6.3 表重建流程（当需要删除/修改列时）

```dart
Future<void> _rebuildTable<T extends BaseEntity>(T entityFactory) async {
  final db = await database;
  final tableName = entityFactory().tableName;
  final tempTableName = '${tableName}_temp';
  
  // 1. 创建新结构的临时表
  await db.execute('''
    CREATE TABLE $tempTableName AS SELECT * FROM $tableName WHERE 0
  ''');
  
  // 2. 迁移数据（选择需要的列）
  await db.execute('''
    INSERT INTO $tempTableName (col1, col2, col3)
    SELECT col1, col2, col3 FROM $tableName
  ''');
  
  // 3. 删除旧表
  await db.execute('DROP TABLE $tableName');
  
  // 4. 重命名临时表
  await db.execute('ALTER TABLE $tempTableName RENAME TO $tableName');
  
  // 5. 重建索引
  await _createIndexes(entityFactory);
}
```

---

## 七、查询优化建议

### 7.1 使用参数化查询

```dart
// ✅ 推荐：参数化查询（防 SQL 注入）
await db.query(
  'video_info',
  where: 'folder_code = ? AND is_deleted = ?',
  whereArgs: [folderCode, 0],
  orderBy: 'play_date DESC',
  limit: 20,
);

// ❌ 避免：字符串拼接（SQL 注入风险）
await db.query(
  'video_info',
  where: "folder_code = '$folderCode'",  // 危险！
);
```

### 7.2 分页查询

```dart
// 标准分页模式
Future<List<VideoInfo>> getVideosPaginated({
  required String folderCode,
  required int page,
  int pageSize = 20,
}) async {
  final offset = (page - 1) * pageSize;
  
  return await findByCondition(
    () => VideoInfo(),
    where: 'folder_code = ? AND is_deleted = 0',
    whereArgs: [folderCode],
    orderBy: 'sort_order ASC, created_at DESC',
    limit: pageSize,
    offset: offset,
  );
}
```

### 7.3 FTS5 全文检索优化

```dart
/// 高级搜索：支持短语匹配、前缀匹配、布尔查询
Future<List<Subtitles>> searchSubtitlesAdvanced({
  required String query,
  String? videoCode,
  int limit = 50,
}) async {
  // 构建查询语句
  var ftsQuery = query;
  
  // 支持前缀匹配（如 "hel*" 匹配 "hello", "help"）
  if (!query.contains(' ') && !query.contains('"')) {
    ftsQuery = '$query*';
  }
  
  // 支持短语匹配（用双引号包裹）
  // "hello world" 精确匹配短语
  
  var sql = '''
    SELECT s.* FROM subtitles s
    JOIN subtitles_fts fts ON s.id = fts.rowid
    WHERE subtitles_fts MATCH ?
    AND s.is_deleted = 0
  ''';
  
  var args = [ftsQuery];
  
  if (videoCode != null) {
    sql += ' AND s.video_code = ?';
    args.add(videoCode);
  }
  
  sql += ' ORDER BY s.index ASC LIMIT ?';
  args.add(limit);
  
  // 执行查询并映射到对象
  // ...
}
```

---

## 八、备份与恢复

### 8.1 手动备份

```dart
/// 备份数据库到指定路径
Future<void> backupDatabase(String backupPath) async {
  final db = await database;
  final sourcePath = db.path;
  
  // 复制数据库文件
  await File(sourcePath).copy(backupPath);
  
  print('数据库已备份到: $backupPath');
}

/// 从备份恢复数据库
Future<void> restoreDatabase(String backupPath) async {
  // 1. 关闭当前数据库连接
  await _database?.close();
  _database = null;
  
  // 2. 替换数据库文件
  final dbPath = await getDatabasePath('vidlang.db');
  await File(backupPath).copy(dbPath, overwrite: true);
  
  // 3. 重新打开数据库
  _database = await openDatabase(dbPath, version: _dbVersion, onUpgrade: _onUpgrade);
  
  print('数据库已从备份恢复');
}
```

### 8.2 自动备份策略（建议）

| 备份频率 | 保留数量 | 存储位置 |
|----------|----------|----------|
| 每日备份 | 7 天 | 本地 documents 目录 |
| 每周备份 | 4 周 | iCloud / Google Drive |
| 手动备份 | 不限 | 用户指定位置 |

---

## 九、性能监控

### 9.1 慢查询日志

```dart
/// 包装查询方法，记录执行时间
Future<List<T>> queryWithTiming<T>({
  required String table,
  required Future<List<Map<String, dynamic>>> Function() queryFn,
}) async {
  final stopwatch = Stopwatch()..start();
  
  try {
    final results = await queryFn();
    stopwatch.stop();
    
    if (stopwatch.elapsedMilliseconds > 100) {
      // 超过 100ms 记录警告
      print('⚠️ 慢查询: $table 耗时 ${stopwatch.elapsedMilliseconds}ms');
    }
    
    return results;
  } catch (e) {
    stopwatch.stop();
    print('❌ 查询失败: $table 错误: $e 耗时 ${stopwatch.elapsedMilliseconds}ms');
    rethrow;
  }
}
```

### 9.2 数据库大小监控

```dart
/// 获取数据库大小
Future<int> getDatabaseSizeInBytes() async {
  final db = await database;
  final file = File(db.path);
  
  if (await file.exists()) {
    return await file.length();
  }
  return 0;
}

/// 格式化显示数据库大小
String formatDatabaseSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
```

---

## 十、常见问题

### Q1: 数据库锁定（database is locked）？

**原因**：多个并发写入操作导致 SQLite 锁定。

**解决方案**：
1. 使用单例模式的 `DatabaseService`
2. 将批量操作放在事务中
3. 避免在 UI 线程执行长时间查询
4. 考虑使用 WAL 模式（Write-Ahead Logging）

```dart
// 启用 WAL 模式
await db.execute('PRAGMA journal_mode=WAL');
```

### Q2: FTS5 搜索无结果？

**排查步骤**：
1. 检查触发器是否正确创建（插入数据时是否同步到 FTS 表）
2. 检查搜索语法是否正确（特殊字符需转义）
3. 检查 `content_rowid` 配置是否正确
4. 使用 `EXPLAIN QUERY PLAN` 分析查询计划

### Q3: 如何处理大量数据的导入性能？

**优化方案**：
1. 使用事务批量插入
2. 导入前禁用索引，导入后重建
3. 分批次导入（每批 500-1000 条）
4. 显示进度条提升用户体验

```dart
/// 批量导入（事务 + 分批）
Future<void> batchInsert(List<BaseEntity> entities, {int batchSize = 500}) async {
  final db = await database;
  
  for (var i = 0; i < entities.length; i += batchSize) {
    final batch = entities.skip(i).take(batchSize).toList();
    
    await db.transaction((txn) async {
      for (var entity in batch) {
        await txn.insert(entity.tableName, entity.toMap());
      }
    });
    
    // 回调进度
    onProgress?.call(i + batch.length, entities.length);
  }
}
```

---

**最后更新**: 2026-07-12  
**维护者**: VidLang 开发团队  
**相关文档**: [README.md](./README.md), [Flutter 代码结构详解](./flutter-code-structure.md), [服务层架构](./services-architecture.md)
