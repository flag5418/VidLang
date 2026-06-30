// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkIdempotent, deduct, getBalance, getPricingRule, getUserId } from '../ai-proxy/billing.ts'
// 导入带缓存的异步版本题型生成器
import {
  pickListenMeaningItemsWithCache,
  pickListenReplyItemsWithCache,
  pickDefinitionChoiceItemsWithCache,
  pickTranslateMeaningItemsWithCache,
} from './cache-helpers.ts'

// ═══════════════════════════════════════════════════════════════
// V4 新增：AI Agent 出题系统导入
// ═══════════════════════════════════════════════════════════════
import {
  queryAndAnalyzeWords,
  buildDispatchInputs,
  generateCacheStats,
} from './cache-helpers-v4.ts'
import { generateQuestions, DispatchInput, QuestionType, DifficultyLevel } from './agents/agent-dispatcher.ts'
import { validateItem as v4ValidateItem } from './quality-gate.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const subtitleBucket = 'subtitles'

function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

function unique<T>(arr: T[]): T[] {
  const seen = new Set<T>()
  const out: T[] = []
  for (const x of arr) {
    if (seen.has(x)) continue
    seen.add(x)
    out.push(x)
  }
  return out
}

function tokenizeWords(text: string): string[] {
  const tokens = text.match(/[A-Za-z]+(?:'[A-Za-z]+)?/g) ?? []
  return tokens.map((t) => t.trim()).filter((t) => t.length > 0)
}

function clampInt(v: any, min: number, max: number, fallback: number): number {
  const n = typeof v === 'number' ? v : parseInt(String(v ?? ''), 10)
  if (!Number.isFinite(n)) return fallback
  return Math.max(min, Math.min(max, n))
}

async function fetchSubtitlesFromStorage(
  userId: string,
  videoCode: string,
): Promise<{ title: string; subtitles: any[] } | null> {
  const supabase = createClient(supabaseUrl, supabaseServiceKey)
  const objectPath = `${userId}/${videoCode}.json`
  const { data, error } = await supabase.storage
    .from(subtitleBucket)
    .download(objectPath)
  if (error || !data) return null
  try {
    const raw = await data.text()
    const parsed = JSON.parse(raw)
    const items = Array.isArray(parsed?.items) ? (parsed.items as any[]) : []
    const title =
      typeof parsed?.title === 'string' && parsed.title.trim().length > 0
        ? parsed.title.trim()
        : 'Video'
    return { title, subtitles: items }
  } catch (_) {
    return null
  }
}

function buildSentenceCandidates(subtitles: any[]): string[] {
  const out: string[] = []
  for (const s of subtitles) {
    const t = typeof s?.content === 'string' ? s.content.trim() : ''
    if (t.length === 0) continue
    out.push(t)
  }
  return out
}

/** 根据难度调整句子和单词筛选参数 */
interface DifficultyParams {
  minWords: number   // 组句题最小单词数
  maxWords: number   // 组句题最大单词数
  minWordLen: number // 拼写/选择题最小单词长度
  maxWordLen: number // 拼写/选择题最大单词长度
  maxSentenceLen: number // 翻译/听写句子最大字符数
}

const DIFFICULTY_PARAMS: Record<string, DifficultyParams> = {
  beginner:     { minWords: 3,  maxWords: 7,  minWordLen: 3, maxWordLen: 5,  maxSentenceLen: 40  },
  elementary:   { minWords: 3,  maxWords: 10, minWordLen: 3, maxWordLen: 7,  maxSentenceLen: 60  },
  intermediate: { minWords: 3,  maxWords: 14, minWordLen: 3, maxWordLen: 14, maxSentenceLen: 100 },
  advanced:     { minWords: 5,  maxWords: 18, minWordLen: 4, maxWordLen: 14, maxSentenceLen: 150 },
  professional: { minWords: 6,  maxWords: 22, minWordLen: 5, maxWordLen: 16, maxSentenceLen: 200 },
}

function getDifficultyParams(difficulty: string): DifficultyParams {
  return DIFFICULTY_PARAMS[difficulty] ?? DIFFICULTY_PARAMS['intermediate']
}

function pickReorderItems(sentences: string[], count: number, params: DifficultyParams): any[] {
  const candidates = sentences
    .map((s) => ({ s, w: tokenizeWords(s) }))
    .filter((x) => x.w.length >= params.minWords && x.w.length <= params.maxWords)

  const picked = shuffle(candidates).slice(0, count)
  return picked.map((x) => {
    const correct = x.w
    const options = shuffle(correct)
    return {
      id: crypto.randomUUID(),
      type: 'reorder',
      prompt: '请按正确顺序组句',
      sentence: x.s,
      options,
      answer: correct,
    }
  })
}

function extractWordPool(sentences: string[], params: DifficultyParams): string[] {
  const words: string[] = []
  for (const s of sentences) {
    for (const w of tokenizeWords(s)) {
      const lw = w.toLowerCase()
      if (lw.length < params.minWordLen) continue
      if (lw.length > params.maxWordLen) continue
      words.push(lw)
    }
  }
  return unique(words)
}

function maskWord(sentence: string, word: string): { masked: string; ok: boolean } {
  const re = new RegExp(`\\b${word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i')
  if (!re.test(sentence)) return { masked: sentence, ok: false }
  const masked = sentence.replace(re, '_____')
  return { masked, ok: true }
}

function pickSpellingItems(sentences: string[], wordPool: string[], count: number): any[] {
  const items: any[] = []
  const shuffledWords = shuffle(wordPool)
  for (const w of shuffledWords) {
    if (items.length >= count) break
    const candidateSentences = shuffle(sentences).slice(0, 40)
    let chosen: string | null = null
    let masked = ''
    for (const s of candidateSentences) {
      const m = maskWord(s, w)
      if (m.ok) {
        chosen = s
        masked = m.masked
        break
      }
    }
    if (!chosen) continue

    const letters = w.toUpperCase().split('')
    const extra = Math.min(6, Math.max(2, 12 - letters.length))
    const pool: string[] = [...letters]
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    for (let i = 0; i < extra; i++) {
      pool.push(alphabet[Math.floor(Math.random() * alphabet.length)])
    }
    const letterPool = shuffle(pool)
    items.push({
      id: crypto.randomUUID(),
      type: 'spelling',
      prompt: '请根据句子拼写缺失单词',
      sentence: chosen,
      masked,
      answer: w,
      letter_pool: letterPool,
    })
  }
  return items
}

function pickMcqItems(sentences: string[], wordPool: string[], count: number): any[] {
  const items: any[] = []
  const pool = shuffle(wordPool)
  for (const w of pool) {
    if (items.length >= count) break
    const candidateSentences = shuffle(sentences).slice(0, 40)
    let chosen: string | null = null
    let masked = ''
    for (const s of candidateSentences) {
      const m = maskWord(s, w)
      if (m.ok) {
        chosen = s
        masked = m.masked
        break
      }
    }
    if (!chosen) continue

    const distractors = shuffle(wordPool.filter((x) => x !== w)).slice(0, 3)
    if (distractors.length < 3) continue
    const options = shuffle([w, ...distractors])
    const answerIndex = options.indexOf(w)
    items.push({
      id: crypto.randomUUID(),
      type: 'mcq',
      prompt: '请选择最合适的单词填空',
      sentence: chosen,
      masked,
      options,
      answer_index: answerIndex,
    })
  }
  return items
}

// ═══════════════════════════════════════════════════════════════
// V4 清理：已删除 WORD_MEANING_MAP（手动映射表）
// 原因：覆盖率低（仅70词），且容易导致答案泄露和错误释义
// 替代方案：使用 word_cache 表 + AI Agent 实时生成
// ═══════════════════════════════════════════════════════════════

/** 获取单词的中文释义（仅从 word_cache 读取） */
async function getWordMeaning(word: string, supabase?: any): Promise<string> {
  const lower = word.toLowerCase()

  // V4 清理：仅使用 word_cache 查询，不再依赖手动映射表
  if (supabase) {
    try {
      const { data } = await supabase
        .from('word_cache')
        .select('result')
        .eq('word', lower)
        .limit(1)

      if (data && data.length > 0) {
        const result = data[0].result
        // 从 definitions 数组中提取中文释义
        if (Array.isArray(result.definitions) && result.definitions.length > 0) {
          // 异步递增查询次数
          supabase.rpc('bump_word_cache_count', { p_word: lower }).catch(() => {})
          return result.definitions[0] as string
        }
      }
    } catch (e) {
      console.warn(`word_cache lookup failed for "${lower}":`, e)
    }
  }

  // V4：缓存未命中时返回空字符串（调用方需检查空值并跳过）
  return ''
}

/** 获取干扰释义（基于其他单词的释义，优先从缓存读取） */
async function getDistractorMeanings(targetWord: string, wordPool: string[], count: number, supabase?: any): Promise<string[]> {
  const others = shuffle(wordPool.filter((w) => w.toLowerCase() !== targetWord.toLowerCase()))
  const selected = others.slice(0, count)

  // 并行获取所有干扰词的释义
  const meanings = await Promise.all(selected.map((w) => getWordMeaning(w, supabase)))
  return meanings
}

// ─── 新题型生成函数（优化版） ───

/** 原音选择：播放音频 → 选择正确的单词（单选） */
function pickListenChooseItems(sentences: string[], wordPool: string[], count: number): any[] {
  const items: any[] = []
  for (const w of shuffle(wordPool)) {
    if (items.length >= count) break
    const distractors = shuffle(wordPool.filter((x) => x !== w)).slice(0, 3)
    if (distractors.length < 3) continue
    const options = shuffle([w, ...distractors])
    items.push({
      id: crypto.randomUUID(),
      type: 'listen_choose',
      prompt: 'Listen and select the word you hear',
      prompt_cn: '听发音，选择你听到的单词',
      options,
      answer: w,
      answer_index: options.indexOf(w),
      ref_text: w,
    })
  }
  return items
}

// ═══════════════════════════════════════════════════════════════
// V4 清理：已删除 pickListenMeaningItems（同步版）
// 原因：同步版本不支持 word_cache 查询，导致答案质量差
// 替代方案：使用 cache-helpers.ts 中的 pickListenMeaningItemsWithCache
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// V4 清理：已删除 pickListenReplyItems（同步版）
// 原因：同步版本不支持 word_cache 查询，导致答案质量差
// 替代方案：使用 cache-helpers.ts 中的 pickListenReplyItemsWithCache
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// V4 清理：已删除 pickDefinitionChoiceItems（同步版）
// 原因：同步版本不支持 word_cache 查询，导致答案质量差
// 替代方案：使用 cache-helpers.ts 中的 pickDefinitionChoiceItemsWithCache
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// V4 清理：已删除 pickTranslateMeaningItems + mockTranslate()
// 原因：mockTranslate() 是假翻译函数，逐词拼接导致语义不通顺
// 替代方案：使用 AI Agent (translation-agent) 调用真实翻译 API
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// V4 清理：已删除 WORD_RELATIONS（预定义关系表）
// 原因：覆盖率低（仅20词），且容易导致错误答案
// 替代方案：使用 AI Agent (relation-agent) 实时生成语义关系
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// V4 清理：pickWordRelationItems 已废弃（WORD_RELATIONS 已删除）
// 原因：依赖预定义关系表，覆盖率低（仅20词）
// 替代方案：Phase 3 将使用 AI Agent (relation-agent) 实时生成语义关系题
// 当前行为：返回空数组（不生成任何题目）
// ═══════════════════════════════════════════════════════════════
function pickWordRelationItems(_sentences: string[], _wordPool: string[], _count: number): any[] {
  console.warn('[deprecated] pickWordRelationItems called but WORD_RELATIONS has been removed in V4. Use AI Agent (relation-agent) instead.')
  return []
}

/** 跟读单词 */
function pickWordPronItems(wordPool: string[], count: number): any[] {
  const items: any[] = []
  for (const w of shuffle(wordPool)) {
    if (items.length >= count) break
    items.push({
      id: crypto.randomUUID(),
      type: 'word_pron',
      prompt: `Please read aloud: ${w}`,
      prompt_cn: `请跟读以下单词：${w}`,
      ref_text: w,
      answer: w,
    })
  }
  return items
}

/** 跟读短语：从句子中抽取2-4词短语 */
function pickPhrasePronItems(sentences: string[], count: number, params: DifficultyParams): any[] {
  const items: any[] = []
  for (const s of shuffle(sentences)) {
    if (items.length >= count) break
    const words = tokenizeWords(s)
    if (words.length < 3) continue
    // 提取中间一段短语（2-4词）
    const phraseLen = Math.min(4, Math.max(2, Math.floor(words.length / 2)))
    const startIdx = Math.floor(Math.random() * Math.max(1, words.length - phraseLen))
    const phrase = words.slice(startIdx, startIdx + phraseLen).join(' ')
    items.push({
      id: crypto.randomUUID(),
      type: 'phrase_pron',
      prompt: `Please read aloud: ${phrase}`,
      prompt_cn: `请跟读以下短语：${phrase}`,
      ref_text: phrase,
      answer: phrase,
    })
  }
  return items
}

/** 跟读句子 */
function pickSentencePronItems(sentences: string[], count: number, params: DifficultyParams): any[] {
  const items: any[] = []
  const candidates = sentences
    .filter((s) => s.length <= params.maxSentenceLen && tokenizeWords(s).length >= params.minWords)
    .map((s) => s.trim())

  for (const s of shuffle(candidates)) {
    if (items.length >= count) break
    items.push({
      id: crypto.randomUUID(),
      type: 'sentence_pron',
      prompt: `Please read aloud: ${s}`,
      prompt_cn: `请跟读以下句子：${s}`,
      ref_text: s,
      answer: s,
    })
  }
  return items
}

function normalizeWordBookSeeds(seedWords: any[]): Array<{
  word: string
  contextSentence: string
  wordBookCode: string
}> {
  const out: Array<{ word: string; contextSentence: string; wordBookCode: string }> = []
  const seen = new Set<string>()
  for (const item of seedWords) {
    const word = String(item?.word ?? '').trim().toLowerCase()
    const contextSentence = String(item?.context_sentence ?? item?.contextSentence ?? word).trim()
    const wordBookCode = String(item?.word_book_code ?? item?.wordBookCode ?? '').trim()
    const uniqueKey = wordBookCode || word
    if (!word || !uniqueKey || seen.has(uniqueKey)) continue
    seen.add(uniqueKey)
    out.push({ word, contextSentence: contextSentence || word, wordBookCode })
  }
  return out
}

function pickWordBookSpellingItems(
  seeds: Array<{ word: string; contextSentence: string; wordBookCode: string }>,
  count: number,
): any[] {
  const items: any[] = []
  for (const seed of shuffle(seeds)) {
    if (items.length >= count) break
    const maskedResult = maskWord(seed.contextSentence || seed.word, seed.word)
    if (!maskedResult.ok) continue
    const letters = seed.word.toUpperCase().split('')
    const extra = Math.min(6, Math.max(2, 12 - letters.length))
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    const pool: string[] = [...letters]
    for (let i = 0; i < extra; i++) {
      pool.push(alphabet[Math.floor(Math.random() * alphabet.length)])
    }
    items.push({
      id: crypto.randomUUID(),
      type: 'spelling',
      prompt: '请根据句子拼写缺失单词',
      sentence: seed.contextSentence,
      masked: maskedResult.masked,
      answer: seed.word,
      letter_pool: shuffle(pool),
      target_word: seed.word,
      word_book_code: seed.wordBookCode,
    })
  }
  return items
}

function pickWordBookMcqItems(
  seeds: Array<{ word: string; contextSentence: string; wordBookCode: string }>,
  count: number,
): any[] {
  const items: any[] = []
  const wordPool = unique(seeds.map((seed) => seed.word))
  for (const seed of shuffle(seeds)) {
    if (items.length >= count) break
    const maskedResult = maskWord(seed.contextSentence || seed.word, seed.word)
    if (!maskedResult.ok) continue
    const distractors = shuffle(wordPool.filter((word) => word !== seed.word)).slice(0, 3)
    if (distractors.length < 3) continue
    const options = shuffle([seed.word, ...distractors])
    items.push({
      id: crypto.randomUUID(),
      type: 'mcq',
      prompt: '请选择最合适的单词填空',
      sentence: seed.contextSentence,
      masked: maskedResult.masked,
      options,
      answer_index: options.indexOf(seed.word),
      target_word: seed.word,
      word_book_code: seed.wordBookCode,
    })
  }
  return items
}

// ═══════════════════════════════════════════════════════════════
//  v2.0 辅助函数：综合测试支持
// ═══════════════════════════════════════════════════════════════

/**
 * 获取文件夹下所有字幕文件列表（通过 subtitle-storage 的 list 操作）
 *
 * 用于综合测试模式：先列出文件夹下有哪些字幕文件，
 * 再逐个拉取内容合并出题。
 */
interface SubtitleFileInfo {
  video_code: string
  name: string
  size: number
  created_at: string
}

interface FolderSubtitleListResult {
  files: SubtitleFileInfo[]
  prefix: string
  count: number
}

async function fetchFolderSubtitleList(
  userId: string,
  folderCode: string,
): Promise<FolderSubtitleListResult | null> {
  try {
    const supabase = createClient(supabaseUrl, supabaseServiceKey)
    // 内部调用 subtitle-storage Edge Function 的 list 操作
    const { data, error } = await supabase.functions.invoke('subtitle-storage', {
      body: {
        op: 'list',
        folder_code: folderCode,
      },
    })

    if (error || !data) {
      console.warn(`fetchFolderSubtitleList failed for folder=${folderCode}:`, error)
      return null
    }

    const result = data as any
    if (!result.ok) {
      console.warn(`fetchFolderSubtitleList returned error for folder=${folderCode}:`, result.error)
      // 文件夹为空不算错误，返回空列表
      if (result.error === 'missing_folder_code') return null
      return { files: [], prefix: `${userId}/${folderCode}/`, count: 0 }
    }

    return {
      files: (result.files ?? []) as SubtitleFileInfo[],
      prefix: result.prefix ?? `${userId}/${folderCode}/`,
      count: result.count ?? 0,
    }
  } catch (e: any) {
    console.error('fetchFolderSubtitleList error:', e.message || e)
    return null
  }
}

/**
 * 为题目标注 source_video_code（资源归属）
 *
 * 根据题目的 ref_text / sentence / display_text 等字段，
 * 在 sentenceSourceMap 中查找对应的来源资源 code。
 * 如果找不到，回退到默认值。
 *
 * 注意：这是一个闭包，需要在外层定义 sentenceSourceMap 和 defaultSourceCode。
 * 实际使用时通过 bind 或工厂函数创建。
 */
function createTagSource(
  sourceMap: Map<string, string>,
  defaultSourceCode: string,
): (item: any) => any {
  return function tagSource(item: any): any {
    // 根据不同题型提取关键文本用于匹配来源
    const keys = ['sentence', 'ref_text', 'display_text', 'masked', 'prompt']
    let matchedSource: string | undefined

    for (const key of keys) {
      const text = item[key] as string | undefined
      if (text && typeof text === 'string' && text.length > 5) {
        // 在 sourceMap 中精确匹配
        const found = sourceMap.get(text.trim())
        if (found) {
          matchedSource = found
          break
        }
        // 模糊匹配：检查是否包含
        for (const [srcSentence, srcCode] of sourceMap.entries()) {
          if (text.includes(srcSentence) || srcSentence.includes(text)) {
            matchedSource = srcCode
            break
          }
        }
        if (matchedSource) break
      }
    }

    // 标注来源
    item.source_video_code = matchedSource ?? defaultSourceCode
    return item
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ ok: false, error: 'method_not_allowed' }, 405)

  const userId = await getUserId(req)
  if (!userId) return json({ ok: false, error: 'unauthorized' }, 401)

  let body: any = {}
  try {
    body = (await req.json()) as any
  } catch (_) {
    body = {}
  }

  const sourceType = String(body.source_type ?? 'resource').trim()
  const videoCode = String(body.video_code ?? '').trim()
  // v2.0: 综合测试使用 folder_code
  const folderCode = String(body.folder_code ?? '').trim()
  const seedWords = Array.isArray(body.seed_words) ? body.seed_words : []

  // 参数校验
  if (sourceType === 'word_book') {
    if (seedWords.length === 0) {
      return json({ ok: false, error: 'missing_seed_words' }, 400)
    }
  } else if (sourceType === 'folder') {
    if (!folderCode) {
      return json({ ok: false, error: 'missing_folder_code', message: 'folder 模式需要 folder_code' }, 400)
    }
  } else {
    // resource 模式（默认）
    if (!videoCode) {
      return json({ ok: false, error: 'missing_video_code' }, 400)
    }
  }

  const difficulty = String(body.difficulty ?? 'intermediate').trim()
  const diffParams = getDifficultyParams(difficulty)

  const config = (body.config ?? {}) as any
  // 旧版字段（向后兼容）
  const reorderCount = clampInt(config.reorder_count, 0, 20, 0)
  const spellingCount = clampInt(config.spelling_count, 0, 20, 0)
  const mcqCount = clampInt(config.mcq_count, 0, 20, 0)
  // 新版字段
  const listenChooseCount = clampInt(config.listen_choose_count, 0, 20, 0)
  const listenMeaningCount = clampInt(config.listen_meaning_count, 0, 20, 0)
  const listenReplyCount = clampInt(config.listen_reply_count, 0, 20, 0)
  const definitionChoiceCount = clampInt(config.definition_choice_count, 0, 20, 0)
  const translateMeaningCount = clampInt(config.translate_meaning_count, 0, 20, 0)
  const wordRelationCount = clampInt(config.word_relation_count, 0, 20, 0)
  const wordPronCount = clampInt(config.word_pron_count, 0, 20, 0)
  const phrasePronCount = clampInt(config.phrase_pron_count, 0, 20, 0)
  const sentencePronCount = clampInt(config.sentence_pron_count, 0, 20, 0)

  const requestId = String(body.request_id ?? crypto.randomUUID())
  const ruleCode = String(body.rule_code ?? 'ai_test_plan')

  const pricing = await getPricingRule(ruleCode)
  const balanceBefore = pricing ? await getBalance(userId) : null
  if (pricing && balanceBefore! < pricing.priceCny) {
    return json(
      {
        ok: false,
        error: 'insufficient_balance',
        required_cny: pricing.priceCny,
        balance_cny: balanceBefore,
      },
      402,
    )
  }

  let title = 'Video'
  let resourceCode = sourceType === 'folder' ? folderCode : (sourceType === 'word_book' ? 'word_book' : videoCode)
  let sentences: string[] = []
  let allItems: any[] = []

  // v2.0: 综合测试时，记录每个句子来自哪个资源（用于 source_video_code 归属）
  const sentenceSourceMap = new Map<string, string>() // sentence → source_video_code

  // v2.0: 创建题目标注器（为每道题附加 source_video_code）
  const tagSource = createTagSource(sentenceSourceMap, sourceType === 'folder' ? folderCode : videoCode)

  // ═══ 初始化 Supabase 客户端（用于 word_cache 查询）═══
  const cacheSupabase = createClient(supabaseUrl, supabaseServiceKey)

  if (sourceType === 'word_book') {
    title = '生词本测试'
    resourceCode = 'word_book'
    const seeds = normalizeWordBookSeeds(seedWords)
    if (seeds.length === 0) return json({ ok: false, error: 'no_content' }, 400)
    const wordPool = unique(seeds.map((s) => s.word))
    const seedSentences = seeds.map((s) => s.contextSentence).filter((s) => s && s.length > 5)

    // 生词本模式：复用新版题型生成器（传入 supabase 实例以支持缓存查询）
    if (listenChooseCount > 0) allItems.push(...pickListenChooseItems(seedSentences, wordPool, listenChooseCount))
    if (listenMeaningCount > 0) allItems.push(...await pickListenMeaningItemsWithCache(seedSentences, wordPool, listenMeaningCount, cacheSupabase))
    if (listenReplyCount > 0) allItems.push(...await pickListenReplyItemsWithCache(seedSentences, wordPool, listenReplyCount, diffParams, cacheSupabase))
    if (definitionChoiceCount > 0) allItems.push(...await pickDefinitionChoiceItemsWithCache(seedSentences, wordPool, definitionChoiceCount, cacheSupabase))
    if (spellingCount > 0) allItems.push(...pickWordBookSpellingItems(seeds, spellingCount))
    if (reorderCount > 0) allItems.push(...pickReorderItems(seedSentences, reorderCount, diffParams))
    if (translateMeaningCount > 0) allItems.push(...await pickTranslateMeaningItemsWithCache(seedSentences, wordPool, translateMeaningCount, diffParams, cacheSupabase))
    if (wordRelationCount > 0) allItems.push(...pickWordRelationItems(seedSentences, wordPool, wordRelationCount))
    if (wordPronCount > 0) allItems.push(...pickWordPronItems(wordPool, wordPronCount))
    if (phrasePronCount > 0) allItems.push(...pickPhrasePronItems(seedSentences, phrasePronCount, diffParams))
    if (sentencePronCount > 0) allItems.push(...pickSentencePronItems(seedSentences, sentencePronCount, diffParams))
    // 旧版兼容
    if (mcqCount > 0) allItems.push(...pickWordBookMcqItems(seeds, mcqCount))
  } else if (sourceType === 'folder') {
    // ════════════════════════════════════════════
    //  v2.0: 综合测试模式 — 按文件夹批量获取所有字幕
    // ════════════════════════════════════════════
    title = `${folderCode} 综合测试`

    // 调用 subtitle-storage list 获取文件夹下所有字幕文件列表
    const folderResult = await fetchFolderSubtitleList(userId, folderCode)
    if (!folderResult || folderResult.files.length === 0) {
      return json({ ok: false, error: 'no_content', message: '该文件夹下没有已上传的字幕内容，请先导入字幕并上传' }, 400)
    }

    // 合并所有资源的字幕：sentences + wordPool + sentenceSourceMap
    const allSentences: string[] = []
    const allWordPool: string[] = []
    const seenSentences = new Set<string>()

    for (const file of folderResult.files) {
      const srcVideoCode = file.video_code
      const storage = await fetchSubtitlesFromStorage(userId, srcVideoCode)
      if (!storage) continue

      const resourceSentences = buildSentenceCandidates(storage.subtitles)
      for (const s of resourceSentences) {
        // 去重（同一句话只保留一次）
        if (!seenSentences.has(s)) {
          seenSentences.add(s)
          allSentences.push(s)
          // 记录该句子来源资源
          sentenceSourceMap.set(s, srcVideoCode)
        }
      }

      // 合并词池
      const resourceWords = extractWordPool(resourceSentences, diffParams)
      for (const w of resourceWords) {
        allWordPool.push(w)
      }
    }

    sentences = allSentences
    if (sentences.length === 0) return json({ ok: false, error: 'no_content' }, 400)
    const wordPool = unique(allWordPool)

    // 出题（每道题附加 source_video_code）
    if (listenChooseCount > 0) allItems.push(...pickListenChooseItems(sentences, wordPool, listenChooseCount).map(tagSource))
    if (listenMeaningCount > 0) allItems.push(...(await pickListenMeaningItemsWithCache(sentences, wordPool, listenMeaningCount, cacheSupabase)).map(tagSource))
    if (listenReplyCount > 0) allItems.push(...(await pickListenReplyItemsWithCache(sentences, wordPool, listenReplyCount, diffParams, cacheSupabase)).map(tagSource))
    if (definitionChoiceCount > 0) allItems.push(...(await pickDefinitionChoiceItemsWithCache(sentences, wordPool, definitionChoiceCount, cacheSupabase)).map(tagSource))
    if (spellingCount > 0) allItems.push(...pickSpellingItems(sentences, wordPool, spellingCount).map(tagSource))
    if (reorderCount > 0) allItems.push(...pickReorderItems(sentences, reorderCount, diffParams).map(tagSource))
    if (translateMeaningCount > 0) allItems.push(...(await pickTranslateMeaningItemsWithCache(sentences, wordPool, translateMeaningCount, diffParams, cacheSupabase)).map(tagSource))
    if (wordRelationCount > 0) allItems.push(...pickWordRelationItems(sentences, wordPool, wordRelationCount).map(tagSource))
    if (wordPronCount > 0) allItems.push(...pickWordPronItems(wordPool, wordPronCount).map(tagSource))
    if (phrasePronCount > 0) allItems.push(...pickPhrasePronItems(sentences, phrasePronCount, diffParams).map(tagSource))
    if (sentencePronCount > 0) allItems.push(...pickSentencePronItems(sentences, sentencePronCount, diffParams).map(tagSource))
    if (mcqCount > 0) allItems.push(...pickMcqItems(sentences, wordPool, mcqCount).map(tagSource))
  } else {
    // ════════════════════════════════════════════
    //  单元测试模式（source_type = 'resource' 或旧版默认）
    // ════════════════════════════════════════════
    const storage = await fetchSubtitlesFromStorage(userId, videoCode)
    if (!storage) return json({ ok: false, error: 'no_content' }, 400)
    title = storage.title
    sentences = buildSentenceCandidates(storage.subtitles)
    if (sentences.length === 0) return json({ ok: false, error: 'no_content' }, 400)
    const wordPool = extractWordPool(sentences, diffParams)

    // 所有句子的来源都是当前 videoCode
    for (const s of sentences) {
      sentenceSourceMap.set(s, videoCode)
    }

    // 听
    if (listenChooseCount > 0) allItems.push(...pickListenChooseItems(sentences, wordPool, listenChooseCount).map(tagSource))
    if (listenMeaningCount > 0) allItems.push(...(await pickListenMeaningItemsWithCache(sentences, wordPool, listenMeaningCount, cacheSupabase)).map(tagSource))
    if (listenReplyCount > 0) allItems.push(...(await pickListenReplyItemsWithCache(sentences, wordPool, listenReplyCount, diffParams, cacheSupabase)).map(tagSource))
    // 读
    if (definitionChoiceCount > 0) allItems.push(...(await pickDefinitionChoiceItemsWithCache(sentences, wordPool, definitionChoiceCount, cacheSupabase)).map(tagSource))
    if (spellingCount > 0) allItems.push(...pickSpellingItems(sentences, wordPool, spellingCount).map(tagSource))
    if (reorderCount > 0) allItems.push(...pickReorderItems(sentences, reorderCount, diffParams).map(tagSource))
    if (translateMeaningCount > 0) allItems.push(...(await pickTranslateMeaningItemsWithCache(sentences, wordPool, translateMeaningCount, diffParams, cacheSupabase)).map(tagSource))
    if (wordRelationCount > 0) allItems.push(...pickWordRelationItems(sentences, wordPool, wordRelationCount).map(tagSource))
    // 说
    if (wordPronCount > 0) allItems.push(...pickWordPronItems(wordPool, wordPronCount).map(tagSource))
    if (phrasePronCount > 0) allItems.push(...pickPhrasePronItems(sentences, phrasePronCount, diffParams).map(tagSource))
    if (sentencePronCount > 0) allItems.push(...pickSentencePronItems(sentences, sentencePronCount, diffParams).map(tagSource))
    // 旧版兼容
    if (mcqCount > 0) allItems.push(...pickMcqItems(sentences, wordPool, mcqCount).map(tagSource))
  }

  // ═══ 全局质量门：过滤所有不合规的题目 ═══
  // （对应设计文档 06-test-system.md §4.2 质量门机制）
  const validatedItems = allItems.filter((item) => {
    const result = validateItem(item)
    if (!result.valid) {
      console.warn(`[quality_gate] 题目被过滤: type=${item.type} reason=${item.ref_text ?? item.display_text ?? item.sentence ?? 'N/A'}`)
    }
    return result.valid
  })

  if (validatedItems.length === 0) {
    console.warn('[quality_gate] 所有题目均未通过质量门检查，返回 no_items')
    return json({ ok: false, error: 'no_items', message: '所有生成的题目均未通过质量检查，请尝试更换测试素材或调整配置' }, 400)
  }

  const items = shuffle(validatedItems)
  console.log(`[quality_gate] 出题完成: 总生成 ${allItems.length} 题, 通过 ${validatedItems.length} 题, 过滤 ${allItems.length - validatedItems.length} 题`)

  let balanceAfter = balanceBefore
  let idempotent = false
  if (pricing && pricing.priceCny > 0) {
    idempotent = await checkIdempotent(requestId)
    if (!idempotent) {
      balanceAfter = await deduct(
        userId,
        ruleCode,
        'test',
        'generate_plan',
        requestId,
        pricing.priceCny,
        balanceBefore!,
        {
          action_key: 'ai_test_plan',
          action_label: 'AI 出题',
          resource_type: sourceType,
          resource_code: resourceCode,
          resource_title: title,
          source_page: 'test_page',
          action_name: 'generate_plan',
          is_chargeable: pricing.priceCny > 0,
          video_code: videoCode,
          title,
          config: {
            listen_choose_count: listenChooseCount,
            listen_meaning_count: listenMeaningCount,
            listen_reply_count: listenReplyCount,
            definition_choice_count: definitionChoiceCount,
            spelling_count: spellingCount,
            reorder_count: reorderCount,
            translate_meaning_count: translateMeaningCount,
            word_relation_count: wordRelationCount,
            word_pron_count: wordPronCount,
            phrase_pron_count: phrasePronCount,
            sentence_pron_count: sentencePronCount,
            mcq_count: mcqCount,
            difficulty,
          },
          item_count: items.length,
        },
      )
    }
  }

  return json({
    ok: true,
    request_id: requestId,
    user_id: userId,
    video_code: videoCode,
    title,
    billing: {
      rule_code: ruleCode,
      price_cny: pricing?.priceCny ?? 0,
      balance_before: balanceBefore,
      balance_after: balanceAfter,
      pricing_missing: !pricing,
      idempotent,
    },
    plan: { version: 1, items },
  })
})
