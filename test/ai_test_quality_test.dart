/// AI 自动出题质量验证测试
///
/// 本测试文件用于全面验证 AI 出题系统的质量，包括：
/// 1. 不同难度等级的参数配置是否合理
/// 2. 各题型生成逻辑是否正确
/// 3. 答案是否存在泄露、重复等问题
/// 4. AI 提示词（prompt）是否合理
///
/// 运行方式: flutter test test/ai_test_quality_test.dart
library;

import 'dart:convert';
import 'dart:math';

// ─── 测试结果收集器 ───

class TestResult {
  final String testName;
  final bool passed;
  final String message;
  final dynamic details;

  TestResult({
    required this.testName,
    required this.passed,
    required this.message,
    this.details,
  });

  @override
  String toString() {
    final icon = passed ? '✅' : '❌';
    return '$icon $testName: $message${details != null ? '\n   详情: $details' : ''}';
  }
}

class QualityReport {
  final List<TestResult> results = [];
  int passCount = 0;
  int failCount = 0;

  void add(TestResult result) {
    results.add(result);
    if (result.passed) {
      passCount++;
    } else {
      failCount++;
    }
  }

  void printReport() {
    print('\n${'=' * 80}');
    print('AI 出题质量验证报告');
    print('${'=' * 80}\n');

    // 打印所有测试结果
    for (final result in results) {
      print(result);
    }

    print('\n${'-' * 80}');
    print('总计: ${results.length} 项测试');
    print('通过: $passCount 项 ✅');
    print('失败: $failCount 项 ❌');
    if (results.isNotEmpty) {
      print('通过率: ${(passCount / results.length * 100).toStringAsFixed(1)}%');
    }
    print('${'=' * 80}\n');
  }
}

// ─── 模拟 Edge Function 的核心逻辑 ───

/// 难度参数接口
class DifficultyParams {
  final int minWords; // 组句题最小单词数
  final int maxWords; // 组句题最大单词数
  final int minWordLen; // 拼写/选择题最小单词长度
  final int maxWordLen; // 拼写/选择题最大单词长度
  final int maxSentenceLen; // 翻译/听写句子最大字符数

  DifficultyParams({
    required this.minWords,
    required this.maxWords,
    required this.minWordLen,
    required this.maxWordLen,
    required this.maxSentenceLen,
  });
}

/// 难度参数配置（与 ai-test-plan/index.ts 保持一致）
final Map<String, DifficultyParams> difficultyParamsMap = {
  'beginner': DifficultyParams(
    minWords: 3,
    maxWords: 7,
    minWordLen: 3,
    maxWordLen: 5,
    maxSentenceLen: 40,
  ),
  'elementary': DifficultyParams(
    minWords: 3,
    maxWords: 10,
    minWordLen: 3,
    maxWordLen: 7,
    maxSentenceLen: 60,
  ),
  'intermediate': DifficultyParams(
    minWords: 3,
    maxWords: 14,
    minWordLen: 3,
    maxWordLen: 14,
    maxSentenceLen: 100,
  ),
  'advanced': DifficultyParams(
    minWords: 5,
    maxWords: 18,
    minWordLen: 4,
    maxWordLen: 14,
    maxSentenceLen: 150,
  ),
  'professional': DifficultyParams(
    minWords: 6,
    maxWords: 22,
    minWordLen: 5,
    maxWordLen: 16,
    maxSentenceLen: 200,
  ),
};

// ─── 工具函数（模拟 Edge Function） ───

List<String> shuffleList(List<String> arr) {
  final a = List<String>.from(arr);
  final random = Random();
  for (int i = a.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final temp = a[i];
    a[i] = a[j];
    a[j] = temp;
  }
  return a;
}

List<String> uniqueList(List<String> arr) {
  final seen = <String>{};
  final out = <String>[];
  for (final x in arr) {
    if (seen.contains(x)) continue;
    seen.add(x);
    out.add(x);
  }
  return out;
}

List<String> tokenizeWords(String text) {
  final regex = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");
  return regex
      .allMatches(text)
      .map((m) => m.group(0)!.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

Map<String, dynamic> maskWord(String sentence, String word) {
  // 简化版：直接用单词匹配
  final pattern = RegExp(
    r'\b' + RegExp.escape(word) + r'\b',
    caseSensitive: false,
  );
  if (!pattern.hasMatch(sentence)) {
    return {'masked': sentence, 'ok': false};
  }
  final masked = sentence.replaceAll(pattern, '_____');
  return {'masked': masked, 'ok': true};
}

// ─── 题目生成函数（模拟 Edge Function） ───

/// 组句题
List<Map<String, dynamic>> pickReorderItems(
  List<String> sentences,
  int count,
  DifficultyParams params,
) {
  final items = <Map<String, dynamic>>[];
  final candidates = <Map<String, dynamic>>[];

  for (final s in sentences) {
    final words = tokenizeWords(s);
    if (words.length >= params.minWords && words.length <= params.maxWords) {
      candidates.add({'s': s, 'w': words});
    }
  }

  final picked = shuffleList(
    candidates.map((x) => x['s'] as String).toList(),
  ).take(count);

  for (final s in picked) {
    final words = tokenizeWords(s);
    final options = shuffleList(words);
    items.add({
      'type': 'reorder',
      'prompt': '请按正确顺序组句',
      'sentence': s,
      'options': options,
      'answer': words,
    });
  }

  return items;
}

/// 提取词池
List<String> extractWordPool(List<String> sentences, DifficultyParams params) {
  final words = <String>[];
  for (final s in sentences) {
    for (final w in tokenizeWords(s)) {
      final lw = w.toLowerCase();
      if (lw.length < params.minWordLen) continue;
      if (lw.length > params.maxWordLen) continue;
      words.add(lw);
    }
  }
  return uniqueList(words);
}

/// 拼写填空题
List<Map<String, dynamic>> pickSpellingItems(
  List<String> sentences,
  List<String> wordPool,
  int count,
) {
  final items = <Map<String, dynamic>>[];
  final shuffledWords = shuffleList(wordPool);

  for (final w in shuffledWords) {
    if (items.length >= count) break;

    String? chosen;
    String masked = '';

    for (final s in shuffleList(sentences).take(40)) {
      final m = maskWord(s, w);
      if (m['ok'] == true) {
        chosen = s;
        masked = m['masked'];
        break;
      }
    }

    if (chosen == null) continue;

    final letters = w.toUpperCase().split('');
    final extra = min(6, max(2, 12 - letters.length));
    final pool = [...letters];
    final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    final random = Random();

    for (int i = 0; i < extra; i++) {
      pool.add(alphabet[random.nextInt(alphabet.length)]);
    }

    items.add({
      'type': 'spelling',
      'prompt': '请根据句子拼写缺失单词',
      'sentence': chosen,
      'masked': masked,
      'answer': w,
      'letter_pool': shuffleList(pool),
    });
  }

  return items;
}

/// 选择题（MCQ）
List<Map<String, dynamic>> pickMcqItems(
  List<String> sentences,
  List<String> wordPool,
  int count,
) {
  final items = <Map<String, dynamic>>[];
  final pool = shuffleList(wordPool);

  for (final w in pool) {
    if (items.length >= count) break;

    String? chosen;
    String masked = '';

    for (final s in shuffleList(sentences).take(40)) {
      final m = maskWord(s, w);
      if (m['ok'] == true) {
        chosen = s;
        masked = m['masked'];
        break;
      }
    }

    if (chosen == null) continue;

    final distractors = shuffleList(
      wordPool.where((x) => x != w).toList(),
    ).take(3).toList();
    if (distractors.length < 3) continue;

    final options = shuffleList([w, ...distractors]);
    items.add({
      'type': 'mcq',
      'prompt': '请选择最合适的单词填空',
      'sentence': chosen,
      'masked': masked,
      'options': options,
      'answer_index': options.indexOf(w),
      'correct_answer': w,
    });
  }

  return items;
}

/// 听音选词
List<Map<String, dynamic>> pickListenChooseItems(
  List<String> wordPool,
  int count,
) {
  final items = <Map<String, dynamic>>[];

  for (final w in shuffleList(wordPool)) {
    if (items.length >= count) break;

    final distractors = shuffleList(
      wordPool.where((x) => x != w).toList(),
    ).take(3).toList();
    if (distractors.length < 3) continue;

    final options = shuffleList([w, ...distractors]);
    items.add({
      'type': 'listen_choose',
      'prompt': 'Listen and select the word you hear',
      'prompt_cn': '听发音，选择你听到的单词',
      'options': options,
      'answer': w,
      'answer_index': options.indexOf(w),
      'ref_text': w,
    });
  }

  return items;
}

/// 听音辩义
List<Map<String, dynamic>> pickListenMeaningItems(
  List<String> wordPool,
  int count,
) {
  final items = <Map<String, dynamic>>[];

  for (final w in shuffleList(wordPool)) {
    if (items.length >= count) break;

    final distractors = shuffleList(
      wordPool.where((x) => x != w).toList(),
    ).take(3).toList();
    if (distractors.length < 3) continue;

    final options = shuffleList([w, ...distractors]);
    items.add({
      'type': 'listen_meaning',
      'prompt': 'Listen and select the word with similar meaning',
      'prompt_cn': '听发音，选择与该词意思最接近的选项',
      'options': options,
      'answer': w,
      'answer_index': options.indexOf(w),
      'ref_text': w,
    });
  }

  return items;
}

/// 听音回复
List<Map<String, dynamic>> pickListenReplyItems(
  List<String> sentences,
  List<String> wordPool,
  int count,
  DifficultyParams params,
) {
  final items = <Map<String, dynamic>>[];
  final candidates = sentences
      .where((s) => s.length <= params.maxSentenceLen && s.trim().length > 10)
      .map((s) => s.trim())
      .toList();

  for (final s in shuffleList(candidates)) {
    if (items.length >= count) break;

    final words = tokenizeWords(s);
    if (words.length < 3) continue;

    final keyWord = words[(words.length / 2).floor()].toLowerCase();
    final distractors = shuffleList(
      wordPool.where((x) => x != keyWord).toList(),
    ).take(3).toList();
    if (distractors.length < 3) continue;

    final options = shuffleList([keyWord, ...distractors]);
    items.add({
      'type': 'listen_reply',
      'prompt': 'Listen to the question and select the best answer: "$s"',
      'prompt_cn': '听以下句子，选择最佳回答：「$s」',
      'options': options,
      'answer': keyWord,
      'answer_index': options.indexOf(keyWord),
      'ref_text': s,
    });
  }

  return items;
}

/// 释义选择
List<Map<String, dynamic>> pickDefinitionChoiceItems(
  List<String> wordPool,
  int count,
) {
  final items = <Map<String, dynamic>>[];
  final random = Random();

  for (final w in shuffleList(wordPool)) {
    if (items.length >= count) break;

    final distractors = shuffleList(
      wordPool.where((x) => x != w).toList(),
    ).take(3).toList();
    if (distractors.length < 3) continue;

    final options = shuffleList([w, ...distractors]);
    final isEnglishToChinese = random.nextDouble() > 0.5;

    if (isEnglishToChinese) {
      items.add({
        'type': 'definition_choice',
        'prompt': 'What is the meaning of "$w"?',
        'prompt_cn': '单词 "$w" 的意思是什么？',
        'display_text': w,
        'options': options,
        'answer': w,
        'answer_index': options.indexOf(w),
        'sub_type': 'en_to_cn',
      });
    } else {
      items.add({
        'type': 'definition_choice',
        'prompt': 'Which word matches the meaning?',
        'prompt_cn': '哪个单词符合给出的含义？（提示词：$w）',
        'display_text': w,
        'options': options,
        'answer': w,
        'answer_index': options.indexOf(w),
        'sub_type': 'cn_to_en',
      });
    }
  }

  return items;
}

/// 英义互译
List<Map<String, dynamic>> pickTranslateMeaningItems(
  List<String> sentences,
  List<String> wordPool,
  int count,
  DifficultyParams params,
) {
  final items = <Map<String, dynamic>>[];
  final candidates = sentences
      .where((s) => s.length <= params.maxSentenceLen && s.length > 10)
      .map((s) => s.trim())
      .toList();

  for (final s in shuffleList(candidates)) {
    if (items.length >= count) break;

    final words = tokenizeWords(s);
    if (words.length < 3) continue;

    final otherSentences = shuffleList(
      sentences
          .where((x) => x != s && x.length <= params.maxSentenceLen)
          .toList(),
    ).take(3).toList();

    if (otherSentences.length < 3) continue;

    final options = shuffleList([s, ...otherSentences]);
    items.add({
      'type': 'translate_meaning',
      'prompt':
          'Read the sentence and select the option with the closest meaning',
      'prompt_cn': '阅读以下英文句子，选择与原文含义最接近的选项',
      'display_text': s,
      'options': options,
      'answer': s,
      'answer_index': options.indexOf(s),
    });
  }

  return items;
}

/// 词性测试
List<Map<String, dynamic>> pickWordRelationItems(
  List<String> wordPool,
  int count,
) {
  final items = <Map<String, dynamic>>[];
  final relationTypes = [
    {
      'key': 'synonym',
      'prompt': 'Select synonyms of',
      'prompt_cn': '选择以下单词的同义词（可多选）',
    },
    {
      'key': 'antonym',
      'prompt': 'Select antonyms of',
      'prompt_cn': '选择以下单词的反义词（可多选）',
    },
    {
      'key': 'same_category',
      'prompt': 'Select words in the same category as',
      'prompt_cn': '选择与以下单词同类的词（可多选）',
    },
  ];

  for (final w in shuffleList(wordPool)) {
    if (items.length >= count) break;

    final relation = relationTypes[items.length % relationTypes.length];
    final others = shuffleList(wordPool.where((x) => x != w).toList());

    if (others.length < 5) continue;

    final correctAnswers = others.take(2).toList();
    final distractors = others.skip(2).take(4).toList();
    final options = shuffleList([...correctAnswers, ...distractors]);
    final answerIndices = correctAnswers
        .map((a) => options.indexOf(a))
        .toList();

    items.add({
      'type': 'word_relation',
      'prompt': '${relation['prompt']} "$w"',
      'prompt_cn': '${relation['prompt_cn']}：「$w」',
      'display_text': w,
      'relation_type': relation['key'],
      'options': options,
      'answer_indices': answerIndices,
      'answers': correctAnswers,
    });
  }

  return items;
}

/// 跟读单词
List<Map<String, dynamic>> pickWordPronItems(List<String> wordPool, int count) {
  final items = <Map<String, dynamic>>[];

  for (final w in shuffleList(wordPool)) {
    if (items.length >= count) break;

    items.add({
      'type': 'word_pron',
      'prompt': 'Please read aloud: $w',
      'prompt_cn': '请跟读以下单词：$w',
      'ref_text': w,
      'answer': w,
    });
  }

  return items;
}

/// 跟读短语
List<Map<String, dynamic>> pickPhrasePronItems(
  List<String> sentences,
  int count,
  DifficultyParams params,
) {
  final items = <Map<String, dynamic>>[];
  final random = Random();

  for (final s in shuffleList(sentences)) {
    if (items.length >= count) break;

    final words = tokenizeWords(s);
    if (words.length < 3) continue;

    final phraseLen = min(4, max(2, (words.length / 2).floor()));
    final startIdx = random.nextInt(max(1, words.length - phraseLen));
    final phrase = words.sublist(startIdx, startIdx + phraseLen).join(' ');

    items.add({
      'type': 'phrase_pron',
      'prompt': 'Please read aloud: $phrase',
      'prompt_cn': '请跟读以下短语：$phrase',
      'ref_text': phrase,
      'answer': phrase,
    });
  }

  return items;
}

/// 跟读句子
List<Map<String, dynamic>> pickSentencePronItems(
  List<String> sentences,
  int count,
  DifficultyParams params,
) {
  final items = <Map<String, dynamic>>[];
  final candidates = sentences
      .where(
        (s) =>
            s.length <= params.maxSentenceLen &&
            tokenizeWords(s).length >= params.minWords,
      )
      .map((s) => s.trim())
      .toList();

  for (final s in shuffleList(candidates)) {
    if (items.length >= count) break;

    items.add({
      'type': 'sentence_pron',
      'prompt': 'Please read aloud: $s',
      'prompt_cn': '请跟读以下句子：$s',
      'ref_text': s,
      'answer': s,
    });
  }

  return items;
}

// ─── 测试数据 ───

/// 模拟字幕数据（包含不同难度的句子）
const List<String> testSentences = [
  // 简单句子（适合 beginner）
  'I have a cat.',
  'She likes apples.',
  'The sun is bright.',
  'He can run fast.',
  'We go to school.',
  'They play games.',
  'It is a good day.',
  'My dog is big.',
  'You are happy.',
  'This is my book.',

  // 中等句子（适合 elementary/intermediate）
  'The weather today is quite nice for a walk in the park.',
  'She decided to buy a new computer because her old one was too slow.',
  'They have been studying English for almost three years now.',
  'I would like to know more about your plans for the weekend.',
  'The movie that we watched last night was really interesting.',
  'He always forgets to bring his homework to class on time.',
  'We need to finish this project before the deadline next week.',
  'She asked me if I could help her with her math homework.',
  'The restaurant around the corner serves delicious Italian food.',
  'My brother and I are planning to visit our grandparents soon.',

  // 复杂句子（适合 advanced/professional）
  'Notwithstanding the aforementioned circumstances, the committee reached an unanimous decision regarding the implementation of new regulatory frameworks.',
  'The unprecedented proliferation of artificial intelligence technologies has fundamentally transformed contemporary paradigms across various industrial sectors.',
  'Consequently, stakeholders must comprehensively evaluate the multifaceted implications inherent in adopting such sophisticated computational methodologies.',
  'The interdisciplinary nature of modern research necessitates collaboration among experts from diverse academic backgrounds and institutional affiliations.',
  'Furthermore, empirical evidence suggests that socioeconomic factors significantly influence educational outcomes in underserved communities worldwide.',
];

// ─── 验证函数 ───

/// 检查答案是否泄露在选项中（除了正确答案本身）
bool checkAnswerNotLeaked(Map<String, dynamic> item) {
  final answer = item['answer'] ?? item['correct_answer'];
  final options = item['options'] as List<dynamic>?;

  if (answer == null || options == null) return true;

  // 检查是否有重复的正确答案出现在选项中
  final answerStr = answer.toString().toLowerCase();
  final answerCount = options
      .where((o) => o.toString().toLowerCase() == answerStr)
      .length;
  if (answerCount > 1) {
    return false; // 答案重复出现
  }

  return true;
}

/// 检查选项中是否有重复
bool checkNoDuplicateOptions(Map<String, dynamic> item) {
  final options = item['options'] as List<dynamic>?;
  if (options == null) return true;

  final uniqueOptions = options.toSet();
  return uniqueOptions.length == options.length;
}

/// 检查 prompt 是否包含答案泄露
bool checkPromptNoAnswerLeak(Map<String, dynamic> item) {
  item['prompt']?.toString() ?? '';
  final promptCn = item['prompt_cn']?.toString() ?? '';
  final answer =
      item['answer']?.toString() ?? item['correct_answer']?.toString() ?? '';

  if (answer.isEmpty) return true;

  // 对于特定题型，检查是否有不当的答案泄露
  if (item['type'] == 'definition_choice' || item['type'] == 'listen_meaning') {
    // 这些题型不应该在中文提示中直接给出英文答案
    if (promptCn.toLowerCase().contains(answer.toLowerCase()) &&
        item['sub_type'] == 'en_to_cn') {
      // en_to_cn 类型不应该在提示中包含答案
      return false;
    }
  }

  return true;
}

/// 检查干扰项是否与答案过于相似
bool checkDistractorQuality(Map<String, dynamic> item) {
  final answer =
      (item['answer'] ?? item['correct_answer'])?.toString().toLowerCase() ??
      '';
  final options = item['options'] as List<dynamic>?;

  if (answer.isEmpty || options == null) return true;

  for (final opt in options) {
    final optStr = opt.toString().toLowerCase();
    if (optStr == answer) continue; // 跳过正确答案

    // 检查干扰项是否只是答案的子串或超集（简单检查）
    if (optStr.contains(answer) || answer.contains(optStr)) {
      if ((optStr.length - answer.length).abs() <= 2) {
        return false; // 干扰项和答案太相似
      }
    }
  }

  return true;
}

// ─── 辅助打印函数 ───

void printItemDetail(Map<String, dynamic> item, [int? index]) {
  final prefix = index != null ? '   │   ├── 第$index题' : '   │   ├──';
  print('$prefix [${item['type']}]');
  print('   │   │   Prompt: ${item['prompt_cn'] ?? item['prompt']}');
  if (item['sentence'] != null) print('   │   │   句子: ${item['sentence']}');
  if (item['masked'] != null) print('   │   │   挖空: ${item['masked']}');
  if (item['options'] != null) {
    print('   │   │   选项: ${jsonEncode(item['options'])}');
  }
  if (item['answer'] != null) print('   │   │   ✔️ 答案: ${item['answer']}');
  if (item['correct_answer'] != null) {
    print('   │   │   ✔️ 正确答案: ${item['correct_answer']}');
  }
  if (item['answer_index'] != null) {
    print('   │   │   答案索引: ${item['answer_index']}');
  }
  if (item['answers'] != null) {
    print('   │   │   ✔️ 多选答案: ${jsonEncode(item['answers'])}');
  }
  if (item['letter_pool'] != null) {
    print('   │   │   字母池: ${jsonEncode(item['letter_pool'])}');
  }
  if (item['ref_text'] != null) print('   │   │   参考文本: ${item['ref_text']}');
  if (item['sub_type'] != null) print('   │   │   子类型: ${item['sub_type']}');
  if (item['relation_type'] != null) {
    print('   │   │   关系类型: ${item['relation_type']}');
  }
}

// ─── 主测试函数 ───

void main() {
  final report = QualityReport();

  print('\n🔍 开始 AI 出题质量验证测试...\n');

  // ═══════════════════════════════════════════════════════════════
  // 第一部分：显示 AI 提示词分析
  // ═══════════════════════════════════════════════════════════════

  print('=' * 80);
  print('【第一部分】AI 提示词（Prompt）展示与分析');
  print('${'=' * 80}\n');

  _analyzePrompts(report);

  // ═══════════════════════════════════════════════════════════════
  // 第二部分：难度参数验证
  // ═══════════════════════════════════════════════════════════════

  print('\n${'=' * 80}');
  print('【第二部分】难度参数验证');
  print('${'=' * 80}\n');

  _testDifficultyParams(report);

  // ═══════════════════════════════════════════════════════════════
  // 第三部分：各题型生成测试
  // ═══════════════════════════════════════════════════════════════

  print('\n${'=' * 80}');
  print('【第三部分】各题型生成测试（5个难度 × 12种题型）');
  print('${'=' * 80}\n');

  _testAllQuestionTypes(report);

  // ═══════════════════════════════════════════════════════════════
  // 第四部分：答案合理性验证
  // ═══════════════════════════════════════════════════════════════

  print('\n${'=' * 80}');
  print('【第四部分】答案合理性验证');
  print('${'=' * 80}\n');

  _testAnswerQuality(report);

  // ═══════════════════════════════════════════════════════════════
  // 第五部分：已知问题专项检测
  // ═══════════════════════════════════════════════════════════════

  print('\n${'=' * 80}');
  print('【第五部分】已知问题专项检测（答案重复、信息泄露等）');
  print('${'=' * 80}\n');

  _testKnownIssues(report);

  // 输出最终报告
  report.printReport();
}

// ─── 第一部分：AI 提示词分析 ───

void _analyzePrompts(QualityReport report) {
  print('┌─────────────────────────────────────────────────────────────┐');
  print('│  各题型 AI 提示词（Prompt）一览                              │');
  print('└─────────────────────────────────────────────────────────────┘\n');

  final prompts = {
    'reorder': {'prompt': '请按正确顺序组句', 'description': '组句题：将打乱的单词重新排列成正确的句子'},
    'spelling': {'prompt': '请根据句子拼写缺失单词', 'description': '拼写填空：根据上下文补全被挖空的单词'},
    'mcq': {'prompt': '请选择最合适的单词填空', 'description': '选择题：从4个选项中选择正确的单词填入空格'},
    'listen_choose': {
      'prompt': 'Listen and select the word you hear / 听发音，选择你听到的单词',
      'description': '听音选词：播放单词发音，从选项中选出听到的词',
    },
    'listen_meaning': {
      'prompt':
          'Listen and select the word with similar meaning / 听发音，选择与该词意思最接近的选项',
      'description': '听音辩义：播放单词发音，选择意思最接近的选项',
      'issue': '当前实现：选项都是其他英文单词而非释义，无法真正测试"辩义"能力',
    },
    'listen_reply': {
      'prompt':
          'Listen to the question and select the best answer / 听以下句子，选择最佳回答',
      'description': '听音回复：播放问题，选择最佳回答',
      'issue': '当前实现：答案是从句子中间随机取的词，不一定是真正的"回答"',
    },
    'definition_choice': {
      'prompt': 'What is the meaning of "{word}"? / 哪个单词符合给出的含义？（提示词：{word}）',
      'description': '释义选择：英译中或中译英',
      'issue': '当前实现：cn_to_en 子类型在提示词中直接暴露了答案（提示词：{word}），且选项都是英文单词而非中文释义',
    },
    'translate_meaning': {
      'prompt':
          'Read the sentence and select the option with the closest meaning / 阅读以下英文句子，选择与原文含义最接近的选项',
      'description': '英义互译：选择与原文含义最接近的选项',
      'issue': '当前实现：选项是其他英文句子而非中文翻译，无法真正测试翻译能力',
    },
    'word_relation': {
      'prompt':
          'Select synonyms/antonyms/same category words of "{word}" / 选择以下单词的同义词/反义词/同类词（可多选）',
      'description': '词性测试：选择同义词、反义词或同类词',
      'issue': '当前实现：正确答案是随机选取的，并非真正的同义词/反义词',
    },
    'word_pron': {
      'prompt': 'Please read aloud: {word} / 请跟读以下单词：{word}',
      'description': '跟读单词：用户朗读单词并进行评分',
    },
    'phrase_pron': {
      'prompt': 'Please read aloud: {phrase} / 请跟读以下短语：{phrase}',
      'description': '跟读短语：用户朗读短语并进行评分',
    },
    'sentence_pron': {
      'prompt': 'Please read aloud: {sentence} / 请跟读以下句子：{sentence}',
      'description': '句子跟读：用户朗读句子并进行评分',
    },
  };

  prompts.forEach((type, info) {
    print('┌─ 【$type】${info['description']} ─────────────────────────────┐');
    print('│ Prompt: ${info['prompt']}');
    if (info.containsKey('issue')) {
      print('│ ⚠️  潜在问题: ${info['issue']}');
      report.add(
        TestResult(
          testName: 'Prompt 分析 [$type]',
          passed: false,
          message: '发现潜在问题',
          details: info['issue'],
        ),
      );
    } else {
      report.add(
        TestResult(
          testName: 'Prompt 分析 [$type]',
          passed: true,
          message: 'Prompt 设计合理',
        ),
      );
    }
    print('└────────────────────────────────────────────────────────────┘\n');
  });
}

// ─── 第二部分：难度参数验证 ───

void _testDifficultyParams(QualityReport report) {
  final difficulties = [
    'beginner',
    'elementary',
    'intermediate',
    'advanced',
    'professional',
  ];

  print('📊 难度参数对比表:\n');
  print('│ 难度     │ 最小词数 │ 最大词数 │ 最小词长 │ 最大词长 │ 最大句长 │');
  print('│──────────│─────────│─────────│─────────│─────────│─────────│');

  for (final diff in difficulties) {
    final params = difficultyParamsMap[diff]!;
    print(
      '│ ${diff.padRight(8)} │ ${params.minWords.toString().padLeft(7)} │ ${params.maxWords.toString().padLeft(7)} │ ${params.minWordLen.toString().padLeft(7)} │ ${params.maxWordLen.toString().padLeft(7)} │ ${params.maxSentenceLen.toString().padLeft(7)} │',
    );
  }
  print('');

  // 验证难度递增规律
  for (int i = 1; i < difficulties.length; i++) {
    final prev = difficultyParamsMap[difficulties[i - 1]]!;
    final curr = difficultyParamsMap[difficulties[i]]!;

    // 检查最小词数是否非递减
    final minWordsOk = curr.minWords >= prev.minWords;
    report.add(
      TestResult(
        testName:
            '难度递增验证 [${difficulties[i]}].minWords >= ${difficulties[i - 1]}',
        passed: minWordsOk,
        message: minWordsOk
            ? '${curr.minWords} >= ${prev.minWords} ✓'
            : '${curr.minWords} < ${prev.minWords} ✗',
        details: {'current': curr.minWords, 'previous': prev.minWords},
      ),
    );

    // 检查最大词数是否递增
    final maxWordsOk = curr.maxWords > prev.maxWords;
    report.add(
      TestResult(
        testName:
            '难度递增验证 [${difficulties[i]}].maxWords > ${difficulties[i - 1]}',
        passed: maxWordsOk,
        message: maxWordsOk
            ? '${curr.maxWords} > ${prev.maxWords} ✓'
            : '${curr.maxWords} <= ${prev.maxWords} ✗',
      ),
    );

    // 检查最大句长是否递增
    final maxSentLenOk = curr.maxSentenceLen > prev.maxSentenceLen;
    report.add(
      TestResult(
        testName:
            '难度递增验证 [${difficulties[i]}].maxSentenceLen > ${difficulties[i - 1]}',
        passed: maxSentLenOk,
        message: maxSentLenOk
            ? '${curr.maxSentenceLen} > ${prev.maxSentenceLen} ✓'
            : '${curr.maxSentenceLen} <= ${prev.maxSentenceLen} ✗',
      ),
    );
  }

  // 验证 beginner 参数确实更简单
  final beginner = difficultyParamsMap['beginner']!;
  report.add(
    TestResult(
      testName: '入门级参数合理性',
      passed:
          beginner.maxWords <= 7 &&
          beginner.maxWordLen <= 5 &&
          beginner.maxSentenceLen <= 40,
      message: '入门级应使用简短句子和小词汇',
      details:
          'maxWords=${beginner.maxWords}, maxWordLen=${beginner.maxWordLen}, maxSentenceLen=${beginner.maxSentenceLen}',
    ),
  );

  // 验证 professional 参数确实更难
  final professional = difficultyParamsMap['professional']!;
  report.add(
    TestResult(
      testName: '专业级参数合理性',
      passed:
          professional.minWords >= 6 &&
          professional.minWordLen >= 5 &&
          professional.maxSentenceLen >= 200,
      message: '专业级应使用长句和复杂词汇',
      details:
          'minWords=${professional.minWords}, minWordLen=${professional.minWordLen}, maxSentenceLen=${professional.maxSentenceLen}',
    ),
  );
}

// ─── 第三部分：各题型生成测试 ───

void _testAllQuestionTypes(QualityReport report) {
  final difficulties = ['beginner', 'intermediate', 'advanced'];

  for (final difficulty in difficulties) {
    final params = difficultyParamsMap[difficulty]!;
    final wordPool = extractWordPool(testSentences, params);

    print('\n📝 难度级别: $difficulty (${params.maxSentenceLen}字符以内)');
    print('   词池大小: ${wordPool.length} 个单词\n');

    if (wordPool.length < 4) {
      print('   ⚠️ 词池不足4个单词，跳过选择题型测试\n');
      continue;
    }

    // 测试每种题型
    _testAndPrintType(
      'reorder (组句)',
      () => pickReorderItems(testSentences, 2, params),
      report,
    );
    _testAndPrintType(
      'spelling (拼写)',
      () => pickSpellingItems(testSentences, wordPool, 2),
      report,
    );
    _testAndPrintType(
      'mcq (选择)',
      () => pickMcqItems(testSentences, wordPool, 2),
      report,
    );
    _testAndPrintType(
      'listen_choose (听音选词)',
      () => pickListenChooseItems(wordPool, 2),
      report,
    );
    _testAndPrintType(
      'listen_meaning (听音辩义)',
      () => pickListenMeaningItems(wordPool, 2),
      report,
    );
    _testAndPrintType(
      'listen_reply (听音回复)',
      () => pickListenReplyItems(testSentences, wordPool, 2, params),
      report,
    );
    _testAndPrintType(
      'definition_choice (释义选择)',
      () => pickDefinitionChoiceItems(wordPool, 2),
      report,
    );
    _testAndPrintType(
      'translate_meaning (英义互译)',
      () => pickTranslateMeaningItems(testSentences, wordPool, 2, params),
      report,
    );
    _testAndPrintType(
      'word_relation (词性测试)',
      () => pickWordRelationItems(wordPool, 2),
      report,
    );
    _testAndPrintType(
      'word_pron (跟读单词)',
      () => pickWordPronItems(wordPool, 2),
      report,
    );
    _testAndPrintType(
      'phrase_pron (跟读短语)',
      () => pickPhrasePronItems(testSentences, 2, params),
      report,
    );
    _testAndPrintType(
      'sentence_pron (跟读句子)',
      () => pickSentencePronItems(testSentences, 2, params),
      report,
    );
  }
}

void _testAndPrintType(
  String typeName,
  List<Map<String, dynamic>> Function() generator,
  QualityReport report,
) {
  try {
    final items = generator();

    report.add(
      TestResult(
        testName: '题型生成 [$typeName]',
        passed: items.isNotEmpty,
        message: '生成了 ${items.length} 道题目',
      ),
    );

    if (items.isNotEmpty) {
      print('   ├── $typeName: 生成 ${items.length} 题 ✅');
      for (int i = 0; i < items.length; i++) {
        printItemDetail(items[i], i + 1);
      }
    } else {
      print('   ├── $typeName: 未生成题目（可能词池/句子不足）⚠️');
    }
  } catch (e) {
    report.add(
      TestResult(
        testName: '题型生成 [$typeName]',
        passed: false,
        message: '生成失败: $e',
      ),
    );
    print('   ├── $typeName: Error: $e ❌');
  }
}

// ─── 第四部分：答案质量验证 ───

void _testAnswerQuality(QualityReport report) {
  print('\n🔍 答案质量深度验证\n');

  // 使用 intermediate 难度进行全面测试
  final params = difficultyParamsMap['intermediate']!;
  final wordPool = extractWordPool(testSentences, params);

  if (wordPool.length < 8) {
    print('⚠️ 词池不足，跳过答案质量测试');
    return;
  }

  // 生成足够多的题目进行验证
  final allItems = <Map<String, dynamic>>[
    ...pickMcqItems(testSentences, wordPool, 5),
    ...pickListenChooseItems(wordPool, 5),
    ...pickListenMeaningItems(wordPool, 5),
    ...pickDefinitionChoiceItems(wordPool, 5),
    ...pickSpellingItems(testSentences, wordPool, 5),
    ...pickReorderItems(testSentences, 5, params),
    ...pickTranslateMeaningItems(testSentences, wordPool, 5, params),
    ...pickWordRelationItems(wordPool, 5),
    ...pickListenReplyItems(testSentences, wordPool, 5, params),
  ];

  print('共生成 ${allItems.length} 道题目进行质量验证\n');

  // 验证1：答案唯一性
  int leakCount = 0;
  for (final item in allItems) {
    if (!checkAnswerNotLeaked(item)) {
      leakCount++;
      print('❌ 答案泄露/重复:');
      printItemDetail(item);
      print('');
    }
  }

  report.add(
    TestResult(
      testName: '答案唯一性验证',
      passed: leakCount == 0,
      message: leakCount == 0 ? '所有题目答案均唯一' : '$leakCount 道题存在答案重复/泄露',
      details: {'leakCount': leakCount, 'totalItems': allItems.length},
    ),
  );

  // 验证2：选项无重复
  int dupOptionCount = 0;
  for (final item in allItems) {
    if (!checkNoDuplicateOptions(item)) {
      dupOptionCount++;
      print('❌ 选项重复:');
      printItemDetail(item);
      print('');
    }
  }

  report.add(
    TestResult(
      testName: '选项无重复验证',
      passed: dupOptionCount == 0,
      message: dupOptionCount == 0 ? '所有题目选项均无重复' : '$dupOptionCount 道题存在重复选项',
    ),
  );

  // 验证3：Prompt 无答案泄露
  int promptLeakCount = 0;
  for (final item in allItems) {
    if (!checkPromptNoAnswerLeak(item)) {
      promptLeakCount++;
      print('❌ Prompt 泄露答案:');
      printItemDetail(item);
      print('');
    }
  }

  report.add(
    TestResult(
      testName: 'Prompt 答案泄露验证',
      passed: promptLeakCount == 0,
      message: promptLeakCount == 0
          ? '所有 Prompt 均无答案泄露'
          : '$promptLeakCount 道 Prompt 存在答案泄露',
    ),
  );

  // 验证4：干扰项质量
  int poorDistractorCount = 0;
  for (final item in allItems) {
    if (!checkDistractorQuality(item)) {
      poorDistractorCount++;
      print('⚠️ 干扰项质量差（过于相似）:');
      printItemDetail(item);
      print('');
    }
  }

  report.add(
    TestResult(
      testName: '干扰项质量验证',
      passed: poorDistractorCount == 0,
      message: poorDistractorCount == 0
          ? '所有干扰项质量良好'
          : '$poorDistractorCount 道题干扰项过于相似',
    ),
  );
}

// ─── 第五部分：已知问题专项检测 ───

void _testKnownIssues(QualityReport report) {
  print('🐛 用户反馈问题专项检测\n');

  // 问题1：definition_choice 的 cn_to_en 类型在提示词中泄露答案
  print('--- 问题1：definition_choice 提示词泄露答案 ---\n');

  final wordPool = [
    'one',
    'two',
    'apple',
    'cat',
    'dog',
    'happy',
    'run',
    'beautiful',
  ];
  final defItems = pickDefinitionChoiceItems(wordPool, 10);

  int leakFound = 0;
  for (final item in defItems) {
    if (item['sub_type'] == 'cn_to_en') {
      final promptCn = item['prompt_cn']?.toString() ?? '';
      final answer = item['answer']?.toString() ?? '';

      if (promptCn.toLowerCase().contains(answer.toLowerCase())) {
        leakFound++;
        print('❌ 发现答案泄露:');
        print('   Prompt CN: $promptCn');
        print('   Answer: $answer');
        print('   Options: ${jsonEncode(item['options'])}');
        print('');
      }
    }
  }

  report.add(
    TestResult(
      testName: '[严重] definition_choice cn_to_en 答案泄露',
      passed: leakFound == 0,
      message: leakFound == 0
          ? '未发现答案泄露'
          : '$leakFound 处发现提示词直接包含答案！用户可以直接从提示中看到正确答案',
      details: {'leakCount': leakFound, '影响': '用户无需知道答案即可答对，测试无效'},
    ),
  );

  // 问题2：listen_meaning 选项不是释义而是其他单词
  print('--- 问题2：listen_meaning 选项设计不合理 ---\n');

  final listenMeaningItems = pickListenMeaningItems(wordPool, 3);

  for (final item in listenMeaningItems) {
    final options = item['options'] as List<dynamic>?;
    final allEnglish =
        options?.every((o) => RegExp(r'^[a-zA-Z]+$').hasMatch(o.toString())) ??
        false;

    print('题型: ${item['type']}');
    print('Prompt: ${item['prompt_cn']}');
    print('选项: ${jsonEncode(options)}');
    print('选项全为英文单词: $allEnglish');
    print('⚠️ 问题: 该题型要求选择"意思最接近的选项"，但选项都是英文单词而非中文释义');
    print('   实际上变成了"听音选词"的重复题型，无法测试辨义能力\n');
  }

  report.add(
    TestResult(
      testName: '[设计缺陷] listen_meaning 选项非释义',
      passed: false,
      message: 'listen_meaning 选项应该是中文释义而非英文单词',
      details: {'expected': '选项应为中文释义列表', 'actual': '选项是其他英文单词'},
    ),
  );

  // 问题3：word_relation 正确答案随机选取
  print('--- 问题3：word_relation 正确答案无语义依据 ---\n');

  final relationItems = pickWordRelationItems(wordPool, 3);

  for (final item in relationItems) {
    print('题型: ${item['type']} (${item['relation_type']})');
    print('目标词: ${item['display_text']}');
    print('正确答案: ${jsonEncode(item['answers'])}');
    print('选项: ${jsonEncode(item['options'])}');
    print('⚠️ 问题: "正确答案"是从词池中随机取的，并非真正的同义词/反义词');
    print('   例如：目标词 "one" 的"同义词"可能是 "apple"，这完全是错误的\n');
  }

  report.add(
    TestResult(
      testName: '[设计缺陷] word_relation 答案无语义依据',
      passed: false,
      message: '词性测试需要语义库支持，当前随机选取答案是不正确的',
      details: {'requirement': '需要接入词典API获取真实的同义词/反义词关系'},
    ),
  );

  // 问题4：listen_reply 答案选取不合理
  print('--- 问题4：listen_reply 答案选取策略有问题 ---\n');

  final replyItems = pickListenReplyItems(
    testSentences,
    wordPool,
    3,
    difficultyParamsMap['intermediate']!,
  );

  for (final item in replyItems) {
    print('问题句: ${item['ref_text']}');
    print('答案: ${item['answer']}');
    print('选项: ${jsonEncode(item['options'])}');
    print('⚠️ 问题: 答案是句子中间的随机词，不一定是该问题的合理回答\n');
  }

  report.add(
    TestResult(
      testName: '[设计缺陷] listen_reply 答案选取不合理',
      passed: false,
      message: '听音回复的答案应该是语义完整的回复，而非句子中的随机词',
      details: {'suggestion': '需要AI生成问答对或使用预置的问答数据'},
    ),
  );

  // 问题5：translate_meaning 选项是英文句子
  print('--- 问题5：translate_meaning 选项设计问题 ---\n');

  final transItems = pickTranslateMeaningItems(
    testSentences,
    wordPool,
    3,
    difficultyParamsMap['intermediate']!,
  );

  for (final item in transItems) {
    final options = item['options'] as List<dynamic>?;

    print('原句: ${item['display_text']}');
    print('选项: ${jsonEncode(options)}');
    print('⚠️ 问题: 该题型要求选择"含义最接近的选项"，但选项是其他英文句子而非中文翻译\n');
  }

  report.add(
    TestResult(
      testName: '[设计缺陷] translate_meaning 选项非翻译',
      passed: false,
      message: '英义互译选项应该是中文翻译而非其他英文句子',
      details: {'requirement': '需要接入翻译API生成中文翻译选项'},
    ),
  );
}
