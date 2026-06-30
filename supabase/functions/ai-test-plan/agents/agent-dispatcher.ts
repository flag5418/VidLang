// deno-lint-ignore-file no-explicit-any
/**
 * V4 Agent Dispatcher (统一调度器)
 *
 * 职责：
 * 1. 根据题型自动选择对应的 Agent
 * 2. 统一调用入口，简化上层代码
 * 3. 自动执行 Quality Gate 校验
 * 4. 失败重试机制
 * 5. 批量生成优化
 *
 * 使用方式：
 * ```
 * const dispatcher = new AgentDispatcher(apiKey, baseUrl)
 * const results = await dispatcher.generateQuestions(inputs)
 * // results 包含所有通过质量门的题目
 * ```
 */

import { WordCacheData, DifficultyLevel, AgentOutput } from '../schemas.ts'
import { validateItem } from '../quality-gate.ts'

// 导入所有 Agent
import { generateMcqQuestion, generateBatchMcqQuestions } from './mcq-agent.ts'
import { generateMeaningQuestion, generateBatchMeaningQuestions } from './meaning-agent.ts'
import { generateDefinitionQuestion, generateBatchDefinitionQuestions } from './definition-agent.ts'
import { generateFormsQuestion, generateBatchFormsQuestions } from './forms-agent.ts'

// ─── 类型定义 ──────────────────────────────

/** 题型枚举 */
export type QuestionType =
  | 'context_mcq'       // B1: 语境选择题
  | 'meaning_choice'    // B2: 释义选择题
  | 'english_definition' // B7: 英文释义题
  | 'word_forms'        // B3: 词形变化题

/** 统一输入接口 */
export interface DispatchInput {
  word: string
  cacheData: WordCacheData
  questionType: QuestionType
  difficulty: DifficultyLevel
  sentence?: string              // context_mcq 需要
  meaningMode?: 'listen_meaning' | 'definition_choice' // meaning_choice 需要
  formsType?: 'forward' | 'reverse' // word_forms 需要
}

/** 调度结果 */
export interface DispatchResult {
  output: AgentOutput | null
  validation: ReturnType<typeof validateItem> | null
  retries: number                // 重试次数
  error?: string                 // 错误信息（如果最终失败）
}

/** 配置选项 */
export interface DispatcherConfig {
  maxRetries: number             // 最大重试次数（默认 2）
  minQualityScore: number        // 最低质量分数（默认 60）
  enableBatch: boolean           // 是否启用批量模式（默认 true）
}

// ─── Dispatcher 类 ──────────────────────────

export class AgentDispatcher {
  private apiKey: string
  private baseUrl: string
  private config: Required<DispatcherConfig>

  constructor(apiKey: string, baseUrl: string, config: Partial<DispatcherConfig> = {}) {
    this.apiKey = apiKey
    this.baseUrl = baseUrl
    this.config = {
      maxRetries: config.maxRetries ?? 2,
      minQualityScore: config.minQualityScore ?? 60,
      enableBatch: config.enableBatch ?? true,
    }
  }

  /**
   * 生成单道题目（带重试 + 质量门）
   */
  async generateOne(input: DispatchInput): Promise<DispatchResult> {
    let lastResult: DispatchResult = {
      output: null,
      validation: null,
      retries: 0,
    }

    for (let attempt = 0; attempt <= this.config.maxRetries; attempt++) {
      try {
        // 根据题型调用对应的 Agent
        const output = await this.callAgent(input)

        if (!output) {
          lastResult.retries = attempt
          continue // Agent 返回 null，重试
        }

        // 执行质量门校验
        const validation = validateItem(output)

        // 检查是否通过
        if (validation.valid && validation.score >= this.config.minQualityScore) {
          return {
            output,
            validation,
            retries: attempt,
          }
        }

        // 未通过质量门，记录并重试
        console.warn(
          `[Dispatcher] Quality gate failed for "${input.word}" (attempt ${attempt + 1}):`,
          `score=${validation.score}, errors=${validation.errors.length}`
        )

        lastResult = {
          output,
          validation,
          retries: attempt,
        }

      } catch (e) {
        console.error(`[Dispatcher] Error on attempt ${attempt + 1} for "${input.word}":`, e)
        lastResult.error = (e as Error).message
        lastResult.retries = attempt
      }

      // 重试前短暂延迟
      if (attempt < this.config.maxRetries) {
        await new Promise(resolve => setTimeout(resolve, 300))
      }
    }

    // 所有重试都失败
    console.error(`[Dispatcher] ❌ All retries exhausted for "${input.word}"`)
    return {
      ...lastResult,
      error: lastResult.error || `Failed to generate valid question after ${this.config.maxRetries + 1} attempts`,
    }
  }

  /**
   * 批量生成题目（优化：按题型分组批量调用）
   */
  async generateBatch(inputs: DispatchInput[]): Promise<DispatchResult[]> {
    const results: DispatchResult[] = []

    if (this.config.enableBatch && inputs.length >= 3) {
      // 按题型分组批量处理
      const grouped = this.groupByType(inputs)

      for (const [type, groupInputs] of Object.entries(grouped)) {
        console.log(`[Dispatcher] Batch processing ${groupInputs.length} questions of type "${type}"`)

        try {
          const batchOutputs = await this.callBatchAgent(type as QuestionType, groupInputs)

          // 对每个输出进行质量门校验
          for (let i = 0; i < batchOutputs.length; i++) {
            const output = batchOutputs[i]
            const validation = validateItem(output)

            results.push({
              output: validation.valid ? output : null,
              validation,
              retries: 0,
              error: !validation.valid ? `Quality gate failed: ${validation.errors.join('; ')}` : undefined,
            })
          }
        } catch (e) {
          console.error(`[Dispatcher] Batch failed for type "${type}", falling back to individual:`, e)

          // Fallback: 逐个生成
          for (const input of groupInputs) {
            const result = await this.generateOne(input)
            results.push(result)
          }
        }
      }
    } else {
      // 数量少时直接逐个处理
      for (const input of inputs) {
        const result = await this.generateOne(input)
        results.push(result)
      }
    }

    return results
  }

  // ─── 私有方法 ────────────────────────────

  /**
   * 根据题型调用对应的 Agent
   */
  private async callAgent(input: DispatchInput): Promise<AgentOutput | null> {
    switch (input.questionType) {
      case 'context_mcq':
        return generateMcqQuestion({
          word: input.word,
          cacheData: input.cacheData,
          sentence: input.sentence,
          difficulty: input.difficulty,
        }, this.apiKey, this.baseUrl)

      case 'meaning_choice':
        return generateMeaningQuestion({
          word: input.word,
          cacheData: input.cacheData,
          difficulty: input.difficulty,
          mode: input.meaningMode || 'definition_choice',
        }, this.apiKey, this.baseUrl)

      case 'english_definition':
        return generateDefinitionQuestion({
          word: input.word,
          cacheData: input.cacheData,
          difficulty: input.difficulty,
        }, this.apiKey, this.baseUrl)

      case 'word_forms':
        return generateFormsQuestion({
          word: input.word,
          cacheData: input.cacheData,
          difficulty: input.difficulty,
          formType: input.formsType || 'forward',
        }, this.apiKey, this.baseUrl)

      default:
        console.error(`[Dispatcher] Unknown question type: ${(input as any).questionType}`)
        return null
    }
  }

  /**
   * 按题型分组批量调用
   */
  private async callBatchAgent(
    type: QuestionType,
    inputs: DispatchInput[]
  ): Promise<AgentOutput[]> {
    switch (type) {
      case 'context_mcq':
        return generateBatchMcqQuestions(
          inputs.map(inp => ({
            word: inp.word,
            cacheData: inp.cacheData,
            sentence: inp.sentence,
            difficulty: inp.difficulty,
          })),
          this.apiKey,
          this.baseUrl
        )

      case 'meaning_choice':
        return generateBatchMeaningQuestions(
          inputs.map(inp => ({
            word: inp.word,
            cacheData: inp.cacheData,
            difficulty: inp.difficulty,
            mode: inp.meaningMode || 'definition_choice',
          })),
          this.apiKey,
          this.baseUrl
        )

      case 'english_definition':
        return generateBatchDefinitionQuestions(
          inputs.map(inp => ({
            word: inp.word,
            cacheData: inp.cacheData,
            difficulty: inp.difficulty,
          })),
          this.apiKey,
          this.baseUrl
        )

      case 'word_forms': {
        // Forms 题需要过滤数据不足的单词
        const validInputs = inputs.filter(inp => {
          const forms = inp.cacheData.morphology || {}
          const formCount = Object.values(forms).filter(v => v !== null && v !== undefined).length
          return formCount >= 3
        })

        return generateBatchFormsQuestions(
          validInputs.map(inp => ({
            word: inp.word,
            cacheData: inp.cacheData,
            difficulty: inp.difficulty,
            formType: inp.formsType || 'forward',
          })),
          this.apiKey,
          this.baseUrl
        )
      }

      default:
        throw new Error(`Unknown batch type: ${type}`)
    }
  }

  /**
   * 按题型分组
   */
  private groupByType(inputs: DispatchInput[]): Record<string, DispatchInput[]> {
    return inputs.reduce((groups, input) => {
      const key = input.questionType
      if (!groups[key]) {
        groups[key] = []
      }
      groups[key].push(input)
      return groups
    }, {} as Record<string, DispatchInput[]>)
  }
}

// ─── 便捷函数 ──────────────────────────────

/**
 * 快速创建 Dispatcher 并生成题目
 *
 * @param apiKey - Qwen API Key
 * @param baseUrl - Qwen Base URL
 * @param inputs - 输入数组
 * @param config - 可选配置
 * @returns Promise<DispatchResult[]>
 */
export async function generateQuestions(
  apiKey: string,
  baseUrl: string,
  inputs: DispatchInput[],
  config?: Partial<DispatcherConfig>,
): Promise<DispatchResult[]> {
  const dispatcher = new AgentDispatcher(apiKey, baseUrl, config)
  return dispatcher.generateBatch(inputs)
}
