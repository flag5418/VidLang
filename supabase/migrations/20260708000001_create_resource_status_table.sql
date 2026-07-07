-- ═══════════════════════════════════════════════════════════════
-- resource_status 表：资源删除状态标记
--
-- 用途：
--   1. 客户端删除资源时，标记 video_code 为 'deleted' 状态
--   2. ai-test-plan 综合测试出题前，批量查询状态，过滤已删除资源
--   3. 作为 subtitle-storage 物理删除的逻辑补充（双重保障）
--
-- 核心问题：用户在本地删除文件夹中某个资源后，如果 subtitle-storage
--           的物理删除因网络失败等原因未执行，已删资源的字幕文件仍
--           在 Storage 中，导致综合测试时会对已删资源出题。
--
-- 解决方案：独立的 status 标记表，即使物理删除失败也能通过逻辑标记拦截。
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS resource_status (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL,
  video_code TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'deleted')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- 联合唯一约束：同一用户同一资源只有一条状态记录
  UNIQUE(user_id, video_code)
);

-- 索引：按用户查询 + 按状态过滤（用于 batch_check 高效查询）
CREATE INDEX IF NOT EXISTS idx_resource_status_user_id 
  ON resource_status(user_id);

CREATE INDEX IF NOT EXISTS idx_resource_status_user_deleted 
  ON resource_status(user_id, status) 
  WHERE status = 'deleted';

-- 启用 RLS（行级安全）
ALTER TABLE resource_status ENABLE ROW LEVEL SECURITY;

-- 策略：用户只能操作自己的资源状态
CREATE POLICY "Users can manage own resource status" ON resource_status
  FOR ALL USING (auth.uid() = user_id);

-- 策略：Service Role 可读写所有记录（Edge Functions 使用）
CREATE POLICY "Service role full access" ON resource_status
  FOR ALL USING (true);

COMMENT ON TABLE resource_status IS '资源删除状态标记表 — 用于 ai-test-plan 综合测试时过滤已删除资源';
COMMENT ON COLUMN resource_status.user_id IS '用户 ID（关联 auth.users）';
COMMENT ON COLUMN resource_status.video_code IS '资源的 video_code（与 subtitle-storage 中的标识一致）';
COMMENT ON COLUMN resource_status.status IS '状态: active=有效, deleted=已删除';
COMMENT ON COLUMN resource_status.updated_at IS '最后更新时间';
