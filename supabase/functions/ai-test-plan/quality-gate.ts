// deno-lint-ignore-file no-explicit-any
/**
 * V4 Quality Gate (质量门)
 *
 * 多维度合规性校验，确保 AI 生成的题目质量达标
 *
 * 校验规则：
 * R1: 选项数量必须 = 4
 * R2: 正确答案必须在选项范围内
 * R3: 选项不能有重复值
 * R4: 选项不能包含目标词本身（释义题除外）
 * R5: 选项长度不能差异过大（防泄露）
 * R6: 不能所有选项都相同（编辑距离检测）
 * R7: 英文释义不能包含目标词
 * R8: 选项之间必须有足够区分度
 * R9: hint 不能直接泄露答案
 */

import { AgentOutput, ValidationResult } from './schemas.ts'

// ─── 配置 ──────────────────────────────────

/** 质量阈值配置 */
const QUALITY_THRESHOLDS = {
  /** 最大允许的选项长度比率（最长/最短） */
  maxOptionLengthRatio: 3,
  /** 最小编辑距离（选项之间） */
  minEditDistance: 2,
  /** 答案泄露关键词列表 */
  answerLeakPatterns: [
    /correct/i,
    /right answer/i,
    /the answer is/i,
    /choose.*[a-d]/i,
    /option\s*[a-d]\s*is\s*(correct|right)/i,
  ],
}

// ─── 工具函数 ──────────────────────────────

/**
 * 计算两个字符串的 Levenshtein 编辑距离
 */
function levenshteinDistance(a: string, b: string): number {
  const matrix: number[][] = []

  for (let i = 0; i <= b.length; i++) {
    matrix[i] = [i]
  }
  for (let j = 0; j <= a.length; j++) {
    matrix[0][j] = j
  }

  for (let i = 1; i <= b.length; i++) {
    for (let j = 1; j <= a.length; j++) {
      if (b.charAt(i - 1) === a.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1]
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1, // substitution
          matrix[i][j - 1] + 1,     // insertion
          matrix[i - 1][j] + 1      // deletion
        )
      }
    }
  }

  return matrix[b.length][a.length]
}

/**
 * 检查字符串是否包含答案泄露模式
 */
function hasAnswerLeak(text: string, correctAnswer: string): boolean {
  const lowerText = text.toLowerCase()
  const lowerAnswer = correctAnswer.toLowerCase()

  // 检查关键词模式
  for (const pattern of QUALITY_THRESHOLDS.answerLeakPatterns) {
    if (pattern.test(lowerText)) {
      return true
    }
  }

  // 检查是否直接包含答案文本（对于 hint 字段）
  if (lowerText.includes(lowerAnswer) && lowerAnswer.length > 3) {
    return true
  }

  return false
}

// ─── 规则实现 ──────────────────────────────

/**
 * R1: 选项数量必须 = 4
 */
function validateR1OptionCount(output: AgentOutput): string | null {
  const options = output.options
  if (!options || options.length !== 4) {
    return `R1 Violation: Expected 4 options, got ${options?.length || 0}`
  }
  return null
}

/**
 * R2: 正确答案必须在选项范围内
 */
function validateR2ValidAnswer(output: AgentOutput): string | null {
  const { correctAnswer, options } = output
  const validAnswers = ['A', 'B', 'C', 'D']

  if (!validAnswers.includes(correctAnswer)) {
    return `R2 Violation: Invalid correctAnswer "${correctAnswer}", must be A/B/C/D`
  }

  const index = correctAnswer.charCodeAt(0) - 65 // A=0, B=1, ...
  if (index < 0 || index >= options.length) {
    return `R2 Violation: Answer index ${index} out of bounds (options length: ${options.length})`
  }

  return null
}

/**
 * R3: 选项不能有重复值
 */
function validateR3NoDuplicates(output: AgentOutput): string | null {
  const { options } = output
  const normalized = options.map(o => o.toLowerCase().trim())
  const unique = new Set(normalized)

  if (unique.size !== options.length) {
    const duplicates = options.filter((opt, idx) =>
      normalized.indexOf(opt.toLowerCase().trim()) !== idx
    )
    return `R3 Violation: Duplicate options found: [${duplicates.join(', ')}]`
  }

  return null
}

/**
 * R4: 选项不能包含目标词本身（释义题和词形题除外）
 */
function validateR4NoTargetWord(options: string[], targetWord: string, type: string): string | null {
  // 这些题型允许包含目标词
  const allowedTypes = ['english_definition', 'word_forms']
  if (allowedTypes.includes(type)) {
    return null
  }

  const lowerTarget = targetWord.toLowerCase()
  for (const option of options) {
    if (option.toLowerCase().includes(lowerTarget)) {
      return `R4 Violation: Option "${option}" contains target word "${targetWord}"`
    }
  }

  return null
}

/**
 * R5: 选项长度不能差异过大（防止明显的答案泄露）
 */
function validateR5OptionLengthBalance(output: AgentOutput): string | null {
  const { options } = output
  const lengths = options.map(o => o.replace(/\s/g, '').length) // 去空格后的字符数

  const minLength = Math.min(...lengths)
  const maxLength = Math.max(...lengths)

  if (minLength > 0 && maxLength / minLength > QUALITY_THRESHOLDS.maxOptionLengthRatio) {
    return `R5 Violation: Option length ratio ${maxLength}/${minLength} exceeds threshold ${QUALITY_THRESHOLDS.maxOptionLengthRatio}. Options may be unbalanced.`
  }

  return null
}

/**
 * R6: 选项之间必须有足够区分度（编辑距离检测）
 */
function validateR6OptionDistinctness(output: AgentOutput): string | null {
  const { options } = output

  for (let i = 0; i < options.length; i++) {
    for (let j = i + 1; j < options.length; j++) {
      const distance = levenshteinDistance(
        options[i].toLowerCase(),
        options[j].toLowerCase()
      )

      if (distance < QUALITY_THRESHOLDS.minEditDistance) {
        return `R6 Violation: Options "${options[i]}" and "${options[j]}" are too similar (edit distance: ${distance})`
      }
    }
  }

  return null
}

/**
 * R7: 英文释义不能包含目标词本身
 */
function validateR7DefinitionNoTargetWord(definition: string, targetWord: string): string | null {
  if (!definition) return null

  const lowerDef = definition.toLowerCase()
  const lowerTarget = targetWord.toLowerCase()

  // 检查各种形式：原词、复数、-ing 等
  const variants = [
    lowerTarget,
    lowerTarget + 's',
    lowerTarget + 'es',
    lowerTarget + 'ing',
    lowerTarget + 'ed',
    lowerTarget + 'ly',
  ]

  for (const variant of variants) {
    // 使用单词边界匹配，避免误判（如 "happy" 不应匹配 "happen"）
    const regex = new RegExp(`\\b${variant}\\b`, 'i')
    if (regex.test(lowerDef)) {
      return `R7 Violation: Definition contains target word variant "${variant}"`
    }
  }

  return null
}

/**
 * R8: 选项之间语义区分度检查（基于简单启发式）
 */
function validateR8SemanticDistinction(output: AgentOutput): string | null {
  const { options, type } = output

  // 对于中文释义题，检查是否有完全相同的选项
  if (type === 'meaning_choice') {
    const normalized = options.map(o => o.replace(/[，。！？、；：“”''（）]/g, ''))
    const unique = new Set(normalized)
    if (unique.size < options.length) {
      return `R8 Violation: Meaning options have semantic duplicates after normalization`
    }
  }

  return null // 更复杂的语义检查需要 NLP 模型，这里仅做基础检查
}

/**
 * R9: hint 不能直接泄露答案
 */
function validateR9HintNoLeak(hint: string | undefined, answerText: string): string | null {
  if (!hint) return null

  if (hasAnswerLeak(hint, answerText)) {
    return `R9 Violation: Hint appears to leak the answer: "${hint.substring(0, 50)}..."`
  }

  return null
}

// ─── 主校验函数 ─────────────────────────────

/**
 * 执行完整的质量门校验
 *
 * @param output - Agent 输出的题目
 * @returns 校验结果（包含错误/警告/评分）
 */
export function validateItem(output: AgentOutput): ValidationResult {
  const errors: string[] = []
  const warnings: string[] = []
  let score = 100 // 初始满分

  // 基础规则（必须通过）
  const r1Error = validateR1OptionCount(output)
  if (r1Error) { errors.push(r1Error); score -= 30 }

  const r2Error = validateR2ValidAnswer(output)
  if (r2Error) { errors.push(r2Error); score -= 30 }

  const r3Error = validateR3NoDuplicates(output)
  if (r3Error) { errors.push(r3Error); score -= 20 }

  // 高级规则
  const r4Error = validateR4NoTargetWord(output.options, output.word, output.type)
  if (r4Error) { errors.push(r4Error); score -= 15 }

  const r5Error = validateR5OptionLengthBalance(output)
  if (r5Error) { warnings.push(r5Error); score -= 10 } // 作为警告而非硬性失败

  const r6Error = validateR6OptionDistinctness(output)
  if (r6Error) { errors.push(r6Error); score -= 15 }

  // 特定题型规则
  if (output.type === 'english_definition' && 'definition' in output) {
    const r7Error = validateR7DefinitionNoTargetWord(
      (output as any).definition,
      output.word
    )
    if (r7Error) { errors.push(r7Error); score -= 20 }
  }

  const r8Error = validateR8SemanticDistinction(output)
  if (r8Error) { warnings.push(r8Error); score -= 5 }

  const r9Error = validateR9HintNoLeak(output.hint, output.answerText)
  if (r9Error) { warnings.push(r9Error); score -= 10 }

  // 确保分数在合理范围内
  score = Math.max(0, Math.min(100, score))

  return {
    valid: errors.length === 0, // 有任何错误则无效
    errors,
    warnings,
    score,
  }
}

/**
 * 批量校验多个题目
 *
 * @param outputs - 题目数组
 * @returns 校验结果数组 + 统计信息
 */
export function validateBatchItems(outputs: AgentOutput[]): {
  results: ValidationResult[]
  summary: {
    total: number
    valid: number
    invalid: number
    averageScore: number
  }
} {
  const results = outputs.map(validateItem)

  const validCount = results.filter(r => r.valid).length
  const avgScore = results.reduce((sum, r) => sum + r.score, 0) / results.length

  return {
    results,
    summary: {
      total: outputs.length,
      valid: validCount,
      invalid: outputs.length - validCount,
      averageScore: Math.round(avgScore * 10) / 10,
    },
  }
}
