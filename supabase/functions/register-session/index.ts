// deno-lint-ignore-file no-explicit-any
/**
 * register-session Edge Function
 * 排他性登录：UPSERT 当前用户的活跃会话，覆盖旧 session
 * 客户端在每次 Supabase 登录成功后调用
 */

import { corsHeaders } from "../_shared/cors.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  // CORS 预检
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return json({ ok: false, error: "method_not_allowed" }, 405);
    }

    // 鉴权：从 Authorization header 获取用户
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ ok: false, error: "unauthorized" }, 401);
    }

    const token = authHeader.replace("Bearer ", "");
    const supabaseAuth = createClient(supabaseUrl, supabaseServiceKey);
    const { data: userData, error: authError } = await supabaseAuth.auth.getUser(token);
    if (authError || !userData.user) {
      return json({ ok: false, error: "unauthorized" }, 401);
    }

    const userId = userData.user.id;

    // 解析请求体
    const body = await req.json() as any;
    const { session_id, device_info } = body;

    if (!session_id) {
      return json({ ok: false, error: "missing_session_id" }, 400);
    }

    // UPSERT：覆盖旧 session（每个用户只保留一条）
    const { error: upsertError } = await supabaseAuth
      .from("user_active_session")
      .upsert({
        user_id: userId,
        session_id: session_id,
        device_info: device_info ?? null,
        logged_in_at: new Date().toISOString(),
      }, { onConflict: "user_id" });

    if (upsertError) {
      console.error("register-session upsert error:", upsertError.message);
      return json({ ok: false, error: "upsert_failed", message: upsertError.message }, 500);
    }

    return json({ ok: true, session_id });
  } catch (e: any) {
    console.error("register-session error:", e.message || e);
    return json({ ok: false, error: "internal_error", message: e.message || String(e) }, 500);
  }
});

function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
