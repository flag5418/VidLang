// deno-lint-ignore-file no-explicit-any
/**
 * B3: Forms Agent (词形变化题)
 *
 * 核心功能：
 * - 测试单词的语法变形能力（过去式、复数、比较级等）
 * - 支持正向（给词选形）和反向（给形选词）
 * - 特别适合动词和形容词的形态变化测试
 *
 * 数据来源：word_cache.morphology (plural, past_tense, comparative, etc.)
 */

import { aiChat } from '../../ai-proxy/clients/qwen-chat.ts'
import {
  FormsAgentInput,
  FormsAgentOutput,
  WordCacheData,
  DifficultyLevel,
  OptionLabel,
} from '../schemas.ts'
import { buildFormsPrompt } from './prompt-templates.ts'

// ─── 辅助函数 ──────────────────────────────

/**
 * 提取词形变化数据
 */
function extractFormsData(cacheData: WordCacheData): {
  morphology: string
  forms: Record<string, string>
} {
  const rawMorphology = cacheData.morphology || {}
  const firstDef = cacheData.definitions?.[0]
  const morphology = firstDef?.part_of_speech || 'unknown'

  // 提取所有非空的形式
  const forms: Record<string, string> = {}
  const formFields = [
    'plural', 'past_tense', 'past_participle', 'present_participle',
    'third_person_singular', 'comparative', 'superlative', 'adverb', 'noun'
  ]

  for (const field of formFields) {
    if (rawMorphology[field] && rawMorphology[field] !== null) {
      forms[field] = rawMorphology[field]
    }
  }

  return { morphology, forms }
}

/**
 * 检查是否有足够的词形数据来出题
 */
function hasEnoughForms(forms: Record<string, string>, minLength = 3): boolean {
  return Object.keys(forms).length >= minLength
}

/**
 * 解析 AI 返回的 JSON
 */
function parseFormsResponse(raw: string, input: FormsAgentInput): FormsAgentOutput | null {
  try {
    let cleaned = raw.trim()
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replace(/^```(?:json)?\s*\n?/, '').replace(/\n?```\s*$/, '')
    }

    const parsed = JSON.parse(cleaned)

    // 验证必要字段
    if (!parsed.options || !Array.isArray(parsed.options) || parsed.options.length !== 4) {
      console.error(`[Forms Agent] Invalid options for "${input.word}":`, parsed.options)
      return null
    }

    if (!['A', 'B', 'C', 'D'].includes(parsed.correctAnswer)) {
      console.error(`[Forms Agent] Invalid correctAnswer for "${input.word}":`, parsed.correctAnswer)
      return null
    }

    const answerIndex = parsed.correctAnswer.charCodeAt(0) - 65

    return {
      type: 'word_forms',
      word: input.word,
      formType: input.formType,
      question: parsed.question || `Choose the correct form of '${input.word}':`,
      options: parsed.options,
      correctAnswer: parsed.correctAnswer as OptionLabel,
      answerText: parsed.options[answerIndex],
      targetForm: parsed.target_form || 'unknown',
      difficulty: input.difficulty,
      hint: parsed.hint || undefined,
      feedback: parsed.feedback || undefined,
      allForms: parsed.all_forms || undefined,
    }
  } catch (e) {
    console.error(`[Forms Agent] Failed to parse response for "${input.word}":`, e)
    return null
  }
}

// ─── 主函数 ─────────────────────────────────

/**
 * 生成一道词形变化题
 */
export async function generateFormsQuestion(
  input: FormsAgentInput,
  apiKey: string,
  baseUrl: string,
): Promise<FormsAgentOutput | null> {
  const { word, cacheData, difficulty, formType } = input

  // 提取词形数据
  const { morphology, forms } = extractFormsData(cacheData)

  // 检查是否有足够的词形数据
  if (!hasEnoughForms(forms)) {
    console.warn(`[Forms Agent] Skipping "${word}": insufficient form data (only ${Object.keys(forms).length} forms)`)
    return null
  }

  console.log(`[Forms Agent] Generating ${formType} question for "${word}" with forms:`, Object.keys(forms))

  // 构建 Prompt
  const prompt = buildFormsPrompt({
    word,
    morphology,
    forms,
    difficulty,
    formType,
  })

  try {
    const result = await aiChat(
      apiKey,
      baseUrl,
      prompt,
      `You are an expert English grammar teacher. Generate word-form transformation questions.`,
      0.3, // 低 temperature 保证语法的准确性
      800,
    )

    const output = parseFormsResponse(result.raw || '', input)

    if (!output) {
      console.warn(`[Forms Agent] Failed to generate valid question for "${word}"`)
      return null
    }

    console.log(`[Forms Agent] ✅ Generated forms question for "${word}" (${formType}, target: ${output.targetForm})`)
    return output

  } catch (e) {
    console.error(`[Forms Agent] Error generating question for "${word}":`, e)
    return null
  }
}

/**
 * 批量生成词形变化题
 *
 * @param inputs - 输入数组（会自动过滤掉数据不足的单词）
 */
export async function generateBatchFormsQuestions(
  inputs: FormsAgentInput[],
  apiKey: string,
  baseUrl: string,
): Promise<FormsAgentOutput[]> {
  const results: FormsAgentOutput[] = []

  for (const input of inputs) {
    // 预检查：跳过数据不足的单词
    const { forms } = extractFormsData(input.cacheData)
    if (!hasEnoughForms(forms)) {
      continue
    }

    const result = await generateFormsQuestion(input, apiKey, baseUrl)
    if (result) {
      results.push(result)
    }
    await new Promise(resolve => setTimeout(resolve, 100))
  }

  return results
}
