-- 论坛系统存储过程和函数
-- 创建时间：2026年7月4日

-- 增加帖子点赞数的函数
CREATE OR REPLACE FUNCTION increment_like_count(post_id BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE forum_posts
  SET like_count = like_count + 1
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

-- 减少帖子点赞数的函数
CREATE OR REPLACE FUNCTION decrement_like_count(post_id BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE forum_posts
  SET like_count = GREATEST(like_count - 1, 0)
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

-- 增加帖子评论数的函数
CREATE OR REPLACE FUNCTION increment_comment_count(post_id BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE forum_posts
  SET comment_count = comment_count + 1
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

-- 减少帖子评论数的函数
CREATE OR REPLACE FUNCTION decrement_comment_count(post_id BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE forum_posts
  SET comment_count = GREATEST(comment_count - 1, 0)
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

-- 增加评论点赞数的函数
CREATE OR REPLACE FUNCTION increment_comment_like_count(comment_id BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE forum_comments
  SET like_count = like_count + 1
  WHERE id = comment_id;
END;
$$ LANGUAGE plpgsql;

-- 减少评论点赞数的函数
CREATE OR REPLACE FUNCTION decrement_comment_like_count(comment_id BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE forum_comments
  SET like_count = GREATEST(like_count - 1, 0)
  WHERE id = comment_id;
END;
$$ LANGUAGE plpgsql;

-- 增加帖子浏览量的函数
CREATE OR REPLACE FUNCTION increment_view_count(post_id BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE forum_posts
  SET view_count = view_count + 1
  WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

-- 获取用户论坛统计信息的函数
CREATE OR REPLACE FUNCTION get_user_forum_stats(user_id UUID)
RETURNS TABLE (
  total_posts BIGINT,
  total_comments BIGINT,
  total_likes_received BIGINT,
  total_likes_given BIGINT,
  total_favorites BIGINT,
  join_date TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM forum_posts WHERE author_id = user_id AND status = 'published'),
    (SELECT COUNT(*) FROM forum_comments WHERE user_id = user_id AND status = 'published'),
    (SELECT COALESCE(SUM(like_count), 0) FROM forum_posts WHERE author_id = user_id AND status = 'published'),
    (SELECT COUNT(*) FROM forum_likes WHERE user_id = user_id),
    (SELECT COUNT(*) FROM user_favorites WHERE user_id = user_id),
    (SELECT created_at FROM auth.users WHERE id = user_id)
  ;
END;
$$ LANGUAGE plpgsql;

-- 自动更新帖子updated_at的触发器
CREATE OR REPLACE FUNCTION update_post_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_forum_posts_updated_at
  BEFORE UPDATE ON forum_posts
  FOR EACH ROW
  EXECUTE FUNCTION update_post_updated_at_column();

-- 自动更新评论updated_at的触发器
CREATE OR REPLACE FUNCTION update_comment_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_forum_comments_updated_at
  BEFORE UPDATE ON forum_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_comment_updated_at_column();

-- 创建分区视图用于热门帖子
CREATE OR REPLACE VIEW hot_posts AS
SELECT 
  p.*,
  c.name as category_name,
  c.slug as category_slug,
  u.email as author_email,
  (p.like_count * 2 + p.comment_count * 3 + p.view_count) as hot_score
FROM forum_posts p
LEFT JOIN forum_categories c ON p.category_id = c.id
LEFT JOIN auth.users u ON p.author_id = u.id
WHERE p.status = 'published'
  AND p.created_at >= NOW() - INTERVAL '30 days'
ORDER BY hot_score DESC;

-- 创建分区视图用于最新帖子
CREATE OR REPLACE VIEW recent_posts AS
SELECT 
  p.*,
  c.name as category_name,
  u.email as author_email
FROM forum_posts p
LEFT JOIN forum_categories c ON p.category_id = c.id
LEFT JOIN auth.users u ON p.author_id = u.id
WHERE p.status = 'published'
ORDER BY p.created_at DESC
LIMIT 50;

-- 创建分区视图用于用户活动统计
CREATE OR REPLACE VIEW user_activity_stats AS
SELECT 
  u.id as user_id,
  u.email,
  u.created_at as joined_at,
  COUNT(DISTINCT p.id) as posts_count,
  COUNT(DISTINCT c.id) as comments_count,
  COUNT(DISTINCT l.id) as likes_given_count,
  COALESCE(SUM(p.like_count), 0) as likes_received_count
FROM auth.users u
LEFT JOIN forum_posts p ON u.id = p.author_id AND p.status = 'published'
LEFT JOIN forum_comments c ON u.id = c.user_id AND c.status = 'published'
LEFT JOIN forum_likes l ON u.id = l.user_id
GROUP BY u.id, u.email, u.created_at
ORDER BY posts_count DESC, comments_count DESC;

-- 创建函数来获取分类统计
CREATE OR REPLACE FUNCTION get_category_stats()
RETURNS TABLE (
  category_id BIGINT,
  category_name TEXT,
  category_slug TEXT,
  posts_count BIGINT,
  recent_posts_count BIGINT,
  total_likes BIGINT,
  total_views BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.name,
    c.slug,
    COUNT(p.id) as posts_count,
    COUNT(CASE WHEN p.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_posts_count,
    COALESCE(SUM(p.like_count), 0) as total_likes,
    COALESCE(SUM(p.view_count), 0) as total_views
  FROM forum_categories c
  LEFT JOIN forum_posts p ON c.id = p.category_id AND p.status = 'published'
  WHERE c.is_active = true
  GROUP BY c.id, c.name, c.slug
  ORDER BY posts_count DESC;
END;
$$ LANGUAGE plpgsql;

-- 创建函数来搜索帖子
CREATE OR REPLACE FUNCTION search_posts(
  search_query TEXT,
  category_filter BIGINT DEFAULT NULL,
  post_type_filter TEXT DEFAULT NULL,
  limit_count INTEGER DEFAULT 10,
  offset_count INTEGER DEFAULT 0
)
RETURNS TABLE (
  id BIGINT,
  title TEXT,
  content TEXT,
  summary TEXT,
  category_name TEXT,
  author_email TEXT,
  created_at TIMESTAMPTZ,
  view_count INTEGER,
  like_count INTEGER,
  comment_count INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.title,
    p.content,
    p.summary,
    c.name as category_name,
    u.email as author_email,
    p.created_at,
    p.view_count,
    p.like_count,
    p.comment_count
  FROM forum_posts p
  LEFT JOIN forum_categories c ON p.category_id = c.id
  LEFT JOIN auth.users u ON p.author_id = u.id
  WHERE p.status = 'published'
    AND (
      search_query IS NULL 
      OR p.title ILIKE '%' || search_query || '%'
      OR p.content ILIKE '%' || search_query || '%'
      OR p.tags::TEXT ILIKE '%' || search_query || '%'
    )
    AND (category_filter IS NULL OR p.category_id = category_filter)
    AND (post_type_filter IS NULL OR p.post_type = post_type_filter)
  ORDER BY 
    CASE 
      WHEN p.title ILIKE '%' || search_query || '%' THEN 0
      ELSE 1
    END,
    p.created_at DESC
  LIMIT limit_count OFFSET offset_count;
END;
$$ LANGUAGE plpgsql;