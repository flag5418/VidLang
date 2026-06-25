// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
import { corsHeaders } from '../_shared/cors.ts'
import { QWEN_MODELS } from '../ai-proxy/clients/qwen-chat.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

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
  const { data } = await supabase.from('settings').select('value').eq('key', key).limit(1)
  return data?.[0]?.value ?? null
}

async function getBalance(userId: string): Promise<number> {
  const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2')
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const { data } = await supabase.from('user_balance').select('balance_cny').eq('user_id', userId).limit(1)
  return data?.[0]?.balance_cny ?? 0
}

async function deduct(userId: string, amount: number, meta: any): Promise<number> {
  const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2')
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const { data: bal } = await supabase.from('user_balance').select('balance_cny').eq('user_id', userId).limit(1)
  const current = bal?.[0]?.balance_cny ?? 0
  const newBalance = Math.max(0, current - amount)
  await supabase.from('user_balance').update({ balance_cny: newBalance }).eq('user_id', userId)
  await supabase.from('usage_log').insert({ user_id: userId, amount_cny: amount, ...meta })
  return newBalance
}

async function callQwen(apiKey: string, baseUrl: string, messages: any[], temperature = 0.3): Promise<any> {
  const uri = `${baseUrl}/chat/completions`
  const response = await fetch(uri, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: QWEN_MODELS.TURBO,
      messages,
      temperature,
      response_format: { type: 'json_object' },
    }),
  })
  if (!response.ok) {
    const text = await response.text()
    throw new Error(`Qwen API error: ${response.status} - ${text}`)
  }
  const result = await response.json()
  const content = result.choices?.[0]?.message?.content
  if (!content) throw new Error('Empty response from Qwen')
  return JSON.parse(content)
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405)

  try {
    const userId = await getUserId(req)
    if (!userId) return json({ ok: false, error: 'unauthorized' }, 401)

    const body = (await req.json()) as any
    const type = body.type as string

    if (!type) return json({ ok: false, error: 'missing_type' }, 400)

    const qwenApiKey = await getSetting('qwen_api_key')
    const qwenBaseUrl = (await getSetting('qwen_base_url')) || 'https://dashscope.aliyuncs.com/compatible-mode/v1'

    if (!qwenApiKey) {
      return json({ ok: false, error: 'api_not_configured', message: 'Qwen API Key 未配置' }, 500)
    }

    if (type === 'speech_recognize') {
      const audioBase64 = body.audio_base64 as string
      const includePronunciation = body.include_pronunciation !== false

      if (!audioBase64) {
        return json({ ok: false, error: 'missing_audio' }, 400)
      }

      const recognizeResult = await callQwen(qwenApiKey, qwenBaseUrl, [
        {
          role: 'system',
          content: `你是一个专业的音频转写和翻译AI。
用户将提供一段音频的描述（因为当前环境无法直接处理音频，你需要根据可能的音频内容生成合理的转写结果）。

但实际上，你需要等待用户提供文本内容。这里暂时返回空结果。
注意：真正的语音识别需要使用阿里云的语音识别API（Paraformer/SenseVoice）。
当前版本作为占位实现，后续集成真正的语音识别服务。

请返回JSON格式：
{
  "ok": true,
  "language": "检测到的语言代码",
  "items": []
}`,
        },
        {
          role: 'user',
          content: '请识别此音频内容并返回带时间戳的转写结果。',
        },
      ], 0.1)

      if (!recognizeResult.ok) {
        return json({ ok: false, error: 'recognition_failed', message: '语音识别失败' })
      }

      const items = recognizeResult.items || []

      if (includePronunciation && items.length > 0) {
        const pronunciationResult = await callQwen(qwenApiKey, qwenBaseUrl, [
          {
            role: 'system',
            content: `你是一个专业的语言学习助手。请为以下外语内容生成中文注音和翻译。

规则：
1. 用常见汉字标注发音，选择声调最接近的汉字
2. 每个词对应一组汉字
3. 这是辅助工具，不求完全精确，只求快速上手
4. 目标：让中文母语者30秒内能近似发音

返回JSON格式：
{
  "items": [
    {
      "index": 0,
      "pronunciation": "整行中文注音",
      "pronunciation_map": [{"word": "原文词", "zh": "中文注音"}],
      "content_translate": "中文翻译"
    }
  ]
}`,
          },
          {
            role: 'user',
            content: JSON.stringify({
              language: recognizeResult.language || 'en',
              texts: items.map((item: any, i: number) => ({ index: i, content: item.content })),
            }),
          },
        ])

        if (pronunciationResult.items) {
          for (const pItem of pronunciationResult.items) {
            const idx = pItem.index ?? 0
            if (idx < items.length) {
              items[idx].pronunciation = pItem.pronunciation
              items[idx].pronunciation_map = pItem.pronunciation_map
              if (!items[idx].content_translate && pItem.content_translate) {
                items[idx].content_translate = pItem.content_translate
              }
            }
          }
        }
      }

      return json({
        ok: true,
        language: recognizeResult.language || 'en',
        items,
        source: 'ai_recognize',
      })
    }

    if (type === 'lyrics_search') {
      const title = (body.title as string)?.trim() || ''
      const artist = (body.artist as string)?.trim() || ''
      const includePronunciation = body.include_pronunciation !== false

      if (!title) {
        return json({ ok: false, error: 'missing_title' }, 400)
      }

      const lyricsResult = await callQwen(qwenApiKey, qwenBaseUrl, [
        {
          role: 'system',
          content: `你是一个专业的歌词搜索助手。请搜索以下歌曲的歌词，并返回带时间轴的歌词。

返回JSON格式：
{
  "ok": true/false,
  "language": "语言代码(en/ja/ko/fr/...)",
  "title": "歌曲名",
  "artist": "演唱者",
  "items": [
    {
      "content": "原文歌词行",
      "start_ms": 起始毫秒数,
      "end_ms": 结束毫秒数,
      "content_translate": "中文翻译"
    }
  ]
}

注意：
1. 尽量返回准确的时间轴，如果不确定可以估算
2. 如果是非英语歌词，保留原文并提供中文翻译
3. 如果搜不到这首歌的歌词，返回 ok: false
4. items中的时间轴单位为毫秒`,
        },
        {
          role: 'user',
          content: JSON.stringify({ title, artist }),
        },
      ])

      if (!lyricsResult.ok) {
        return json({ ok: false, error: 'lyrics_not_found', message: '未能找到歌词' })
      }

      let items = lyricsResult.items || []

      if (includePronunciation && items.length > 0) {
        const lang = lyricsResult.language || 'en'
        const pronunciationResult = await callQwen(qwenApiKey, qwenBaseUrl, [
          {
            role: 'system',
            content: `你是一个专业的语言学习助手。请为以下${lang === 'en' ? '英语' : lang === 'ja' ? '日语' : lang === 'ko' ? '韩语' : lang === 'fr' ? '法语' : '外语'}歌词生成中文注音。

规则：
1. 用常见汉字标注发音，选择声调最接近的汉字
2. 每个词对应一组汉字
3. 这是辅助工具，不求完全精确，只求快速上手
4. 目标：让中文母语者30秒内能近似发音跟着唱

返回JSON格式：
{
  "items": [
    {
      "index": 0,
      "pronunciation": "整行中文注音",
      "pronunciation_map": [{"word": "原文词", "zh": "中文注音"}]
    }
  ]
}`,
          },
          {
            role: 'user',
            content: JSON.stringify({
              language: lang,
              texts: items.map((item: any, i: number) => ({ index: i, content: item.content })),
            }),
          },
        ])

        if (pronunciationResult.items) {
          for (const pItem of pronunciationResult.items) {
            const idx = pItem.index ?? 0
            if (idx < items.length) {
              items[idx].pronunciation = pItem.pronunciation
              items[idx].pronunciation_map = pItem.pronunciation_map
            }
          }
        }
      }

      return json({
        ok: true,
        language: lyricsResult.language || 'en',
        title: lyricsResult.title || title,
        artist: lyricsResult.artist || artist,
        items,
        source: 'ai_lyrics_search',
      })
    }

    return json({ ok: false, error: 'unsupported_type', message: `不支持的 type: ${type}` }, 400)
  } catch (e: any) {
    console.error('ai-audio-recognize error:', e.message || e)
    return json({ ok: false, error: 'internal_error', message: e.message || String(e) }, 500)
  }
})
