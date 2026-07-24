-- ============================================================
-- 论坛 V2.0 修复：FK 关系映射提示
-- 告诉 PostgREST 通过 user_profiles 视图解析 author_id FK
-- ============================================================

-- forum_posts.author_id → user_profiles
COMMENT ON CONSTRAINT forum_posts_author_id_fkey ON forum_posts IS 
  E'@foreignKey (author_id) references user_profiles (id)';

-- forum_posts.deleted_by → user_profiles
COMMENT ON CONSTRAINT forum_posts_deleted_by_fkey ON forum_posts IS 
  E'@foreignKey (deleted_by) references user_profiles (id)';

-- forum_replies.author_id → user_profiles
COMMENT ON CONSTRAINT forum_replies_author_id_fkey ON forum_replies IS 
  E'@foreignKey (author_id) references user_profiles (id)';

-- forum_replies.deleted_by → user_profiles
COMMENT ON CONSTRAINT forum_replies_deleted_by_fkey ON forum_replies IS 
  E'@foreignKey (deleted_by) references user_profiles (id)';
