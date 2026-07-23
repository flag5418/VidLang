# VidLang 文档索引

> **版本**: V1.0 | **日期**: 2026-07-13
> **说明**: 精简后的文档结构，所有文档均为当前有效状态

---

## 文档目录结构

```
docs/
├── DOCUMENTATION_INDEX.md    ← 本文件（文档总索引）
├── AGENTS.md                  ← AI 协作规范（CatPaw/Claude Code 必读）
├── AGENT_CONTEXT.md           ← AI 快速恢复认知
├── knowledge-base-index.yaml  ← 知识库索引
│
├── architecture/              ← 【核心】架构设计（权威来源）
│   ├── overview-V1.1.md        ← 架构总览 + 导航结构 + 技术栈 + 开发阶段
│   └── database-schema-V2.0.md ← 数据库设计（SQLite 20表 + Supabase 云端表 + DDL）
│
├── modules/                   ← 【模块】各功能模块的详细设计
│   ├── scoring-design.md      ← 跟读/跟唱评分系统设计
│   ├── wordbook-design.md     ← 单词本系统设计
│   ├── test-system-design.md  ← 测试引擎设计
│   ├── ai-conversation-design.md  ← AI 对话系统设计
│   ├── billing-redesign.md      ← 计费系统设计（V1.1，充值/扣费/优惠策略/billing-center）
│   └── forum-design.md          ← 论坛功能设计（V1.1，自定义域名+Cloudflare代理方案+iOS审核细节） │
│
├── reference/                 ← 【参考】代码级知识库（给 AI/开发者查）
│   ├── flutter-code-structure.md   ← Flutter 代码结构详解
│   ├── services-architecture.md    ← 服务层架构（52个服务，V2.1）
│   ├── omni-player-integration.md  ← OmniPlayer 集成指南
│   ├── supabase-integration.md     ← Supabase 集成指南（18个Edge Functions，多通道AI架构，V1.1）
│   ├── ai-service-integration.md   ← AI 服务集成（V1.1，多通道混合架构：5大通道/12个rule_code/WordDetail模型） │
│   ├── tdesign-components.md       ← TDesign 组件使用参考
│   └── design-style-guide.md       ← UI 设计规范
│
│   ├── ai-engineering-optimization-plan-V1.0.md ← 【优化方案】AI 工程化优化计划（V1.0）
│   └── testing-standards-V1.0.md ← 【测试规范】测试策略、Mock、覆盖率、CI（V1.0）
│
└── expired/                   ← 【过期】所有过时文档（扁平存放，不再维护）
```

---

## 快速查找指南

| 我想了解... | 查看文档 |
|------------|---------|
| 产品定位、导航结构、技术栈 | `architecture/overview-V1.1.md` |
| 数据库有哪些表、字段定义 | `architecture/database-schema-V2.0.md` |
| 评分系统怎么工作 | `modules/scoring-design.md` |
| 单词本两档记忆体系 | `modules/wordbook-design.md` |
| 测试引擎填空/听写/选择 | `modules/test-system-design.md` |
| AI 对话如何实现 | `modules/ai-conversation-design.md` |
| 充值扣费怎么算 | `modules/billing-redesign.md` |
| 论坛功能怎么设计 | `modules/forum-design.md` |
| Flutter 代码目录结构 | `reference/flutter-code-structure.md` |
| 服务层有哪些服务 | `reference/services-architecture.md` |
| 如何使用 TDesign 组件 | `reference/tdesign-components.md` |

---

## 文档维护规则

### 新增文档时的存放决策

1. **架构级变更** → `architecture/` （如新增引擎、导航调整、数据库大改）
2. **新模块设计** → `modules/` （如新增论坛、成长体系等独立功能）
3. **代码级知识** → `reference/` （如 API 用法、组件示例、编码规范）
4. **过时文档** → 移入 `expired/`（扁平存放，不再维护）

### 文档与代码一致性原则

- `architecture/` 下的文档是**权威来源**，代码实现应与之一致
- 当代码变更导致文档过时时，**同步更新对应文档**，不要只改代码不更新文档
- 定期（每个迭代）检查 `reference/` 下文档是否与代码一致

### 已知不一致项（待修复）

> 以下为上一轮审查中发现的不一致，将在后续迭代中逐步修正：

1. ~~导航 Tab 数量~~ → 已在 `architecture/overview-V1.1.md` 中统一为 **4 Tab**
2. ~~数据库表数量~~ → 已在 `architecture/database-schema-V2.0.md` 中统一为 **20 表（本地，已移除 article_chapter）+ N 表（云端）**
3. ~~计费体系分散~~ → 已合并到 `database-schema-V2.0.md` 第五章 + `modules/billing-redesign-V1.1.md`
4. ~~database-design.md 与 database-schema-V2.0.md 重叠~~ → 已归档 `database-design-V2.0.md` 到 expired/，保留 `database-schema-V2.0.md` 为唯一权威数据库文档
