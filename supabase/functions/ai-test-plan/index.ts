// @ts-nocheck
// deno-lint-ignore-file no-explicit-any
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { checkIdempotent, deduct, getBalance, getPricingRule, getUserId } from '../ai-proxy/billing.ts'

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
}

const DIFFICULTY_PARAMS: Record<string, DifficultyParams> = {
  beginner:     { minWords: 3,  maxWords: 7,  minWordLen: 3, maxWordLen: 5  },
  elementary:   { minWords: 3,  maxWords: 10, minWordLen: 3, maxWordLen: 7  },
  intermediate: { minWords: 3,  maxWords: 14, minWordLen: 3, maxWordLen: 14 },
  advanced:     { minWords: 5,  maxWords: 18, minWordLen: 4, maxWordLen: 14 },
  professional: { minWords: 6,  maxWords: 22, minWordLen: 5, maxWordLen: 16 },
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

Deno.serve(async (req: Request) => {
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

  const sourceType = String(body.source_type ?? 'video').trim()
  const videoCode = String(body.video_code ?? '').trim()
  const seedWords = Array.isArray(body.seed_words) ? body.seed_words : []
  if (sourceType !== 'word_book' && !videoCode) {
    return json({ ok: false, error: 'missing_video_code' }, 400)
  }
  if (sourceType === 'word_book' && seedWords.length === 0) {
    return json({ ok: false, error: 'missing_seed_words' }, 400)
  }

  const difficulty = String(body.difficulty ?? 'intermediate').trim()
  const diffParams = getDifficultyParams(difficulty)

  const config = (body.config ?? {}) as any
  const reorderCount = clampInt(config.reorder_count, 0, 20, 2)
  const spellingCount = clampInt(config.spelling_count, 0, 20, 2)
  const mcqCount = clampInt(config.mcq_count, 0, 20, 2)

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
  let resourceCode = videoCode
  let sentences: string[] = []
  let reorderItems: any[] = []
  let spellingItems: any[] = []
  let mcqItems: any[] = []

  if (sourceType === 'word_book') {
    title = '生词本测试'
    resourceCode = 'word_book'
    const seeds = normalizeWordBookSeeds(seedWords)
    if (seeds.length === 0) return json({ ok: false, error: 'no_content' }, 400)
    spellingItems = spellingCount > 0 ? pickWordBookSpellingItems(seeds, spellingCount) : []
    mcqItems = mcqCount > 0 ? pickWordBookMcqItems(seeds, mcqCount) : []
  } else {
    const storage = await fetchSubtitlesFromStorage(userId, videoCode)
    if (!storage) return json({ ok: false, error: 'no_content' }, 400)
    title = storage.title
    sentences = buildSentenceCandidates(storage.subtitles)
    if (sentences.length === 0) return json({ ok: false, error: 'no_content' }, 400)
    const wordPool = extractWordPool(sentences, diffParams)
    reorderItems = reorderCount > 0 ? pickReorderItems(sentences, reorderCount, diffParams) : []
    spellingItems = spellingCount > 0 ? pickSpellingItems(sentences, wordPool, spellingCount) : []
    mcqItems = mcqCount > 0 ? pickMcqItems(sentences, wordPool, mcqCount) : []
  }

  const items = shuffle([...reorderItems, ...spellingItems, ...mcqItems])
  if (items.length === 0) return json({ ok: false, error: 'no_items' }, 400)

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
          config: { reorder_count: reorderCount, spelling_count: spellingCount, mcq_count: mcqCount, difficulty },
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
