# VidLang - Flutter 代码结构详解

> **版本**: V2.0 | **日期**: 2026-07-13
> **状态**: 当前有效
> **适用读者**: Flutter 开发者、AI 辅助工具

---

## 一、项目入口与启动流程

### 1.1 应用入口：`lib/main.dart`

`main.dart` 是 Flutter 应用的入口文件，负责：

1. **全局初始化** - WidgetsFlutterBinding、屏幕方向、Logger、ErrorHandler
2. **优先渲染** - 先 `runApp` 显示 Splash Screen，避免白屏
3. **后台异步初始化** - Supabase、数据库实体注册、本地 AI 服务
4. **配置 ScreenUtil** - 屏幕适配（设计稿 375×812，支持 iPad）
5. **设置主题** - 亮色/暗色双主题（TDesign 组件库）
6. **启动应用** - `ProviderScope` → `VidLangApp` → `SplashScreen` → `MainPage`

**启动流程图：**

```
main()
    ↓
WidgetsFlutterBinding.ensureInitialized()
    ↓
检测设备类型（iPad / iPhone）→ 设置屏幕方向
    ↓
VscodeLogger.init() + GlobalErrorHandler.install()
    ↓
runApp(                                    // ⭐ 先渲染，避免白屏
    ProviderScope(
        └── VidLangApp                     // MaterialApp + TDesign
            └── SplashScreen               // 启动屏
                └── MainPage               // 主页面（底部导航栏，5个Tab）
                    ├── LearnTab (首页)     // home_page.dart
                    ├── VideoTab (视频)     // file_list_page.dart
                    ├── ArticleTab (文章)   // article_list_page.dart
                    ├── WordBookTab (单词本)// collection_page.dart
                    └── ProfileTab (我的)   // profile_page.dart
    )
    ↓ （后台异步）
_initializeAsyncDependencies()
    ├── Supabase.initialize()              // 云端服务
    ├── DatabaseService.registerEntities([...])  // 注册 20 个实体
    ├── DatabaseService.database           // 触发 SQLite 建表
    ├── DeviceUtils.initialize()           // 设备信息
    └── LocalAiService.instance.initialize()     // 本地 AI（TTS/STT/翻译）
```

### 1.2 已注册的数据库实体（截至 V2.0）

```dart
// lib/main.dart 中的注册列表（共 20 个实体）
DatabaseService.registerEntities({
  'video_folder': EntityConfig(creator: () => VideoFolder()),
  'video_info': EntityConfig(creator: () => VideoInfo()),
  'subtitles': EntityConfig(creator: () => Subtitles(), enableFullTextSearch: true),
  'participle': EntityConfig(creator: () => Participle(), enableFullTextSearch: true),
  'config': EntityConfig(creator: () => Config()),
  'study_record': EntityConfig(creator: () => StudyRecord()),       // ✅ 已注册
  'user': EntityConfig(creator: () => User()),
  'error_log': EntityConfig(creator: () => ErrorLog()),
  'article': EntityConfig(creator: () => Article()),
  'article_chapter': EntityConfig(creator: () => ArticleChapter()),  // 旧版迁移中
  'article_paragraph': EntityConfig(creator: () => ArticleParagraph()),
  'article_sentence': EntityConfig(creator: () => ArticleSentence(), enableFullTextSearch: true),
  'article_bookmark': EntityConfig(creator: () => ArticleBookmark()),
  'word_book': EntityConfig(creator: () => WordBook()),
  'word_tag': EntityConfig(creator: () => WordTag()),
  'word_book_tag': EntityConfig(creator: () => WordBookTag()),
  'recording_record': EntityConfig(creator: () => RecordingRecord()),
  'test_session': EntityConfig(creator: () => TestSession()),
  'test_item': EntityConfig(creator: () => TestItem()),
  'test_evaluation': EntityConfig(creator: () => TestEvaluation()),
  'ai_evaluation_log': EntityConfig(creator: () => AiEvaluationLog()),
});
```

**FTS5 全文检索表（4个）：** `subtitles`, `participle`, `article_sentence`

---

## 二、目录结构详解

### 2.1 完整目录树（lib/）

```
lib/
├── main.dart                          # 应用入口（~400行）
├── splash_screen.dart                 # 启动屏
│
├── models/                            # 数据模型层（36个文件）
│   ├── base_entity.dart               # 实体基类（⭐ 核心）
│   │
│   ├── # ── 视频引擎 ───────────────────────────────────
│   ├── video_folder.dart              # 视频集/文件夹
│   ├── video_info.dart                # 视频信息 + DurationHelper
│   ├── subtitles.dart                 # 字幕行（FTS5）
│   ├── participle.dart                # 分词（FTS5）
│   ├── playback_settings.dart         # 播放设置
│   │
│   ├── # ── 文章引擎 ───────────────────────────────────
│   ├── article.dart                   # 文章
│   ├── article_chapter.dart           # 文章章节（旧版迁移中）
│   ├── article_paragraph.dart         # 文章段落
│   ├── article_sentence.dart          # 文章句子（FTS5）
│   ├── article_bookmark.dart          # 文章书签
│   ├── article_translation.dart       # 文章翻译
│   │
│   ├── # ── 学习系统 ───────────────────────────────────
│   ├── study_record.dart              # 学习记录 ✅已注册
│   ├── recording_record.dart          # 跟读录音记录
│   ├── word_book.dart                 # 单词本
│   ├── word_book_tag.dart             # 单词-标签关联
│   ├── word_book_query_models.dart    # 单词本查询模型
│   ├── word_tag.dart                  # 单词标签
│   ├── word_card_data.dart            # 单词卡片数据
│   ├── word_detail.dart               # 单词详情
│   ├── test_models.dart               # 测试模型（session/item/evaluation）
│   ├── ai_evaluation_log.dart         # AI学习评价日志
│   │
│   ├── # ── 用户系统 ───────────────────────────────────
│   ├── user.dart                      # 用户模型
│   ├── config.dart                    # 系统配置（KV模型）
│   ├── error_log.dart                 # 错误日志
│   ├── device_type.dart               # 设备类型
│   │
│   ├── # ── 对话/AI ────────────────────────────────────
│   ├── conversation_message.dart      # 对话消息
│   ├── conversation_record.dart       # 对话记录
│   │
│   ├── # ── 评测/计费 ──────────────────────────────────
│   ├── evaluation_models.dart         # 评测模型
│   ├── shengtong_evaluation_result.dart # 声通评测结果
│   ├── shengtong_result.dart          # 声通结果
│   ├── billing_summary.dart           # 计费汇总
│   ├── pricing_rule.dart              # 价格规则
│   ├── topup_config.dart              # 充值配置
│   ├── learning_resource.dart         # 学习资源
│   │
│   └── forum/                         # 论坛模型（2个文件）
│
├── providers/                          # 状态管理层（17个文件）
│   ├── file_provider.dart              # 文件域状态（⭐ 核心 Provider）
│   ├── player_engine_provider.dart     # 播放器引擎状态
│   ├── navigation_provider.dart        # 导航状态
│   ├── user_provider.dart              # 用户状态
│   ├── theme_provider.dart             # 主题状态
│   ├── conversation_provider.dart      # 对话状态
│   ├── test_provider.dart              # 测试状态
│   ├── growth_provider.dart            # 成长状态
│   ├── subscription_provider.dart      # 订阅/会员状态
│   ├── difficulty_provider.dart        # 难度设置
│   ├── display_config_provider.dart    # 显示配置
│   ├── device_type_provider.dart       # 设备类型
│   ├── forum_providers.dart            # 论坛状态
│   ├── forum_admin_providers.dart      # 论坛管理状态
│   └── forum_mock_provider.dart        # 论坛Mock数据
│
├── services/                           # 服务层（60+个文件）
│   │
│   ├── # ── 核心服务 ───────────────────────────────────
│   ├── database_service.dart           # 数据库服务（⭐ 核心）
│   ├── file_picker_service.dart        # 文件导入/扫描
│   ├── thumbnail_service.dart          # 缩略图生成
│   ├── file_manager_service.dart       # 物理文件管理
│   ├── folder_stats_service.dart       # 文件夹统计
│   │
│   ├── # ── AI 服务 ─────────────────────────────────────
│   ├── ai_service.dart                 # AI 查询（DeepSeek/Qwen）
│   ├── local_ai_service.dart           # 本地AI服务统一入口
│   ├── local_tts_service.dart          # 本地TTS
│   ├── local_stt_service.dart          # 本地STT
│   ├── local_model_service.dart        # 本地模型管理
│   ├── dictionary_service.dart         # 查词服务
│   ├── translation_service.dart       # 翻译服务
│   ├── unified_translation_service.dart # 统一翻译服务
│   ├── huggingface_translation_service.dart # HuggingFace翻译
│   ├── speech_to_text_service.dart     # 语音转文字
│   ├── audio_recognition_service.dart  # 音频识别
│   ├── unified_stt_service.dart        # 统一STT服务
│   ├── qwen_realtime_service.dart      # Qwen实时语音
│   │
│   ├── # ── TTS 服务 ───────────────────────────────────
│   ├── tts_service.dart                # TTS入口
│   ├── dashscope_tts_service.dart      # 阿里云TTS
│   ├── unified_tts_service.dart        # 统一TTS服务
│   │
│   ├── # ── 评测服务 ───────────────────────────────────
│   ├── evaluation_service.dart         # 评测服务
│   ├── evaluation_api.dart             # 评测API
│   ├── evaluation_storage_service.dart # 评测存储
│   ├── ai_evaluation_service.dart      # AI评测
│   ├── score_service.dart              # 评分服务
│   ├── shengtong_evaluator.dart        # 声通评测器
│   ├── shengtong_evaluator_manual.dart # 声通手动评测
│   ├── shengtong_http_evaluator.dart   # 声通HTTP评测
│   │
│   ├── # ── 用户/认证/计费 ──────────────────────────────
│   ├── auth_service.dart               # 认证（Supabase Auth）
│   ├── billing_service.dart            # 计费服务
│   ├── topup_service.dart              # 充值服务
│   ├── settings_service.dart           # 设置服务
│   │
│   ├── # ── 数据统计 ───────────────────────────────────
│   ├── stats_service.dart              # 统计服务
│   ├── learning_stats_service.dart     # 学习统计
│   │
│   ├── # ── 解析服务 ───────────────────────────────────
│   ├── article_parser.dart             # 文章解析
│   ├── lrc_parser.dart                 # LRC歌词解析
│   ├── id3_parser.dart                 # ID3音频标签解析
│   │
│   ├── # ── 其他服务 ───────────────────────────────────
│   ├── conversation_service.dart       # 对话服务
│   ├── word_book_service.dart          # 单词本服务
│   ├── word_tag_service.dart           # 单词标签服务
│   ├── app_keys_service.dart           # API密钥服务
│   ├── global_error_handler.dart       # 全局错误处理
│   ├── native_service.dart             # 原生通道服务
│   ├── ios_native_features.dart        # iOS原生功能
│   ├── model_path_service.dart         # 模型路径服务
│   ├── initial_letter_cover.dart       # 首字母封面生成
│   ├── wifi_transfer_service.dart      # WiFi传输服务
│   ├── translation_init_service.dart   # 翻译初始化
│   └── forum/                          # 论坛服务
│
├── views/                              # 页面层（55+个文件）
│   │
│   ├── main/
│   │   └── main_page.dart              # 主页面（底部导航栏，5 Tab）
│   │
│   ├── login/
│   │   └── index.dart                  # 登录页
│   │
│   ├── home/
│   │   ├── home_page.dart              # 首页（Learn Tab）
│   │   └── home_page_backup.dart       # 首页备份
│   │
│   ├── files/
│   │   ├── file_list_page.dart         # 视频集列表页
│   │   ├── folder_detail_page.dart     # 视频集详情页
│   │   └── wifi_transfer_page.dart     # WiFi传输页
│   │
│   ├── player/
│   │   └── player_page.dart            # 视频播放器页 ⭐核心页面
│   │
│   ├── article/
│   │   ├── article_list_page.dart      # 文章列表页
│   │   ├── article_reader_page.dart    # 文章阅读器页
│   │   ├── article_reader_page_new.dart # 文章阅读器新版
│   │   └── article_import_page.dart    # 文章导入页
│   │
│   ├── audio_player/
│   │   ├── audio_player_page.dart      # 音频播放器页（歌曲/跟读）
│   │   ├── learning_record_page.dart   # 学习记录页
│   │   ├── subtitle_list_widget.dart  # 字幕列表组件
│   │   ├── lyric_display_widget.dart  # 歌词显示组件
│   │   ├── ai_evaluation_sheet.dart   # AI评测浮层
│   │   └── recognition_prompt_dialog.dart # 识别提示弹窗
│   │
│   ├── conversation/
│   │   ├── conversation_page.dart      # AI对话页
│   │   └── conversation_history_page.dart # 对话历史页
│   │
│   ├── word_book/
│   │   ├── collection_page.dart        # 单词本（收藏本）
│   │   ├── word_book_review_page.dart  # 单词复习页
│   │   ├── word_book_detail_sheet.dart # 单词详情浮层
│   │   ├── word_book_lookup_sheet.dart # 单词查词浮层
│   │   ├── camera_translate_page.dart # 拍照翻译页
│   │   └── widgets/                    # 单词本子组件（4个文件）
│   │
│   ├── profile/
│   │   ├── profile_page.dart           # 个人中心
│   │   ├── edit_profile_page.dart      # 编辑资料页
│   │   ├── topup_page.dart             # 充值页
│   │   ├── topup_history_page.dart     # 充值历史页
│   │   ├── billing_page.dart           # 账单页
│   │   ├── billing_rules_page.dart     # 计费规则页
│   │   ├── user_settings_page.dart     # 用户设置页
│   │   └── learning_stats_page.dart    # 学习统计页
│   │
│   ├── forum/
│   │   ├── forum_home_page.dart        # 论坛首页
│   │   ├── forum_create_post_page.dart # 发帖页
│   │   └── admin/
│   │       └── forum_admin_page.dart   # 论坛管理页
│   │
│   ├── growth/
│   │   ├── learning_history_page.dart  # 学习历史页
│   │   ├── growth_detail_page.dart     # 成长详情页
│   │   └── growth_record_page.dart     # 成长记录页
│   │
│   ├── settings/
│   │   └── model_settings_page.dart    # 模型设置页
│   │
│   └── test/                           # 测试/调试页面（10个文件）
│       ├── test_home_page.dart
│       ├── test_page.dart
│       ├── test_session_page.dart
│       ├── test_result_page.dart
│       ├── test_debug_page.dart
│       ├── db_diagnostic_page.dart
│       ├── network_debug_page.dart
│       ├── shengtong_http_test_page.dart
│       ├── audio_test_page.dart
│       └── evaluation_test_page.dart
│
├── components/                         # 公共 UI 组件（14个文件）
│   │
│   ├── # ── 业务卡片 ───────────────────────────────────
│   ├── folder_card.dart                # 文件夹卡片
│   ├── video_card.dart                 # 视频卡片
│   ├── main_video_card.dart            # 主视频卡片（大卡）
│   ├── article_hero_card.dart          # 文章英雄卡片
│   ├── article_item_card.dart          # 文章条目卡片
│   ├── audio_hero_card.dart            # 音频英雄卡片
│   ├── audio_item_card.dart            # 音频条目卡片
│   ├── import_progress_dialog.dart     # 导入进度弹窗
│   ├── playback_settings_sheet.dart    # 播放设置底部弹窗
│   │
│   └── ui/                             # 基础UI组件（11个文件）
│       ├── filled_card.dart            # 填充卡片
│       ├── outlined_card.dart          # 描边卡片
│       ├── base_card.dart              # 卡片基类
│       ├── primary_button.dart         # 主要按钮
│       ├── secondary_button.dart       # 次要按钮
│       ├── badge.dart                  # 徽标
│       ├── avatar.dart                 # 头像
│       ├── text_input_field.dart       # 输入框
│       ├── empty_state.dart            # 空状态
│       ├── shimmer_card.dart           # 骨架屏卡片
│       └── ui_components.dart          # UI组件汇总导出
│
├── widgets/                            # 业务组件（18个文件）
│   │
│   ├── # ── 通用组件 ───────────────────────────────────
│   ├── app_dialogs.dart                # 通用弹窗
│   ├── app_tdesign_dialogs.dart        # TDesign弹窗
│   ├── recharge_dialog.dart            # 充值弹窗
│   ├── anchored_popup.dart             # 锚点弹出层
│   ├── word_card.dart                  # 单词卡片（查词浮层）
│   ├── word_detail_panel.dart          # 单词详情面板
│   ├── chat_bubble.dart                # 对话气泡
│   ├── evaluation_demo.dart            # 评测演示
│   │
│   ├── # ── 评测组件 ───────────────────────────────────
│   ├── pronunciation_evaluation_modal.dart # 发音评测浮层
│   ├── evaluation_content_widgets.dart     # 评测内容组件
│   │
│   ├── # ── 文章组件 ───────────────────────────────────
│   ├── selectable_paragraph_text.dart  # 可选中文本段落
│   ├── selectable_english_line.dart    # 可选中文本行
│   │
│   ├── # ── 阅读器 ─────────────────────────────────────
│   ├── shadow_reader/
│   │   └── shadow_reader_component.dart # 影子阅读器组件
│   │
│   ├── native_translation_guide_sheet.dart # 原生翻译引导
│   │
│   └── common/                         # 通用UI（2个文件）
│       ├── loading_widget.dart         # 加载组件
│       └── error_widget.dart           # 错误组件
│
├── theme/                              # 主题系统（9个文件）
│   ├── theme.dart                      # 主题汇总导出
│   ├── app_theme.dart                  # AppTheme 定义
│   ├── app_colors.dart                 # 颜色常量（亮色+暗色#2E302A）
│   ├── app_icons.dart                  # 统一图标（Material rounded线性风格）
│   ├── app_typography.dart             # 字体排版
│   ├── app_radius.dart                 # 圆角定义
│   ├── app_spacing.dart                # 间距定义
│   ├── app_shadows.dart                # 阴影定义
│   └── design_tokens.dart              # 设计令牌（统一引用入口）
│
└── utils/                              # 工具类（9个文件）
    ├── device_utils.dart               # 设备工具
    ├── device_config.dart              # 设备配置
    ├── adaptive.dart                   # 适配工具
    ├── english_segmenter.dart          # 英文分词器
    ├── dialog_utils.dart               # 弹窗工具
    ├── play_status.dart                # 播放状态
    ├── pcm_helper.dart                 # PCM音频数据处理
    ├── app_guard.dart                  # 应用守卫
    └── ai_test_tool.dart               # AI测试工具
```

---

## 三、各层职责详解

### 3.1 Models 层（数据模型）

**职责**：
- 定义数据结构（字段、类型、默认值）
- 实现 SQLite 映射（`toMap()` / `fromMap()`）
- 提供数据验证和计算属性
- 继承 `BaseEntity` 获得软删除和审计字段

**关键类：BaseEntity**

```dart
/// 实体基类
///
/// 所有数据库实体必须继承此类，提供以下能力：
/// - 软删除（is_deleted, deleted_at, deleted_by）
/// - 审计字段（created_at, updated_at, created_by, updated_by）
/// - 多用户支持（user_code）
abstract class BaseEntity {
  int? id;                  // 主键（自增）
  String code = '';         // 业务主键（UUID）
  int isDeleted = 0;        // 软删除标记（0/1）
  String? deletedAt;        // 删除时间
  String? deletedBy;        // 删除人
  String createdAt = '';    // 创建时间（ISO8601）
  String updatedAt = '';    // 更新时间
  String createdBy = '';    // 创建人
  String updatedBy = '';    // 更新人
  String userCode = '';     // 用户标识

  /// 表名（子类必须实现）
  String get tableName;

  /// 转 Map（用于插入/更新）
  Map<String, dynamic> toMap();

  /// 从 Map 创建（用于查询结果映射）
  BaseEntity fromMap(Map<String, dynamic> map);

  /// 从 Map 填充审计字段
  void fromBaseEntity(Map<String, dynamic> map) { ... }
}
```

**关键模型示例：VideoInfo**

```dart
class VideoInfo extends BaseEntity {
  String name = '';              // 视频名称
  String folderCode = '';        // 所属视频集 code
  int duration = 0;              // 总时长（毫秒）
  String? cover;                 // 视频封面路径
  String? currentCover;          // 当前播放截图
  int currentPosition = 0;       // 当前播放位置（毫秒）
  bool isCurrentPlaying = false; // 是否正在播放
  bool hasSubtitles = false;     // 是否有字幕
  DateTime? playDate;            // 最后播放时间
  int playCount = 0;             // 总播放次数
  int totalPlayDuration = 0;     // 总学习时长（秒）
  String? filePath;              // 视频文件路径 ✅ 已实现

  @override
  String get tableName => 'video_info';

  // ... toMap() / fromMap() 实现

  /// 时长格式化工具（定义在本文件中）
  static String formatDuration(int milliseconds) { ... }
}
```

### 3.2 Providers 层（状态管理）

**职责**：
- 管理 UI 状态（loading、error、data）
- 封装业务操作方法（CRUD）
- 提供响应式数据流（Riverpod）
- 协调 Service 层调用

**核心 Provider 列表：**

| Provider | 文件 | 职责 |
|----------|------|------|
| `fileProvider` | file_provider.dart | 视频集/视频CRUD、导入、播放状态 |
| `playerEngineProvider` | player_engine_provider.dart | 播放器引擎控制（核心） |
| `navigationProvider` | navigation_provider.dart | 底部导航切换 |
| `userProvider` | user_provider.dart | 用户信息、登录状态 |
| `themeProvider` | theme_provider.dart | 主题切换（亮色/暗色/系统） |
| `conversationProvider` | conversation_provider.dart | AI对话状态 |
| `testProvider` | test_provider.dart | 测试会话状态 |
| `growthProvider` | growth_provider.dart | 成长数据 |
| `subscriptionProvider` | subscription_provider.dart | 会员/订阅 |
| `forumProviders` | forum_providers.dart | 论坛数据 |
| `difficultyProvider` | difficulty_provider.dart | 学习难度 |

**使用方式：**

```dart
// 在 Widget 中监听状态
class FileListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileState = ref.watch(fileProvider);

    if (fileState.isLoading) {
      return const TDLoading();
    }

    return ListView.builder(
      itemCount: fileState.folders.length,
      itemBuilder: (context, index) {
        final folder = fileState.folders[index];
        return FolderCard(folder: folder);
      },
    );
  }
}

// 在 Widget 中调用方法
onPressed: () {
  ref.read(fileProvider.notifier).loadFolders();
}
```

### 3.3 Services 层（业务逻辑）

**职责**：
- 封装复杂业务逻辑
- 协调多个 Model 操作
- 处理异步任务和异常
- 与外部系统交互（文件系统、网络、AI）

**核心 Service：DatabaseService**

```dart
class DatabaseService {
  // 单例模式（通过 static 方法访问）
  static Future<Database> get database async {...}
  static void registerEntities(Map<String, EntityConfig> entities) {...}

  // 初始化和建表
  Future<Database> _initDatabase() async {...}
  Future<void> _createTable(BaseEntity entity) async {...}

  // 通用 CRUD
  Future<int> insert(BaseEntity entity) async {...}
  Future<List<T>> findByCondition<T extends BaseEntity>(...) async {...}
  Future<int> update(BaseEntity entity) async {...}
  Future<int> softDelete(BaseEntity entity) async {...}

  // FTS5 全文检索
  Future<List<T>> searchFTS<T extends BaseEntity>(...) async {...}
}
```

**FilePickerService 示例：**

```dart
class FilePickerService {
  /// 导入本地视频文件夹
  ///
  /// 扫描指定目录下的视频文件，创建 VideoInfo 记录
  /// 支持的字幕格式：.srt, .vtt, .ass, .lrc
  Future<ImportResult> importVideosFromFolder(
    String folderPath, {
    String folderCode = '',
    Function(int current, int total)? onProgress,
  }) async {
    // 1. 扫描目录获取视频文件列表
    final videos = await _scanDirectory(folderPath);

    // 2. 遍历视频文件
    for (var i = 0; i < videos.length; i++) {
      final video = videos[i];

      // 3. 探测视频时长
      final duration = await _detectDuration(video.path);

      // 4. 生成缩略图
      final thumbnail = await _generateThumbnail(video.path);

      // 5. 解析字幕文件（如果有）
      final subtitles = await _parseSubtitles(video.path);

      // 6. 创建 VideoInfo 并入库
      final videoInfo = VideoInfo(
        name: video.name,
        folderCode: folderCode,
        duration: duration,
        cover: thumbnail,
        filePath: video.path,  // ✅ 包含文件路径
        hasSubtitles: subtitles.isNotEmpty,
      )..code = generateCode();

      await _db.insert(videoInfo);

      // 7. 字幕入库（如果有）
      if (subtitles.isNotEmpty) {
        await _saveSubtitles(videoInfo.code, subtitles);
      }

      // 8. 回调进度
      onProgress?.call(i + 1, videos.length);
    }

    return ImportResult(success: true, count: videos.length);
  }
}
```

### 3.4 Views 层（页面）

**职责**：
- 组装 UI 组件（统一使用 TDesign 组件库）
- 响应用户交互
- 监听 Provider 状态
- 处理页面导航

**典型页面结构：**

```dart
/// 视频集详情页
///
/// 显示视频集的详细信息，包括：
/// - 顶部大卡（当前播放视频）
/// - 九宫格视频列表
/// - 播放控制按钮
class FolderDetailPage extends ConsumerStatefulWidget {
  final String folderCode;

  const FolderDetailPage({super.key, required this.folderCode});

  @override
  ConsumerState<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends ConsumerState<FolderDetailPage> {
  @override
  void initState() {
    super.initState();
    // 加载数据
    Future.microtask(() {
      ref.read(fileProvider.notifier).loadVideos(widget.folderCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fileState = ref.watch(fileProvider);

    return Scaffold(
      appBar: AppBar(title: Text('视频集详情')),
      body: Column(
        children: [
          // 顶部大卡
          if (fileState.currentVideo != null)
            MainVideoCard(video: fileState.currentVideo!),

          // 视频列表（九宫格）
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
              itemCount: fileState.videos.length,
              itemBuilder: (context, index) {
                final video = fileState.videos[index];
                return GestureDetector(
                  onTap: () => ref.read(fileProvider.notifier)
                    .setCurrentVideo(video),
                  child: VideoCard(video: video),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### 3.5 Components 层（公共组件）

**职责**：
- 可复用的 UI 组件
- 与业务逻辑解耦
- 支持主题适配（亮色/暗色）
- 提供清晰的 Props 接口
- 统一使用 TDesign 风格

**示例：VideoCard**

```dart
/// 视频卡片组件
///
/// 用于显示单个视频的缩略图、名称、播放状态等
///
/// 使用示例：
/// ```dart
/// VideoCard(
///   video: videoInfo,
///   onTap: () => playVideo(videoInfo),
/// )
/// ```
class VideoCard extends StatelessWidget {
  final VideoInfo video;
  final VoidCallback? onTap;
  final bool isSelected;

  const VideoCard({
    super.key,
    required this.video,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
          border: isSelected
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        ),
        child: Column(
          children: [
            // 缩略图
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                  image: video.cover != null
                    ? DecorationImage(image: FileImage(File(video.cover!)))
                    : null,
                  color: AppColors.gray200,
                ),
                child: Stack(
                  children: [
                    // 时长标签
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        color: Colors.black54,
                        child: Text(
                          VideoInfo.formatDuration(video.duration),
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                    // 播放状态图标
                    if (_buildPlayStatusIcon() != null)
                      Center(child: _buildPlayStatusIcon()),
                  ],
                ),
              ),
            ),
            // 视频名称
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                video.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyXs,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建播放状态图标
  Widget? _buildPlayStatusIcon() {
    if (video.isCurrentPlaying) {
      return Icon(AppIcons.playCircle, color: AppColors.primary, size: 32);
    } else if (_isCompleted()) {
      return Icon(AppIcons.checkCircle, color: AppColors.success, size: 32);
    }
    return null;
  }

  bool _isCompleted() {
    // 播放进度 > 90% 视为完成
    return video.duration > 0 &&
           video.currentPosition > video.duration * 0.9;
  }
}
```

---

## 四、关键设计模式和最佳实践

### 4.1 单例模式（Services）

```dart
// ✅ 推荐：单例 Service（通过 Riverpod Provider 注入）
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

// 或静态访问
final db = DatabaseService.instance;
```

### 4.2 依赖注入（Riverpod）

```dart
// ✅ 推荐：通过 Provider 注入依赖
final myServiceProvider = Provider<MyService>((ref) {
  return MyService(ref.watch(otherServiceProvider));
});

// ❌ 避免：硬编码依赖
class MyPage extends StatelessWidget {
  final MyService _service = MyService(); // 不利于测试和替换
}
```

### 4.3 不可变状态（Immutable State）

```dart
// ✅ 推荐：使用 copyWith 创建新状态
state = state.copyWith(isLoading: true);

// ❌ 避免：直接修改状态
state.isLoading = true; // 编译错误（State 的字段是 final）
```

### 4.4 异步错误处理

```dart
// ✅ 推荐：统一的错误处理模式
Future<void> doSomething() async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    final result = await _service.fetchData();
    state = state.copyWith(data: result, isLoading: false);
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: e.toString(),
    );
    // 可选：显示用户友好的错误提示
    showErrorSnackBar('操作失败，请重试');
  }
}
```

### 4.5 Widget 拆分原则

```
✅ 当 Widget 超过 150 行时，考虑拆分：
   - 将子组件提取到独立文件（components/ 或 widgets/）
   - 使用 Builder 模式或回调简化构建逻辑
   - 使用 Part 文件组织大型 StatefulWidget

✅ 当组件可复用时：
   - 提取到 lib/components/（纯 UI，无业务逻辑）
   - 参数通过构造函数传入
   - 支持主题适配（亮色/暗色）

✅ UI 组件库选择：
   - 优先使用 tdesign_flutter 组件（TDButton, TDCard, TDDialog 等）
   - 基础组件从 lib/components/ui/ 获取（PrimaryButton, FilledCard 等）
   - 禁止直接使用 Material CircularProgressIndicator（用 TDLoading 替代）
```

### 4.6 三引擎架构模式

```
VidLang 采用三引擎架构，共享统一的学习引擎逻辑：

┌─────────────────────────────────────────────────────┐
│                  学习引擎（Learning Engine）            │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ 字幕查词  │  │ 跟读评分  │  │   单句暂停/复读    │   │
│  │ 单词收藏  │  │ AI评测   │  │   由慢到快模式     │   │
│  └──────────┘  └──────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────┘
        ▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────────┐
│  视频引擎     │ │  文章引擎     │ │   歌曲引擎        │
│  OmniPlayer   │ │ ShadowReader │ │  just_audio      │
│  player_page  │ │ article_*    │ │  audio_player_*  │
└──────────────┘ └──────────────┘ └──────────────────┘
```

---

## 五、常见问题排查

### Q1: 应用启动后数据库表未创建？

**检查清单：**
1. `main.dart` 中是否调用了 `DatabaseService.registerEntities({...})`
2. 新模型是否继承了 `BaseEntity`
3. 新模型是否实现了 `tableName` getter
4. 是否调用了 `DatabaseService.database` 触发初始化
5. 实体是否在 `_initializeAsyncDependencies()` 中的 `registerEntities` 里注册

### Q2: Provider 状态不更新？

**可能原因：**
1. 忘记调用 `ref.read(provider.notifier).method()`
2. 方法内未调用 `state = state.copyWith(...)`
3. Widget 未使用 `ref.watch(provider)` 监听
4. StateNotifier 未正确继承或泛型参数错误

### Q3: 文件导入失败？

**排查步骤：**
1. 检查文件权限（iOS 需要配置 Info.plist）
2. 检查文件路径是否正确（使用绝对路径）
3. 检查文件是否存在（`await File(path).exists()`）
4. 检查磁盘空间是否充足

### Q4: 主题颜色不生效？

**检查清单：**
1. 是否使用了 `AppColors.xxx` 而非硬编码颜色值
2. 是否在 `MaterialApp` 中设置了 `theme:` 和 `darkTheme:`
3. 是否使用了 `ref.watch(themeProvider)` 监听主题切换
4. `app_colors.dart` 和 `app_theme.dart` 是否存在循环引用

### Q5: 新增数据库实体后表未创建？

**解决步骤：**
1. 在 `lib/models/` 下创建新模型（继承 `BaseEntity`）
2. 在 `lib/main.dart` 的 `registerEntities` 中添加新实体
3. **卸载重装 App**（开发阶段），或实现数据库迁移
4. 验证：打开 `db_diagnostic_page.dart` 查看已创建的表

---

## 六、代码统计（截至 2026-07-13）

| 目录 | 文件数 | 说明 |
|------|--------|------|
| models/ | 36 | 数据模型（含forum子目录） |
| providers/ | 17 | 状态管理（Riverpod StateNotifier） |
| services/ | 60+ | 业务逻辑（含forum子目录） |
| views/ | 55+ | 页面UI（15个子模块） |
| components/ | 14 | 公共组件（含ui子目录11个） |
| widgets/ | 18 | 业务组件（含common/shadow_reader子目录） |
| theme/ | 9 | 主题系统 |
| utils/ | 9 | 工具类 |
| **lib/ 总计** | **~220+** | （不含 plugs/ 和 test/） |

> **注**：以上仅统计 `lib/` 目录下的源码文件，不含 `plugs/`（第三方插件）、`test/`（测试文件）和 `.dart_tool/`。

---

## 七、版本更新记录

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| V1.0 | 2026-07-12 | 初始版本 |
| V2.0 | 2026-07-13 | **重大更新**：同步20个已注册实体、补全三引擎目录树（views/services/providers）、更新启动流程（Supabase/LocalAiService）、修正VideoInfo.filePath、刷新代码统计（70+→220+文件） |

---

**最后更新**: 2026-07-13
**维护者**: VidLang 开发团队
**相关文档**: [AGENT_CONTEXT.md](../AGENT_CONTEXT.md), [database-design.md](./database-design.md), [services-architecture.md](./services-architecture.md), [overall-architecture.md](./overall-architecture.md)
