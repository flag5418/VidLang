# ✅ V4 AI 出题系统 - 测试通知

**时间**: 2026-06-29
**状态**: 🎉 代码开发完成，待你执行部署和测试

---

## 🎯 你需要做的事情（3 步，约 10 分钟）

### ⏱️ Step 1: 执行数据库 Migration（2 分钟）

📍 **位置**: Supabase Dashboard → SQL Editor

📋 **操作**:
1. 打开: https://supabase.com/dashboard
2. 选择项目: **VideoLearnEnglish**
3. 左侧菜单 → **SQL Editor**
4. 点击 **New Query**
5. 复制这个文件内容并粘贴:
   ```
   supabase/migrations/20260629000002_extend_word_cache_for_v4.sql
   ```
   或者直接复制下面的 SQL:

```sql
ALTER TABLE word_cache
  ADD COLUMN IF NOT EXISTS synonyms TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS antonyms TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'other',
  ADD COLUMN IF NOT EXISTS morphology_adverb VARCHAR(100),
  ADD COLUMN IF NOT EXISTS morphology_noun VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_word_cache_category ON word_cache(category);
CREATE INDEX IF NOT EXISTS idx_word_cache_synonyms ON word_cache USING gin(synonyms);

UPDATE word_cache
SET synonyms = COALESCE(synonyms, '{}'),
    antonyms = COALESCE(antonyms, '{}'),
    category = COALESCE(category, 'other')
WHERE synonyms IS NULL OR antonyms IS NULL OR category IS NULL;
```

6. 点击 **Run** ▶️
7. 看到 `✅ Migration 完成！` 即成功

---

### 📦 Step 2: 部署 Edge Functions（3 分钟）

📍 **位置**: 终端 (Terminal)

📋 **执行命令**:
```bash
cd /Volumes/Expand/wangqingquan/Documents/work/study/flutter/vidlang/supabase

# 部署核心函数
supabase functions deploy ai-test-plan --no-verify-jwt
supabase functions deploy word-cache --no-verify-jwt
supabase functions deploy ai-proxy --no-verify-jwt
```

✅ 每个看到 `Deployed Function` 即为成功

---

### 🔄 Step 3: 刷新 word_cache 数据（5 分钟，可选但推荐）

这一步会让已有单词补充 V4 新字段（同义词、反义词等）。

📋 **执行命令**:
```bash
# 先预览（Dry Run）
curl -X POST "https://你的project-ref.supabase.co/functions/v1/word-cache?action=refresh" \
  -H "Authorization: Bearer 你的service-role-key" \
  -d '{"limit": 50, "dry_run": true}'

# 确认后正式执行
curl -X POST "https://你的project-ref.supabase.co/functions/v1/word-cache?action=refresh" \
  -H "Authorization: Bearer 你的service-role-key" \
  -d '{"limit": 100, "dry_run": false}'
```

> 💡 如果找不到 service-role-key，可以跳过这步，系统会在出题时自动补充

---

## 🧪 测试要点

完成上述步骤后，请按以下顺序测试：

### 🔥 必测项（优先级高）

#### 1️⃣ MCQ 选择题（V4 Agent 核心功能）
- **配置**: `mcq_count: 5`, `difficulty: intermediate`
- **预期改进**:
  - ✅ 干扰项与目标词**同词性**（不再出现名词干扰动词题）
  - ✅ 干扰项包含**同义词/反义词/词形变化**
  - ✅ 有 **hint** 和 **feedback** 字段
- **检查清单**:
  - [ ] 选项是否都是合理的单词？
  - [ ] 是否有明显的答案泄露？
  - [ ] hint 是否有用但不直接给答案？
  - [ ] feedback 解析是否准确？

#### 2️⃣ 释义选择题（V4 Agent 改进）
- **配置**: `definition_choice_count: 5`
- **预期改进**:
  - ✅ 正确释义来自 **word_cache**（非手动映射表）
  - ✅ 干扰项是 **常见错误**（非随机词的释义）
- **检查清单**:
  - [ ] 中文释义是否准确？
  - [ ] 干扰项是否具有迷惑性？
  - [ ] 听音模式是否正常？

#### 3️⃣ 跟读题（保持不变）
- **配置**: `word_pron_count: 3`, `sentence_pron_count: 2`
- **预期**: 与之前完全一致（这些题型不涉及语义改动）
- **检查清单**:
  - [ ] TTS 是否正常播放？
  - [ ] 录音评分是否正常？

### ⭐ 新功能测试（如果有 UI 支持）

#### 4️⃣ 英文释义题（V4 差异化功能）
- 这是最能体现 V4 优势的功能
- **预期效果**:
  - 用英文描述单词含义，让用户选择正确单词
  - 培养英英思维
  - 干扰项策略精细（反义词 + 不同类别 + 近形词）

#### 5️⃣ 词形变化题（V4 新增）
- **预期效果**:
  - 测试 do→does/did/done/doing 等变形
  - 支持正向（给词选形）和反向（给形选词）
  - 不规则动词有特殊说明

---

## 🐛 发现问题怎么办？

### 收集以下信息给我：

1. **题目截图或文字描述**
2. **具体问题**（如：干扰项不合理 / 答案泄露 / ...）
3. **复现步骤**（哪个视频/生词本 + 哪个题型）
4. **期望 vs 实际**

### 常见问题速查：

| 问题 | 可能原因 | 解决方案 |
|------|---------|---------|
| 题目质量差 | word_cache 数据不完整 | 执行 Step 3 刷新数据 |
| 所有题被过滤 | Quality Gate 过严 | 查看日志调整阈值 |
| API 超时 | AI 调用慢 | 减少单次出题数量 |
| 答案泄露 | Prompt 需要优化 | 反馈具体例子 |

---

## 📊 本次更新摘要

### ✨ 新增功能

1. **4 个 AI Agent**
   - MCQ Agent（智能选择题）
   - Meaning Agent（释义选择题）
   - Definition Agent（英文释义题）⭐
   - Forms Agent（词形变化题）

2. **Quality Gate 质量保障**
   - 9 大校验规则
   - 编辑距离检测
   - 答案泄露模式匹配
   - 自动过滤低质量题目

3. **难度分级体系**
   - 5 个等级完整配置
   - 每个 Agent 的 Prompt 自动注入难度指导语
   - 词汇/句子/干扰项/hint 全部差异化

4. **word_cache 扩展**
   - 新增 synonyms/antonyms/category 字段
   - 创建索引加速查询
   - refresh 接口支持批量刷新

### 📝 修改文件

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `qwen-chat.ts` | 修改 | definition prompt 返回新字段 |
| `word-cache/index.ts` | 修改 | 新增 refresh 路由 + 写入新字段 |
| `ai-test-plan/schemas.ts` | **新建** | 统一类型系统 |
| `ai-test-plan/agents/*.ts` | **新建** | 4 个 Agent + Dispatcher |
| `ai-test-plan/quality-gate.ts` | **新建** | 9 大校验规则 |
| `ai-test-plan/cache-helpers-v4.ts` | **新建** | 数据提取 + 智能分配 |
| `migrations/...v4.sql` | **新建** | 数据库 Migration |

---

## 🎉 准备好了吗？

**执行完 Step 1 和 Step 2 后就可以开始测试了！**

有任何问题随时告诉我，我会：
- 🔧 快速修复 Bug
- 📊 分析题目质量数据
- 🎯 根据 feedback 优化 Prompt
- 🚀 继续开发剩余 Agent（Reading/Listening）

**祝你测试顺利！** 💪
