// deno-lint-ignore-file no-explicit-any
/**
 * V4 Cache Helpers (word_cache 数据提取 + Agent 输入构建)
 *
 * 职责：
 * 1. 从 word_cache 表批量查询单词数据
 * 2. 将原始数据转换为 Agent 需要的 WordCacheData 格式
 * 3. 智能分配题型（根据单词的可用数据）
 * 4. 构建 DispatchInput 数组
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  WordCacheData,
  DifficultyLevel,
  QuestionType,
  DispatchInput,
} from './schemas.ts'

// ─── 类型定义 ──────────────────────────────

/** 查询结果（从 DB 获取的原始行） */
interface WordCacheRow {
  word: string
  result: Record<string, any>
  synonyms?: string[]
  antonyms?: string[]
  category?: string
  morphology_adverb?: string
  morphology_noun?: string
  query_count: number
}

/** 单词分析结果 */
interface WordAnalysis {
  word: string
  cacheData: WordCacheData
  hasCache: boolean
  availableTypes: QuestionType[]   // 该单词可以生成的题型
  dataQuality: 'excellent' | 'good' | 'basic' | 'poor'
}

// ─── 数据转换 ──────────────────────────────

/**
 * 将数据库行转换为 WordCacheData 格式
 */
function rowToWordCacheData(row: WordCacheRow): WordCacheData {
  const result = row.result || {}

  // 提取 definitions
  const definitions = Array.isArray(result.definitions)
    ? result.definitions
    : typeof result.definitions === 'string'
      ? [{ part_of_speech: 'unknown', chinese_meaning: result.definitions }]
      : []

  // 提取 morphology
  let morphology = result.morphology || {}
  // 如果独立列有数据，合并到 morphology
  if (row.morphology_adverb) {
    morphology = { ...morphology, adverb: row.morphology_adverb }
  }
  if (row.morphology_noun) {
    morphology = { ...morphology, noun: row.morphology_noun }
  }

  return {
    word: row.word,
    definitions,
    difficulty: result.difficulty,
    morphology,
    synonyms: row.synonyms || result.synonyms || [],
    antonyms: row.antonyms || result.antonyms || [],
    category: row.category || result.category,
    phonetic_uk: result.phonetic_uk,
    phonetic_us: result.phonetic_us,
    standalone_examples: result.standalone_examples,
  }
}

// ─── 数据质量评估 ──────────────────────────

/**
 * 评估单词数据的完整度
 */
function assessDataQuality(cacheData: WordCacheData): WordAnalysis['dataQuality'] {
  let score = 0

  // 有定义 (+30)
  if (cacheData.definitions.length > 0 && cacheData.definitions[0].chinese_meaning) score += 30

  // 有词形变化 (+20)
  if (cacheData.morphology && Object.keys(cacheData.morphology).length >= 3) score += 20

  // 有同义词 (+20)
  if (cacheData.synonyms && cacheData.synonyms.length >= 2) score += 20

  // 有反义词 (+10)
  if (cacheData.antonyms && cacheData.antonyms.length >= 1) score += 10

  // 有音标 (+10)
  if (cacheData.phonetic_uk || cacheData.phonetic_us) score += 10

  // 有例句 (+10)
  if (cacheData.standalone_examples && cacheData.standalone_examples.length >= 2) score += 10

  if (score >= 80) return 'excellent'
  if (score >= 60) return 'good'
  if (score >= 30) return 'basic'
  return 'poor'
}

/**
 * 根据数据质量确定可用的题型
 */
function determineAvailableTypes(cacheData: WordCacheData): QuestionType[] {
  const types: QuestionType[] = []
  const quality = assessDataQuality(cacheData)

  // 所有有基本定义的词都可以出释义题
  if (cacheData.definitions.length > 0) {
    types.push('meaning_choice')
  }

  // 有足够词形变化数据 → 词形题
  if (cacheData.morphology) {
    const formCount = Object.values(cacheData.morphology).filter(v => v !== null && v !== undefined).length
    if (formCount >= 3) {
      types.push('word_forms')
    }
  }

  // 有同义词/反义词 → 英文释义题（中高级）
  if ((cacheData.synonyms?.length >= 2 || cacheData.antonyms?.length >= 1)) {
    types.push('english_definition')
  }

  // 有基本定义 → 语境选择题（最常用）
  if (cacheData.definitions.length > 0 && quality !== 'poor') {
    types.push('context_mcq')
  }

  return types
}

// ─── 主查询函数 ─────────────────────────────

/**
 * 批量查询 word_cache 并返回分析结果
 *
 * @param supabase - Supabase 客户端
 * @param words - 要查询的单词数组
 * @returns 分析结果数组
 */
export async function queryAndAnalyzeWords(
  supabase: any,
  words: string[],
): Promise<WordAnalysis[]> {
  // 去重并规范化
  const uniqueWords = [...new Set(words.map(w => w.toLowerCase().trim()))].filter(w => w.length > 0)

  if (uniqueWords.length === 0) {
    return []
  }

  // 批量查询（Supabase 支持 in 查询）
  const { data, error } = await supabase
    .from('word_cache')
    .select('*')
    .in('word', uniqueWords)

  if (error) {
    console.error('[Cache Helpers] Query error:', error)
    throw error
  }

  // 建立 word → row 的映射
  const cacheMap = new Map<string, WordCacheRow>()
  for (const row of (data || [])) {
    cacheMap.set(row.word.toLowerCase(), row as WordCacheRow)
  }

  // 转换为分析结果
  const analyses: WordAnalysis[] = []

  for (const word of uniqueWords) {
    const row = cacheMap.get(word)

    if (row) {
      const cacheData = rowToWordCacheData(row)
      const analysis: WordAnalysis = {
        word,
        cacheData,
        hasCache: true,
        availableTypes: determineAvailableTypes(cacheData),
        dataQuality: assessDataQuality(cacheData),
      }
      analyses.push(analysis)
    } else {
      // 未命中缓存
      analyses.push({
        word,
        cacheData: { word, definitions: [] },
        hasCache: false,
        availableTypes: [], // 无缓存则无法生成语义型题目
        dataQuality: 'poor',
      })
    }
  }

  return analyses
}

// ─── Agent 输入构建 ─────────────────────────

/** 出题配置 */
export interface QuestionGenerationConfig {
  difficulty: DifficultyLevel
  typeWeights?: Partial<Record<QuestionType, number>>  // 各题型权重
  maxQuestionsPerWord?: number                          // 每个词最多出几道题
  preferHighQuality?: boolean                            // 是否优先选择高质量数据
}

/** 默认权重配置 */
const DEFAULT_TYPE_WEIGHTS: Record<QuestionType, number> = {
  context_mcq: 40,          // 最常用
  meaning_choice: 30,        // 常用
  english_definition: 15,    // 中等（适合中高级）
  word_forms: 15,            // 中等（需要足够的词形数据）
}

/**
 * 根据分析结果构建 Agent 输入数组
 *
 * @param analyses - 单词分析结果
 * @param config - 出题配置
 * @param sentences - 可选的句子映射（word → sentence）
 * @returns DispatchInput 数组
 */
export function buildDispatchInputs(
  analyses: WordAnalysis[],
  config: QuestionGenerationConfig,
  sentences?: Record<string, string>,
): DispatchInput[] {
  const inputs: DispatchInput[] = []
  const weights = { ...DEFAULT_TYPE_WEIGHTS, ...config.typeWeights }

  for (const analysis of analyses) {
    // 跳过无缓存的单词
    if (!analysis.hasCache || analysis.availableTypes.length === 0) {
      continue
    }

    // 根据权重决定为该词分配哪些题型
    const selectedTypes = selectTypesByWeight(
      analysis.availableTypes,
      weights,
      config.maxQuestionsPerWord || 1,
      config.preferHighQuality ?? true,
      analysis.dataQuality,
    )

    for (const type of selectedTypes) {
      const input: DispatchInput = {
        word: analysis.word,
        cacheData: analysis.cacheData,
        questionType: type,
        difficulty: config.difficulty,
      }

      // 为 context_mcq 添加句子
      if (type === 'context_mcq' && sentences?.[analysis.word]) {
        input.sentence = sentences[analysis.word]
      }

      inputs.push(input)
    }
  }

  return inputs
}

/**
 * 根据权重选择题型
 */
function selectTypesByWeight(
  availableTypes: QuestionType[],
  weights: Record<QuestionType, number>,
  maxCount: number,
  preferHighQuality: boolean,
  dataQuality: string,
): QuestionType[] {
  // 过滤可用的类型及其权重
  const weighted = availableTypes
    .map(type => ({ type, weight: weights[type] || 0 }))
    .sort((a, b) => b.weight - a.weight) // 按权重降序

  // 如果偏好高质量数据，优先选择更"有价值"的题型
  if (preferHighQuality && dataQuality === 'excellent') {
    // 高质量数据可以尝试更多题型
    return weighted.slice(0, Math.min(maxCount + 1, weighted.length)).map(w => w.type)
  }

  return weighted.slice(0, maxCount).map(w => w.type)
}

// ─── 统计信息 ──────────────────────────────

/**
 * 生成缓存命中统计
 */
export function generateCacheStats(analyses: WordAnalysis[]): {
  total: number
  hit: number
  miss: number
  hitRate: string
  qualityDistribution: Record<string, number>
  typeAvailability: Record<QuestionType, number>
} {
  const total = analyses.length
  const hit = analyses.filter(a => a.hasCache).length
  const miss = total - hit

  const qualityDist: Record<string, number> = {}
  const typeAvail: Record<QuestionType, number> = {
    context_mcq: 0,
    meaning_choice: 0,
    english_definition: 0,
    word_forms: 0,
  }

  for (const analysis of analyses) {
    // 质量分布
    qualityDist[analysis.dataQuality] = (qualityDist[analysis.dataQuality] || 0) + 1

    // 题型可用性
    for (const type of analysis.availableTypes) {
      typeAvail[type]++
    }
  }

  return {
    total,
    hit,
    miss,
    hitRate: total > 0 ? `${((hit / total) * 100).toFixed(1)}%` : '0%',
    qualityDistribution: qualityDist,
    typeAvailability: typeAvail,
  }
}
