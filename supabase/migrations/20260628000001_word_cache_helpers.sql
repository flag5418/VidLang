-- ============================================================
-- word_cache 辅助函数
-- 用于统计、聚合查询
-- ============================================================

-- 1. 计算总查询次数
CREATE OR REPLACE FUNCTION sum_word_cache_query_count()
RETURNS BIGINT AS $$
  SELECT COALESCE(SUM(query_count), 0) FROM public.word_cache;
$$ LANGUAGE SQL SECURITY DEFINER;

-- 2. 按难度分布统计
CREATE OR REPLACE FUNCTION get_word_cache_difficulty_distribution()
RETURNS TABLE(
  difficulty TEXT,
  count BIGINT
) AS $$
  SELECT 
    result->>'difficulty' AS difficulty,
    COUNT(*) AS count
  FROM public.word_cache
  WHERE result->>'difficulty' IS NOT NULL
  GROUP BY result->>'difficulty'
  ORDER BY count DESC;
$$ LANGUAGE SQL SECURITY DEFINER;

-- 3. 获取缓存命中率统计（最近 N 天）
CREATE OR REPLACE FUNCTION get_word_cache_hit_stats(days INT DEFAULT 7)
RETURNS TABLE(
  date TEXT,
  new_words BIGINT,
  total_queries BIGINT,
  unique_words_queried BIGINT
) AS $$
  SELECT
    DATE(created_at)::TEXT AS date,
    COUNT(*) AS new_words,
    SUM(query_count) AS total_queries,
    COUNT(DISTINCT word) AS unique_words_queried
  FROM public.word_cache
  WHERE created_at >= NOW() - INTERVAL '1 day' * days
  GROUP BY DATE(created_at)
  ORDER BY date DESC;
$$ LANGUAGE SQL SECURITY DEFINER;

-- 4. 批量检查单词是否在缓存中
CREATE OR REPLACE FUNCTION check_words_in_cache(words TEXT[])
RETURNS TABLE(
  word TEXT,
  found BOOLEAN,
  query_count INTEGER
) AS $$
  SELECT 
    unnest(words) AS word,
    EXISTS(SELECT 1 FROM public.word_cache wc WHERE wc.word = unnest(words)) AS found,
    COALESCE((SELECT query_count FROM public.word_cache wc WHERE wc.word = unnest(words)), 0) AS query_count;
$$ LANGUAGE SQL SECURITY DEFINER;

-- 5. 获取低频词（可清理候选）
CREATE OR REPLACE FUNCTION get_stale_cache_entries(days INT DEFAULT 180, min_queries INT DEFAULT 0)
RETURNS TABLE(
  id BIGINT,
  word TEXT,
  query_count INTEGER,
  updated_at TIMESTAMPTZ
) AS $$
  SELECT id, word, query_count, updated_at
  FROM public.word_cache
  WHERE updated_at < NOW() - INTERVAL '1 day' * days
    AND query_count <= min_queries
  ORDER BY updated_at ASC
  LIMIT 1000;
$$ LANGUAGE SQL SECURITY DEFINER;
