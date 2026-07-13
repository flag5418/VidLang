# VidLang Skill 索引

> **版本**: V1.0 | **日期**: 2026-07-12
> **说明**: 本文档列出所有可用的 AI Skill

---

## 一、Skill 列表

| Skill | 文件 | 触发条件 | 说明 |
|-------|------|----------|------|
| 新增模块 | `new-module.md` | 新增模块、创建模块、新模块、添加模块 | 创建完整的功能模块 |
| 实现新功能 | `new-feature.md` | 实现功能、新功能、开发功能、添加功能 | 实现具体的功能需求 |
| 修复 Bug | `fix-bug.md` | 修复 Bug、修复 bug、修 bug、解决问题、修复问题 | 修复代码中的错误 |

---

## 二、Skill 详情

### 2.1 新增模块 (new-module)

**触发条件**：当用户要求新增功能模块时

**工作流**：
1. 规划阶段：理解需求、查阅文档、设计模型、制定计划
2. 实现阶段：创建模型、注册实体、创建服务、创建状态管理、创建页面
3. 验证阶段：运行测试、检查规范、更新文档、提交代码

**检查清单**：
- 数据模型：继承 BaseEntity、实现 tableName、toMap、fromMap
- 服务层：文档注释、异常处理、参数化查询
- 状态管理：Riverpod StateNotifierProvider
- 页面：文档注释、const 构造函数、主题适配
- 文档：更新 AGENTS.md、AGENT_CONTEXT.md、知识库

**知识库加载**：
- 自动加载：overall-architecture.md、flutter-code-structure.md
- 按需加载：database-design.md、services-architecture.md、models-design.md

---

### 2.2 实现新功能 (new-feature)

**触发条件**：当用户要求实现新功能时

**工作流**：
1. 规划阶段：理解需求、查阅规范、设计方案、制定计划
2. 实现阶段：实现模型、实现服务、实现状态管理、实现页面、更新文档
3. 验证阶段：运行测试、检查规范、验证功能、更新文档、提交代码

**检查清单**：
- 功能规范：阅读规范、理解用户故事、理解验收标准
- 数据模型：符合规范、字段命名正确、关系定义正确
- 服务层：职责单一、异常处理、安全操作
- 状态管理：State 完整、Notifier 完整、Provider 正确
- 页面：结构清晰、组件复用、主题适配、交互良好

**知识库加载**：
- 自动加载：overall-architecture.md、flutter-code-structure.md
- 按需加载：database-design.md、services-architecture.md、models-design.md、supabase-integration.md、ai-service-integration.md

---

### 2.3 修复 Bug (fix-bug)

**触发条件**：当用户要求修复 Bug 时

**工作流**：
1. 分析阶段：理解 Bug、复现 Bug、分析原因、评估影响、制定方案
2. 修复阶段：实现修复、编写测试、验证效果、检查规范、更新文档
3. 验证阶段：运行测试、检查回归、更新文档、提交代码

**检查清单**：
- Bug 分析：理解描述、复现步骤、分析原因、评估影响、制定方案
- 修复代码：符合规范、完整注释、测试覆盖、不影响其他功能
- 测试验证：编写用例、覆盖边界、可重复执行、结果正确
- 文档更新：更新 Bug 记录、更新知识库

**知识库加载**：
- 自动加载：overall-architecture.md、flutter-code-structure.md
- 按需加载：database-design.md、services-architecture.md、models-design.md、supabase-integration.md、ai-service-integration.md

---

## 三、使用说明

### 3.1 自动触发

当用户输入包含触发关键词时，opencode 会自动加载对应的 Skill。

例如：
- "帮我新增一个文章模块" → 自动加载 new-module Skill
- "实现一个生词本功能" → 自动加载 new-feature Skill
- "修复这个 bug" → 自动加载 fix-bug Skill

### 3.2 手动触发

也可以在对话中明确指定使用某个 Skill：

```
使用 new-module Skill 帮我创建歌曲模块
```

### 3.3 Skill 工作流

每个 Skill 都定义了完整的工作流，AI 会按照工作流执行任务：

1. **规划阶段**：理解需求、查阅文档、设计方案
2. **实现阶段**：编写代码、创建文件、更新配置
3. **验证阶段**：运行测试、检查规范、更新文档

### 3.4 检查清单

每个 Skill 都提供了检查清单，确保任务完成质量：

- 所有检查项必须通过
- 检查清单可作为验收标准
- 可以自定义检查清单

---

## 四、文件位置

### 4.1 活跃文件（opencode 自动加载）

```
.opencode/skills/
├── new-module.md
├── new-feature.md
└── fix-bug.md
```

### 4.2 参考文件（docs 中的副本）

```
docs/developer/skills/
├── new-module.md
├── new-feature.md
├── fix-bug.md
└── README.md（本文件）
```

---

## 五、配置说明

### 5.1 opencode.json 配置

Skill 在 `opencode.json` 中注册：

```json
{
  "skills": {
    "new-module": {
      "name": "新增模块",
      "description": "当用户要求新增功能模块时使用此 Skill",
      "path": ".opencode/skills/new-module.md",
      "triggers": ["新增模块", "创建模块", "新模块", "添加模块"]
    }
  }
}
```

### 5.2 触发条件配置

每个 Skill 可以配置多个触发关键词：

```json
"triggers": ["关键词1", "关键词2", "关键词3"]
```

当用户输入包含任意一个触发关键词时，对应的 Skill 会被加载。

---

## 六、自定义 Skill

### 6.1 创建新 Skill

1. 在 `.opencode/skills/` 目录下创建新的 Markdown 文件
2. 按照模板编写 Skill 内容
3. 在 `opencode.json` 中注册新 Skill
4. 将文件复制到 `docs/developer/skills/` 作为参考

### 6.2 Skill 模板

```markdown
# Skill: [Skill 名称]

> **版本**: V1.0 | **日期**: YYYY-MM-DD
> **触发条件**: [触发条件描述]

---

## 一、工作流

### 1.1 规划阶段
- [ ] 任务 1
- [ ] 任务 2

### 1.2 实现阶段
- [ ] 任务 1
- [ ] 任务 2

### 1.3 验证阶段
- [ ] 任务 1
- [ ] 任务 2

---

## 二、检查清单

### 2.1 检查项
- [ ] 检查点 1
- [ ] 检查点 2

---

## 三、知识库加载

### 3.1 自动加载
- 文档 1
- 文档 2

### 3.2 按需加载
- 文档 3
- 文档 4

---

## 四、注意事项

1. 注意事项 1
2. 注意事项 2

---

**文档版本**：V1.0
**创建时间**：YYYY-MM-DD
```

---

**文档版本**：V1.0
**创建时间**：2026-07-12
