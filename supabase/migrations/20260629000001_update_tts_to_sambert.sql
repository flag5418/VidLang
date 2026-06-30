-- ============================================================
-- Update pricing_rule TTS model: cosyvoice-v1 → qwen-tts
-- 2026-06-29: 经联网核查阿里云百炼官方文档确认：
--   - qwen3-tts 是开源本地部署模型的名称，不是百炼 API 的 model ID
--   - 百炼平台正确的 TTS 模型 ID 是 'qwen-tts'
--   - 计费：输入 0.0016元/千Token + 输出 0.01元/千Token
--   - 端点：/api/v1/services/aigc/multimodal-generation/generation
--   - 支持音色：Aiden(男英), Chelsie(女英), Cherry(女英), Ethan(男英) 等
--
-- ⚠️ 费用控制红线：
--   - 绝对不要使用 deep_thinking / enable_thinking 参数（会静默升配到高价模型）
--   - Chat 模型必须用 qwen-turbo（0.0003元/input 千Token），不要用 qwen-max
-- ============================================================

UPDATE public.pricing_rule
SET model = 'qwen-tts'
WHERE rule_code = 'ai_tts';
