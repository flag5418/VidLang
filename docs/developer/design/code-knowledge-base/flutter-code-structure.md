# VidLang - Flutter 代码结构详解

> **版本**: V1.0 | **日期**: 2026-07-12  
> **状态**: 当前有效  
> **适用读者**: Flutter 开发者、AI 辅助工具

---

## 一、项目入口与启动流程

### 1.1 应用入口：`lib/main.dart`

`main.dart` 是 Flutter 应用的入口文件，负责：

1. **注册数据库实体** - 启动时自动建表
2. **配置 ScreenUtil** - 屏幕适配（设计稿 375×812）
3. **设置主题** - 亮色/暗色双主题
4. **配置路由** - 页面导航
5. **启动应用** - `ProviderScope` → `VidLangApp` → `MainPage`

**启动流程图：**

```
main()
    ↓
WidgetsFlutterBinding.ensureInitialized()
    ↓
DatabaseService.instance.registerEntities([...])  // 注册所有实体
    ↓
ScreenUtil.ensureScreenSize()                       // 屏幕适配初始化
    ↓
ProviderScope(                                     // Riverpod 作用域
    └── VidLangApp                                 // MaterialApp
        └── MainPage                               // 主页面（底部导航）
            ├── FileListPage                        // 视频集列表（默认）
            └── ProfilePage                        // 个人中心
```

### 1.2 已注册的数据库实体（截至 V1.0）

```dart
// lib/main.dart 中的注册列表
DatabaseService.instance.registerEntities([
  VideoFolder(),      // video_folder 表
  VideoInfo(),        // video_info 表
  Subtitles(),        // subtitles 表（FTS5）
  Participle(),       // participle 表（FTS5）
  Config(),           // config 表
  User(),             // user 表
  // ⚠️ StudyRecord 未注册（待修复）
]);
```

---

## 二、目录结构详解

### 2.1 完整目录树（lib/）

```
lib/
├── main.dart                      # 应用入口
│
├── models/                        # 数据模型层
│   ├── base_entity.dart           # 实体基类（⭐ 核心）
│   ├── video_folder.dart          # 视频集/文件夹
│   ├── video_info.dart            # 视频信息 + DurationHelper
│   ├── subtitles.dart             # 字幕行（FTS5 全文检索）
│   ├── participle.dart            # 分词（FTS5 全文检索）
│   ├── study_record.dart          # 学习记录（⚠️ 未注册）
│   ├── user.dart                  # 用户模型
│   └── config.dart                # 系统配置（KV 模型）
│
├── providers/                     # 状态管理层（Riverpod）
│   ├── file_provider.dart         # 文件域状态（⭐ 核心 Provider）
│   ├── navigation_provider.dart   # 导航状态
│   └── user_provider.dart         # 用户状态
│
├── services/                      # 服务层（业务逻辑）
│   ├── database_service.dart      # 数据库服务（⭐ 核心）
│   ├── file_picker_service.dart   # 文件导入/扫描
│   ├── thumbnail_service.dart     # 缩略图生成
│   ├── file_manager_service.dart  # 物理文件管理
│   ├── ai_service.dart            # AI 查询（DeepSeek）
│   ├── tts_service.dart           # 文字转语音
│   ├── auth_service.dart          # 认证（Supabase Auth）
│   └── sync_service.dart          # 云端同步
│
├── views/                         # 页面层（UI）
│   ├── main/
│   │   └── main_page.dart         # 主页面（底部导航栏）
│   ├── files/
│   │   ├── file_list_page.dart    # 视频集列表页
│   │   └── folder_detail_page.dart # 视频集详情页
│   ├── home/
│   │   └── home_page.dart         # 首页（Learn Tab，占位）
│   ├── profile/
│   │   └── profile_page.dart      # 个人中心（占位）
│   ├── player/                    # 播放器模块（未来）
│   ├── reader/                    # 阅读器模块（未来）
│   └── test/
│       ├── test_page.dart         # 测试页
│       └── test_session_page.dart # 测试会话页
│
├── components/                    # 公共 UI 组件（可复用）
│   ├── folder_card.dart           # 文件夹卡片组件
│   ├── video_card.dart            # 视频卡片组件
│   ├── main_video_card.dart       # 主视频卡片（大卡）
│   ├── avatar.dart                # 头像组件
│   └── import_progress_dialog.dart # 导入进度弹窗
│
├── widgets/                       # 业务组件（特定场景）
│   └── word_card.dart             # 单词卡片（查词浮层）
│
├── theme/                         # 主题系统
│   ├── app_theme.dart             # AppTheme 定义
│   ├── app_colors.dart            # 颜色常量
│   ├── app_icons.dart             # 统一图标
│   ├── design_tokens.dart         # 设计令牌
│   └── text_styles.dart           # 文字样式
│
├── utils/                         # 工具类
│   └── ...                        # （待补充）
│
└── splash_screen.dart             # 启动屏
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
  String? filePath;              // 视频文件路径（⚠️ 待添加）
  
  @override
  String get tableName => 'video_info';
  
  // ... toMap() / fromMap() 实现
  
  /// 时长格式化工具（定义在本文件中）
  static String formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
```

### 3.2 Providers 层（状态管理）

**职责**：
- 管理 UI 状态（loading、error、data）
- 封装业务操作方法（CRUD）
- 提供响应式数据流（Riverpod）
- 协调 Service 层调用

**核心 Provider：FileProvider**

```dart
// 状态类
class FileState {
  final List<VideoFolder> folders;       // 视频集列表
  final List<VideoInfo> videos;          // 当前视频集的视频列表
  final VideoInfo? currentVideo;         // 当前选中的视频
  final bool isLoading;                  // 加载状态
  final String? error;                   // 错误信息
  
  FileState({
    this.folders = const [],
    this.videos = const [],
    this.currentVideo,
    this.isLoading = false,
    this.error,
  });
  
  FileState copyWith({...}) => ...       // 不可变更新
}

// Notifier 类
class FileNotifier extends StateNotifier<FileState> {
  final DatabaseService _db;
  final FilePickerService _filePicker;
  
  FileNotifier(this._db, this._filePicker) : super(FileState());
  
  // CRUD 操作
  Future<void> loadFolders() async {...}
  Future<void> loadVideos(String folderCode) async {...}
  Future<void> importVideos(String folderCode) async {...}
  Future<void> deleteFolder(String folderCode) async {...}
  
  // 播放状态管理
  void setCurrentVideo(VideoInfo video) {...}
  void updatePlayProgress(String videoCode, int position) {...}
}

// Provider 定义
final fileProvider = StateNotifierProvider<FileNotifier, FileState>((ref) {
  return FileNotifier(
    ref.watch(databaseServiceProvider),
    ref.watch(filePickerServiceProvider),
  );
});
```

**使用方式：**

```dart
// 在 Widget 中监听状态
class FileListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileState = ref.watch(fileProvider);
    
    if (fileState.isLoading) {
      return CircularProgressIndicator();
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
  // 单例模式
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();
  
  late Database _database;
  
  // 初始化和建表
  Future<Database> get database async {...}
  Future<void> registerEntities(List<BaseEntity> entities) async {...}
  Future<void> _createTable(BaseEntity entity) async {...}
  
  // 通用 CRUD
  Future<int> insert(BaseEntity entity) async {...}
  Future<List<T>> findByCondition<T extends BaseEntity>(
    T entityFactory(), {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {...}
  Future<int> update(BaseEntity entity) async {...}
  Future<int> softDelete(BaseEntity entity) async {...}
  
  // FTS5 全文检索
  Future<List<T>> searchFTS<T extends BaseEntity>(
    T entityFactory(),
    String table,
    String query, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {...}
}
```

**FilePickerService 示例：**

```dart
class FilePickerService {
  /// 导入本地视频文件夹
  /// 
  /// 扫描指定目录下的视频文件，创建 VideoInfo 记录
  /// 支持的字幕格式：.srt, .vtt, .ass
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
        hasSubtitles: subtitles.isNotEmpty,
      )..code = generateCode(); // 生成 UUID
      
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
- 组装 UI 组件
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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
- 支持主题适配
- 提供清晰的 Props 接口

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
          borderRadius: BorderRadius.circular(DesignTokens.borderRadiusSm),
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
                  borderRadius: BorderRadius.circular(DesignTokens.borderRadiusXs),
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
                style: TextStyles.bodyXs,
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
      return Icon(Icons.play_circle, color: AppColors.primary, size: 32);
    } else if (_isCompleted()) {
      return Icon(Icons.check_circle, color: AppColors.success, size: 32);
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
// ✅ 推荐：单例 Service
class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();
  
  // 使用
  final db = DatabaseService.instance;
}
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
   - 支持主题适配
```

---

## 五、常见问题排查

### Q1: 应用启动后数据库表未创建？

**检查清单：**
1. `main.dart` 中是否调用了 `registerEntities([...])`
2. 新模型是否继承了 `BaseEntity`
3. 新模型是否实现了 `tableName` getter
4. 是否调用了 `DatabaseService.instance.database` 触发初始化

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
3. 是否使用了 `context.watch<ThemeMode>()` 或 `ref.watch(themeProvider)`
4. `app_colors.dart` 和 `app_theme.dart` 是否存在循环引用

---

## 六、代码统计（截至 2026-07-12）

| 目录 | 文件数 | 大约行数 | 说明 |
|------|--------|----------|------|
| models/ | 10+ | ~1500 | 数据模型 |
| providers/ | 3 | ~800 | 状态管理 |
| services/ | 15+ | ~4000 | 业务逻辑 |
| views/ | 15+ | ~3000 | 页面 UI |
| components/ | 5 | ~600 | 公共组件 |
| widgets/ | 10+ | ~1500 | 业务组件 |
| theme/ | 9 | ~800 | 主题系统 |
| utils/ | 5 | ~300 | 工具类 |
| **总计** | **70+** | **~12500** | |

---

**最后更新**: 2026-07-12  
**维护者**: VidLang 开发团队  
**相关文档**: [README.md](./README.md), [数据库设计.md](./database-design.md), [状态管理指南.md](./state-management-guide.md)
