// deno-lint-ignore-file no-explicit-any
/**
 * B7: Definition Agent (英文释义理解题)
 *
 * 核心功能：
 * - 用英文描述单词含义，让用户选择正确的单词
 * - 测试深度理解能力（而非机械记忆）
 * - 干扰项策略：反义词 + 不同类别词 + 近音近形词
 *
 * 价值：
 * - 培养英英思维（English-to-English）
 * - 适合中高级学习者
 * - 差异化功能（竞品较少）
 */

import { aiChat } from '../../ai-proxy/clients/qwen-chat.ts'
import {
  DefinitionAgentInput,
  DefinitionAgentOutput,
  WordCacheData,
  DifficultyLevel,
  OptionLabel,
} from '../schemas.ts'
import { buildDefinitionPrompt } from './prompt-templates.ts'

// ─── 辅助函数 ──────────────────────────────

/**
 * 提取完整信息
 */
function extractDefinitionInfo(cacheData: WordCacheData): {
  morphology: string
  definition: string
  englishMeaning?: string
  synonyms?: string[]
  antonyms?: string[]
  category?: string
} {
  const firstDef = cacheData.definitions?.[0]
  return {
    morphology: firstDef?.part_of_speech || 'unknown',
    definition: firstDef?.chinese_meaning || 'N/A',
    englishMeaning: firstDef?.english_meaning,
    synonyms: cacheData.synonyms,
    antonyms: cacheData.antonyms,
    category: cacheData.category,
  }
}

/**
 * 解析 AI 返回的 JSON
 */
function parseDefinitionResponse(raw: string, input: DefinitionAgentInput): DefinitionAgentOutput | null {
  try {
    let cleaned = raw.trim()
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replace(/^```(?:json)?\s*\n?/, '').replace(/\n?```\s*$/, '')
    }

    const parsed = JSON.parse(cleaned)

    // 验证必要字段
    if (!parsed.definition || typeof parsed.definition !== 'string') {
      console.error(`[Definition Agent] Missing definition for "${input.word}"`)
      return null
    }

    if (!parsed.options || !Array.isArray(parsed.options) || parsed.options.length !== 4) {
      console.error(`[Definition Agent] Invalid options for "${input.word}":`, parsed.options)
      return null
    }

    if (!['A', 'B', 'C', 'D'].includes(parsed.correctAnswer)) {
      console.error(`[Definition Agent] Invalid correctAnswer for "${input.word}":`, parsed.correctAnswer)
      return null
    }

    const answerIndex = parsed.correctAnswer.charCodeAt(0) - 65

    // 验证正确答案是否为目标词（或其变体）
    const correctOption = parsed.options[answerIndex]?.toLowerCase()
    const targetWord = input.word.toLowerCase()
    const isCorrect = correctOption === targetWord ||
      correctOption?.startsWith(targetWord) ||
      targetWord.includes(correctOption || '')

    if (!isCorrect) {
      console.warn(`[Definition Agent] Correct option "${correctOption}" doesn't match target "${targetWord}"`)
      // 不直接返回 null，因为 AI 可能用了不同的形式（如复数等）
    }

    return {
      type: 'english_definition',
      word: input.word,
      definition: parsed.definition,
      question: parsed.question || `Which word means "${parsed.definition}"?`,
      options: parsed.options,
      correctAnswer: parsed.correctAnswer as OptionLabel,
      answerText: parsed.options[answerIndex],
      difficulty: input.difficulty,
      hint: parsed.hint || undefined,
      feedback: parsed.feedback || undefined,
      distractorMetadata: {
        antonym: undefined, // 可后续通过分析选项填充
        differentCategory: undefined,
        similarSound: undefined,
      },
    }
  } catch (e) {
    console.error(`[Definition Agent] Failed to parse response for "${input.word}":`, e)
    return null
  }
}

// ─── 主函数 ─────────────────────────────────

/**
 * 生成一道英文释义理解题
 */
export async function generateDefinitionQuestion(
  input: DefinitionAgentInput,
  apiKey: string,
  baseUrl: string,
): Promise<DefinitionAgentOutput | null> {
  const { word, cacheData, difficulty } = input

  // 提取完整信息
  const info = extractDefinitionInfo(cacheData)

  // 英文释义题需要一定的词汇基础，beginner 可能不适合
  if (difficulty === 'beginner' && !info.englishMeaning) {
    console.warn(`[Definition Agent] Skipping "${word}" for beginner: no english_meaning available`)
    return null
  }

  // 构建 Prompt
  const prompt = buildDefinitionPrompt({
    word,
    morphology: info.morphology,
    definition: info.definition,
    englishMeaning: info.englishMeaning,
    synonyms: info.synonyms,
    antonyms: info.antonyms,
    category: info.category,
    difficulty,
  })

  try {
    const result = await aiChat(
      apiKey,
      baseUrl,
      prompt,
      `You are an expert vocabulary teacher. Generate English-definition questions that test deep understanding.`,
      0.5, // 稍高的 temperature 允许更多创造性
      1000,
    )

    const output = parseDefinitionResponse(result.raw || '', input)

    if (!output) {
      console.warn(`[Definition Agent] Failed to generate valid question for "${word}"`)
      return null
    }

    console.log(`[Definition Agent] ✅ Generated definition question for "${word}" (${difficulty})`)
    return output

  } catch (e) {
    console.error(`[Definition Agent] Error generating question for "${word}":`, e)
    return null
  }
}

/**
 * 批量生成英文释义题
 */
export async function generateBatchDefinitionQuestions(
  inputs: DefinitionAgentInput[],
  apiKey: string,
  baseUrl: string,
): Promise<DefinitionAgentOutput[]> {
  const results: DefinitionAgentOutput[] = []

  for (const input of inputs) {
    const result = await generateDefinitionQuestion(input, apiKey, baseUrl)
    if (result) {
      results.push(result)
    }
    await new Promise(resolve => setTimeout(resolve, 150))
  }

  return results
}
