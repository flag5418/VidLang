-- ============================================================
-- 论坛系统：用户资料公开视图
-- 解决 Edge Function 中 auth.users 跨 schema join 不被 PostgREST 支持的问题
-- 仅暴露 id + raw_user_meta_data（display_name / avatar_url 等）
-- 不暴露 email / phone / password 等敏感字段
-- ============================================================

CREATE OR REPLACE VIEW public.user_profiles AS
SELECT id, raw_user_meta_data
FROM auth.users;
