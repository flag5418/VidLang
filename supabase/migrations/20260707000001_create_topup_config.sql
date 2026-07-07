-- ============================================================
-- 充值档位配置表
-- 支持动态配置充值档位、折扣、赠送等规则
-- ============================================================

CREATE TABLE IF NOT EXISTS public.topup_config (
  id BIGSERIAL PRIMARY KEY,
  original_amount NUMERIC(10,2) NOT NULL,        -- 充值面值（元）
  actual_amount NUMERIC(10,2) NOT NULL,          -- 用户实际支付金额（元）
  bonus_amount NUMERIC(10,2) NOT NULL DEFAULT 0, -- 额外赠送金额（元）
  discount_rate NUMERIC(5,4),                     -- 折扣率（1.0 = 无折扣）
  label TEXT,                                     -- 展示标签："体验" / "热门" / "最划算"
  discount_label TEXT,                            -- 折扣文案："打 9.5 折" / "送 ¥20"
  sort_order INT NOT NULL DEFAULT 0,             -- 排序权重（越小越靠前）
  status TEXT NOT NULL DEFAULT 'active',          -- active / inactive
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 初始数据：3 个充值档位
INSERT INTO public.topup_config (original_amount, actual_amount, bonus_amount, discount_rate, label, discount_label, sort_order) VALUES
  (10,  10,  0,    1.0,    '体验',     NULL,           1),
  (50,  55,  5,    NULL,   '热门',     '送 ¥5',        2),
  (100, 120, 20,   NULL,   '最划算',   '送 ¥20',       3)
ON CONFLICT DO NOTHING;

-- RLS：所有人可读（充值配置是公开信息）
ALTER TABLE public.topup_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read topup_config" ON public.topup_config;
CREATE POLICY "Anyone can read topup_config" ON public.topup_config
  FOR SELECT USING (true);
