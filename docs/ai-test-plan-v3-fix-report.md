# AI 出题系统 v3 修复报告

> **日期**: 2026-06-29
> **状态**: ✅ 代码修改完成，待用户评估后决定是否实施
> **触发原因**: 用户反馈 AI 出题存在大量严重问题（答案明显、题型不匹配、选项无关等）

---

## 一、问题清单

### 1.1 用户原始反馈

> "ai出图一大堆问题，首先暴露答案非常明显，词性的提问和选项完全无关，听力明明是一个短句，让我选一个单词，非常明显多的错误"

### 1.2 逐项问题定位

| # | 问题现象 | 根因分析 | 严重度 |
|---|---------|---------|--------|
| 1 | `word_relation` 题型答案随机编造 | 无预定义数据时从词池随机取词作为"正确答案" | 🔴 P0 致命 |
| 2 | 多种题型的选项出现 `「xxx」的释义` fallback 字符串 | `getWordMeaning` 未命中时返回 fallback 格式而非空值 | 🔴 P0 致命 |
| 3 | `listen_reply` 使用陈述句作为素材 | 陈述句不适合做"选择回答"类题目 | 🟠 P0 严重 |
| 4 | `listen_reply` prompt 中包含原文句子 | 答案泄露风险 | 🟠 P0 严重 |
| 5 | `translate_meaning` 的翻译结果无空格拼接 | `mockTranslate` 使用 `join('')` 导致中文粘连 | 🟠 P0 严重 |
| 6 | `translate_meaning` 翻译失败时不跳过 | 大量未收录词导致翻译结果几乎全是英文 | 🟠 P0 严重 |
| 7 | `definition_choice` cn_to_en prompt 泄露英文答案 | prompt 中包含原英文单词 | 🟡 P1 中等 |
| 8 | 句子中出现连续重复词（如 "one one test"） | 数据质量问题未被过滤 | 🟡 P1 中等 |
| 9 | **无全局质量门** | 设计文档 §4.2 要求的质量门从未实现 | 🔴 P0 致命 |
| 10 | MCQ 干扰项与正确答案无语义约束 | 从 wordPool 随机取词，可能词性/语义完全不相关 | 🟡 P1 设计缺陷 |

---

## 二、已完成的代码修改

### 2.1 修改文件清单

| 文件路径 | 修改类型 | 说明 |
|---------|---------|------|
| `supabase/functions/ai-test-plan/index.ts` | **重大修改** | 新增质量门 + 6 处 P0/P1 修复 |
| `supabase/functions/ai-test-plan/cache-helpers.ts` | **重写** | 完全同步 index.ts 的所有修复 |

### 2.2 逐项修复详情

#### 修复 #1: 新增全局质量门 `validateItem()`

**位置**: `index.ts` 文件顶部（import 之后）

**新增函数**: `validateItem(item)` — 每道题返回前必须通过此校验

```typescript
// 6 条校验规则：
// R1: 选项去重且 ≥2 个
// R2: 答案在选项中 / answer_index 合法
// R3: Prompt 不泄露 >3 字符的答案
// R4: listen_reply/translate_meaning 选项不能与原文重叠 >70%
// R5: word_relation low confidence 直接过滤
// R6: 句子不含连续重复词
```

**接入点**: 在 `shuffle(allItems)` 之前插入过滤逻辑：

```
allItems (原始生成) → validateItem 过滤 → validatedItems → shuffle → 返回
```

**日志输出**: 每道被过滤的题目输出 `[quality_gate] type=xxx reason=xxx`，最终汇总生成/通过/过滤数量。

---

#### 修复 #2: `getWordMeaning` fallback 改为空字符串

**原代码**:
```typescript
return WORD_MEANING_MAP[lower] ?? `「${word}」的释义`
```

**新代码**:
```typescript
if (WORD_MEANING_MAP[lower]) {
  return WORD_MEANING_MAP[lower]
}
// 未命中，返回空字符串
return ''
```

**影响范围**: `index.ts` 和 `cache-helpers.ts` 两处

**调用方适配**: 所有使用 `getWordMeaning` 的题型生成器增加了空值检查，为空时 `continue` 跳过该题。

---

#### 修复 #3: `pickListenReplyItems` 只用疑问句

**原行为**: 所有句子（含陈述句）都可作为 listen_reply 素材

**新行为**:
- 只保留以 what/where/when/why/how/who/which/can/could/would/do/does/did/is/are/am 开头的句子
- 或以 `?` 结尾的句子
- 过滤掉含连续重复词的句子
- prompt 不再包含原文句子内容（改为通用提示）
- 空释义时跳过

**原 prompt**: `听以下句子，选择最佳回答：「${s}」`
**新 prompt**: `听以下问题，选择最合适的回答：`

---

#### 修复 #4: `pickDefinitionChoiceItems` cn_to_en 答案泄露修复

**原 prompt**: `Which word matches the meaning: "${wordMeaning}"?` （prompt_cn 含义中不含英文，但英文 prompt 有）
**新 prompt**: `Which word matches the meaning?` (统一不暴露)
**prompt_cn 保持不变**: `哪个单词符合以下含义：「${wordMeaning}」？`

同时增加空释义过滤。

---

#### 修复 #5: `pickTranslateMeaningItems` mockTranslate 修复

**Bug 1 — 无空格**:
```typescript
// 原: translatedParts.join('')
// 新: translatedParts.join(' ')
```

**Bug 2 — 翻译失败不检测**:
```typescript
// 新增: 英文字符占比 >40% 视为翻译失败，返回 null，跳过该题
if (englishCharRatio(result) > 0.4) return null
```

**新增过滤**: 连续重复词句子直接排除

---

#### 修复 #6: `pickWordRelationItems` 删除随机降级

**原代码（致命 Bug）**:
```typescript
// 如果没有预定义的关系数据，降级为随机选取
if (correctAnswers.length === 0) {
  const others = shuffle(wordPool.filter((x) => x !== w))
  correctAnswers = others.slice(0, 2)  // ❌ 随机指定"正确答案"！
}
```

**新代码**:
```typescript
// 【P0 v3修复】没有预定义关系数据时直接跳过，不再随机降级！
if (correctAnswers.length === 0) {
  continue  // ✅ 直接跳过，不出题
}
```

**代价**: 只有 `WORD_RELATIONS` 表中预定义了关系的 ~20 个词能出此题型。其余词自动跳过。

---

## 三、最新出题策略完整说明（v3）

### 3.1 题型总览（12 种）

| # | 题型标识 | 中文名称 | 技能维度 | 选项类型 | 缓存支持 | v3 修复状态 |
|---|---------|---------|---------|---------|---------|------------|
| 1 | `reorder` | 组句题 | 读/写 | 打乱的单词列表 | ❌ 不需要 | 无需修复 |
| 2 | `spelling` | 拼写填空 | 写 | 字母池（选字母拼写） | ❌ 不需要 | 无需修复 |
| 3 | `mcq` | 选择题填空 | 读/写 | 4 个英文单词 | ❌ 不需要 | ⚠️ 设计缺陷见§3.3 |
| 4 | `listen_choose` | 听音选词 | 听 | 4 个英文单词 | ❌ 不需要 | 无需修复 |
| 5 | `listen_meaning` | 听音辩义 | 听+读 | **4 个中文释义** | ✅ WithCache | ✅ 已修复 |
| 6 | `listen_reply` | 听力理解 | 听+读 | **4 个中文释义** | ✅ WithCache | ✅ 已修复 |
| 7 | `definition_choice` | 释义选择 | 读 | 中文释义 / 英文单词 | ✅ WithCache | ✅ 已修复 |
| 8 | `translate_meaning` | 英义互译 | 读 | **4 个中文翻译** | ✅ WithCache | ✅ 已修复 |
| 9 | `word_relation` | 词关系 | 读+词汇 | 英文单词（多选） | ❌ 预定义表 | ✅ 已修复 |
| 10 | `word_pron` | 单词跟读 | 说 | 无选项 | ❌ 不需要 | 无需修复 |
| 11 | `phrase_pron` | 短语跟读 | 说 | 无选项 | ❌ 不需要 | 无需修复 |
| 12 | `sentence_pron` | 句子跟读 | 说 | 无选项 | ❌ 不需要 | 无需修复 |

### 3.2 逐题型实现说明

#### ① `reorder` 组句题
- **含义**: 给出一堆打乱顺序的单词，用户按正确语法顺序排列成句
- **数据来源**: 字幕句子，按难度控制词数（beginner: 3~7, professional: 6~22）
- **实现**: `tokenizeWords` 分词 → `shuffle` 打乱 → 正确答案 = 原始词序数组
- **质量保证**: 词数在 `minWords ~ maxWords` 范围内

#### ② `spelling` 拼写填空
- **含义**: 给出挖空句子（如 `He _____ dad.`），提供字母池让用户拼出缺失词
- **数据来源**: wordPool 中的单词，在字幕句子中找到包含该词的句子后挖空
- **实现**: 正则 `\b${word}\b` 全词匹配替换为 `_____`；字母池 = 目标词字母 + 随机干扰字母（总数 8~12）
- **质量保证**: 必须找到包含该词的句子才能出题

#### ③ `mcq` 选择题填空 ⚠️
- **含义**: 四选一填空，选出正确的单词填入空格
- **数据来源**: 同 spelling，但选项是 4 个英文单词
- **实现**: 正确答案 = 目标词；干扰项 = 从 wordPool **随机取** 3 个其他词
- **⚠️ 当前设计缺陷**: 干扰项与正确答案之间**没有任何语义约束**
  - 例：正确答案 `happy`（形容词），干扰项可能是 `computer`（名词）、`because`（连词）、`project`（名词）
  - 用户可通过词性轻松排除 2~3 个选项，导致题目过于简单
- **改进方向**: 见 §4 待决策事项 Q1

#### ④ `listen_choose` 听音选词
- **含义**: 播放单词 TTS 发音，从 4 个英文单词中选出听到的那个
- **数据来源**: wordPool 单词
- **实现**: 纯辨音测试，前端播放 `ref_text` 音频
- **注意**: 干扰项也是纯随机取自 wordPool，但因为是辨音测试（非语义），可接受

#### ⑤ `listen_meaning` 听音辩义 ✅ v3 已修复
- **含义**: 播放单词发音，选择它的**中文释义**
- **数据来源**: wordPool → `word_cache` 获取中文释义
- **实现**:
  - 正确答案 = 该词的**中文释义**（来自 word_cache 或本地映射表）
  - 干扰项 = 其他 3 个词的**中文释义**
  - 前端播放 `ref_text`（原英文词）音频
- **v3 修复**: word_cache 和本地映射都没有该词时 → **跳过不出题**

#### ⑥ `listen_reply` 听力理解 ✅ v3 已修复
- **含义**: 播放一个问题/疑问句，选择最合适的回答
- **数据来源**: 字幕中的**疑问句**（v3 新增过滤）
- **实现**:
  - 只使用疑问句（what/where/when/why/how/who 开头或 `?` 结尾）
  - 提取关键词 → 取其**中文释义**作为正确答案
  - 干扰项 = 其他词的**中文释义**
- **v3 修复**:
  - ✅ 只要疑问句（不用陈述句硬凑）
  - ✅ 过滤重复词句子
  - ✅ 空释义跳过
  - ✅ prompt 不再包含原文

#### ⑦ `definition_choice` 释义选择 ✅ v3 已修复
- **含义**: 两种子类型随机出现：
  - **en_to_cn**: 给英文单词 → 选中文释义
  - **cn_to_en**: 给中文释义 → 选英文单词
- **v3 修复**:
  - ✅ cn_to_en prompt 只显示中文（不暴露英文答案）
  - ✅ 空释义时整道题跳过

#### ⑧ `translate_meaning` 英义互译 ✅ v3 已修复
- **含义**: 给英文句子，选择最接近的中文翻译
- **实现**: `mockTranslate` 逐词查释义拼接
- **v3 修复**:
  - ✅ `join('')` → `join(' ')`
  - ✅ 英文占比 >40% 视为失败并跳过
  - ✅ 过滤重复词句子
- **⚠️ 局限性**: 仍依赖本地映射表（~70 词），建议后续接入 AI 翻译 API

#### ⑨ `word_relation` 词关系 ✅ v3 已修复
- **含义**: 三种关系轮换 — 同义词 / 反义词 / 同类词（多选）
- **数据来源**: 预定义 `WORD_RELATIONS` 映射表（约 20 个词）
- **v3 核心修复**:
  - ✅ **删除随机降级** — 无预定义数据的词直接跳过
  - ✅ 某关系类型下没数据也跳过（如 `two` 无反义词）
  - ✅ 输出 confidence 固定 `'high'`
- **代价**: 仅 ~20 个词能出此题型

#### ⑩~⑫ 跟读类（word_pron / phrase_pron / sentence_pron）
- **含义**: 用户跟读 → 录音 → 声通 AI 评分
- **数据来源**: wordPool 或字幕句子
- **实现**: 纯展示型，不生成选项
- **短语截取策略**: 从句子中间取 2~4 词

### 3.3 wordPool 建立流程详解

```
字幕文件 (JSON 存储于 Supabase Storage)
  ↓ fetchSubtitlesFromStorage(userId, videoCode)
  ↓ 路径: {userId}/{videoCode}.json
字幕对象数组 [{ content: "sentence text", ... }, ...]
  ↓ buildSentenceCandidates(subtitles)
  ↓ 提取每条 subtitle.content，trim 后收集
句子字符串数组 ["sentence1", "sentence2", ... ]
  ↓ extractWordPool(sentences, diffParams)
  ↓ 对每个句子:
  │   tokenizeWords(s) → 用 /[A-Za-z]+/ 正则提取英文单词
  │   toLowerCase()
  │   按 minWordLen ~ maxWordLen 过滤长度
  ↓ unique() 去重
wordPool = [ "happy", "computer", "because", ... ]  (全部小写、唯一)
```

**wordPool 被以下题型使用**:
- `mcq`: 正确答案 + 3 个干扰项全部来自 wordPool
- `listen_choose`: 同上
- `listen_meaning`/`listen_reply`/`definition_choice`: 作为候选词源传给 getWordMeaning
- `spelling`: 从 wordPool 取词后在句子中挖空
- `word_relation`: 作为同类词匹配的搜索空间

**难度对 wordPool 的影响**:

| 难度 | minWordLen | maxWordLen | 效果 |
|------|-----------|-----------|------|
| beginner | 3 | 5 | 排除短词和长词，保留基础词汇 |
| elementary | 3 | 7 | 稍微放宽 |
| intermediate | 3 | 14 | 大部分词汇保留 |
| advanced | 4 | 14 | 排除极短词 |
| professional | 5 | 16 | 只保留较长词汇 |

### 3.4 全局质量门规则（v3 新增）

所有题目在返回客户端前必须通过以下校验：

| 规则码 | 名称 | 检测内容 | 失败处理 |
|-------|------|---------|---------|
| R1 | options_valid | 选项数组 ≥2 且去重后数量不变 | 过滤该题 |
| R2 | answer_in_options | 答案在选项中或 answer_index 合法 | 过滤该题 |
| R3 | no_prompt_leakage | Prompt 中不包含 >3 字符的答案文本 | 过滤该题 |
| R4 | no_source_leakage | listen_reply/translate_meaning 选项与原文重叠 ≤70% | 过滤该题 |
| R5 | high_confidence_only | word_relation 必须是 high confidence | 过滤该题 |
| R6 | no_repeated_words | 句子不含连续重复词 | 过滤该题 |

**降级策略**: 当所有题目被过滤完时，返回 `{ error: 'no_items', message: '所有生成的题目均未通过质量检查...' }` 而非返回低质量题目。

---

## 四、当前局限性（诚实说明）

| # | 局限性 | 影响 | 建议方案 | 优先级 |
|---|-------|------|---------|--------|
| 1 | `WORD_MEANING_MAP` 仅 ~70 词 | 未命中词的 listen_meaning/listen_reply/definition_choice 会少出题 | 执行 word_cache prefill | P0 |
| 2 | `WORD_RELATIONS` 仅 ~20 词 | word_relation 覆盖面窄 | 扩充预定义表或接入 AI 词典 | P1 |
| 3 | `mockTranslate` 是逐词拼接 | 翻译质量一般 | 接入 AI 翻译 API | P1 |
| 4 | **MCQ 干扰项无语义约束** | 题目过于简单 | 改为同词性/同长度干扰 or 移除此题型 | **待决策** |
| 5 | `listen_choose` 干扰项无音近约束 | 可能差异过大 | 可加音近词逻辑 | P2 |

---

## 五、待决策事项

### Q1: MCQ 题型的去留

**现状**: MCQ（选择题填空）的干扰项从 wordPool 随机选取，与正确答案无任何语义关联。

**选项 A — 保留但优化干扰项**:
- 从 wordPool 中筛选**同词性**或**同长度**的词作为干扰项
- 需要词性标注能力（可从 word_cache 的 morphology 字段获取）
- 工作量：中等

**选项 B — 与 definition_choice 合并**:
- MCQ 本质上是在考"语境中的词义理解"，与 definition_choice 重叠
- 将 mcq 的 en_to_cn 子类型归入 definition_choice
- 减少一种题型维护成本
- 工作量：小

**选项 C — 移除 MCQ**:
- 当前 MCQ 质量确实差，不如专注做好 definition_choice
- 生词本模式已有独立的 `pickWordBookMcqItems`，不受影响
- 工作量：最小

### Q2: word_relation 覆盖面不足的处理

**现状**: 仅 20 个词有预定义关系数据，其余词全部跳过。

**选项 A — 扩充 WORD_RELATIONS 到 200+ 常用词**:
- 手动维护成本高，但可控
- 适合高频核心词汇

**选项 B — 接入 AI 词典 API**:
- 出题时实时查询同义词/反义词
- 增加网络延迟和 API 成本
- 覆盖面最广

**选项 C — 暂时禁用 word_relation**:
- 在配置页默认关闭此题型
- 等 word_cache prefill 完成后再开启

### Q3: translate_meaning 是否接入真实 AI 翻译

**现状**: mockTranslate 逐词拼接，翻译质量一般。

**建议**: 短期保持 mockTranslate（已修复 join 和阈值），中期接入 qwen-chat 的翻译能力。不需要立即决策。

---

## 六、文件变更汇总

| 文件 | 变更类型 | 行数变化 | 说明 |
|------|---------|---------|------|
| `supabase/functions/ai-test-plan/index.ts` | 修改 | +80/-30 | 新增 validateItem + 6 处修复 |
| `supabase/functions/ai-test-plan/cache-helpers.ts` | 重写 | 全部 | 同步所有 P0 修复 |

---

## 七、向后兼容性

- **API 协议不变**: 返回 JSON 结构完全兼容，客户端无需改动
- **题目数量可能减少**: 因为质量门过滤和空释义跳过，同样配置下生成的题目数可能比之前少
- **word_relation 可能返回 0 题**: 如果 wordPool 中没有 WORD_RELATIONS 表内的词
- **计费逻辑不变**: 仍基于 plan 生成计费，与题目质量无关

---

> **下一步**: 用户阅读本文档后确认修改内容，如有调整意见更新文档，确认后部署。
