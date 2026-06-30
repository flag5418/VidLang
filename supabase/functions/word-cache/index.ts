// @ts-nocheck
/**
 * Word Cache Edge Function
 * 
 * 全局单词缓存管理：
 * 1. 批量预填充（从常用词表导入）
 * 2. 查询缓存状态（命中率、词量统计）
 * 3. 缓存预热（后台异步填充高频词）
 *
 * 路由：
 * - GET  /?action=stats          → 缓存统计
 * - POST /?action=prefill        → 批量预填充
 * - POST /?action=refresh        → V4: 刷新已有单词的 synonyms/antonyms/category 字段
 * - GET  /?action=get&word=xxx   → 查询单词缓存
 * - DELETE/?action=cleanup       → 清理过期缓存
 */

import { corsHeaders } from '../_shared/cors.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ─── 类型定义 ─────────────────────────────────

interface WordCacheRow {
  id: number
  word: string
  result: Record<string, any>
  query_count: number
  created_at: string
  updated_at: string
}

interface PrefillRequest {
  words: string[]           // 要预填充的单词列表
  batch_size?: number       // 每批处理数量（默认 50）
  skip_existing?: boolean   // 是否跳过已存在的（默认 true）
}

interface PrefillResult {
  success: boolean
  total: number
  processed: number
  skipped: number
  failed: number
  errors: Array<{ word: string; error: string }>
  duration_ms: number
}

// ─── 常用词表（用于预填充）─────────────────────

// 按难度分级的高频词汇表（覆盖 primary → gre）
const COMMON_WORDS_BY_DIFFICULTY: Record<string, string[]> = {
  // Primary (小学)
  primary: [
    'apple', 'banana', 'cat', 'dog', 'elephant', 'fish', 'girl', 'happy',
    'ice', 'juice', 'kite', 'lion', 'monkey', 'nose', 'orange', 'panda',
    'queen', 'rain', 'sun', 'tree', 'umbrella', 'violin', 'water', 'yellow',
    'zoo', 'book', 'pen', 'school', 'teacher', 'student', 'friend', 'family',
    'mother', 'father', 'sister', 'brother', 'one', 'two', 'three', 'four',
    'five', 'six', 'seven', 'eight', 'nine', 'ten', 'red', 'blue', 'green',
    'big', 'small', 'good', 'bad', 'hot', 'cold', 'new', 'old', 'run', 'walk',
    'eat', 'drink', 'sleep', 'play', 'read', 'write', 'sing', 'dance',
  ],
  
  // JuniorHigh (初中)
  juniorHigh: [
    'abandon', 'ability', 'absolutely', 'accept', 'achieve', 'across', 'activity',
    'actually', 'add', 'address', 'adventure', 'advice', 'afford', 'afraid',
    'after', 'again', 'against', 'age', 'agree', 'air', 'allow', 'almost',
    'alone', 'along', 'already', 'also', 'although', 'always', 'amazing',
    'american', 'among', 'ancient', 'angry', 'animal', 'another', 'answer',
    'anyone', 'anything', 'anywhere', 'appear', 'argue', 'around', 'arrive',
    'art', 'article', 'artist', 'asleep', 'attention', 'attitude', 'avoid',
    'awake', 'aware', 'away', 'awesome', 'awful', 'balance', 'beautiful',
    'because', 'become', 'bedroom', 'before', 'begin', 'behavior', 'believe',
    'beside', 'beyond', 'birthday', 'block', 'blood', 'body', 'bookshelf',
    'boring', 'born', 'borrow', 'both', 'bottom', 'brain', 'breakfast',
    'breath', 'bridge', 'bright', 'broken', 'brotherhood', 'building',
    'business', 'busy', 'calculate', 'camera', 'camping', 'cancel', 'capital',
    'captain', 'careful', 'careless', 'catch', 'celebrate', 'center', 'central',
    'certain', 'certainly', 'chance', 'change', 'character', 'cheap', 'check',
    'cheerful', 'chocolate', 'choose', 'cinema', 'circle', 'classical', 'clean',
    'clear', 'clever', 'climate', 'climb', 'close', 'clothes', 'cloudy', 'coach',
    'coast', 'collect', 'college', 'colorful', 'comfortable', 'common', 'communicate',
    'community', 'compare', 'competition', 'complete', 'computer', 'concern',
    'condition', 'confident', 'confirm', 'connect', 'consider', 'contain',
    'continue', 'control', 'conversation', 'correct', 'cost', 'courage', 'course',
    'cousin', 'cover', 'create', 'culture', 'curious', 'customer', 'dangerous',
    'decide', 'decision', 'degree', 'delicious', 'depend', 'describe', 'design',
    'develop', 'difference', 'different', 'difficult', 'direction', 'discover',
    'discuss', 'disease', 'distance', 'disturb', 'divide', 'document', 'double',
    'doubt', 'dream', 'dress', 'drink', 'drive', 'during', 'earthquake', 'education',
    'effect', 'effort', 'either', 'electric', 'electricity', 'email', 'emergency',
    'emotion', 'encourage', 'energy', 'engine', 'enjoy', 'enough', 'enter',
    'entertainment', 'environment', 'especially', 'European', 'even', 'evening',
    'event', 'ever', 'everybody', 'everyone', 'everything', 'everywhere', 'exactly',
    'excellent', 'except', 'exciting', 'exercise', 'experience', 'experiment',
    'explain', 'express', 'extra', 'extremely', 'factory', 'fairly', 'famous',
    'fantastic', 'farmer', 'fashion', 'favorite', 'february', 'festival', 'fewer',
    'field', 'fight', 'finally', 'finger', 'finish', 'fitness', 'flight', 'floor',
    'flower', 'follow', 'food', 'foolish', 'foreign', 'forest', 'forever', 'forget',
    'formal', 'forward', 'found', 'freedom', 'fresh', 'fridge', 'friendly',
    'frightened', 'front', 'fruit', 'full', 'funny', 'future', 'general', 'gentle',
    'geography', 'government', 'gradually', 'grammar', 'grandparent', 'grass',
    'great', 'ground', 'group', 'grow', 'guard', 'guess', 'guide', 'habit',
    'haircut', 'halfway', 'handwriting', 'happen', 'hardly', 'harmful', 'harvest',
    'headache', 'health', 'healthy', 'heart', 'heaven', 'height', 'helpful',
    'herself', 'history', 'hobby', 'holiday', 'honest', 'honour', 'hopeful',
    'horrible', 'hospital', 'host', 'hotel', 'housework', 'however', 'huge',
    'human', 'humorous', 'hunger', 'hungry', 'immediately', 'important',
    'impossible', 'include', 'increase', 'indeed', 'independent', 'influence',
    'information', 'initial', 'insect', 'inside', 'instead', 'instruction',
    'instrument', 'interest', 'international', 'internet', 'introduce', 'invention',
    'island', 'itself', 'journey', 'joyful', 'judge', 'juice', 'jump', 'keeper',
    'keyboard', 'kick', 'kill', 'kindness', 'kingdom', 'kitchen', 'knowledge',
    'laboratory', 'language', 'largely', 'latest', 'lately', 'laugh', 'lawyer',
    'leader', 'learned', 'leather', 'leave', 'length', 'lesson', 'library',
    'lifetime', 'lightning', 'likely', 'lion', 'list', 'listen', 'litter',
    'lively', 'locate', 'lonely', 'lovely', 'low', 'luckily', 'luggage',
    'lunch', 'machine', 'magazine', 'mainly', 'major', 'manage', 'manner',
    'market', 'match', 'material', 'matter', 'maximum', 'meaning', 'measure',
    'medical', 'medicine', 'medium', 'member', 'memory', 'mental', 'mention',
    'message', 'method', 'middle', 'might', 'million', 'mind', 'mineral',
    'minority', 'minute', 'miss', 'mistake', 'mobile', 'model', 'modern',
    'moment', 'Monday', 'money', 'monthly', 'moreover', 'mountain', 'movie',
    'museum', 'musical', 'myself', 'narrow', 'nation', 'national', 'native',
    'natural', 'nature', 'nearby', 'nearly', 'necessary', 'neighbor', 'neither',
    'nervous', 'network', 'never', 'newspaper', 'next', 'nice', 'nightmare',
    'noise', 'none', 'normal', 'northern', 'notebook', 'notice', 'nowadays',
    'number', 'object', 'obtain', 'obvious', 'occasion', 'occupy', 'offer',
    'office', 'official', 'often', 'Olympic', 'opening', 'operate', 'operation',
    'opinion', 'opposite', 'orange', 'ordinary', 'organize', 'original',
    'otherwise', 'outdoor', 'outstanding', 'overcome', 'oversleep', 'owner',
    'pack', 'painting', 'palace', 'parent', 'particular', 'partly', 'partner',
    'passenger', 'pattern', 'peaceful', 'penniless', 'perhaps', 'period',
    'permit', 'personal', 'physical', 'pilot', 'pioneer', 'pleasant', 'pleased',
    'plenty', 'pocket', 'poem', 'poet', 'point', 'police', 'polite', 'pollution',
    'popular', 'position', 'positive', 'possess', 'possible', 'postcard', 'postman',
    'potato', 'power', 'powerful', 'practice', 'prefer', 'prepare', 'present',
    'president', 'pretty', 'prevent', 'price', 'primary', 'prison', 'probably',
    'problem', 'process', 'produce', 'product', 'programme', 'progress',
    'project', 'promise', 'proper', 'properly', 'protect', 'proud', 'provide',
    'public', 'purpose', 'quality', 'quantity', 'quarter', 'question', 'quick',
    'quiet', 'quite', 'race', 'radio', 'railway', 'raise', 'rapid', 'rather',
    'reach', 'ready', 'realize', 'reason', 'receive', 'recent', 'recently',
    'recognize', 'record', 'recover', 'reduce', 'refer', 'reflect', 'refuse',
    'regular', 'relation', 'relative', 'remain', 'remember', 'remind', 'remove',
    'repair', 'repeat', 'replace', 'reply', 'report', 'represent', 'require',
    'research', 'resource', 'respect', 'responsible', 'restauran', 'result',
    'return', 'review', 'revolution', 'rice', 'rich', 'ride', 'right', 'risk',
    'role', 'roof', 'roommate', 'round', 'routine', 'rude', 'ruin', 'rule',
    'runner', 'safety', 'salad', 'salary', 'satisfy', 'Saturday', 'save',
    'scene', 'schedule', 'scholarship', 'science', 'scientific', 'score', 'screen',
    'seafood', 'season', 'seat', 'secondary', 'secret', 'secretary', 'seem',
    'seldom', 'separate', 'service', 'settle', 'several', 'shake', 'shall',
    'shame', 'shape', 'share', 'sharp', 'sheep', 'shelter', 'shine', 'shirt',
    'shock', 'shoot', 'shopping', 'shortcoming', 'shoulder', 'shower', 'sight',
    'sign', 'silent', 'similar', 'simple', 'simply', 'since', 'sincerely',
    'situation', 'skill', 'skin', 'sleepy', 'slightly', 'slow', 'small',
    'smart', 'smooth', 'soccer', 'social', 'society', 'software', 'soil',
    'soldier', 'solution', 'someone', 'something', 'sometime', 'sometimes',
    'somewhere', 'son', 'soon', 'sorry', 'sort', 'sound', 'soup', 'southern',
    'space', 'speak', 'special', 'speech', 'speed', 'spell', 'spirit',
    'splendid', 'spread', 'spring', 'square', 'stadium', 'stage', 'standard',
    'starvation', 'state', 'station', 'stay', 'steady', 'store', 'storm',
    'straight', 'strange', 'stream', 'street', 'strength', 'strict', 'strike',
    'strong', 'struggle', 'student', 'study', 'style', 'subject', 'succeed',
    'success', 'such', 'sudden', 'suffer', 'suggest', 'suitable', 'summary',
    'summer', 'sunlight', 'super', 'supper', 'supply', 'support', 'suppose',
    'surface', 'surprise', 'surround', 'survive', 'swallow', 'sweet', 'symbol',
    'system', 'tablecloth', 'tailor', 'taste', 'taxi', 'teaching', 'technology',
    'temperature', 'tennis', 'terrible', 'terrified', 'test', 'textbook', 'thankful',
    'themselves', 'therefore', 'thick', 'thief', 'think', 'thought', 'throat',
    'throughout', 'thus', 'Thursday', 'tide', 'tight', 'tire', 'title', 'toilet',
    'tomorrow', 'tonight', 'total', 'touch', 'towards', 'tourist', 'toward',
    'tower', 'tradition', 'traffic', 'train', 'translate', 'transport', 'travel',
    'treasure', 'treat', 'treatment', 'trouble', 'truly', 'trust', 'Tuesday',
    'turn', 'twelfth', 'twentieth', 'type', 'typical', 'ugly', 'uncle',
    'uncomfortable', 'underground', 'understand', 'uniform', 'university',
    'unknown', 'unless', 'unusual', 'upstairs', 'upward', 'urgent', 'usually',
    'valley', 'valuable', 'variety', 'various', 'vegetable', 'verb', 'version',
    'victory', 'view', 'village', 'violence', 'violent', 'visitor', 'voice',
    'volleyball', 'voyage', 'waiter', 'warmth', 'wash', 'waste', 'watch',
    'watermelon', 'weak', 'wealth', 'weather', 'website', 'wedding', 'weekday',
    'weight', 'welcome', 'western', 'whatever', 'whenever', 'wherever', 'whether',
    'while', 'whisper', 'white', 'whole', 'widespread', 'wildlife', 'willing',
    'windy', 'wisdom', 'within', 'without', 'wonder', 'wooden', 'worldwide',
    'worried', 'worth', 'wound', 'writer', 'wrong', 'yard', 'yesterday', 'youngster',
    'zero', 'zone',
  ],
  
  // SeniorHigh (高中)
  seniorHigh: [
    'phenomenon', 'controversial', 'entrepreneur', 'psychological', 'enthusiastic',
    'perspective', 'fundamental', 'substantial', 'distinctive', 'comprehensive',
    'sophisticated', 'beneficial', 'adequate', 'concept', 'establish', 'maintain',
    'significant', 'approach', 'factor', 'issue', 'occur', 'demonstrate', 'evaluate',
    'generate', 'implement', 'interpret', 'investigate', 'justify', 'modify',
    'negotiate', 'obtain', 'participate', 'promote', 'regulate', 'substitute',
    'transform', 'undergo', 'validate', 'accommodate', 'accumulate', 'acknowledge',
    'anticipate', 'appreciate', 'articulate', 'authenticate', 'collaborate',
    'compensate', 'consolidate', 'constitute', 'contemplate', 'coordinate',
    'cultivate', 'deteriorate', 'discriminate', 'dominate', 'elaborate', 'eliminate',
    'emphasize', 'encounter', 'enumerate', 'escalate', 'exaggerate', 'facilitate',
    'fluctuate', 'guarantee', 'hinder', 'hypothesize', 'illuminate', 'incorporate',
    'indicate', 'initiate', 'innovate', 'integrate', 'legitimate', 'manipulate',
    'mediate', 'minimize', 'monitor', 'negotiate', 'nominate', 'optimize',
    'paradox', 'perceive', 'persist', 'prioritize', 'propagate', 'reconcile',
    'reinforce', 'retrieve', 'simulate', 'stimulate', 'supplement', 'terminate',
    'tolerate', 'transform', 'undermine', 'validate', 'verify', 'visualize',
  ],
  
  // CET4 (大学四级)
  cet4: [
    'unprecedented', 'ubiquitous', 'meticulous', 'inevitable', 'deteriorate',
    'scrutinize', 'empirical', 'legitimate', 'viable', 'contemporary', 'conventional',
    'cumulative', 'deliberate', 'diverse', 'dynamic', 'efficient', 'equivalent',
    'explicit', 'feasible', 'genuine', 'homogeneous', 'identical', 'implicit',
    'inevitable', 'inherent', 'innovative', 'integral', 'judicious', 'legitimate',
    'meticulous', 'notorious', 'optimal', 'persistent', 'pragmatic', 'proficient',
    'provisional', 'radical', 'relevant', 'resilient', 'rigorous', 'simultaneous',
    'spontaneous', 'subsequent', 'substantial', 'succinct', 'tentative', 'transparent',
    'ubiquitous', 'unanimous', 'versatile', 'vulnerable',
  ],
  
  // CET6 (大学六级)
  cet6: [
    'exacerbate', 'impediment', 'ramifications', 'succinct', 'zealous', 'amenable',
    'clandestine', 'burgeoning', 'corroborate', 'disparate', 'ephemeral', 'laudable',
    'pragmatic', 'serendipity', 'ephemeral', 'ubiquitous', 'esoteric', 'obsequious',
    'perspicacious', 'quixotic', 'surreptitious', 'ambiguous', 'analogous', 'autonomous',
    'benevolent', 'capricious', 'conscientious', 'deleterious', 'effervescent', 'fallacious',
    'gregarious', 'heterogeneous', 'iconoclastic', 'juxtapose', 'lenient', 'mundane',
    'nonchalant', 'obstinate', 'perennial', 'quiescent', 'reticent', 'salubrious',
    'tenacious', 'ubiquitous', 'vicarious', 'xenophobic', 'zealous',
  ],
  
  // IELTS/TOEFEL/GRE 高级词汇
  ielts: [
    'ameliorate', 'bolster', 'cacophony', 'debacle', 'eclectic', 'fortuitous',
    'gregarious', 'hegemony', 'idiosyncratic', 'juxtaposition', 'kinetic',
    'laudatory', 'mercurial', 'nascent', 'obfuscate', 'panacea', 'querulous',
    'recalcitrant', 'surreptitious', 'taciturn', 'ubiquitous', 'vicissitude',
    'wanton', 'xenophobia', 'yeoman', 'zeitgeist',
  ],
  
  toefl: [
    'aberration', 'benevolent', 'cogent', 'didactic', 'ephemeral', 'fecund',
    'garrulous', 'hackneyed', 'iconoclast', 'juxtapose', 'kindred', 'litigious',
    'meritorious', 'nonplussed', 'obsequious', 'pedantic', 'quixotic', 'raucious',
    'sycophant', 'torpid', ' ubiquitous', 'vacillate', 'winsome', 'xenodochial',
    'yearn', 'zenith',
  ],
  
  gre: [
    'serendipity', 'ephemeral', 'ubiquitous', 'esoteric', 'obsequious',
    'perspicacious', 'quixotic', 'surreptitious', 'abrogate', 'bucolic',
    'capricious', 'denigrate', 'ebullient', 'fatuous', 'garrulous', 'hegemony',
    'iconoclast', 'jeremiad', 'knell', 'lugubrious', 'mendacious', 'nescient',
    'obfuscate', 'pellucid', 'quixotic', 'recalcitrant', 'sanguine', 'torpid',
    'unctuous', 'veracious', 'waggish', 'xenophobic', 'yokel', 'zany',
  ],
}

// ─── 辅助函数 ─────────────────────────────────

/**
 * 从 app_settings 获取 AI API 配置
 */
async function getAiConfig(supabase: any): Promise<{ apiKey: string; baseUrl: string }> {
  const { data: keyData } = await supabase
    .from('app_settings')
    .select('value')
    .eq('key', 'qwen_api_key')
    .single()
  
  const { data: urlData } = await supabase
    .from('app_settings')
    .select('value')
    .eq('key', 'qwen_base_url')
    .single()
  
  return {
    apiKey: keyData?.value || '',
    baseUrl: urlData?.value || 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  }
}

/**
 * 调用 definition() 函数获取单词释义
 */
async function fetchWordDefinition(
  apiKey: string,
  baseUrl: string,
  word: string,
): Promise<Record<string, any> | null> {
  try {
    // 动态导入 qwen-chat 模块
    const { definition } = await import('../ai-proxy/clients/qwen-chat.ts')
    return await definition(apiKey, baseUrl, word)
  } catch (e) {
    console.error(`Failed to fetch definition for "${word}":`, e)
    return null
  }
}

/**
 * 批量填充单词到 word_cache 表
 */
async function prefillWords(
  supabase: any,
  words: string[],
  apiKey: string,
  baseUrl: string,
  options?: { skipExisting?: boolean; batchSize?: number },
): Promise<PrefillResult> {
  const startTime = Date.now()
  const skipExisting = options?.skipExisting ?? true
  const batchSize = options?.batchSize ?? 50
  
  let processed = 0
  let skipped = 0
  let failed = 0
  const errors: Array<{ word: string; error: string }> = []
  
  // 分批处理
  for (let i = 0; i < words.length; i += batchSize) {
    const batch = words.slice(i, i + batchSize)
    
    for (const word of batch) {
      const normalizedWord = word.toLowerCase().trim()
      
      try {
        // 检查是否已存在
        if (skipExisting) {
          const { data: existing } = await supabase
            .from('word_cache')
            .select('word')
            .eq('word', normalizedWord)
            .limit(1)
          
          if (existing && existing.length > 0) {
            skipped++
            continue
          }
        }
        
        // 调用 AI 获取释义
        const result = await fetchWordDefinition(apiKey, baseUrl, normalizedWord)
        
        if (!result || !result.word) {
          failed++
          errors.push({ word: normalizedWord, error: 'AI returned empty result' })
          continue
        }
        
        // 写入缓存（V4：同时填充 synonyms/antonyms/category 独立列）
        const cacheData: any = {
          word: normalizedWord,
          result: result,
          query_count: 0,
        }

        // V4 扩展：从 AI 结果中提取字段到独立列（加速查询）
        if (result.synonyms && Array.isArray(result.synonyms)) {
          cacheData.synonyms = result.synonyms
        }
        if (result.antonyms && Array.isArray(result.antonyms)) {
          cacheData.antonyms = result.antonyms
        }
        if (result.category && typeof result.category === 'string') {
          cacheData.category = result.category
        }
        if (result.morphology) {
          if (result.morphology.adverb) {
            cacheData.morphology_adverb = result.morphology.adverb
          }
          if (result.morphology.noun) {
            cacheData.morphology_noun = result.morphology.noun
          }
        }

        const { error: upsertError } = await supabase
          .from('word_cache')
          .upsert(cacheData, { onConflict: 'word' })
        
        if (upsertError) {
          failed++
          errors.push({ word: normalizedWord, error: upsertError.message })
        } else {
          processed++
        }
      } catch (e: any) {
        failed++
        errors.push({ word: normalizedWord, error: e.message || String(e) })
      }
    }
    
    // 批次间稍作延迟，避免触发 API 限流
    if (i + batchSize < words.length) {
      await new Promise(resolve => setTimeout(resolve, 100))
    }
  }
  
  return {
    success: true,
    total: words.length,
    processed,
    skipped,
    failed,
    errors: errors.slice(0, 20), // 只保留前20个错误
    duration_ms: Date.now() - startTime,
  }
}

// ─── 主入口 ─────────────────────────────────

Deno.serve(async (req: Request) => {
  // CORS 预检
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const action = url.searchParams.get('action') || 'stats'
    
    // 初始化 Supabase 客户端（使用 service_role key，有完整权限）
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, serviceRoleKey)
    
    switch (action) {
      case 'stats':
        return await handleStats(supabase)

      case 'prefill':
        return await handlePrefill(req, supabase)

      case 'refresh':
        return await handleRefresh(req, supabase)

      case 'get':
        return await handleGet(url, supabase)

      case 'cleanup':
        return await handleCleanup(supabase, url)

      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400)
    }
  } catch (e: any) {
    console.error('word-cache error:', e)
    return jsonResponse({ error: e.message }, 500)
  }
})

// ─── 路由处理器 ─────────────────────────────────

/**
 * 获取缓存统计信息
 */
async function handleStats(supabase: any): Promise<Response> {
  // 总词量
  const { count: totalCount } = await supabase
    .from('word_cache')
    .select('*', { count: 'exact', head: true })
  
  // 总查询次数
  const { data: sumData } = await supabase
    .rpc('sum_word_cache_query_count')
    .select()
    .single()
    .catch(() => ({ sum: 0 }))
  
  // 今日新增
  const today = new Date().toISOString().split('T')[0]
  const { count: todayCount } = await supabase
    .from('word_cache')
    .select('*', { count: 'exact', head: true })
    .gte('created_at', today)
  
  // 热门 TOP 10（按查询次数排序）
  const { data: topWords } = await supabase
    .from('word_cache')
    .select('word, query_count')
    .order('query_count', { ascending: false })
    .limit(10)
  
  // 按难度分布（从 result JSON 中提取 difficulty 字段）
  const { data: difficultyDist } = await supabase
    .rpc('get_word_cache_difficulty_distribution')
    .select()
    .catch(() => [])
  
  return jsonResponse({
    success: true,
    stats: {
      total_words: totalCount || 0,
      total_queries: sumData?.sum || 0,
      today_new: todayCount || 0,
      top_words: topWords || [],
      difficulty_distribution: difficultyDist || [],
    },
  })
}

/**
 * 批量预填充
 */
async function handlePrefill(req: Request, supabase: any): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }
  
  const body = await req.json() as Partial<PrefillRequest>
  let words: string[] = body.words || []
  
  // 如果没有指定单词列表，使用内置的常用词表
  if (words.length === 0) {
    const difficulties = (body as any).difficulties || ['primary', 'juniorHigh']
    for (const diff of difficulties) {
      if (COMMON_WORDS_BY_DIFFICULTY[diff]) {
        words = words.concat(COMMON_WORDS_BY_DIFFICULTY[diff])
      }
    }
  }
  
  if (words.length === 0) {
    return jsonResponse({ error: 'No words to prefill' }, 400)
  }
  
  // 去重
  words = [...new Set(words.map(w => w.toLowerCase().trim()))].filter(w => w.length > 0)
  
  // 获取 AI 配置
  const aiConfig = await getAiConfig(supabase)
  if (!aiConfig.apiKey) {
    return jsonResponse({ error: 'AI API key not configured' }, 500)
  }
  
  // 开始预填充
  const result = await prefillWords(supabase, words, aiConfig.apiKey, aiConfig.baseUrl, {
    skipExisting: body.skip_existing ?? true,
    batch_size: body.batch_size ?? 50,
  })
  
  return jsonResponse(result)
}

/**
 * V4 刷新：为已有单词补充 synonyms/antonyms/category 字段
 *
 * 用法：POST /?action=refresh
 * Body: { "limit": 100, "dry_run": false }
 */
async function handleRefresh(req: Request, supabase: any): Promise<Response> {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  const body = await req.json().catch(() => ({}))
  const limit = Math.min(body.limit || 50, 500) // 单次最多处理 500 个
  const dryRun = body.dry_run ?? false

  // 获取 AI 配置
  const aiConfig = await getAiConfig(supabase)
  if (!aiConfig.apiKey) {
    return jsonResponse({ error: 'AI API key not configured' }, 500)
  }

  // 查询缺少 V4 字段的单词（synonyms 为空或 NULL）
  const { data: wordsToUpdate } = await supabase
    .from('word_cache')
    .select('word')
    .or('synonyms.is.null,synonyms.eq.{}')
    .order('query_count', { ascending: false })
    .limit(limit)

  if (!wordsToUpdate || wordsToUpdate.length === 0) {
    return jsonResponse({
      success: true,
      message: '所有单词已包含 V4 字段，无需刷新',
      updated_count: 0,
    })
  }

  let updated = 0
  let failed = 0
  const errors: Array<{ word: string; error: string }> = []

  for (const row of wordsToUpdate) {
    try {
      // 重新调用 AI 获取完整释义（包含新字段）
      const result = await fetchWordDefinition(aiConfig.apiKey, aiConfig.baseUrl, row.word)

      if (!result || !result.word) {
        failed++
        errors.push({ word: row.word, error: 'AI returned empty result' })
        continue
      }

      if (!dryRun) {
        // 更新记录，填充 V4 新字段
        const updateData: any = {
          result: result, // 更新整个 result JSON
          updated_at: new Date().toISOString(),
        }

        // 提取到独立列
        if (result.synonyms && Array.isArray(result.synonyms)) {
          updateData.synonyms = result.synonyms
        }
        if (result.antonyms && Array.isArray(result.antonyms)) {
          updateData.antonyms = result.antonyms
        }
        if (result.category && typeof result.category === 'string') {
          updateData.category = result.category
        }
        if (result.morphology) {
          if (result.morphology.adverb) updateData.morphology_adverb = result.morphology.adverb
          if (result.morphology.noun) updateData.morphology_noun = result.morphology.noun
        }

        const { error } = await supabase
          .from('word_cache')
          .update(updateData)
          .eq('word', row.word)

        if (error) {
          failed++
          errors.push({ word: row.word, error: error.message })
        } else {
          updated++
        }
      } else {
        // dry_run 模式：只统计不更新
        updated++
      }
    } catch (e: any) {
      failed++
      errors.push({ word: row.word, error: e.message || String(e) })
    }
  }

  return jsonResponse({
    success: true,
    mode: dryRun ? 'dry_run' : 'live',
    total_found: wordsToUpdate.length,
    updated_count: updated,
    failed_count: failed,
    errors: errors.slice(0, 20),
  })
}

/**
 * 查询单词缓存
 */
async function handleGet(url: URL, supabase: any): Promise<Response> {
  const word = url.searchParams.get('word')
  if (!word) {
    return jsonResponse({ error: 'Missing "word" parameter' }, 400)
  }
  
  const normalizedWord = word.toLowerCase().trim()
  const { data } = await supabase
    .from('word_cache')
    .select('*')
    .eq('word', normalizedWord)
    .limit(1)
  
  if (!data || data.length === 0) {
    return jsonResponse({ found: false, word: normalizedWord })
  }
  
  const row = data[0] as WordCacheRow
  
  // 异步递增查询次数
  supabase.rpc('bump_word_cache_count', { p_word: normalizedWord }).catch(() => {})
  
  return jsonResponse({
    found: true,
    word: row.word,
    result: row.result,
    query_count: row.query_count,
    updated_at: row.updated_at,
  })
}

/**
 * 清理过期缓存
 */
async function handleCleanup(supabase: any, url: URL): Promise<Response> {
  const daysParam = url.searchParams.get('days') || '180'
  const days = parseInt(daysParam, 10)
  
  if (isNaN(days) || days < 1) {
    return jsonResponse({ error: 'Invalid "days" parameter' }, 400)
  }
  
  const cutoffDate = new Date()
  cutoffDate.setDate(cutoffDate.getDate() - days)
  
  const { count } = await supabase
    .from('word_cache')
    .delete()
    .lt('updated_at', cutoffDate.toISOString())
    .select('*', { count: 'exact' })
  
  return jsonResponse({
    success: true,
    deleted_count: count || 0,
    cutoff_date: cutoffDate.toISOString(),
    retention_days: days,
  })
}

// ─── 工具函数 ─────────────────────────────────

function jsonResponse(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  })
}
