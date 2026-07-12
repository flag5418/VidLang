# VidLang 视频播放模块评估与改进建议

> 评估日期：2026-06-04  
> 评估范围：PlayerPage + PlayerEngineProvider + OmniPlayer + Subtitles 全链路

---

## 一、当前架构总览

```
用户操作
    ↓
folder_detail_page.dart → PlayerPage(videoCode)
    ↓ ← initState
playerEngineProvider.notifier.openVideoByCode(code)
    ↓
1. 查 VideoInfo（数据库）
2. 查 VideoFolder（获取跳过设置）
3. 初始化 OmniPlayer
4. 打开视频文件
5. 开始播放
    ↓
OmniPlayer（原生桥接）
├── iOS: IJKPlayer (FFmpeg+VideoToolbox)
├── Android: Texture + MediaPlayer
├── CacheManager（LRU 磁盘缓存）
└── EventChannel 推送状态/位置/尺寸
    ↓
PlayerEngineNotifier 订阅事件
├── 位置更新 → 二分查找当前字幕索引
├── 字幕高亮 → 字幕 UI 更新
├── 单句暂停 → 句末自动暂停
├── 由慢到快 → 逐级加速
└── 学习记录 → 定时保存进度
    ↓
PlayerPage UI
├── VideoWidget（画面渲染）
├── TopBar（返回/标题/视频列表/设置）
├── BottomBar（进度条/播放控制/功能按钮）
├── 字幕显示（当前句 + 翻译）
├── 速度选择浮层
├── 视频列表抽屉
├── 设置抽屉
└── Dub 面板（复读/配音 UI 壳）
```

---

## 二、当前评估：成熟度评分

| 维度 | 评分 | 说明 |
|------|------|------|
| **播放器内核** | ⭐⭐⭐⭐⭐ | OmniPlayer 支持 iOS(PlatformView+IJK) 和 Android(Texture)，带 LRU 磁盘缓存，stream 体系完整 |
| **字幕跟踪** | ⭐⭐⭐⭐⭐ | 二分查找当前字幕索引，支持 start/end 位置精确匹配，多字幕切换 |
| **状态管理** | ⭐⭐⭐⭐ | PlayerEngineNotifier 设计清晰，copyWith 模式好，事件订阅完整 |
| **学习功能 - 跟读** | ⭐⭐ | Dub 面板 UI 完整但**录音功能未实现**（占位消息），评分未集成 |
| **学习功能 - 测试** | ⭐ | **完全未实现**，只有 TestPage 是开发工具页非学习测试 |
| **学习功能 - 查词** | ⭐⭐⭐ | DeepSeekApi 已经实现三阶段查询，但**播放器中未集成查词入口** |
| **学习记录** | ⭐⭐⭐ | StudyRecord 模型存在，但**播放器中未接入学习统计** |
| **设置持久化** | ⭐⭐⭐⭐ | SettingsService 配置体系完整，播放速度/字幕显隐/翻译等持久化 |
| **UI 细节** | ⭐⭐⭐⭐ | 控制栏自动隐藏/速度浮层/设置抽屉/视频列表/翻译显隐 都完整 |
| **iOS 原生能力** | ⭐⭐⭐ | OCR/TTS/翻译 channel 已定义，但**部分标记为未实现** |
| **国际化** | ⭐ | UI 全是中文，面向全球市场需全面英化 |

**综合评分：视频播放核心（播放+字幕）≈ 85分，学习闭环（跟读+查词+测试+记录）≈ 30分**

---

## 三、核心问题清单

### P0 - 阻塞性问题（必须修）

| # | 问题 | 描述 |
|---|------|------|
| 1 | **录音功能缺失** | Dub 面板 `_startRecording` 和 `_playUserRecording` 都是 `TDMessage.showMessage` 占位，未实现真正的录音→播放→评分循环 |
| 2 | **查词入口未接入播放页** | DeepSeekApi 已实现（三阶段查询+流式返回），但播放页中没有"点击字幕单词弹出释义卡片"的功能 |
| 3 | **测试功能完全缺失** | 视频学习的核心闭环中，"学习完内容后进行测试"这个环节是空的 |
| 4 | **学习记录未写入** | `StudyRecord` 模型存在、`DatabaseService` 支持完整 CRUD，但 PlayerEngineNotifier 中从未调用 `StudyRecord.save()` |

### P1 - 重要改进

| # | 问题 | 描述 |
|---|------|------|
| 5 | **UI 语言全中文** | PlayerPage 所有按钮中文（由慢到快/翻译/字幕/单句暂停/复读），面向全球市场需改为英文 |
| 6 | **控制栏自动隐藏缺失** | `_restartAutoHide()` 被注释为"不再自动隐藏控制栏"，但视频播放器没有自动隐藏很影响沉浸体验 |
| 7 | **缺少字幕点击交互** | 字幕文字不可点击，无法选择/复制/查询单词 |
| 8 | **速度选择用户体验普通** | 弹出竖排列表，点击后消失；更好的设计是横排滑动选择器 |
| 9 | **播放页面没有单词本入口** | 用户收集的单词在播放页内无法快速查看 |
| 10 | **iOS 原生录音 channel 未实现** | 原生侧需要实现 `startRecording` / `stopRecording` / `playRecording` 方法 |

### P2 - 增强优化

| # | 问题 | 描述 |
|---|------|------|
| 11 | **缺少手势操作** | 双击暂停/播放、长按倍速等常见视频手势缺失 |
| 12 | **字幕行数配置** | 字幕只能显示一行，无多行/字号配置 |
| 13 | **缺少后台音频播放** | 锁屏后视频暂停，无法后台播音频（类似 YouTube Premium 或 Apple Podcast） |
| 14 | **进度同步** | 学习进度只在本地 sqlite，没有云同步（supabase 尚未接入） |
| 15 | **Crash 恢复** | 播放中断后无恢复逻辑 |

---

## 四、OmniPlayer 评估

### 4.1 优势
- **跨平台统一 API**：iOS/Android 共用 MethodChannel + EventChannel
- **LRU 缓存**：CacheManager 实现完整，支持后台静默下载
- **seek 同步逻辑**：`_applySeekPositionSync` 处理了 seek 后进度回跳的边界情况
- **dispose 安全**：`_activeDisposeFuture` 防止并发 dispose/reinit 导致的 iOS 黑屏

### 4.2 不足
- **音频播放能力未使用**：`MediaItem` 已有 `isVideo` 字段，支持纯音频，但未被利用（后续文章/歌曲需要）
- **无 HLS 兼容说明**：`_isCacheable` 方法排除了 `.m3u8`，说明预期不处理流媒体
- **无音量控制暴露**：播放器无音量滑块

---

## 五、PlayerEngineNotifier 评估

### 5.1 优势
- 渐进式状态管理（copyWith 模式）
- 二分查找字幕索引效率高
- 单句暂停 / 由慢到快 逻辑完整
- 文件夹视频列表预加载
- SkipOpening/SkipEnding 支持完好

### 5.2 不足

```dart
// 缺失的关键功能：

// ❌ 无录音处理
void _startRecording(...) {
  TDMessage.showMessage(...); // 占位
}

// ❌ 无测试入口
// 完全缺少 test/quiz 相关方法

// ❌ 无学习记录
// updateStudyRecord() 不存在

// ❌ 无云同步
// supabase 未接入

// ❌ 无手势处理
// 双击/滑动 未挂载
```

---

## 六、改进路线图

### 第一阶段（核心闭环补全，2-3周）

| 优先级 | 任务 | 依赖 |
|--------|------|------|
| P0 | **接入录音功能**：iOS 原生录音 channel 实现 + Dart 层录制/回放流程 | OmniPlayer 音频能力 |
| P0 | **集成单词查询**：点击字幕单词 → DeepSeekApi 查询 → 浮层展示 | DeepSeekApi 已就绪 |
| P0 | **实现测试功能**：选择题/填空/听写三种模式（优先基于字幕内容） | 需设计 TestPage 内容 |
| P0 | **接入学习记录**：播放结束时写入 StudyRecord | StudyRecord 模型已就绪 |
| P1 | **UI 英文化**：PlayerPage 所有按钮/提示改为英文 | - |
| P1 | **恢复控制栏自动隐藏**：5秒无操作自动隐藏 | - |

### 第二阶段（体验打磨，1-2周）

| 优先级 | 任务 |
|--------|------|
| P1 | 字幕点击交互：选中后可查词/复制/收藏 |
| P1 | 双击暂停/播放手势 |
| P1 | 速度选择 UI 优化（横向滑杆） |
| P2 | 字幕字号/行数配置 |

### 第三阶段（面向全球市场，2-3周）

| 优先级 | 任务 |
|--------|------|
| P2 | Supabase 用户系统接入（替代当前本地 user） |
| P2 | 学习进度云同步 |
| P2 | 后台音频播放（锁屏后继续播音频） |
| P2 | 单词本独立页面（跨视频收藏的单词） |
| P1 | 国际化/本地化（i18n） |

---

## 七、修改建议（具体代码层面）

### 7.1 PlayerEngineNotifier 新增方法

```dart
// 需要新增的核心方法：

/// 点击字幕中的单词查询
Future<void> lookupWord(String word, String sentence) async {
  // 调用 DeepSeekApi.translateWord() 或 translateWordStream()
  // 结果通过 State 或 callback 传递给 UI
}

/// 开始录音
Future<void> startRecording() async {
  // MethodChannel 调用原生录音
  // 记录录音文件路径
}

/// 停止录音
Future<String?> stopRecording() async {
  // 停止录音，返回文件路径
}

/// 播放录音
Future<void> playRecording(String filePath) async {
  // 播放录音文件
}

/// 保存学习记录
Future<void> saveStudyRecord() async {
  final record = StudyRecord(
    videoCode: widget.videoCode,
    date: DateTime.now(),
    startTime: _sessionStartTime,
    endTime: DateTime.now(),
    duration: ...,
  );
  await record.save();
}

/// 进入测试模式
void enterTestMode() {
  // 导航到测试页面，传入当前视频的字幕列表
}

/// 收藏单词
Future<void> saveWord(String word, String sentence, String videoCode) async {
  // 存入 WordBook 表
}
```

### 7.2 PlayerPage 需新增的 UI

```dart
// 字幕点击交互
Widget _buildInteractiveSubtitle(Subtitle subtitle) {
  // 将字幕文字拆分为单词
  // 每个单词可点击 → lookupWord()
  // 选中的单词高亮
}

// 测试入口按钮（底部控制栏新增）
Widget _testButton() {
  // "Quiz" 按钮
  // 点击进入测试模式
}

// 单词本入口（顶部栏新增）
Widget _wordBookButton() {
  // 跳转至单词本页面
}
```

### 7.3 新增测试页面设计思路

不重新设计复杂测试系统，先做 **2 种最简单的题型**：

```
1. Fill-in-the-blank（完形填空）
   - 从当前字幕句子中随机删除 1 个词
   - 用户输入/选择答案
   - 自动比对

2. Multiple Choice（选择题）
   - 随机选一句字幕作为题干
   - 删除一个关键词
   - 提供 4 个选项（1 正确 + 3 干扰）
```

测试引擎复用逻辑：
- 数据源 = 当前视频的 `List<Subtitles>`
- 题目生成规则 = 固定算法（不需要 AI）
- 评分 = 简单字符串比对
- Phase 2 可接 DeepSeek 生成更复杂题型

---

## 八、总结：当前阶段的核心建议

**你现在的 VidLang 像一辆引擎已经点火、底盘扎实的车，但缺少了"方向盘+仪表盘"——方向盘是查词和跟读交互，仪表盘是测试和学习记录。**

### 站在整体架构视角，我现在最推荐的开发顺序：

```
当前状态：播放 ✅ | 字幕 ✅ | 跟读(UI) ✅ | 查词(API) ✅ | 测试 ❌ | 学习记录 ❌
            |           |              |              |
            v           v              v              v
Phase 1:  录音功能    查词集成      实现测试      写入学习记录
          (1周)       (3天)         (1周)         (2天)
            
            ↓           ↓              ↓              ↓
Phase 2:  完成视频学习的核心闭环 → 用户可以在一段视频内完整经历
          "看→学→查→练→测→记录" 的全流程
          
            ↓
Phase 3:  UI英文化 + 体验优化 → 准备国际市场发布

            ↓
Phase 4:  Article + Song 功能 → 复用 Phase1-2 的学习引擎
```

### 最后的核心判断

VidLang 的视频播放模块**底子非常好**——OmniPlayer 自研、字幕引擎精确、状态管理清晰。你现在聚焦在"把视频导入和播放做完善"是对的。但建议在继续加功能之前，先把 **视频学习的完整闭环** 走通（查词+跟读录音+测试+学习记录），这样才能验证核心价值。

**一个用户能完整地：导入视频 → 看视频学对话 → 点击生词查释义 → 跟读录音回放 → 做完形填空测试 → 看到学习记录 → 单词加入复习本**，到这一步你才真正有了一个有竞争力的英语学习产品，而不仅仅是一个"带字幕的视频播放器"。
