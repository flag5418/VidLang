// deno-lint-ignore-file no-explicit-any
/**
 * V4 AI 出题系统 - Prompt 模板库
 *
 * 所有 Agent 的 Prompt 模板集中管理
 * 支持难度分级注入 + 变量替换
 */

import { DifficultyLevel, DIFFICULTY_PROMPTS } from '../schemas.ts'

// ─── 工具函数 ──────────────────────────────

/**
 * 构建难度指导段落
 */
export function buildDifficultySection(difficulty: DifficultyLevel): string {
  const config = DIFFICULTY_PROMPTS[difficulty]
  return `
## Learner Profile
- **Difficulty Level**: ${difficulty}
- **CEFR Equivalent**: ${config.cefr}
- **Instruction Style**: ${config.instructionStyle}

## Difficulty-Specific Guidelines
1. **Vocabulary**: ${config.vocabularyGuideline}
2. **Sentence Complexity**: ${config.sentenceGuideline}
3. **Distractor Quality**: ${config.distractorGuideline}
4. **Hint Detail Level**: ${config.hintDetail} (strong=almost give answer, weak=directional only, none=no hint)
`.trim()
}

/**
 * 安全地转义 JSON 字符串中的特殊字符
 */
export function escapeJsonString(str: string): string {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\t/g, '\\t')
}

// ─── B1: context_mcq Prompt ─────────────────

export function buildMcqPrompt(params: {
  word: string
  morphology: string
  definition: string
  sentence?: string
  synonyms?: string[]
  antonyms?: string[]
  difficulty: DifficultyLevel
}): string {
  const { word, morphology, definition, sentence, synonyms, antonyms, difficulty } = params

  const contextSection = sentence ? `
## Context Sentence
Original: "${sentence}"
The target word "${word}" has been removed. User must choose the correct form to fill the blank.
` : ''

  const synonymInfo = synonyms && synonyms.length > 0
    ? `\n- Synonyms: ${synonyms.join(', ')}`
    : ''
  const antonymInfo = antonyms && antonyms.length > 0
    ? `\n- Antonyms: ${antonyms.join(', ')}`
    : ''

  return `You are an expert English language test designer. Create a high-quality multiple-choice question.

${buildDifficultySection(difficulty)}

## Target Word
- **Word**: "${word}"
- **Part of Speech**: ${morphology}
- **Definition**: ${definition}${synonymInfo}${antonymInfo}
${contextSection}
## Requirements for Options (A/B/C/D)

**CRITICAL RULES:**

1. **Option A (CORRECT)**: Must be the exact correct form of "${word}" that fits the context (or base form if no sentence)

2. **Option B, C, D (DISTRACTORS)** - Must follow this strategy:
   - At least 1 distractor: A different form of the SAME word (tense/number/degree/comparison)
   - At least 1 distractor: A SYNONYM or same-category word with the SAME part of speech
   - At least 1 distractor: An ANTONYM or commonly confused word

3. **Quality Rules**:
   - ALL options must be grammatically valid in the blank position
   - Options should be similar in length and complexity (don't make obvious answer stand out)
   - NEVER use words from completely different parts of speech
   - NEVER include the definition meaning in the options
   - NEVER make the correct answer always Option A

## Output Format (STRICT JSON only, no markdown)

{
  "question": "Complete the sentence:"${sentence ? `\n  "sentence": "${escapeJsonString(sentence.replace(new RegExp(word, 'gi'), '_____'))}",` : ''}
  "masked_sentence": "${sentence ? escapeJsonString(sentence.replace(new RegExp(word, 'gi'), '_____')) : 'N/A'}",
  "options": ["option_A", "option_B", "option_C", "option_D"],
  "correctAnswer": "A|B|C|D",
  "hint": "A helpful hint without giving away the answer${difficulty === 'beginner' ? ' (can be more specific for beginners)' : ''}",
  "feedback": "Explanation of why the correct answer is right and why others are wrong"
}`
}

// ─── B2: meaning_choice Prompt ──────────────

export function buildMeaningPrompt(params: {
  word: string
  definition: string
  phoneticUk?: string
  phoneticUs?: string
  difficulty: DifficultyLevel
  mode: 'listen_meaning' | 'definition_choice'
}): string {
  const { word, definition, phoneticUk, phoneticUs, difficulty, mode } = params

  const isListen = mode === 'listen_meaning'

  return `You are an expert vocabulary teacher. Create a meaning-recognition question.

${buildDifficultySection(difficulty)}

## Target Word
- **Word**: "${word}"
- **Phonetic (UK)**: ${phoneticUk || 'N/A'}
- **Phonetic (US)**: ${phoneticUs || 'N/A'}
- **Chinese Definition**: ${definition}

## Task Type
${isListen
  ? '**Listening Mode**: Student will hear the pronunciation of "${word}" and must choose the correct Chinese meaning.'
  : '**Visual Mode**: Student sees the English word "${word}" and must choose the correct Chinese meaning.'
}

## Requirements for Options (A/B/C/D)

1. **Option A (CORRECT)**: The accurate Chinese translation of "${word}"

2. **Options B, C, D (DISTRACTORS)**:
   - 1 option: A plausible but INCORRECT translation (common learner mistake)
   - 1 option: Translation of a SYNONYM or related word
   - 1 option: Translation of an ANTONYM or completely unrelated word
   - All options should be natural Chinese expressions (not word-for-word translations)

3. **Quality Rules**:
   - Correct translation should be accurate and natural
   - Distractors should be believable mistakes that learners actually make
   - All options should be similar in length (2-8 Chinese characters each)
   - NEVER include the English word "${word}" in any option

## Output Format (STRICT JSON)

{
  "question": "${isListen ? '[🔊] Listen and choose the correct meaning:' : `What does "${word}" mean?`}",
  "options": ["中文释义A", "中文释义B", "中文释义C", "中文释义D"],
  "correctAnswer": "A|B|C|D",
  "hint": "提示内容",
  "feedback": "\"${word}\" 的详细解释和用法说明"
}`
}

// ─── B7: english_definition Prompt ──────────

export function buildDefinitionPrompt(params: {
  word: string
  morphology: string
  definition: string
  englishMeaning?: string
  synonyms?: string[]
  antonyms?: string[]
  category?: string
  difficulty: DifficultyLevel
}): string {
  const {
    word, morphology, definition, englishMeaning,
    synonyms, antonyms, category, difficulty
  } = params

  return `You are an expert vocabulary teacher. Create an English-definition multiple-choice question.

${buildDifficultySection(difficulty)}

## Target Word
- **Word**: "${word}"
- **Part of Speech**: ${morphology}
- **Chinese Meaning**: ${definition}
- **English Meaning (reference)**: ${englishMeaning || 'N/A'}
${synonyms ? `- **Synonyms**: ${synonyms.join(', ')}` : ''}
${antonyms ? `- **Antonyms**: ${antonyms.join(', ')}` : ''}
${category ? `- **Semantic Category**: ${category}` : ''}

## Task
Write a CLEAR English DEFINITION of "${word}". Then create 4 word options where ONLY ONE matches your definition.

## CRITICAL Rules for Definition
1. Your definition must clearly describe "${word}" to someone who knows it well
2. Your definition must NOT contain the word "${word}" itself or its variations
3. Your definition should be ${difficulty === 'beginner' ? 'simple (under 10 words)' : difficulty === 'professional' ? 'sophisticated and precise (15-25 words)' : 'clear and concise (10-18 words)'}
4. Use language appropriate for ${DIFFICULTY_PROMPTS[difficulty].cefr} level learners

## Distractor Strategy (CRITICAL for quality)
- **Option A (CORRECT)**: "${word}" itself
- **Option B**: An ANTONYM of "${word}" (same part of speech, opposite meaning)
- **Option C**: A word from a DIFFERENT semantic category but same part of speech
- **Option D**: A word that LOOKS or SOUNDS similar to "${word}" but means something different

All distractors must be REAL English words that could plausibly confuse a learner.

## Output Format (STRICT JSON)

{
  "definition": "Your English definition of '${word}' (without mentioning the word)",
  "question": "Which word means \\"[your definition here]\\"?",
  "options": ["word_A", "word_B", "word_C", "word_D"],
  "correctAnswer": "A|B|C|D",
  "hint": "Hint without giving away answer",
  "feedback": "Why the answer is correct and why distractors are wrong"
}`
}

// ─── B3: word_forms Prompt ──────────────────

export function buildFormsPrompt(params: {
  word: string
  morphology: string
  forms: Record<string, string>
  difficulty: DifficultyLevel
  formType: 'forward' | 'reverse'
}): string {
  const { word, morphology, forms, difficulty, formType } = params

  // 选择一个目标形式（排除空值）
  const availableForms = Object.entries(forms).filter(([_, v]) => v !== null && v !== undefined)
  const targetForm = availableForms.length > 0
    ? availableForms[Math.floor(Math.random() * availableForms.length)][0]
    : 'past_tense' // fallback

  if (formType === 'forward') {
    return `You are an expert English grammar teacher. Create a word-form transformation question.

${buildDifficultySection(difficulty)}

## Target Word
- **Word**: "${word}"
- **Part of Speech**: ${morphology}
- **Available Forms**: ${JSON.stringify(forms)}

## Task
Ask the student to choose the CORRECT form of "${word}" for a specific grammatical transformation.

Target form to test: **${targetForm.replace(/_/g, ' ')}**

## Requirements
1. Question should clearly state what form is needed (e.g., "Choose the past tense form:")
2. Option A: CORRECT form (${forms[targetForm] || '[correct form]'})
3. Options B, C, D: Other forms from the list above (wrong answers)
4. All options must be real grammatical forms of "${word}" (no made-up words)
5. If "${word}" is irregular, mention it in the feedback

## Output Format (STRICT JSON)

{
  "question": "Choose the correct ${targetForm.replace(/_/g, ' ')} form of '${word}':",
  "options": ["form_A", "form_B", "form_C", "form_D"],
  "correctAnswer": "A|B|C|D",
  "target_form": "${targetForm}",
  "all_forms": ${JSON.stringify(forms)},
  "hint": "Hint about this grammatical rule",
  "feedback": "Explanation of this transformation"
}`
  } else {
    // Reverse: give a form, ask for the base word
    const selectedForm = availableForms.length > 0
      ? availableForms[Math.floor(Math.random() * availableForms.length)][1]
      : word
    const formName = availableForms.find(([_, v]) => v === selectedForm)?.[0] || 'unknown'

    return `You are an expert English grammar teacher. Create a reverse word-form identification question.

${buildDifficultySection(difficulty)}

## Given Information
- **Word Form**: "${selectedForm}"
- **This is the**: ${formName.replace(/_/g, ' ')} form

## Task
Student sees the word form "${selectedForm}" and must identify which BASE WORD it comes from.

## Requirements
1. Question: "Which word has '${selectedForm}' as its ${formName.replace(/_/g, ' ')}?"
2. Option A: CORRECT base word ("${word}")
3. Options B, C, D: Other English words that could plausibly have similar forms
4. Distractors should be words with similar patterns (e.g., same ending, same part of speech)

## Output Format (STRICT JSON)

{
  "question": "Which word has '${selectedForm}' as its ${formName.replace(/_/g, ' ')}?",
  "options": ["base_word_A", "base_word_B", "base_word_C", "base_word_D"],
  "correctAnswer": "A|B|C|D",
  "target_form": "${formName}",
  "all_forms": ${JSON.stringify(forms)},
  "hint": "Think about verb/noun/adjective patterns",
  "feedback": "Explanation of the relationship between '${word}' and '${selectedForm}'"
}`
  }
}

// ─── B8: reading_comprehension Prompt ───────

export function buildReadingPrompt(params: {
  passage: string
  translation?: string
  difficulty: DifficultyLevel
  skillType: 'main_idea' | 'detail' | 'inference' | 'vocab_in_context'
  targetWord?: string              // For vocab_in_context type
}): string {
  const { passage, translation, difficulty, skillType, targetWord } = params

  const skillInstructions: Record<string, string> = {
    main_idea: `**Main Idea Question**: Ask about the central theme or main point of the passage.
- Correct answer: Accurate summary of the main idea
- Distractors: Too broad, too specific (only one detail), or completely off-topic`,
    detail: `**Detail Question**: Ask about a specific fact mentioned in the passage.
- Correct answer: EXPLICITLY stated in the text
- Distractors: Other facts from the text (but not the answer), information not mentioned, or contradiction of the text`,
    inference: `**Inference Question**: Ask what can be logically inferred from the passage.
- Correct answer: Reasonable conclusion based on text evidence (NOT explicitly stated)
- Distractors: Over-generalization, direct quote (not inference), or contradicts the text`,
    vocab_in_context: `**Vocabulary-in-Context Question**: Ask about the meaning of a specific word in this context.
- Target word: "**${targetWord || '[TARGET_WORD]'}**" (highlighted in passage)
- Correct answer: The meaning of this word IN THIS SPECIFIC CONTEXT
- Distractors: Common meaning of the word (but not this context), similar-looking words, completely wrong meanings`,
  }

  return `You are an expert English reading comprehension test designer.

${buildDifficultySection(difficulty)}

## Input Material (Passage)
"""
${passage}
"""
${translation ? `\n**Chinese Translation (for reference only, do not show to student)**:\n${translation}` : ''}

## Question Type
${skillInstructions[skillType] || skillInstructions.detail}

## Requirements
1. Question must be answerable SOLELY based on the passage above
2. All options must be complete sentences (not fragments)
3. Correct answer must be unequivocally supported by the text
4. Distractors must be plausible but incorrect based on the text
5. Language level matches ${DIFFICULTY_PROMPTS[difficulty].cefr}

## Output Format (STRICT JSON)

{
  "question": "Your question here",
  "options": ["option_A", "option_B", "option_C", "option_D"],
  "correctAnswer": "A|B|C|D",
  "skill_type": "${skillType}",
  "hint": "Hint for finding the answer${skillType === 'detail' ? ': Look for specific details in the text' : skillType === 'inference' ? ': Think about what the author implies, not states' : ''}",
  "feedback": "Explanation with evidence from the passage"${skillType === 'detail' ? ',\n  "evidence": "Direct quote or paraphrase from text that supports the answer"' : ''}
}`
}
