# VidLang 整体架构与产品设计

> 版本：v2.0  
> 更新日期：2026-06-04  
> 设计范围：视频学习 + 文章学习 + 歌曲学习 三引擎统一架构  
> 目标市场：全球英语学习者（App Store + Google Play）  
> 后台服务：Supabase + Stripe/RevenueCat

---

## 一、产品定位

### 1.1 一句话定义

> **VidLang — Learn English through videos, articles & songs. All in one place.**

通过视频、文章、歌曲三种媒介，让英语学习融入日常生活。

### 1.2 目标用户

| 用户画像 | 需求 | 使用场景 |
|----------|------|----------|
| 雅思/托福备考者 | 视频练听力+口语，文章练阅读 | 看 TED/纪录片，读外刊 |
| 美剧/电影爱好者 | 通过追剧学地道表达 | 看无字幕/英文字幕视频 |
| 英语歌曲爱好者 | 通过歌词学英语+跟唱 | 听英文歌，跟唱评分 |
| 日常英语学习者 | 碎片时间学习 | 通勤时读文章/听歌 |

### 1.3 核心价值

1. **一个 app 覆盖三种学习场景** — 视频、文章、歌曲，学习数据互通
2. **自由导入内容** — 不依赖平台内容库，用户想学什么自己决定
3. **完整学习闭环** — 看/读 → 查词 → 跟读/跟唱 → 测试 → 记录
4. **免费+付费双层模型** — 免费层用 iOS 原生能力获客，付费层用 AI 评分变现

---

## 二、三引擎架构

### 2.1 核心抽象

VidLang 的体系可以用一句话概括：

> **一个 Content（内容），按 Type（类型）渲染不同的 Player（播放器），共享同一个 Learning Engine（学习引擎）。**

```
                    ┌──────────────────────────────────┐
                    │        Content Layer              │
                    │   (统一的"内容+片段"数据模型)      │
                    └──────────────┬───────────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          ▼                        ▼                        ▼
   ┌──────────────┐       ┌──────────────┐        ┌──────────────┐
   │ VideoPlayer  │       │   Reader     │        │  SongPlayer  │
   │ (OmniPlayer) │       │ (TTS/Audio)  │        │  (Audio +    │
   │ 视频渲染     │       │ 文字渲染     │        │  歌词渲染)   │
   └──────┬───────┘       └──────┬───────┘        └──────┬───────┘
          │                      │                        │
          └──────────────────────┼────────────────────────┘
                                 ▼
                    ┌─────────────────────────────────────┐
                    │       Shared Learning Engine         │
                    ├─────────────────────────────────────┤
                    │  WordLookup (DeepSeek API)          │
                    │  Recording + Playback               │
                    │  Scoring (Pronunciation / Music)    │
                    │  TestEngine (Fill/Listen/Quiz)       │
                    │  WordBook (跨来源单词本)             │
                    │  StudyRecord (学习统计)              │
                    └─────────────────────────────────────┘
```

### 2.2 内容 & 片段（统一数据模型）

```dart
/// 内容接口 — 视频/文章/歌曲 都实现此接口
abstract class ContentEntity {
  String? code;
  String title;
  ContentType type;
  List<SegmentEntity> segments; // 片段列表
  int wordCount;
  double progress;
  DateTime? lastStudiedAt;
}

/// 片段接口 — 字幕/句子/歌词 都实现此接口
abstract class SegmentEntity {
  String content;
  String? translation;
  int startPositionMs;  // 时间轴开始（毫秒）
  int endPositionMs;    // 时间轴结束（毫秒）
  int index;            // 序号
  int wordCount;
}

enum ContentType { video, article, song }
```

### 2.3 三引擎对比

| 维度 | Video | Article | Song |
|------|-------|---------|------|
| **内容源** | 本地视频文件 | 粘贴文本/OCR | 本地音频/YouTube |
| **片段** | Subtitle(start/end) | Sentence(start/end) | LyricLine(start/end) |
| **播放器** | OmniPlayer（视频画面） | just_audio/TTS（纯文字） | just_audio（歌词+封面） |
| **渲染层** | 视频画面 + 字幕 | 句子高亮 + 背景 | 歌词高亮 + 封面/背景 |
| **听** | 听视频原声 | iOS TTS / 音频 | 听原唱 |
| **跟** | 跟读 → 发音评分 | 跟读 → 发音评分 | 跟唱 → 音乐评分 |
| **查词** | 点字幕单词 | 点句子单词 | 点歌词单词 |
| **测试** | 填空/听写/选择 | 填空/听写/选择 | 填空/听写/选择 |
| **单词本** | 统一 WordBook | 统一 WordBook | 统一 WordBook |
| **学习记录** | 统一 StudyRecord | 统一 StudyRecord | 统一 StudyRecord |

---

## 三、首页设计

### 3.1 底部导航

```
┌─────────────────────────────────────────────────┐
│                                                   │
│    Learn     Words     Discover     Profile       │
│                                                   │
└─────────────────────────────────────────────────┘
```

| Tab | 说明 |
|-----|------|
| **Learn** | 首页核心——继续学习 + 快速导入 |
| **Words** | 单词本——所有收藏的单词（间隔复习） |
| **Discover** | 发现内容（待后续扩展：社区/推荐/热榜） |
| **Profile** | 设置/统计/付费/帮助 |

### 3.2 Learn Tab 布局

```
┌──────────────────────────────────────────────┐
│  VidLang                  🔥 5-day streak    │ ← 品牌 + 动力
├──────────────────────────────────────────────┤
│                                              │
│  Today's Stats                               │ ← 今日概览
│  🎬 12min  📖 8min  🎵 5min  📝 Quiz 85%   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │  Continue Learning                   │   │ ← 继续学习区
│  │                                      │   │
│  │  🎬 Friends S01E01        ████░░ 45% │   │
│  │  📖 Climate Change...     ██░░░░ 20% │   │
│  │  🎵 Let It Be            ██████ 60% │   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │  Quick Import                        │   │ ← 快速导入
│  │  [🎬 Video]  [📖 Article]  [🎵 Song]│   │
│  └──────────────────────────────────────┘   │
│                                              │
│  ┌──────────────────────────────────────┐   │
│  │  Recent Activity                     │   │ ← 学习动态
│  │  ✓ 3:00pm  Finished "Greetings"     │   │
│  │  ☆ 2:30pm  Saved "profound"        │   │
│  │  ✓ 2:00pm  Quiz score: 85%         │   │
│  └──────────────────────────────────────┘   │
│                                              │
├──────────────────────────────────────────────┤
│  Learn │ Words │ Discover │ Profile          │
└──────────────────────────────────────────────┘
```

### 3.3 各 Tab 简要说明

**Words Tab**：
- 所有跨来源收藏的单词（来源标签：视频/文章/歌曲）
- 间隔复习模式（Swipable cards — 单词 → 回想 → 翻转看释义）
- 按掌握程度筛选（待复习 / 学习中 / 已掌握）

**Discover Tab**（后续扩展）：
- 热门内容推荐
- 学习排行榜
- 社区分享的内容

**Profile Tab**：
- 学习统计（今日/本周/本月学习时长）
- 付费管理（免费配额 / 订阅计划）
- 设置（播放偏好/语言/通知）
- 帮助与反馈

---

## 四、信息架构

### 4.1 完整页面结构

```
App 入口
├── Login / Register (Supabase Auth)
│   ├── Apple Sign-In
│   ├── Google Sign-In
│   └── Email + Password
│
├── MainPage (Tab Navigation)
│   ├── Learn Tab (首页)
│   │   ├── ContentContinueCard → PlayerPage / ReaderPage / SongPage
│   │   ├── QuickImport → ImportSheet
│   │   │   ├── Import Video → FilePicker
│   │   │   ├── Paste Article → ArticleCreatePage
│   │   │   └── Add Song → SongImportPage
│   │   └── RecentActivity → ActivityList
│   │
│   ├── Words Tab
│   │   ├── WordBookPage (全部单词)
│   │   ├── ReviewSession (间隔复习)
│   │   └── WordDetailCard (DeepSeek 查询结果)
│   │
│   ├── Discover Tab (后续)
│   │
│   └── Profile Tab
│       ├── Stats (学习统计)
│       ├── Subscription (付费管理)
│       ├── Settings
│       └── Help & Feedback
│
├── PlayerPage (视频播放器)
│   ├── VideoWidget (画面)
│   ├── SubtitleDisplay (可交互字幕)
│   ├── WordCard (点击单词浮层)
│   ├── DubPanel (跟读录音)
│   ├── SpeedSelector
│   ├── VideoListDrawer
│   ├── SettingsDrawer
│   └── → TestPage (视频测试)
│
├── ArticleReaderPage (文章阅读器)
│   ├── SentenceDisplay (可交互句子)
│   ├── WordCard
│   ├── DubPanel
│   ├── SpeedSelector
│   └── → TestPage (文章测试)
│
├── SongPlayerPage (歌曲播放器)
│   ├── LyricDisplay (可交互歌词)
│   ├── WordCard
│   ├── KaraokePanel (跟唱)
│   └── → TestPage (歌词测试)
│
└── TestPage (统一测试引擎)
    ├── FillInBlank (完形填空)
    ├── Dictation (听写)
    └── Quiz (选择题)
```

### 4.2 主线流程

```
用户打开 app
    ↓
[Learn Tab] 展示继续学习内容 + 快速导入
    ↓
选择导入视频 → FilePicker → 扫描文件夹 → 导入到虚拟视频集
    ↓
点击视频 → 进入 PlayerPage（横屏全屏）
    ↓
播放、暂停、字幕跟踪、单句暂停、由慢到快
    ↓                                                    ← 当前开发到这里
点击字幕单词 → WordCard 浮层（DeepSeek 查询）              ← Phase 1 补
点击跟读 → DubPanel → 录音 → 回放 → 评分                  ← Phase 1 补
点击 Quiz → TestPage → 填空/选择 → 计分                    ← Phase 1 补
收藏单词 → 存入 WordBook                                  ← Phase 1 补
退出播放 → 自动保存 StudyRecord                            ← Phase 1 补
    ↓
[Words Tab] 查看所有收藏单词，开始间隔复习
    ↓
[Profile Tab] 查看今日学习统计
```

---

## 五、技术栈总览

### 5.1 前端（Flutter）

| 领域 | 选用 | 说明 |
|------|------|------|
| 框架 | Flutter 3.x | - |
| 状态管理 | Riverpod | 现有选择，保持 |
| 数据库（本地） | sqflite | 现有选择，保持 |
| 视频播放 | OmniPlayer（自研） | 现有，iOS IJK + Android Texture |
| 音频播放 | just_audio | 新增，用于歌曲播放 |
| 屏幕适配 | flutter_screenutil | 现有，保持 |
| 组件库 | tdesign_flutter | 现有，保持 |
| 动画 | Lottie | 现有，保持 |

### 5.2 后端（Supabase）

| 功能 | Supabase 方案 |
|------|--------------|
| 用户认证 | `supabase-flutter` Auth（Apple/Google/Email） |
| 用户数据 | PostgreSQL（profiles, study_records, word_book 等） |
| 文件存储 | Supabase Storage（录音文件、封面、头像） |
| AI 能力 | Supabase Edge Functions（包装 DeepSeek API） |
| 实时同步 | Supabase Realtime（跨设备进度同步） |
| 付费 | RevenueCat（接入 App Store + Google Play） |

### 5.3 本地+云端数据策略

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

## 六、开发阶段规划

```
Phase 1 (当前)：视频闭环
├── 录音功能 → 跟读评分循环
├── 字幕查词集成 → WordCard
├── 基础测试 → 填空/选择
├── 学习记录写入
└── UI 英文化

Phase 2：文章阅读
├── Article + ArticleSentence 模型
├── 粘贴/OCR 导入
├── 分句 + 时间轴
├── TTS 朗读 + 跟读
└── 复用测试引擎

Phase 3：歌曲学习
├── Song + LyricLine 模型
├── 歌词导入 + 时间轴
├── 音频播放 + 歌词高亮
├── 声通音乐评分集成
└── 复用测试引擎

Phase 4：Supabase + 上架
├── 用户系统 + 云端同步
├── 付费系统（RevenueCat）
├── App Store / Google Play 上架
└── 国际化（英文默认 + 多语言）
```

---

## 七、核心设计原则

1. **Code Reuse > Code Rewrite** — 三引擎共享学习引擎，避免重复开发
2. **Offline First** — 本地 SQLite 为主，云端同步为异步优化
3. **Open Content** — 不依赖平台内容库，用户自由导入
4. **Freemium** — 免费层（iOS 原生能力）获客，付费层（AI + 评分）变现
5. **Global First** — 产品默认英文，多语言后续本地化
6. **Progressive Enhancement** — 核心闭环先走通（看→学→练→测→记），再优化体验
