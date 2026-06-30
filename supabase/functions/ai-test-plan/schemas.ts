// deno-lint-ignore-file no-explicit-any
/**
 * V4 AI 出题系统 - 统一输出 Schema
 *
 * 所有 Agent 的输出必须符合这些接口定义
 * 用于 TypeScript 类型检查 + 运行时校验（Quality Gate）
 */

// ─── 通用类型 ──────────────────────────────

/** 难度等级 */
export type DifficultyLevel = 'beginner' | 'elementary' | 'intermediate' | 'advanced' | 'professional'

/** CEFR 等级 */
export type CefrLevel = 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2'

/** 选项标签 */
export type OptionLabel = 'A' | 'B' | 'C' | 'D'

/** 技能类型（用于阅读/听力理解） */
export type SkillType =
  | 'main_idea'       // 主旨大意
  | 'detail'          // 细节理解
  | 'inference'       // 推理判断
  | 'vocab_in_context' // 语境词义

// ─── Agent 输入类型 ──────────────────────────

/** 单词缓存数据（从 word_cache 获取） */
export interface WordCacheData {
  word: string
  definitions: Array<{
    part_of_speech: string
    chinese_meaning: string
    english_meaning?: string
    examples?: Array<{ english: string; chinese: string }>
  }>
  difficulty?: string           // primary/juniorHigh/seniorHigh/cet4/cet6/postgraduate/ielts/toefl/gre
  morphology?: Record<string, any>
  synonyms?: string[]
  antonyms?: string[]
  category?: string             // emotion/action/size/...
  phonetic_uk?: string
  phonetic_us?: string
  standalone_examples?: Array<{ english: string; chinese: string }>
}

/** MCQ Agent 输入 */
export interface McqAgentInput {
  word: string
  cacheData: WordCacheData
  sentence?: string              // 语境句子（可选）
  difficulty: DifficultyLevel
}

/** Meaning Agent 输入 */
export interface MeaningAgentInput {
  word: string
  cacheData: WordCacheData
  difficulty: DifficultyLevel
  mode: 'listen_meaning' | 'definition_choice'  // 听音选义 / 看词选义
}

/** Definition Agent 输入 */
export interface DefinitionAgentInput {
  word: string
  cacheData: WordCacheData
  difficulty: DifficultyLevel
}

/** Forms Agent 输入 */
export interface FormsAgentInput {
  word: string
  cacheData: WordCacheData
  difficulty: DifficultyLevel
  formType: 'forward' | 'reverse'  // 正向（给词选形）/ 反向（给形选词）
}

/** Reading Agent 输入 */
export interface ReadingAgentInput {
  passage: string                  // 文章/段落文本
  translation?: string            // 中文翻译（可选）
  sentences?: Array<{             // 句子级数据（可选）
    english: string
    chinese?: string
  }>
  difficulty: DifficultyLevel
  questionCount?: number          // 生成题目数量（默认 3）
}

/** Listening Agent 输入 */
export interface ListeningAgentInput {
  transcript: string              // 音频转写文本
  translation?: string            // 中文翻译（可选）
  difficulty: DifficultyLevel
  questionCount?: number
}

// ─── Agent 输出类型 ──────────────────────────

/** B1: 语境选择题输出 */
export interface McqAgentOutput {
  type: 'context_mcq'
  word: string
  question: string                // 题目文本（如 "Complete the sentence:"）
  sentence: string                // 原始完整句子
  maskedSentence: string          // 挖空后的句子
  options: string[]               // [optionA, optionB, optionC, optionD]
  correctAnswer: OptionLabel      // 'A' | 'B' | 'C' | 'D'
  answerText: string              // 正确答案的实际文本
  difficulty: DifficultyLevel
  hint?: string                   // 提示（可选）
  feedback?: string               // 解析（可选）
  metadata?: {
    morphology: string            // 目标词的词性
    distractorTypes: string[]     // 干扰项类型说明 ['same_word_form', 'synonym', 'antonym']
  }
}

/** B2: 释义选择题输出 */
export interface MeaningAgentOutput {
  type: 'meaning_choice'
  word: string
  mode: 'listen_meaning' | 'definition_choice'
  question: string                // "What does 'happy' mean?" 或 "[音频图标] 选择正确的中文释义"
  options: string[]               // 中文释义选项
  correctAnswer: OptionLabel
  answerText: string              // 正确的中文释义
  difficulty: DifficultyLevel
  hint?: string
  feedback?: string
  phoneticUk?: string
  phoneticUs?: string
}

/** B7: 英文释义理解题输出 */
export interface DefinitionAgentOutput {
  type: 'english_definition'
  word: string
  definition: string              // AI 生成的英文释义（不包含目标词）
  question: string                // "Which word means '...'"
  options: string[]               // [wordA, wordB, wordC, wordD]
  correctAnswer: OptionLabel
  answerText: string              // 正确单词
  difficulty: DifficultyLevel
  hint?: string
  feedback?: string
  distractorMetadata?: {
    antonym?: string              // 反义词干扰
    differentCategory?: string    // 不同类别干扰
    similarSound?: string         // 近音/近形干扰
  }
}

/** B3: 词形变化题输出 */
export interface FormsAgentOutput {
  type: 'word_forms'
  word: string
  formType: 'forward' | 'reverse'
  question: string                // "Choose the correct third person singular form of 'do':"
  options: string[]               // [does, did, doing, done]
  correctAnswer: OptionLabel
  answerText: string              // 正确形式
  targetForm: string              // 目标变形名称（如 "third_person_singular"）
  difficulty: DifficultyLevel
  hint?: string
  feedback?: string
  allForms?: Record<string, string> // 完整词形变化表（用于解析展示）
}

/** B8: 阅读理解题输出 */
export interface ReadingAgentOutput {
  type: 'reading_comprehension'
  passage: string                 // 原文段落
  skillType: SkillType
  question: string
  options: string[]
  correctAnswer: OptionLabel
  answerText: string
  difficulty: DifficultyLevel
  hint?: string
  feedback?: string
  evidence?: string               // 原文依据（用于 detail 题）
}

/** 联合输出类型 */
export type AgentOutput =
  | McqAgentOutput
  | MeaningAgentOutput
  | DefinitionAgentOutput
  | FormsAgentOutput
  | ReadingAgentOutput

// ─── Quality Gate 校验结果 ───────────────────

export interface ValidationResult {
  valid: boolean
  errors: string[]                // 错误列表（任意一个则无效）
  warnings: string[]              // 警告列表（不阻止但记录）
  score: number                   // 质量评分 (0-100)
}

// ─── 难度映射工具 ───────────────────────────

/** 用户难度 → CEFR 映射 */
export const DIFFICULTY_TO_CEFR: Record<DifficultyLevel, CefrLevel> = {
  beginner: 'A1',
  elementary: 'A2',
  intermediate: 'B1',
  advanced: 'C1',
  professional: 'C2',
}

/** 用户难度 → Prompt 指导语映射 */
export const DIFFICULTY_PROMPTS: Record<DifficultyLevel, {
  cefr: string
  instructionStyle: string
  vocabularyGuideline: string
  sentenceGuideline: string
  distractorGuideline: string
  hintDetail: 'strong' | 'medium' | 'weak' | 'none'
}> = {
  beginner: {
    cefr: 'A1 (Beginner)',
    instructionStyle: 'Use very simple words and short sentences. For absolute beginners.',
    vocabularyGuideline: 'Use only high-frequency basic words (CEFR A1). Avoid phrasal verbs, idioms, or academic terms.',
    sentenceGuideline: 'Use simple SVO (Subject-Verb-Object) sentences. Maximum 10 words per sentence.',
    distractorGuideline: 'Distractors should be OBVIOUSLY wrong to beginners. Use words from completely different semantic categories.',
    hintDetail: 'strong',
  },
  elementary: {
    cefr: 'A2 (Elementary)',
    instructionStyle: 'Use common daily vocabulary. For learners with basic English foundation.',
    vocabularyGuideline: 'Use common daily vocabulary (CEFR A2). Simple phrasal verbs are okay.',
    sentenceGuideline: 'Use compound sentences with "and/but". Maximum 15 words per sentence.',
    distractorGuideline: 'Distractors should have clear differences from the answer. Include 1-2 plausible but wrong options.',
    hintDetail: 'medium',
  },
  intermediate: {
    cefr: 'B1-B2 (Intermediate)',
    instructionStyle: 'Use standard vocabulary. For intermediate learners preparing for exams like CET-4/6.',
    vocabularyGuideline: 'Use standard vocabulary (CEFR B1-B2). Academic words are acceptable if common.',
    sentenceGuideline: 'Use complex sentences with subordinate clauses. Maximum 20 words per sentence.',
    distractorGuideline: 'Distractors require understanding context to distinguish. Include synonyms, antonyms, and commonly confused words.',
    hintDetail: 'weak',
  },
  advanced: {
    cefr: 'C1 (Advanced)',
    instructionStyle: 'Use nuanced, sophisticated language. For advanced learners preparing for IELTS/TOEFL.',
    vocabularyGuideline: 'Use sophisticated vocabulary (CEFR C1). Academic and domain-specific terms are expected.',
    sentenceGuideline: 'Use complex nested clauses. Maximum 25 words per sentence.',
    distractorGuideline: 'Distractors require fine-grained semantic distinction. Near-synonyms with subtle meaning differences.',
    hintDetail: 'weak',
  },
  professional: {
    cefr: 'C2 (Professional)',
    instructionStyle: 'Use academic/professional register. For expert-level learners or GRE preparation.',
    vocabularyGuideline: 'Use academic/professional vocabulary (CEFR C2). Specialized terminology is appropriate.',
    sentenceGuideline: 'Use academic long complex sentences. No strict length limit.',
    distractorGuideline: 'Distractors test abstract concept discrimination. Require deep understanding of nuance and context.',
    hintDetail: 'none',
  },
}
