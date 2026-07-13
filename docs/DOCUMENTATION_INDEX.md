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
│   ├── overview.md            ← 架构总览 + 导航结构 + 技术栈 + 开发阶段
│   └── database-schema.md     ← 数据库设计（22表 ERD + DDL + 计费表）
│
├── modules/                   ← 【模块】各功能模块的详细设计
│   ├── scoring-design.md      ← 跟读/跟唱评分系统设计
│   ├── wordbook-design.md     ← 单词本系统设计
│   ├── test-system-design.md  ← 测试引擎设计
│   ├── ai-conversation-design.md  ← AI 对话系统设计
│   └── billing-redesign.md    ← 计费系统重设计
│
├── reference/                 ← 【参考】代码级知识库（给 AI/开发者查）
│   ├── flutter-code-structure.md   ← Flutter 代码结构详解
│   ├── services-architecture.md    ← 服务层架构（51个服务）
│   ├── database-design.md          ← 数据库设计（完整版，含查询优化）
│   ├── omni-player-integration.md  ← OmniPlayer 集成指南
│   ├── supabase-integration.md     ← Supabase 集成指南
│   ├── ai-service-integration.md   ← AI 服务集成指南
│   ├── tdesign-components.md       ← TDesign 组件使用参考
│   └── design-style-guide.md       ← UI 设计规范
│
└── archive/                   ← 【归档】过时/冗余文档（仅供参考，不再维护）
    ├── detailed-design/       ← 旧版详细设计文档（19个文件）
    ├── code-knowledge-base/   ← 旧版代码知识库（已迁移至 reference/）
    ├── design-templates/      ← Pencil 设计模板（已弃用）
    ├── architecture-old/      ← 旧版架构文档（已合并至 architecture/）
    └── superpowers/           ← 旧版功能规格文档
```

---

## 快速查找指南

| 我想了解... | 查看文档 |
|------------|---------|
| 产品定位、导航结构、技术栈 | `architecture/overview.md` |
| 数据库有哪些表、字段定义 | `architecture/database-schema.md` |
| 评分系统怎么工作 | `modules/scoring-design.md` |
| 单词本两档记忆体系 | `modules/wordbook-design.md` |
| 测试引擎填空/听写/选择 | `modules/test-system-design.md` |
| AI 对话如何实现 | `modules/ai-conversation-design.md` |
| 充值扣费怎么算 | `modules/billing-redesign.md` |
| Flutter 代码目录结构 | `reference/flutter-code-structure.md` |
| 服务层有哪些服务 | `reference/services-architecture.md` |
| 如何使用 TDesign 组件 | `reference/tdesign-components.md` |

---

## 文档维护规则

### 新增文档时的存放决策

1. **架构级变更** → `architecture/` （如新增引擎、导航调整、数据库大改）
2. **新模块设计** → `modules/` （如新增论坛、成长体系等独立功能）
3. **代码级知识** → `reference/` （如 API 用法、组件示例、编码规范）
4. **过时文档** → 移入 `archive/` 并在本文档中标注

### 文档与代码一致性原则

- `architecture/` 下的文档是**权威来源**，代码实现应与之一致
- 当代码变更导致文档过时时，**同步更新对应文档**，不要只改代码不更新文档
- 定期（每个迭代）检查 `reference/` 下文档是否与代码一致

### 已知不一致项（待修复）

> 以下为上一轮审查中发现的不一致，将在后续迭代中逐步修正：

1. ~~导航 Tab 数量~~ → 已在 `architecture/overview.md` 中统一为 **4 Tab**
2. ~~数据库表数量~~ → 已在 `architecture/database-schema.md` 中统一为 **22 表**
3. ~~计费体系分散~~ → 已合并到 `database-schema.md` 第五章
