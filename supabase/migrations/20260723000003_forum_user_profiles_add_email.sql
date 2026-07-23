-- 论坛系统：user_profiles 视图增加 email 字段
-- forum-service 等 Edge Function 需要对用户邮箱的引用
DROP VIEW IF EXISTS public.user_profiles;
CREATE VIEW public.user_profiles AS
SELECT id, email, raw_user_meta_data
FROM auth.users;
