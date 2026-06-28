// @ts-nocheck
/**
 * ai-test-plan 缓存辅助函数
 * 
 * 提供支持 word_cache 的异步版本题型生成器。
 * 这些函数是原有同步版本的包装，增加了 supabase 参数以查询缓存。
 */

// ═══════════════════════════════════════════════════════════════
// 带缓存的异步版本题型生成器
// ═══════════════════════════════════════════════════════════════

/**
 * 听音辩义（带缓存）
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
    const distractorMeanings = await getDistractorMeanings(w, wordPool, 3, supabase)
    if (distractorMeanings.length < 3) continue

    const options = shuffle([correctMeaning, ...distractorMeanings])
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
 * 听音回复（带缓存）
 */
export async function pickListenReplyItemsWithCache(
  sentences: string[],
  wordPool: string[],
  count: number,
  params: any,
  supabase: any,
): Promise<any[]> {
  const items: any[] = []
  const candidates = shuffle(sentences)
    .filter((s) => s.length > 10)

  const questionPatterns = [
    { pattern: /^(what|where|when|why|how|who|which|can|could|would|do|does|did|is|are|am)/i, weight: 2 },
    { pattern: /\?$/i, weight: 3 },
  ]

  for (const s of candidates) {
    if (items.length >= count) break
    const words = tokenizeWords(s)
    if (words.length < 3) continue

    let keyWord: string
    const isQuestion = questionPatterns.some((p) => p.pattern.test(s))

    if (isQuestion) {
      const meaningfulWords = words.filter((w) =>
        !['is', 'are', 'am', 'do', 'does', 'did', 'can', 'could', 'would', 'should', 'will', 'the', 'a', 'an', 'this', 'that', 'these', 'those', 'it', 'you', 'he', 'she', 'we', 'they', 'i', 'me', 'him', 'her', 'us', 'them'].includes(w.toLowerCase())
      )
      keyWord = meaningfulWords.length > 0 ? meaningfulWords[meaningfulWords.length - 1] : words[words.length - 1]
    } else {
      const nouns = words.filter((w) =>
        /^[A-Z]/.test(w) ||
        ['computer', 'school', 'park', 'movie', 'restaurant', 'project', 'book', 'day', 'time', 'year', 'home', 'work', 'life', 'world', 'people', 'man', 'woman', 'child', 'thing'].includes(w.toLowerCase())
      )
      keyWord = nouns.length > 0 ? nouns[0] : words[Math.min(2, words.length - 1)]
    }

    const keyWordLower = keyWord.toLowerCase()
    const distractors = shuffle(wordPool.filter((x) => x !== keyWordLower)).slice(0, 3)
    if (distractors.length < 3) continue

    const correctAnswer = await getWordMeaning(keyWordLower, supabase)
    const distractorAnswers = await Promise.all(distractors.map((d) => getWordMeaning(d, supabase)))
    const options = shuffle([correctAnswer, ...distractorAnswers])

    items.push({
      id: crypto.randomUUID(),
      type: 'listen_reply',
      prompt: `Listen and choose the best response`,
      prompt_cn: `听以下句子，选择最佳回答：「${s}」`,
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
 * 释义选择（带缓存）
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
    const distractorMeanings = await getDistractorMeanings(w, wordPool, 3, supabase)
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
        prompt: `Which word matches the meaning: "${wordMeaning}"?`,
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
 * 英义互译（带缓存）
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

  function mockTranslate(sentence: string): string {
    const words = tokenizeWords(sentence)
    const translatedParts: string[] = []

    for (const w of words) {
      // 同步版本使用本地映射（避免在循环中多次 await）
      const meaning = WORD_MEANING_MAP[w.toLowerCase()] ?? w
      translatedParts.push(meaning.startsWith('「') ? w : meaning)
    }

    return translatedParts.join('') || sentence
  }

  for (const s of candidates) {
    if (items.length >= count) break
    const words = tokenizeWords(s)
    if (words.length < 3) continue

    const mainTranslation = mockTranslate(s)
    const otherSentences = shuffle(sentences.filter((x) => x !== s && x.length <= params.maxSentenceLen)).slice(0, 3)
    if (otherSentences.length < 3) continue

    const distractorTranslations = otherSentences.map((sent) => mockTranslate(sent))
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

// ═══════════════════════════════════════════════════════════════
// 工具函数（从主文件导入或重新定义）
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

  return WORD_MEANING_MAP[lower] ?? `「${word}」的释义`
}

async function getDistractorMeanings(targetWord: string, wordPool: string[], count: number, supabase?: any): Promise<string[]> {
  const others = shuffle(wordPool.filter((w) => w.toLowerCase() !== targetWord.toLowerCase()))
  const selected = others.slice(0, count)
  const meanings = await Promise.all(selected.map((w) => getWordMeaning(w, supabase)))
  return meanings
}
