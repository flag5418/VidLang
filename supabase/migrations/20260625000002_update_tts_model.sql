-- ============================================================
-- Update pricing_rule TTS model to sambert-zhichu-v1
-- 2026-06-29: TTS 模型从 CosyVoice-v3-Flash 改为 Sambert TTS
--
-- 原因：CosyVoice 模型不支持 DashScope multimodal-generation 端点
--       （会报 url error, please check url!）
--       因此改用 Sambert TTS HTTP REST API 端点：
--       /api/v1/services/aigc/text2speech/generation
-- ============================================================

UPDATE public.pricing_rule
SET model = 'sambert-zhichu-v1'
WHERE rule_code = 'ai_tts';
