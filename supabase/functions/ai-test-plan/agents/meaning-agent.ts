// deno-lint-ignore-file no-explicit-any
/**
 * B2: Meaning Agent (释义选择题)
 *
 * 核心功能：
 * - 生成"看词选义"或"听音选义"题目
 * - 正确答案来自 word_cache.definitions
 * - 干扰项为 AI 生成的常见错误释义
 *
 * 两种模式：
 * - definition_choice: 看英文单词 → 选中文释义
 * - listen_meaning: 播放 TTS 发音 → 选中文释义
 */

import { aiChat } from '../../ai-proxy/clients/qwen-chat.ts'
import {
  MeaningAgentInput,
  MeaningAgentOutput,
  WordCacheData,
  DifficultyLevel,
  OptionLabel,
} from '../schemas.ts'
import { buildMeaningPrompt } from './prompt-templates.ts'

// ─── 辅助函数 ──────────────────────────────

/**
 * 提取释义和音标
 */
function extractMeaningInfo(cacheData: WordCacheData): {
  definition: string
  phoneticUk?: string
  phoneticUs?: string
} {
  const firstDef = cacheData.definitions?.[0]
  return {
    definition: firstDef?.chinese_meaning || 'N/A',
    phoneticUk: cacheData.phonetic_uk,
    phoneticUs: cacheData.phonetic_us,
  }
}

/**
 * 解析 AI 返回的 JSON
 */
function parseMeaningResponse(raw: string, input: MeaningAgentInput): MeaningAgentOutput | null {
  try {
    let cleaned = raw.trim()
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replace(/^```(?:json)?\s*\n?/, '').replace(/\n?```\s*$/, '')
    }

    const parsed = JSON.parse(cleaned)

    // 验证必要字段
    if (!parsed.options || !Array.isArray(parsed.options) || parsed.options.length !== 4) {
      console.error(`[Meaning Agent] Invalid options for "${input.word}":`, parsed.options)
      return null
    }

    if (!['A', 'B', 'C', 'D'].includes(parsed.correctAnswer)) {
      console.error(`[Meaning Agent] Invalid correctAnswer for "${input.word}":`, parsed.correctAnswer)
      return null
    }

    const answerIndex = parsed.correctAnswer.charCodeAt(0) - 65

    return {
      type: 'meaning_choice',
      word: input.word,
      mode: input.mode,
      question: parsed.question || `What does "${input.word}" mean?`,
      options: parsed.options,
      correctAnswer: parsed.correctAnswer as OptionLabel,
      answerText: parsed.options[answerIndex],
      difficulty: input.difficulty,
      hint: parsed.hint || undefined,
      feedback: parsed.feedback || undefined,
      phoneticUk: input.cacheData.phonetic_uk,
      phoneticUs: input.cacheData.phonetic_us,
    }
  } catch (e) {
    console.error(`[Meaning Agent] Failed to parse response for "${input.word}":`, e)
    return null
  }
}

// ─── 主函数 ─────────────────────────────────

/**
 * 生成一道释义选择题
 */
export async function generateMeaningQuestion(
  input: MeaningAgentInput,
  apiKey: string,
  baseUrl: string,
): Promise<MeaningAgentOutput | null> {
  const { word, cacheData, difficulty, mode } = input

  // 提取信息
  const { definition, phoneticUk, phoneticUs } = extractMeaningInfo(cacheData)

  if (definition === 'N/A') {
    console.warn(`[Meaning Agent] Skipping "${word}": no definition available`)
    return null
  }

  // 构建 Prompt
  const prompt = buildMeaningPrompt({
    word,
    definition,
    phoneticUk,
    phoneticUs,
    difficulty,
    mode,
  })

  try {
    const result = await aiChat(
      apiKey,
      baseUrl,
      prompt,
      `You are an expert vocabulary teacher. Generate meaning-recognition questions.`,
      0.3, // 低 temperature 保证释义准确性
      800,
    )

    const output = parseMeaningResponse(result.raw || '', input)

    if (!output) {
      console.warn(`[Meaning Agent] Failed to generate valid question for "${word}"`)
      return null
    }

    console.log(`[Meaning Agent] ✅ Generated meaning question for "${word}" (${mode})`)
    return output

  } catch (e) {
    console.error(`[Meaning Agent] Error generating question for "${word}":`, e)
    return null
  }
}

/**
 * 批量生成释义选择题
 */
export async function generateBatchMeaningQuestions(
  inputs: MeaningAgentInput[],
  apiKey: string,
  baseUrl: string,
): Promise<MeaningAgentOutput[]> {
  const results: MeaningAgentOutput[] = []

  for (const input of inputs) {
    const result = await generateMeaningQuestion(input, apiKey, baseUrl)
    if (result) {
      results.push(result)
    }
    // 短暂延迟避免限流
    await new Promise(resolve => setTimeout(resolve, 100))
  }

  return results
}
