# 文档维护检查清单

> **版本**: v1.0.0
> **创建日期**: 2026-07-12
> **执行频率**: 每月一次

---

## 📋 使用说明

此文档用于定期检查项目文档的一致性和时效性。建议在每月的第一个工作日执行。

## ✅ 检查项目

### 1. 知识库文档更新

| 检查项 | 状态 | 备注 |
|--------|------|------|
| `services-architecture.md` 是否反映最新服务结构 | ⬜ | |
| `state-management-guide.md` 是否包含新 Provider | ⬜ | |
| `tdesign-components.md` 是否包含最新组件用法 | ⬜ | |
| `omni-player-integration.md` API 是否与代码一致 | ⬜ | |
| `supabase-integration.md` Edge Functions 列表是否完整 | ⬜ | |
| `ai-service-integration.md` rule_code 是否最新 | ⬜ | |
| `theme-system.md` Design Tokens 是否有新增 | ⬜ | |
| `development-setup.md` 依赖版本是否更新 | ⬜ | |

### 2. 代码与文档一致性

| 检查项 | 状态 | 备注 |
|--------|------|------|
| 新增的 Service 是否已记录到 services-architecture | ⬜ | |
| 新增的 Provider 是否已记录到 state-management-guide | ⬜ | |
| 新增的 Model 字段是否有注释说明 | ⬜ | |
| 废弃的 API 是否已在文档中标记 | ⬜ | |
| TDesign 组件使用是否符合规范（tdesign-components.md） | ⬜ | |

### 3. 文档索引更新

| 检查项 | 状态 | 备注 |
|--------|------|------|
| `DOCUMENTATION_INDEX.md` 链接是否有效 | ⬜ | |
| 新文档是否已添加到索引 | ⬜ | |
| 已删除文档是否已从索引移除 | ⬜ | |
| 状态标记（✅/⏳）是否准确 | ⬜ | |

### 4. 归档清理

| 检查项 | 状态 | 备注 |
|--------|------|------|
| 超过 6 个月的临时文档是否归档 | ⬜ | |
| `archive/ARCHIVE_INDEX.md` 是否更新 | ⬜ | |
| 重复文档是否合并或删除 | ⬜ | |

### 5. TDesign 规范执行情况

| 检查项 | 数量 | 备注 |
|--------|------|------|
| 原生 AlertDialog 使用次数 | ___ | 目标: 0 |
| 原生 ElevatedButton 使用次数 | ___ | 目标: 0 (除 app_dialogs.dart) |
| 原生 SnackBar 使用次数 | ___ | 目标: 0 |
| 原生 CircularProgressIndicator 使用次数 | ___ | 目标: 0 |
| 原生 AppBar 使用次数 | ___ | 目标: 0 |
| 原生 TextField 使用次数 | ___ | 目标: 0 |

---

## 📊 月度报告模板

```markdown
# 文档维护报告 - YYYY-MM

## 执行时间
- 日期: YYYY-MM-DD
- 执行人: @username

## 完成情况
- ✅ 已完成: X/Y 项
- ⚠️ 需要关注: X 项
- ❌ 未完成: X 项

## 主要发现
1. ...
2. ...

## 待办事项
- [ ] ...
- [ ] ...

## 下月计划
- ...
```

---

## 🔧 快速修复脚本

### 检查无效链接

```bash
# 在 docs 目录下运行，查找所有失效的 markdown 链接
find . -name "*.md" -exec grep -H '\[.*\](.*\.md)' {} \; | \
  while read line; do
    link=$(echo "$line" | grep -oP '\(\K[^)]+\.md')
    if [ ! -f "$(dirname "$line")/$link" ]; then
      echo "BROKEN: $line"
    fi
  done
```

### 检查未记录的新文件

```bash
# 查找最近 30 天修改但未在索引中提及的文件
find lib -name "*.dart" -mtime -30 -type f | \
  while read file; do
    if ! grep -q "$(basename $file)" docs/DOCUMENTATION_INDEX.md; then
      echo "NEW FILE: $file"
    fi
  done
```

---

## 📞 问题反馈

如发现文档问题或建议改进：
1. 在本文件底部添加评论
2. 或提交 Issue 到项目仓库

---

## 📝 维护历史

| 日期 | 执行人 | 完成率 | 主要变更 |
|------|--------|--------|----------|
| 2026-07-12 | AI Assistant | 100% | 初始创建 |
| | | | |
