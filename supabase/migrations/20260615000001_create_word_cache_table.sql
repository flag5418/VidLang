-- ============================================================
-- 单词释义全局缓存表
-- 所有用户共享，避免重复调用 AI 查词，节省费用并提高速度
-- ============================================================

CREATE TABLE IF NOT EXISTS public.word_cache (
  id          BIGSERIAL PRIMARY KEY,
  word        TEXT UNIQUE NOT NULL,          -- 单词（小写）
  result      JSONB NOT NULL DEFAULT '{}',   -- WordDetail JSON 结构
  query_count INTEGER NOT NULL DEFAULT 1,    -- 命中次数
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 查询索引（按单词精确匹配）
CREATE INDEX IF NOT EXISTS idx_word_cache_word ON public.word_cache(word);

-- 清理过期缓存（保留 180 天）
CREATE INDEX IF NOT EXISTS idx_word_cache_updated ON public.word_cache(updated_at);

-- RLS：允许已登录用户读取和写入
ALTER TABLE public.word_cache ENABLE ROW LEVEL SECURITY;

-- 读权限：所有已登录用户
DROP POLICY IF EXISTS "word_cache_read" ON public.word_cache;
CREATE POLICY "word_cache_read" ON public.word_cache
  FOR SELECT
  TO authenticated
  USING (true);

-- 写权限：所有已登录用户（UPSERT 模式，重复单词会冲突更新）
DROP POLICY IF EXISTS "word_cache_write" ON public.word_cache;
CREATE POLICY "word_cache_write" ON public.word_cache
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "word_cache_update" ON public.word_cache;
CREATE POLICY "word_cache_update" ON public.word_cache
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- 自动更新 updated_at 触发器
CREATE OR REPLACE FUNCTION update_word_cache_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_word_cache_updated_at ON public.word_cache;
CREATE TRIGGER trg_word_cache_updated_at
  BEFORE UPDATE ON public.word_cache
  FOR EACH ROW
  EXECUTE FUNCTION update_word_cache_updated_at();

-- RPC：原子递增 query_count
CREATE OR REPLACE FUNCTION bump_word_cache_count(p_word TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.word_cache
     SET query_count = query_count + 1
   WHERE word = p_word;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
