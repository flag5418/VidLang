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

// ─── 新题型生成函数 ───

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

/** 听音辩义：播放音频 → 选择与原义类似的解释（单选） */
function pickListenMeaningItems(sentences: string[], wordPool: string[], count: number): any[] {
  const items: any[] = []
  for (const w of shuffle(wordPool)) {
    if (items.length >= count) break
    // 使用同字幕中的其他词作为干扰"释义"
    const distractors = shuffle(wordPool.filter((x) => x !== w)).slice(0, 3)
    if (distractors.length < 3) continue
    const options = shuffle([w, ...distractors])
    items.push({
      id: crypto.randomUUID(),
      type: 'listen_meaning',
      prompt: 'Listen and select the word with similar meaning',
      prompt_cn: '听发音，选择与该词意思最接近的选项',
      options,
      answer: w,
      answer_index: options.indexOf(w),
      ref_text: w,
    })
  }
  return items
}

/** 听音回复：播放一个问题 → 根据听到的内容选择回答（单选） */
function pickListenReplyItems(sentences: string[], wordPool: string[], count: number, params: DifficultyParams): any[] {
  const items: any[] = []
  const candidates = sentences
    .filter((s) => s.length <= params.maxSentenceLen)
    .map((s) => s.trim())
    .filter((s) => s.length > 10)

  for (const s of shuffle(candidates)) {
    if (items.length >= count) break
    const words = tokenizeWords(s)
    if (words.length < 3) continue
    // 从句子中提取关键词作为答案
    const keyWord = words[Math.floor(words.length / 2)]
    const distractors = shuffle(wordPool.filter((x) => x !== keyWord.toLowerCase())).slice(0, 3)
    if (distractors.length < 3) continue
    const options = shuffle([keyWord.toLowerCase(), ...distractors])
    items.push({
      id: crypto.randomUUID(),
      type: 'listen_reply',
      prompt: `Listen to the question and select the best answer: "${s}"`,
      prompt_cn: `听以下句子，选择最佳回答：「${s}」`,
      options,
      answer: keyWord.toLowerCase(),
      answer_index: options.indexOf(keyWord.toLowerCase()),
      ref_text: s,
    })
  }
  return items
}

/** 释义选择：英→中 或 中→英（单选，2种子类型） */
function pickDefinitionChoiceItems(sentences: string[], wordPool: string[], count: number): any[] {
  const items: any[] = []
  for (const w of shuffle(wordPool)) {
    if (items.length >= count) break
    const distractors = shuffle(wordPool.filter((x) => x !== w)).slice(0, 3)
    if (distractors.length < 3) continue
    const isEnglishToChinese = Math.random() > 0.5
    const options = shuffle([w, ...distractors])
    if (isEnglishToChinese) {
      items.push({
        id: crypto.randomUUID(),
        type: 'definition_choice',
        prompt: `What is the meaning of "${w}"?`,
        prompt_cn: `单词 "${w}" 的意思是什么？`,
        display_text: w,
        options,
        answer: w,
        answer_index: options.indexOf(w),
        sub_type: 'en_to_cn',
      })
    } else {
      items.push({
        id: crypto.randomUUID(),
        type: 'definition_choice',
        prompt: `Which word matches the meaning?`,
        prompt_cn: `哪个单词符合给出的含义？（提示词：${w}）`,
        display_text: w,
        options,
        answer: w,
        answer_index: options.indexOf(w),
        sub_type: 'cn_to_en',
      })
    }
  }
  return items
}

/** 英义互译：给出英文段落 → 选择与原文类似的中文解释（单选） */
function pickTranslateMeaningItems(sentences: string[], wordPool: string[], count: number, params: DifficultyParams): any[] {
  const items: any[] = []
  const candidates = sentences
    .filter((s) => s.length <= params.maxSentenceLen && s.length > 10)
    .map((s) => s.trim())

  for (const s of shuffle(candidates)) {
    if (items.length >= count) break
    const words = tokenizeWords(s)
    if (words.length < 3) continue
    // 干扰项用其他句子
    const otherSentences = shuffle(sentences.filter((x) => x !== s && x.length <= params.maxSentenceLen)).slice(0, 3)
    if (otherSentences.length < 3) continue
    const options = shuffle([s, ...otherSentences])
    items.push({
      id: crypto.randomUUID(),
      type: 'translate_meaning',
      prompt: 'Read the sentence and select the option with the closest meaning',
      prompt_cn: '阅读以下英文句子，选择与原文含义最接近的选项',
      display_text: s,
      options,
      answer: s,
      answer_index: options.indexOf(s),
    })
  }
  return items
}

/** 词性测试：根据单词选择同义词/反义词等（多选） */
function pickWordRelationItems(sentences: string[], wordPool: string[], count: number): any[] {
  const items: any[] = []
  const relationTypes = [
    { key: 'synonym', prompt: 'Select synonyms of', prompt_cn: '选择以下单词的同义词（可多选）' },
    { key: 'antonym', prompt: 'Select antonyms of', prompt_cn: '选择以下单词的反义词（可多选）' },
    { key: 'same_category', prompt: 'Select words in the same category as', prompt_cn: '选择与以下单词同类的词（可多选）' },
  ]

  for (const w of shuffle(wordPool)) {
    if (items.length >= count) break
    const relation = relationTypes[items.length % relationTypes.length]
    // 多选：从 pool 中随机选2-3个作为正确答案候选 + 干扰项
    const others = shuffle(wordPool.filter((x) => x !== w))
    if (others.length < 5) continue
    // 正确答案：取前2个（简化逻辑，实际需要语义库）
    const correctAnswers = others.slice(0, 2)
    const distractors = others.slice(2, 6)
    const options = shuffle([...correctAnswers, ...distractors])
    const answerIndices = correctAnswers.map((a) => options.indexOf(a))

    items.push({
      id: crypto.randomUUID(),
      type: 'word_relation',
      prompt: `${relation.prompt} "${w}"`,
      prompt_cn: `${relation.prompt_cn}：「${w}」`,
      display_text: w,
      relation_type: relation.key,
      options,
      answer_indices: answerIndices,
      answers: correctAnswers,
    })
  }
  return items
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
  let resourceCode = videoCode
  let sentences: string[] = []
  let allItems: any[] = []

  if (sourceType === 'word_book') {
    title = '生词本测试'
    resourceCode = 'word_book'
    const seeds = normalizeWordBookSeeds(seedWords)
    if (seeds.length === 0) return json({ ok: false, error: 'no_content' }, 400)
    const wordPool = unique(seeds.map((s) => s.word))
    const seedSentences = seeds.map((s) => s.contextSentence).filter((s) => s && s.length > 5)

    // 生词本模式：复用新版题型生成器
    if (listenChooseCount > 0) allItems.push(...pickListenChooseItems(seedSentences, wordPool, listenChooseCount))
    if (listenMeaningCount > 0) allItems.push(...pickListenMeaningItems(seedSentences, wordPool, listenMeaningCount))
    if (listenReplyCount > 0) allItems.push(...pickListenReplyItems(seedSentences, wordPool, listenReplyCount, diffParams))
    if (definitionChoiceCount > 0) allItems.push(...pickDefinitionChoiceItems(seedSentences, wordPool, definitionChoiceCount))
    if (spellingCount > 0) allItems.push(...pickWordBookSpellingItems(seeds, spellingCount))
    if (reorderCount > 0) allItems.push(...pickReorderItems(seedSentences, reorderCount, diffParams))
    if (translateMeaningCount > 0) allItems.push(...pickTranslateMeaningItems(seedSentences, wordPool, translateMeaningCount, diffParams))
    if (wordRelationCount > 0) allItems.push(...pickWordRelationItems(seedSentences, wordPool, wordRelationCount))
    if (wordPronCount > 0) allItems.push(...pickWordPronItems(wordPool, wordPronCount))
    if (phrasePronCount > 0) allItems.push(...pickPhrasePronItems(seedSentences, phrasePronCount, diffParams))
    if (sentencePronCount > 0) allItems.push(...pickSentencePronItems(seedSentences, sentencePronCount, diffParams))
    // 旧版兼容
    if (mcqCount > 0) allItems.push(...pickWordBookMcqItems(seeds, mcqCount))
  } else {
    const storage = await fetchSubtitlesFromStorage(userId, videoCode)
    if (!storage) return json({ ok: false, error: 'no_content' }, 400)
    title = storage.title
    sentences = buildSentenceCandidates(storage.subtitles)
    if (sentences.length === 0) return json({ ok: false, error: 'no_content' }, 400)
    const wordPool = extractWordPool(sentences, diffParams)

    // 听
    if (listenChooseCount > 0) allItems.push(...pickListenChooseItems(sentences, wordPool, listenChooseCount))
    if (listenMeaningCount > 0) allItems.push(...pickListenMeaningItems(sentences, wordPool, listenMeaningCount))
    if (listenReplyCount > 0) allItems.push(...pickListenReplyItems(sentences, wordPool, listenReplyCount, diffParams))
    // 读
    if (definitionChoiceCount > 0) allItems.push(...pickDefinitionChoiceItems(sentences, wordPool, definitionChoiceCount))
    if (spellingCount > 0) allItems.push(...pickSpellingItems(sentences, wordPool, spellingCount))
    if (reorderCount > 0) allItems.push(...pickReorderItems(sentences, reorderCount, diffParams))
    if (translateMeaningCount > 0) allItems.push(...pickTranslateMeaningItems(sentences, wordPool, translateMeaningCount, diffParams))
    if (wordRelationCount > 0) allItems.push(...pickWordRelationItems(sentences, wordPool, wordRelationCount))
    // 说
    if (wordPronCount > 0) allItems.push(...pickWordPronItems(wordPool, wordPronCount))
    if (phrasePronCount > 0) allItems.push(...pickPhrasePronItems(sentences, phrasePronCount, diffParams))
    if (sentencePronCount > 0) allItems.push(...pickSentencePronItems(sentences, sentencePronCount, diffParams))
    // 旧版兼容
    if (mcqCount > 0) allItems.push(...pickMcqItems(sentences, wordPool, mcqCount))
  }

  const items = shuffle(allItems)
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
