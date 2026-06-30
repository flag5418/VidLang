# Phase 2: word_cache 扩展完成报告

**日期**: 2026-06-29
**状态**: ✅ 已完成

---

## 📋 变更概览

### 目标
为 V4 AI 出题系统扩展 `word_cache` 数据基础，新增：
- **synonyms**（同义词列表）
- **antonyms**（反义词列表）
- **category**（语义类别枚举）
- **morphology 扩展**（adverb/noun 形式）

---

## 🔧 修改的文件

### 1. `supabase/functions/ai-proxy/clients/qwen-chat.ts`

#### 变更内容：
1. **扩展 `DefinitionResult` 接口**（第 87-98 行）
   ```typescript
   export interface DefinitionResult {
     // ... 原有字段 ...
     synonyms?: string[]      // V4 新增：同义词列表
     antonyms?: string[]      // V4 新增：反义词列表
     category?: string        // V4 新增：语义类别
   }
   ```

2. **增强 `definition()` 函数的 prompt**（第 225-275 行）
   - 新增 `synonyms` 字段：要求返回 2-4 个同义词
   - 新增 `antonyms` 字段：要求返回 1-3 个反义词
   - 新增 `category` 字段：20 种语义类别枚举值
   - 扩展 `morphology` 对象：
     - 添加 `adverb`：副词形式（如 happily）
     - 添加 `noun`：名词形式（如 happiness）

3. **输出规则更新**（第 265-275 行）
   ```
   规则 8: synonyms 提供 2-4 个常见同义词（同词性优先）
   规则 9: antonyms 提供 1-3 个常见反义词（如有）
   规则 10: category 必须在指定的语义类别枚举值中选择
   规则 11: 输出纯 JSON，不要包裹在 markdown 代码块中
   ```

---

### 2. `supabase/migrations/20260629000002_extend_word_cache_for_v4.sql`（新建）

#### Migration 脚本功能：

**表结构扩展**：
```sql
ALTER TABLE word_cache
  ADD COLUMN synonyms TEXT[] DEFAULT '{}',
  ADD COLUMN antonyms TEXT[] DEFAULT '{}',
  ADD COLUMN category VARCHAR(50) DEFAULT 'other',
  ADD COLUMN morphology_adverb VARCHAR(100),
  ADD COLUMN morphology_noun VARCHAR(100);
```

**索引优化**：
```sql
-- 加速按 category 和 difficulty 查询
CREATE INDEX idx_word_cache_category ON word_cache(category);
CREATE INDEX idx_word_cache_difficulty ON word_cache((result->>'difficulty'));

-- GIN 索引加速数组查询
CREATE INDEX idx_word_cache_synonyms ON word_cache USING gin(synonyms);
CREATE INDEX idx_word_cache_antonyms ON word_cache USING gin(antonyms);
```

**数据迁移**：
- 为现有记录设置默认值（避免 NULL 异常）
- 验证脚本确认列添加成功

---

### 3. `supabase/functions/word-cache/index.ts`

#### 变更内容：

1. **路由注释更新**
   - 移除 `prewarm` 路由（未实现）
   - 新增 `refresh` 路由说明

2. **`prefillWords()` 函数增强**（第 357-383 行）
   - 写入缓存时同步提取新字段到独立列
   - 从 AI 结果中提取：
     - `result.synonyms` → `cacheData.synonyms`
     - `result.antonyms` → `cacheData.antonyms`
     - `result.category` → `cacheData.category`
     - `result.morphology.adverb` → `cacheData.morphology_adverb`
     - `result.morphology.noun` → `cacheData.morphology_noun`

3. **新增 `handleRefresh()` 函数**（第 532-620 行）
   - **功能**：为已有单词补充 V4 新字段
   - **用法**：
     ```bash
     POST /?action=refresh
     Body: { "limit": 100, "dry_run": false }
     ```
   - **特性**：
     - 自动查询缺少 `synonyms` 的单词
     - 按 `query_count` 降序排列（优先刷新高频词）
     - 支持 `dry_run` 模式（只统计不更新）
     - 单次最多处理 500 个单词
     - 返回详细统计信息（成功/失败数量、错误列表）

4. **Switch 路由添加 `case 'refresh'`**

---

## 📊 数据结构对比

### Before (V3)
```json
{
  "word": "happy",
  "phonetic_uk": "/ˈhæpi/",
  "definitions": [...],
  "difficulty": "primary",
  "morphology": {
    "comparative": "happier",
    "superlative": "happiest"
  },
  "mnemonic": "..."
}
```

### After (V4)
```json
{
  "word": "happy",
  "phonetic_uk": "/ˈhæpi/",
  "definitions": [...],
  "difficulty": "primary",
  "morphology": {
    "comparative": "happier",
    "superlative": "happiest",
    "adverb": "happily",        // ← 新增
    "noun": "happiness"         // ← 新增
  },
  "synonyms": ["glad", "joyful", "cheerful", "delighted"],  // ← 新增
  "antonyms": ["sad", "unhappy"],                            // ← 新增
  "category": "emotion",                                     // ← 新增
  "mnemonic": "..."
}
```

---

## 🚀 使用指南

### 1. 执行 Migration
```bash
cd supabase
supabase db push  # 或手动执行 SQL 文件
```

### 2. 刷新已有数据
```bash
# Dry Run 模式（查看需要更新的数量）
curl -X POST "https://your-project.supabase.co/functions/v1/word-cache?action=refresh" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"limit": 100, "dry_run": true}'

# 实际执行
curl -X POST "https://your-project.supabase.co/functions/v1/word-cache?action=refresh" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{"limit": 100, "dry_run": false}'
```

### 3. 验证字段填充情况
```bash
# 查看统计信息
curl "https://your-project.supabase.co/functions/v1/word-cache?action=stats"
```

---

## 🎯 下一步计划 (Phase 3)

现在 `word_cache` 已具备完整的数据基础，可以开始开发核心 Agent：

1. **MCQ Agent**（选择题 Agent）
   - 使用 `synonyms` 生成干扰项
   - 使用 `difficulty` 调整题目难度
   - 使用 `category` 确保选项语义一致

2. **Reading Agent**（阅读理解 Agent）
   - 基于 `article_content` 生成理解题
   - 利用 `word_cache` 中的例句模式

3. **Listening Agent**（听力理解 Agent）
   - 结合音频文件生成听力题

4. **Quality Gate**（质量门）
   - 多维度合规性校验
   - 答案泄露检测
   - 干扰项有效性验证

---

## ⚠️ 注意事项

1. **API 费用控制**
   - `refresh` 操作会重新调用 AI API
   - 建议先使用 `dry_run: true` 评估影响范围
   - 单次限制 500 个避免超时

2. **向后兼容性**
   - 所有新字段都有默认值
   - 旧代码不会因 NULL 值崩溃
   - `synonyms/antonyms` 默认为空数组 `{}`

3. **索引性能**
   - GIN 索引会占用额外存储空间
   - 但能显著加速 `ANY(synonyms)` 查询
   - 建议在数据量 >10K 时再创建

---

## ✅ 验证清单

- [x] `qwen-chat.ts` prompt 包含新字段定义
- [x] `DefinitionResult` 接口已更新
- [x] Migration SQL 脚本已编写
- [x] 索引已优化（category/difficulty/synonyms/antonyms）
- [x] `prefillWords()` 提取新字段到独立列
- [x] `handleRefresh()` 函数已实现
- [x] Linter 检查通过（0 errors）
- [ ] Migration 已执行（待用户操作）
- [ ] 数据已刷新（待用户执行 refresh）
