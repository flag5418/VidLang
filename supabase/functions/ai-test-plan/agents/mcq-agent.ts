// deno-lint-ignore-file no-explicit-any
/**
 * B1: MCQ Agent (语境选择题)
 *
 * 核心功能：
 * - 基于单词 + 语境句子生成高质量 4 选 1 选择题
 * - 使用 synonyms/antonyms 智能生成干扰项
 * - 支持难度分级（beginner → professional）
 *
 * 数据来源：word_cache (definitions, morphology, synonyms, antonyms, category)
 */

import { aiChat } from '../../ai-proxy/clients/qwen-chat.ts'
import {
  McqAgentInput,
  McqAgentOutput,
  WordCacheData,
  DifficultyLevel,
  OptionLabel,
} from '../schemas.ts'
import { buildMcqPrompt } from './prompt-templates.ts'

// ─── 辅助函数 ──────────────────────────────

/**
 * 从 word_cache 数据提取核心信息
 */
function extractWordInfo(cacheData: WordCacheData): {
  morphology: string
  definition: string
  synonyms?: string[]
  antonyms?: string[]
} {
  // 提取主要词性（从第一个 definition 获取）
  const firstDef = cacheData.definitions?.[0]
  const morphology = firstDef?.part_of_speech || cacheData.morphology?._type || 'unknown'
  const definition = firstDef?.chinese_meaning || firstDef?.english_meaning || 'N/A'

  return {
    morphology,
    definition,
    synonyms: cacheData.synonyms,
    antonyms: cacheData.antonyms,
  }
}

/**
 * 解析 AI 返回的 JSON
 */
function parseMcqResponse(raw: string, input: McqAgentInput): McqAgentOutput | null {
  try {
    // 清理 markdown 代码块标记
    let cleaned = raw.trim()
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replace(/^```(?:json)?\s*\n?/, '').replace(/\n?```\s*$/, '')
    }

    const parsed = JSON.parse(cleaned)

    // 验证必要字段
    if (!parsed.options || !Array.isArray(parsed.options) || parsed.options.length !== 4) {
      console.error(`[MCQ Agent] Invalid options for "${input.word}":`, parsed.options)
      return null
    }

    if (!['A', 'B', 'C', 'D'].includes(parsed.correctAnswer)) {
      console.error(`[MCQ Agent] Invalid correctAnswer for "${input.word}":`, parsed.correctAnswer)
      return null
    }

    const answerIndex = parsed.correctAnswer.charCodeAt(0) - 65 // A=0, B=1, ...

    return {
      type: 'context_mcq',
      word: input.word,
      question: parsed.question || 'Complete the sentence:',
      sentence: input.sentence || parsed.sentence || '',
      maskedSentence: parsed.masked_sentence || '',
      options: parsed.options,
      correctAnswer: parsed.correctAnswer as OptionLabel,
      answerText: parsed.options[answerIndex],
      difficulty: input.difficulty,
      hint: parsed.hint || undefined,
      feedback: parsed.feedback || undefined,
      metadata: {
        morphology: extractWordInfo(input.cacheData).morphology,
        distractorTypes: [], // 可后续通过分析选项填充
      },
    }
  } catch (e) {
    console.error(`[MCQ Agent] Failed to parse response for "${input.word}":`, e, '\nRaw:', raw.substring(0, 200))
    return null
  }
}

// ─── 主函数 ─────────────────────────────────

/**
 * 生成一道语境选择题
 *
 * @param input - Agent 输入参数
 * @param apiKey - Qwen API Key
 * @param baseUrl - Qwen Base URL
 * @returns MCQ 题目输出 | null（如果生成失败）
 */
export async function generateMcqQuestion(
  input: McqAgentInput,
  apiKey: string,
  baseUrl: string,
): Promise<McqAgentOutput | null> {
  const { word, cacheData, sentence, difficulty } = input

  // 提取单词信息
  const { morphology, definition, synonyms, antonyms } = extractWordInfo(cacheData)

  // 如果没有足够的词性信息，跳过
  if (morphology === 'unknown' && !definition) {
    console.warn(`[MCQ Agent] Skipping "${word}": insufficient data`)
    return null
  }

  // 构建 Prompt
  const prompt = buildMcqPrompt({
    word,
    morphology,
    definition,
    sentence,
    synonyms,
    antonyms,
    difficulty,
  })

  try {
    // 调用 AI（使用 qwen-turbo，temperature=0.4 保证质量同时有变化）
    const result = await aiChat(
      apiKey,
      baseUrl,
      prompt,
      `You are an expert English test designer. Generate high-quality multiple-choice questions.`,
      0.4, // temperature：适中，保证质量的同时允许一定创造性
      1200, // maxTokens：足够容纳题目+解析
    )

    // 解析返回结果
    const output = parseMcqResponse(result.raw || '', input)

    if (!output) {
      console.warn(`[MCQ Agent] Failed to generate valid question for "${word}"`)
      return null
    }

    console.log(`[MCQ Agent] ✅ Generated MCQ for "${word}" (${difficulty})`)
    return output

  } catch (e) {
    console.error(`[MCQ Agent] Error generating question for "${word}":`, e)
    return null
  }
}

/**
 * 批量生成 MCQ 题目（优化：一次 API 调用生成多道题）
 *
 * @param inputs - 多个单词的输入数组
 * @param apiKey - Qwen API Key
 * @param baseUrl - Qwen Base URL
 * @returns 成功生成的题目数组
 */
export async function generateBatchMcqQuestions(
  inputs: McqAgentInput[],
  apiKey: string,
  baseUrl: string,
): Promise<McqAgentOutput[]> {
  const results: McqAgentOutput[] = []

  // 分批处理（每批最多 5 个词，避免 prompt 过长）
  const BATCH_SIZE = 5

  for (let i = 0; i < inputs.length; i += BATCH_SIZE) {
    const batch = inputs.slice(i, i + BATCH_SIZE)

    // 构建批量 Prompt
    const batchPrompts = batch.map((input, idx) => {
      const { morphology, definition, synonyms, antonyms } = extractWordInfo(input.cacheData)
      return buildMcqPrompt({
        word: input.word,
        morphology,
        definition,
        sentence: input.sentence,
        synonyms,
        antonyms,
        difficulty: input.difficulty,
      })
    })

    const combinedPrompt = `Generate ${batch.length} separate multiple-choice questions, one for each word below.

Return a JSON ARRAY (not an object). Each element in the array is one complete question.

${batchPrompts.map((p, idx) => `\n--- QUESTION ${idx + 1} FOR WORD "${batch[idx].word}" ---\n${p}`).join('\n')}

## FINAL OUTPUT FORMAT
Return ONLY a JSON array like:
[
  { "word": "...", "question": "...", ... },
  { "word": "...", "question": "...", ... }
]

Each object must have: word, question, sentence/masked_sentence, options[4], correctAnswer, hint, feedback`

    try {
      const result = await aiChat(
        apiKey,
        baseUrl,
        combinedPrompt,
        `You are an expert English test designer. Generate multiple questions at once.`,
        0.4,
        3000, // 更大的 token 上限以容纳多道题
      )

      // 尝试解析为数组
      let cleaned = (result.raw || '').trim()
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replace(/^```(?:json)?\s*\n?/, '').replace(/\n?```\s*$/, '')
      }

      const parsedArray = JSON.parse(cleaned)

      if (Array.isArray(parsedArray)) {
        for (const item of parsedArray) {
          // 匹配回对应的 input
          const matchingInput = batch.find(inp => inp.word === item.word)
          if (matchingInput) {
            const output = parseMcqResponse(JSON.stringify(item), matchingInput)
            if (output) {
              results.push(output)
            }
          }
        }
      }

      console.log(`[MCQ Batch] ✅ Generated ${parsedArray.length?.length || 0} questions from batch`)

    } catch (e) {
      console.error(`[MCQ Batch] Error in batch generation:`, e)

      // Fallback: 逐个生成
      console.log('[MCQ Batch] Falling back to individual generation...')
      for (const input of batch) {
        const singleResult = await generateMcqQuestion(input, apiKey, baseUrl)
        if (singleResult) {
          results.push(singleResult)
        }
      }
    }

    // 批次间稍作延迟
    if (i + BATCH_SIZE < inputs.length) {
      await new Promise(resolve => setTimeout(resolve, 200))
    }
  }

  return results
}
