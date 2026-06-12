// deno-lint-ignore-file no-explicit-any
/**
 * 通义千问 Chat API 客户端（翻译、释义、词联）
 */

export interface QwenChatParams {
  prompt: string
  model?: string
  temperature?: number
  maxTokens?: number
}

/** 调用 Qwen Chat Completion */
export async function qwenChat(
  apiKey: string,
  baseUrl: string,
  params: QwenChatParams,
): Promise<string> {
  const model = params.model || 'qwen-plus'
  const url = `${baseUrl}/chat/completions`

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'system',
          content: '你是一个专业的英语学习助手，请用中文回答。',
        },
        { role: 'user', content: params.prompt },
      ],
      temperature: params.temperature ?? 0.7,
      max_tokens: params.maxTokens ?? 1000,
    }),
  })

  if (!response.ok) {
    const errText = await response.text()
    throw new Error(`Qwen API error ${response.status}: ${errText}`)
  }

  const data = (await response.json()) as any
  const content = data?.choices?.[0]?.message?.content
  if (!content) throw new Error('Qwen API returned empty response')
  return content as string
}

/** AI 释义：查询单词释义、例句、音标 */
export async function definition(
  apiKey: string,
  baseUrl: string,
  word: string,
  sentence?: string,
): Promise<Record<string, any>> {
  let prompt = `请用中文详细解释英语单词"${word}"，要求返回 JSON 格式：\n{\n  "word": "单词",\n  "phonetic_uk": "英式音标",\n  "phonetic_us": "美式音标",\n  "part_of_speech": "词性",\n  "definitions": "中文释义（简要）",\n  "examples": [{"english": "英文例句", "chinese": "中文翻译"}]\n}`

  if (sentence) {
    prompt += `\n\n上下文句子：${sentence}`
  }

  const raw = await qwenChat(apiKey, baseUrl, {
    prompt,
    temperature: 0.3,
    maxTokens: 800,
  })

  // 尝试解析 JSON，失败则返回原始文本
  try {
    const jsonStr = raw.replace(/```json\n?|\n?```/g, '').trim()
    return JSON.parse(jsonStr)
  } catch {
    return { word, definitions: raw }
  }
}

/** AI 翻译：句子/段落翻译 */
export async function translateText(
  apiKey: string,
  baseUrl: string,
  text: string,
  targetLanguage = '中文',
): Promise<string> {
  const prompt = `请将以下英文翻译成${targetLanguage}，只返回译文，不要有任何解释：\n\n${text}`

  const raw = await qwenChat(apiKey, baseUrl, {
    prompt,
    temperature: 0.3,
    maxTokens: 2000,
  })

  return raw.trim()
}

/** AI 词联：联想相关词汇 */
export async function wordLink(
  apiKey: string,
  baseUrl: string,
  word: string,
  sentence?: string,
): Promise<Record<string, any>> {
  let prompt = `请对英语单词"${word}"进行词汇联想，返回 JSON 格式：\n{\n  "synonyms": ["近义词1", "近义词2"],\n  "antonyms": ["反义词1"],\n  "related": ["相关词1", "相关词2"],\n  "collocations": ["常用搭配1", "常用搭配2"]\n}`

  if (sentence) {
    prompt += `\n\n上下文句子：${sentence}`
  }

  const raw = await qwenChat(apiKey, baseUrl, {
    prompt,
    temperature: 0.5,
    maxTokens: 500,
  })

  try {
    const jsonStr = raw.replace(/```json\n?|\n?```/g, '').trim()
    return JSON.parse(jsonStr)
  } catch {
    return { word, raw_output: raw }
  }
}
