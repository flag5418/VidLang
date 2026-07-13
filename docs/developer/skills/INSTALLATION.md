# VidLang Skill 安装完成

> **版本**: V1.0 | **日期**: 2026-07-12
> **状态**: 已完成

---

## 安装总结

### 已完成的工作

#### 1. 创建了 3 个核心 Skill

| Skill | 文件 | 触发条件 |
|-------|------|----------|
| 新增模块 | `new-module.md` | 新增模块、创建模块、新模块、添加模块 |
| 实现新功能 | `new-feature.md` | 实现功能、新功能、开发功能、添加功能 |
| 修复 Bug | `fix-bug.md` | 修复 Bug、修复 bug、修 bug、解决问题、修复问题 |

#### 2. 配置了 opencode.json

- 注册了所有 Skill
- 配置了触发条件
- 配置了知识库自动加载
- 配置了规则自动加载

#### 3. 创建了文档结构

```
.opencode/skills/              # 活跃文件（opencode 自动加载）
├── new-module.md
├── new-feature.md
└── fix-bug.md

docs/developer/skills/         # 参考文件（docs 中的副本）
├── new-module.md
├── new-feature.md
├── fix-bug.md
└── README.md                  # Skill 索引文档
```

---

## 使用方法

### 1. 自动触发

当用户输入包含触发关键词时，opencode 会自动加载对应的 Skill。

**示例**：

```
用户：帮我新增一个文章模块
→ 自动加载 new-module Skill
→ 按照工作流执行任务
→ 提供检查清单验证完成质量
```

```
用户：实现一个生词本功能
→ 自动加载 new-feature Skill
→ 按照工作流执行任务
→ 提供检查清单验证完成质量
```

```
用户：修复这个 bug
→ 自动加载 fix-bug Skill
→ 按照工作流执行任务
→ 提供检查清单验证完成质量
```

### 2. 手动触发

也可以在对话中明确指定使用某个 Skill：

```
使用 new-module Skill 帮我创建歌曲模块
```

### 3. 查看可用 Skill

查看 `docs/developer/skills/README.md` 了解所有可用的 Skill。

---

## Skill 工作流

每个 Skill 都定义了完整的工作流，确保任务完成质量：

### 1. 规划阶段

- 理解用户需求
- 查阅相关知识库文档
- 设计技术方案
- 制定实施计划

### 2. 实现阶段

- 编写代码
- 创建文件
- 更新配置
- 更新文档

### 3. 验证阶段

- 运行测试
- 检查代码规范
- 验证功能完整性
- 更新知识库
- 提交代码

---

## 检查清单

每个 Skill 都提供了检查清单，确保任务完成质量：

### 新增模块检查清单

- [ ] 数据模型继承 BaseEntity
- [ ] 实现 tableName getter
- [ ] 实现 toMap() 方法
- [ ] 实现 fromMap() 方法
- [ ] 服务类有完整文档注释
- [ ] 异步方法处理异常
- [ ] 使用 Riverpod StateNotifierProvider
- [ ] 页面有完整文档注释
- [ ] 支持主题适配
- [ ] 更新 AGENTS.md
- [ ] 更新 AGENT_CONTEXT.md
- [ ] 更新知识库文档

### 实现新功能检查清单

- [ ] 阅读功能规范文档
- [ ] 理解用户故事
- [ ] 理解验收标准
- [ ] 模型符合规范
- [ ] 服务职责单一
- [ ] State 定义完整
- [ ] 页面结构清晰
- [ ] 更新功能规范
- [ ] 更新知识库

### 修复 Bug 检查清单

- [ ] 理解 Bug 描述
- [ ] 复现 Bug 步骤
- [ ] 分析根本原因
- [ ] 评估影响范围
- [ ] 修复代码符合规范
- [ ] 编写测试用例
- [ ] 测试用例覆盖边界情况
- [ ] 更新 Bug 记录
- [ ] 更新知识库

---

## 知识库加载

### 自动加载

每次会话自动加载以下知识库：

- `overall-architecture.md` - 整体架构
- `flutter-code-structure.md` - 代码结构
- `AGENT_CONTEXT.md` - AI 上下文速查

### 按需加载

根据任务类型按需加载：

- `database-design.md` - 数据库设计
- `services-architecture.md` - 服务架构
- `models-design.md` - 数据模型设计
- `supabase-integration.md` - Supabase 集成
- `ai-service-integration.md` - AI 服务集成

---

## 配置说明

### opencode.json 配置

```json
{
  "skills": {
    "skill-name": {
      "name": "Skill 显示名称",
      "description": "Skill 描述",
      "path": ".opencode/skills/skill-file.md",
      "triggers": ["触发关键词1", "触发关键词2"]
    }
  }
}
```

### 触发条件配置

- 每个 Skill 可以配置多个触发关键词
- 当用户输入包含任意一个触发关键词时，对应的 Skill 会被加载
- 触发关键词不区分大小写

---

## 自定义 Skill

### 创建新 Skill 的步骤

1. 在 `.opencode/skills/` 目录下创建新的 Markdown 文件
2. 按照模板编写 Skill 内容
3. 在 `opencode.json` 中注册新 Skill
4. 将文件复制到 `docs/developer/skills/` 作为参考

### Skill 模板

参考 `docs/developer/skills/README.md` 中的模板。

---

## 验证安装

运行以下命令验证安装是否成功：

```bash
# 检查 Skill 文件是否存在
ls -la .opencode/skills/

# 检查配置文件是否存在
cat opencode.json

# 检查文档是否存在
ls -la docs/developer/skills/
```

---

## 下一步

1. **测试 Skill**：尝试使用触发关键词测试 Skill 是否正常工作
2. **自定义 Skill**：根据项目需求创建更多 Skill
3. **完善知识库**：补充更多知识库文档
4. **优化工作流**：根据实际使用情况优化 Skill 工作流

---

## 相关文档

| 文档 | 路径 | 说明 |
|------|------|------|
| Skill 索引 | `docs/developer/skills/README.md` | 所有可用 Skill 的索引 |
| 知识库索引 | `docs/knowledge-base-index.yaml` | 知识库文档索引 |
| AGENTS.md | `AGENTS.md` | AI 自动加载的核心规则 |
| opencode.json | `opencode.json` | opencode 配置文件 |

---

**文档版本**：V1.0
**创建时间**：2026-07-12
