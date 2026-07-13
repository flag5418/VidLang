# VidLang 代码清理 & 文档对齐 — 逐文档审查报告

> **审查方式**: 以文档为基准，逐一与代码 + Supabase 脚本交叉验证
> **P0 死代码已删除**: `home_page_backup.dart` (808行) + `shengtong_evaluator_manual.dart` (340行)
> **用户确认废弃**: `article_chapter` 彻底移除（文章只有 段落→句子→单词 三级）
> **审查完成日期**: 2026-07-13

---

# 📄 文档 1/5: database-schema.md → database-schema-V2.0.md

## ✅ 已确认一致的部分

### 本地 SQLite 注册表（20 个）— 与 main.dart 完全匹配

| # | 表名 | 模型 | FTS5 | 状态 |
|---|------|------|:----:|------|
| 1 | video_folder | VideoFolder | ❌ | ✅ 一致 |
| 2 | video_info | VideoInfo | ❌ | ✅ 一致 |
| 3 | subtitles | Subtitles | ✅ | ✅ 一致 |
| 4 | participle | Participle | ✅ | ✅ 一致 |
| 5 | article | Article | ❌ | ✅ 一致 |
| 6 | article_paragraph | ArticleParagraph | ❌ | ✅ 一致 |
| 7 | article_sentence | ArticleSentence | ✅ | ✅ 一致 |
| 8 | article_bookmark | ArticleBookmark | ❌ | ✅ 一致 |
| 9 | study_record | StudyRecord | ❌ | ✅ 一致（duration=秒） |
| 10 | recording_record | RecordingRecord | ❌ | ✅ 一致 |
| 11 | test_session | TestSession | ❌ | ✅ 一致 |
| 12 | test_item | TestItem | ❌ | ✅ 一致 |
| 13 | test_evaluation | TestEvaluation | ❌ | ✅ 一致 |
| 14 | ai_evaluation_log | AiEvaluationLog | ❌ | ✅ 一致 |
| 15 | word_book | WordBook | ❌ | ✅ 一致 |
| 16 | word_tag | WordTag | ❌ | ✅ 一致 |
| 17 | word_book_tag | WordBookTag | ❌ | ✅ 一致 |
| 18 | config | Config | ❌ | ✅ 一致 |
| 19 | user | User | ❌ | ✅ 一致 |
| 20 | error_log | ErrorLog | ❌ | ✅ 一致 |

### 时长单位规范 — ✅ 正确
- 视频相关 = 毫秒 ✅
- 学习记录 = 秒 ✅
- 录音记录 = 毫秒 ✅

---

## ✅ 差异项 A：device_type 定位 — 已解决 (2026-07-13)

**结论**: `device_type.dart` 中的 `AppDeviceType` 是**运行时枚举**，不是数据库模型，不需要注册到 `registerEntities()`。

**实际情况**:
- `lib/models/device_type.dart` → 包含 `AppDeviceType` 枚举（iphone/ipad），仅用于运行时设备类型判断
- `main.dart` import 并广泛使用（加载、检测、屏幕方向、UI构建）
- **不注册到数据库是正确的设计决策**
- ~~方案A：从文档中移除第 22 行~~ → ✅ 已在 `database-schema-V2.0.md` 中修正为 20 表

---

## ⏳ 差异项 B：Supabase 云端表 — 待后续文档补充

> **状态**: 已识别，属于文档扩充范围（非代码修复）
> **建议**: 在 `database-schema-V2.0.md` 中新增章节或另建 `supabase-schema.md`

### B.1 计费体系（5 张表）— 数据待同步

### B.2 充值档位（topup_config）— 文档待补充

### B.3 Forum 论坛系统（11 张表）— 文档待补充

### B.4 对话会话（conversation_session）— 文档待补充

### B.5 其他 Supabase 表 — 文档待补充

---

## ⏳ 差异项 C：ERD 辅助表 — 已确认非问题

- `playback_settings` — 运行时配置，使用 SharedPreferences，不需入库
- `conversation_*` — Supabase 端表，不在本地 SQLite 范围
- `learning_resource` — 预留模型，暂未启用（零引用）
- `billing_summary` — Supabase DTO，非本地实体

---

# 📄 文档 3/5: services-architecture.md (V2.0 → V2.1) — ✅ 已完成

## 审查发现 & 修复

| # | 问题 | 严重度 | 状态 |
|---|------|--------|------|
| 1 | `ShengtongEvaluatorManual` 文档列出但文件不存在 | 🔴 | ✅ 已从文档移除 |
| 2 | `DeviceInfoService` 存在但文档遗漏 | 🔴 | ✅ 已加入 §2.1 核心基础设施 |
| 3 | TTS 收费模式描述过时 | 🟡 | ✅ 已更新 §3.5 |
| 4 | 声通评测器描述过时 | 🟡 | ✅ 已更新描述 |
| 5 | 统计表数据不准 | 🟡 | ✅ 全部修正 |
| 6 | 底部相关文档链接路径未版本化 | 🟢 | ✅ 已修正 |

### 代码残留 — ✅ 已全部清理

| 服务文件 | 残留内容 | 状态 |
|---------|---------|------|
| `lib/services/translation_service.dart` | 可能的 chapter 引用 | ✅ **已确认无残留**（grep 零匹配） |
| `lib/services/article_parser.dart` | chapter 注释 | ✅ **已更新注释**为"无 chapter 层级" |

---

# 📄 文档 4/5: supabase-integration.md (v1.0 → V1.1) — ✅ 已完成

## 审查发现 & 修复

| # | 问题 | 严重度 | 状态 |
|---|------|--------|------|
| 1 | Edge Functions 清单严重不全 | 🔴 | ✅ 已补全完整清单 + 分类 |
| 2 | 「禁止直连第三方 API」描述矛盾 | 🔴 | ✅ 重写为多通道架构说明 |
| 3 | ai-proxy rule_code 不准确 | 🔴 | ✅ 路由表已按代码重写 |
| 4 | billing-webhook/topup 函数名错误 | 🔴 | ✅ 已替换为正确函数名 |
| 5 | §9.2 离线优先策略代码示例过时 | 🟡 | ✅ 已移除替换 |
| 6 | 架构图只画了 3 个 Edge Function | 🟡 | ✅ 已重绘完整架构图 |
| 7 | 版本号格式不规范 | 🟢 | ✅ 已修正 |

### 代码残留 — ✅ 已修复 (2026-07-13)

| 文件 | 残留内容 | 状态 |
|-----|---------|------|
| `lib/services/unified_tts_service.dart` | 注释写 "ai-proxy Edge Function → 阿里云 qwen-tts" | ✅ **已修正**为 "DashScope HTTP SSE 直连（阿里云 qwen3-tts-flash）" |

---

# 🔧 决策 & 代码清理记录

## 决策 1：article_chapter 彻底废弃 ✅ (2026-07-13) — **全部完成**

**用户确认**: 文章只有 **段落 → 句子 → 单词** 三级，chapter 层彻底不需要

### 文档已修复
- ✅ `database-schema-V2.0.md`: ERD 图移除 article_chapter
- ✅ `database-schema-V2.0.md`: 表清单移除 article_chapter（20 表）

### 代码清理 — ✅ 全部完成

| 文件 | 操作 | 状态 |
|------|------|------|
| `lib/models/article_chapter.dart` | 删除整个文件 | ✅ **文件已不存在** |
| `lib/main.dart` | 移除注册行 | ✅ **registerEntities 中无此项** |
| `lib/views/article/article_reader_page.dart` | 移除引用 | ✅ **仅剩注释说明"ArticleChapter 已移除"** |
| `lib/services/article_parser.dart` | 移除 chapter 分支 | ✅ **已更新注释**为"无 chapter 层级" |
| `lib/services/translation_service.dart` | 检查并移除 | ✅ **grep 零匹配，无残留** |
| `lib/services/wifi_transfer_service.dart` | 方法名 + 注释 | ✅ **已重命名** `_parseArticleChaptersAndSentences` → `_parseArticleParagraphsAndSentences` |

---

## 决策 2：video_folder.parent_code — 🔶 结论变更 (2026-07-13)

**原始决策**: 废弃 parent_code，文件夹扁平化
**✅ 重新评估结论**: **parent_code 仍在积极使用，不应废弃**

### 证据（代码实际使用情况）

`parent_code` 被用于**分组(Group)-叶子(Leaf)** 两级文件夹结构：

| 文件 | 使用方式 |
|------|---------|
| `lib/services/settings_service.dart` | `isGroupFolder()` / `isLeafVideoSet()` 判断方法 |
| `lib/services/file_picker_service.dart` | 导入文件夹时设置 `parentCode` |
| `lib/services/wifi_transfer_service.dart` | WiFi 传输中按 `parent_code` 过滤叶子文件夹 |
| `lib/services/stats_service.dart` | 统计查询中用 `parent_code IS NOT NULL` 过滤 |
| `lib/providers/file_provider.dart` | 文件列表 Provider 中按 `parent_code` 查询 |

**结论**: `parent_code` 是分组-叶子结构的核心字段，**保留不动**。原 TODO 中的废弃决定撤销。

---

## 📊 总体进度

| 类别 | 总数 | 已完成 | 待处理 |
|------|:----:|:------:|:------:|
| 文档 1/5 (database-schema) | 3 项差异 | 1 (差异A) | 2 (差异B/C 属于文档扩充) |
| 文档 3/5 (services-architecture) | 6 项 + 2 残留 | **8/8** ✅ | 0 |
| 文档 4/5 (supabase-integration) | 7 项 + 1 残留 | **8/8** ✅ | 0 |
| 决策1 代码清理 (article_chapter) | 6 个文件 | **6/6** ✅ | 0 |
| 决策2 代码清理 (parent_code) | 1 项 | **N/A** 🔶 | 撤销（仍在使用） |

### 剩余工作（非阻塞，可后续处理）
- [ ] 差异 B: Supabase 云端表补充到数据库文档（属文档扩充，不影响运行）
- [ ] 差异 C 辅助表说明可在 ERD 图注中标注定位
