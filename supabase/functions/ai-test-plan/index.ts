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
// 词汇释义映射表（用于生成中文释义选项）
// 注意：这是一个基础映射，生产环境应接入专业词典API
// ═══════════════════════════════════════════════════════════════

const WORD_MEANING_MAP: Record<string, string> = {
  // 常见词汇映射
  'one': '一；一个', 'two': '二；两个', 'three': '三；三个',
  'apple': '苹果', 'banana': '香蕉', 'cat': '猫', 'dog': '狗',
  'happy': '快乐的；高兴的', 'sad': '悲伤的；难过的',
  'run': '跑；奔跑', 'walk': '走；步行',
  'beautiful': '美丽的；漂亮的', 'good': '好的；良好的',
  'big': '大的；巨大的', 'small': '小的；小型的',
  'book': '书；书籍', 'school': '学校',
  'have': '有；拥有', 'like': '喜欢；喜爱',
  'is': '是（be动词）', 'are': '是（复数）', 'am': '是（第一人称）',
  'the': '这个；那个（定冠词）', 'a': '一个（不定冠词）', 'an': '一个（不定冠词）',
  'sun': '太阳；阳光', 'bright': '明亮的；鲜艳的',
  'fast': '快的；迅速地', 'slow': '慢的；缓慢地',
  'play': '玩；玩耍', 'game': '游戏；比赛',
  'day': '天；白天', 'today': '今天',
  'my': '我的', 'your': '你的；你们的',
  'this': '这个', 'that': '那个',
  'weather': '天气', 'nice': '好的；令人愉快的',
  'park': '公园', 'walk': '散步；走',
  'decide': '决定；下定决心', 'buy': '买；购买',
  'new': '新的', 'old': '旧的；老的',
  'computer': '电脑；计算机', 'because': '因为',
  'study': '学习；研究', 'english': '英语；英国的',
  'year': '年；年份', 'now': '现在',
  'would': '将；愿意（情态动词）', 'know': '知道；了解',
  'more': '更多的；更多', 'about': '关于；大约',
  'plan': '计划；规划', 'weekend': '周末',
  'movie': '电影', 'watch': '观看；注视',
  'last': '最后的；上一次的', 'night': '夜晚；晚上',
  'really': '真正地；确实', 'interesting': '有趣的；有意思的',
  'always': '总是；一直', 'forget': '忘记；遗忘',
  'bring': '带来；拿来', 'class': '班级；课程',
  'time': '时间；次', 'homework': '家庭作业',
  'need': '需要；必要', 'finish': '完成；结束',
  'project': '项目；工程', 'before': '在...之前',
  'deadline': '截止日期；最后期限', 'next': '下一个的',
  'week': '周；星期', 'ask': '询问；请求',
  'help': '帮助；协助', 'math': '数学',
  'restaurant': '餐厅；饭店', 'corner': '角落；拐角',
  'serve': '服务；端上', 'delicious': '美味的；可口的',
  'italian': '意大利的；意大利人', 'food': '食物；食品',
  'brother': '兄弟；哥哥或弟弟', 'plan': '计划；打算',
  'visit': '访问；拜访', 'grandparent': '祖父母；外公外婆或爷爷奶奶',
  'soon': '不久；很快',
}

/** 获取单词的中文释义（优先从 word_cache 读取） */
async function getWordMeaning(word: string, supabase?: any): Promise<string> {
  const lower = word.toLowerCase()

  // ① 如果有 supabase 实例，先查 word_cache
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
      // 缓存查询失败，降级到本地映射
      console.warn(`word_cache lookup failed for "${lower}":`, e)
    }
  }

  // ② 降级：使用本地映射表
  return WORD_MEANING_MAP[lower] ?? `「${word}」的释义`
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

/**
 * 听音辩义：播放音频 → 选择与原义类似的解释（单选）【优化版】
 * 修复：使用中文释义作为选项，而非其他英文单词
 */
function pickListenMeaningItems(sentences: string[], wordPool: string[], count: number): any[] {
  const items: any[] = []
  for (const w of shuffle(wordPool)) {
    if (items.length >= count) break

    // 【优化】正确答案使用该单词的中文释义
    const correctMeaning = getWordMeaning(w)

    // 【优化】干扰项使用其他单词的中文释义
    const distractorMeanings = getDistractorMeanings(w, wordPool, 3)
    if (distractorMeanings.length < 3) continue

    const options = shuffle([correctMeaning, ...distractorMeanings])
    items.push({
      id: crypto.randomUUID(),
      type: 'listen_meaning',
      prompt: 'Listen and select the word with similar meaning',
      prompt_cn: '听发音，选择与该词意思最接近的选项',
      options,
      answer: correctMeaning,  // 答案现在是中文释义
      answer_index: options.indexOf(correctMeaning),
      ref_text: w,  // 原始单词用于音频播放
      answer_word: w,  // 额外字段：记录原始单词
    })
  }
  return items
}

/**
 * 听音回复：播放一个问题 → 根据听到的内容选择回答（单选）【优化版】
 * 修复：答案选取策略更合理，优先选择句子的核心语义词
 */
function pickListenReplyItems(sentences: string[], wordPool: string[], count: number, params: DifficultyParams): any[] {
  const items: any[] = []
  const candidates = sentences
    .filter((s) => s.length <= params.maxSentenceLen)
    .map((s) => s.trim())
    .filter((s) => s.length > 10)

  // 常见疑问词和回答模式
  const questionPatterns = [
    { pattern: /^(what|where|when|why|how|who|which|can|could|would|do|does|did|is|are|am)/i, weight: 2 },
    { pattern: /\?$/i, weight: 3 },
  ]

  for (const s of shuffle(candidates)) {
    if (items.length >= count) break
    const words = tokenizeWords(s)
    if (words.length < 3) continue

    // 【优化】改进答案选取策略
    let keyWord: string

    // 检测是否是问句
    const isQuestion = questionPatterns.some((p) => p.pattern.test(s))

    if (isQuestion) {
      // 问句：取最后一个有意义的词作为可能的答案方向
      const meaningfulWords = words.filter((w) =>
        !['is', 'are', 'am', 'do', 'does', 'did', 'can', 'could', 'would', 'should', 'will', 'the', 'a', 'an', 'this', 'that', 'these', 'those', 'it', 'you', 'he', 'she', 'we', 'they', 'i', 'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his', 'our', 'their', 'what', 'where', 'when', 'why', 'how', 'who', 'which'].includes(w.toLowerCase())
      )
      keyWord = meaningfulWords.length > 0 ? meaningfulWords[meaningfulWords.length - 1] : words[words.length - 1]
    } else {
      // 陈述句：取句子的主语或关键词（通常是第一个或第二个名词性词）
      const nouns = words.filter((w) =>
        /^[A-Z]/.test(w) ||  // 首字母大写的可能是专有名词
        ['computer', 'school', 'park', 'movie', 'restaurant', 'project', 'book', 'day', 'time', 'year', 'home', 'work', 'life', 'world', 'people', 'man', 'woman', 'child', 'thing'].includes(w.toLowerCase())
      )
      keyWord = nouns.length > 0 ? nouns[0] : words[Math.min(2, words.length - 1)]
    }

    const keyWordLower = keyWord.toLowerCase()
    const distractors = shuffle(wordPool.filter((x) => x !== keyWordLower)).slice(0, 3)
    if (distractors.length < 3) continue

    // 【优化】使用中文释义作为选项，使题目更有意义
    const correctAnswer = getWordMeaning(keyWordLower)
    const distractorAnswers = distractors.map((d) => getWordMeaning(d))
    const options = shuffle([correctAnswer, ...distractorAnswers])

    items.push({
      id: crypto.randomUUID(),
      type: 'listen_reply',
      prompt: `Listen to the question and select the best answer: "${s}"`,
      prompt_cn: `听以下句子，选择最佳回答：「${s}」`,
      options,
      answer: correctAnswer,  // 答案现在是中文释义
      answer_index: options.indexOf(correctAnswer),
      ref_text: s,
      answer_word: keyWordLower,  // 记录原始关键词
    })
  }
  return items
}

/**
 * 释义选择：英→中 或 中→英（单选，2种子类型）【优化版】
 * 修复：cn_to_en 类型不再泄露答案，使用中文释义作为提示
 */
function pickDefinitionChoiceItems(sentences: string[], wordPool: string[], count: number): any[] {
  const items: any[] = []
  for (const w of shuffle(wordPool)) {
    if (items.length >= count) break

    const wordMeaning = getWordMeaning(w)
    const distractorMeanings = getDistractorMeanings(w, wordPool, 3)
    if (distractorMeanings.length < 3) continue

    const isEnglishToChinese = Math.random() > 0.5

    if (isEnglishToChinese) {
      // en_to_cn：给出英文单词，选择中文释义
      const options = shuffle([wordMeaning, ...distractorMeanings])
      items.push({
        id: crypto.randomUUID(),
        type: 'definition_choice',
        prompt: `What is the meaning of "${w}"?`,
        prompt_cn: `单词 "${w}" 的意思是什么？`,
        display_text: w,
        options,  // 选项是中文释义列表
        answer: wordMeaning,  // 答案是该单词的中文释义
        answer_index: options.indexOf(wordMeaning),
        sub_type: 'en_to_cn',
        answer_word: w,  // 记录原始单词
      })
    } else {
      // cn_to_en：【优化】给出中文释义，选择英文单词（不再泄露答案！）
      const englishOptions = shuffle(wordPool.filter((x) => x !== w).slice(0, 3))
      if (englishOptions.length < 3) continue
      const allEnglishOptions = shuffle([w, ...englishOptions])
      items.push({
        id: crypto.randomUUID(),
        type: 'definition_choice',
        prompt: `Which word matches the meaning: "${wordMeaning}"?`,
        // 【关键修复】不再在提示词中暴露英文答案！只显示中文释义
        prompt_cn: `哪个单词符合以下含义：「${wordMeaning}」？`,
        display_text: wordMeaning,  // 显示的是中文释义而非英文单词
        options: allEnglishOptions,  // 选项是英文单词
        answer: w,  // 答案是英文单词
        answer_index: allEnglishOptions.indexOf(w),
        sub_type: 'cn_to_en',
        answer_meaning: wordMeaning,  // 记录对应的中文释义
      })
    }
  }
  return items
}

/**
 * 英义互译：给出英文段落 → 选择与原文类似的中文解释（单选）【优化版】
 * 修复：使用模拟翻译作为选项，而非其他英文句子
 * 注意：生产环境应接入AI翻译API获取准确翻译
 */
function pickTranslateMeaningItems(sentences: string[], wordPool: string[], count: number, params: DifficultyParams): any[] {
  const items: any[] = []
  const candidates = sentences
    .filter((s) => s.length <= params.maxSentenceLen && s.length > 10)
    .map((s) => s.trim())

  /**
   * 简单的句子翻译模拟（基于关键词替换）
   * 生产环境应替换为真实的AI翻译API调用
   */
  function mockTranslate(sentence: string): string {
    const words = tokenizeWords(sentence)
    const translatedParts: string[] = []

    for (const w of words) {
      const meaning = getWordMeaning(w)
      // 如果找到释义且不是原词形式，使用释义
      if (meaning && !meaning.startsWith('「')) {
        translatedParts.push(meaning)
      } else {
        // 保留原词（可能是专有名词或未收录词）
        translatedParts.push(w)
      }
    }

    return translatedParts.join('') || sentence
  }

  for (const s of shuffle(candidates)) {
    if (items.length >= count) break
    const words = tokenizeWords(s)
    if (words.length < 3) continue

    // 【优化】生成主要翻译
    const mainTranslation = mockTranslate(s)

    // 【优化】生成干扰翻译（基于其他句子）
    const otherSentences = shuffle(sentences.filter((x) => x !== s && x.length <= params.maxSentenceLen)).slice(0, 3)
    if (otherSentences.length < 3) continue

    const distractorTranslations = otherSentences.map((sent) => mockTranslate(sent))
    const options = shuffle([mainTranslation, ...distractorTranslations])

    items.push({
      id: crypto.randomUUID(),
      type: 'translate_meaning',
      prompt: 'Read the sentence and select the option with the closest meaning',
      prompt_cn: '阅读以下英文句子，选择与原文含义最接近的中文选项',
      display_text: s,
      options,  // 选项现在是中文翻译
      answer: mainTranslation,  // 答案是中文翻译
      answer_index: options.indexOf(mainTranslation),
      original_sentence: s,  // 记录原始英文句子
    })
  }
  return items
}

/**
 * 词性测试：根据单词选择同义词/反义词等（多选）【优化版】
 * 改进：使用预定义的语义关系，而非完全随机选取
 * 注意：仍建议接入专业词典API以获得更准确的结果
 */

// 预定义的同义词/反义词/同类词关系（示例数据）
const WORD_RELATIONS: Record<string, { synonyms?: string[]; antonyms?: string[]; category?: string }> = {
  'happy': { synonyms: ['glad', 'joyful', 'cheerful'], antonyms: ['sad', 'unhappy'], category: 'emotion' },
  'sad': { synonyms: ['unhappy', 'sorrowful'], antonyms: ['happy', 'glad'], category: 'emotion' },
  'big': { synonyms: ['large', 'huge', 'great'], antonyms: ['small', 'tiny'], category: 'size' },
  'small': { synonyms: ['tiny', 'little'], antonyms: ['big', 'large', 'huge'], category: 'size' },
  'fast': { synonyms: ['quick', 'rapid', 'swift'], antonyms: ['slow'], category: 'speed' },
  'slow': { synonyms: ['sluggish'], antonyms: ['fast', 'quick', 'rapid'], category: 'speed' },
  'good': { synonyms: ['great', 'excellent', 'fine'], antonyms: ['bad', 'poor'], category: 'quality' },
  'beautiful': { synonyms: ['pretty', 'lovely', 'attractive'], antonyms: ['ugly'], category: 'appearance' },
  'new': { synonyms: ['fresh', 'modern'], antonyms: ['old', 'ancient'], category: 'time' },
  'old': { synonyms: ['ancient'], antonyms: ['new', 'fresh', 'modern'], category: 'time' },
  'run': { synonyms: ['jog', 'sprint'], antonyms: ['walk'], category: 'action' },
  'walk': { synonyms: ['stroll'], antonyms: ['run', 'jog'], category: 'action' },
  'buy': { synonyms: ['purchase'], antonyms: ['sell'], category: 'commerce' },
  'like': { synonyms: ['love', 'enjoy'], antonyms: ['hate', 'dislike'], category: 'emotion' },
  'book': { synonyms: [], antonyms: [], category: 'object' },
  'school': { synonyms: [], antonyms: [], category: 'place' },
  'cat': { synonyms: [], antonyms: ['dog'], category: 'animal' },
  'dog': { synonyms: [], antonyms: ['cat'], category: 'animal' },
  'apple': { synonyms: [], antonyms: [], category: 'fruit' },
  'banana': { synonyms: [], antonyms: [], category: 'fruit' },
  'one': { synonyms: [], antonyms: [], category: 'number' },
  'two': { synonyms: [], antonyms: [], category: 'number' },
  'three': { synonyms: [], antonyms: [], category: 'number' },
}

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
    const wLower = w.toLowerCase()
    const wordRelation = WORD_RELATIONS[wLower]

    let correctAnswers: string[] = []

    // 【优化】根据关系类型从预定义数据中获取答案
    if (wordRelation) {
      switch (relation.key) {
        case 'synonym':
          correctAnswers = wordRelation.synonyms ?? []
          break
        case 'antonym':
          correctAnswers = wordRelation.antonyms ?? []
          break
        case 'same_category':
          // 同类词：从词池中找相同category的词
          correctAnswers = wordPool
            .filter((x) => {
              const xr = WORD_RELATIONS[x.toLowerCase()]
              return xr?.category === wordRelation.category && x.toLowerCase() !== wLower
            })
            .slice(0, 2)
          break
      }
    }

    // 如果没有预定义的关系数据，降级为随机选取（但会标记为估算）
    if (correctAnswers.length === 0) {
      const others = shuffle(wordPool.filter((x) => x !== w))
      if (others.length < 3) continue
      // 随机取2个作为"可能"的正确答案
      correctAnswers = others.slice(0, 2)
    }

    // 过滤掉不在词池中的答案
    const validCorrectAnswers = correctAnswers.filter((a) => wordPool.includes(a) || wordPool.map((x) => x.toLowerCase()).includes(a.toLowerCase()))
    if (validCorrectAnswers.length === 0) {
      // 完全没有有效答案，跳过此题
      continue
    }

    // 生成干扰项（从词池中排除正确答案）
    const distractors = shuffle(wordPool.filter((x) =>
      x !== w && !validCorrectAnswers.map((a) => a.toLowerCase()).includes(x.toLowerCase())
    )).slice(0, 4)

    if (distractors.length + validCorrectAnswers.length < 4) continue  // 至少需要4个选项

    const options = shuffle([...validCorrectAnswers, ...distractors])
    const answerIndices = validCorrectAnswers.map((a) => options.indexOf(a))

    items.push({
      id: crypto.randomUUID(),
      type: 'word_relation',
      prompt: `${relation.prompt} "${w}"`,
      prompt_cn: `${relation.prompt_cn}：「${w}」`,
      display_text: w,
      relation_type: relation.key,
      options,
      answer_indices: answerIndices,
      answers: validCorrectAnswers,
      confidence: wordRelation ? 'high' : 'low',  // 标记置信度
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
