# AI 出题系统 V4 重设计方案

> **日期**: 2026-06-29
> **状态**: 📝 设计方案（待用户确认后实施）
> **触发原因**: 用户要求彻底删除手动映射表，改用 AI + 全局单词表驱动出题；参考 wordpecker-app 的优秀实践

---

## 一、wordpecker-app 分析总结

### 1.1 核心架构差异

| 维度 | wordpecker-app | 当前 VidLang (v3) |
|------|---------------|-------------------|
| **出题引擎** | OpenAI Agents SDK（真正的 AI 生成） | 硬编码函数模板拼接 |
| **题目生成方式** | LLM 根据单词+释义+上下文**实时生成**题目和干扰项 | 从固定词池随机取词做干扰项 |
| **题型数量** | 5 种（multiple_choice, fill_blank, true_false, sentence_completion, matching）| 12 种（但多数质量差）|
| **单词数据** | 极简：`{ value, meaning }` + context | 复杂但无用：WORD_MEANING_MAP(70词), WORD_RELATIONS(20词) |
| **干扰项策略** | **AI 根据语义生成合理的干扰项** | 随机从 wordPool 取（无语义约束）|
| **Prompt 设计** | 详细的 system prompt + 结构化 schema 输出 | 简单的字符串模板 |
| **额外能力** | hint（提示）、feedback（解析）、difficulty 分级 | 无 |

### 1.2 wordpecker-app 的关键优势

#### ① AI 实时生成题目（核心差异）

wordpecker-app 的出题流程：
```
用户单词列表 [{id, value, meaning}, ...]
  ↓ 传入 exercise-agent
  ↓ prompt: "Create quiz questions for these vocabulary words: \n{word}: {meaning}\n..."
  ↓ LLM (GPT-4) 实时生成
  ↓ Zod schema 校验输出
返回: [{ type, word, question, options, correctAnswer, difficulty, hint, feedback }, ...]
```

**关键点**：
- 每道题的**题目文本、选项、干扰项全部由 AI 根据该单词的语义实时生成**
- 不是从预设池子里随机取
- AI 会根据单词的词性、释义、用法来设计**语义合理**的干扰项
- 每道题自带 `hint`（提示）和 `feedback`（答案解析）

#### ② 5 种题型定义清晰

| 类型 | 说明 | 示例 |
|------|------|------|
| **multiple_choice** | 给出释义/描述，4 选 1 单词 | "Which word means 'showing kindness'?" → A. benevolent B. malevolent C. hostile D. indifferent |
| **fill_blank** | 句子挖空，填入正确单词（无选项，需拼写） | "His _____ nature made everyone trust him." → 答案: benevolent |
| **sentence_completion** | 句子挖空，4 选 1 填空（类似我们的 MCQ 但由 AI 生成高质量选项） | "The _____ scientist won the Nobel Prize." → [dedicated, reluctant, arrogant, lazy] |
| **true_false** | 判断关于该单词用法的陈述对错 | "Benevolent means having evil intentions." → False |
| **matching** | 词义配对（3-4 对） | [{benevolent: 善良的}, {malevolent: 恶意的}, ...] |

#### ③ Agent 化架构

wordpecker-app 有 **8 个独立 Agent**，各司其职：

| Agent | 职责 |
|-------|------|
| **vocabulary-agent** | 根据上下文发现/推荐新单词 |
| **definition-agent** | 生成单词释义（支持 context-aware）|
| **examples-agent** | 生成例句 |
| **similar-words-agent** | 找同义词、近义词、可替换词（含 usage_note 区分细微差别）|
| **exercise-agent** | 生成练习题（学习模式，偏简单）|
| **quiz-agent** | 生成测试题（考试模式，偏难）|
| **image-analysis-agent** | 图片描述分析 |
| **language-validation-agent** | 语言校验 |

每个 Agent = **专门的 prompt.md + Zod schema + OpenAI Agent 实例**

### 1.3 wordpecker-app 的局限（我们可超越的）

| 局限 | 说明 | 我们的应对 |
|------|------|-----------|
| 每次 5 个词调用一次 API | 成本较高 | 我们可以批量处理 + 缓存 |
| 无跟读/发音功能 | 纯文字练习 | 我们已有声通 TTS + 跟读评分 |
| 无字幕/视频关联 | 只基于单词列表 | 我们有视频字幕作为上下文 |
| 单用户无认证 | 简化版 | 我们有完整用户体系 |

---

## 二、V4 重设计方案：AI 驱动 + 词性感知

### 2.1 核心原则变更

```
❌ V3 方式：硬编码模板 + 手动映射表（WORD_MEANING_MAP 70词 / WORD_RELATIONS 20词）
✅ V4 方式：AI 实时生成 + 全局 word_cache 表驱动 + 词性感知
```

**必须删除的**：
- ~~`WORD_MEANING_MAP`~~ — 删除，改用 `word_cache.definitions[0]`
- ~~`WORD_RELATIONS`~~ — 删除，改用 AI 实时查询或 `word_cache` 扩展字段
- ~~`mockTranslate()`~~ — 删除，改用 AI 翻译
- 所有同步版本的题型生成器（`pickXxxItems` 不带 WithCache 后缀的）

**必须保留/增强的**：
- ✅ 全局质量门 `validateItem()` — 保留并增强
- ✅ `word_cache` 三级缓存体系 — 作为 AI 出题的数据基础
- ✅ 跟读类题型（word_pron / phrase_pron / sentence_pron）— 这些不涉及语义，保留原逻辑
- ✅ 组句题 reorder — 纯排序，不涉及语义，保留原逻辑
- ✅ 拼写题 spelling — 字母池机制合理，保留但增强句子来源

### 2.2 新架构：基于 word_cache 的词性驱动出题

#### word_cache 表需要扩展的字段

当前 `word_cache.result` 结构：
```json
{
  "definitions": ["快乐的；高兴的"],
  "phonetic": "/ˈhæpi/",
  "morphology": "adjective",
  "examples": [...]
}
```

**建议扩展为**：
```json
{
  "definitions": ["快乐的；高兴的", "令人愉快的"],
  "phonetic": "/ˈhæpi/",
  "morphology": "adjective",           // ← 已有，核心字段
  "examples": [
    { "en": "I'm so happy to see you!", "zh": "我很高兴见到你！" }
  ],
  // ═══ V4 新增字段 ═══
  "forms": {                            // 词形变化
    "comparative": "happier",           // 比较级
    "superlative": "happiest",          // 最高级
    "adverb": "happily",               // 副词形式
    "noun": "happiness",              // 名词形式
    "antonym": "sad/unhappy"           // 反义词（可以是多个）
  },
  "synonyms": ["glad", "joyful", "cheerful", "delighted"],  // 同义词
  "category": "emotion",                // 语义类别
  "difficulty": "juniorHigh"            // 难度等级
}
```

> **注意**: 这些扩展字段可以通过已有的 `qwen-chat.ts` definition prompt 一次性获取，不需要额外的 API 调用。

### 2.3 V4 题型重新设计（12 → 8 种精简+增强）

根据你的思路和 wordpecker-app 的参考，重新规划题型：

---

#### 类型 A：纯机械型（不依赖 AI 语义，保留现有逻辑）

| # | 题型 | 说明 | 改动 |
|---|------|------|------|
| A1 | **reorder 组句题** | 打乱单词顺序组句 | 不变 |
| A2 | **spelling 拼写填空** | 字母池拼写挖空单词 | 不变 |
| A3 | **word_pron 单词跟读** | TTS + 录音评分 | 不变 |
| A4 | **phrase_pron 短语跟读** | TTS + 录音评分 | 不变 |
| A5 | **sentence_pron 句子跟读** | TTS + 录音评分 | 不变 |

---

#### 类型 B：AI 语义驱动型（完全重写）

##### B1: `context_mcq` 语境选择题（替代旧 mcq + definition_choice）

**这是你提到的核心需求**：挖空短句中的单词，让用户选择正确的单词填入。

**v3 的问题**：干扰项从 wordPool 随机取，可能词性完全不同。
**v4 的方案**：

```
目标词: "do" (动词)
句子: "She _____ her homework every evening."
↓ AI 生成选项（同词性 + 同变形空间）
A. does      ← 正确（第三人称单数）
B. did       ← 干扰（过去式，同一动词的不同时态）
C. doing     ← 干扰（现在分词）
D. done      ← 干扰（过去分词）
```

**或者更广语义的干扰**：

```
目标词: "happy" (形容词)
句子: "The _____ child smiled at everyone."
A. happy        ← 正确
B. cheerful     ← 干扰（同义词形容词）
C. unhappy     ← 干扰（反义词形容词）
D. happiness   ← 干扰（名词形式，测试词性辨析）
```

**实现方式**：调用 AI Agent，传入 `{ word, morphology, sentence, definitions }`，让 AI 生成 4 个语义合理的选项。

**Prompt 要点**（参考 wordpecker-app exercise-agent）：
```
You are generating a vocabulary multiple-choice question.
Target word: "{word}" ({morphology})
Definition: {definition}
Context sentence: "{sentence}"

Generate 4 options (A/B/C/D):
- Option A must be the CORRECT form of the target word that fits the sentence
- Options B/C/D must be PLAUSIBLE distractors that:
  * Share the same part of speech (morphology) as the target
  * Could confuse a learner who doesn't fully understand the word
  * Include at least one: same-word different form / synonym / antonym / same-category word
- All options must be grammatically possible in the sentence position
```

---

##### B2: `meaning_choice` 释义选择题（替代旧 listen_meaning + definition_choice en_to_cn）

**含义**：给出单词（或播放发音），选择正确的中文释义。

**v4 方案**：
- 正确答案：来自 `word_cache.definitions[0]`
- 干扰项：来自 AI 根据**同类别/易混淆词**生成的错误释义
- 或者：从 word_cache 中其他**相同 morphology** 的词取释义作为干扰

**两种子类型**：
- **听音选义** (`listen_meaning`)：播放 TTS → 选中文释义
- **看词选义** (`definition_choice`)：看英文词 → 选中文释义

---

##### B3: `word_forms` 词形变化题（全新题型）

**这就是你提到的**："本来是 do 这个单词，但我们可以将不同进行时放进去"

**实现**：

```
题目: 选择 "do" 的正确第三人称单数现在时形式
A. does       ← 正确
B. did        ← 过去式
C. doing      ← 现在分词
D. done       ← 过去分词
```

**数据来源**：`word_cache.result.forms`（扩展字段）
**如果 forms 为空**：跳过此题型或调用 AI 补充

**变体 — 反向词形**：
```
题目: 以下哪个是 "happy" 的副词形式？
A. happily     ← 正确
B. happier     ← 比较级
C. happiness   ← 名词
D. unhappy     ← 反义词
```

---

##### B4: `semantic_relation` 语义关系题（替代旧 word_relation）

**替代原来只有 20 个词的 WORD_RELATIONS**。

**实现方式**：AI 实时生成

```
输入: target_word = "happy", morphology = "adjective"
↓ AI 查询/生成
输出:
  synonyms: ["glad", "joyful", "cheerful"]
  antonyms: ["sad", "unhappy", "miserable"]
  category_words: ["angry", "excited", "nervous"]  // 同类（emotion）
↓ 生成题目
题目: 选择 "happy" 的同义词（可多选）
A. glad ✓       B. sad       C. joyful ✓      D. quickly
E. cheerful ✓   F. happy     G. excited       H. computer
答案: A, C, E
```

**关键改进**：不再依赖预定义表，任何有 word_cache 记录的词都可以出此题。

---

##### B5: `listening_comprehension` 听力理解题（替代旧 listen_reply）

**重写**：不再用简单的关键词→中文释义映射。

**v4 方案（借鉴 wordpecker-app 的 sentence_completion + AI 生成）**：

```
播放音频: "What time does the movie start?"
↓ AI 根据音频内容生成题目和选项
题目 (显示): "___"
选项:
A. At 7 o'clock.      ← 正确（AI 根据语境生成合理回答）
B. At the cinema.     ← 干扰（答非所问但相关）
C. It's a comedy.     ← 干扰（描述电影类型）
D. With my friends.   ← 干扰（描述陪伴对象）
```

**或者更简单的版本**（适合当前架构）：
- 使用字幕中的疑问句
- AI 生成 4 个**语义合理**的回答选项（而非随机取词的中文释义）

---

##### B6: `translation_match` 英义互译题（替代旧 translate_meaning）

**删除 mockTranslate()**，改用 AI 翻译。

**实现**：
- 输入英文句子 → 调用 qwen-chat 翻译接口获取准确翻译
- 干扰翻译：AI 对同一句子做**略微偏离**的翻译（常见错误类型）
- 或：取其他句子的翻译作为干扰

**降级策略**：如果 AI 翻译不可用，跳过此题型（不再用逐词拼接的假翻译充数）。

---

##### B7: `english_definition` 英文释义理解题（全新，参考 wordpecker-app）

**就是你提到的**："用英文描述这个单词的含义，让客户进行选择"

**这是 wordpecker-app 的 multiple_choice 类型的核心**：

```
题目: Which word means "showing kindness and goodwill toward others"?
A. benevolent   ← 正确
B. malevolent   ← 反义词干扰
C. indifferent   ← 无关词干扰
D. boisterous    ← 近音/近形干扰
```

**为什么这种题有价值**：
- 测试的是**深度理解**而非机械记忆
- 干扰项需要 AI 精心设计（反义词、无关词、近形词）
- 适合中高级学习者

**数据来源**：`word_cache.definitions` 中的英文释义（如果有的话），或 AI 实时生成。

**根据词性找不相关单词的逻辑**：
```
目标词: "happy" (adjective, emotion 类)
干扰策略:
1. 反义词: "sad" (adjective, emotion) — 同类但意思相反
2. 不同类别形容词: "rapid" (adjective, speed) — 同词性不同义
3. 不同词性: "happiness" (noun) — 同根不同词性
4. 完全无关: "computer" (noun, object) — 不同词性不同义
```

---

### 2.4 V4 出题架构图

```
┌─────────────────────────────────────────────────────┐
│                   用户请求                           │
│  { source_type, video_code/folder_code, config }    │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              素材收集阶段                             │
│  • 字幕句子 (sentences)                              │
│  • wordPool (从句子提取的去重单词列表)                 │
│  • 对 wordPool 中每个词查询 word_cache               │
│    → 获取 definitions, morphology, forms, synonyms  │
│    → 未命中的词标记为 "no_cache"                     │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              分类分发阶段                             │
│                                                      │
│  ┌─ 机械型 ──────────────────────────────────┐      │
│  │ reorder / spelling / *_pron               │      │
│  │ → 直接用现有逻辑，无需 AI                  │      │
│  └───────────────────────────────────────────┘      │
│                                                      │
│  ┌─ AI 语义型 ───────────────────────────────┐      │
│  │                                             │      │
│  │  有 word_cache 的词:                        │      │
│  │  → 用缓存数据 (definitions/morphology/forms)│      │
│  │  → 局部调用 AI 生成高质量选项               │      │
│  │                                             │      │
│  │  无 word_cache 的词:                        │      │
│  │  → 跳过（不出语义相关的题）                  │      │
│  │  → 或：先异步触发 word_cache prefill        │      │
│  │                                             │      │
│  └───────────────────────────────────────────┘      │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              质量门阶段 (validateItem v4)             │
│  • 继承 v3 的 R1~R6 规则                             │
│  • 新增 R7: AI 生成的选项必须 ≥ 3 个有效值            │
│  • 新增 R8: 选项之间不能完全相同（编辑距离 > 1）      │
│  • 新增 R9: 英文释义题的选项不能包含目标词本身        │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              返回给客户端                            │
│  { plan: { items: [...] }, billing: {...} }         │
└─────────────────────────────────────────────────────┘
```

### 2.5 AI Agent 设计（参考 wordpecker-app）

建议在 Edge Function 内创建以下 Agent 函数：

```
supabase/functions/ai-test-plan/
  ├── index.ts                    # 主入口 + 质量门 + 机械型题型
  ├── cache-helpers.ts            # word_cache 查询工具
  ├── agents/                      # ★ 新增：AI 语义出题 Agent
  │   ├── prompt-templates.ts     # 各类题型的 Prompt 模板
  │   ├── mcq-agent.ts            # B1 语境选择题 Agent
  │   ├── meaning-agent.ts        # B2 释义选择题 Agent
  │   ├── forms-agent.ts          # B3 词形变化题 Agent
  │   ├── relation-agent.ts       # B4 语义关系题 Agent
  │   ├── listening-agent.ts      # B5 听力理解题 Agent
  │   ├── translation-agent.ts    # B6 英义互译题 Agent
  │   └── definition-agent.ts     # B7 英文释义理解题 Agent
  └── schemas.ts                  # 各类题型的输出 Schema
```

**每个 Agent 的统一结构**（参考 wordpecker-app）：
```typescript
// 以 mcq-agent.ts 为例
interface McqAgentInput {
  word: string
  morphology: string        // 词性
  definition: string        // 中文释义
  sentence?: string          // 语境句子（可选）
  forms?: Record<string, string>  // 词形变化
  synonyms?: string[]        // 同义词
}

interface McqAgentOutput {
  type: 'context_mcq'
  question: string           // 题目文本
  sentence: string           // 原始句子（如有）
  masked: string             // 挖空后的句子
  options: string[]          // [A, B, C, D]
  optionLabels: string[]     // ['A', 'B', 'C', 'D']
  correctAnswer: string      // 'A'/'B'/'C'/'D'
  answer: string             // 正确答案的实际文本
  difficulty: 'easy'|'medium'|'hard'
  hint: string|null          // 提示
  feedback: string|null      // 解析
}
```

### 2.6 Prompt 模板设计要点（初稿）

#### B1 context_mcq Prompt:

```markdown
You are an expert English language test designer. Create a high-quality multiple-choice question.

## Target Word
Word: {{word}}
Part of Speech: {{morphology}}
Definition: {{definition}}

{% if sentence %}
## Context Sentence
"{{sentence}}"
The target word "{{word}}" has been removed from this sentence. The user must choose the correct form to fill the blank.
{% endif %}

## Requirements for Options (A/B/C/D)
1. One option MUST be the correct answer (the right form of "{{word}}" for this context)
2. The other 3 options must be PLAUSIBLE distractors following these rules:
   - At least 1 distractor: a different form of the SAME word (tense/number/degree/etc.)
   - At least 1 distractor: a SYNONYM or same-category word with the SAME part of speech
   - At least 1 distractor: an ANTONYM or a word learners often confuse with "{{word}}"
3. ALL options must be grammatically valid in the blank position
4. Options should be similar in length and complexity (don't make the obvious answer stand out)
5. NEVER use words from completely different parts of speech as distractors

## Output Format (JSON)
{
  "question": "Complete the sentence:",
  "sentence": "{{masked_sentence}}",
  "options": ["option_A", "option_B", "option_C", "option_D"],
  "correctAnswer": "A|B|C|D",
  "hint": "A helpful hint without giving away the answer",
  "feedback": "Explanation of why the correct answer is right"
}
```

#### B7 english_definition Prompt:

```markdown
You are an expert vocabulary teacher. Create a definition-based multiple-choice question.

## Target Word
Word: {{word}}
Part of Speech: {{morphology}}
Definition: {{definition}}
Synonyms: {{synonyms}}

## Task
Write a clear English DEFINITION of "{{word}}". Then create 4 word options where only ONE matches your definition.

## Distractor Strategy (CRITICAL - this determines question quality)
- Option A (Correct): {{word}} itself
- Option B: An ANONYM of {{word}} (same part of speech, opposite meaning)
- Option C: A word from a DIFFERENT semantic category but same part of speech
- Option D: A word that LOOKS or SOUNDS similar to {{word}} but means something different

## Rules
- Your definition should be clear enough that someone who knows {{word}} will pick it
- Your definition should NOT contain the word {{word}} itself
- Distractors must be real English words that could plausibly confuse a learner
```

---

## 三、实施路径建议

### Phase 1: 清理（立即做）
1. 删除 `WORD_MEANING_MAP`（~70 行）
2. 删除 `WORD_RELATIONS`（~25 行）
3. 删除 `mockTranslate()` 函数
4. 删除所有同步版本的 `pickXxxItems` 函数（不带 WithCache 后缀的）
5. 保留：reorder, spelling, *_pron, validateItem, quality gate

### Phase 2: word_cache 扩展（并行）
1. 修改 `qwen-chat.ts` definition prompt，让它同时返回 forms/synonyms/category
2. 修改 `word_cache` 表的 result JSON 结构（向后兼容）
3. 编写 migration 脚本，对已有记录补充新字段
4. 执行 prefill 填充高频词的新字段

### Phase 3: Agent 开发（核心工作）
按优先级开发 7 个 Agent：
1. **mcq-agent** (B1) — 最高优先，替代最常用的 MCQ
2. **meaning-agent** (B2) — 替代 listen_meaning / definition_choice
3. **definition-agent** (B7) — 英文释义题，差异化功能
4. **forms-agent** (B3) — 词形变化题
5. **relation-agent** (B4) — 替代 word_relation
6. **listening-agent** (B5) — 替代 listen_reply
7. **translation-agent** (B6) — 替代 translate_meaning

### Phase 4: 集成与测试
1. 将 Agent 接入主入口 `index.ts`
2. 增强 `validateItem` 增加 R7/R8/R9 规则
3. 端到端测试每种题型
4. 性能优化（批量调用 / 缓存 AI 结果）

---

## 四、待决策事项

### Q1: AI 调用策略 — 实时 vs 预生成

| 方案 | 优点 | 缺点 | 成本 |
|------|------|------|------|
| **A: 实时生成** | 每次题目新鲜、高度个性化 | 出题延迟高（每题 1-3 秒）| 高 |
| **B: 预生成 + 缓存** | 出题快、成本可控 | 题目可能重复 | 中 |
| **C: 混合模式** | 常用词缓存 + 冷门词实时 | 实现复杂 | 中低 |

**我的建议**: 方案 C。对 word_cache 中已有完整数据的词使用预先生成的模板（类似 wordpecker-app），对缺失数据的词跳过或实时补查。

### Q2: 每个 Agent 是否独立调用 AI？

wordpecker-app 是一次性把 5 个词传给一个 Agent，批量生成所有题目。

我们可以：
- **方案 A**: 每个词单独调用对应 Agent（更精确但更多次调用）
- **方案 B**: 按题型批量调用（如一次传入 10 个词，生成 10 道 MCQ 题）

**我的建议**: 方案 B，批量调用减少延迟和成本。

### Q3: 是否引入 OpenAI Agents SDK？

wordpecker-app 使用了 `@openai/agents` SDK（基于 GPT-4）。我们有以下选择：
- **A**: 继续用现有的 qwen-chat（通义千问）— 零迁移成本
- **B**: 新增 DeepSeek/GPT 支持 — 更好的英文理解能力
- **C**: 出题专门用 GPT-4，其他功能继续用 Qwen

**我的建议**: 先用 Qwen 测试效果，如果英文题目质量不够再切换到 GPT-4 / DeepSeek。

---

## 五、文件变更预览

| 文件 | 操作 | 说明 |
|------|------|------|
| `index.ts` | **大改** | 删除映射表/旧函数，接入 Agent，保留机械型题型 |
| `cache-helpers.ts` | **重写** | 改为 word_cache 数据提取 + Agent 调用封装 |
| `agents/prompt-templates.ts` | **新建** | 所有题型的 Prompt 模板 |
| `agents/mcq-agent.ts` | **新建** | B1 语境选择题 |
| `agents/meaning-agent.ts` | **新建** | B2 释义选择题 |
| `agents/forms-agent.ts` | **新建** | B3 词形变化题 |
| `agents/relation-agent.ts` | **新建** | B4 语义关系题 |
| `agents/listening-agent.ts` | **新建** | B5 听力理解题 |
| `agents/translation-agent.ts` | **新建** | B6 英义互译题 |
| `agents/definition-agent.ts` | **新建** | B7 英文释义题 |
| `schemas.ts` | **新建** | 所有题型的 TypeScript/Zod schema |
| `qwen-chat.ts` | **修改** | definition prompt 扩展（返回 forms/synonyms）|

---

---

## 六、难度分级体系（V4 新增）

### 6.1 现状分析

当前难度参数 `difficulty` 已从客户端传入 Edge Function（5 个等级：beginner / elementary / intermediate / advanced / professional），**但仅用于控制句子长度和单词长度过滤**：

```typescript
// 当前唯一的"难度感知"
const DIFFICULTY_PARAMS = {
  beginner:     { minWords: 3, maxWords: 7,  minWordLen: 3, maxWordLen: 5,  maxSentenceLen: 40  },
  elementary:   { minWords: 3, maxWords: 10, minWordLen: 3, maxWordLen: 7,  maxSentenceLen: 60  },
  intermediate: { minWords: 3, maxWords: 14, minWordLen: 3, maxWordLen: 14, maxSentenceLen: 100 },
  advanced:     { minWords: 5, maxWords: 18, minWordLen: 4, maxWordLen: 14, maxSentenceLen: 150 },
  professional: { minWords: 6, maxWords: 22, minWordLen: 5, maxWordLen: 16, maxSentenceLen: 200 },
}
```

**问题**：Agent 出题时完全没有使用 difficulty 信息！AI 生成的题目对 beginner 和 professional 是完全一样的。

### 6.2 V4 难度分级设计

#### 难度如何影响每种题型

| 难度维度 | beginner | elementary | intermediate | advanced | professional |
|---------|----------|------------|-------------|----------|-------------|
| **词汇范围** | 高频基础词（CEFR A1） | 基础词（A2） | 中级词（B1-B2） | 高级词（C1） | 学术/专业词（C2） |
| **句子复杂度** | 简单句（SVO） | 并列句 | 复合句 | 嵌套从句 | 学术长难句 |
| **选项区分度** | 干扰项明显不同 | 有细微差异 | 需要理解语境才能区分 | 近义词精细辨析 | 抽象概念辨析 |
| **Prompt 指导语** | "Use very simple words. For beginners." | "Use common daily vocabulary." | "Use standard vocabulary." | "Use nuanced, sophisticated language." | "Use academic/professional register." |
| **hint 详细度** | 给出强提示（几乎告诉答案） | 给出中等提示 | 给出弱提示 | 只给方向性提示 | 不给提示 |
| **阅读/听力素材** | 短段落（3-5 句） | 中等段落（5-8 句） | 标准段落（8-12 句） | 长篇章（12-20 句） | 完整文章/演讲 |

#### Agent Prompt 中的难度注入

每个 Agent 的 prompt 模板都需要包含难度段：

```markdown
## Learner Profile
- **Difficulty Level**: {{difficulty}}
- **CEFR Equivalent**: {{cefr_level}}
- **Instruction Style**: {{instruction_style}}

## Difficulty-Specific Guidelines
{{difficulty_guidelines}}
```

**具体示例 — B1 context_mcq 的难度差异化**：

```
=== beginner ===
Target: "cat" (noun)
Sentence: "The _____ is sleeping on the sofa."
Options: A. cat  B. dog  C. car  D. cup
→ 干扰项都是基础名词，视觉上差异大

=== professional ===  
Target: "ubiquitous" (adjective)
Sentence: "Smartphones have become _____ in modern society, transforming how we communicate, work, and access information."
Options: A. ubiquitous  B. obsolete  C. sporadic  D. negligible
→ 干扰项是高级形容词，需要精确语义辨析
```

**具体示例 — B8 reading_comprehension 的难度差异化**：

```
=== beginner (3-5 句短文) ===
Passage: "Tom has a cat. The cat is white. Tom loves his cat."
Question: "What color is Tom's cat?"
Options: A. White  B. Black  C. Red  D. Blue

=== professional (完整文章) ===
Passage: [一段关于 AI ethics 的学术论述，200 词]
Question: "According to the author, what is the primary concern regarding AI deployment?"
Options: [4 个需要推理和综合理解的选项]
```

### 6.3 word_cache.difficulty 字段

当前 word_cache 已有 `difficulty` 字段（来自 definition Agent 的判断）。V4 中：

- **出题时**：根据用户选择的 difficulty 过滤/优先选择匹配的词
  - 如用户选 beginner → 优先选 difficulty ≤ elementary 的词出题
  - 如用户选 professional → 只选 difficulty ≥ advanced 的词
- **Agent 内部**：将 difficulty 传给 LLM，让它调整语言风格

---

## 七、阅读理解 & 听力理解题型（V4 核心新增）

### 7.1 为什么这是必须的

你提到的核心痛点：**当前所有题型都围绕单个单词展开**，缺少对**篇章级内容**的理解考察。但实际英语考试（四六级/雅思/托福/高考）的核心部分正是：

- **阅读理解**：读一篇文章 → 回答主旨/细节/推断题
- **听力理解**：听一段对话或独白 → 回答问题

我们的素材其实已经具备生成这类题目的条件：
- **视频/音频**：有完整字幕（`subtitles` 表，含 content + contentTranslate + 时间轴）
- **文章**：有完整 Markdown 正文 + 段落 + 句子层级（`article` + `article_chapter` + `article_sentence`）

### 7.2 素材结构对比

| 维度 | 视频/音频字幕 | 文章 |
|------|-------------|------|
| **数据源** | `subtitles` 表（按时间轴排列的句子序列） | `article` + `article_chapter` + `article_sentence` |
| **结构** | 扁平句子列表 | 层级：文章 → 章节 → 段落 → 句子 |
| **翻译** | `contentTranslate`（单句翻译） | 可能有段落/全文翻译 |
| **元信息** | 时间轴（startPosition/endPosition） | 标题、作者、来源 |
| **适合题型** | 听力理解 | 阅读理解 |
| **连贯性** | 句子间有口语化跳跃 | 段落内逻辑连贯 |

### 7.3 B8: `reading_comprehension` 阅读理解题（全新）

#### 数据流

```
文章 / 视频字幕（连续 N 句）
  ↓ 按 difficulty 截取合适长度
  ↓ 传入 reading-agent
  ↓ AI 分析内容，生成:
    • 主旨题 (main idea)
    • 细节题 (detail) 
    • 推断题 (inference)
    • 词汇题 (vocabulary in context)
返回: [{ type, passage, question, options, answer, skill_type, hint, feedback }]
```

#### 4 种子题型（借鉴标准阅读理解测试格式）

##### ① main_idea 主旨大意题

```
 passage: [一段 80~150 词的文字]
 question: "What is the main idea of this passage?"
 options:
   A. [正确主旨概括]
   B. [过于宽泛]
   C. [以偏概全（只提到一个细节）]
   D. [完全无关]
 skill_type: "main_idea"
 difficulty_adjustment: beginner 用 3-5 句短段落；professional 用完整章节
```

##### ② detail 细节理解题

```
 passage: [同上]
 question: "According to the passage, when did the event happen?"
 options:
   A. [文中明确提到的正确时间]
   B. [文中提到的另一个时间（干扰）]
   C. [文中未提及的时间]
   D. [与文中信息相反的时间]
 skill_type: "detail"
 关键: 答案必须在原文中能找到依据
```

##### ③ inference 推理判断题

```
 passage: [同上]
 question: "What can be inferred from the passage about...?"
 options:
   A. [合理推断（基于原文线索）]
   B. [过度推断（原文不支持但看似合理）]
   C. [直接照抄原文（不是推断）]
   D. [与原文矛盾]
 skill_type: "inference"
 关键: 答案不能在原文中直接找到，需要推理
```

##### ④ vocab_in_context 语境词义题

```
 passage: [同上，其中某个词/短语被加粗或下划线]
 question: "In this passage, the word '_____' most likely means:"
 options:
   A. [该词在此语境中的正确释义]
   B. [该词的常见义项但非此语境含义]
   C. [形近词干扰]
   D. [无关词]
 skill_type: "vocab_in_context"
 关键: 考的是一词多义在特定语境下的含义
```

#### Reading Agent Prompt 要点

```markdown
You are an expert English reading comprehension test designer.

## Input Material
{{passage_text}}

[If translation available]  
Chinese Translation: {{passage_translation}}

## Learner Difficulty: {{difficulty}}
- Adjust passage length and complexity accordingly
- beginner: Use 3-5 simple sentences, basic vocabulary
- professional: Use a full paragraph or section, academic language

## Task
Generate {{count}} reading comprehension questions from the passage.

## Question Type Distribution (adjust based on difficulty):
- beginner: 2 detail + 1 vocab_in_context (concrete, findable in text)
- elementary: 1 main_idea + 2 detail + 1 vocab_in_context
- intermediate: 1 main_idea + 1 detail + 1 inference + 1 vocab_in_context
- advanced: 1 main_idea + 1 detail + 2 inference + 1 vocab_in_context
- professional: 1 main_idea + 1 detail + 2 inference + 1 tone/attitude

## Quality Rules
1. Every answer MUST be justifiable from the passage text
2. Distractors must be plausible (common mistakes a learner would make)
3. Do NOT ask about information not present or inferrable from the passage
4. For vocab_in_context questions: test the meaning IN THIS CONTEXT, not dictionary definition
5. Include the relevant sentence reference for detail/inference questions

## Output Format (JSON array)
[
  {
    "type": "reading_comprehension",
    "skill_type": "detail|main_idea|inference|vocab_in_context|tone",
    "passage": "...",           // The passage text (or excerpt)
    "question": "...",
    "options": ["A", "B", "C", "D"],
    "optionLabels": ["A", "B", "C", "D"],
    "correctAnswer": "A|B|C|D",
    "answer": "actual answer text",
    "evidence": "The sentence or phrase that supports the answer",
    "hint": "Helpful hint without giving away the answer",
    "feedback": "Explanation of why this is correct and why others are wrong",
    "difficulty": "easy|medium|hard"
  }
]
```

#### 文章模式 vs 字幕模式的区别

| | 文章模式 (`source_type=article`) | 字幕模式 (`source_type=resource/folder`) |
|---|---|---|
| **Passage 来源** | `article.contentMarkdown` 解析出的连续段落 | 从 `subtitles` 中取连续 N 条字幕拼接 |
| **连贯性** | 高（书面语，逻辑严密） | 中（口语化，可能有跳跃） |
| **适用题型** | 全部 4 种（尤其 main_idea 和 inference） | 以 detail 和 vocab_in_context 为主 |
| **Passage 长度** | 按 chapter 或 paragraph 切分 | 按 subtitle 连续片段切分（约 10-30 条） |
| **翻译** | 可能有段落翻译 | 使用每句的 `contentTranslate` 拼接 |

### 7.4 B9: `listening_comprehension` 听力理解题（替代旧 listen_reply）

#### 与 B8 的关系

B9 本质上是 B8 的**音频版本**——区别在于：
- Passage 不是文字展示的，而是**播放音频**
- 问题在**听完后**显示（或在听的过程中显示）
- 依赖字幕的时间轴信息定位音频位置

#### 两种子类型

##### ① conversation 对话理解

```
素材: 字幕中连续的问答对（如 6-10 条字幕，形成一个小对话）
播放: TTS 按时间轴顺序播放这段对话
问题: "What does the man want to do?"
选项: A/B/C/D（AI 根据对话内容生成）
关键: 测试对话意图理解、言外之意
```

##### ② monologue 独白理解

```
素材: 字幕中连续的同一个人说话内容（如一段旁白/讲解）
播放: TTS 播放
问题: "Why does the speaker mention...?"
选项: A/B/C/D
关键: 测试主旨把握、细节捕捉、态度判断
```

#### Listening Agent Prompt 要点

```markdown
You are an expert English listening comprehension test designer.

## Input Dialogue/Monologue
{{subtitle_texts}}
[With Chinese translations for reference]
{{subtitle_translations}}

## Audio Context
This is from a {{video_type}} titled "{{title}}".
The speaker(s): {{speaker_description}}

## Learner Difficulty: {{difficulty}}

## Task
Generate {{count}} listening comprehension questions.

## Question Types:
1. **purpose**: What is the speaker's purpose/intention?
2. **detail**: Specific information from the audio
3. **inference**: What can be implied but not directly stated?
4. **attitude**: How does the speaker feel about...?

## Critical Rules
- Options must be answerable FROM THE AUDIO CONTENT ONLY
- For beginner: Questions about concrete facts (numbers, names, places)
- For advanced: Questions about attitude, implication, tone
- Each question must include the timestamp range of relevant audio segment
- NEVER include the exact audio transcript as an option (that gives away the answer)

## Output Format
Same as reading_comprehension, plus:
- "audio_range": { "start_ms": 0, "end_ms": 5000 } // 用于客户端定位播放位置
```

### 7.5 客户端适配考虑

#### 阅读理解 UI

```
┌─────────────────────────────────────┐
│ 📖 Reading Comprehension           │
├─────────────────────────────────────┤
│                                     │
│ [Passage 文本区域]                   │
│ The quick brown fox jumps over      │
│ the lazy dog. This sentence has     │
│ been used for decades as a          │
│ typing practice example...          │
│                                     │
├─────────────────────────────────────┤
│ Q1: What is the main idea?          │
│  ○ The fox is quick                 │
│  ○ The dog is lazy                  │
│  ● It's a typing practice text      │
│  ○ Foxes like to jump               │
│                                     │
│  [下一题 →]                          │
└─────────────────────────────────────┘
```

#### 听力理解 UI

```
┌─────────────────────────────────────┐
│ 🎧 Listening Comprehension         │
├─────────────────────────────────────┤
│  ▶ [播放按钮]  00:00 / 01:23        │
│                                     │
│ (音频播放中...)                      │
│                                     │
├─────────────────────────────────────┤
│ (播放完毕后显示问题)                   │
│                                     │
│ Q1: Why did the woman call?         │
│  ○ To book a restaurant             │
│  ○ To complain about service         │
│  ● To make a reservation            │
│  ○ To cancel her order              │
│                                     │
│  [▶ 重播片段]  [下一题 →]            │
└─────────────────────────────────────┘
```

---

## 八、V4 完整题型矩阵（更新版）

### 8.1 按技能维度分类

| 技能 | 题型标识 | 名称 | 出题方式 | Agent | 难度敏感 |
|------|---------|------|---------|-------|---------|
| **📖 读** | `reorder` | 组句题 | 机械模板 | ❌ | ⚠️ 仅长度 |
| **📖 读** | `spelling` | 拼写填空 | 机械模板 | ❌ | ⚠️ 仅长度 |
| **📖 读** | `context_mcq` | 语境选择题 | **AI Agent** | ✅ mcq-agent | ✅ |
| **📖 读** | `meaning_choice` | 释义选择题 | **AI Agent** | ✅ meaning-agent | ✅ |
| **📖 读** | `word_forms` | 词形变化题 | **AI Agent** | ✅ forms-agent | ✅ |
| **📖 读** | `semantic_relation` | 语义关系题 | **AI Agent** | ✅ relation-agent | ✅ |
| **📖 读** | `english_definition` | 英文释义题 | **AI Agent** | ✅ definition-agent | ✅ |
| **📖 读** | **`reading_comprehension`** | **阅读理解** | **AI Agent** | ✅ **reading-agent** | ✅ |
| **📖 读** | `translation_match` | 英义互译题 | **AI Agent** | ✅ translation-agent | ✅ |
| **👂 听** | `listen_choose` | 听音选词 | 机械模板 | ❌ | ⚠️ 仅长度 |
| **👂 听** | `listen_meaning` | 听音辩义 | **AI Agent** | ✅ meaning-agent | ✅ |
| **👂 听** | **`listening_comprehension`** | **听力理解** | **AI Agent** | ✅ **listening-agent** | ✅ |
| **✍️ 写** | `spelling` | 拼写填空 | 机械模板 | ❌ | ⚠️ 仅长度 |
| **🗣️ 说** | `word_pron` | 单词跟读 | 机械+声通 | ❌ | ❌ |
| **🗣️ 说** | `phrase_pron` | 短语跟读 | 机械+声通 | ❌ | ❌ |
| **🗣️ 说** | `sentence_pron` | 句子跟读 | 机械+声通 | ❌ | ❌ |

### 8.2 按粒度分类

| 粒度 | 题型 | 说明 |
|------|------|------|
| **单词级** | context_mcq, meaning_choice, word_forms, semantic_relation, english_definition, listen_choose, listen_meaning, spelling | 围绕单个单词的考查 |
| **句子级** | reorder, listening_comprehension(对话), translation_match | 围绕单句/几句的考查 |
| **篇章级** | **reading_comprehension**, **listening_comprehension(独白)** | 围绕整个段落/文章/对话的考查 |
| **发音级** | word_pron, phrase_pron, sentence_pron | 跟读评分 |

---

## 九、更新后的实施路径

### Phase 1: 清理（不变）
1. 删除 WORD_MEANING_MAP / WORD_RELATIONS / mockTranslate
2. 删除所有同步版本 pickXxxItems
3. 保留机械型题型 + validateItem 质量门

### Phase 2: word_cache 扩展（不变）
1. definition prompt 返回 forms/synonyms/category/difficulty
2. migration 补充新字段

### Phase 3: Agent 开发（更新：增加 2 个新 Agent）

按优先级：

| 优先级 | Agent | 题型 | 理由 |
|--------|-------|------|------|
| P0 | **mcq-agent** | B1 context_mcq | 替代最常用的 MCQ，质量影响最大 |
| P0 | **meaning-agent** | B2 meaning_choice | 替代 listen_meaning / definition_choice |
| P0 | **reading-agent** | **B8 reading_comprehension** | **全新能力，应试核心需求** |
| P1 | **listening-agent** | **B9 listening_comprehension** | **全新能力，替代旧的 listen_reply** |
| P1 | **definition-agent** | B7 english_definition | 差异化功能 |
| P1 | **forms-agent** | B3 word_forms | 词形变化 |
| P2 | **relation-agent** | B4 semantic_relation | 替代 word_relation |
| P2 | **translation-agent** | B6 translation_match | 需要 AI 翻译能力 |

### Phase 4: 难度分级集成
1. 所有 Agent prompt 注入 difficulty 参数
2. word_cache.difficulty 过滤逻辑
3. 客端难度选择器已存在（`TestHomePage._buildDifficultySelector`），无需改动

### Phase 5: 集成与测试（更新）
1. 文章模式 source_type 扩展（支持 article 类型）
2. 阅读/听力 UI 开发
3. 端到端测试

---

## 十、待决策事项（更新）

### Q1~Q3: 不变（已确认：Q1=A实时, Q2=B批量, Q3=A先用Qwen）

### Q4: 阅读/听力的素材来源优先级

当用户选择"综合测试"时，素材可能同时包含视频字幕和文章。

| 方案 | 说明 |
|------|------|
| **A**: 视频字幕 → 听力理解题；文章 → 阅读理解题 | 各归各的，最自然 |
| **B**: 所有素材统一生成两类题 | 字幕也可以出阅读理解（作为文本） |
| **C**: 由用户在配置页选择是否包含阅读/听力理解题 | 最灵活 |

**我的建议**: 方案 A，同时在配置页新增两个 slider：`readingCount` 和 `listeningCount`。

### Q5: 阅读/听力题的数量控制

阅读理解和听力理解题比单词级题目**更耗时**（需要读/听一段材料再答题）。

建议：
- 每次 test session 中，阅读理解 **2-4 题**（共享同一篇 passage）
- 听力理解 **2-4 题**（共享同一段音频）
- 单道阅读/听力题的"成本"按 2-3 道单词题计算（计费时加权）

---

> **下一步**: 请审阅第六章（难度分级）和第七章（阅读理解/听力理解），确认后我开始实施 Phase 1 代码清理。
