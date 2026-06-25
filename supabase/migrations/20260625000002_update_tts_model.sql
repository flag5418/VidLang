-- ============================================================
-- Update pricing_rule TTS model to CosyVoice-v3-Flash
-- 2026-06-25: TTS 模型更换为更低成本的 CosyVoice-v3-Flash
-- ============================================================

UPDATE public.pricing_rule
SET model = 'CosyVoice-v3-Flash'
WHERE rule_code = 'ai_tts';
