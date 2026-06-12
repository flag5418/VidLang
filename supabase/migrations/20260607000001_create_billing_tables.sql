-- ============================================================
-- AI 计费体系数据库建表 SQL
-- 5 张表：pricing_rule, usage_event, wallet_ledger, user_wallet, app_settings
-- ============================================================

-- 1. 计费规则表
CREATE TABLE IF NOT EXISTS public.pricing_rule (
  id BIGSERIAL PRIMARY KEY,
  rule_code TEXT UNIQUE NOT NULL,
  name_zh TEXT NOT NULL,
  description_zh TEXT NOT NULL,
  model TEXT NOT NULL,
  price_cny NUMERIC(10,4) NOT NULL,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 消费记录表
CREATE TABLE IF NOT EXISTS public.usage_event (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  rule_code TEXT NOT NULL,
  scene TEXT NOT NULL,
  entry TEXT NOT NULL,
  request_id TEXT UNIQUE NOT NULL,
  cost_cny NUMERIC(10,4) NOT NULL,
  meta JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_usage_event_user_id ON public.usage_event(user_id);
CREATE INDEX IF NOT EXISTS idx_usage_event_created_at ON public.usage_event(created_at DESC);

-- 3. 余额流水表（合并充值+消费+调整）
CREATE TABLE IF NOT EXISTS public.wallet_ledger (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL,
  type TEXT NOT NULL,
  amount_cny NUMERIC(10,4) NOT NULL,
  balance_after NUMERIC(10,4) NOT NULL,
  channel TEXT,
  paid_at TIMESTAMPTZ,
  ref_id BIGINT,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wallet_ledger_user_id ON public.wallet_ledger(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_ledger_created_at ON public.wallet_ledger(created_at DESC);

-- 4. 用户钱包表（纯余额）
CREATE TABLE IF NOT EXISTS public.user_wallet (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) UNIQUE NOT NULL,
  balance_cny NUMERIC(10,4) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_wallet_user_id ON public.user_wallet(user_id);

-- 5. 应用设置表
CREATE TABLE IF NOT EXISTS public.app_settings (
  id BIGSERIAL PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 初始数据
-- ============================================================

-- 计费规则初始数据
INSERT INTO public.pricing_rule (rule_code, name_zh, description_zh, model, price_cny, status) VALUES
  ('ai_definition', 'AI释义', '查询单词的详细释义、例句、音标', 'qwen-plus', 0.01, 'active'),
  ('ai_translate', 'AI翻译', '调用通义千问进行句子/段落翻译', 'qwen-plus', 0.03, 'active'),
  ('ai_tts', 'AI发音', '调用通义千问 TTS 进行 AI 语音合成', 'qwen-tts', 0.02, 'active'),
  ('ai_word_link', 'AI词联', '根据上下文联想关联词汇、近义词、反义词', 'qwen-plus', 0.02, 'active'),
  ('ai_evaluate', 'AI评测', '调用声通对跟读录音进行发音评分', 'shengtong', 0.05, 'active')
ON CONFLICT (rule_code) DO NOTHING;

-- 应用设置初始数据
INSERT INTO public.app_settings (key, value, description) VALUES
  ('default_new_user_balance', '10.00', '新用户注册默认赠送余额（元）'),
  ('qwen_api_key', '', '通义千问 API Key（请在 Supabase Dashboard 中填充）'),
  ('qwen_base_url', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'Qwen API 地址'),
  ('shengtong_api_key', '', '声通发音评分 API Key'),
  ('shengtong_app_id', '', '声通 App ID')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- RLS 策略：用户只能读自己的钱包和记录
-- ============================================================

ALTER TABLE public.pricing_rule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_event ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_wallet ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- pricing_rule: 所有人可读
CREATE POLICY "Anyone can read pricing_rule" ON public.pricing_rule
  FOR SELECT USING (true);

-- usage_event: 只能读自己的
CREATE POLICY "Users read own usage" ON public.usage_event
  FOR SELECT USING (auth.uid() = user_id);

-- wallet_ledger: 只能读自己的
CREATE POLICY "Users read own ledger" ON public.wallet_ledger
  FOR SELECT USING (auth.uid() = user_id);

-- user_wallet: 只能读/更新自己（Edge Function 使用 service_role 写入）
CREATE POLICY "Users read own wallet" ON public.user_wallet
  FOR SELECT USING (auth.uid() = user_id);

-- app_settings: 所有人可读
CREATE POLICY "Anyone can read app_settings" ON public.app_settings
  FOR SELECT USING (true);
