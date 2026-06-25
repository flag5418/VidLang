-- ============================================================
-- Add pricing rules for ai_chat (评测判分/自定义prompt)
-- ============================================================

INSERT INTO public.pricing_rule (rule_code, name_zh, description_zh, model, price_cny, status) VALUES
  ('ai_chat', 'AI对话判分', '调用通义千问进行评测判分和自定义对话', 'qwen-turbo', 0.02, 'active')
ON CONFLICT (rule_code) DO UPDATE SET
  name_zh = excluded.name_zh,
  description_zh = excluded.description_zh,
  model = excluded.model,
  price_cny = excluded.price_cny,
  status = excluded.status;
