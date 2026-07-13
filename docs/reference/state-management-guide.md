# VidLang - 状态管理指南（Riverpod）

> **版本**: V1.0 | **日期**: 2026-07-12  
> **状态**: 当前有效  
> **适用读者**: Flutter 开发者、UI 开发者、AI 辅助工具

---

## 一、状态管理概述

### 1.1 技术选型

VidLang 使用 **Flutter Riverpod** 作为状态管理方案。

**选择理由：**
- ✅ 编译时安全（类型检查）
- ✅ 自动依赖追踪和 dispose
- ✅ 测试友好（无需 BuildContext）
- ✅ 支持 Provider 组合和条件监听
- ✅ 与 Flutter 架构完美融合

**版本要求：**
```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^2.4.0
```

### 1.2 核心概念

| 概念 | 说明 | 使用场景 |
|------|------|----------|
| **Provider** | 提供不可变对象或服务实例 | 单例服务、配置常量 |
| **StateNotifierProvider** | 提供 StateNotifier + State | 复杂状态管理（CRUD） |
| **FutureProvider** | 异步数据加载 | 一次性异步操作 |
| **StreamProvider** | 流式数据监听 | 实时事件、WebSocket |
| **Consumer / ConsumerWidget** | 监听 Provider 变化并重建 UI | Widget 层 |

---

## 二、项目中的 Provider 清单

### 2.1 全局 Provider 列表

| 序号 | Provider 名称 | 类型 | 状态类/返回值 | 职责 |
|------|--------------|------|---------------|------|
| 1 | `fileProvider` | StateNotifierProvider<FileNotifier, FileState> | FileState | 文件域状态（文件夹/视频 CRUD） |
| 2 | `navigationProvider` | StateNotifierProvider<NavigationNotifier, NavigationState> | NavigationState | 导航状态（当前 Tab、路由栈） |
| 3 | `userProvider` | StateNotifierProvider<UserNotifier, UserState> | UserState | 用户状态（登录信息、订阅模式） |
| 4 | `subscriptionProvider` | StateNotifierProvider<SubscriptionNotifier, SubscriptionState> | SubscriptionState | 订阅模式（免费/收费切换） |

### 2.2 服务层 Provider（单例注入）

| 序号 | Provider 名称 | 类型 | 返回值 | 职责 |
|------|--------------|------|--------|------|
| 5 | `databaseServiceProvider` | Provider<DatabaseService> | DatabaseService | 数据库单例 |
| 6 | `filePickerServiceProvider` | Provider<FilePickerService> | FilePickerService | 文件导入单例 |
| 7 | `thumbnailServiceProvider` | Provider<ThumbnailService> | ThumbnailService | 缩略图单例 |
| 8 | `authServiceProvider` | Provider<AuthService> | AuthService | 认证单例 |
| 9 | `aiServiceProvider` | Provider<AiService> | AiService | AI 服务（静态方法，无需实例） |

---

## 三、核心 Provider 详解

### 3.1 fileProvider（文件域状态）⭐⭐⭐

**文件**: `lib/providers/file_provider.dart`

#### 状态结构

```dart
class FileState {
  final List<VideoFolder> folders;       // 文件夹列表
  final VideoFolder? currentFolder;      // 当前选中文件夹
  final List<VideoInfo> videos;          // 当前文件夹的视频列表
  final VideoInfo? currentVideo;         // 当前正在播放的视频
  final bool isLoading;                   // 加载状态
  final String? error;                   // 错误信息
  
  FileState({
    this.folders = const [],
    this.currentFolder,
    this.videos = const [],
    this.currentVideo,
    this.isLoading = false,
    this.error,
  });
  
  // 不可变更新（copyWith 模式）
  FileState copyWith({...}) => ...;
}
```

#### Notifier 方法清单

```dart
class FileNotifier extends StateNotifier<FileState> {
  
  // ════════════════════════════════════
  //  文件夹 CRUD
  // ════════════════════════════════════
  
  /// 加载所有文件夹（首页使用）
  Future<void> loadFolders() async {...}
  
  /// 创建新文件夹
  Future<VideoFolder> createFolder({
    required String name,
    VideoFolderType type = VideoFolderType.virtual,
    String? path,
  }) async {...}
  
  /// 重命名文件夹
  Future<void> renameFolder(String folderCode, String newName) async {...}
  
  /// 删除文件夹（软删除 + 物理文件清理）
  Future<void> deleteFolder(String folderCode) async {...}
  
  // ════════════════════════════════════
  //  视频 CRUD
  // ════════════════════════════════════
  
  /// 加载指定文件夹的视频列表
  Future<void> loadVideos(String folderCode) async {...}
  
  /// 导入视频到指定文件夹
  Future<void> importVideos(String folderCode) async {...}
  
  /// 删除视频（软删除 + 物理文件删除）
  Future<void> deleteVideo(VideoInfo video) async {...}
  
  // ════════════════════════════════════
  //  播放状态管理
  // ════════════════════════════════════
  
  /// 设置当前播放视频
  void setCurrentVideo(VideoInfo video) {...}
  
  /// 更新播放进度
  void updatePlayProgress(String videoCode, int positionMs) {...}
  
  /// 更新视频的当前截图
  void updateCurrentCover(String videoCode, String coverPath) {...}
  
  /// 标记视频正在播放
  void setPlayingStatus(String videoCode, bool isPlaying) {...}
  
  // ════════════════════════════════════
  //  字幕与分词
  // ════════════════════════════════════
  
  /// 加载视频字幕
  Future<List<Subtitle>> loadSubtitles(String videoCode) async {...}
  
  /// 搜索字幕关键词
  Future<List<Subtitle>> searchSubtitles(String query) async {...}
  
  /// 获取单词的分词结果
  Future<List<Participle>> getWordParticiple(String word) async {...}
}
```

#### 使用示例

```dart
class FolderDetailPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. 监听完整状态
    final fileState = ref.watch(fileProvider);
    
    return Scaffold(
      body: fileState.isLoading
        ? Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // 顶部大卡（当前视频）
              if (fileState.currentVideo != null)
                MainVideoCard(video: fileState.currentVideo!),
              
              // 视频九宫格
              Expanded(
                child: GridView.builder(
                  itemCount: fileState.videos.length,
                  itemBuilder: (context, index) {
                    final video = fileState.videos[index];
                    return GestureDetector(
                      onTap: () {
                        // 2. 调用 Notifier 方法
                        ref.read(fileProvider.notifier)
                          .setCurrentVideo(video);
                      },
                      child: VideoCard(video: video),
                    );
                  },
                ),
              ),
              
              // 错误提示
              if (fileState.error != null)
                ErrorWidget(message: fileState.error!),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 3. 触发导入操作
          ref.read(fileProvider.notifier)
            .importVideos(folderCode);
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
```

---

### 3.2 subscriptionProvider（订阅模式）⭐⭐

**职责**：管理用户的订阅模式（免费/收费），影响 AI 功能的使用。

#### 状态结构

```dart
enum SubscriptionMode { free, premium }

class SubscriptionState {
  final SubscriptionMode currentMode;
  final double balanceCny;        // 余额（元）
  final bool isLoading;
  final String? error;
  
  SubscriptionState({
    this.currentMode = SubscriptionMode.free,
    this.balanceCny = 0,
    this.isLoading = false,
    this.error,
  });
}
```

#### 使用场景

```dart
// 在任何地方获取当前订阅模式
final mode = ref.watch(subscriptionProvider).currentMode;

// 根据 mode 决定使用哪种服务
if (mode == SubscriptionMode.premium) {
  // 收费模式：走 AI 云端服务
  final detail = await AiService.getDefinition(word: word);
} else {
  // 免费模式：走 iOS 原生翻译
  final translation = await IosNativeFeatures.translate(text: word);
}

// UI 层显示不同的按钮样式
TDSwitch(
  value: mode == SubscriptionMode.premium,
  onChanged: (value) {
    if (value) {
      showRechargeDialog();  // 引导充值
    } else {
      ref.read(subscriptionProvider.notifier).switchToFree();
    }
  },
)
```

---

## 四、Riverpod 最佳实践

### 4.1 三种监听方式对比

| 方式 | API | 用途 | 重建频率 |
|------|-----|------|----------|
| **完整监听** | `ref.watch(provider)` | 需要所有字段时 | 状态任意变化都重建 |
| **选择性监听** | `ref.watch(provider.select((s) => s.field))` | 只需要某个字段时 | 仅该字段变化才重建 |
| **一次性读取** | `ref.read(provider)` | 在回调中使用 | 不触发重建 |

#### 选择性监听示例（性能优化）

```dart
// ❌ 低效：监听整个 state，任何字段变化都重建
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileProvider);  // 监听全部
    
    return Text('${state.videos.length}');  // 只用了 videos.length
  }
}

// ✅ 高效：只监听 videos 字段
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videos = ref.watch(
      fileProvider.select((s) => s.videos)  // 只监听 videos
    );
    
    return Text('${videos.length}');
  }
}
```

### 4.2 Provider 组合与依赖

```dart
// 定义依赖关系：FileNotifier 依赖 DatabaseService 和 FilePickerService
final fileProvider = StateNotifierProvider<FileNotifier, FileState>((ref) {
  return FileNotifier(
    // 通过 ref.watch() 获取其他 Provider 的实例
    databaseService: ref.watch(databaseServiceProvider),
    filePickerService: ref.watch(filePickerServiceProvider),
  );
});

// DatabaseService 单例 Provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

// FilePickerService 单例 Provider
final filePickerServiceProvider = Provider<FilePickerService>((ref) {
  return FilePickerService();
});
```

### 4.3 异步操作标准模式

```dart
/// Notifier 中的异步方法模板
Future<void> _asyncOperation() async {
  // 1. 设置 loading 状态
  state = state.copyWith(isLoading: true, error: null);
  
  try {
    // 2. 执行业务逻辑
    final result = await _service.doSomething();
    
    // 3. 更新成功状态
    state = state.copyWith(
      data: result,
      isLoading: false,
    );
    
  } on CustomException catch (e) {
    // 4. 处理已知业务异常
    state = state.copyWith(
      isLoading: false,
      error: e.message,
    );
    
  } catch (e) {
    // 5. 处理未知异常
    state = state.copyWith(
      isLoading: false,
      error: '操作失败，请重试',
    );
    
    // 可选：记录日志
    dev.log('❌ 操作失败', error: e, name: 'MyNotifier');
  }
}
```

### 4.4 防抖与节流

```dart
// 搜索输入防抖（避免频繁请求）
class SearchNotifier extends StateNotifier<SearchState> {
  Timer? _debounce;
  
  void onSearchQueryChanged(String query) {
    // 取消上一次定时器
    _debounce?.cancel();
    
    // 如果查询为空，立即清空结果
    if (query.isEmpty) {
      state = state.copyWith(results: []);
      return;
    }
    
    // 设置 300ms 防抖
    _debounce = Timer(const Duration(milliseconds: 300), () {
      performSearch(query);
    });
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
```

### 4.5 多 Provider 协作示例

```dart
// 场景：用户点击"查词"按钮，涉及多个 Provider 协作

class WordCardWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听订阅模式（决定用免费还是收费查词）
    final subscriptionState = ref.watch(subscriptionProvider);
    
    return ElevatedButton(
      onPressed: () => _lookupWord(ref, subscriptionState.currentMode),
      child: Text('查词'),
    );
  }
  
  Future<void> _lookupWord(WidgetRef ref, SubscriptionMode mode) async {
    try {
      WordDetail detail;
      
      if (mode == SubscriptionMode.premium) {
        // 收费模式：调用 AiService（通过 NativeService 封装）
        detail = await NativeService.lookupWord(
          word: widget.word,
          mode: mode,
        );
        
        // 余额不足时，引导充值
        if (detail.isInsufficientBalance) {
          ref.read(subscriptionProvider.notifier).showRechargeDialog(
            requiredCny: detail.costCny!,
          );
          return;
        }
      } else {
        // 免费模式：iOS 原生翻译
        detail = await NativeService.lookupWord(
          word: widget.word,
          mode: mode,
        );
      }
      
      // 显示查词结果（更新 UI 状态）
      ref.read(wordCardProvider.notifier).showResult(detail);
      
    } catch (e) {
      showErrorToast('查词失败: $e');
    }
  }
}
```

---

## 五、常见模式与反模式

### 5.1 ✅ 推荐模式

#### 模式 1：State + Notifier 分离

```dart
// State 类（纯数据，不可变）
class MyState {
  final List<Item> items;
  final bool isLoading;
  const MyState({this.items = const [], this.isLoading = false});
  MyState copyWith({...}) => ...;
}

// Notifier 类（业务逻辑）
class MyNotifier extends StateNotifier<MyState> {
  MyNotifier() : super(const MyState());
  
  Future<void> loadItems() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await _service.fetchItems();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// Provider 定义
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier();
});
```

#### 模式 2：ConsumerWidget 替代 Consumer

```dart
// ✅ 推荐：ConsumerWidget（类型安全，代码简洁）
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  }
}

// ❌ 避免：Consumer（需要嵌套 builder，类型不安全）
Consumer(
  builder: (context, ref, child) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  },
)
```

#### 模式 3：ref.read vs ref.watch

```dart
// ref.watch：在 build 方法中使用（触发重建）
@override
Widget build(BuildContext context, WidgetRef ref) {
  final mode = ref.watch(subscriptionProvider);  // ✅ 正确
  return Text(mode.name);
}

// ref.read：在回调和生命周期方法中使用（不触发重建）
onPressed: () {
  ref.read(fileProvider.notifier).loadFolders();  // ✅ 正确
  final folders = ref.read(fileProvider).folders;   // ✅ 正确（读取快照）
}

// ❌ 错误：在 build 中使用 ref.read（不会响应变化）
@override
Widget build(BuildContext context, WidgetRef ref) {
  final mode = ref.read(subscriptionProvider);  // ❌ 不会重建！
  return Text(mode.name);
}
```

### 5.2 ❌ 反模式（应避免）

#### 反模式 1：在 setState 中直接修改状态

```dart
// ❌ 错误：直接修改 state 的字段（编译错误）
void addItem(Item item) {
  state.items.add(item);  // ❌ state.items 是 final 的！
}

// ✅ 正确：使用 copyWith 创建新状态
void addItem(Item item) {
  state = state.copyWith(items: [...state.items, item]);
}
```

#### 反模式 2：在 build 方法中执行副作用

```dart
// ❌ 错误：每次 build 都会执行（可能导致无限循环）
@override
Widget build(BuildContext context, WidgetRef ref) {
  ref.read(myProvider.notifier).loadData();  // ❌ 不要在这里调用！
  return Container();
}

// ✅ 正确：在 initState 或回调中执行
class MyPage extends ConsumerStatefulWidget { ... }

class _MyPageState extends ConsumerState<MyPage> {
  @override
  void initState() {
    super.initState();
    // 使用微任务确保在第一帧后执行
    Future.microtask(() {
      ref.read(myProvider.notifier).loadData();  // ✅ 正确
    });
  }
}
```

#### 反模式 3：过度拆分 Provider

```dart
// ❌ 过度拆分：每个字段一个 Provider（难以维护）
final firstNameProvider = StateProvider<String>((ref) => '');
final lastNameProvider = StateProvider<String>((ref) => '');
final ageProvider = StateProvider<int>((ref) => 0);
final emailProvider = StateProvider<String>((ref) => '');

// ✅ 合理拆分：相关字段放在同一个 State 中
class UserState {
  final String firstName;
  final String lastName;
  final int age;
  final String email;
  // ...
}
final userProvider = StateNotifierProvider<UserNotifier, UserState>(...);
```

---

## 六、测试指南

### 6.1 单元测试 Notifier

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/providers/file_provider.dart';

void main() {
  group('FileNotifier', () () {
    late FileNotifier notifier;
    
    setUp(() {
      notifier = FileNotifier();
    });
    
    test('初始状态应为空', () {
      expect(notifier.state.folders, isEmpty);
      expect(notifier.state.isLoading, false);
      expect(notifier.state.error, isNull);
    });
    
    test('loadFolders 应更新状态', () async {
      // Mock DatabaseService
      // ...
      
      await notifier.loadFolders();
      
      expect(notifier.state.isLoading, false);
      expect(notifier.state.folders, isNotEmpty);
    });
    
    test('setCurrentVideo 应更新 currentVideo', () {
      final video = VideoInfo(name: 'test.mp4')..code = 'test-code';
      
      notifier.setCurrentVideo(video);
      
      expect(notifier.state.currentVideo, video);
      expect(notifier.state.currentVideo?.isCurrentPlaying, true);
    });
  });
}
```

### 6.2 Widget 测试（使用 ProviderScope）

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/providers/file_provider.dart';

void main() {
  testWidgets('FolderListPage 应显示文件夹列表', (tester) async {
    // 提供 mock override
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileProvider.overrideWithValue(
            // 返回预设的状态用于测试
            StateNotifierController<FileNotifier, FileState>(
              FileNotifier(),
              FileState(folders: [
                VideoFolder(name: 'Folder 1')..code = 'f1',
                VideoFolder(name: 'Folder 2')..code = 'f2',
              ]),
            ),
          ),
        ],
        child: MaterialApp(home: FolderListPage()),
      ),
    );
    
    expect(find.text('Folder 1'), findsOneWidget);
    expect(find.text('Folder 2'), findsOneWidget);
  });
}
```

---

## 七、调试技巧

### 7.1 Riverpod Inspector

在开发模式下启用 Riverpod Inspector：

```dart
void main() {
  runApp(
    UncontrolledProviderScope(
      container: ProviderContainer(
        // 开发模式启用 inspector
        observers: [Logger()],
      ),
      child: MyApp(),
    ),
  );
}
```

然后在 Chrome DevTools 中查看 Provider 状态树。

### 7.2 日志输出

```dart
// 自定义 Observer，打印所有 Provider 变更
class Logger extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    print('{
      "provider": "${provider.name ?? provider.runtimeType}",
      "newValue": "$newValue"
    }');
  }
  
  @override
  void didDisposeProvider(
    ProviderBase provider,
    ProviderContainer container,
  ) {
    print('Disposed: ${provider.name ?? provider.runtimeType}');
  }
}
```

### 7.3 常见问题排查

| 问题 | 可能原因 | 解决方案 |
|------|----------|----------|
| **UI 不更新** | 使用了 `ref.read` 而非 `ref.watch` | 改为 `ref.watch` 或 `ref.listen` |
| **无限重建** | 在 build 中调用了修改 state 的方法 | 将副作用移到 `initState` 或回调中 |
| **状态丢失** | Provider 被重新创建（未使用 `family` 或全局） | 检查 Provider 作用域 |
| **内存泄漏** | 未正确 dispose StreamController | 在 Notifier 的 `dispose()` 中关闭 |

---

## 八、迁移指南（从其他状态管理）

如果你熟悉其他状态管理方案，以下是快速对照：

### 8.1 Riverpod vs Provider（旧版）

| 概念 | Provider（旧版） | Riverpod（新版） |
|------|------------------|-----------------|
| 创建 Provider | `provider = Provider(...)` | `final provider = Provider(...)` |
| 访问 | `Provider.of(context)` | `ref.watch(provider)` |
| 作用域 | `MultiProvider` | `ProviderScope` |
| 编译安全 | ❌ 运行时异常 | ✅ 编译时检查 |
| 测试 | 需要 `ProviderScope` | 同样需要，但更简单 |

### 8.2 Riverpod vs BLoC

| 维度 | BLoC | Riverpod |
|------|------|----------|
| 样板代码 | 较多（Event/State/Bloc） | 较少（State/Notifier） |
| 学习曲线 | 陡峭 | 平缓 |
| 依赖注入 | 手动或 get_it | 内置 ref 系统 |
| 适用场景 | 大型复杂应用 | 中小型应用（VidLang 规模合适） |

---

## 九、性能优化 Checklist

- [ ] 使用 `select()` 进行选择性监听，避免不必要的重建
- [ ] 列表项使用 `const` 构造函数
- [ ] 长列表使用 `ListView.builder` 而非 `ListView`
- [ ] 图片使用缓存（`cached_network_image` / `Image.file` with cache）
- [ ] 搜索/输入使用防抖（300ms）
- [ ] 避免在 `build()` 中创建新的 List/Map（使用 `...` spread）
- [ ] 大状态对象考虑拆分为多个子 Provider
- [ ] 使用 `UncontrolledProviderScope` 测试时提供 mock 数据

---

**最后更新**: 2026-07-12  
**维护者**: VidLang 开发团队  
**相关文档**: 
- [README.md](./README.md) - 知识库入口
- [Flutter 代码结构详解](./flutter-code-structure.md) - Providers 目录位置
- [服务层架构](./services-architecture.md) - Services 如何被 Providers 调用
