-- ============================================================
-- 更新声通语音评测 API 凭据
-- 日期：2026-06-29
-- 说明：更新 appKey 和 secretKey 为新的评分账号
-- ============================================================

-- 更新声通 App Key
INSERT INTO public.app_settings (key, value, description, updated_at) VALUES
  ('shengtong_app_key', '17827042090007b7', '声通 App Key', NOW())
ON CONFLICT (key) DO UPDATE SET
  value = excluded.value,
  description = excluded.description,
  updated_at = excluded.updated_at;

-- 更新声通 Secret Key
INSERT INTO public.app_settings (key, value, description, updated_at) VALUES
  ('shengtong_secret_key', '074713c03b62c75d1bee970dab2706e', '声通 Secret Key', NOW())
ON CONFLICT (key) DO UPDATE SET
  value = excluded.value,
  description = excluded.description,
  updated_at = excluded.updated_at;

-- 验证更新结果
SELECT key, value, description, updated_at 
FROM public.app_settings 
WHERE key IN ('shengtong_app_key', 'shengtong_secret_key')
ORDER BY key;
