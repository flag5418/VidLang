-- ============================================================
-- 评测结果存储系统数据库建表
-- 2 张表：evaluation_records, evaluation_summaries
-- + 新增计费规则
-- ============================================================

-- 1. 评测详细记录表（云端存储，每种类型最多50条）
CREATE TABLE IF NOT EXISTS public.evaluation_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  evaluation_type TEXT NOT NULL CHECK (evaluation_type IN ('word', 'sentence', 'paragraph')),
  
  -- 资源信息
  resource_type TEXT,
  resource_code TEXT,
  resource_title TEXT,
  ref_text TEXT,
  
  -- 评分维度
  overall_score NUMERIC(5,2),
  fluency_score NUMERIC(5,2),
  integrity_score NUMERIC(5,2),
  accuracy_score NUMERIC(5,2),
  pronunciation_score NUMERIC(5,2),
  
  -- 详细结果（JSONB 存储完整声通返回）
  raw_result JSONB DEFAULT '{}',
  
  -- 单词级摘要（快速查询用）
  word_summary JSONB DEFAULT '[]',
  
  -- 薄弱维度
  weak_dimensions JSONB DEFAULT '[]',
  
  -- 元数据
  duration_ms INTEGER,
  language TEXT DEFAULT 'en',
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_eval_records_user_type ON public.evaluation_records(user_id, evaluation_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_eval_records_user_created ON public.evaluation_records(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_eval_records_resource ON public.evaluation_records(resource_type, resource_code);

-- 2. 评测类型摘要表（按类型汇总统计）
CREATE TABLE IF NOT EXISTS public.evaluation_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  evaluation_type TEXT NOT NULL CHECK (evaluation_type IN ('word', 'sentence', 'paragraph')),
  
  -- 统计数据
  total_count INTEGER DEFAULT 0,
  avg_overall NUMERIC(5,2),
  avg_fluency NUMERIC(5,2),
  avg_accuracy NUMERIC(5,2),
  avg_integrity NUMERIC(5,2),
  avg_pronunciation NUMERIC(5,2),
  
  -- 最近趋势（最近 10 次评分）
  recent_scores JSONB DEFAULT '[]',
  
  -- 薄弱维度汇总
  weak_dimensions JSONB DEFAULT '[]',
  
  -- 常错单词
  frequent_errors JSONB DEFAULT '[]',
  
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, evaluation_type)
);

CREATE INDEX IF NOT EXISTS idx_eval_summaries_user ON public.evaluation_summaries(user_id);

-- ============================================================
-- RLS 策略
-- ============================================================

ALTER TABLE public.evaluation_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evaluation_summaries ENABLE ROW LEVEL SECURITY;

-- evaluation_records: 用户管理自己的记录
DROP POLICY IF EXISTS "Users manage own evaluation_records" ON public.evaluation_records;
CREATE POLICY "Users manage own evaluation_records" ON public.evaluation_records
  FOR ALL USING (auth.uid() = user_id);

-- evaluation_summaries: 用户管理自己的摘要
DROP POLICY IF EXISTS "Users manage own evaluation_summaries" ON public.evaluation_summaries;
CREATE POLICY "Users manage own evaluation_summaries" ON public.evaluation_summaries
  FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- 新增计费规则
-- ============================================================

-- AI 发音分析（使用 qwen-turbo 高性价比模型）
INSERT INTO public.pricing_rule (rule_code, name_zh, description_zh, model, price_cny, status) VALUES
  ('ai_audio_evaluation', 'AI 发音分析', '基于声通评测结果的 AI 深度分析和改进建议', 'qwen-turbo', 0.01, 'active')
ON CONFLICT (rule_code) DO UPDATE SET
  name_zh = excluded.name_zh,
  description_zh = excluded.description_zh,
  model = excluded.model,
  price_cny = excluded.price_cny,
  status = excluded.status;

-- 评测存储（内部服务，免费）
INSERT INTO public.pricing_rule (rule_code, name_zh, description_zh, model, price_cny, status) VALUES
  ('evaluation_storage', '评测存储', '保存评测结果到云端（内部服务）', 'internal', 0, 'active')
ON CONFLICT (rule_code) DO UPDATE SET
  name_zh = excluded.name_zh,
  description_zh = excluded.description_zh,
  model = excluded.model,
  price_cny = excluded.price_cny,
  status = excluded.status;
