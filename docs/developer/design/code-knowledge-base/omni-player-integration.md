# OmniPlayer 播放器集成知识库

> **版本**: v1.0.0 (本地定制版)
> **最后更新**: 2026-07-12
> **状态**: ✅ 已启用 - 项目唯一视频/音频播放引擎
> **源码位置**: `plugs/omni_player/`

---

## 📋 目录

1. [核心原则](#核心原则)
2. [架构概览](#架构概览)
3. [安装与引入](#安装与引入)
4. [PlayerState（播放器状态）](#playerstate播放器状态)
5. [MediaItem（媒体项）](#mediaitem媒体项)
6. [OmniPlayer API 完整参考](#omniplayer-api-完整参考)
7. [缓存系统](#缓存系统)
8. [Riverpod 集成模式](#riverpod-集成模式)
9. [PlayerPage 使用示例](#playerpage-使用示例)
10. [音频播放集成](#音频播放集成)
11. [最佳实践与注意事项](#最佳实践与注意事项)
12. [常见问题排查](#常见问题排查)

---

## 核心原则

### ⚠️ 强制规范

> **OmniPlayer 是本项目唯一的视频/音频播放引擎**，所有视频和音频播放功能必须统一使用 OmniPlayer。

**技术特点**:
- ✅ 基于 Platform Channel 的原生播放器封装
- ✅ 支持 iOS (AVPlayer) 和 Android (ExoPlayer/MediaPlayer)
- ✅ 内置视频缓存系统（首次流式加载，后续本地播放）
- ✅ 支持后台播放、锁屏控制、通知栏控制
- ✅ 支持 Seek 同步优化（解决快速拖动时的进度回跳问题）
- ✅ 支持倍速播放 (0.5x - 2.0x)、AB 循环、单句暂停

**禁止行为**:
- ❌ 使用 `video_player` 包
- ❌ 使用 `chewie` 包
- ❌ 使用 `better_player` 包（旧版本文档已废弃）
- ❌ 直接使用原生 AVPlayer/ExoPlayer（必须通过 OmniPlayer 封装）

---

## 架构概览

### 分层架构

```
┌─────────────────────────────────────────────┐
│              PlayerPage (UI 层)              │  ← 用户交互界面
├─────────────────────────────────────────────┤
│         playerEngineProvider (State)         │  ← Riverpod 状态管理
├─────────────────────────────────────────────┤
│       PlayerEngineNotifier (Logic)           │  ← 业务逻辑层
├──────────┬──────────────────────────────────┤
│          │                                  │
│  ┌──────▼──────┐                  ┌────────▼─────────┐
│  │  OmniPlayer  │                  │ AudioPlayer      │  ← TTS/配音
│  │  (Singleton) │                  │ (audioplayers)   │
│  └──────┬──────┘                  └──────────────────┘
│         │                                         │
│  ┌──────▼──────────────────────────────────────────┐
│  │              Platform Channel                   │  ← MethodChannel + EventChannel
│  └──────┬─────────────────┬───────────────────────┘
│         │                 │
│  ┌──────▼──────┐   ┌──────▼──────┐
│  │ iOS Native  │   │ Android     │
│  │ AVPlayer    │   │ ExoPlayer   │
│  └─────────────┘   └─────────────┘
└─────────────────────────────────────────────────────┘
```

### 数据流向

```
用户操作 → PlayerPage → PlayerEngineNotifier → OmniPlayer → 原生播放器
                                                              ↓
原生事件 ← EventChannel ← OmniPlayer ← 原生回调 ← 播放状态变化
                                                              ↓
                                                    PlayerEngineNotifier 更新 State
                                                              ↓
                                                    Riverpod 触发 UI 重建
```

---

## 安装与引入

### 依赖配置

```yaml
# pubspec.yaml (本地路径引用)
dependencies:
  omni_player:
    path: plugs/omni_player
```

### 统一引入方式

```dart
// 播放器核心
import 'package:omni_player/omni_player.dart';

// 状态管理（Riverpod）
import 'package:vidlang/providers/player_engine_provider.dart';

// 模型
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/models/subtitles.dart';
```

---

## PlayerState（播放器状态）

### 状态枚举

```dart
enum PlayerState {
  idle,       // 空闲：未初始化或已释放
  loading,    // 加载中：正在缓冲数据
  playing,    // 播放中
  paused,     // 已暂停
  stopped,    // 已停止
  completed,  // 播放完成
  error,      // 错误状态
}
```

### 状态转换图

```
                    ┌──────────┐
                    │   idle   │
                    └────┬─────┘
                         │ open()
                         ▼
                    ┌──────────┐
              ┌────▶│ loading  │◀────┐
              │     └────┬─────┘     │
              │          │           │ seek()
              │          ▼           │
              │     ┌──────────┐     │
              │     │ playing  │─────┘
              │     └────┬─────┘
              │          │ pause()
              │          ▼
              │     ┌──────────┐
              └─────│ paused   │────┐
                    └────┬─────┘    │
                         │ play()   │ stop()
                         ▼          ▼
                    ┌──────────┐ ┌──────────┐
                    │ completed│ │ stopped  │
                    └──────────┘ └──────────┘
                                      ▲
                                      │ error
                                 ┌──────────┐
                                 │  error   │
                                 └──────────┘
```

### VideoSize（视频尺寸）

```dart
class VideoSize {
  final int width;   // 视频宽度（像素）
  final int height;  // 视频高度（像素）

  double get aspectRatio => height == 0 ? 1.0 : width / height;
}
```

**使用场景**: 
- 自适应视频容器尺寸
- 判断横屏/竖屏视频
- 计算字幕显示区域

---

## MediaItem（媒体项）

### 定义

```dart
class MediaItem {
  final String url;                    // 媒体 URL（本地路径或网络地址）
  final String title;                  // 标题（用于通知栏显示）
  final String? artist;                // 艺术家（可选）
  final String? album;                 // 专辑（可选）
  final String? coverUrl;              // 封面图 URL（可选）
  final bool isVideo;                  // 是否为视频（默认 false = 音频）
  final Map<String, String>? headers;  // HTTP 请求头（网络资源时使用）
}
```

### 创建示例

```dart
// 1️⃣ 本地视频文件
MediaItem(
  url: '/path/to/local/video.mp4',
  title: '教学视频第1集',
  isVideo: true,
)

// 2️⃣ 网络视频（带认证头）
MediaItem(
  url: 'https://example.com/video.mp4',
  title: '在线课程',
  isVideo: true,
  headers: {
    'Authorization': 'Bearer token123',
    'User-Agent': 'VidLang/1.0',
  },
)

// 3️⃣ 音频文件
MediaItem(
  url: '/path/to/audio.mp3',
  title: '听力练习',
  artist: 'TOEFL',
  album: 'Listening Practice',
  isVideo: false,
)

// 4️⃣ 从 VideoInfo 模型创建
MediaItem(
  url: videoInfo.filePath!,  // 注意：需要确保 filePath 不为空
  title: videoInfo.title ?? '未命名视频',
  isVideo: true,
)
```

---

## OmniPlayer API 完整参考

### 单例访问

```dart
// 获取全局单例（推荐方式）
final player = OmniPlayer.instance;

// 特性：
// - 如果当前实例已 dispose，会自动创建新实例
// - 新实例会等待上一实例的原生 dispose 完成（避免 iOS 黑屏）
// - 线程安全
```

### 初始化

```dart
/// 初始化播放器（必须在第一次使用前调用）
///
/// [cacheConfig] 可选：启用缓存系统
Future<void> initialize({CacheConfig? cacheConfig})

// 示例：
await OmniPlayer.instance.initialize();

// 启用缓存（推荐配置）
await OmniPlayer.instance.initialize(cacheConfig: CacheConfig(
  enabled: true,
  maxSize: 500 * 1024 * 1024,  // 500 MB
));
```

### 打开媒体

```dart
/// 打开视频/音频并开始播放
Future<void> open(MediaItem item)

/// 打开媒体（从指定时间点开始）
Future<void> openFrom(MediaItem item, {int? startMs})

// 示例：
final mediaItem = MediaItem(
  url: videoPath,
  title: videoTitle,
  isVideo: true,
);

await OmniPlayer.instance.open(mediaItem);

// 从 30 秒处开始播放
await OmniPlayer.instance.openFrom(mediaItem, startMs: 30000);
```

### 播放控制

```dart
/// 开始/恢复播放
Future<void> play()

/// 暂停播放
Future<void> pause()

/// 停止播放（释放资源但保持实例）
Future<void> stop()

/// 跳转到指定位置（毫秒）
Future<void> seekTo(int positionMs)

/// 设置播放速度 (0.5 - 2.0)
Future<void> setSpeed(double speed)

/// 设置循环播放
Future<void> setLooping(bool looping)

// 示例：
await OmniPlayer.instance.play();
await OmniPlayer.instance.pause();
await OmniPlayer.instance.seekTo(60000);  // 跳到 1 分钟
await OmniPlayer.instance.setSpeed(1.5);  // 1.5 倍速
await OmniPlayer.instance.setLooping(true);  // 循环播放
```

### 音量控制

```dart
/// 设置音量 (0.0 - 1.0)
Future<void> setVolume(double volume)

// 示例：
await OmniPlayer.instance.setVolume(0.8);  // 80% 音量
```

### 状态查询（同步）

```dart
// 当前状态属性（同步获取）
PlayerState get state        // 播放状态
Duration get position        // 当前位置
Duration get duration        // 总时长
double get buffered          // 缓冲进度 (0.0 - 1.0)
int? get textureId           // 视频纹理 ID（用于渲染）
String? get error            // 错误信息
VideoSize? get videoSize     // 视频尺寸
MediaItem? get currentItem    // 当前媒体项
bool get looping             // 是否循环

// 使用示例：
final player = OmniPlayer.instance;
print('状态: ${player.state.name}');
print('进度: ${player.position.inSeconds}s / ${player.duration.inSeconds}s');
print('缓冲: ${(player.buffered * 100).toStringAsFixed(1)}%');
if (player.error != null) {
  print('错误: ${player.error}');
}
```

### 事件监听（异步流）

```dart
// 所有事件流均为 Broadcast Stream，可多次订阅
Stream<PlayerState> get stateStream        // 状态变化
Stream<Duration> get positionStream        // 进度更新（高频）
Stream<Duration> get durationStream        // 时长变化
Stream<double> get bufferedStream          // 缓冲进度变化
Stream<int?> get textureIdStream           // 纹理 ID 变化
Stream<String> get errorStream             // 错误事件
Stream<VideoSize> get videoSizeStream      // 视频尺寸变化
Stream<void> get previousTrackStream       // 通知栏"上一首"
Stream<void> get nextTrackStream           // 通知栏"下一首"

// 示例：监听状态变化
OmniPlayer.instance.stateStream.listen((state) {
  print('状态变为: ${state.name}');
});

// 示例：监听进度更新（用于更新进度条）
OmniPlayer.instance.positionStream.listen((position) {
  // 更新 UI 进度条
  _updateProgressBar(position);
});
```

### 资源释放

```dart
/// 释放播放器资源（会断开所有事件订阅）
///
/// ⚠️ 调用后需通过 OmniPlayer.instance 获取新实例
Future<void> dispose()

// 示例：
@override
void dispose() {
  OmniPlayer.instance.dispose();  // 释放原生资源
  super.dispose();
}
```

---

## 缓存系统

### CacheConfig（缓存配置）

```dart
class CacheConfig {
  final bool enabled;           // 是否启用缓存（默认 true）
  final int maxSize;            // 最大缓存空间（默认 500 MB）
  final String? customDirectory; // 自定义缓存目录（可选）
}
```

### 工作原理

```
第一次播放：
  用户点击播放 → 检查缓存 → 未命中 → 流式下载 + 播放 → 后台保存到本地

第二次播放：
  用户点击播放 → 检查缓存 → 命中 → 直接读取本地文件 → 即时播放
```

### 配置示例

```dart
// 推荐配置（适合视频学习应用）
final cacheConfig = CacheConfig(
  enabled: true,
  maxSize: 1024 * 1024 * 1024,  // 1 GB（可根据用户设备调整）
);

await OmniPlayer.instance.initialize(cacheConfig: cacheConfig);
```

### CacheManager API

```dart
// 获取缓存管理器（initialize 后可用）
CacheManager? cacheManager = OmniPlayer.instance.cacheManager;

// 查询缓存状态
Future<CacheEntry?> getCacheEntry(String url)  // 查询单个文件的缓存信息
Future<List<CacheEntry>> getAllCacheEntries()  // 获取所有缓存条目
Future<int> getCacheSize()                     // 获取当前缓存大小（字节）

// 清理缓存
Future<void> clearCache()                      // 清除所有缓存
Future<void> removeCacheEntry(String url)      // 移除单个缓存

// 示例：检查视频是否已缓存
final entry = await cacheManager?.getCacheEntry(videoUrl);
if (entry != null && entry.isComplete) {
  print('视频已缓存，大小: ${entry.size / 1024 / 1024} MB');
} else {
  print('视频未缓存或下载不完整');
}

// 示例：清理缓存（当存储空间不足时）
if (await cacheManager!.getCacheSize() > cacheConfig.maxSize * 0.9) {
  await cacheManager.clearCache();
  print('缓存已清理');
}
```

### CacheEntry（缓存条目）

```dart
class CacheEntry {
  final String url;        // 原始 URL
  final String localPath;  // 本地缓存路径
  final int size;          // 文件大小（字节）
  final bool isComplete;   // 是否下载完整
  final DateTime createdAt; // 创建时间
  final DateTime updatedAt; // 最后访问时间
}
```

---

## Riverpod 集成模式

### PlayerEngineProvider（项目标准）

**文件位置**: `lib/providers/player_engine_provider.dart`

#### State 定义

```dart
class PlayerEngineState {
  // 核心播放状态
  final String? videoCode;
  final String title;
  final PlayerState playerState;
  final Duration position;
  final Duration duration;
  final double buffered;
  final VideoSize? videoSize;

  // 播放控制
  final double speed;              // 播放速度 (0.5-2.0)
  final bool looping;              // 是否循环
  final String loopingMode;        // 循环模式：single_loop/list_loop/single_play/sequence_play

  // UI 状态
  final bool controlsVisible;      // 控制栏是否可见
  final bool subtitleVisible;      // 字幕是否显示
  final bool translateVisible;     // 译文是否显示
  final double subtitleFontSize;   // 字体大小 (12-40)

  // 学习功能
  final bool singleSentencePause;  // 单句暂停
  final bool slowToFastActive;     // 慢速→常速模式
  final bool pronunciationVisible; // 音标显示
  final bool followModeActive;     // 跟读模式
  final bool isRecording;          // 正在录音
  final double? lastFollowScore;   // 上次跟读评分

  // 定时关闭
  final int shutdownTimerSeconds;  // 定时器秒数（0=关闭）
  final String shutdownTimerType;  // 'time' 或 'episode'
  final int shutdownEpisodeCount;  // 集数定时（0=关闭）

  // AB 循环
  final Duration? abLoopStart;
  final Duration? abLoopEnd;

  // 错误处理
  final String? errorMessage;

  // 其他
  final List<VideoInfo> folderVideos;  // 文件夹内视频列表
  final int? currentSubtitleIndex;     // 当前字幕索引
  final bool hasSubtitles;             // 是否有字幕
  final String? audioType;             // 音频类型
  final double originalVolume;         // 原始音量
}
```

#### Notifier 核心方法

```dart
class PlayerEngineNotifier extends StateNotifier<PlayerEngineState> {
  // === 初始化 ===
  Future<void> initialize();                          // 初始化播放器
  Future<void> openVideoByCode(String videoCode);     // 通过 videoCode 打开视频
  Future<void> reloadSubtitles(String videoCode);     // 重新加载字幕

  // === 播放控制 ===
  Future<void> play();                                // 播放
  Future<void> pause();                               // 暂停
  Future<void> togglePlayPause();                     // 切换播放/暂停
  Future<void> seekTo(Duration position);             // 跳转
  Future<void> seekRelative(Duration delta);          // 相对跳转（快进/快退）
  Future<void> setSpeed(double speed);                // 设置速度
  Future<void> cycleSpeed();                          // 循环切换速度
  Future<void> setLooping(bool looping);              // 设置循环
  Future<void> setLoopingMode(String mode);           // 设置循环模式
  Future<void> setVolume(double volume);              // 设置音量

  // === 字幕控制 ===
  Future<void> toggleSubtitle();                      // 切换字幕显示
  Future<void> toggleTranslate();                     // 切换译文显示
  Future<void> setSubtitleFontSize(double size);      // 设置字幕大小
  Future<void> goToSubtitle(int index);               // 跳转到指定字幕

  // === 学习功能 ===
  Future<void> toggleSingleSentencePause();           // 切换单句暂停
  Future<void> toggleSlowToFast();                    // 切换慢速→常速
  Future<void> togglePronunciation();                 // 切换音标
  Future<void> toggleFollowMode();                    // 切换跟读模式
  Future<void> setABLoop(Duration? start, Duration? end); // 设置 AB 循环

  // === 定时关闭 ===
  Future<void> setShutdownTimer(int seconds);         // 设置定时关闭
  Future<void> setEpisodeTimer(int count);            // 设置集数定时
  Future<void> clearShutdownTimer();                  // 清除定时器

  // === 文件夹播放 ===
  Future<void> playNext();                            // 下一集
  Future<void> playPrevious();                        // 上一集
  Future<void> playVideoAtIndex(int index);           // 播放指定集

  // === 错误处理 ===
  void clearError();                                  // 清除错误
}
```

#### Provider 使用示例

```dart
class ExampleWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听整个状态
    final state = ref.watch(playerEngineProvider);

    // 选择性监听（性能优化）
    final playerState = ref.watch(playerEngineProvider.select((s) => s.playerState));
    final position = ref.watch(playerEngineProvider.select((s) => s.position));
    final speed = ref.watch(playerEngineProvider.select((s) => s.speed));

    return Column(
      children: [
        // 显示播放状态
        Text('状态: ${playerState.name}'),
        
        // 进度条
        LinearProgressIndicator(
          value: state.duration.inMilliseconds > 0
              ? state.position.inMilliseconds / state.duration.inMilliseconds
              : 0.0,
        ),

        // 控制按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(playerState == PlayerState.playing ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                ref.read(playerEngineProvider.notifier).togglePlayPause();
              },
            ),
            Text('${speed}x'),
            IconButton(
              icon: Icon(Icons.speed),
              onPressed: () {
                ref.read(playerEngineProvider.notifier).cycleSpeed();
              },
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## PlayerPage 使用示例

### 完整页面结构

```dart
class PlayerPage extends ConsumerStatefulWidget {
  final String videoCode;           // 视频唯一标识
  final List<VideoInfo>? folderVideos; // 文件夹内的其他视频（可选）

  const PlayerPage({
    super.key,
    required this.videoCode,
    this.folderVideos,
  });
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with WidgetsBindingObserver {

  // === 生命周期 ===
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockLandscape();  // 锁定横竖屏
    Future.microtask(() => _initializePlayer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlockOrientation();
    super.dispose();
  }

  // === 初始化流程 ===
  Future<void> _initializePlayer() async {
    final notifier = ref.read(playerEngineProvider.notifier);
    
    // 1. 打开视频
    await notifier.openVideoByCode(widget.videoCode);
    
    // 2. 加载字幕
    await notifier.reloadSubtitles(widget.videoCode);
    
    // 3. 加载文件夹列表（如未传入）
    if (widget.folderVideos == null) {
      await _loadFolderVideos();
    }
    
    // 4. 初始化翻译服务（如果需要）
    await _checkAndInitializeTranslation(notifier);
  }

  // === UI 构建 ===
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerEngineProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 视频渲染层
          _buildVideoLayer(state),

          // 字幕层
          if (state.subtitleVisible) _buildSubtitleLayer(state),

          // 控制层（自动隐藏）
          if (state.controlsVisible) _buildControlsLayer(state),
        ],
      ),
    );
  }

  Widget _buildVideoLayer(PlayerEngineState state) {
    return OmniVideoWidget(  // 视频纹理渲染组件
      textureId: OmniPlayer.instance.textureId,
      aspectRatio: state.videoSize?.aspectRatio ?? 16 / 9,
    );
  }

  Widget _buildControlsLayer(PlayerEngineState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 进度条
        _buildSeekBar(state),

        // 控制按钮行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSpeedButton(state),
            _buildPlayPauseButton(state),
            _buildLoopButton(state),
            _buildNextButton(state),
          ],
        ),

        // 底部工具栏
        _buildToolbar(state),
      ],
    );
  }
}
```

### 关键功能实现

#### 1. 自动隐藏控制栏

```dart
bool _controlsVisible = true;
Timer? _hideTimer;

void _resetAutoHide() {
  _hideTimer?.cancel();
  setState(() => _controlsVisible = true);
  
  _hideTimer = Timer(const Duration(seconds: 3), () {
    if (mounted && !_showWordPopup) {
      setState(() => _controlsVisible = false);
    }
  });
}

void _showControls() {
  if (!_controlsVisible) {
    setState(() => _controlsVisible = true);
  }
  _resetAutoHide();
}
```

#### 2. 手势操作

```dart
GestureDetector(
  onTap: () {
    // 点击切换控制栏显隐
    ref.read(playerEngineProvider.notifier).toggleControlsVisibility();
  },
  onDoubleTap: () {
    // 双击切换播放/暂停
    ref.read(playerEngineProvider.notifier).togglePlayPause();
  },
  onHorizontalDragEnd: (details) {
    // 左右滑动快进/快退
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity > 0) {
      ref.read(playerEngineProvider.notifier).seekRelative(Duration(seconds: 10));
    } else {
      ref.read(playerEngineProvider.notifier).seekRelative(Duration(seconds: -10));
    }
  },
  child: _buildVideoContent(),
)
```

#### 3. 字幕显示

```dart
Widget _buildSubtitle(PlayerEngineState state) {
  if (!state.hasSubtitles || state.currentSubtitleIndex == null) {
    return SizedBox.shrink();
  }

  final subtitle = state.subtitles[state.currentSubtitleIndex!];
  
  return Positioned(
    bottom: 120,
    left: 16,
    right: 16,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 英文原文（可选择）
          SelectableEnglishLine(
            text: subtitle.text,
            fontSize: state.subtitleFontSize,
            onTap: () => _showWordCard(subtitle),  // 点击查词
          ),
          
          // 中文翻译
          if (state.translateVisible && subtitle.translation != null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                subtitle.translation!,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: state.subtitleFontSize * 0.8,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
```

---

## 音频播放集成

### AudioPlayerPage（独立音频播放页面）

**文件位置**: `lib/views/audio_player/audio_player_page.dart`

对于纯音频内容（如听力练习、播客），项目提供独立的音频播放页面：

```dart
class AudioPlayerPage extends ConsumerStatefulWidget {
  final String audioCode;
  const AudioPlayerPage({super.key, required this.audioCode});
}

// 特殊之处：
// - 使用 OmniPlayer 但 isVideo=false
// - 显示专辑封面（如有）
// - 支持后台播放和锁屏控制
// - 集成 TTS 服务（跟读功能）
```

### 音频 vs 视频的区别

| 特性 | 视频播放 | 音频播放 |
|------|----------|----------|
| 渲染组件 | `OmniVideoWidget` | 无（仅音频） |
| 屏幕方向 | 强制横屏 | 保持竖屏 |
| 后台播放 | 可选 | 默认开启 |
| 锁屏控制 | 显示标题+进度 | 显示封面+标题 |
| 通知栏 | 基础控制 | 完整控制（上一首/下一首） |

---

## 最佳实践与注意事项

### ✅ 必须遵守的规范

#### 1. 生命周期管理

```dart
// ✅ 正确：在 initState 中初始化，dispose 中清理
class _PlayerPageState extends ConsumerState<PlayerPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _initializePlayer());  // 微任务延迟初始化
  }

  @override
  void dispose() {
    // 不要在这里 dispose OmniPlayer（它是单例）
    // 只清理页面级别的资源
    _hideTimer?.cancel();
    super.dispose();
  }
}
```

#### 2. 状态监听优化

```dart
// ✅ 正确：选择性监听，避免不必要的重建
@override
Widget build(BuildContext context) {
  // 只监听需要的字段
  final playerState = ref.watch(
    playerEngineProvider.select((s) => s.playerState)
  );
  final position = ref.watch(
    playerEngineProvider.select((s) => s.position)
  );

  // position 高频更新时，使用独立的 StatefulWidget 包裹进度条
  return Column(
    children: [
      _BuildProgressBar(position: position),  // 独立重建
      _BuildControlButtons(state: playerState),  // 低频更新
    ],
  );
}
```

#### 3. Seek 操作处理

```dart
// ✅ 正确：使用 Provider 方法进行 seek
void _onSeek(double value) {
  final duration = ref.read(playerEngineProvider).duration;
  final targetPosition = Duration(
    milliseconds: (duration.inMilliseconds * value).round(),
  );
  
  ref.read(playerEngineProvider.notifier).seekTo(targetPosition);
}

// ❌ 错误：直接调用 OmniPlayer.seekTo（绕过状态管理）
// OmniPlayer.instance.seekTo(targetPosition.inMilliseconds);
```

#### 4. 错误处理

```dart
// ✅ 正确：监听错误状态并展示
@override
Widget build(BuildContext context) {
  final errorMessage = ref.watch(
    playerEngineProvider.select((s) => s.errorMessage)
  );

  if (errorMessage != null) {
    return ErrorDisplayWidget(
      error: errorMessage!,
      onRetry: () {
        ref.read(playerEngineProvider.notifier).clearError();
        ref.read(playerEngineProvider.notifier).openVideoByCode(widget.videoCode);
      },
    );
  }

  return _buildNormalContent();
}
```

### ⚠️ 常见陷阱

#### 1. iOS 黑屏问题

**原因**: 在旧实例 dispose 完成前就初始化新实例。

**解决方案**: OmniPlayer 已内置 `_activeDisposeFuture` 机制，会自动等待。只需确保使用 `OmniPlayer.instance` 获取单例：

```dart
// ✅ 安全
final player = OmniPlayer.instance;  // 自动处理并发问题
await player.open(mediaItem);
```

#### 2. 快速 Seek 回跳

**现象**: 用户拖动到 01:08，松手后却显示 01:02。

**原因**: 原生播放器的 discontinuity 事件返回旧的 position 值。

**解决方案**: OmniPlayer 内置 `_applySeekPositionSync` 方法，自动校正：

- 钳位：不显示低于 seek 目标的值
- 过滤：忽略与 seek 前相同的陈旧样本
- 清除：仅在原生位置落在目标附近时结束同步

开发者无需额外处理，OmniPlayer 已自动优化。🎉

#### 3. 内存泄漏

**原因**: 忘记取消 Stream 订阅。

**解决方案**: OmniPlayer 使用 Broadcast Stream，不会导致内存泄漏。但如果手动订阅：

```dart
StreamSubscription? _positionSub;

@override
void initState() {
  super.initState();
  _positionSub = OmniPlayer.instance.positionStream.listen(_onPositionChanged);
}

@override
void dispose() {
  _positionSub?.cancel();  // ✅ 必须取消
  super.dispose();
}
```

#### 4. 后台播放被杀

**原因**: iOS/Android 系统限制后台进程。

**解决方案**: 
- 在 `Info.plist` (iOS) 中添加 `UIBackgroundModes: audio`
- 在 `AndroidManifest.xml` 中添加 `FOREGROUND_SERVICE` 权限
- OmniPlayer 已处理锁屏控制和通知栏控制

---

## 常见问题排查

### Q1: 视频无法播放，一直处于 loading 状态？

**排查步骤**:
1. 检查文件路径是否正确（本地文件必须是绝对路径）
2. 检查文件是否存在：`File(path).existsSync()`
3. 查看错误信息：`OmniPlayer.instance.error`
4. 检查权限（特别是 Android 10+ 的分区存储）

```dart
try {
  final file = File(videoPath);
  if (!await file.exists()) {
    TDToast.showError('文件不存在', context: context);
    return;
  }
  
  await OmniPlayer.instance.open(MediaItem(
    url: videoPath,
    title: title,
    isVideo: true,
  ));
} catch (e) {
  TDToast.showError('播放失败: $e', context: context);
}
```

### Q2: 如何实现画中画 (PiP)？

OmniPlayer 当前不支持 PiP。如需此功能：
- iOS: 使用 `AVPictureInPictureController`
- Android: 使用 `PictureInPictureParamsBuilder`
- 需要扩展 OmniPlayer 原生代码

### Q3: 如何支持投屏 (Cast)？

OmniPlayer 当前不支持 Cast。建议方案：
- 集成 Google Cast SDK (Android)
- 集成 AirPlay (iOS)
- 或使用第三方包如 `chromecast`

### Q4: 如何支持弹幕？

OmniPlayer 不内置弹幕功能。实现方案：
1. 在视频层上方叠加弹幕 Widget
2. 使用 `danmaku` 或 `barrage` 包
3. 与播放进度同步弹幕时间轴

```dart
Stack(
  children: [
    OmniVideoWidget(textureId: textureId),
    BarrageWidget(
      barrageController: _barrageController,
      ...  // 弹幕配置
    ),
  ],
)
```

### Q5: 如何统计播放时长（用于学习记录）？

```dart
// 方案 1：定期采样（推荐）
Timer? _statsTimer;
Duration _totalWatched = Duration.zero;
DateTime? _lastTick;

void _startStatsTracking() {
  _lastTick = DateTime.now();
  _statsTimer = Timer.periodic(Duration(seconds: 1), (timer) {
    final state = ref.read(playerEngineProvider);
    if (state.playerState == PlayerState.playing) {
      _totalWatched += Duration(seconds: 1);
    }
    
    // 每 30 秒保存一次
    if (_totalWatched.inSeconds % 30 == 0) {
      _saveLearningRecord(_totalWatched);
    }
  });
}

// 方案 2：监听状态变化
OmniPlayer.instance.stateStream.listen((state) {
  if (state == PlayerState.playing) {
    _startTime = DateTime.now();
  } else if (state == PlayerState.paused || state == PlayerState.completed) {
    final watched = DateTime.now().difference(_startTime!);
    _saveLearningRecord(watched);
  }
});
```

---

## 📚 相关文档

- [OmniPlayer 源码](../../../plugs/omni_player/lib/src/omni_player.dart)
- [PlayerEngineProvider](../../../lib/providers/player_engine_provider.dart)
- [PlayerPage 实现](../../../lib/views/player/player_page.dart)
- [TDesign 组件库](./tdesign-components.md) — 播放器页面的 UI 组件
- [数据库设计](./database-design.md) — VideoInfo/Subtitle 表结构
- [服务层架构](./services-architecture.md) — LearningStatsService

---

## 🔄 版本历史

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0.0 | 2026-07-12 | 初版建立，完整的 API 参考与集成指南 | AI Assistant |

---

## ✅ 功能清单（后续扩展参考）

### 已实现 ✅
- [x] 基础播放/暂停/停止
- [x] Seek（含同步优化）
- [x] 倍速播放 (0.5x - 2.0x)
- [x] 循环播放（单集/列表/顺序）
- [x] 字幕加载与显示
- [x] AI 翻译集成
- [x] 单句暂停
- [x] 慢速→常速模式
- [x] 跟读评分
- [x] AB 循环
- [x] 定时关闭（时间/集数）
- [x] 视频缓存系统
- [x] 后台播放 & 锁屏控制
- [x] 文件夹连续播放

### 待实现 🚧
- [ ] 画中画 (PiP)
- [ ] 投屏 (Cast/AirPlay)
- [ ] 弹幕支持
- [ ] 字幕样式自定义（字体、颜色、位置）
- [ ] 音轨切换（多语言）
- [ ] 倍速预设 > 2.0x（如 3.0x、4.0x）
- [ ] 播放历史记录（最近观看位置）
- [ ] 收藏/稍后再看列表
- [ ] 截图功能
- [ ] GIF 录制
