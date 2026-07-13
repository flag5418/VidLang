# VidLang 架构总览

> **版本**: V1.0 | **日期**: 2026-07-13
> **状态**: 当前有效 | **来源**: 合并自 `overall-architecture.md` + `07-homepage-nav.md`

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

### 1.3 产品矩阵化战略

VidLang 采用产品矩阵化策略，底层技术 100% 可复用，换语言即换内容：

```
VidLang EN（中国人学英语，首发）
    ↓
VidLang CN（英国人学中文，第二款）
    ↓
VidLang KR（中国人学韩语，第三款）
    ↓
VidLang JP（日文版，后续扩展）
```

**可复用技术栈**：

| 技术组件 | 复用方式 |
|----------|---------|
| omni_player（视频播放内核） | 100% 复用，不区分语言 |
| 字幕解析引擎（SRT/VTT/LRC） | 100% 复用 |
| AI 服务（DeepSeek/Qwen） | 100% 复用，换 prompt 语言即可 |
| Supabase 计费体系 | 100% 复用 |

### 1.4 核心价值

1. **一个 app 覆盖三种学习场景** — 视频、文章、歌曲，学习数据互通
2. **自由导入内容** — 不依赖平台内容库，用户想学什么自己决定
3. **完整学习闭环** — 看/读 → 查词 → 跟读/跟唱 → 测试 → 记录
4. **预付费钱包模式** — 充多少用多少，余额永不过期，跨语言版本通用

---

## 二、三引擎架构

### 2.1 核心抽象

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

### 2.2 三引擎对比

| 维度 | Video | Article | Song |
|------|-------|---------|------|
| **内容源** | 本地视频文件 | 粘贴文本/OCR | 本地音频/YouTube |
| **片段** | Subtitle(start/end) | Sentence(start/end) | LyricLine(start/end) |
| **播放器** | OmniPlayer（视频画面） | just_audio/TTS（纯文字） | just_audio（歌词+封面） |
| **跟读/跟唱** | 跟读 → 发音评分 | 跟读 → 发音评分 | 跟唱 → 音乐评分 |
| **查词** | 点字幕单词 | 点句子单词 | 点歌词单词 |
| **单词本** | 统一 WordBook | 统一 WordBook | 统一 WordBook |

---

## 三、导航结构（当前实现）

### 3.1 底部导航栏

> ⚠️ **重要**: 以下为代码实际实现的 **4 Tab** 导航（`navigation_provider.dart` + `main_page.dart`）

```
┌───────────────────────────────────────────────────────┐
│                                                         │
│   🏠 Home     📁 Files     📚 Words     👤 Profile     │
│                                                         │
└───────────────────────────────────────────────────────┘
```

| Tab | 对应页面 | 说明 |
|-----|----------|------|
| **🏠 Home** | `home_page.dart` | 首页——继续学习 + 今日统计 + 快速导入 |
| **📁 Files** | `file_list_page.dart` | 文件列表——导入/管理视频文件夹 |
| **📚 Words** | `collection_page.dart` | 单词本（收藏本）——所有收藏的单词 |
| **👤 Profile** | `profile_page.dart` | 个人中心——统计/设置/付费/充值 |

### 3.2 iPad 侧边栏导航

iPad 设备使用侧边栏（Sidebar）替代底部 Tab，包含相同的 4 个入口。

### 3.3 完整页面结构

```
App 入口
├── Login / Register (Supabase Auth)
│   ├── Apple Sign-In
│   ├── Google Sign-In
│   └── Email + Password
│
├── MainPage (Tab Navigation)
│   ├── Home Tab (首页)
│   │   ├── Continue Learning → PlayerPage / ReaderPage / SongPage
│   │   ├── Quick Import → ImportSheet
│   │   └── Recent Activity
│   │
│   ├── Files Tab
│   │   ├── Folder List → FolderDetailPage
│   │   └── Video List → PlayerPage
│   │
│   ├── Words Tab
│   │   ├── WordBookPage (全部单词)
│   │   ├── ReviewSession (间隔复习)
│   │   └── WordDetailCard
│   │
│   └── Profile Tab
│       ├── Stats (学习统计)
│       ├── Subscription (付费管理)
│       └── Settings
│
├── PlayerPage (视频播放器)
├── ArticleReaderPage (文章阅读器 - ShadowReader)
├── SongPlayerPage (歌曲播放器 - AudioPlayer)
└── TestPage (统一测试引擎)
```

---

## 四、技术栈

### 4.1 前端（Flutter）

| 领域 | 选用 | 说明 |
|------|------|------|
| 框架 | Flutter 3.13+ (SDK ^3.13.0) | - |
| 状态管理 | flutter_riverpod (StateNotifierProvider.autoDispose) | - |
| 数据库（本地） | SQLite (sqflite) + FTS5 全文检索 | 20 个已注册实体 |
| 视频播放 | OmniPlayer（自研） | iOS AVPlayer + Android ExoPlayer |
| 音频播放 | just_audio | 歌曲/跟读/TTS |
| 屏幕适配 | flutter_screenutil | 设计稿 375×812 |
| 组件库 | tdesign_flutter（自研修改版） | 统一UI风格 |
| 本地AI | ONNX Runtime (sherpa-onnx) | 本地TTS/STT/翻译 |

### 4.2 后端（Supabase）

| 功能 | Supabase 方案 |
|------|--------------|
| 用户认证 | supabase-flutter Auth（Apple/Google/Email） |
| 云端数据 | PostgreSQL（profiles, study_records 等） |
| 文件存储 | Supabase Storage（录音文件、封面、头像） |
| AI 能力 | 多通道架构（Edge Function + WebSocket 直连） | 见 §4.4 详细说明 |
| 实时通信 | Supabase Realtime（排他性登录检测）+ Qwen WebSocket（AI 对话） | |
| 付费 | 自研预付费钱包系统 |

### 4.3 数据存储策略

> 核心学习数据存放在**本地 SQLite**，为支持 AI 分析将必要数据上传至 Supabase 云端。

| 数据类型 | 存储位置 | 说明 |
|----------|---------|------|
| 学习记录（study_record） | 本地 SQLite | 离线可用，核心数据不依赖网络 |
| 录音/评分记录 | 本地 SQLite + Supabase Storage | 本地保留原始录音，云端用于 AI 深度分析 |
| 用户配置/设置 | 本地 config 表 | 多用户隔离，按 user_code 存储 |
| 计费/钱包 | Supabase PostgreSQL | 充值、扣费、余额必须云端一致 |
| 论坛/社交 | Supabase PostgreSQL + Edge Functions | 纯云端功能 |
| AI 对话记录 | Supabase conversation_session | 云端存储，跨设备可查看历史 |

### 4.4 AI 服务调用架构

> AI 调用根据场景选择不同通道，**非统一走 Edge Function**。

| 场景 | 通道 | 说明 |
|------|------|------|
| 查词释义（ai_definition） | **Edge Function** (`ai-proxy`) | 统一计费 + 缓存 |
| AI 翻译（ai_translate） | **Edge Function** (`ai-proxy`) / iOS 系统翻译 | 免费走本地，付费走云端 |
| TTS 语音合成 | **DashScope WebSocket 直连** | 流式合成，首包延迟低，本地缓存 |
| STT 发音评分 | **Edge Function** (`ai-proxy` → 声通) | 上传音频 base64，返回评分 |
| AI 对话（conversation） | **Qwen Realtime WebSocket** | 全双工实时对话流 |
| AI 对话判分（ai_chat） | **Edge Function** (`ai-proxy`) | 批量判分 |

---

## 五、开发阶段规划

```
✅ Phase 1：视频闭环 — 已完成
├── ✅ OmniPlayer 视频播放器（缓存/Seek同步/倍速/AB循环）
├── ✅ 字幕解析（SRT/VTT/ASS）+ 显示 + 点击查词
├── ✅ 跟读录音 → 发音评分
├── ✅ 测试引擎（填空/听写/选择/AI评价）
├── ✅ 学习记录写入
└── ✅ AI翻译集成 + TTS朗读

✅ Phase 2：文章阅读 — 已完成
├── ✅ ShadowReader 阅读器（句子高亮/跟读/TTS）
└── ✅ 复用测试引擎 + 学习记录

✅ Phase 3：歌曲学习 — 已完成
├── ✅ LRC歌词解析 + AudioPlayerPage
├── ✅ 跟唱评分
└── ✅ 复用测试引擎

✅ Phase 4：用户系统 + 计费 — 已完成
├── ✅ Supabase Auth + 自研计费系统
└── ✅ BillingService + GlobalErrorHandler

✅ Phase 5：社交与扩展 — 已完成核心功能
├── ✅ 论坛模块（11 张表，完整 CRUD）
├── ✅ AI 对话（Qwen Realtime WebSocket 全双工）
├── ✅ WiFi 传输（设备间资源直传）
├── ✅ 成长体系（学习统计/历史/等级）
├── ✅ 拍照翻译（OCR + AI 翻译）
└── 🚧 持续迭代中（体验优化/性能调优/新功能）
```

---

## 六、核心设计原则

1. **Code Reuse > Code Rewrite** — 三引擎共享学习引擎
2. **Offline First** — 本地 SQLite 为主，云端同步为异步优化
3. **Open Content** — 不依赖平台内容库，用户自由导入
4. **Freemium** — 免费层获客，付费层（AI + 评分）变现
5. **Progressive Enhancement** — 核心闭环先走通，再优化体验
