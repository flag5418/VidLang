// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/**
 * AI Proxy Edge Function
 * 统一入口：鉴权 → 计费预检 → 路由 AI 客户端 → 扣费 → 返回
 */

import { corsHeaders } from '../_shared/cors.ts'
import {
  checkIdempotent,
  deduct,
  getBalance,
  getPricingRule,
  getSetting,
  getUserId,
} from './billing.ts'
import {
  definition,
  translateConversationResponse,
  translateText,
  wordLink,
} from './clients/qwen-chat.ts'
import { qwenTts } from './clients/qwen-tts.ts'

// ─── 路由表 ───
const ROUTES: Record<
  string,
  (apiKey: string, baseUrl: string, params: any) => Promise<any>
> = {
  ai_definition: (key, url, p) => definition(key, url, p.word, p.sentence),
  ai_translate: (key, url, p) =>
    translateText(key, url, p.text, p.target_language || '中文'),
  ai_word_link: (key, url, p) => wordLink(key, url, p.word, p.sentence),
  ai_translate_conversation: (key, url, p) =>
    translateConversationResponse(key, url, p.text),
}

// ─── 主服务 ───
Deno.serve(async (req: Request) => {
  // CORS 预检
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. 仅接受 POST
    if (req.method !== 'POST') {
      return json({ ok: false, error: 'method_not_allowed' }, 405)
    }

    // 2. 解析请求体
    const body = (await req.json()) as any
    const {
      rule_code: ruleCode,
      scene,
      entry,
      request_id: requestId,
      params = {},
    } = body

    if (!ruleCode || !scene || !entry || !requestId) {
      return json({ ok: false, error: 'missing_required_fields' }, 400)
    }

    // 3. 鉴权
    const userId = await getUserId(req)
    if (!userId) {
      return json({ ok: false, error: 'unauthorized' }, 401)
    }

    // 4. 幂等检查
    const alreadyDone = await checkIdempotent(requestId)
    if (alreadyDone) {
      return json(
        { ok: false, error: 'duplicate_request', message: '该请求已处理' },
        409,
      )
    }

    // 5. 查询计费规则
    const rule = await getPricingRule(ruleCode)
    if (!rule) {
      return json(
        {
          ok: false,
          error: 'unknown_rule_code',
          message: `未知计费规则: ${ruleCode}`,
        },
        400,
      )
    }

    // 6. 余额检查
    const balance = await getBalance(userId)
    if (balance < rule.priceCny) {
      return json(
        {
          ok: false,
          error: 'insufficient_balance',
          message: `余额不足，当前余额 ¥${balance.toFixed(2)}，本次需要 ¥${rule.priceCny.toFixed(2)}`,
          balance_cny: balance,
          required_cny: rule.priceCny,
        },
        402,
      )
    }

    // 7a. 对话相关的纯计费/结算路由（不需要外部 AI 调用）
    if (
      ruleCode === 'ai_conversation_settle' ||
      ruleCode === 'ai_conversation_question' ||
      ruleCode === 'ai_conversation_answer'
    ) {
      let result: any = { ok: true }
      if (ruleCode === 'ai_conversation_settle') {
        result = await settleConversation(userId, params)
      } else {
        result = {
          conversation_id: params.conversation_id,
          turn_index: params.turn_index,
          billed: ruleCode,
        }
      }

      const newBalance = await deduct(
        userId,
        ruleCode,
        scene,
        entry,
        requestId,
        rule.priceCny,
        balance,
        buildUsageMeta(ruleCode, scene, entry, params, {
          conversation_id: params.conversation_id,
          turn_index: params.turn_index,
          turn_count: params.turn_count,
          duration_seconds: params.duration_seconds,
        }),
      )

      return json({
        ok: true,
        rule_code: ruleCode,
        cost_cny: rule.priceCny,
        balance_after: newBalance,
        result,
      })
    }

    // 7. 获取 API 配置
    const qwenApiKey = await getSetting('qwen_api_key')
    const qwenBaseUrl =
      (await getSetting('qwen_base_url')) ||
      'https://dashscope.aliyuncs.com/compatible-mode/v1'

    // 7b. TTS 走独立路由（API 格式不同）
    let result: any
    if (ruleCode === 'ai_tts') {
      if (!qwenApiKey) {
        return json(
          {
            ok: false,
            error: 'tts_not_configured',
            message: 'TTS API Key 未配置',
          },
          500,
        )
      }
      result = await qwenTts(qwenApiKey, {
        text: params.text,
        voice: params.voice,
      })
    } else {
      // 7c. Chat 类路由
      if (!qwenApiKey) {
        return json(
          {
            ok: false,
            error: 'api_not_configured',
            message: 'Qwen API Key 未配置',
          },
          500,
        )
      }
      const handler = ROUTES[ruleCode]
      if (!handler) {
        return json(
          {
            ok: false,
            error: 'unsupported_rule',
            message: `不支持的规则: ${ruleCode}`,
          },
          400,
        )
      }
      result = await handler(qwenApiKey, qwenBaseUrl, params)
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
      buildUsageMeta(ruleCode, scene, entry, params, {
        word: params.word,
        sentence: params.sentence,
        text: params.text,
      }),
    )

    // 9. 返回成功
    return json({
      ok: true,
      rule_code: ruleCode,
      cost_cny: rule.priceCny,
      balance_after: newBalance,
      result,
    })
  } catch (e: any) {
    console.error('ai-proxy error:', e.message || e)
    return json(
      { ok: false, error: 'internal_error', message: e.message || String(e) },
      500,
    )
  }
})

// ─── 对话结算 ───
async function settleConversation(userId: string, params: any): Promise<any> {
  const { createClient } =
    await import('https://esm.sh/@supabase/supabase-js@2')
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const conversationId = params.conversation_id
  const turnCount = params.turn_count ?? 0
  const durationSeconds = params.duration_seconds ?? 0

  if (!conversationId) {
    throw new Error('缺少 conversation_id')
  }

  // 更新会话记录
  const { error } = await supabase
    .from('conversation_session')
    .update({
      status: 'completed',
      turn_count: turnCount,
      duration_seconds: durationSeconds,
      ended_at: new Date().toISOString(),
    })
    .eq('id', conversationId)
    .eq('user_id', userId)

  if (error) {
    throw new Error(`结算失败: ${error.message}`)
  }

  return {
    conversation_id: conversationId,
    turn_count: turnCount,
    duration_seconds: durationSeconds,
    status: 'completed',
  }
}

// ─── 辅助 ───
function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function buildUsageMeta(
  ruleCode: string,
  scene: string,
  entry: string,
  params: any,
  extra: Record<string, any> = {},
) {
  const billing = typeof params?.billing === 'object' && params.billing
    ? params.billing
    : {}
  const action = actionMeta(ruleCode)
  return {
    action_key: billing.action_key ?? action.key,
    action_label: billing.action_label ?? action.label,
    resource_type: billing.resource_type,
    resource_code: billing.resource_code,
    resource_title: billing.resource_title,
    folder_code: billing.folder_code,
    folder_title: billing.folder_title,
    source_page: billing.source_page ?? scene,
    action_name: billing.action_name ?? entry,
    is_chargeable: true,
    ...extra,
  }
}

function actionMeta(ruleCode: string): { key: string; label: string } {
  if (ruleCode.startsWith('ai_conversation')) {
    return { key: 'ai_conversation', label: 'AI 对话' }
  }
  if (ruleCode === 'st_pron_score') {
    return { key: 'st_pron_score', label: '跟读评分' }
  }
  if (ruleCode === 'ai_test_plan') {
    return { key: 'ai_test_plan', label: 'AI 出题' }
  }
  if (ruleCode === 'ai_definition') {
    return { key: 'ai_definition', label: 'AI 释义' }
  }
  if (ruleCode === 'ai_translate' || ruleCode === 'ai_translate_conversation') {
    return { key: 'ai_translate', label: 'AI 翻译' }
  }
  if (ruleCode === 'ai_tts') {
    return { key: 'ai_tts', label: 'AI 朗读' }
  }
  return { key: ruleCode, label: ruleCode }
}
