// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
/**
 * AI Learning Suggestion Edge Function
 *
 * 接收用户学习统计数据，调用千问 API 生成约 150 字的结构化学习建议。
 */

import { corsHeaders } from '../_shared/cors.ts'

// ─── 环境变量 ───
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// ─── 辅助 ───
function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function getUserId(req: Request): Promise<string | null> {
  const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2')
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    global: { headers: { Authorization: req.headers.get('Authorization')! } },
  })
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) return null
  return data.user.id
}

async function getSetting(key: string): Promise<string | null> {
  const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2')
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const { data } = await supabase
    .from('app_settings')
    .select('value')
    .eq('key', key)
    .single()
  return (data?.value as string) ?? null
}

// ─── 千问 API 调用 ───
async function callQwen(
  apiKey: string,
  baseUrl: string,
  messages: Array<{ role: string; content: string }>,
): Promise<string> {
  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 30000)

  try {
    const resp = await fetch(`${baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'qwen-plus',
        messages,
        max_tokens: 300,
        temperature: 0.7,
      }),
      signal: controller.signal,
    })

    if (!resp.ok) {
      throw new Error(`Qwen API error: ${resp.status}`)
    }

    const data = (await resp.json()) as any
    const content = data?.choices?.[0]?.message?.content
    if (!content) {
      throw new Error('Qwen API returned empty content')
    }
    return content.trim()
  } finally {
    clearTimeout(timeout)
  }
}

// ─── 构造 Prompt ───
function buildPrompt(stats: any): string {
  const { totalDays, totalDurationMinutes, learnedResources, totalResources, streakDays, byType, weeklyTrend } = stats

  const hours = Math.floor(totalDurationMinutes / 60)
  const mins = totalDurationMinutes % 60
  const completionPct = totalResources > 0
    ? Math.round((learnedResources / totalResources) * 100)
    : 0

  const trendSummary = weeklyTrend
    ?.map((d: any) => `${d.date.slice(5)}:${d.minutes}分钟`)
    .join('，') ?? '无数据'

  return `你是语言学习教练，根据以下学习数据，生成约150字的结构化学习建议。

数据：
- 累计学习 ${totalDays} 天
- 总时长 ${hours}小时${mins}分钟
- 完成资源 ${learnedResources}/${totalResources}（${completionPct}%）
- 连续学习 ${streakDays} 天
- 视频：${byType?.video?.learned ?? 0}/${byType?.video?.total ?? 0}
- 音频：${byType?.audio?.learned ?? 0}/${byType?.audio?.total ?? 0}
- 文章：${byType?.article?.learned ?? 0}/${byType?.article?.total ?? 0}
- 近7天趋势(分钟)：${trendSummary}

要求：
1. 先总体评价学习状况（1-2句）
2. 指出1-2个可改进方向
3. 给出1-2条具体可行的建议
4. 语气温暖鼓励，约150字
5. 纯文本输出，不用 Markdown 格式`
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
      totalDays,
      totalDurationMinutes,
      learnedResources,
      totalResources,
      streakDays,
      byType,
      weeklyTrend,
    } = body

    // 必填校验
    if (
      totalDays == null ||
      totalDurationMinutes == null ||
      learnedResources == null ||
      totalResources == null ||
      streakDays == null
    ) {
      return json(
        {
          ok: false,
          error: 'missing_required_fields',
          message: '需要 totalDays, totalDurationMinutes, learnedResources, totalResources, streakDays',
        },
        400,
      )
    }

    // 3. 获取 API 配置
    const qwenApiKey = await getSetting('qwen_api_key')
    if (!qwenApiKey) {
      return json(
        { ok: false, error: 'api_not_configured', message: 'Qwen API Key 未配置' },
        500,
      )
    }

    const qwenBaseUrl =
      (await getSetting('qwen_base_url')) ||
      'https://dashscope.aliyuncs.com/compatible-mode/v1'

    // 4. 构造 prompt 并调用千问
    const prompt = buildPrompt(body)

    let suggestion: string
    try {
      suggestion = await callQwen(qwenApiKey, qwenBaseUrl, [
        { role: 'user', content: prompt },
      ])
    } catch (e: any) {
      console.error('Qwen API error:', e.message || e)
      return json(
        {
          ok: false,
          error: 'ai_unavailable',
          message: 'AI 服务暂时不可用，请稍后重试',
        },
        503,
      )
    }

    // 5. 返回结果
    return json({
      ok: true,
      suggestion,
    })
  } catch (e: any) {
    console.error('ai-learning-suggestion error:', e.message || e)
    return json(
      { ok: false, error: 'internal_error', message: e.message || String(e) },
      500,
    )
  }
})
