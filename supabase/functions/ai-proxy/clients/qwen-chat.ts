// deno-lint-ignore-file no-explicit-any
/**
 * 通义千问 Chat API 客户端（翻译、释义、词联）
 *
 * 所有翻译函数返回统一结构：
 *   { ok: true/false, error?: string, message?: string, data: Map }
 * 其中 data 为 Map 结构，前端可以直接转为业务 Model。
 */

// ─── 模型配置（全局统一维护）─────────────────────────────

/** 阿里云百炼模型配置表 — 英语学习 App 专用 */
export const QWEN_MODELS = {
  /** 文本大模型：对话/翻译/推理（唯一文本模型） */
  TURBO: 'qwen-turbo',
  /** 语音合成 TTS：CosyVoice-v3-Flash */
  TTS: 'CosyVoice-v3-Flash',
  /** 语音识别 ASR：fun-asr-realtime */
  ASR: 'fun-asr-realtime',
  /** 实时对话：多模态实时模型 */
  REALTIME: 'qwen3.5-omni-plus-realtime',
} as const

/** 默认文本对话模型 */
const DEFAULT_CHAT_MODEL = QWEN_MODELS.TURBO

export interface QwenChatParams {
  prompt: string
  model?: string
  temperature?: number
  maxTokens?: number
}

// ─── 统一返回类型 ──────────────────────────────

/** 统一的成功结果 */
export interface AiSuccessResult {
  ok: true
  data: Record<string, any>
}

/** 统一的失败结果 */
export interface AiErrorResult {
  ok: false
  error: string
  message: string
}

/** 统一结果 */
export type AiResult = AiSuccessResult | AiErrorResult

// ─── 各场景结果类型 ──────────────────────────────

/** 单词释义结果 */
export interface DefinitionResult {
  word: string
  phonetic_uk?: string
  phonetic_us?: string
  part_of_speech?: string
  definitions?: string[]
  difficulty?: string
  examples?: { english: string; chinese: string }[]
  standalone_examples?: { english: string; chinese: string }[]
  morphology?: Record<string, any>
  mnemonic?: string
}

/** 划词翻译结果（支持单词/短句/长句） */
export interface TranslationResult {
  /** 中文翻译 */
  translation: string
  /** 关键短语解释（仅短句/单词时返回） */
  phrase_explanations?: Array<{ phrase: string; meaning: string }>
  /** 词性（仅单词时返回） */
  part_of_speech?: string
  /** 词形变化（仅单词时返回） */
  word_forms?: Record<string, string>
}

/** 对话翻译结果 */
export interface ConversationTranslationResult {
  translation: string
}

/** 文章/字幕翻译结果 */
export interface ArticleTranslationResult {
  sentences: Array<{
    sentence_index: number
    paragraph_index: number
    en: string
    zh: string
  }>
  paragraphs?: Array<{
    paragraph_index: number
    zh: string
  }>
}

/** 评测判分结果 */
export interface JudgeResult {
  score: number
  is_correct: boolean
  feedback: string
}

/** 通用解析：尝试从 raw 中解析 JSON */
function parseJsonSafe(raw: string): Record<string, any> | null {
  try {
    const cleaned = raw.replace(/```json\s*/i, '').replace(/```\s*/, '').trim()
    return JSON.parse(cleaned) as Record<string, any>
  } catch {
    return null
  }
}

/** 调用 Qwen Chat Completion */
export async function qwenChat(
  apiKey: string,
  baseUrl: string,
  params: QwenChatParams,
): Promise<string> {
  const model = params.model || DEFAULT_CHAT_MODEL
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

/**
 * AI 释义：查询单词释义、例句、音标
 *
 * 返回 Map 结构：
 * {
 *   word, phonetic_uk, phonetic_us, part_of_speech,
 *   definitions, difficulty, examples, standalone_examples,
 *   context_sentence_info,  // 新增：当前句释义（含高亮）
 *   morphology, mnemonic
 * }
 */
export async function definition(
  apiKey: string,
  baseUrl: string,
  word: string,
  sentence?: string,
  model?: string,
): Promise<Record<string, any>> {
  // ── 难度参照表（few-shot，提高判断准确性）──
  const difficultyReference = `
难度判断必须严格参照以下标准：

【primary - 小学】 apple, cat, dog, happy, run, book, school, pen, one, two, good, big, small, I, a, the, is, are, have, can
【juniorHigh - 初中】 abandon, beautiful, decide, environment, necessary, important, different, difficult, interesting, popular, quickly, carefully
【seniorHigh - 高中】 phenomenon, controversial, entrepreneur, psychological, enthusiastic, perspective, fundamental, substantial, distinctive, comprehensive
【cet4 - 大学四级】 sophisticated, beneficial, adequate, concept, establish, maintain, significant, approach, factor, issue, occur
【cet6 - 大学六级】 unprecedented, ubiquitous, meticulous, inevitable, deteriorate, scrutinize, paradox, empirical, legitimate, viable
【postgraduate - 考研】 arbitrary, coherent, intrinsic, stringent, plausible, corroborate, elucidate, juxtapose, mitigate
【ielts - 雅思】 exacerbate, impediment, ramifications, succinct, zealous, amenable, clandestine, burgeoning
【toefl - 托福】 corroborate, disparate, ephemeral, laudable, meticulous, pragmatic, succinct, ubiquitous
【gre - GRE】 serendipity, ephemeral, ubiquitous, esoteric, obsequious, perspicacious, quixotic, surreptitious`

  let prompt = `请用中文详细解释英语单词"${word}"，要求返回严格的 JSON 格式（不要 markdown 代码块标记）：
{
  "word": "${word}",
  "phonetic_uk": "英式音标（IPA格式，如 /ˈæp.əl/）",
  "phonetic_us": "美式音标（IPA格式，如 /ˈæp.əl/）",
  "part_of_speech": "词性（名词/动词/形容词/副词/代词/冠词/介词/连词）",
  "definitions": ["核心中文释义1", "引申中文释义2"],
  "difficulty": "仅限以下值之一: primary / juniorHigh / seniorHigh / cet4 / cet6 / postgraduate / ielts / toefl / gre",
  "examples": [
    {"english": "例句1英文（必须包含原词${word}）", "chinese": "例句1中文翻译"},
    {"english": "例句2英文（必须包含原词${word}）", "chinese": "例句2中文翻译"},
    {"english": "例句3英文（必须包含原词${word}）", "chinese": "例句3中文翻译"}
  ],
  "standalone_examples": [
    {"english": "独立例句1英文（必须包含原词${word}）", "chinese": "独立例句1中文翻译"},
    {"english": "独立例句2英文（必须包含原词${word}）", "chinese": "独立例句2中文翻译"},
    {"english": "独立例句3英文（必须包含原词${word}）", "chinese": "独立例句3中文翻译"}
  ],
  "morphology": {
    "plural": "复数形式（名词必填）",
    "past_tense": "过去式（动词必填）",
    "past_participle": "过去分词（动词必填）",
    "present_participle": "现在分词（动词必填）",
    "third_person_singular": "第三人称单数（动词必填）",
    "comparative": "比较级（形容词/副词必填）",
    "superlative": "最高级（形容词/副词必填）",
    "is_irregular": true/false,
    "note": "不规则变化说明（如有）"
  },
  "mnemonic": "记忆法或词源解析（可选）"
}

重要规则：
1. examples 和 standalone_examples 必须各返回至少3条例句
2. 每条例句的 english 必须包含原词 ${word}（忽略大小写）
3. 例句要自然、地道、适合英语学习者理解
4. morphology 根据词性填写对应字段，无关字段设为 null
5. difficulty 值必须在上述9个枚举值中选择

${difficultyReference}`

  // ── 当前句释义（含高亮信息）──
  if (sentence) {
    prompt += `\n\n当前上下文句子：${sentence}

请在返回的 JSON 中额外包含以下字段（用于显示该单词在当前句中的释义和高亮）：
"context_sentence_info": {
  "original_sentence": "${sentence}",
  "word_highlighted_sentence": "将原句中的 ${word} 用【】包裹高亮，如 This is an 【unprecedented】 challenge.",
  "sentence_translation": "整句的中文翻译，其中 ${word} 的中文释义用【】包裹高亮",
  "word_meaning_in_context": "${word} 在此句中的具体含义（结合语境的精准翻译）"
}`
    // 因增加了 context_sentence_info，提高 maxTokens
  }

  const raw = await qwenChat(apiKey, baseUrl, {
    prompt,
    temperature: 0.3,
    maxTokens: sentence ? 1200 : 800, // 有上下文句子时增加 token 上限
    model: model || DEFAULT_CHAT_MODEL,
  })

  const parsed = parseJsonSafe(raw)
  if (parsed && typeof parsed.word === 'string') {
    return parsed
  }
  // 解析失败时返回降级结果
  return { word, definitions: [raw] }
}

/**
 * AI 翻译：句子/段落翻译
 *
 * 根据输入长度智能返回：
 * - 短句/单词（≤10词）：返回结构化翻译 + 短语解释 + 词性 + 词形变化
 * - 长句/段落：返回纯翻译文本
 *
 * 返回 Map 结构：
 * {
 *   translation: "中文翻译",
 *   phrase_explanations: [{ phrase, meaning }],  // 仅短句
 *   part_of_speech: "词性",                       // 仅单词
 *   word_forms: { ... }                           // 仅单词
 * }
 */
export async function translateText(
  apiKey: string,
  baseUrl: string,
  text: string,
  targetLanguage = '中文',
  model?: string,
): Promise<Record<string, any>> {
  const wordCount = text.split(/\s+/).length

  let prompt: string
  if (wordCount <= 10) {
    // 短句/单词：返回结构化翻译
    prompt = `请将以下英文翻译成${targetLanguage}，同时提供结构化信息。
返回严格的 JSON 格式（不要 markdown 代码块标记）：
{
  "translation": "完整的中文翻译",
  "phrase_explanations": [{"phrase": "关键短语", "meaning": "中文解释"}],
  "part_of_speech": "词性（如果是单词）",
  "word_forms": {"过去式": "形式", "复数": "形式"}
}

规则：
1. translation 始终存在
2. phrase_explanations 仅对短语/短句有效，单词可为空数组
3. part_of_speech 仅对单词有效，短语/长句可为空
4. word_forms 仅对单词有效，短语/长句可为空

待翻译内容：${text}`
  } else {
    // 长句/段落：只返回翻译
    prompt = `请将以下英文翻译成${targetLanguage}，只返回译文，不要有任何解释：\n\n${text}`
  }

  const raw = await qwenChat(apiKey, baseUrl, {
    prompt,
    temperature: 0.3,
    maxTokens: wordCount <= 10 ? 1000 : 2000,
    model: model || DEFAULT_CHAT_MODEL,
  })

  // 尝试解析为结构化 JSON
  const parsed = parseJsonSafe(raw)
  if (parsed && typeof parsed.translation === 'string') {
    return parsed
  }

  // 解析失败，降级为纯翻译
  return { translation: raw.trim() }
}

/**
 * AI 词联：联想相关词汇
 */
export async function wordLink(
  apiKey: string,
  baseUrl: string,
  word: string,
  sentence?: string,
  model?: string,
): Promise<Record<string, any>> {
  let prompt = `请对英语单词"${word}"进行词汇联想，返回严格的 JSON 格式（不要 markdown 代码块标记）：
{
  "synonyms": ["近义词1", "近义词2"],
  "antonyms": ["反义词1"],
  "related": ["相关词1", "相关词2"],
  "collocations": ["常用搭配1", "常用搭配2"]
}`

  if (sentence) {
    prompt += `\n\n上下文句子：${sentence}`
  }

  const raw = await qwenChat(apiKey, baseUrl, {
    prompt,
    temperature: 0.5,
    maxTokens: 500,
    model: model || DEFAULT_CHAT_MODEL,
  })

  const parsed = parseJsonSafe(raw)
  if (parsed && Array.isArray(parsed.synonyms)) {
    return parsed
  }
  return { word, raw_output: raw }
}

/**
 * AI 对话翻译：翻译对话中的英文回复为中文
 *
 * 返回 Map 结构：
 * { translation: "中文翻译" }
 */
export async function translateConversationResponse(
  apiKey: string,
  baseUrl: string,
  text: string,
  model?: string,
): Promise<Record<string, any>> {
  const prompt = `你是一个专业的英语翻译助手。请将以下英文翻译成中文，要求翻译自然流畅、口语化，适合英语学习者理解。
返回严格的 JSON 格式（不要 markdown 代码块标记）：
{
  "translation": "中文翻译"
}

待翻译内容：${text}`

  const raw = await qwenChat(apiKey, baseUrl, {
    prompt,
    temperature: 0.3,
    maxTokens: 2000,
    model: model || DEFAULT_CHAT_MODEL,
  })

  const parsed = parseJsonSafe(raw)
  if (parsed && typeof parsed.translation === 'string') {
    return parsed
  }

  return { translation: raw.trim() }
}

/**
 * 通用聊天：透传 prompt，返回原始文本
 * 用于评测判分、自定义 prompt 等场景
 *
 * 返回 Map 结构：
 * { raw: "AI 返回的原始文本" }
 */
export async function aiChat(
  apiKey: string,
  baseUrl: string,
  prompt: string,
  systemPrompt = '你是一个专业的英语学习助手，请用中文回答。',
  temperature = 0.3,
  maxTokens = 2000,
  model = DEFAULT_CHAT_MODEL,
): Promise<Record<string, any>> {
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
        { role: 'system', content: systemPrompt },
        { role: 'user', content: prompt },
      ],
      temperature,
      max_tokens: maxTokens,
    }),
  })

  if (!response.ok) {
    const errText = await response.text()
    throw new Error(`Qwen API error ${response.status}: ${errText}`)
  }

  const data = (await response.json()) as any
  const content = data?.choices?.[0]?.message?.content
  if (!content) throw new Error('Qwen API returned empty response')
  return { raw: content }
}
