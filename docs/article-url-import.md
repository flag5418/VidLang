---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: 9a16bac6e27d25132787d930f50d9879_ce86f3867a0311f182885254006c9bbf
    ReservedCode1: 1M5Rz3TzlFubBa7m1cdP3cacbucWvXTRJlYWd2F+VLmxXLSyvAy/2pWtGvKsi29NNRXvurWaFm0ks7X7dDRYnH6yC/QLFDyR3kg1P24/XACjsP4MP9a56bKbV4oxNTqoRz5PRc4Vwt7/FR2yDHM2smr/AXkLR7HawaO6kIdnsWhOKJBbqDyJE59OO0w=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: 9a16bac6e27d25132787d930f50d9879_ce86f3867a0311f182885254006c9bbf
    ReservedCode2: 1M5Rz3TzlFubBa7m1cdP3cacbucWvXTRJlYWd2F+VLmxXLSyvAy/2pWtGvKsi29NNRXvurWaFm0ks7X7dDRYnH6yC/QLFDyR3kg1P24/XACjsP4MP9a56bKbV4oxNTqoRz5PRc4Vwt7/FR2yDHM2smr/AXkLR7HawaO6kIdnsWhOKJBbqDyJE59OO0w=
---

# VidLang 文章 URL 导入方案

> **版本**：v1.0 | **日期**：2026-07-07
> **性质**：技术设计文档，记录文章 URL 正文提取方案的完整设计、可行性分析、技术选型与实现细节。

---

## 一、需求与问题域

### 1.1 背景

VidLang 文章阅读器（`ArticleReaderPage`，2707 行）已具备完整的学习功能：查词、TTS 朗读、跟读评分、翻译、标注。但用户导入文章的入口依赖粘贴纯文本，操作成本高。用户希望输入一个网页链接即可自动提取正文并导入阅读器。

### 1.2 用户故事

```
用户在「资源 → 文章」页面输入一个链接
  → App 自动提取网页正文
  → 跳转到 ArticleReaderPage 深度学习
```

### 1.3 约束

| 约束 | 说明 |
|------|------|
| 运行时 | Supabase Edge Function（Deno / TypeScript），不可用 Python 库 |
| 提取质量 | 需覆盖主流 CMS 站点（WordPress / Medium / 知乎专栏 / CSDN / 掘金 / 新闻站） |
| 中文支持 | 算法需对中文逗号/句号密度做适配 |
| 失败兜底 | 提取失败时引导用户手动复制 → 跳转 `ArticleImportPage` |
| 仅文章 Tab | 视频和音频 Tab 保持原有搜索过滤功能不变 |

---

## 二、方案调研

### 2.1 网页正文提取：开源方案对比

| 方案 | 语言 | Stars | 准确率 | 中文 | 速度 | 维护 | Deno 兼容 |
|------|------|------|:--:|:--:|------|:--:|:--:|
| **Mozilla Readability** | JS | 6.5k+ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 快 | 活跃 | ✅ 最佳 |
| trafilatura | Python | 2.5k+ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 中 | 活跃 | ❌ 需 Python |
| newspaper3k | Python | 12k+ | ⭐⭐⭐ | ⭐⭐ | 慢 | 停滞 | ❌ |
| goose3 | Python | 1.5k+ | ⭐⭐⭐ | ⭐⭐⭐ | 中 | 一般 | ❌ |
| boilerpipe | Java | 1k+ | ⭐⭐⭐ | ⭐⭐ | 快 | 停更 | ❌ |
| mercury-parser | Node.js | 2.7k+ | ⭐⭐⭐⭐ | ⭐⭐⭐ | 中 | 停更 | ⚠️ |

**结论**：Mozilla Readability 是唯一适配 Supabase Edge Function（Deno/TS）的方案。trafilatura 准确率最高但无法在 Deno 运行。

### 2.2 移动端 WebView 操控视频播放器：可行性分析

在调研文章方案时，同步评估了移动端 WebView 操控视频播放器的可行性。

| 功能 | YouTube (WebView) | Bilibili (WebView) |
|------|:--:|:--:|
| 播放/暂停 | ✅ Android 稳，iOS 需用户手势 | ❌ 无公开 API |
| 跳转/倍速/音量 | ✅ iframe API | ❌ |
| 获取播放进度 | ✅ `getCurrentTime()` | ❌ |
| 监听字幕 DOM | ❌ 跨域 iframe 同源策略阻断 | ❌ |
| 获取字幕内容 | ⚠️ 需 YouTube Data API v3 | ❌ |

**关键障碍**：

- **同源策略**：WebView 注入的 JS 无法访问跨域 iframe 内部 DOM，MutationObserver 监听字幕不可行
- **iOS WKWebView**：`playVideo()` 常被系统拦截，要求先有用户手势
- **Bilibili**：播放器变量名 Webpack 混淆，无公开 JS API，基本不可控

**结论**：移动端 WebView 能做视频的播放/暂停/倍速控制，但字幕自动获取是关键瓶颈。桌面端系统音频 Loopback 方案优势明显。

---

## 三、Mozilla Readability 算法原理

### 3.1 整体流程

```
HTML 字符串
  → DOM Parser 解析（linkedom）
  → Readability.parse()
    → Step 1: 预处理（清洗 script/style/noscript/注释）
    → Step 2: 全局打分（文本密度 + 链接密度 + 标签权重）
    → Step 3: 向上累加分数，选出最高分容器
    → Step 4: 二次清洗（去低分枝叶、高链接密度段落）
    → Step 5: 输出 { title, content, textContent, excerpt }
```

### 3.2 评分算法

#### 正分规则：加权文本密度

```javascript
// 伪代码
function getWeight(text) {
  let score = 0;
  const segments = text.split(/,|\.|:|;|!|\?|，|。|；|！|？/);
  for (const seg of segments) {
    const words = seg.trim().split(/\s+/);
    score += Math.max(words.length - 5, 0);
  }
  return score;
}
```

标点密度高的文本更可能是正文——广告、导航栏文本短而零碎，通不过"超过 5 单词"的门槛。

#### 负分规则：链接密度

链接密度 > 33% → 大幅降分（侧边栏、推荐列表、导航栏）。

#### 标签加权

| 标签 | 权重偏移 | 原因 |
|------|---------|------|
| `<article>`, `<main>` | +25 | HTML5 语义标签 |
| `<div>`, `<section>` | +5 | 通用容器 |
| `<p>` | +1/段 | 正文基本单元 |
| `class/id` 含 `comment/sidebar/footer/ad` | -25 | 命名黑名单 |

#### 兄弟节点对比

在同级兄弟中选出得分最高的 1-3 个节点，其他大幅降分丢弃——这是 Readability 最精妙的设计。

### 3.3 中文适配

| 原始行为 | 中文问题 | 适配 |
|------|------|------|
| 仅 `, . ; ! ?` 断句 | 漏掉中文标点 | 扩展为 `，。；！？` |
| 逗号密度评分 | 无法识别中文逗号 | 双轨计数：`getCharCount(',') + getCharCount('，')` |
| 句号权重 | 漏掉中文句号 | `getCharCount('.')*2 + getCharCount('。')*2` |
| class/id 黑名单全英文 | 漏掉 `评论/侧边栏/推荐` | 后续迭代可扩展中文黑名单 |

### 3.4 能力边界

**能做好**：标准 CMS 站点（WordPress / Medium / 知乎专栏 / CSDN / 掘金 / 新浪 / 腾讯新闻）。

**做不好**：SPA 动态渲染页面（需 headless browser 执行 JS）、论坛帖子、列表页/首页。

这些做不好的场景由「WebView 划词 + 手动复制」兜底。

---

## 四、技术实现

### 4.1 系统架构

```
┌──────────────────────────────────────────────┐
│  Flutter App                                  │
│  ┌──────────────────────────────────────┐    │
│  │  file_list_page.dart                  │    │
│  │  文章 Tab: URL 输入 → 验证 → 转入     │    │
│  │  视频/音频 Tab: 搜索过滤（不变）       │    │
│  │                          │             │    │
│  │  失败 → SnackBar「手动复制」          │    │
│  │         → ArticleImportPage            │    │
│  │                          │             │    │
│  │  成功 → ArticleParser.parse()         │    │
│  │       → DatabaseService               │    │
│  │       → ArticleReaderPage              │    │
│  └──────────────┬───────────────────────┘    │
│                 │ Supabase Functions SDK       │
└─────────────────┼─────────────────────────────┘
                  │
┌─────────────────▼─────────────────────────────┐
│  Supabase Edge Function: extract-article       │
│  ┌──────────────────────────────────────┐    │
│  │  1. URL 验证 (http/https 协议检查)    │    │
│  │  2. fetch(url) → HTML 字符串          │    │
│  │  3. linkedom DOM 解析                │    │
│  │  4. Readability 内联算法提取正文      │    │
│  │  5. 返回 { title, textContent,        │    │
│  │            content, excerpt }         │    │
│  └──────────────────────────────────────┘    │
└───────────────────────────────────────────────┘
```

### 4.2 Edge Function 设计

**路径**：`supabase/functions/extract-article/index.ts`

| 项目 | 选择 | 原因 |
|------|------|------|
| DOM 解析 | `linkedom` | 轻量，Deno 原生支持，无需 `jsdom` 的 `vm` 模块 |
| Readability | 内联移植 | `@mozilla/readability` 依赖 `jsdom`，不兼容 Deno；核心算法 ~150 行 |
| UA | 桌面端 Chrome | 避免目标站因移动端 UA 返回简化页 |
| Content-Type 检查 | 强制 | 拒绝非 HTML 响应，避免 JSON/PDF 误提取 |

**接口协议**：

```
POST /functions/v1/extract-article
Body:  { "url": "https://example.com/article" }

成功:  { "ok": true,  "title": "...", "textContent": "...", "content": "<html>...", "length": 1234 }
失败:  { "ok": false, "error": "...", "message": "..." }
```

**错误码细分**：

| error | 含义 | HTTP |
|------|------|:--:|
| `missing_url` | 未提供 url | 400 |
| `invalid_url` | 不合法 URL | 400 |
| `invalid_protocol` | 非 http/https | 400 |
| `fetch_failed` | 目标网站不可达 | 502 |
| `not_html` | Content-Type 非 HTML | 400 |
| `extraction_failed` | Readability 未提取到正文 | 422 |
| `parse_failed` | DOM 解析失败 | 500 |

### 4.3 Flutter 端改动

**文件**：`lib/views/files/file_list_page.dart`（+130 行）

#### UI 状态切换

```
_resourceTypes[_currentTab] == 'article'
  ├─ 是 → URL 输入模式
  │   ├─ placeholder: 「请输入链接」
  │   ├─ 图标: 🔗 AppIcons.link
  │   ├─ 键盘: TextInputType.url
  │   ├─ 后缀: 「转入」按钮（蓝色胶囊）
  │   └─ 回车键: 触发 _importFromUrl()
  │
  └─ 否 → 搜索过滤模式（不变）
      ├─ placeholder: 「搜索视频...」/「搜索音频...」
      ├─ 图标: 🔍 AppIcons.search
      └─ 后缀: × 清除按钮
```

#### 导入流程

```
_urlRegExp.hasMatch(url)
  ├─ ❌ → SnackBar「请输入有效的网址」
  └─ ✅ → _isImporting = true → 加载动画

      client.functions.invoke('extract-article', body: {url})
        ├─ data['ok'] == true
        │   → ArticleParser.parse(title, textContent)
        │   → DatabaseService.insert(article)
        │   → batchInsert(sentences, chapters, paragraphs)
        │   → ConversationService.uploadArticleContentToCloud()
        │   → Navigator.push(ArticleReaderPage)
        │
        └─ data['ok'] != true / 异常
            → SnackBar「提取失败」+ 「手动复制」按钮
            → 跳转 ArticleImportPage
```

#### URL 校验

```dart
static final _urlRegExp = RegExp(
  r'^https?://[\w\-]+(\.[\w\-]+)+(:\d+)?(/[\w\-./?%&=+#@!~*(),;:]*)?$',
  caseSensitive: false,
);
```

仅允许 http/https 协议，拒绝 `file://`、`ftp://`、纯 IP 等非标准格式。

---

## 五、移动端 WebView 替代方案

### 5.1 WebView 文章浏览方案

与 URL 提取方案互补，用于 SPA 页面和动态内容站：

```
用户在 WebView 中浏览文章
  → 底部悬浮「导入到阅读器」按钮
  → 从 WebView 内注入 Readability.js 提取正文（不走 Edge Function）
  → 或注入防复制解除脚本，让用户手动复制
```

### 5.2 防复制绕过脚本

95% 的网站防复制可被以下注入脚本打穿：

```javascript
// CSS 恢复选中 + 清空事件拦截 + 删除遮罩层 + MutationObserver 动态防护
document.querySelectorAll('*').forEach(el => {
  el.style.userSelect = 'auto';
  el.style.webkitUserSelect = 'auto';
});
document.oncopy = null;
document.oncontextmenu = null;
document.onselectstart = null;
document.querySelectorAll('[class*="mask"],[class*="overlay"]')
  .forEach(el => el.remove());
```

---

## 六、工作量与文件清单

### 6.1 改动文件

| 文件 | 操作 | 行数 |
|------|------|:--:|
| `supabase/functions/extract-article/index.ts` | 新增 | 490 |
| `lib/views/files/file_list_page.dart` | 修改 | +130 |

### 6.2 部署步骤

```bash
# 1. 部署 Edge Function
cd supabase
supabase functions deploy extract-article

# 2. 构建运行
cd ..
flutter run
```

### 6.3 验证方式

1. 切换到「文章」Tab
2. 搜索框显示 🔗 + 提示「请输入链接」
3. 粘贴 `https://zhuanlan.zhihu.com/p/xxx`
4. 点「转入」→ 自动跳转 ArticleReaderPage
5. 输入非法 URL → 收到错误提示
6. 截图中的红色搜索框区域已改为 URL 输入模式

---

## 七、决策记录

| 决策 | 选项 A | 选项 B | 选择 | 原因 |
|------|------|------|:--:|------|
| DOM 解析器 | jsdom | linkedom | B | jsdom 依赖 Node `vm` 模块，Deno 不兼容 |
| Readability 方式 | npm 包 | 内联移植 | 内联 | npm 包依赖 jsdom，且核心算法仅 150 行 |
| 提取结果展示 | 预览 → 确认 → 导入 | 直接导入 | 直接导入 | Readability 输出是净化 HTML，非原文，用户没法对照判断 |
| 失败兜底 | 仅提示错误 | 提示 + 「手动复制」跳转 | 提示 + 跳转 | 降级用户体验，不阻塞学习流程 |
| 视频/音频 Tab | 也改 URL 输入 | 保持原有搜索 | 保持 | 视频和音频无 URL 导入场景 |
| SPA 页面 | Edge Function | WebView 内 Readability.js | 双层 | Edge Function 覆盖 80% SSR；WebView 内运行覆盖 20% SPA |
| 文章 vs WebView 视频 | 先做文章 | 先做视频 | 先做文章 | 移动端 WebView 视频字幕获取被同源策略阻断，瓶颈未解 |

---

## 八、后续迭代

| 优先级 | 事项 | 说明 |
|:--:|------|------|
| P1 | 中文 class/id 黑名单 | 扩展 `unlikelyCandidates` 正则，增加「评论/侧边栏/推荐/广告」等中文关键词 |
| P1 | WebView 内 Readability.js | 覆盖 SPA 动态渲染页面，从 WebView 直接提取不走 Edge Function |
| P2 | 多页自动拼接 | 利用 `<a rel="next">` 或 URL pattern 自动合并多页文章 |
| P2 | 用户选择 JSON 提取规则 | 高级功能：拦截 XHR 响应，让用户选 JSON 字段，保存为模板 |
| P3 | 阅读进度云同步 | 同一篇文章的阅读进度跨设备同步 |
*（内容由AI生成，仅供参考）*
