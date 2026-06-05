# VidLang 详细设计 — 商业模式与数据策略

## 一、Freemium 双层模型

### 1.1 免费层（iOS/Android 原生能力）

| 功能 | 能力来源 | 是否限频 |
|------|---------|---------|
| 视频播放 + 字幕 | OmniPlayer（本地） | 不限 |
| TTS 朗读（系统引擎） | iOS AVSpeechSynthesizer / Android TTS | 不限 |
| OCR 文字识别 | iOS Vision / ML Kit | 不限 |
| 系统翻译 | iOS Translation / ML Kit | 不限 |
| 跟读录音 | 本地录音 | 不限 |
| 单词收藏 + 复习 | 本地存储 | 不限 |
| 测试（填空/听写） | 本地算法 | 不限 |

**免费层目的**：吸引流量，用户不付费也能体验完整学习流程

### 1.2 付费层（AI 计费）

| 功能 | 能力来源 | 计费模式 |
|------|---------|---------|
| DeepSeek 单词深度查询 | Supabase Edge → DeepSeek API | 按次 / 订阅 |
| DeepSeek 文章翻译 | Supabase Edge → DeepSeek API | 按字符 / 订阅 |
| 声通发音评分 | Supabase Edge → 声通 WebSocket | 按次 / 订阅 |
| AI 测试题生成 | Supabase Edge → DeepSeek API | 按次 / 订阅 |
| AI 智能分句 | Supabase Edge → DeepSeek API | 按字符 / 订阅 |
| 学习进度云同步 | Supabase | 订阅用户专属 |

### 1.3 付费方案

```
Free Plan:
├── 100 AI credits / month
├── Local sync only (no cloud)
└── 5 test questions per session

Premium ($4.99/month or $39.99/year):
├── 1000 AI credits / month
├── Cloud sync across devices
├── Unlimited test questions
├── AI-generated reading comprehension tests
├── Detailed pronunciation feedback
└── No ads

AI Credits Top-up:
├── 100 credits: $1.99
├── 500 credits: $7.99
└── 2000 credits: $24.99
```

AI Credits 消耗参考：

| 操作 | 消耗 Credits |
|------|------------|
| 查一个单词 | 1 |
| 翻译 100 字 | 1 |
| 一次发音评分 | 2 |
| 生成 10 道测试题 | 3 |
| AI 分句 + 时间轴 | 2 |

## 二、数据同步策略

### 2.1 架构

```
用户设备
├── 本地 SQLite（主存储）
│   ├── 所有学习数据
│   ├── 离线可用
│   └── 快速访问
└── 异步同步到 Supabase
    └── 仅 Premium 用户

Supabase
├── Profiles（用户资料）
├── Folders（文件夹）
├── Resources（视频/文章/歌曲信息）
├── Segments（字幕/句子/歌词）
├── WordBook（单词本）
├── StudyRecords（学习记录）
├── RecordingRecords（跟读记录）
└── AI Credits（AI 额度）
```

### 2.2 同步时机

```
用户操作 → 写本地 SQLite（即时）
    ↓
如果用户是 Premium 且在线：
    ↓ 延迟 3 秒（防抖动）
    ↓
异步同步到 Supabase
    ↓
其他设备登录时：
    ↓ 全量拉取（首次登录）
    ↓ 增量同步（后续）
```

## 三、技术栈总结

### 3.1 前端

| 领域 | 选择 | 说明 |
|------|------|------|
| 框架 | Flutter 3.x | - |
| 状态管理 | Riverpod | 现有 |
| 本地数据库 | sqflite | 现有 |
| 视频播放 | OmniPlayer（自研） | 现有 |
| 音频播放 | just_audio | 新增 |
| Markdown 渲染 | flutter_markdown | 新增 |
| 屏幕适配 | flutter_screenutil | 现有 |
| 支付 | RevenueCat | 新增 |
| 云服务 | supabase_flutter | 新增 |

### 3.2 后端（Supabase）

| 服务 | 用途 |
|------|------|
| Auth | Apple/Google/Email 登录 |
| Database | PostgreSQL 存储用户数据 |
| Storage | 录音文件/封面/头像 |
| Edge Functions | DeepSeek API 代理/声通评分代理 |
| Realtime | 跨设备同步 |
| Row Level Security | 用户数据隔离 |

### 3.3 Edge Functions 示例

```typescript
// supabase/functions/evaluate-pronunciation/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const { audio, referenceText } = await req.json();
  // 调用声通评分 WebSocket
  const score = await shengtongEvaluate(audio, referenceText);
  return new Response(JSON.stringify(score), {
    headers: { "Content-Type": "application/json" },
  });
});
```

```typescript
// supabase/functions/deepseek-word/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const { word, sentence } = await req.json();
  // 扣除用户 AI Credits
  // 调用 DeepSeek API 查询单词
  const result = await deepseekQuery(word, sentence);
  return new Response(JSON.stringify(result), {
    headers: { "Content-Type": "application/json" },
  });
});
```
