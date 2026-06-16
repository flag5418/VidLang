-- ============================================================
-- Article translation pricing rule
-- ============================================================

INSERT INTO public.pricing_rule (rule_code, name_zh, description_zh, model, price_cny, status) VALUES
  ('ai_translate_article', '文章全文翻译', '调用千问将英文文章全文翻译为中文', 'qwen-plus', 0.03, 'active')
ON CONFLICT (rule_code) DO UPDATE SET
  name_zh = excluded.name_zh,
  description_zh = excluded.description_zh,
  model = excluded.model,
  price_cny = excluded.price_cny,
  status = excluded.status;
