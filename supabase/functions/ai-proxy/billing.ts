// deno-lint-ignore-file no-explicit-any
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

/** 校验 JWT 获取 user_id */
export async function getUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;
  const token = authHeader.replace("Bearer ", "");
  try {
    const { data, error } = await supabase.auth.getUser(token);
    if (error || !data.user) return null;
    return data.user.id;
  } catch {
    return null;
  }
}

/** 查询用户余额 */
export async function getBalance(userId: string): Promise<number> {
  const { data } = await supabase
    .from("user_wallet")
    .select("balance_cny")
    .eq("user_id", userId)
    .single();
  return (data?.balance_cny as number) ?? 0;
}

/** 查询计费规则 */
export async function getPricingRule(
  ruleCode: string
): Promise<{ model: string; priceCny: number } | null> {
  const { data } = await supabase
    .from("pricing_rule")
    .select("model, price_cny")
    .eq("rule_code", ruleCode)
    .eq("status", "active")
    .single();
  if (!data) return null;
  return {
    model: data.model as string,
    priceCny: data.price_cny as number,
  };
}

/** 幂等检查 */
export async function checkIdempotent(
  requestId: string
): Promise<boolean> {
  const { count } = await supabase
    .from("usage_event")
    .select("id", { count: "exact", head: true })
    .eq("request_id", requestId);
  return (count ?? 0) > 0;
}

/** 扣费事务：写 usage_event + wallet_ledger + 更新 user_wallet */
export async function deduct(
  userId: string,
  ruleCode: string,
  scene: string,
  entry: string,
  requestId: string,
  priceCny: number,
  currentBalance: number,
  meta: Record<string, any> = {}
): Promise<number> {
  const newBalance = parseFloat((currentBalance - priceCny).toFixed(4));

  // 插入消费记录
  const { data: usageData } = await supabase
    .from("usage_event")
    .insert({
      user_id: userId,
      rule_code: ruleCode,
      scene,
      entry,
      request_id: requestId,
      cost_cny: priceCny,
      meta,
    })
    .select("id")
    .single();

  const usageId = usageData?.id;

  // 插入流水（消费）
  await supabase.from("wallet_ledger").insert({
    user_id: userId,
    type: "consume",
    amount_cny: -priceCny,
    balance_after: newBalance,
    ref_id: usageId,
  });

  // 更新余额
  await supabase
    .from("user_wallet")
    .update({ balance_cny: newBalance, updated_at: new Date().toISOString() })
    .eq("user_id", userId);

  return newBalance;
}

/** 读取 app_settings */
export async function getSetting(key: string): Promise<string | null> {
  const { data } = await supabase
    .from("app_settings")
    .select("value")
    .eq("key", key)
    .single();
  return (data?.value as string) ?? null;
}
