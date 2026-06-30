// @ts-nocheck
/**
 * ai-test-plan 缓存辅助函数（v3 修复版）
 * 
 * 提供支持 word_cache 的异步版本题型生成器。
 * v3 修复：与 index.ts 同步修复所有 P0 问题。
 */

// ═══════════════════════════════════════════════════════════════
//  共用工具函数
// ═══════════════════════════════════════════════════════════════

function tokenizeWords(text: string): string[] {
  const tokens = text.match(/[A-Za-z]+(?:'[A-Za-z]+)?/g) ?? []
  return tokens.map((t) => t.trim()).filter((t) => t.length > 0)
}

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

/** 检查释义是否为 fallback 格式 */
function isFallbackMeaning(text: string): boolean {
  return text.includes('「') && text.includes('」')
}

/** 检查字符串中英文字符比例 */
function englishCharRatio(text: string): number {
  if (!text || text.length === 0) return 0
  const englishChars = (text.match(/[a-zA-Z]/g) || []).length
  return englishChars / text.length
}

/** 检测句子是否包含连续重复词 */
function hasRepeatedWords(sentence: string): boolean {
  const words = tokenizeWords(sentence)
  for (let i = 0; i < words.length - 1; i++) {
    if (words[i].toLowerCase() === words[i + 1].toLowerCase()) return true
  }
  return false
}

// 本地映射表（降级用）
const WORD_MEANING_MAP: Record<string, string> = {
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
  'decide': '决定；下定决心', 'buy': '买；购买',
  'new': '新的', 'old': '旧的；老的',
  'computer': '电脑；计算机', 'because': '因为',
  'study': '学习；研究', 'english': '英语；英国的',
  'year': '年；年份', 'now': '现在',
  'would': '将；愿意（情态动词）', 'know': '知道；了解',
  'more': '更多的；更多', 'about': '关于；大约',
  'plan': '计划；规划', 'weekend': '周末',
  'movie': '电影', 'watch': '观看；注视',
  'really': '真正地；确实', 'interesting': '有趣的；有意思的',
  'always': '总是；一直', 'forget': '忘记；遗忘',
  'bring': '带来；拿来', 'class': '班级；课程',
  'time': '时间；次', 'homework': '家庭作业',
  'need': '需要；必要', 'finish': '完成；结束',
  'project': '项目；工程', 'before': '在...之前',
  'week': '周；星期', 'ask': '询问；请求',
  'help': '帮助；协助', 'math': '数学',
  'restaurant': '餐厅；饭店', 'delicious': '美味的；可口的',
  'brother': '兄弟；哥哥或弟弟', 'visit': '访问；拜访',
  'soon': '不久；很快',
}

/**
 * 获取单词的中文释义（v3 修复版）
 * 【P0】未命中时返回空字符串，不再返回 fallback 格式
 */
async function getWordMeaning(word: string, supabase?: any): Promise<string> {
  const lower = word.toLowerCase()

  if (supabase) {
    try {
      const { data } = await supabase
        .from('word_cache')
        .select('result')
        .eq('word', lower)
        .limit(1)

      if (data && data.length > 0) {
        const result = data[0].result
        if (Array.isArray(result.definitions) && result.definitions.length > 0) {
          supabase.rpc('bump_word_cache_count', { p_word: lower }).catch(() => {})
          return result.definitions[0] as string
        }
      }
    } catch (e) {
      console.warn(`word_cache lookup failed for "${lower}":`, e)
    }
  }

  // 本地映射表
  if (WORD_MEANING_MAP[lower]) {
    return WORD_MEANING_MAP[lower]
  }

  // 未命中，返回空字符串
  return ''
}

async function getDistractorMeanings(targetWord: string, wordPool: string[], count: number, supabase?: any): Promise<string[]> {
  const others = shuffle(wordPool.filter((w) => w.toLowerCase() !== targetWord.toLowerCase()))
  const selected = others.slice(0, count)
  const meanings = await Promise.all(selected.map((w) => getWordMeaning(w, supabase)))
  // 过滤空值和 fallback 值
  return meanings.filter((m) => m && !isFallbackMeaning(m))
}

// ═══════════════════════════════════════════════════════════════
//  带缓存的异步版本题型生成器
// ═══════════════════════════════════════════════════════════════

/**
 * 听音辩义（带缓存）【v3 修复版】
 * P0: 空释义时跳过，过滤 fallback 干扰项
 */
export async function pickListenMeaningItemsWithCache(
  sentences: string[],
  wordPool: string[],
  count: number,
  supabase: any,
): Promise<any[]> {
  const items: any[] = []
  for (const w of shuffle(wordPool)) {
    if (items.length >= count) break

    const correctMeaning = await getWordMeaning(w, supabase)
    // P0: 无有效释义则跳过
    if (!correctMeaning) continue

    const distractorMeanings = await getDistractorMeanings(w, wordPool, 5, supabase)
    // P0: 过滤后不足3个则跳过
    if (distractorMeanings.length < 3) continue

    const options = shuffle([correctMeaning, ...distractorMeanings.slice(0, 3)])
    items.push({
      id: crypto.randomUUID(),
      type: 'listen_meaning',
      prompt: 'Listen and select the meaning',
      prompt_cn: '听发音，选择与该词意思最接近的选项',
      options,
      answer: correctMeaning,
      answer_index: options.indexOf(correctMeaning),
      ref_text: w,
      answer_word: w,
    })
  }
  return items
}

/**
 * 听音回复（带缓存）【v3 修复版】
 * P0: 只要疑问句、过滤重复词、空释义跳过
 */
export async function pickListenReplyItemsWithCache(
  sentences: string[],
  wordPool: string[],
  count: number,
  params: any,
  supabase: any,
): Promise<any[]> {
  const items: any[] = []

  const questionPatterns = [
    /^(what|where|when|why|how|who|which|can|could|would|do|does|did|is|are|am)/i,
    /\?$/i,
  ]

  // P0: 只保留疑问句 + 过滤重复词句子
  const candidates = shuffle(sentences)
    .filter((s) => s.length > 10 && s.length <= params.maxSentenceLen)
    .filter((s) => !hasRepeatedWords(s))
    .filter((s) => questionPatterns.some((p) => p.test(s)))

  for (const s of candidates) {
    if (items.length >= count) break
    const words = tokenizeWords(s)
    if (words.length < 3) continue

    const stopWords = new Set(['is','are','am','do','does','did','can','could','would','should','will','the','a','an','this','that','these','those','it','you','he','she','we','they','i','me','him','her','us','them','my','your','his','our','their','what','where','when','why','how','who','which'])
    const meaningfulWords = words.filter((w) => !stopWords.has(w.toLowerCase()))
    const keyWord = meaningfulWords.length > 0 ? meaningfulWords[meaningfulWords.length - 1] : words[words.length - 1]
    const keyWordLower = keyWord.toLowerCase()

    const distractors = shuffle(wordPool.filter((x) => x !== keyWordLower)).slice(0, 3)
    if (distractors.length < 3) continue

    // P0: 空释义跳过
    const correctAnswer = await getWordMeaning(keyWordLower, supabase)
    if (!correctAnswer) continue

    const distractorResults: string[] = []
    for (const d of distractors) {
      const dm = await getWordMeaning(d, supabase)
      if (dm) distractorResults.push(dm)
    }
    if (distractorResults.length < 3) continue

    const options = shuffle([correctAnswer, ...distractorResults])

    items.push({
      id: crypto.randomUUID(),
      type: 'listen_reply',
      prompt: `Listen and choose the best response`,
      prompt_cn: `听以下问题，选择最合适的回答：`,
      options,
      answer: correctAnswer,
      answer_index: options.indexOf(correctAnswer),
      ref_text: s,
      answer_word: keyWordLower,
    })
  }
  return items
}

/**
 * 释义选择（带缓存）【v3 修复版】
 * P0: 空释义跳过、cn_to_en prompt 不泄露答案
 */
export async function pickDefinitionChoiceItemsWithCache(
  sentences: string[],
  wordPool: string[],
  count: number,
  supabase: any,
): Promise<any[]> {
  const items: any[] = []
  for (const w of shuffle(wordPool)) {
    if (items.length >= count) break

    const wordMeaning = await getWordMeaning(w, supabase)
    // P0: 无有效释义则跳过
    if (!wordMeaning) continue

    const rawDistractors = await getDistractorMeanings(w, wordPool, 5, supabase)
    const distractorMeanings = rawDistractors.slice(0, 3)
    if (distractorMeanings.length < 3) continue

    const isEnglishToChinese = Math.random() > 0.5

    if (isEnglishToChinese) {
      const options = shuffle([wordMeaning, ...distractorMeanings])
      items.push({
        id: crypto.randomUUID(),
        type: 'definition_choice',
        prompt: `What does "${w}" mean?`,
        prompt_cn: `单词 "${w}" 的意思是什么？`,
        display_text: w,
        options,
        answer: wordMeaning,
        answer_index: options.indexOf(wordMeaning),
        sub_type: 'en_to_cn',
        answer_word: w,
      })
    } else {
      const englishOptions = shuffle(wordPool.filter((x) => x !== w).slice(0, 3))
      if (englishOptions.length < 3) continue
      const allEnglishOptions = shuffle([w, ...englishOptions])
      items.push({
        id: crypto.randomUUID(),
        type: 'definition_choice',
        prompt: `Which word matches the meaning?`,
        // prompt 中只显示中文释义
        prompt_cn: `哪个单词符合以下含义：「${wordMeaning}」？`,
        display_text: wordMeaning,
        options: allEnglishOptions,
        answer: w,
        answer_index: allEnglishOptions.indexOf(w),
        sub_type: 'cn_to_en',
        answer_meaning: wordMeaning,
      })
    }
  }
  return items
}

/**
 * 英义互译（带缓存）【v3 修复版】
 * P0: join 加空格、英文比例阈值、过滤重复词
 */
export async function pickTranslateMeaningItemsWithCache(
  sentences: string[],
  wordPool: string[],
  count: number,
  params: any,
  supabase: any,
): Promise<any[]> {
  const items: any[] = []
  const candidates = shuffle(sentences)
    .filter((s) => s.length >= params.minSentenceLen && s.length <= params.maxSentenceLen)
    .filter((s) => !hasRepeatedWords(s))  // P0: 过滤重复词

  /**
   * mockTranslate v3: join(' ') 替代 join('')，增加英文比例检测
   */
  function mockTranslate(sentence: string): string | null {
    const words = tokenizeWords(sentence)
    const translatedParts: string[] = []

    for (const w of words) {
      const meaning = WORD_MEANING_MAP[w.toLowerCase()]
      if (meaning) {
        translatedParts.push(meaning)
      } else {
        translatedParts.push(w)
      }
    }

    const result = translatedParts.join(' ') || sentence  // P0: 修复加空格

    // P0: 英文占比过高说明翻译失败
    if (englishCharRatio(result) > 0.4) return null
    return result
  }

  for (const s of candidates) {
    if (items.length >= count) break
    const words = tokenizeWords(s)
    if (words.length < 3) continue

    const mainTranslation = mockTranslate(s)
    if (!mainTranslation) continue  // P0: 翻译失败跳过

    const otherSentences = shuffle(sentences.filter((x) => x !== s && x.length <= params.maxSentenceLen)).slice(0, 3)
    if (otherSentences.length < 3) continue

    const distractorTranslations: string[] = []
    for (const sent of otherSentences) {
      const dt = mockTranslate(sent)
      if (dt) distractorTranslations.push(dt)
    }
    if (distractorTranslations.length < 3) continue

    const options = shuffle([mainTranslation, ...distractorTranslations])

    items.push({
      id: crypto.randomUUID(),
      type: 'translate_meaning',
      prompt: 'Read and select the closest meaning',
      prompt_cn: '阅读以下英文句子，选择与原文含义最接近的中文选项',
      display_text: s,
      options,
      answer: mainTranslation,
      answer_index: options.indexOf(mainTranslation),
      original_sentence: s,
    })
  }
  return items
}
