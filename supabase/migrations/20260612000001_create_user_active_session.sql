-- 排他性登录：用户活跃会话表
-- 每个 Supabase 用户只保留一条记录，新登录 UPSERT 覆盖旧 session

CREATE TABLE IF NOT EXISTS user_active_session (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  device_info TEXT,
  logged_in_at TIMESTAMPTZ DEFAULT now()
);

-- 开启 Realtime，客户端订阅此表的变更以实现被顶号检测
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'user_active_session'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_active_session;
  END IF;
END $$;

-- RLS 策略：用户只能读写自己的 session 记录
ALTER TABLE user_active_session ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own session" ON user_active_session;
CREATE POLICY "Users can manage own session"
  ON user_active_session
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
