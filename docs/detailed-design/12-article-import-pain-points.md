# VidLang 文章资料收集 — 痛点分析与解决策略

> 本文分析从各种来源收集文章资料的技术难点和解决方案。
> 覆盖：WiFi 传输（电脑→手机）和手机端直接导入两条路径。

---

## 一、文章资料的来源矩阵

### 1.1 用户可能上传的文件类型

```
电脑端（WiFi 传输）                手机端（App内导入）
───────────────                    ───────────────
.txt （纯文本）                     📋 粘贴文本
.md  （Markdown）                   📷 拍照/截图（OCR）
.html（网页文件）                   📁 导入 .md / .txt
.pdf （PDF文档）                    🌐 分享到 VidLang
.png / .jpg（截图）                 📎 从 Files app 选择
.epub（电子书）
.doc/.docx（Word文档）
```

### 1.2 每种类型的处理难度

| 格式 | 处理难度 | 说明 |
|------|---------|------|
| `.txt` | ⭐ 非常简单 | 直接读取为字符串即可 |
| `.md` | ⭐ 非常简单 | 直接存储，后续用 `flutter_markdown` 渲染 |
| `.html` | ⭐⭐⭐ 中等难度 | 需要提取正文，去除导航/广告/脚本 |
| `.pdf` | ⭐⭐⭐⭐ 较难 | PDF 解析需要额外库，布局信息丢失 |
| `.png/.jpg` | ⭐⭐⭐⭐ 较难 | 需要 OCR 识别，结果有误差率 |
| `.epub` | ⭐⭐⭐ 中等 | 本质是 ZIP+XHTML，需要解压+解析 |
| `.docx` | ⭐⭐⭐ 中等 | 本质是 ZIP+XML，可提取文本 |

---

## 二、WiFi 传输模块改造方案

### 2.1 当前状态

```
WiFi 传输只支持：
├── 文件夹：创建/重命名/删除
├── 视频文件：上传/重命名/删除
├── 字幕：单独上传关联到视频
└── 封面：查看
```

文件夹没有区分类型，所有文件夹都被视为"视频文件夹"。

### 2.2 改造后的结构

```
WiFi 传输页面左侧：
┌──────────────────────┐
│  📁 文件夹列表       │
│                      │
│  🎬 Videos (3)      │ ← 视频文件夹（蓝色图标）
│  🎵 Audio  (2)      │ ← 音频文件夹（绿色图标）
│  📖 Articles (1)    │ ← 文章文件夹（橙色图标）
│                      │
│  [+ New Folder]      │ ← 新建文件夹时选择类型
└──────────────────────┘

右侧：选中文件夹后显示内容
├── 视频/音频文件夹：显示文件列表（同现有）
└── 文章文件夹：显示文章列表 + 上传面板
```

### 2.3 文件夹创建 API 扩展

现有 API `POST /api/folders` 的 body 增加 `folderType`：

```json
// 请求
{
  "name": "IELTS Reading",
  "type": "virtual",
  "folderType": "article"   // 新增：video / article / music
}

// 响应
{
  "ok": true,
  "data": {
    "code": "xxx",
    "name": "IELTS Reading",
    "folderType": "article",
    "canUpload": true
  }
}
```

### 2.4 文章上传 API

```http
PUT /api/folders/{folderCode}/articles?filename=article.md
Content-Type: application/octet-stream
↓
系统根据扩展名自动判断处理方式：
├── .md   → 直接存储为 Article
├── .txt  → 直接存储为 Article
├── .html → 提取正文后存储
├── .pdf  → 解析后存储（后续）
└── .png  → 暂不支持 WiFi 端 OCR（手机端处理）
```

**文章上传的后端处理流程：**

```
接收文件
    ↓
判断文件扩展名
├── .md  → 直接读取内容 → 存储
├── .txt → 直接读取内容 → 存储
├── .html
│   ├── 用 regex 提取 <article> / <main> / <body> 内容
│   ├── 剥离 <script> <style> <nav> <footer> 等标签
│   ├── 将标签换为 Markdown 等价语法
│   │   ├── <h1>~<h6> → #
│   │   ├── <p> → 段落
│   │   ├── <strong>/<b> → **加粗**
│   │   ├── <em>/<i> → *斜体*
│   │   ├── <ul>/<ol>/<li> → 列表
│   │   └── <blockquote> → >
│   └── 存储为 Markdown
│
├── .pdf → 调用 Supabase Edge Function（pdf到文本）
│   ├── 或使用 dart 端的 pdf 解析库
│   └── 结果存为纯文本（再转为 Markdown）
│
├── .png/.jpg → 返回错误提示："图片OCR请在手机端导入"
│   （WiFi 端不做 OCR，依赖手机端 iOS Vision）
│
└── 未知格式 → 返回错误提示
    ↓
保存 Article + ArticleChapter + ArticleSentence
```

### 2.5 关键决策：WiFi 端支持的文件类型分阶段

```
Phase 1（Must Have）:
├── .md     → 直接存（最推荐用户使用）
├── .txt    → 直接存
└── 粘贴文本 → 用户在 HTML 页面中直接粘贴

Phase 2（Nice to Have）:
├── .html   → 提取正文+转换 Markdown
└── 网页 URL → 服务端抓取 → 提取正文（类似 readability）

Phase 3（Future）:
├── .pdf    → 解析文本
└── .docx   → 解析文本
```

---

## 三、手机端文章导入方案

### 3.1 手机端有、WiFi 端没有的能力

```
手机端优势                          WiFi 端优势
───────────                        ─────────
📷 相机拍照+OCR                    💻 键盘输入更快
📱 相册选择截图                     🗂️ 拖拽批量上传
🌐 分享到 VidLang                  🖥️ 大屏幕多任务
🎤 语音输入                        🔗 浏览器复制粘贴
```

**核心原则：手机端和 WiFi 端互补，不重复实现。**

| 操作 | 最佳路径 |
|------|---------|
| 电脑上有一篇网页文章 | 浏览器复制 → WiFi 页面粘贴 |
| 电脑上有一个 .md 文件 | 直接拖拽到 WiFi 页面 |
| 手机上刷到一篇文章 | 分享到 VidLang / 复制链接 |
| 书上看到一段文字 | 拍照 → 手机端 OCR |
| 手机上有个 PDF | Files app 选择 → 导入 |

### 3.2 手机端导入入口

```
ArticleListPage 的 [+ New] 按钮：
┌──────────────────────────────────────┐
│  New Article                          │
├──────────────────────────────────────┤
│                                       │
│  📋  Paste Text                       │ ← 优先推荐
│     Paste English text or Markdown    │
│                                       │
│  📷  Scan with Camera                 │ ← OCR 拍照
│     Take photo of text                │
│                                       │
│  📁  Import File                      │ ← 文件选择器
│     .md, .txt, .html, .pdf           │
│                                       │
│  🌐  Share Extension                  │ ← 系统分享
│     Share from Safari, Notes, etc.    │
│                                       │
└──────────────────────────────────────┘
```

### 3.3 处理管线（手机端）

```
用户粘贴/选择文件
    ↓
判断输入类型
│
├── 纯文本（粘贴）
│   └── 尝试检测是否为 Markdown
│       ├── 包含 # 或 ## → 按 Markdown 处理
│       └── 否则 → 用 <h1>标题</h1> 包装为简单 Markdown
│
├── .md 文件（文件选择器）
│   └── 直接读取
│
├── .html 文件（文件选择器）
│   └── 提取正文（服务端或本地处理）
│
├── .pdf 文件（文件选择器）
│   └── 解析文本 → 转为 Markdown
│
├── 图片（拍照/相册）
│   └── iOS Vision OCR → 识别文字 → 转为 Markdown
│
└── 分享（系统 Share Sheet）
    └── 接收 URL 或文本 → 处理
    ↓
统一输出
├── title（自动从内容提取：第一个 # 或前 50 字）
├── contentMarkdown（Markdown 格式全文）
└── language（检测语言，默认 en）
    ↓
保存 Article + 解析分章分句
```

---

## 四、关键决策：HTML 转 Markdown 的方案

### 4.1 问题

用户通过 WiFi 上传 `.html` 文件（或粘贴网页 URL 的内容），需要从中**提取正文**并**转为 Markdown**。

### 4.2 方案选择

| 方案 | 优点 | 缺点 | 推荐 |
|------|------|------|------|
| **A. 正则提取** | 无额外依赖，纯 Dart | 不够健壮，复杂 HTML 易出错 | Phase 1 |
| **B. html 解析库** | 解析准确 | 需引入依赖（`html` package） | Phase 2 |
| **C. 调用 DeepSeek** | 最智能，可处理任意格式 | 消耗 AI Credits，有延迟 | Phase 2 |
| **D. 要求用户手动复制** | 零开发成本 | 用户体验差 | — |

### 4.3 推荐策略

```
Phase 1: 推荐用户使用 .md 格式上传，不接受 .html
         （在 WiFi 页面 UI 上只展示 .md / .txt 的上传按钮）
         UI 文案："For best results, upload .md or .txt files"

Phase 2: 增加 HTML 解析（用 dart:html 或 regex）
         增加 DeepSeek 辅助清理

Phase 3: 增加 PDF 解析
```

### 4.4 关于图片/截图 OCR 的处理

```
❌ WiFi 传输端不做 OCR
理由：
1. Dart 服务端没有成熟的 OCR 库
2. 用户如果电脑上有截图，可以直接用手机拍
3. App 内已有 iOS Vision OCR（IosNativeFeatures.extractTextFromCamera）
4. 最简单的方案：用户在手机 App 内拍照识别

✅ 手机 App 内做 OCR（已有能力）
流程：
1. 用户点击 [Scan with Camera]
2. 打开相机拍照
3. iOS Vision 识别文字 → 返回 OCRResult.text
4. 将识别结果作为纯文本 → 存为 Article
```

---

## 五、WiFi 传输 HTML 页面改造要点

### 5.1 当前 HTML 页面的局限性

现有 `_html()` 方法返回嵌入的 HTML 字符串，约 600 行。修改此 HTML 需要：

1. 在 Dart 字符串中维护大段 HTML（不易调试）
2. 涉及 CSS/JS 修改都需要重新编译 Flutter 应用

### 5.2 改造建议

```
方案 A：继续用嵌入式 HTML（简单但难维护）
├── 在 _html() 中增加类型选择
├── 增加文章上传 UI
└── 增加文章列表展示

方案 B：将 HTML 模板移到 assets/ 目录
├── assets/wifi/index.html（单独文件，可独立编辑）
├── Dart 端读取模板 + 注入变量
└── 开发和调试更方便
```

推荐使用 **方案 B**——将 HTML 模板放到 `assets/` 目录，开发时可以直接在浏览器中调试，不需要每次都编译 Flutter。

### 5.3 文件夹列表 UI 改造

```
┌──────────────────────────────────────────────────┐
│  📁 VidLang WiFi Transfer                        │
│                                                   │
│  ┌─────────────┬────────────────────────────────┐│
│  │ 📁 Folders  │  📂 IELTS Reading              ││
│  │             │  (articles)                    ││
│  │ 🎬 Videos   │                                ││
│  │   3 folders │  📄 Climate Change.md          ││ ← 文章列表
│  │             │    5 chapters, 1284 words      ││
│  │ 🎵 Audio    │    60% completed               ││
│  │   0 folders │                                ││
│  │             │  📄 AI Ethics.md               ││
│  │ 📖 Articles │    3 chapters, 892 words       ││
│  │   2 folders │    30% completed               ││
│  │             │                                ││
│  │             │  [+ Upload .md / .txt]         ││ ← 上传按钮
│  │             │  [+ Paste Text]                ││ ← 粘贴文本
│  │             │                                ││
│  ├─────────────┤────────────────────────────────┤│
│  │ [+ New      │                                ││
│  │  Folder]    │  📄 管理文章按钮               ││
│  └─────────────┴────────────────────────────────┘│
└──────────────────────────────────────────────────┘
```

### 5.4 新建文件夹时选择类型

```
┌──────────────────────────────────┐
│  New Folder                      │
├──────────────────────────────────┤
│                                   │
│  Folder Name:                    │
│  ┌──────────────────────────┐   │
│  │ IELTS Reading             │   │
│  └──────────────────────────┘   │
│                                   │
│  Type:                           │
│  ○ 🎬 Video                      │
│  ○ 🎵 Audio                      │
│  ● 📖 Article (Markdown/Text)   │ ← 选中
│                                   │
│  [Cancel]    [Create]            │
└──────────────────────────────────┘
```

---

## 六、总结：文章资料收集的最佳实践（给用户建议）

> **给使用 VidLang 的用户建议：**

```
最佳流程（推荐）：
1. 在电脑浏览器中打开文章
2. 全选 (Ctrl+A) → 复制 (Ctrl+C)
3. 打开 VidLang WiFi 页面
4. 选择文章文件夹 → [Paste Text]
5. 粘贴 → 自动处理完成

次佳流程（有 .md 文件）：
1. 电脑上编辑好 Markdown 文件
2. 拖拽到 WiFi 页面上传

手机端流程：
1. 在 Safari 中看到英文文章
2. 使用 Share Sheet → "Share to VidLang"
3. 自动下载并处理

截图书籍/纸质材料：
1. 拍照 → App 内 OCR 识别
2. 或使用 iPhone "实况文本" 复制 → 粘贴到 VidLang
```

> **给开发者的优先级建议：**

```
开发优先级：

P0 - 立刻实现（WiFi + 手机端）：
├── WiFi: 文件夹增加 folderType 字段
├── WiFi: 文章文件夹支持上传 .md / .txt
├── WiFi: 文章文件夹列表展示
├── 手机端: 粘贴文本创建文章
└── 手机端: 导入 .md / .txt 文件

P1 - 尽快实现：
├── WiFi/手机端: HTML 提取正文并转为 Markdown
├── 手机端: OCR 拍照识别
└── 手机端: 系统分享扩展

P2 - 后续：
├── PDF 解析
├── 网页 URL 抓取
└── EPUB 支持
```
