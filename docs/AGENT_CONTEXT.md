# VidLang — AI 上下文速查（优先读此文件）

> **用途**：供 Cursor/Agent 快速恢复项目认知，避免每次重读全库。  
> **维护**：功能/架构有实质变化时由开发者或 Agent 增量更新本节。  
> **最后核对**：2026-07-13（大规模同步当前代码状态，修复 13+ 处文档滞后问题）

---

## 1. 产品是什么

**VidLang** — Learn English through videos, articles & songs. All in one place.

通过**视频、文章、歌曲三种媒介**，让英语学习融入日常生活。支持本地导入内容 + AI 辅助学习（查词、翻译、跟读评分、测试）。

核心学习闭环（已实现）：

```
内容导入（视频/文章/歌曲）→ 播放/阅读（断点续播、片头片尾跳过）→ 字幕/分词存储
→ 滑词查词(AI) / 单句暂停 / 变速(0.5x-2.0x) / 由慢到快
→ 跟读评分(TTS+录音) → 单集测试 → 学习记录统计 → 单词本收藏
```

**三引擎架构**：
- 🎬 **VideoPlayer** (OmniPlayer) — 视频学习引擎
- 📖 **ArticleReader** (TTS/Audio) — 文章阅读引擎  
- 🎵 **SongPlayer** (Audio+歌词) — 歌曲学习引擎

三者共享统一的学习引擎（WordLookup、Recording+Scoring、TestEngine、WordBook、StudyRecord）。

**视觉**：汽水音乐 + 腾讯 Lemon——干净、层级清晰、**图标统一**（`lib/theme/app_icons.dart`，Material rounded 线性风格）。  
**主题（已确认）**：
- 深色背景主色：`#2E302A`（黑绿灰，非纯黑）
- 浅色：以白色为主
- 两套主题都要保留

详见 `design-style-guide.md`（待按上表更新）、`pages/files.md`。

---

## 1.1 视频集（文件夹）两种类型 — 产品定义

| 类型 | 用户说法 | 行为 | 存储 |
|------|----------|------|------|
| **虚拟视频集** | 首屏创建、导入本地文件夹 | 按用户磁盘上**文件夹名**在 App 内建一条记录；**视频/字幕文件不拷入应用目录**（省空间）；`VideoFolder.path` 指向源目录；详情**只列视频**，不展示同目录下的字幕/图片/文本等文件条目 | 元数据在 SQLite；媒体路径在设备原位置 |
| **真实视频集** | WiFi 传输模块（后续） | 设备开 WiFi 服务，电脑浏览器上传/管理；App 内创建的真实目录；文件默认进应用目录（**可讨论**是否改为系统可访问路径，便于用系统文件管理器管理） | 后续实现 |

**当前代码实现（已修正）**：
- ✅ `VideoInfo.filePath` 字段**已存在**（默认空字符串），虚拟集可正常播放
- ✅ 文件类型使用 `fileType` 字段：`'virtual'`（绑定外部路径）/ `'real'`（应用沙盒）
- ✅ 导入时**不拷贝文件**，仅存储原路径（与虚拟集设计一致）
- ✅ `VideoFolder` 使用 `folderType` 字段区分类型（`FolderContentType` 枚举：video/article/music）
- ⚠️ WiFi 真实传输功能待后续实现

---

## 2. 技术栈（以 `pubspec.yaml` 为准）

| 领域 | 选用 |
|------|------|
| 框架 | Flutter 3.x（SDK `^3.13.0`） |
| 状态管理 | `flutter_riverpod`（`StateNotifierProvider` + `ConsumerWidget`） |
| 数据库 | `sqflite` + FTS5 全文检索，库名 `vidlang.db`，实体注册式建表 |
| UI 组件库 | `tdesign_flutter`（TDesign Flutter 组件库） |
| 视频播放 | `omni_player`（自研，iOS AVPlayer + Android ExoPlayer） |
| 音频播放 | `just_audio`、`flutter_pcm_player` |
| TTS/语音 | `flutter_tts`、DashScope TTS、本地 ONNX TTS |
| AI 服务 | DeepSeek API（通过 Supabase Edge Function `ai-proxy`） + 本地模型 |
| 缩略图 | `flutter_video_thumbnail_plus` |
| 选文件 | `file_picker` |
| 布局适配 | `flutter_screenutil`（设计稿 375×812） + 自定义 Adaptive 工具 |
| 音频处理 | ONNX Runtime（语音识别、音乐评分） |
| 后端服务 | Supabase (Auth + Database + Storage + Edge Functions + Realtime) |
| 付费 | 自建计费体系（Top-up 预付费钱包模式） |

**文档过时注意**：`docs/README.md` 仍写 Better Player / `video_thumbnail`，实际依赖已换，以上表为准。

---

## 3. 代码结构（实际 `lib/`，截至 2026-07-13）

```
lib/
├── main.dart                      # 应用入口：注册 20+ DB 实体、ScreenUtil、主题、路由
├── splash_screen.dart             # 启动屏
│
├── models/                        # 数据模型层（全部继承 BaseEntity）
│   ├── base_entity.dart           # 实体基类（软删除、审计字段、CRUD）
│   ├── video_folder.dart          # 视频集/文件夹（含片头片尾跳过、封面时间点）
│   ├── video_info.dart            # 视频信息（含 filePath、DurationHelper）
│   ├── subtitles.dart             # 字幕行（FTS5 全文检索）
│   ├── participle.dart            # 分词（FTS5 全文检索）
│   ├── study_record.dart          # 学习记录 ✅ 已注册
│   ├── user.dart                  # 用户模型
│   ├── config.dart                # 系统配置 KV 模型
│   ├── article*.dart              # 文章相关（Article, ArticleChapter, ArticleParagraph, ArticleSentence, ArticleBookmark）
│   ├── word_book*.dart            # 单词本（WordBook, WordBookTag, WordTag）
│   ├── recording_record.dart      # 跟读录音记录
│   ├── test_models.dart           # 测试相关模型
│   ├── ai_evaluation_log.dart     # AI 评估日志
│   ├── error_log.dart             # 错误日志
│   └── device_type.dart           # 设备类型
│
├── providers/                     # 状态管理层（Riverpod）
│   ├── player_engine_provider.dart # 播放器状态（⭐ 核心，1200+ 行）
│   ├── file_provider.dart         # 文件夹/视频 CRUD
│   ├── navigation_provider.dart   # 导航状态
│   ├── user_provider.dart         # 用户状态
│   ├── subscription_provider.dart # 订阅状态
│   └── theme_provider.dart        # 主题状态
│
├── services/                      # 服务层（50+ 文件）
│   ├── database_service.dart      # 数据库服务（注册实体、FTS5）
│   ├── auth_service.dart          # 认证服务（Supabase Auth）
│   ├── ai_service.dart            # AI 查询服务（DeepSeek）
│   ├── local_ai_service.dart      # 本地 AI 服务
│   ├── tts_service.dart           # TTS 统一入口
│   │   ├── dashscope_tts_service.dart    # 阿里云 TTS
│   │   ├── local_tts_service.dart        # 本地 ONNX TTS
│   │   └── unified_tts_service.dart      # TTS 统一封装
│   ├── translation_service.dart   # 翻译服务
│   │   ├── huggingface_translation_service.dart
│   │   ├── translation_init_service.dart
│   │   └── unified_translation_service.dart
│   ├── evaluation_service.dart    # 评分服务（发音/音乐）
│   │   ├── shengtong_evaluator.dart      # 声通评分
│   │   ├── shengtong_http_evaluator.dart
│   │   └── score_service.dart
│   ├── speech_to_text_service.dart # STT 服务
│   │   ├── local_stt_service.dart
│   │   └── unified_stt_service.dart
│   ├── word_book_service.dart     # 单词本服务
│   ├── learning_stats_service.dart # 学习统计服务
│   ├── settings_service.dart      # 设置持久化
│   ├── stats_service.dart         # 统计数据
│   ├── billing_service.dart       # 计费/充值
│   ├── conversation_service.dart  # AI 对话
│   ├── forum/forum_service.dart   # 论坛社区
│   ├── thumbnail_service.dart     # 缩略图生成
│   ├── file_picker_service.dart   # 文件导入/扫描
│   ├── file_manager_service.dart  # 物理文件管理
│   ├── wifi_transfer_service.dart # WiFi 传输（待完善）
│   └── ...                        # 其他辅助服务
│
├── views/                         # 页面层（15+ 子模块）
│   ├── main/main_page.dart        # 主页面（底部导航栏）
│   ├── home/home_page.dart        # 首页（Learn Tab）
│   ├── files/
│   │   ├── file_list_page.dart     # 视频集列表
│   │   └── folder_detail_page.dart # 视频集详情
│   ├── player/player_page.dart    # ✅ 视频播放器（1632 行，功能完整）
│   ├── article/                   # 文章阅读模块
│   ├── audio_player/              # 音频播放模块
│   ├── conversation/              # AI 对话模块
│   ├── forum/                     # 论坛模块
│   │   ├── forum_home_page.dart
│   │   └── forum_create_post_page.dart
│   ├── growth/                    # 成长统计
│   │   └── learning_history_page.dart
│   ├── profile/                   # 个人中心
│   │   └── edit_profile_page.dart
│   ├── settings/                  # 设置页
│   ├── login/index.dart           # 登录页
│   ├── test/                      # 测试页
│   ├── word_book/                 # 单词本
│   │   └── collection_page.dart
│   └── shadow_reader/             # 跟读组件
│
├── components/                   # 公共 UI 组件
│   └── ui/                        # TDesign 封装组件
│
├── widgets/                      # 业务组件
│   ├── common/                    # 通用业务组件
│   ├── article/                   # 文章相关组件
│   └── shadow_reader/             # 跟读评分组件
│
├── theme/                        # 主题系统（9 个文件）
│   ├── theme.dart                 # Theme 入口
│   ├── app_colors.dart            # 颜色定义
│   ├── app_typography.dart        # 字体定义
│   ├── app_spacing.dart           # 间距
│   ├── app_radius.dart            # 圆角
│   ├── app_shadows.dart           # 阴影
│   ├── app_icons.dart             # 图标（Material rounded）
│   ├── design_tokens.dart         # 设计令牌
│   └── app_theme.dart             # AppTheme 定义
│
└── utils/                        # 工具类
    ├── adaptive.dart             # 屏幕适配工具
    ├── device_config.dart        # 设备配置
    └── device_utils.dart         # 设备工具
```

---

## 4. 数据库实体（`main.dart` 已注册，20+ 个表）

### 核心业务表

| tableName | FTS | 说明 |
|-----------|-----|------|
| `video_folder` | 否 | 视频/文章/歌曲集；含 `folder_type`、`skip_opening/ending`、`parent_code` |
| `video_info` | 否 | 媒体文件元数据；含 `file_path`、`file_type`(virtual/real)、时长/进度均为**毫秒** |
| `subtitles` | ✅ FTS5 | 字幕/歌词/句子行；按 `video_code` 关联 |
| `participle` | ✅ FTS5 | 分词数据，供全文检索 |
| `study_record` | 否 | ✅ 已注册；学习记录（duration 为**秒**） |
| `word_book` | 否 | 单词本（跨来源收藏） |
| `word_book_tag` | 否 | 单词本标签 |
| `word_tag` | 否 | 标签关联 |
| `recording_record` | 否 | 跟读录音记录 |

### 文章系统表

| tableName | 说明 |
|-----------|------|
| `article` | 文章主体 |
| `article_chapter` | 文章章节 |
| `article_paragraph` | 文章段落 |
| `article_sentence` | 文章句子（可交互单元） |
| `article Bookmark` | 文章书签 |

### 系统/用户表

| tableName | 说明 |
|-----------|------|
| `user` | 用户信息 |
| `config` | 系统配置 KV（category/key/value/value_type） |
| `error_log` | 错误日志 |
| `ai_evaluation_log` | AI 评估日志 |
| `test_models` | 测试相关数据 |

---

## 5. 当前实现进度

### 产品方确认的首页 / 详情行为

**首页（视频集列表，类似播放器库）：**
- 列表项 = 视频集；**第一项 = 最近播放的视频集**（按 `last_play_date` 等排序）
- 每项：封面、总集数、已播完集数、**整体播放进度**
- 封面规则：默认 = 第一集封面；该集有播放后 = **最后一次播放视频的截图**（`currentCover` / 播放截图逻辑）
- 搜索：**仅按视频集名称**过滤（视频集多时）
- WiFi 入口在首页菜单（后续开发）

**详情页：**
- 顶部：**最后一次播放**的那一集（大卡）
- 下方：同集内其他视频——状态（未播放 / 播放中 / 正在播放 / 已播完）、进度、**字幕状态**、名称
- 视频集级：**综合评测**（后做）；单视频：**单元测试**（后做，有字幕才可测）

### 已完成 / 可用（截至 2026-07-13）

**核心功能模块**：
- ✅ **视频播放器** (`player_page.dart` + `player_engine_provider.dart`)：完整实现，2800+ 行
  - 播放/暂停/停止、Seek（含同步优化）、倍速 (0.5x-2.0x)
  - 字幕显示与选择、AI 翻译集成
  - 单句暂停、由慢到快模式、跟读评分（ShadowReaderComponent）
  - AB 循环、定时关闭（时间/集数）、循环模式（单集/列表/顺序）
  - 字幕查词（WordCard）、单词本收藏
  - 视频列表抽屉、iPad 横屏适配（70/30 分栏）
  - 学习记录自动保存（LearningStatsService）
- ✅ **文章阅读器**：文章导入、分句、TTS 朗读、跟读
- ✅ **歌曲播放器**：音频播放、歌词显示、LRC 解析、ID3 解析
- ✅ **AI 服务**：DeepSeek 查词/翻译/对话（云端+本地双模式）
- ✅ **TTS 系统**：阿里云 TTS + 本地 ONNX TTS 统一封装
- ✅ **评分系统**：声通发音评分 + 音乐评分（ONNX）
- ✅ **单词本系统**：跨来源收藏、标签管理、间隔复习
- ✅ **测试系统**：填空/听写/选择题生成
- ✅ **用户系统**：Supabase Auth 登录/注册
- ✅ **计费系统**：Top-up 预付费钱包模式
- ✅ **论坛社区**：发帖/评论/关注
- ✅ **文件管理**：虚拟集导入、扫描、缩略图
- ✅ **主题系统**：亮色/暗色双主题（TDesign 组件库）
- ✅ **设置持久化**：播放偏好、UI 偏好等

### 未实现 / 占位 / 待完善

| 模块 | 状态 |
|------|------|
| WiFi 真实视频集传输 | ⏳ 后续开发 |
| 画中画 (PiP) | ⏳ 待实现 |
| 投屏 (Cast/AirPlay) | ⏳ 待实现 |
| 弹幕支持 | ⏳ 待实现 |
| 国际化（i18n） | ⏳ 待实现 |
| App Store / Google Play 上架 | ⏳ 阶段 D |
| 多级文件夹 UI 展示 | ⏳ 当前仅扁平列表 |

### 开发进度（当前阶段：Phase 1-3 混合）

根据 `overall-architecture.md` 的路线图：

**✅ Phase 1 已完成**：视频闭环
- ✅ 录音功能 → 跟读评分循环
- ✅ 字幕查词集成 → WordCard
- ✅ 基础测试 → 填空/选择
- ✅ 学习记录写入
- ✅ UI 英文化

**✅ Phase 2 大部分完成**：文章阅读
- ✅ Article + ArticleSentence 模型
- ✅ 粘贴/OCR 导入
- ✅ 分句 + 时间轴
- ✅ TTS 朗读 + 跟读
- ✅ 复用测试引擎

**✅ Phase 3 大部分完成**：歌曲学习
- ✅ Song + LyricLine 模型
- ✅ 歌词导入 + LRC 解析
- ✅ 音频播放 + 歌词高亮
- ✅ ID3 解析
- ✅ 声通音乐评分集成

**🔄 Phase 4 进行中**：Supabase + 上架
- ✅ 用户系统 + 云端同步（基础）
- ✅ 付费系统（自建计费体系）
- ⏳ App Store / Google Play 上架准备

---

## 6. 已知缺口与待改进项（2026-07-13 更新）

### ✅ 已修复的历史问题
- ~~**`app_colors.dart` ↔ `app_theme.dart` 断裂**~~ → 主题系统已正常工作
- ~~**`VideoInfo` 无媒体路径字段**~~ → `filePath` 字段已存在并正常使用
- ~~**`StudyRecord` 未在 `main.dart` 注册**~~ → 已注册，表自动创建
- ~~**视频播放页未实现**~~ → 完整播放器已实现（2800+ 行代码）

### ⏳ 当前待改进项（优先级排序）
1. **多级文件夹 UI**：`parent_code` 字段已存在，但首页仍显示扁平列表，未实现层级展示
2. **WiFi 真实传输**：`wifi_transfer_service.dart` 已创建，但功能待完善
3. **国际化 (i18n)**：当前硬编码中英文混合，需提取字符串资源
4. **高级播放功能**：画中画、投屏、弹幕等待实现
5. **性能优化**：大文件夹加载速度、字幕搜索性能等

---

## 7. 关键业务流程（简图）

### 启动

`main()` → `DatabaseService.registerEntities(...)` → `ProviderScope` → `VidLangApp` → `MainPage` → 默认 `FileListPage`。

### 打开文件夹

`FileListPage` tap → `FolderDetailPage(folderCode)` → `loadVideos` → 取 `isCurrentPlaying` 或列表首项为 `currentVideo`。

### 导入视频（详情或列表）

`FilePickerService` → DB insert `VideoInfo`（及字幕）→ `fileProvider.loadVideos` / `loadFolders`。

### 切换当前集（详情九宫格）

`setCurrentVideo` / `selectVideo` → 批量更新 `is_current_playing` → 更新文件夹 `last_video_code` 等。

---

## 8. 页面与路由（现状，2026-07-13 更新）

无统一命名路由表；主要为 `Navigator.push`：

**已实现的页面导航**：
- `MainPage` (底部导航) → `FileListPage` | `HomePage` | `ProfilePage`
- `FileListPage` → `FolderDetailPage`
- ✅ **`FolderDetailPage` / `FileListPage` → `PlayerPage`** （视频播放器）
- ✅ **文章相关页面** → `ArticleReaderPage`
- ✅ **音频/歌曲相关页面** → `AudioPlayerPage`
- ✅ **登录页** → `LoginPage`（Supabase Auth）
- ✅ **设置页** → `SettingsPage`
- ✅ **单词本** → `WordBookCollectionPage`
- ✅ **论坛** → `ForumHomePage` | `ForumCreatePostPage`
- ✅ **成长统计** → `LearningHistoryPage`
- ✅ **个人资料编辑** → `EditProfilePage`

**核心 Provider**：
- `playerEngineProvider` — 播放器状态管理（⭐ 最复杂）
- `fileProvider` — 文件夹/视频 CRUD
- `subscriptionProvider` — 订阅模式（免费/Premium）
- `themeProvider` — 主题切换

---

## 9. 文件管理 UI 要点（实现对照 `pages/files.md`）

- **首页**：3 列文件夹卡片；角标 `completedCount/videoCount`；末尾「新建」卡片；`+` 菜单：导入文件、WiFi（未做）
- **详情**：顶部大卡（封面、播放钮、进度条、字幕图标、名称）；下方 4 列九宫格；点击格子切换当前集
- **字幕**：有字幕才可「测试」；无字幕菜单无测试项
- **播放四种态**：○ 未播放 / ◐ 部分 / ▶ 当前 / ✓ 完成 — 需在组件层用 `VideoInfo` 字段计算

---

## 10. 后续路线图（产品方确认）

**阶段 A（当前）**：修编译/主题；首页与详情显示对齐 §5；`filePath` + 虚拟集类型；真搜索；图标统一；不启动播放页。

**阶段 B**：WiFi 真实视频集（存储策略可选：应用私有 vs 用户可见目录）。

**阶段 C**：播放前设计——截图路径、字幕表、分词表、手动字幕选择、为滑词/单句暂停/变速预留字段。

**阶段 D**：播放器 + 学习记录 + 单集测试 + 综合评测。

---

## 11. 配置体系：全局 vs 视频集 vs 多级文件夹

### 11.1 已有数据能力

| 层级 | 存储 | 字段（播放相关） |
|------|------|------------------|
| **全局默认** | `config` 表，`category` + `key` + `value` + `value_type` | 待约定键名（见下） |
| **视频集/文件夹** | `video_folder` 表 | `skip_opening`, `skip_opening_duration`, `skip_ending`, `skip_ending_duration`, `thumbnail_time` |
| **层级** | `video_folder.parent_code` | 已建字段；**UI/查询未实现**（当前 `loadFolders` 拉全表扁平列表） |

`Config` 是通用 KV（`category`/`key`/`value`/`ValueType`），适合分类存：系统、外观、播放、网络等。  
目前代码里 `config` **仅用于** `DatabaseService` 的 `current_user_code` / `current_token`（`category = system`），**尚无**播放类全局配置的读写封装。

### 11.2 建议的全局键（`category: playback`）

| key | type | 含义 |
|-----|------|------|
| `skip_opening_enabled` | boolean | 默认是否跳过片头 |
| `skip_opening_seconds` | number | 默认片头秒数 |
| `skip_ending_enabled` | boolean | 默认是否跳过片尾 |
| `skip_ending_seconds` | number | 默认片尾秒数 |
| `thumbnail_time_seconds` | number | 默认封面截图时间点（秒） |

新建视频集时：**从全局拷贝**到 `VideoFolder` 各字段（用户再在集级修改）。  
导入时生成缩略图用该集的 `thumbnail_time`（无则回落全局）。

### 11.3 解析优先级（播放 / 完成判定 / 统计时用）

建议单一入口 `resolvePlaybackSettings(folder)`：

```
有效设置 = 当前视频集字段（已显式保存）
         → 若需支持多级：沿 parent_code 向上找祖先（可选：子覆盖父）
         → 全局 config 默认值
```

**与「播完」的关系**（播放阶段实现，逻辑要先定）：

- 有效时长 ≈ `duration - skipOpeningDuration - skipEndingDuration`（启用时）
- **播完**：`currentPosition` 达到有效终点（不是物理片尾）
- **完整播放次数**：一次会话内有效区间从头到尾算 1 次（跳过片头片尾后的区间）

### 11.4 UI 入口（阶段 A 可只做壳，阶段 D 接播放）

| 位置 | 操作 |
|------|------|
| **我的 / 设置** | 「播放与封面」→ 全局开关 + 秒数步进器 + 封面时间点 |
| **视频集详情 ··· 菜单** | 「播放设置」→ 同三项；保存写 `VideoFolder` |
| **视频集卡片长按**（可选） | 快捷进入播放设置 |
| **多级文件夹** | 首页只显示 `parent_code == null`；进入有子级的集 → 子文件夹列表 + 面包屑；**叶子集**才进现有「大卡+视频列表」详情 |

图标：统一 `AppIcons`（如 `settings`、`skipNext` 等 rounded 线性），与汽水/Lemon 一致。

### 11.5 已确认（2026-05-20）

1. **视频仅挂在叶子视频集**（二级结构：分组 `parent_code` 空 + 叶子 `parent_code` 非空）。  
2. **暂不做 3 级以上**；以后有需求再扩展。  
3. **首页只列叶子视频集**，按 `last_play_date` 倒序（未播放排后）。  
4. 播放设置：全局 `Config` + 视频集 `VideoFolder` 字段；新建集从全局拷贝。  
5. `SettingsService.ensureDefaultGroupCode()` 提供默认分组「未分组」。

---

## 12. 相关文档索引

| 文件 | 内容 |
|------|------|
| `README.md` | 模型字段、DB 规范、路线图（部分技术栈过时） |
| `DEVELOPMENT.md` | 注释/命名/Git 规范 |
| `design-style-guide.md` | 视觉与交互规范 |
| `pages/files.md` | 文件管理页交互与状态（最细） |
| `pages/files-v2.pen` | 设计稿（Pencil） |

---

## 12. 给 Agent 的工作约定

- 改 UI 前先对 `theme/` 与 `design-style-guide.md`
- 改数据先对 `BaseEntity` / `DatabaseService` / 是否需在 `main.dart` 注册新表
- 时长单位：**视频 duration/position = 毫秒**；`StudyRecord.duration` = **秒**
- 保持 Riverpod：`fileProvider` 为文件域单一事实来源
- 小步提交；用户未要求不 git commit
