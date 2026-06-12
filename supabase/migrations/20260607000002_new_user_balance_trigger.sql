-- ============================================================
-- 新用户注册时自动创建钱包并赠送余额
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  default_balance NUMERIC(10,4);
BEGIN
  -- 读取默认赠送金额
  SELECT COALESCE(
    (SELECT value::NUMERIC(10,4) FROM public.app_settings WHERE key = 'default_new_user_balance'),
    10.00
  ) INTO default_balance;

  -- 创建钱包
  INSERT INTO public.user_wallet (user_id, balance_cny)
  VALUES (NEW.id, default_balance);

  -- 写入流水记录（充值类型）
  INSERT INTO public.wallet_ledger (
    user_id, type, amount_cny, balance_after,
    channel, paid_at, note
  ) VALUES (
    NEW.id, 'topup', default_balance, default_balance,
    'system_grant', NOW(), '新用户注册赠送'
  );

  RETURN NEW;
END;
$$;

-- 绑定到 auth.users 表的 INSERT 触发器
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
