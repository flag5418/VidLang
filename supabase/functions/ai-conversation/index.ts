// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/**
 * AI Conversation Edge Function
 * 创建英语口语对话会话：鉴权 → 计费预检 → 查询上下文 → 构建 instructions → 返回连接参数
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import {
  buildArticleInstructions,
  buildSubtitleInstructions,
  type ArticleSentenceItem,
  type SubtitleItem,
} from './build-instructions.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const subtitleBucket = 'subtitles'

// ─── 辅助函数 ───
function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function getSupabase(req: Request) {
  return createClient(supabaseUrl, supabaseServiceKey, {
    global: { headers: { Authorization: req.headers.get('Authorization')! } },
  })
}

async function getUserId(req: Request): Promise<string | null> {
  const supabase = getSupabase(req)
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) return null
  return data.user.id
}

async function getBalance(userId: string): Promise<number> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const { data } = await supabase
    .from('user_wallet')
    .select('balance_cny')
    .eq('user_id', userId)
    .single()
  return (data?.balance_cny as number) ?? 0
}

async function getSetting(key: string): Promise<string | null> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const { data } = await supabase
    .from('app_settings')
    .select('value')
    .eq('key', key)
    .single()
  return (data?.value as string) ?? null
}

async function getPricingRule(
  ruleCode: string,
): Promise<{ model: string; priceCny: number } | null> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const { data } = await supabase
    .from('pricing_rule')
    .select('model, price_cny')
    .eq('rule_code', ruleCode)
    .eq('status', 'active')
    .single()
  if (!data) return null
  return { model: data.model as string, priceCny: data.price_cny as number }
}

// ─── 查询字幕内容 ───
async function fetchSubtitles(
  videoCode: string,
): Promise<{ title: string; subtitles: SubtitleItem[] }> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  // 查询视频标题
  const { data: video } = await supabase
    .from('video_info')
    .select('title')
    .eq('code', videoCode)
    .single()

  // 查询字幕列表
  const { data: subs } = await supabase
    .from('subtitles')
    .select('content, content_translate')
    .eq('video_code', videoCode)
    .eq('is_deleted', 0)
    .order('start_position', { ascending: true })

  return {
    title: (video?.title as string) ?? 'Video',
    subtitles: (subs ?? []) as SubtitleItem[],
  }
}

async function fetchSubtitlesFromStorage(
  userId: string,
  videoCode: string,
): Promise<{ title: string; subtitles: SubtitleItem[] } | null> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const objectPath = `${userId}/${videoCode}.json`
  const { data, error } = await supabase.storage
    .from(subtitleBucket)
    .download(objectPath)
  if (error || !data) return null
  try {
    const raw = await data.text()
    const parsed = JSON.parse(raw)
    const items = Array.isArray(parsed?.items)
      ? (parsed.items as SubtitleItem[])
      : []
    const title =
      typeof parsed?.title === 'string' && parsed.title.trim().length > 0
        ? parsed.title.trim()
        : 'Video'
    return { title, subtitles: items }
  } catch (_) {
    return null
  }
}
// ─── 查询文章内容 ───
async function fetchArticle(
  articleCode: string,
): Promise<{ title: string; sentences: ArticleSentenceItem[] }> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  // 查询文章标题
  const { data: article } = await supabase
    .from('article')
    .select('title')
    .eq('code', articleCode)
    .single()

  // 查询句子列表
  const { data: sentences } = await supabase
    .from('article_sentence')
    .select('content, content_translate, sentence_index')
    .eq('article_code', articleCode)
    .eq('is_deleted', 0)
    .order('sentence_index', { ascending: true })

  return {
    title: (article?.title as string) ?? 'Article',
    sentences: (sentences ?? []) as ArticleSentenceItem[],
  }
}

// ─── 创建对话会话记录 ───
async function createConversationRecord(
  userId: string,
  sourceType: string,
  sourceCode: string,
): Promise<string> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const { data } = await supabase
    .from('conversation_session')
    .insert({
      user_id: userId,
      source_type: sourceType,
      source_code: sourceCode,
      status: 'active',
      started_at: new Date().toISOString(),
    })
    .select('id')
    .single()
  return (data?.id as string) ?? ''
}

// ─── 预扣费 ───
async function deductPrepay(
  userId: string,
  ruleCode: string,
  priceCny: number,
  currentBalance: number,
  conversationId: string,
  billingMeta: Record<string, any> = {},
): Promise<number> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const newBalance = parseFloat((currentBalance - priceCny).toFixed(4))

  // 记录消费
  const { data: usageData } = await supabase
    .from('usage_event')
    .insert({
      user_id: userId,
      rule_code: ruleCode,
      scene: 'conversation',
      entry: 'start_session',
      request_id: conversationId,
      cost_cny: priceCny,
      meta: { type: 'prepay', is_chargeable: priceCny > 0, ...billingMeta },
    })
    .select('id')
    .single()

  // 记录流水
  await supabase.from('wallet_ledger').insert({
    user_id: userId,
    type: 'consume',
    amount_cny: -priceCny,
    balance_after: newBalance,
    ref_id: usageData?.id,
  })

  // 更新余额
  await supabase
    .from('user_wallet')
    .update({ balance_cny: newBalance, updated_at: new Date().toISOString() })
    .eq('user_id', userId)

  return newBalance
}

// ─── 主服务 ───
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (req.method !== 'POST') {
      return json({ ok: false, error: 'method_not_allowed' }, 405)
    }

    // 1. 鉴权
    const userId = await getUserId(req)
    if (!userId) {
      return json({ ok: false, error: 'unauthorized' }, 401)
    }

    // 2. 解析请求
    const body = (await req.json()) as any
    const {
      source_type: sourceType,
      source_code: sourceCode,
      voice = 'Ethan',
      difficulty = 'intermediate',
      source_title: sourceTitle,
    } = body

    if (!sourceType || !sourceCode) {
      return json(
        {
          ok: false,
          error: 'missing_required_fields',
          message: '需要 source_type 和 source_code',
        },
        400,
      )
    }

    if (!['subtitle', 'article'].includes(sourceType)) {
      return json(
        {
          ok: false,
          error: 'invalid_source_type',
          message: 'source_type 必须为 subtitle 或 article',
        },
        400,
      )
    }

    // 3. 计费预检（创建会话默认不收费；缺少规则时也不阻断）
    const rule = await getPricingRule('ai_conversation')
    const createCost = rule?.priceCny ?? 0
    const balance = await getBalance(userId)
    if (createCost > 0 && balance < createCost) {
      return json(
        {
          ok: false,
          error: 'insufficient_balance',
          message: `余额不足，当前余额 ¥${balance.toFixed(2)}，本次需要 ¥${createCost.toFixed(2)}`,
          balance_cny: balance,
          required_cny: createCost,
        },
        402,
      )
    }

    // 4. 查询上下文内容（优先：Storage → 客户端上报 → 服务端字幕表）
    let instructions: string
    if (sourceType === 'subtitle') {
      const clientItems = (body as any).subtitle_items
      const clientTitle = (body as any).source_title
      const clientSubtitles = Array.isArray(clientItems)
        ? (clientItems as SubtitleItem[])
        : []
      const title =
        typeof clientTitle === 'string' && clientTitle.trim().length > 0
          ? clientTitle.trim()
          : 'Video'

      const fromStorage = await fetchSubtitlesFromStorage(userId, sourceCode)
      const { title: finalTitle, subtitles } = fromStorage
        ? fromStorage
        : clientSubtitles.length > 0
          ? { title, subtitles: clientSubtitles }
          : await fetchSubtitles(sourceCode)

      if (subtitles.length === 0) {
        return json(
          { ok: false, error: 'no_content', message: '该视频没有字幕内容' },
          404,
        )
      }
      instructions = buildSubtitleInstructions(finalTitle, subtitles, difficulty)
    } else {
      const { title, sentences } = await fetchArticle(sourceCode)
      if (sentences.length === 0) {
        return json(
          { ok: false, error: 'no_content', message: '该文章没有句子内容' },
          404,
        )
      }
      instructions = buildArticleInstructions(title, sentences, difficulty)
    }

    // 5. 获取 DashScope API Key
    const qwenApiKey = await getSetting('qwen_api_key')
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

    // 6. 创建会话记录
    const conversationId = await createConversationRecord(
      userId,
      sourceType,
      sourceCode,
    )

    // 7. 预扣费（仅当创建会话收费时）
    const balanceAfter =
      createCost > 0
        ? await deductPrepay(
            userId,
            'ai_conversation',
            createCost,
            balance,
            conversationId,
            {
              action_key: 'ai_conversation',
              action_label: 'AI 对话',
              resource_type: sourceType === 'subtitle' ? 'video' : sourceType,
              resource_code: sourceCode,
              resource_title: sourceTitle ?? '',
              source_page: 'conversation_page',
              action_name: 'start_session',
            },
          )
        : balance

    // 8. 返回连接参数
    const wsUrl =
      'wss://dashscope.aliyuncs.com/api-ws/v1/realtime?model=qwen3.5-omni-plus-realtime'

    return json({
      ok: true,
      conversation_id: conversationId,
      ws_url: wsUrl,
      api_key: qwenApiKey,
      instructions,
      voice,
      model: 'qwen3.5-omni-plus-realtime',
      cost_cny: createCost,
      balance_after: balanceAfter,
    })
  } catch (e: any) {
    console.error('ai-conversation error:', e.message || e)
    return json(
      { ok: false, error: 'internal_error', message: e.message || String(e) },
      500,
    )
  }
})
