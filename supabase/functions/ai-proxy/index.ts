// deno-lint-ignore-file no-explicit-any
/**
 * AI Proxy Edge Function
 * 统一入口：鉴权 → 计费预检 → 路由 AI 客户端 → 扣费 → 返回
 */

import { corsHeaders } from "../_shared/cors.ts";
import {
  getUserId,
  getBalance,
  getPricingRule,
  checkIdempotent,
  deduct,
  getSetting,
} from "./billing.ts";
import { definition, translateText, wordLink } from "./clients/qwen-chat.ts";
import { qwenTts } from "./clients/qwen-tts.ts";

// ─── 路由表 ───
const ROUTES: Record<string, (apiKey: string, baseUrl: string, params: any) => Promise<any>> = {
  ai_definition: (key, url, p) => definition(key, url, p.word, p.sentence),
  ai_translate: (key, url, p) =>
    translateText(key, url, p.text, p.target_language || "中文"),
  ai_word_link: (key, url, p) => wordLink(key, url, p.word, p.sentence),
};

// ─── 主服务 ───
Deno.serve(async (req: Request) => {
  // CORS 预检
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. 仅接受 POST
    if (req.method !== "POST") {
      return json({ ok: false, error: "method_not_allowed" }, 405);
    }

    // 2. 解析请求体
    const body = await req.json() as any;
    const {
      rule_code: ruleCode,
      scene,
      entry,
      request_id: requestId,
      params = {},
    } = body;

    if (!ruleCode || !scene || !entry || !requestId) {
      return json({ ok: false, error: "missing_required_fields" }, 400);
    }

    // 3. 鉴权
    const userId = await getUserId(req);
    if (!userId) {
      return json({ ok: false, error: "unauthorized" }, 401);
    }

    // 4. 幂等检查
    const alreadyDone = await checkIdempotent(requestId);
    if (alreadyDone) {
      return json({ ok: false, error: "duplicate_request", message: "该请求已处理" }, 409);
    }

    // 5. 查询计费规则
    const rule = await getPricingRule(ruleCode);
    if (!rule) {
      return json({ ok: false, error: "unknown_rule_code", message: `未知计费规则: ${ruleCode}` }, 400);
    }

    // 6. 余额检查
    const balance = await getBalance(userId);
    if (balance < rule.priceCny) {
      return json({
        ok: false,
        error: "insufficient_balance",
        message: `余额不足，当前余额 ¥${balance.toFixed(2)}，本次需要 ¥${rule.priceCny.toFixed(2)}`,
        balance_cny: balance,
        required_cny: rule.priceCny,
      }, 402);
    }

    // 7. 获取 API 配置
    const qwenApiKey = await getSetting("qwen_api_key");
    const qwenBaseUrl = (await getSetting("qwen_base_url")) || "https://dashscope.aliyuncs.com/compatible-mode/v1";

    // 7a. TTS 走独立路由（API 格式不同）
    let result: any;
    if (ruleCode === "ai_tts") {
      if (!qwenApiKey) {
        return json({ ok: false, error: "tts_not_configured", message: "TTS API Key 未配置" }, 500);
      }
      result = await qwenTts(qwenApiKey, { text: params.text, voice: params.voice });
    } else {
      // 7b. Chat 类路由
      if (!qwenApiKey) {
        return json({ ok: false, error: "api_not_configured", message: "Qwen API Key 未配置" }, 500);
      }
      const handler = ROUTES[ruleCode];
      if (!handler) {
        return json({ ok: false, error: "unsupported_rule", message: `不支持的规则: ${ruleCode}` }, 400);
      }
      result = await handler(qwenApiKey, qwenBaseUrl, params);
    }

    // 8. 扣费
    const newBalance = await deduct(
      userId,
      ruleCode,
      scene,
      entry,
      requestId,
      rule.priceCny,
      balance,
      { word: params.word, sentence: params.sentence, text: params.text },
    );

    // 9. 返回成功
    return json({
      ok: true,
      rule_code: ruleCode,
      cost_cny: rule.priceCny,
      balance_after: newBalance,
      result,
    });
  } catch (e: any) {
    console.error("ai-proxy error:", e.message || e);
    return json({ ok: false, error: "internal_error", message: e.message || String(e) }, 500);
  }
});

// ─── 辅助 ───
function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
