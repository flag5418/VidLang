-- ============================================================
-- 评测系统数据库建表
-- 3 张表：test_record, test_item_detail, test_evaluation
-- + 声通 app_settings + st_pron_score 计费规则
-- ============================================================

-- 1. 评测主记录表
CREATE TABLE IF NOT EXISTS public.test_record (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  test_type TEXT NOT NULL,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'in_progress',
  total_score NUMERIC(5,2),
  duration_seconds INTEGER,
  meta JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_test_record_user_id ON public.test_record(user_id);
CREATE INDEX IF NOT EXISTS idx_test_record_started_at ON public.test_record(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_test_record_user_status ON public.test_record(user_id, status);

-- 2. 题型明细表
CREATE TABLE IF NOT EXISTS public.test_item_detail (
  id BIGSERIAL PRIMARY KEY,
  test_record_id BIGINT REFERENCES public.test_record(id) ON DELETE CASCADE NOT NULL,
  item_type TEXT NOT NULL,
  item_order INTEGER NOT NULL DEFAULT 0,
  ref_text TEXT NOT NULL,
  ref_audio_url TEXT,
  user_audio_url TEXT,
  score NUMERIC(5,2),
  raw_result JSONB DEFAULT '{}',
  ai_analysis JSONB DEFAULT '{}',
  is_correct BOOLEAN,
  answer_text TEXT,
  completed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_test_item_detail_record_id ON public.test_item_detail(test_record_id);
CREATE INDEX IF NOT EXISTS idx_test_item_detail_item_type ON public.test_item_detail(test_record_id, item_type);

-- 3. AI 评价报告表
CREATE TABLE IF NOT EXISTS public.test_evaluation (
  id BIGSERIAL PRIMARY KEY,
  test_record_id BIGINT REFERENCES public.test_record(id) ON DELETE CASCADE UNIQUE NOT NULL,
  overall_score NUMERIC(5,2),
  category_scores JSONB DEFAULT '{}',
  weakness_analysis TEXT,
  training_suggestions TEXT,
  previous_comparison JSONB DEFAULT '{}',
  generated_by TEXT DEFAULT 'qwen',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_test_evaluation_record_id ON public.test_evaluation(test_record_id);

-- ============================================================
-- 初始数据：声通配置 + 计费规则
-- ============================================================

-- 声通 app_settings
INSERT INTO public.app_settings (key, value, description) VALUES
  ('shengtong_app_key', '17827042090007b7', '声通 App Key'),
  ('shengtong_secret_key', '074713c03b62c75d1bee970dab2706e', '声通 Secret Key'),
  ('shengtong_server_url', 'https://api.stkouyu.com:8443', '声通 API 端点')
ON CONFLICT (key) DO UPDATE SET
  value = excluded.value,
  description = excluded.description,
  updated_at = NOW();

-- st_pron_score 计费规则
INSERT INTO public.pricing_rule (rule_code, name_zh, description_zh, model, price_cny, status) VALUES
  ('st_pron_score', '跟读评分', '调用声通对跟读录音进行发音评分', 'shengtong', 0.05, 'active')
ON CONFLICT (rule_code) DO UPDATE SET
  name_zh = excluded.name_zh,
  description_zh = excluded.description_zh,
  model = excluded.model,
  price_cny = excluded.price_cny,
  status = excluded.status;

-- ============================================================
-- RLS 策略
-- ============================================================

ALTER TABLE public.test_record ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_item_detail ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_evaluation ENABLE ROW LEVEL SECURITY;

-- test_record: 用户读写自己
DROP POLICY IF EXISTS "Users manage own test_record" ON public.test_record;
CREATE POLICY "Users manage own test_record" ON public.test_record
  FOR ALL USING (auth.uid() = user_id);

-- test_item_detail: 用户通过 test_record 间接控制（Edge Function 用 service_role 写入）
DROP POLICY IF EXISTS "Users read own test_item_detail" ON public.test_item_detail;
CREATE POLICY "Users read own test_item_detail" ON public.test_item_detail
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.test_record
      WHERE test_record.id = test_item_detail.test_record_id
      AND test_record.user_id = auth.uid()
    )
  );

-- test_evaluation: 用户读取自己
DROP POLICY IF EXISTS "Users read own test_evaluation" ON public.test_evaluation;
CREATE POLICY "Users read own test_evaluation" ON public.test_evaluation
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.test_record
      WHERE test_record.id = test_evaluation.test_record_id
      AND test_record.user_id = auth.uid()
    )
  );
