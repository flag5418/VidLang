# 文档归档索引

> **最后更新**: 2026-07-12
> **说明**: 此目录存放已过时或不再活跃维护的文档

---

## 归档文档列表

### 已归档文档（按时间倒序）

| 文档名 | 原位置 | 归档日期 | 归档原因 |
|--------|--------|----------|----------|
| `COMPILATION_STATUS.md` | `docs/` | 2026-07-12 | 编译状态快照，已过时 |
| `FORUM_TEST_REPORT.md` | `docs/` | 2026-07-12 | 论坛测试报告，已完成 |
| `IMPLEMENTATION_SUMMARY.md` | `docs/` | 2026-07-12 | 实现总结，已被知识库替代 |
| `INTEGRATION_GUIDE.md` | `docs/` | 2026-07-12 | 集成指南，内容分散到各知识库 |
| `TEST-NOTIFICATION.md` | `docs/` | 2026-07-12 | 测试通知，临时文档 |
| `V4-DEPLOYMENT-GUIDE.md` | `docs/` | 2026-07-12 | V4 部署指南，版本已更新 |
| `ai-test-plan-v3-fix-report.md` | `docs/` | 2026-07-12 | AI 测试计划 v3 报告，已结束 |
| `ai-test-plan-v4-redesign.md` | `docs/` | 2026-07-12 | AI 测试计划 v4 重设计，已实施 |
| `ai-translation-test-result-v2.txt` | `docs/` | 2026-07-12 | 翻译测试结果 v2，历史数据 |
| `ai-translation-test-result.txt` | `docs/` | 2026-07-12 | 翻译测试结果 v1，历史数据 |
| `forum_fix_summary.md` | `docs/` | 2026-07-12 | 论坛修复总结，已完成 |
| `hy-mt2-comparison.md` | `docs/` | 2026-07-12 | MT 对比分析，历史参考 |
| `ui-redesign-phase1-summary.md` | `docs/` | 2026-07-12 | UI 重设计阶段总结，已完成 |
| `ui-redesign-plan.md` | `docs/` | 2026-07-12 | UI 重设计计划，已执行 |

### 待归档文档

以下文档仍在使用中，但建议在下次大版本更新时归档：

| 文档名 | 当前位置 | 建议 | 备注 |
|--------|----------|------|------|
| `AGENT_CONTEXT.md` | `docs/` | 归档或删除 | AI Agent 上下文，可能已过时 |
| `DEVELOPMENT.md` | `docs/` | 合并到 knowledge-base | 开发指南，与 development-setup 重叠 |
| `EVALUATION_IMPLEMENTATION.md` | `docs/` | 归档 | 评测实现，已完成 |
| `FINAL_IMPLEMENTATION_REPORT.md` | `docs/` | 归档 | 最终实现报告，历史记录 |
| `REAL_TIME_INTEGRATION.md` | `docs/` | 合并到 supabase-integration | 实时集成，部分内容重复 |

---

## 归档规则

### 自动归档条件
- 文档最后修改时间超过 6 个月
- 文档内容被新文档完全替代
- 临时性文档（测试报告、会议记录等）

### 归档流程
1. 将文档移动到 `archive/` 目录
2. 在此文件中添加记录
3. 更新 `DOCUMENTATION_INDEX.md`
4. 如有替代文档，添加引用链接

### 恢复流程
如需恢复归档文档：
1. 从 `archive/` 移回原位置
2. 更新此文件的归档记录
3. 标记为"已恢复"
