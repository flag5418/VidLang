# VidLang 数据库表结构设计

> 设计原则：最小改动现有表，主要新增文章/单词相关表。

---

## 一、ER 关系总览

```
resource_folder (扩展 video_folder)
       │
       ├── video_info (视频资源，不变)
       │       └── subtitles (字幕，不变)
       │
       ├── article (新增：文章主表)
       │       ├── article_chapter (新增：文章章节)
       │       └── article_sentence (新增：文章句子)
       │
       └── music (暂用 video_info + subtitles type=lyric)

study_record (扩展：支持 resource_type + resource_code)
word_book (新增：跨来源单词本)
recording_record (新增：跟读录音记录)
participle (保留，向后兼容)

config (不变)
user (不变)
error_log (不变)
```

---

## 二、现有表修改

### 2.1 video_folder — 增加 folder_type 字段

```dart
// 新增枚举
enum FolderContentType {
  video,    // 视频文件夹（默认）
  article,  // 文章文件夹
  music,    // 歌曲/MTV文件夹
}

// VideoFolder 新增字段
class VideoFolder extends BaseEntity {
  // ... 原有字段全部保留 ...

  /// 文件夹内容类型：video / article / music
  /// 默认为 video，保持向后兼容
  FolderContentType folderType;
}
```

**对应的 SQL 变更：** 新增 `folder_type` 列，默认 `'video'`

**WiFi API 中 `_folderJson` 增加：**
```dart
Map<String, Object?> _folderJson(VideoFolder f) {
  return {
    ... existing fields,
    'folderType': f.folderType.name,  // 'video' | 'article' | 'music'
    'canUpload': f.type == VideoFolderType.real,
  };
}
```

### 2.2 subtitles — 增加 type 字段（支持 MTV 歌词）

```dart
class Subtitles extends BaseEntity {
  // ... 原有字段全部保留 ...

  /// 片段类型：subtitle（字幕） / lyric（歌词）
  /// 默认为 'subtitle'，保持向后兼容
  String type;

  // 原有 videoCode 字段的注释更新：
  /// 视频code（关联 VideoInfo）
  /// 对于 MTV：存储歌词时间轴
  String videoCode;
}
```

**SQL 变更：** 新增 `type` 列，默认 `'subtitle'`

### 2.3 study_record — 扩展支持文章/歌曲

```dart
class StudyRecord extends BaseEntity {
  // 原有字段
  // String videoCode;      ← 改为 resourceCode，保留 videoCode 作为别名
  // DateTime date;
  // DateTime startTime;
  // DateTime? endTime;
  // int duration;
  // int playCount;

  // 修改为：
  /// 资源 code（关联 video_info.code / article.code）
  String resourceCode;

  /// 资源类型：video / article / music
  String resourceType;

  /// 所属文件夹 code
  String folderCode;

  /// 学习日期
  DateTime date;

  /// 学习开始时间
  DateTime startTime;

  /// 学习结束时间
  DateTime? endTime;

  /// 学习时长（秒）
  int duration;

  /// 学习进度（本次学习了多少句/条）
  int segmentsStudied;

  /// 收藏单词数
  int wordsSaved;

  /// 测试得分（可选）
  double? testScore;

  /// 跟读次数
  int followCount;

  /// 最佳跟读分数
  double? bestFollowScore;
}
```

**向后兼容：** 读数据时如果 `resource_code` 为空，用 `video_code` 回退

---

## 三、新增表

### 3.1 article（文章主表）

```dart
class Article extends BaseEntity {
  /// 所属文件夹 code
  String folderCode;

  /// 文章标题
  String title;

  /// 原文全文（Markdown 格式）
  String contentMarkdown;

  /// 封面图路径
  String? coverUrl;

  /// 作者
  String? author;

  /// 来源 URL
  String? sourceUrl;

  /// 语言，默认 'en'
  String language;

  /// 总章节数
  int totalChapters;

  /// 总句子数
  int totalSentences;

  /// 总单词数
  int wordCount;

  /// 学习进度 0.0 ~ 1.0
  double progress;

  /// 最后学习的章节索引
  int lastChapterIndex;

  /// 最后学习的句子索引
  int lastSentenceIndex;

  /// 最后学习时间
  DateTime? lastStudyDate;

  /// 学习次数
  int studyCount;

  /// 排序索引
  int orderIndex;

  @override
  String get tableName => 'article';
}
```

**SQL:**
```sql
CREATE TABLE IF NOT EXISTS article (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL,
  user_code TEXT,
  folder_code TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  content_markdown TEXT NOT NULL DEFAULT '',
  cover_url TEXT,
  author TEXT,
  source_url TEXT,
  language TEXT NOT NULL DEFAULT 'en',
  total_chapters INTEGER NOT NULL DEFAULT 0,
  total_sentences INTEGER NOT NULL DEFAULT 0,
  word_count INTEGER NOT NULL DEFAULT 0,
  progress REAL NOT NULL DEFAULT 0.0,
  last_chapter_index INTEGER NOT NULL DEFAULT 0,
  last_sentence_index INTEGER NOT NULL DEFAULT 0,
  last_study_date TEXT,
  study_count INTEGER NOT NULL DEFAULT 0,
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_by TEXT,
  updated_by TEXT,
  deleted_by TEXT
);
```

### 3.2 article_chapter（文章章节）

```dart
class ArticleChapter extends BaseEntity {
  /// 所属文章 code
  String articleCode;

  /// 章节序号（从0开始）
  int chapterIndex;

  /// 章节标题
  String title;

  /// 该章节的 Markdown 原文
  String markdown;

  /// 该章节起始句子索引
  int startSentenceIndex;

  /// 该章节包含的句子数
  int sentenceCount;

  /// 章节跟读录音路径
  String? recordingPath;

  /// 最后跟读评分
  double? lastScore;

  @override
  String get tableName => 'article_chapter';
}
```

### 3.3 article_sentence（文章句子）

```dart
class ArticleSentence extends BaseEntity {
  /// 所属文章 code
  String articleCode;

  /// 所属章节索引
  int chapterIndex;

  /// 句子序号（全局，从0开始）
  int sequenceIndex;

  /// 句子原文
  String content;

  /// 翻译
  String? contentTranslate;

  /// 阅读时间轴：累计起始位置（毫秒）
  int startPositionMs;

  /// 阅读时间轴：累计结束位置（毫秒）
  int endPositionMs;

  /// 单词数
  int wordCount;

  /// 是否被用户标记为重点句
  bool isKeySentence;

  @override
  String get tableName => 'article_sentence';
}
```

**开启全文检索：**
```dart
// 在 main.dart 注册时：
'article_sentence': EntityConfig(
  creator: () => ArticleSentence(),
  description: '文章句子表',
  enableFullTextSearch: true,
),
```

### 3.4 word_book（单词本）

替代/扩展 `participle`，支持跨来源收藏。

```dart
class WordBook extends BaseEntity {
  /// 单词
  String word;

  /// 来源类型：video / article / music
  String sourceType;

  /// 来源资源 code
  String sourceCode;

  /// 来源标题（缓存展示用）
  String? sourceTitle;

  /// 来源句子/字幕 code
  String? segmentCode;

  /// 上下文句子原文
  String? contextSentence;

  /// DeepSeek 查询结果缓存（JSON）
  String? definitionsJson;

  /// 英式音标
  String? phoneticUk;

  /// 美式音标
  String? phoneticUs;

  /// 难度 1-5
  int difficulty;

  /// 复习次数
  int reviewCount;

  /// 答对次数
  int correctCount;

  /// 最后复习时间
  DateTime? lastReviewAt;

  /// 下次复习时间（间隔重复）
  DateTime? nextReviewAt;

  /// 掌握程度：learning / reviewing / mastered
  String masteryLevel;

  @override
  String get tableName => 'word_book';
}
```

### 3.5 recording_record（跟读录音记录）

```dart
class RecordingRecord extends BaseEntity {
  /// 资源 code
  String resourceCode;

  /// 资源类型：video / article / music
  String resourceType;

  /// 跟读范围：full / chapter / sentence
  String scope;

  /// 章节 code（可选）
  String? chapterCode;

  /// 句子 code（可选）
  String? sentenceCode;

  /// 录音文件路径
  String audioPath;

  /// 录音时长（毫秒）
  int durationMs;

  /// 总分 0-100
  double? overallScore;

  /// 流利度
  double? fluencyScore;

  /// 准确度
  double? accuracyScore;

  /// 完整度
  double? completenessScore;

  /// 逐词评分 JSON
  String? wordScoresJson;

  /// 声通原始返回 JSON
  String? rawResultJson;

  /// 录音时间
  DateTime recordedAt;

  @override
  String get tableName => 'recording_record';
}
```

---

## 四、表关系总表

| 表名 | 操作 | 关联 | 说明 |
|------|------|------|------|
| `video_folder` | **修改**（加 `folder_type`） | — | 通用文件夹 |
| `video_info` | **不变** | → `video_folder.code` | 视频/音频资源 |
| `subtitles` | **修改**（加 `type`） | → `video_info.code` | 字幕/歌词片段 |
| `article` | **新增** | → `video_folder.code` | 文章主表 |
| `article_chapter` | **新增** | → `article.code` | 文章章节 |
| `article_sentence` | **新增**（FTS） | → `article.code` | 文章句子 |
| `word_book` | **新增** | 跨表 | 单词本 |
| `recording_record` | **新增** | 跨表 | 跟读录音 |
| `study_record` | **修改** | → 跨表 | 学习记录 |
| `participle` | **保留**（不动） | → `video_info.code` | 旧分词表（向后兼容） |
| `config` | **不变** | — | 配置 |
| `user` | **不变** | — | 用户 |
| `error_log` | **不变** | — | 错误日志 |

---

## 五、在 main.dart 中的注册

```dart
DatabaseService.registerEntities({
  // 现有
  'video_folder': EntityConfig(creator: () => VideoFolder(), description: '文件夹表'),
  'video_info': EntityConfig(creator: () => VideoInfo(), description: '资源表'),
  'subtitles': EntityConfig(creator: () => Subtitles(), description: '字幕/歌词表', enableFullTextSearch: true),
  'participle': EntityConfig(creator: () => Participle(), description: '分词表', enableFullTextSearch: true),
  'config': EntityConfig(creator: () => Config(), description: '配置表'),
  'study_record': EntityConfig(creator: () => StudyRecord(), description: '学习记录表'),
  'user': EntityConfig(creator: () => User(), description: '用户表'),
  'error_log': EntityConfig(creator: () => ErrorLog(), description: '错误日志表'),

  // 新增
  'article': EntityConfig(creator: () => Article(), description: '文章表'),
  'article_chapter': EntityConfig(creator: () => ArticleChapter(), description: '文章章节表'),
  'article_sentence': EntityConfig(creator: () => ArticleSentence(), description: '文章句子表', enableFullTextSearch: true),
  'word_book': EntityConfig(creator: () => WordBook(), description: '单词本表'),
  'recording_record': EntityConfig(creator: () => RecordingRecord(), description: '跟读录音记录表'),
});
```

---

## 六、数据库版本号

**保持 `_databaseVersion = 1` 不变。**

`DatabaseService._ensureTable` 在每次 `onOpen` 时自动检测缺表并创建。新增的列（`folder_type`、`type`）通过 `ALTER TABLE ADD COLUMN` 自动迁移。无需升级版本号。
