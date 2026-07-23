# VidLang AI 工程化优化方案

> **版本**: V1.0 | **日期**: 2026-07-22
> **状态**: 当前有效

---

## 一、背景

VidLang 项目使用多款 AI 编程工具协同开发：OpenCode、CatPaw、Trae、Marvis。各工具的配置文件格式不同，规则分散，缺少统一的"单一事实来源"。

本次优化目标：
1. 建立以 `AGENTS.md` 为核心的统一规则体系
2. 安装 Superpowers 工作流框架提升 AI 输出质量
3. 为每款工具创建适配配置，指向同一份规范

---

## 二、工具配置总览

| 工具 | 类型 | 配置文件路径 | 格式 |
|------|------|-------------|------|
| **OpenCode** | CLI AI Agent | `opencode.json` + `AGENTS.md` + `.opencode/skills/*.md` | JSON + Markdown |
| **CatPaw** | AI IDE (美团) | `.catpaw/commands/*.md` | Markdown 命令 |
| **Trae** | AI IDE (字节) | `.trae/rules/project_rules.md` | Markdown 规则 |
| **Marvis** | OS 级 AI 助手 (腾讯) | 无项目级配置，依赖 `AGENTS.md` | Markdown |

### 统一策略

```
AGENTS.md（单一事实来源）
  ├── opencode.json（引用 + skills）
  ├── .opencode/skills/*.md（OpenCode 专用 skill）
  ├── .trae/rules/project_rules.md（Trae 适配 + 指向 AGENTS.md）
  ├── .catpaw/commands/*.md（CatPaw 命令 + 指向 AGENTS.md）
  └── Marvis（直接读取 AGENTS.md）
```

---

## 三、Superpowers 集成

### 3.1 安装方式

在 `opencode.json` 的 `plugin` 数组中添加：

```json
{
  "plugin": ["superpowers@git+https://github.com/obra/superpowers.git"]
}
```

重启 OpenCode 后自动安装。验证方式：询问 "Tell me about your superpowers"。

### 3.2 可用 Agent

| Agent | 用途 |
|-------|------|
| `@brainstorm` | Socratic 追问式需求澄清与设计 |
| `@tdd` | 测试驱动开发（RED-GREEN-REFACTOR） |
| `@debug` | 系统化调试（观察→假设→验证→修复） |
| `@planner` | 创建详细实施计划与任务分解 |
| `@review` | 代码审查 |
| `@verify` | 证据优先的完成验证 |

### 3.3 Skill 优先级

```
项目 skills（.opencode/skills/） > 个人 skills（~/.config/opencode/skills/） > Superpowers skills
```

VidLang 已有的 3 个中文 skill 优先级最高，Superpowers skill 作为补充。

---

## 四、优化清单

### P0 — 基础设施

- [x] 安装 Superpowers 插件
- [x] 创建 Trae 项目规则 `.trae/rules/project_rules.md`
- [x] 完善 CatPaw 命令 `.catpaw/commands/`
- [ ] 重启 OpenCode 使插件生效
- [ ] 验证 Superpowers agent 可用（`@brainstorm`, `@tdd` 等）

### P1 — 代码健康度

- [ ] 拆分 `article_reader_page.dart`（2809 行 → logic + widgets）
- [ ] 拆分 `profile_page.dart`（1402 行 → logic + widgets）
- [ ] 删除 `file_list_page.dart.bak`
- [ ] 清理或填充空的 `lib/views/settings/`

### P2 — 技能体系增强

- [ ] 新增英文 trigger words（现有 skill 增加英文关键词）
- [ ] 新增 `code-review.md` skill
- [ ] 新增 `test-driven.md` skill
- [ ] 利用 Superpowers 的 `brainstorming` + `writing-plans` 做新模块设计

### P3 — 文档精简

- [ ] 评估 59 份过期文档，删除确实无用的
- [ ] 删除 `docs/developer/skills/`（与 `.opencode/skills/` 重复）
- [ ] 评估 `项目全局规则.md` 是否可归档（已被 AGENTS.md V2.0 取代）

---

## 五、工具使用速查

### OpenCode

```bash
# 交互模式
opencode

# 列出可用 skill
(native skill tool)

# 加载 Superpowers agent
@brainstorm 我想添加实时翻译功能
@tdd 帮我实现重试函数
@review 审查这个认证模块
```

### CatPaw

项目命令位于 `.catpaw/commands/`：
- `project-rules` — 加载项目规范
- `new-module` — 按规范创建新模块

### Trae

项目规则位于 `.trae/rules/project_rules.md`，Trae IDE 会自动读取。
完整规范请参阅根目录 `AGENTS.md`。

### Marvis

Marvis 作为 OS 级 AI 助手，推荐在对话中提供：
1. 项目根目录的 `AGENTS.md` 作为上下文
2. 或直接在对话中引用关键规范

---

## 六、相关文档

| 文档 | 路径 |
|------|------|
| AI 协作规范 | `AGENTS.md` |
| 文档总索引 | `docs/DOCUMENTATION_INDEX.md` |
| OpenCode 规则 | `opencode.json` |
| Superpowers 文档 | 仓库 `docs/README.opencode.md` |
| Trae 规则文档 | `docs.trae.ai/ide/rules` |

---

**文档版本**: V1.0
**更新时间**: 2026-07-22
**变更**: 初始版本，记录 AI 工程化优化方案
