# 🚀 V4 AI 出题系统 - 完整部署指南

**日期**: 2026-06-29
**状态**: ✅ 代码已完成，待部署

---

## ⚡ 快速部署（3 步完成）

### Step 1: 执行数据库 Migration ⏱️ 2 分钟

1. 打开 **Supabase Dashboard**: https://supabase.com/dashboard
2. 选择项目: **VideoLearnEnglish**
3. 左侧菜单 → **SQL Editor**
4. 点击 **New Query**
5. 复制以下文件的全部内容并粘贴：

   📄 `supabase/migrations/20260629000002_extend_word_cache_for_v4.sql`

   **或者直接复制下面的 SQL：**

```sql
-- ════════════════════════════════════════════
-- V4 Migration: 扩展 word_cache 表支持 AI Agent 出题
-- ════════════════════════════════════════════

-- 1. 添加新字段
ALTER TABLE word_cache
  ADD COLUMN IF NOT EXISTS synonyms TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS antonyms TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'other',
  ADD COLUMN IF NOT EXISTS morphology_adverb VARCHAR(100),
  ADD COLUMN IF NOT EXISTS morphology_noun VARCHAR(100);

-- 2. 添加注释
COMMENT ON COLUMN word_cache.synonyms IS 'V4: 同义词列表';
COMMENT ON COLUMN word_cache.antonyms IS 'V4: 反义词列表';
COMMENT ON COLUMN word_cache.category IS 'V4: 语义类别枚举值';
COMMENT ON COLUMN word_cache.morphology_adverb IS 'V4: 副词形式';
COMMENT ON COLUMN word_cache.morphology_noun IS 'V4: 名词形式';

-- 3. 创建索引（加速查询）
CREATE INDEX IF NOT EXISTS idx_word_cache_category ON word_cache(category);
CREATE INDEX IF NOT EXISTS idx_word_cache_difficulty ON word_cache((result->>'difficulty'));
CREATE INDEX IF NOT EXISTS idx_word_cache_synonyms ON word_cache USING gin(synonyms);
CREATE INDEX IF NOT EXISTS idx_word_cache_antonyms ON word_cache USING gin(antonyms);

-- 4. 为现有记录设置默认值
UPDATE word_cache
SET
  synonyms = CASE WHEN synonyms IS NULL OR array_length(synonyms, 1) IS NULL THEN '{}' ELSE synonyms END,
  antonyms = CASE WHEN antonyms IS NULL OR array_length(antonyms, 1) IS NULL THEN '{}' ELSE antonyms END,
  category = COALESCE(category, 'other')
WHERE synonyms IS NULL OR antonyms IS NULL OR category IS NULL;

-- 5. 验证
DO $$
BEGIN
  RAISE NOTICE '✅ Migration 完成！word_cache 表已扩展支持 V4 AI 出题系统';
END $$;
```

6. 点击 **Run** (▶️) 执行
7. 确认看到输出: `✅ Migration 完成！`

---

### Step 2: 部署 Edge Functions ⏱️ 3 分钟

打开终端，执行：

```bash
# 进入项目目录
cd /Volumes/Expand/wangqingquan/Documents/work/study/flutter/vidlang/supabase

# 部署核心函数（按顺序）
supabase functions deploy ai-test-plan --no-verify-jwt
supabase functions deploy word-cache --no-verify-jwt  
supabase functions deploy ai-proxy --no-verify-jwt

# ✅ 看到 "Deployed Function" 消息即为成功
```

**如果遇到链接问题**，先执行：
```bash
supabase link --project-ref <你的project-ref>
```
> 💡 Project Ref 在 Dashboard → Settings → API 中可以找到（格式类似 `abcdefghijklmnopqrst`）

---

### Step 3: 刷新 word_cache 数据 ⏱️ 5-10 分钟

这一步会为已有单词补充 V4 新字段（synonyms/antonyms/category）。

```bash
# 先 Dry Run（预览，不实际修改数据）
curl -X POST "https://<your-project-ref>.supabase.co/functions/v1/word-cache?action=refresh" \
  -H "Authorization: Bearer <your-service-role-key>" \
  -H "Content-Type: application/json" \
  -d '{"limit": 50, "dry_run": true}'

# 确认无误后正式执行
curl -X POST "https://<your-project-ref>.supabase.co/functions/v1/word-cache?action=refresh" \
  -H "Authorization: Bearer <your-service-role-key>" \
  -H "Content-Type: application/json" \
  -d '{"limit": 100, "dry_run": false}'
```

> ⚠️ **注意**: 
> - 替换 `<your-project-ref>` 为你的实际项目 ID
> - 替换 `<your-service-role-key>` 为 Service Role Key（在 Dashboard → Settings → API）
> - 刷新过程会调用 AI API，每个单词约需 0.5-1 秒
> - 建议先刷新 50 个高频词测试效果

---

## 🧪 测试验证清单

### 基础功能测试

- [ ] **数据库验证**
  ```sql
  -- 在 SQL Editor 中执行，确认新字段存在
  SELECT column_name, data_type 
  FROM information_schema.columns 
  WHERE table_name = 'word_cache' 
  AND column_name IN ('synonyms', 'antonyms', 'category');
  -- 应返回 3 行记录
  ```

- [ ] **Edge Function 验证**
  ```bash
  # 测试 word-cache stats 接口
  curl "https://<project-ref>.supabase.co/functions/v1/word-cache?action=stats"
  # 应返回 JSON 包含 total_words, difficulty_distribution 等
  ```

### 功能测试（App 端）

1. **MCQ 选择题（V4 Agent）**
   - [ ] 进入测试页面
   - [ ] 选择一个视频或生词本
   - [ ] 配置: `mcq_count: 5, difficulty: intermediate`
   - [ ] 开始测试
   - [ ] **检查项**:
     - [ ] 干扰项是否与目标词同词性？
     - [ ] 是否有答案泄露（选项中出现正确答案的明显提示）？
     - [ ] hint 是否有用但不直接给答案？
     - [ ] feedback 解析是否准确？

2. **释义选择题（V4 Agent）**
   - [ ] 配置: `definition_choice_count: 5`
   - [ ] **检查项**:
     - [ ] 正确释义是否准确？
     - [ ] 干扰项是否是常见错误？
     - [ ] 听音模式是否正常播放 TTS？

3. **英文释义题（V4 新功能）⭐**
   - [ ] 配置: 开启 `english_definition` 类型（如果 UI 支持）
   - [ ] 或通过 API 直接测试:
     ```bash
     curl -X POST "https://<project-ref>.supabase.co/functions/v1/ai-test-plan" \
       -H "Authorization: Bearer <user-token>" \
       -H "Content-Type: application/json" \
       -d '{
         "source_type": "resource",
         "video_code": "<test-video-code>",
         "difficulty": "intermediate",
         "config": {
           "mcq_count": 3,
           "definition_choice_count": 2
         }
       }'
     ```
   - [ ] **检查项**:
     - [ ] 英文释义是否清晰易懂？
     - [ ] 选项中是否有反义词干扰？
     - [ ] 选项中是否有近形词干扰？

4. **词形变化题（V4 新功能）**
   - [ ] 配置: 开启 `word_forms` 类型
   - [ ] **检查项**:
     - [ ] 是否正确测试了动词变形？
     - [ ] 不规则动词是否有特殊说明？
     - [ ] 反向模式（给形式选词）是否正常？

### 质量门验证

- [ ] 是否还有题目被质量门过滤？（查看日志 `[quality_gate]`）
- [ ] 过滤率是否合理？（预期 <15%）
- [ ] 是否出现 `no_items` 错误？

---

## 🔧 故障排查

### 问题 1: Migration 执行失败
**症状**: SQL Editor 报错 `column already exists`
**解决**: 使用 `IF NOT EXISTS` 子句已经处理了这个情况，如果仍然报错可以忽略

### 问题 2: Edge Function 部署失败
**症状**: `Error: Failed to deploy function`
**解决**:
```bash
# 检查函数语法
supabase functions serve ai-test-plan # 本地测试

# 查看详细日志
supabase functions deploy ai-test-plan --no-verify-jwt --debug
```

### 问题 3: refresh 接口无响应
**症状**: curl 请求超时或返回错误
**解决**:
- 检查 Service Role Key 是否正确
- 检查 AI API Key 是否配置（在 `app_settings` 表中需要 `qwen_api_key`）
- 先用 dry_run 模式测试

### 问题 4: 题目质量差
**症状**: 干扰项不合理 / 答案泄露
**解决**:
1. 检查 word_cache 数据是否完整:
   ```sql
   SELECT word, 
          array_length(synonyms, 1) as syn_count,
          array_length(antonyms, 1) as ant_count,
          category
   FROM word_cache 
   ORDER BY query_count DESC 
   LIMIT 20;
   ```
2. 如果 synonyms/antonyms 大部分为空，需要执行 refresh
3. 查看 Edge Function 日志中的 Quality Gate 输出

---

## 📊 监控命令速查

```bash
# 1. word-cache 统计
curl "https://<ref>.supabase.co/functions/v1/word-cache?action=stats"

# 2. 刷新 V4 字段（Dry Run）
curl -X POST "https://<ref>.supabase.co/functions/v1/word-cache?action=refresh" \
  -H "Authorization: Bearer <key>" \
  -d '{"limit": 100, "dry_run": true}'

# 3. 刷新 V4 字段（正式执行）
curl -X POST "https://<ref>.supabase.co/functions/v1/word-cache?action=refresh" \
  -H "Authorization: Bearer <key>" \
  -d '{"limit": 500, "dry_run": false}'

# 4. 预填充常用词（如果 word_cache 为空）
curl -X POST "https://<ref>.supabase.co/functions/v1/word-cache?action=prefill" \
  -H "Authorization: Bearer <key>" \
  -d '{"difficulties": ["primary", "juniorHigh", "seniorHigh"]}'

# 5. 查看函数日志（Supabase Dashboard → Logs）
```

---

## 🎯 下一步优化方向

当前版本完成后，可以考虑：

1. **Phase 4.1**: Reading Agent（阅读理解题）
2. **Phase 4.2**: Listening Agent（听力理解题）
3. **Phase 4.3**: Translation Agent（英义互译题）
4. **Phase 4.4**: 性能监控面板（API 调用统计、成本追踪）

---

## 📞 技术支持

如遇问题，请提供以下信息：

1. **错误日志**（Edge Function 日志或浏览器控制台）
2. **复现步骤**（具体操作流程）
3. **期望行为 vs 实际行为**

---

**祝测试顺利！🎉**
