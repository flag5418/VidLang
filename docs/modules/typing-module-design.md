---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 9a16bac6e27d25132787d930f50d9879_69fba53a871611f18766525400f8a581
    ReservedCode1: ROaEzst3XACAHCY/5tezPp2x11MKvmVBQLRXjoupmNiZObhZAoUY/eyUAAEr4CEFtrKavLpWkUa2pbi5ZblaXejxImJl1baokL4+dqhM//NWq6Hd0AMFLJ+ZeTDWDkd/Kx9HSs5UjiEETPtYu+VK73o0TBS4dgQN8R03SAa7+lDBppWK2Qaizew4paw=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 9a16bac6e27d25132787d930f50d9879_69fba53a871611f18766525400f8a581
    ReservedCode2: ROaEzst3XACAHCY/5tezPp2x11MKvmVBQLRXjoupmNiZObhZAoUY/eyUAAEr4CEFtrKavLpWkUa2pbi5ZblaXejxImJl1baokL4+dqhM//NWq6Hd0AMFLJ+ZeTDWDkd/Kx9HSs5UjiEETPtYu+VK73o0TBS4dgQN8R03SAa7+lDBppWK2Qaizew4paw=
---

# VidLang 打字模块总体设计

> **版本**: V1.0 | **日期**: 2026-07-24
> **状态**: 设计中（Phase 6） | **定位**: 免费引流模块，不参与计费

---

## 一、模块定位

### 1.1 一句话定义

> **通过打字，将三引擎（视频/文章/歌曲）的学习内容转化为肌肉记忆，打通手机→平板→电脑三端学习闭环。**

### 1.2 战略定位

| 维度 | 说明 |
|------|------|
| **商业定位** | 全免费，作为引流入口。降低新用户使用门槛，以差异化功能吸引竞品用户 |
| **学习定位** | 第五学习维度（听说读→听说读写打），多感官编码强化记忆 |
| **平台定位** | 电脑端 Web 为核心体验场景，手机/平板为辅（查看统计、选择素材） |
| **内容定位** | 复用三引擎素材，不做独立内容库 |

### 1.3 与现有模块的关系

```
三引擎（视频/文章/歌曲）
    │
    ├── 学习引擎（查词/翻译/跟读/评测）← 共用
    │
    └── 资源管理（folder/subtitle/paragraph/lyric）← 共用素材
            │
            ▼
        打字模块（新增）
            │
            ├── 素材选择（从已有资源中选打字内容）
            ├── 打字训练（Web 端执行）
            ├── 辅助工具（查词/原音/跟读/视频播放）
            └── 统计分析（Web HTML 页面）
```

---

## 二、总体架构

### 2.1 架构图

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter App（客户端）                    │
│                                                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────┐ │
│  │ 素材选择页  │  │ 打字入口页  │  │ WebView 容器       │ │
│  │ (Flutter)  │  │ (Flutter)  │  │ (加载打字Web页面)   │ │
│  └─────┬──────┘  └─────┬──────┘  └────────┬───────────┘ │
│        │               │                  │              │
└────────┼───────────────┼──────────────────┼──────────────┘
         │               │                  │
         ▼               ▼                  ▼
┌──────────────────────────────────────────────────────────┐
│              Supabase Edge Functions                       │
│                                                          │
│  ┌────────────────┐  ┌──────────────────────────────────┐│
│  │ typing-content  │  │ typing-stats                     ││
│  │ 获取打字素材     │  │ 统计存储与查询                    ││
│  │ (字幕/段落/歌词) │  │ (WPM/准确率/错误热力/历史趋势)     ││
│  └────────────────┘  └──────────────────────────────────┘│
│                                                          │
│  ┌──────────────────────────────────────────────────────┐│
│  │ typing-web (新增)                                     ││
│  │ 渲染打字 Web 页面（HTML+CSS+JS）                       ││
│  │ - 打字界面 / 统计仪表盘 / 设置                          ││
│  └──────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────┐
│                    复用现有服务                             │
│                                                          │
│  ai-proxy (查词/翻译)  │  DashScope TTS (原音播放)         │
│  声通 STT (跟读评分)   │  Supabase Storage (字幕数据)      │
└──────────────────────────────────────────────────────────┘
```

### 2.2 新增 Edge Functions

| Edge Function | 路由 | 功能 |
|---------------|------|------|
| `typing-content` | POST `/functions/v1/typing-content` | 获取打字素材（从 Storage 读取字幕/段落/歌词） |
| `typing-stats` | POST `/functions/v1/typing-stats` | 打字统计 CRUD（写入 session 数据，查询历史） |
| `typing-web` | GET `/functions/v1/typing-web` | 渲染打字 Web 页面（HTML 直出） |

### 2.3 新增云端表

```sql
-- 打字训练会话
CREATE TABLE typing_sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES auth.users NOT NULL,
    source_type VARCHAR(10) NOT NULL,  -- 'video' | 'article' | 'song'
    source_code VARCHAR(100) NOT NULL, -- video_code / article_code / song_code
    source_title VARCHAR(500),
    folder_code VARCHAR(100),
    folder_title VARCHAR(500),
    
    -- 统计指标
    total_chars       INT NOT NULL DEFAULT 0,  -- 素材总字符数
    typed_chars       INT NOT NULL DEFAULT 0,  -- 实际输入字符数
    correct_chars     INT NOT NULL DEFAULT 0,  -- 正确字符数
    error_chars       INT NOT NULL DEFAULT 0,  -- 错误字符数
    wpm               DECIMAL(6,1),            -- 字/分钟
    accuracy          DECIMAL(5,2),            -- 准确率 %
    duration_seconds  INT NOT NULL DEFAULT 0,  -- 训练时长（秒）
    
    -- 错误详情
    error_details     JSONB,  -- [{char, expected, typed, position}]
    
    -- 模式
    typing_mode       VARCHAR(20) NOT NULL DEFAULT 'full', -- 'full' | 'fill' | 'dictation'
    
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX idx_typing_sessions_user ON typing_sessions(user_id, created_at DESC);
CREATE INDEX idx_typing_sessions_source ON typing_sessions(source_type, source_code);

-- RLS
ALTER TABLE typing_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can CRUD own sessions" ON typing_sessions
    FOR ALL USING (auth.uid() = user_id);
```

---

## 三、功能模块划分

### 3.1 功能总览

```
打字模块
├── 1. 素材选择
│   ├── 1.1 从视频字幕选择
│   ├── 1.2 从文章段落选择
│   ├── 1.3 从歌曲歌词选择
│   └── 1.4 打字模式选择（全文本 / 填空 / 听写）
│
├── 2. 打字训练（Web 核心）
│   ├── 2.1 内容展示区
│   ├── 2.2 实时输入区
│   ├── 2.3 即时反馈（正确/错误高亮）
│   ├── 2.4 实时速度/准确率指示器
│   └── 2.5 训练控制（暂停/继续/重来/结束）
│
├── 3. 辅助工具（打字中可用）
│   ├── 3.1 查词（点击 → ai-proxy 释义弹窗）
│   ├── 3.2 播放原音（TTS 朗读当前句/全文）
│   ├── 3.3 跟读评分（录音 → 声通评分）
│   └── 3.4 视频播放器（视频字幕打字时嵌入小窗）
│
├── 4. 统计分析（Web HTML 页面）
│   ├── 4.1 会话级统计（本次训练报告）
│   ├── 4.2 历史趋势（WPM/准确率 日/周/月趋势图）
│   ├── 4.3 按素材统计（每个视频/文章/歌曲的打字数据）
│   └── 4.4 错误热力图（高频错误字符/单词排行）
│
└── 5. Flutter 入口
    ├── 5.1 打字入口页（从文件列表/播放器/阅读器进入）
    └── 5.2 WebView 容器（加载 typing-web，JS Bridge 通信）
```

### 3.2 模块详细说明

#### 模块 1：素材选择

| 子模块 | 入口 | 说明 |
|--------|------|------|
| 1.1 视频字幕 | 文件列表 → 视频 → "打字训练" | 选整个视频字幕，或选指定时间段字幕 |
| 1.2 文章段落 | 文章阅读器 → "打字训练" | 选全文或指定段落 |
| 1.3 歌曲歌词 | 歌曲播放器 → "打字训练" | 选全部歌词 |
| 1.4 模式选择 | 选好素材后弹出 | 全文本 / 填空 / 听写，三种模式切换 |

**打字模式定义**：

| 模式 | 显示内容 | 用户操作 | 适用场景 |
|------|---------|---------|---------|
| **全文本** (full) | 完整原文展示在上方 | 逐字输入，实时比对 | 综合训练，练速度+拼写 |
| **填空** (fill) | 关键单词挖空（占全文 15-30%） | 输入挖空词，Tab 跳下一个 | 词汇强化，练拼写 |
| **听写** (dictation) | 不展示原文，仅播放音频 | 听音输入整句，提交后显示原文对比 | 听力+拼写，高级训练 |

#### 模块 2：打字训练（Web 核心）

打字 Web 页面布局：

```
┌─────────────────────────────────────────────────────────┐
│  [←返回]  打字训练 · 《TED: The Power of Believing》      │
│  ┌─────────────────────────────────────────────────────┐│
│  │                                                     ││
│  │   原文展示区（只读，灰色已打完，高亮当前行）           ││
│  │   The quick brown fox jumps over the lazy dog.      ││
│  │   → Pack my box with five dozen liquor jugs. ←      ││
│  │   How vexingly quick daft zebras jump!              ││
│  │                                                     ││
│  └─────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────┐│
│  │   输入区（焦点在此，实时比对）                         ││
│  │   Pack my box █                                      ││
│  └─────────────────────────────────────────────────────┘│
│                                                         │
│  WPM: 42  │  准确率: 96.3%  │  进度: 3/15 句             │
│                                                         │
│  [🔍查词] [🔊原音] [🎤跟读] [📺视频] [⏸暂停] [🔄重来]    │
└─────────────────────────────────────────────────────────┘
```

**键盘交互规范**：
- `Enter`：提交当前句，跳到下一句
- `Tab`：填空模式跳到下一个空
- `Esc`：暂停训练
- `Backspace`：删除，回退到上一个错误位置
- 错误字符以红色闪烁 0.3s 后恢复，正确字符变灰

#### 模块 3：辅助工具

| 工具 | 触发方式 | 实现方式 |
|------|---------|---------|
| **查词** | 双击/长按原文中单词 | JS → JS Bridge → Flutter → ai-proxy → 弹窗显示释义 |
| **播放原音** | 点击 🔊 按钮 | Flutter TTS（DashScope/iOS原生）朗读当前句子 |
| **跟读评分** | 点击 🎤 按钮 | Flutter 录音 → 声通评分 → 弹窗显示分数 |
| **视频播放** | 视频素材时显示 📺 按钮 | 小窗嵌入 OmniPlayer，可拖动、最小化 |

> 辅助工具走 Flutter 原生能力，Web 页面通过 JS Bridge 触发，不在 Web 内实现。

#### 模块 4：统计分析（全在 Web HTML 页面内）

**页面结构**：

```
统计仪表盘
├── 概览卡片
│   ├── 总训练次数
│   ├── 累计打字时长
│   ├── 平均 WPM
│   ├── 平均准确率
│   └── 总字符数
│
├── 趋势图（日/周/月切换）
│   ├── WPM 折线图
│   └── 准确率折线图
│
├── 按素材统计
│   ├── 素材列表（标题 + WPM + 准确率 + 训练次数）
│   └── 点击进入单素材详情
│
└── 错误分析
    ├── 高频错误词 TOP 20
    └── 高频错误字符 TOP 10
```

#### 模块 5：Flutter 入口

| 入口位置 | 触发条件 | 说明 |
|---------|---------|------|
| 文件列表 → 视频长按菜单 | 选"打字训练" | 带 video_code 进入 |
| 文章阅读器工具栏 | 点击 ⌨️ 图标 | 带 article_code 进入 |
| 歌曲播放器工具栏 | 点击 ⌨️ 图标 | 带 song_code 进入 |
| 底部导航 | 新增"打字"Tab？（可选） | 直接进入打字首页，选素材 |

**Flutter → WebView 通信协议**：

```dart
// Flutter 向 WebView 注入初始数据
webViewController.runJavaScript('''
  window.__typingConfig = {
    sourceType: "video",
    sourceCode: "v001",
    folderCode: "f001",
    typingMode: "full",
    jwt: "$jwt",
    apiBase: "https://xxx.supabase.co/functions/v1"
  };
  window.dispatchEvent(new Event('typing:ready'));
''');
```

---

## 四、数据流

### 4.1 完整链路

```
[1] 用户选择素材 → Flutter 组装 sourceType/sourceCode/typingMode
        │
[2] Flutter 打开 WebView，加载 typing-web Edge Function
        │   URL: https://xxx.supabase.co/functions/v1/typing-web
        │   通过 JS Bridge 注入 jwt + 素材参数
        │
[3] Web 页面调 typing-content Edge Function 获取素材文本
        │   POST { sourceType, sourceCode }
        │   返回 { title, content, segments: [...] }
        │
[4] 用户打字训练（纯前端实时比对，无网络请求）
        │   - 逐字符校验正确性
        │   - 本地计时 + 统计 WPM/准确率
        │
[5] 训练结束 → Web 调 typing-stats Edge Function 保存 session
        │   POST { sourceType, sourceCode, total_chars, typed_chars,
        │          correct_chars, error_chars, wpm, accuracy,
        │          duration_seconds, error_details, typingMode }
        │
[6] 统计页面调 typing-stats 查询历史数据
        │   POST { op: "overview" | "trend" | "source" | "errors" }
        │   返回 JSON 数据，前端 Chart.js 渲染图表
```

### 4.2 离线策略

打字训练核心逻辑（字符比对、计时、WPM 计算）在 Web 前端完成，不依赖网络。仅在以下节点需要网络：

| 节点 | 是否阻塞训练 |
|------|:---:|
| 获取素材文本 | 是（但可缓存上次素材） |
| 查词 | 否（无网络时降级为本地提示"需要网络"） |
| 播放原音 | 否 |
| 跟读评分 | 否 |
| 保存 session | 否（失败则本地暂存，下次在线时补传） |

---

## 五、Web 页面设计规范（打字专属）

打字 Web 页面不走 Flutter TDesign 组件库，需要独立的设计规范（保持简洁严谨）：

### 5.1 色彩

| 用途 | 色值 | 说明 |
|------|------|------|
| 背景 | `#1E1E2E` | 深色底，减少眼部疲劳 |
| 卡片背景 | `#282840` | |
| 原文文字 | `#CDD6F4` | 柔和白 |
| 已输入正确 | `#A6E3A1` | 柔绿 |
| 输入错误 | `#F38BA8` | 柔红 |
| 当前行高亮 | `#45475A` | |
| 强调色 | `#89B4FA` | 柔蓝 |
| WPM/准确率 | `#F9E2AF` | 柔黄 |

### 5.2 字体

- 英文正文：`JetBrains Mono` / `SF Mono`（等宽字体，打字必备）
- 中文标注：系统默认中文字体
- 字号：原文 18px / 输入区 20px / 统计数字 28px

### 5.3 布局

- 三栏结构：左侧原文（60%）→ 中间输入区（40%）→ 右侧统计面板（可折叠）
- 顶部工具栏固定
- 底部状态栏固定
- 响应式：宽屏三栏，窄屏（<900px）堆叠为单栏

---

## 六、与现有系统的集成点

| 集成点 | 方式 | 说明 |
|--------|------|------|
| 素材获取 | 复用 `subtitle-storage` Edge Function 已存储的字幕数据 | typing-content 直接查询 Storage |
| 查词 | 通过 JS Bridge → Flutter → `ai-proxy` | 复用现有查词能力 |
| TTS | 通过 JS Bridge → Flutter → DashScope/AVSpeech | 复用现有 TTS 通道 |
| 跟读评分 | 通过 JS Bridge → Flutter → 声通 | 复用现有评分引擎 |
| 视频播放 | Flutter WebView 上层叠加 OmniPlayer 小窗 | 不嵌入 Web |
| 统计数据 | 独立 `typing_sessions` 表，不混入 `study_record` | 打字训练的学习性质不同 |

---

## 七、不做的功能（明确边界）

| 不做 | 理由 |
|------|------|
| 打字游戏/竞速/排行榜 | 花里胡哨，偏离学习定位 |
| 社交分享打字成绩 | 非核心，后期可评估 |
| 自定义键盘布局 | 打字模块面向 QWERTY 标准键盘，无需复杂化 |
| 付费/计费 | 战略决策：全免费引流 |
| 移动端打字界面 | 手机屏幕打字体验差，仅做素材选择和统计查看 |
| 独立内容库 | 不创建打字专用素材，完全复用三引擎 |

---

## 八、开发阶段建议

| 阶段 | 内容 | 预估 |
|------|------|:---:|
| **Phase 6.1** | 打字 Web 页面（typing-web Edge Function）+ 全文本模式 | 核心 |
| **Phase 6.2** | Flutter 入口 + WebView 容器 + JS Bridge（查词/TTS） | 核心 |
| **Phase 6.3** | typing-content / typing-stats Edge Functions + 云端表 | 核心 |
| **Phase 6.4** | 填空模式 + 听写模式 | 扩展 |
| **Phase 6.5** | 统计仪表盘（趋势图 + 错误分析） | 扩展 |
| **Phase 6.6** | 视频小窗播放 + 跟读评分集成 | 增强 |

---

## 九、文档索引

| 文档 | 路径 |
|------|------|
| 本设计文档 | `docs/modules/typing-module-design.md` |
| 可行性评估 | `docs/modules/typing-module-evaluation.md` |
| HTML UI 原型 | `docs/modules/typing-ui-prototype.html` |
*（内容由AI生成，仅供参考）*
