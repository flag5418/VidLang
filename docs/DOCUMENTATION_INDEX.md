# VidLang - 文档索引

> **最后更新**: 2026-07-12  
> **版本**: V2.0
> **用途**: 快速查找项目文档，了解文档组织结构

---

## 一、文档导航

### 1.1 必读文档（按优先级排序）

| 优先级 | 文档 | 路径 | 说明 |
|--------|------|------|------|
| ⭐⭐⭐ | **项目全局规则** | `/项目全局规则.md` | 最高规范，所有开发者必须遵守 |
| ⭐⭐⭐ | **AI 上下文速查** | `AGENT_CONTEXT.md` | AI/Cursor 快速恢复项目认知 |
| ⭐⭐ | **代码知识库** | `developer/design/code-knowledge-base/README.md` | 结构化技术知识库 |
| ⭐⭐ | **开发规范** | `DEVELOPMENT.md` | 注释、命名、Git 规范 |
| ⭐ | **整体架构** | `developer/architecture/overall-architecture.md` | 三引擎架构、产品定位 |
| ⭐ | **设计风格指南** | `developer/design/design-style-guide.md` | UI/UX 规范 |

### 1.2 文档分类索引

#### 📋 项目管理

| 文档 | 路径 | 说明 |
|------|------|------|
| 项目全局规则 | `/项目全局规则.md` | 目录结构、命名规范、文档管理 |
| README（外部） | `/README.md` | 面向外部开发者的项目简介 |
| 文档索引（本文件） | `DOCUMENTATION_INDEX.md` | 文档导航和快速查找 |

#### 🏗️ 架构设计 (`developer/architecture/`)

| 文档 | 路径 | 说明 |
|------|------|------|
| 整体架构 | `developer/architecture/overall-architecture.md` | 产品定位、三引擎架构、技术栈 |
| AI 计费体系与 Edge Function 架构 | `developer/architecture/AI 计费体系与 Edge Function 架构设计.md` | Supabase Edge Functions 设计 |
| 用户与计费体系 | `developer/architecture/用户与计费体系.md` | 付费模式设计 |
| 多区域技术计划 | `developer/architecture/multi-region-technical-plan.md` | 国际化技术方案 |

#### 🎨 产品/技术设计 (`developer/design/`)

| 文档 | 路径 | 说明 |
|------|------|------|
| 设计风格指南 | `developer/design/design-style-guide.md` | UI/UX 视觉规范 |
| UI 重构计划 | `developer/design/ui-redesign-plan.md` | UI 改版方案 |
| UI 重构总结 | `developer/design/ui-redesign-phase1-summary.md` | Phase 1 总结 |
| 文章学习设计 | `developer/design/article-study-design.md` | 文章学习功能设计 |
| URL 导入功能 | `developer/design/article-url-import.md` | URL 导入实现方案 |
| 战略指导方针 | `developer/design/strategic-guideline.md` | 产品战略方向 |
| 市场分析优先级 | `developer/design/market-analysis-priority.md` | 功能优先级排序 |
| 优化提案 | `developer/design/optimization-proposals.md` | 技术优化建议汇总 |

#### 📚 代码知识库 (`developer/design/code-knowledge-base/`) ⭐ 核心

| 文档 | 路径 | 说明 |
|------|------|------|
| 知识库入口 | `developer/design/code-knowledge-base/README.md` | 知识库总览和快速入门 |
| Flutter 代码结构 | `developer/design/code-knowledge-base/flutter-code-structure.md` | lib/ 目录详解、各层职责 |
| 数据库设计 | `developer/design/code-knowledge-base/database-design.md` | 表结构、字段规范、FTS5、迁移 |
| 服务层架构 | `developer/design/code-knowledge-base/services-architecture.md` | 服务层设计与 API 模式 |
| 状态管理指南 | `developer/design/code-knowledge-base/state-management-guide.md` | Riverpod 状态管理模式 |
| TDesign 组件库 | `developer/design/code-knowledge-base/tdesign-components.md` | TDesign Flutter 组件使用指南 |
| OmniPlayer 集成 | `developer/design/code-knowledge-base/omni-player-integration.md` | 视频播放器集成指南 |
| Supabase 集成 | `developer/design/code-knowledge-base/supabase-integration.md` | 后端服务集成完整指南 |
| AI 服务集成 | `developer/design/code-knowledge-base/ai-service-integration.md` | AI 服务集成（云端+本地） |
| 主题系统 | `developer/design/code-knowledge-base/theme-system.md` | Design Tokens + 双模式主题 |
| 开发环境配置 | `developer/design/code-knowledge-base/development-setup.md` | 开发环境搭建与快速开始 |

#### 🤖 AI 相关文档 (`developer/ai-guides/`)

| 文档 | 路径 | 说明 |
|------|------|------|
| AI Prompt 优化 | `developer/ai-guides/ai-prompt-optimization-v2.md` | Prompt 工程最佳实践 |
| AI 测试计划 V4 | `developer/ai-guides/ai-test-plan-v4-redesign.md` | AI 翻译质量测试方案 |
| AI 测试修复报告 | `developer/ai-guides/ai-test-plan-v3-fix-report.md` | 测试问题修复记录 |
| AI 翻译质量测试计划 | `developer/ai-guides/ai-translation-quality-test-plan.md` | 翻译质量评估方案 |
| AI 翻译测试结果 V2 | `developer/ai-guides/ai-translation-test-result-v2.txt` | 测试结果数据 |
| AI 翻译测试结果 | `developer/ai-guides/ai-translation-test-result.txt` | 初始测试结果 |
| 评测实现文档 | `developer/ai-guides/EVALUATION_IMPLEMENTATION.md` | 语音评测功能实现 |
| 视频播放评估 | `developer/ai-guides/video-playback-evaluation.md` | 播放器选型评估 |

#### 🔧 开发环境配置 (`developer/setup/`)

| 文档 | 路径 | 说明 |
|------|------|------|
| 集成指南 | `developer/setup/INTEGRATION_GUIDE.md` | 模块集成指南 |
| 部署指南 V4 | `developer/setup/V4-DEPLOYMENT-GUIDE.md` | 应用部署流程 |
| Flutter i18n 分析 | `developer/setup/flutter-i18n-analysis.md` | 国际化方案分析 |
| Phase 2 单词缓存扩展 | `developer/setup/phase2-word-cache-extension.md` | Phase 2 功能规划 |
| Phase 3 Agent 开发 | `developer/setup/phase3-agent-development.md` | AI Agent 开发规划 |
| 单词缓存实现 | `developer/setup/word-cache-implementation.md` | 单词缓存机制实现 |

#### 🎨 设计稿与页面说明

| 目录/文件 | 路径 | 说明 |
|-----------|------|------|
| 设计稿目录 | `designs/` | Pencil 格式的 UI 设计稿 |
| 详细设计目录 | `detailed-design/` | 页面级别的详细设计文档（01-19） |
| 页面说明目录 | `pages/` | 各页面的交互和功能说明 |

#### 🤖 AI Agent 能力 (`superpowers/`)

| 目录/文件 | 路径 | 说明 |
|-----------|------|------|
| 实现计划 | `superpowers/plans/` | 功能实现计划 |
| 技术规格 | `superpowers/specs/` | 详细技术规格文档 |

#### 🔌 第三方集成 (`声通/`)

| 文件 | 路径 | 说明 |
|------|------|------|
| PPT 内容 | `声通/ppt_content.txt` | 声通语音评测演示内容 |
| 演示文稿 | `声通/声通语音评测引擎 - 英文案例.pptx` | 声通评测引擎介绍 |

#### 🗂️ 归档文档 (`developer/archive/`)

| 目录 | 路径 | 说明 |
|------|------|------|
| 过期文档归档 | `developer/archive/` | 已过期的旧版本文档备份 |
| 归档索引 | `developer/archive/ARCHIVE_INDEX.md` | 归档文档清单 |

---

## 二、目录结构规范

### 2.1 标准目录结构

```
docs/
├── AGENT_CONTEXT.md              # AI 上下文速查（最高优先级）
├── DEVELOPMENT.md                # 开发规范
├── DOCUMENTATION_INDEX.md        # 文档索引（本文件）
├── README.md                     # 文档说明
│
├── developer/                    # 开发者文档
│   ├── MAINTENANCE_CHECKLIST.md  # 维护检查清单
│   ├── architecture/             # 架构设计文档
│   ├── design/                   # 产品/技术设计文档
│   │   └── code-knowledge-base/  # 代码知识库 ⭐
│   ├── ai-guides/                # AI 相关文档
│   ├── setup/                    # 开发环境配置
│   └── archive/                  # 过期文档归档
│
├── designs/                      # UI 设计稿（Pencil 格式）
├── detailed-design/              # 详细设计文档（页面级别）
├── pages/                        # 页面交互说明
├── superpowers/                  # AI Agent 能力文档
└── 声通/                         # 第三方集成文档
```

### 2.2 文档存放决策树

```
新增文档？
│
├─ 是架构设计？      → docs/developer/architecture/
├─ 是产品设计？      → docs/developer/design/
├─ 是代码知识库？    → docs/developer/design/code-knowledge-base/
├─ 是 AI 相关？      → docs/developer/ai-guides/
├─ 是开发环境配置？   → docs/developer/setup/
├─ 是已过期？        → docs/developer/archive/
├─ 是 UI 设计稿？    → docs/designs/
├─ 是页面详细设计？  → docs/detailed-design/
├─ 是 AI Agent？     → docs/superpowers/
└─ 是第三方集成？    → docs/{集成方名称}/
```

---

## 三、更新日志

### 2026-07-12 V2.0（重大重组）

**✅ 完成的整理工作：**

1. **建立标准目录结构**
   - ✅ 创建 `developer/architecture/` - 架构设计文档（4 个文件）
   - ✅ 创建 `developer/design/` - 产品/技术设计文档（8 个文件）
   - ✅ 创建 `developer/ai-guides/` - AI 相关文档（8 个文件）
   - ✅ 创建 `developer/setup/` - 开发环境配置（6 个文件）
   - ✅ 整理 `developer/archive/` - 过期文档归档（11 个文件）

2. **移动的文档清单**
   
   **架构设计 (→ developer/architecture/)**
   - `overall-architecture.md`
   - `AI 计费体系与 Edge Function 架构设计.md`
   - `用户与计费体系.md`
   - `multi-region-technical-plan.md`

   **产品设计 (→ developer/design/)**
   - `design-style-guide.md`
   - `article-study-design.md`
   - `article-url-import.md`
   - `strategic-guideline.md`
   - `market-analysis-priority.md`
   - `ui-redesign-plan.md`
   - `ui-redesign-phase1-summary.md`
   - `optimization-proposals.md`

   **AI 相关 (→ developer/ai-guides/)**
   - `ai-prompt-optimization-v2.md`
   - `ai-test-plan-v3-fix-report.md`
   - `ai-test-plan-v4-redesign.md`
   - `ai-translation-quality-test-plan.md`
   - `ai-translation-test-result-v2.txt`
   - `ai-translation-test-result.txt`
   - `EVALUATION_IMPLEMENTATION.md`
   - `video-playback-evaluation.md`

   **开发配置 (→ developer/setup/)**
   - `INTEGRATION_GUIDE.md`
   - `V4-DEPLOYMENT-GUIDE.md`
   - `flutter-i18n-analysis.md`
   - `phase2-word-cache-extension.md`
   - `phase3-agent-development.md`
   - `word-cache-implementation.md`

   **归档文档 (→ developer/archive/)**
   - `IMPLEMENTATION_SUMMARY.md`
   - `FINAL_IMPLEMENTATION_REPORT.md`
   - `FORUM_TEST_REPORT.md`
   - `forum_fix_summary.md`
   - `full-module-function-analysis.md`
   - `hy-mt2-comparison.md`
   - `REAL_TIME_INTEGRATION.md`
   - `TEST-NOTIFICATION.md`
   - `COMPILATION_STATUS.md`
   - `上架行动清单.md`
   - `支付与上架准备.md`

3. **更新文档索引**
   - ✅ 更新所有文档路径链接
   - ✅ 添加目录结构规范说明
   - ✅ 添加文档存放决策树
   - ✅ 更新快速导航表格

---

## 四、维护规范

### 4.1 更新责任

| 文档类型 | 维护者 | 更新频率 |
|----------|--------|----------|
| 项目全局规则 | Tech Lead | 重大变更时 |
| AGENT_CONTEXT.md | 全体开发者 | 每次功能变更后 |
| 代码知识库 | Feature Owner | 新模块开发完成后 |
| 本索引文档 | Doc Owner | 目录结构调整时 |

### 4.2 版本管理

- 设计文档使用版本号：`文档名-V{版本}.md`
- 代码知识库文档在文件头标注版本和日期
- 修改前备份旧版本到 `developer/archive/`

### 4.3 一致性检查

**每月例行检查项：**
- [ ] 技术栈描述是否与 `pubspec.yaml` 一致
- [ ] 数据库表结构是否与代码一致
- [ ] 目录结构描述是否与实际一致
- [ ] API 接口文档是否与最新代码一致
- [ ] 本文档索引链接是否有效

> 📋 **完整维护清单**: [`MAINTENANCE_CHECKLIST.md`](developer/MAINTENANCE_CHECKLIST.md)  
> 📦 **归档文档索引**: [`ARCHIVE_INDEX.md`](developer/archive/ARCHIVE_INDEX.md)

---

## 五、快速链接

### 5.1 内部文档

- **项目根目录**: `/Volumes/Expand/wangqingquan/Documents/work/study/flutter/vidlang`
- **文档目录**: `/docs`
- **知识库目录**: `/docs/developer/design/code-knowledge-base`
- **最高规范**: `/项目全局规则.md`

### 5.2 外部资源

| 资源 | 地址 |
|------|------|
| Flutter 官方文档 | https://docs.flutter.dev/ |
| Riverpod 文档 | https://riverpod.dev/ |
| Supabase 文档 | https://supabase.com/docs |
| TDesign Flutter | https://github.com/Tencent/tdesign-flutter |
| DeepSeek API | https://platform.deepseek.com/api-docs |

---

## 六、反馈与贡献

发现文档错误或有过时信息？
- 在项目中直接修改并提交 PR
- 或联系维护者进行更新

**文档维护者**: VidLang 开发团队  
**最后更新时间**: 2026-07-12（V2.0 重大重组：按项目全局规则整理文档目录结构）
