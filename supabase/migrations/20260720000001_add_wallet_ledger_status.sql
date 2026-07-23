-- ============================================================
-- 修复 wallet_ledger 表缺少 status 字段的问题
-- 日期: 2026-07-20
-- ============================================================

-- 1. 添加 status 字段到 wallet_ledger 表
ALTER TABLE public.wallet_ledger
ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'success';

-- 2. 为已有数据设置合理的 status 值
-- 充值记录（type = 'topup'）默认标记为 success
UPDATE public.wallet_ledger
SET status = 'success'
WHERE status IS NULL OR status = '';

-- 3. 添加注释
COMMENT ON COLUMN public.wallet_ledger.status IS '交易状态: success/pending/failed';
