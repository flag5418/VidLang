# VidLang 详细设计 — 测试体系（单元 / 综合 / 生词本）

本设计用于落地：可配置题型 → 统一生成卷子（每次随机）→ 多页面执行 → 评分统计 → 计费核算（统一走 Supabase Edge Function）。

## 0. 目标与原则

- 单元测试/综合测试：题目由 AI 生成（每次随机，非缓存复用），执行评分尽量本地完成
- 生词本测试：题目以生词本为主（固定单词），可选使用 AI 生成干扰项/例句，但不依赖 AI 对话
- 所有网络接口统一走 Supabase Edge Functions（便于鉴权、计费、日志、开关）
- 题型可插拔：新增题型只新增 “生成器 + 执行页 + 评分器”，不改主流程

## 1. 测试范围与入口

### 1.1 三类测试

- 单元测试（Unit Test）：针对单个资源（视频/音频/文章）
- 综合测试（Folder Test）：针对文件夹下所有资源（可过滤类型）
- 生词本测试（WordBook Test）：针对收藏单词（一次测试可抽 N 个词）

### 1.2 入口建议

- 单元测试：播放器页 / 阅读页 / 音频页的 “测试”按钮
- 综合测试：文件夹详情页 “综合测试”
- 生词本测试：生词本页 “测试”

## 2. 题型集合（V1 设计）

题型统一按 “可执行页面 + 可评分口径 + 可计费点” 定义。

### 2.1 建议保留的核心题型

- 跟读评分（Speak & Score）：TTS/原声 → 录音 → 声通评分（按次计费）
- 填空拼写（Cloze Spelling）：挖空目标词/短语 → 软键盘/字母池 → 拼写比对
- 组句（Sentence Builder）：打乱 token → 点击组句 → 与原句对比
- 选择题问答（MCQ QA）：四选一（正确 + 3 干扰）→ 选择 → 对错
- 同类/相似词（Word Category）：给词/短语 → 选择同类词/相似词（1 正确 + 多干扰）
- AI 对话（Conversation）：练习型题型（统计轮次/时长/覆盖度，费用按问/答计费）

### 2.2 题型扩展（后续）

- 听写（Dictation）：播放音频 → 输入整句/关键词（本地编辑距离评分）
- 找错（Error Spotting）：句子中替换一个词 → 用户找出错误词
- 配对（Matching）：词↔释义 / 词↔例句 / 句子↔翻译
- 词形变化（Morphology）：时态/单复数/派生词填空

## 3. 测试配置页（题型选择/数量/顺序）

单元/综合/生词本三种测试，统一使用同一个配置器页面（根据 scope 变化字段）。

### 3.1 配置项（通用）

- 题型列表（可拖拽排序）
  - 开关（是否启用）
  - 数量（本题型题目数）
  - 简介（1 行说明）
- 难度（简单/标准/困难）
- 总题数、预计费用（实时计算）

### 3.2 配置项（scope 扩展）

- 单元测试：sourceType（subtitle/article/audio）、sourceCode（videoCode/articleCode）
- 综合测试：folderCode + 资源过滤（视频/音频/文章）
- 生词本测试：抽词数量 N、抽词策略（新词优先/错题优先/随机）、每词出题策略（每词 1-3 题）

## 4. “每次随机出题”的生成策略（选择 A）

点击“开始测试”时一次性生成本次 session 的 plan；不做跨 session 缓存，但 plan 内包含 seed，便于本次复盘复现。

### 4.1 生成链路

- 客户端收集素材（字幕/句子/生词）并截断（上限条数/字符数）
- 调用 Supabase Edge Function 生成 plan（AI 生成结构化 JSON）
- 客户端校验 plan（schema 校验 + 质量门），不合格则重试/降级
- 进入执行页，按 plan 顺序逐题执行

### 4.2 质量门（必须做）

- 每题必须包含：type、prompt、answerKey、difficulty、sourceRef
- 选择题：选项去重、长度合理、正确项唯一
- 组句：token 数 >= 3（建议 >= 5）
- 填空：挖空目标不允许为空、目标不允许是标点
- 失败策略：最多重试 2 次；仍失败则降级成本地模板题（从字幕随机抽取）

## 5. Edge Function 设计（统一接口 + 统一计费）

所有题目生成/计费走 Edge Function；客户端只做执行与本地评分。

## 5.0 字幕云端存储（Supabase Storage）

为降低重复上传、保证 Edge Function 侧可稳定拿到字幕内容，引入字幕云端存储：

- Bucket：`subtitles`（private）
- 路径：`{user_id}/{video_code}.json`
- 内容：`{ video_code, title, uploaded_at, items: [{ start_position, end_position, content, content_translate }] }`

生命周期：

- 导入字幕成功（本地入库后）→ 调用 `subtitle-storage` 上传（upsert）
- 删除视频/删除文件夹时 → 调用 `subtitle-storage` 删除（释放免费空间）
- `ai-conversation`/后续 `ai_test_plan`：优先从 Storage 下载字幕；没有则 fallback 客户端上报或服务端表

### 5.1 新增/复用的规则码（pricing_rule.rule_code）

- ai_test_plan：生成卷子（按次计费，建议与题目总数挂钩）
- st_pron_score：声通跟读评分（按次计费）
- ai_conversation_question / ai_conversation_answer：AI 对话问/答（已实现）

### 5.2 建议新增路由（ai-proxy 下）

- rule_code=ai_test_plan
  - params：scope、sourceType/sourceCode/folderCode、questionGroups、difficulty、seed、material（截断后）
  - result：plan（结构化）

说明：后续要切换 DeepSeek，只需要在 ai-proxy 内增加一个 client（例如 deepseek-chat.ts），并在 app_settings 中加 provider 配置（qwen/deepseek），不改客户端协议。

### 5.3 新增字幕管理函数（subtitle-storage）

- `POST /functions/v1/subtitle-storage`
  - `op=upload`：上传字幕 json（upsert）
  - `op=get`：读取字幕 json
  - `op=exists`：判断是否存在
  - `op=delete`：删除字幕文件

## 6. 客户端执行与状态机（统一 Test Runner）

### 6.1 数据结构（概念）

- TestSession：一次测试实例（scope、config、plan、统计结果、费用汇总）
- TestPlan：由 AI 生成的题目列表（按组：题型→题目序列）
- TestItem：单题（type、prompt、answerKey、options、audioMeta、sourceRef）
- TestAttempt：作答记录（userAnswer、isCorrect/score、durationMs、cost）

### 6.2 执行流程

- 配置页 → 生成 plan → 进入 TestRunnerPage
- Runner 根据当前 item.type 路由到对应题型页面
- 提交后写 attempt，计算该题型累计统计
- 自动跳转下一题，直到结束
- 结果页：按题型分组展示数量、正确率、平均分、平均用时、费用

## 7. 费用与统计口径

## 7.0 费用展示总原则（最终版）

- 所有业务页面不再展示费用提示、预计费用、单次扣费说明
- 所有费用展示统一收口到“计费明细”模块
- “计费规则”与“计费明细”分离：
  - `pricing_rule`：价格表/开关，仅定义某项 AI 动作是否收费、单价多少
  - “计费明细”模块：账单中心，仅负责向用户展示消费总览、趋势和明细
- 只有能绑定到具体资源的 AI 行为，才允许进入收费统计主链路
- 模型提供方（Qwen / DeepSeek / 声通）不向用户展示，用户侧只按“业务动作”理解消费

### 7.1 费用来源

- 出题费：`ai_test_plan`（当前建议免费，可保留规则但 `price_cny=0`）
- 声通评分：`st_pron_score`（每次提交跟读题扣一次）
- 对话费：`ai_conversation_question` / `ai_conversation_answer`
- 查词释义：`ai_definition`（默认免费；当调用发生在具体资源上下文中时，可纳入资源统计）
- 翻译：`ai_translate` / `ai_translate_conversation`（默认免费；可统计次数）
- TTS：`ai_tts`（默认免费；当调用发生在播放器/文章/生词本等资源上下文中时，可纳入资源统计）

### 7.2 统计需求（必须支持）

- session 级：总分、总题数、总正确率、总费用、总用时
- 题型级：数量、正确率、平均分、平均用时、费用
- 历史汇总：某个单元/文件夹/生词本累计测试次数、平均分、平均费用

备注：历史统计建议先本地落库（SQLite），后续再考虑上云同步（同一套 session/attempt schema 可直接上传）。

## 7.3 计费明细模块（统一账单中心）

该模块是用户唯一查看消费的入口，建议放在“我的”页面中。

### 首页结构

- 单日消费统计（默认显示今日）
- 最近几日消费趋势图
- AI 消费汇总（按业务动作分类）
- 资源消费汇总（按资源大类分类）

### 交互层级

- 首页不显示单笔明细，只展示汇总与入口
- 点击某个 AI 动作 → 进入该动作的消费明细页
- 点击某个资源大类（视频 / 音频 / 文章）→ 进入该大类的资源统计页
- 资源统计页先展示：
  - 文件夹汇总
  - 具体资源汇总
- 点击具体资源 → 进入该资源的消费明细页
- 单笔扣费信息只在最后一级详情页显示

### 明细页字段（最少）

- 资源大类
- 资源标题
- 页面（scene）
- 操作（entry）
- 时间
- 金额
- 建议补充：文件夹标题、规则名称

## 7.4 用户侧统计口径（最终确认）

### 一级：按业务动作分类

- AI 对话
- 跟读评分
- AI 出题
- AI 释义
- AI 翻译
- AI 朗读（TTS）

### 二级：按资源分类

- 视频
- 音频
- 文章
- 生词本（仅当缺少原始来源时作为兜底分类）

### 三级：资源层级

- 视频 / 音频 / 文章先按文件夹聚合
- 再下钻到具体资源
- 最后进入单笔消费明细

### 生词本来源归类规则

- 默认归到原始来源资源
- 如果来源资源缺失，再归到“生词本”

## 7.5 usage_event 必填元信息（账单统计主轴）

后续所有进入收费体系或进入消费统计体系的 AI 调用，都应在 `usage_event.meta` 中补齐以下字段：

- `action_key`：业务动作分类键
- `action_label`：业务动作名称
- `resource_type`：`video` / `music` / `article` / `word_book`
- `resource_code`
- `resource_title`
- `folder_code`
- `folder_title`
- `source_page`
- `action_name`
- `is_chargeable`

说明：

- `scene` / `entry` 继续保留，用于排查调用来源
- `resource_type` / `resource_code` / `folder_code` 才是账单统计主轴
- 即使价格为 0，只要需要进入消费统计体系，也应尽量补齐资源信息

## 8. 生词本测试（独立 scope，但复用同一配置器）

### 8.1 组卷策略

- 从生词本抽 N 个词（策略：新词优先/错题优先/随机）
- 每个词生成 1-3 题（由配置决定）
  - 释义选择、拼写、同类词、例句填空
- 可选：AI 仅用于生成干扰项/例句（不强依赖）

### 8.2 与单元/综合的差异

- 数据源固定为生词本
- 评分更偏词汇（对错/拼写/用时）
- 不包含 AI 对话（可选加入，但默认不包含）

## 9. 扩展规划（保证后续可持续加题型）

- 题型注册表：type → generator/validator/page/scorer
- plan schema 版本号：plan_version（便于兼容）
- 出题 provider 抽象：Qwen / DeepSeek / 未来其他模型（在 Edge Function 内切换）
- 计费扩展：新增题型只需新增 rule_code，并在 ai-proxy 统一扣费与写 usage_event
