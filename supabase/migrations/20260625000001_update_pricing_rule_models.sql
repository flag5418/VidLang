-- ============================================================
-- Update pricing_rule models from qwen-plus to qwen-turbo
-- 2026-06-25: 统一替换为低成本模型
-- ============================================================

UPDATE public.pricing_rule
SET model = 'qwen-turbo'
WHERE model = 'qwen-plus';

UPDATE public.pricing_rule
SET model = 'qwen3-tts-flash'
WHERE model = 'qwen-tts';
