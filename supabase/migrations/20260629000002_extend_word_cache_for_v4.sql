-- Migration: 扩展 word_cache 表支持 V4 AI 出题系统
-- 日期: 2026-06-29
-- 目的: 添加 synonyms、antonyms、category 等字段，为 AI Agent 出题提供数据基础

-- ============================================================
-- 1. 扩展 word_cache 表：添加 V4 新字段
-- ============================================================

ALTER TABLE word_cache
  ADD COLUMN IF NOT EXISTS synonyms TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS antonyms TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'other',
  ADD COLUMN IF NOT EXISTS morphology_adverb VARCHAR(100),
  ADD COLUMN IF NOT EXISTS morphology_noun VARCHAR(100);

-- 添加注释
COMMENT ON COLUMN word_cache.synonyms IS 'V4: 同义词列表（从 AI definition API 获取）';
COMMENT ON COLUMN word_cache.antonyms IS 'V4: 反义词列表（从 AI definition API 获取）';
COMMENT ON COLUMN word_cache.category IS 'V4: 语义类别枚举值（emotion/action/size/quality/appearance/time/place/object/nature/abstract/food/animal/number/person/technology/education/business/health/travel/other）';
COMMENT ON COLUMN word_cache.morphology_adverb IS 'V4: 副词形式（如 happily）';
COMMENT ON COLUMN word_cache.morphology_noun IS 'V4: 名词形式（如 happiness）';

-- ============================================================
-- 2. 创建索引：加速按 category 和 difficulty 查询
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_word_cache_category ON word_cache(category);
CREATE INDEX IF NOT EXISTS idx_word_cache_difficulty ON word_cache(
  (result->>'difficulty')
);

-- ============================================================
-- 3. 创建 GIN 索引：加速 synonyms/antonyms 数组查询
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_word_cache_synonyms ON word_cache USING gin(synonyms);
CREATE INDEX IF NOT EXISTS idx_word_cache_antonyms ON word_cache USING gin(antonyms);

-- ============================================================
-- 4. 数据迁移：为现有记录填充默认值
-- ============================================================

-- 注意：现有记录的 synonyms/antonyms/category 需要通过重新调用 definition API 来填充
-- 这里仅设置合理的默认值，避免 NULL 导致查询异常

UPDATE word_cache
SET
  synonyms = CASE WHEN synonyms IS NULL OR array_length(synonyms, 1) IS NULL THEN '{}' ELSE synonyms END,
  antonyms = CASE WHEN antonyms IS NULL OR array_length(antonyms, 1) IS NULL THEN '{}' ELSE antonyms END,
  category = COALESCE(category, 'other')
WHERE synonyms IS NULL
   OR antonyms IS NULL
   OR category IS NULL;

-- ============================================================
-- 5. 验证脚本：检查新字段是否正确添加
-- ============================================================

DO $$
DECLARE
  column_exists BOOLEAN;
BEGIN
  -- 检查 synonyms 列是否存在
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'word_cache' AND column_name = 'synonyms'
  ) INTO column_exists;

  IF column_exists THEN
    RAISE NOTICE '✅ word_cache.synonyms 列已成功添加';
  ELSE
    RAISE EXCEPTION '❌ word_cache.synonyms 列添加失败';
  END IF;

  -- 检查 antonyms 列是否存在
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'word_cache' AND column_name = 'antonyms'
  ) INTO column_exists;

  IF column_exists THEN
    RAISE NOTICE '✅ word_cache.antonyms 列已成功添加';
  ELSE
    RAISE EXCEPTION '❌ word_cache.antonyms 列添加失败';
  END IF;

  -- 检查 category 列是否存在
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'word_cache' AND column_name = 'category'
  ) INTO column_exists;

  IF column_exists THEN
    RAISE NOTICE '✅ word_cache.category 列已成功添加';
  ELSE
    RAISE EXCEPTION '❌ word_cache.category 列添加失败';
  END IF;

  RAISE NOTICE '🎉 Migration 完成！word_cache 表已扩展支持 V4 AI 出题系统';
END $$;
