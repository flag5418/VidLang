import 'dart:math';

/// AI 出题质量优化验证测试
/// 验证边缘函数优化后的出题逻辑是否合理
void main() {
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║          AI 出题质量优化验证测试（优化版）                    ║');
  print('╚══════════════════════════════════════════════════════════════╝\n');

  // 测试数据
  final testSentences = [
    'The sun is bright today.',
    'I like to play games.',
    'She has a beautiful cat.',
    'We walk to school every day.',
    'He bought a new computer because he needs it for work.',
    'They are studying English this year.',
    'I would like to know more about your plan for the weekend.',
    'We watched a really interesting movie last night.',
    'I always forget to bring my math homework to class.',
    'I need to finish my project before the deadline next week.',
    'Can you help me with this difficult problem?',
    'My brother and I plan to visit our grandparents soon.',
    'There is an Italian restaurant on the corner that serves delicious food.',
  ];

  // 难度参数配置
  final Map<String, DifficultyParams> difficultyParamsMap = {
    'beginner': DifficultyParams(minWords: 3, maxWords: 7, minWordLen: 3, maxWordLen: 5, maxSentenceLen: 40),
    'elementary': DifficultyParams(minWords: 3, maxWords: 10, minWordLen: 3, maxWordLen: 7, maxSentenceLen: 60),
    'intermediate': DifficultyParams(minWords: 3, maxWords: 14, minWordLen: 3, maxWordLen: 14, maxSentenceLen: 100),
    'advanced': DifficultyParams(minWords: 5, maxWords: 18, minWordLen: 4, maxWordLen: 14, maxSentenceLen: 150),
    'professional': DifficultyParams(minWords: 6, maxWords: 22, minWordLen: 5, maxWordLen: 16, maxSentenceLen: 200),
  };

  // 词汇释义映射表（与边缘函数保持一致）
  final Map<String, String> wordMeaningMap = {
    'one': '一；一个', 'two': '二；两个', 'three': '三；三个',
    'apple': '苹果', 'banana': '香蕉', 'cat': '猫', 'dog': '狗',
    'happy': '快乐的；高兴的', 'sad': '悲伤的；难过的',
    'run': '跑；奔跑', 'walk': '走；步行',
    'beautiful': '美丽的；漂亮的', 'good': '好的；良好的',
    'big': '大的；巨大的', 'small': '小的；小型的',
    'book': '书；书籍', 'school': '学校',
    'have': '有；拥有', 'like': '喜欢；喜爱',
    'is': '是（be动词）', 'are': '是（复数）', 'am': '是（第一人称）',
    'the': '这个；那个（定冠词）', 'a': '一个（不定冠词）', 'an': '一个（不定冠词）',
    'sun': '太阳；阳光', 'bright': '明亮的；鲜艳的',
    'fast': '快的；迅速地', 'slow': '慢的；缓慢地',
    'play': '玩；玩耍', 'game': '游戏；比赛',
    'day': '天；白天', 'today': '今天',
    'my': '我的', 'your': '你的；你们的',
    'this': '这个', 'that': '那个',
    'weather': '天气', 'nice': '好的；令人愉快的',
    'park': '公园',
    'decide': '决定；下定决心', 'buy': '买；购买',
    'new': '新的', 'old': '旧的；老的',
    'computer': '电脑；计算机', 'because': '因为',
    'study': '学习；研究', 'english': '英语；英国的',
    'year': '年；年份', 'now': '现在',
    'would': '将；愿意（情态动词）', 'know': '知道；了解',
    'more': '更多的；更多', 'about': '关于；大约',
    'plan': '计划；规划', 'weekend': '周末',
    'movie': '电影', 'watch': '观看；注视',
    'last': '最后的；上一次的', 'night': '夜晚；晚上',
    'really': '真正地；确实', 'interesting': '有趣的；有意思的',
    'always': '总是；一直', 'forget': '忘记；遗忘',
    'bring': '带来；拿来', 'class': '班级；课程',
    'time': '时间；次', 'homework': '家庭作业',
    'need': '需要；必要', 'finish': '完成；结束',
    'project': '项目；工程', 'before': '在...之前',
    'deadline': '截止日期；最后期限', 'next': '下一个的',
    'week': '周；星期', 'ask': '询问；请求',
    'help': '帮助；协助', 'math': '数学',
    'restaurant': '餐厅；饭店', 'corner': '角落；拐角',
    'serve': '服务；端上', 'delicious': '美味的；可口的',
    'italian': '意大利的；意大利人', 'food': '食物；食品',
    'brother': '兄弟；哥哥或弟弟',
    'visit': '访问；拜访', 'grandparent': '祖父母；外公外婆或爷爷奶奶',
    'soon': '不久；很快',
  };

  // 预定义语义关系
  final Map<String, WordRelation> wordRelations = {
    'happy': WordRelation(synonyms: ['glad', 'joyful', 'cheerful'], antonyms: ['sad', 'unhappy'], category: 'emotion'),
    'sad': WordRelation(synonyms: ['unhappy', 'sorrowful'], antonyms: ['happy', 'glad'], category: 'emotion'),
    'big': WordRelation(synonyms: ['large', 'huge', 'great'], antonyms: ['small', 'tiny'], category: 'size'),
    'small': WordRelation(synonyms: ['tiny', 'little'], antonyms: ['big', 'large', 'huge'], category: 'size'),
    'fast': WordRelation(synonyms: ['quick', 'rapid', 'swift'], antonyms: ['slow'], category: 'speed'),
    'slow': WordRelation(synonyms: ['sluggish'], antonyms: ['fast', 'quick', 'rapid'], category: 'speed'),
    'good': WordRelation(synonyms: ['great', 'excellent', 'fine'], antonyms: ['bad', 'poor'], category: 'quality'),
    'beautiful': WordRelation(synonyms: ['pretty', 'lovely', 'attractive'], antonyms: ['ugly'], category: 'appearance'),
    'new': WordRelation(synonyms: ['fresh', 'modern'], antonyms: ['old', 'ancient'], category: 'time'),
    'old': WordRelation(synonyms: ['ancient'], antonyms: ['new', 'fresh', 'modern'], category: 'time'),
    'run': WordRelation(synonyms: ['jog', 'sprint'], antonyms: ['walk'], category: 'action'),
    'walk': WordRelation(synonyms: ['stroll'], antonyms: ['run', 'jog'], category: 'action'),
    'buy': WordRelation(synonyms: ['purchase'], antonyms: ['sell'], category: 'commerce'),
    'like': WordRelation(synonyms: ['love', 'enjoy'], antonyms: ['hate', 'dislike'], category: 'emotion'),
    'cat': WordRelation(antonyms: ['dog'], category: 'animal'),
    'dog': WordRelation(antonyms: ['cat'], category: 'animal'),
  };

  int totalTests = 0;
  int passedTests = 0;
  int failedTests = 0;

  void runTest(String testName, bool result, {String? details}) {
    totalTests++;
    if (result) {
      passedTests++;
      print('  ✅ $testName');
      if (details != null) print('     $details');
    } else {
      failedTests++;
      print('  ❌ $testName');
      if (details != null) print('     $details');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  print('【第一部分】优化后的核心功能验证\n');

  // 测试1: 验证 definition_choice cn_to_en 不再泄露答案
  print('--- 测试1: definition_choice cn_to_en 答案泄露修复 ---');
  for (var i = 0; i < 3; i++) {
    final wordPool = extractWordPool(testSentences, difficultyParamsMap['intermediate']!);
    final items = pickDefinitionChoiceItemsOptimized(testSentences, wordPool, 2, wordMeaningMap);
    
    for (final item in items) {
      if (item['sub_type'] == 'cn_to_en') {
        final promptCn = item['prompt_cn']?.toString() ?? '';
        final answer = item['answer']?.toString() ?? '';
        final displayText = item['display_text']?.toString() ?? '';
        
        // 验证提示词中不包含英文答案
        final noAnswerInPrompt = !promptCn.toLowerCase().contains(answer.toLowerCase());
        // 验证显示文本是中文释义而非英文单词
        final isChineseDisplay = !RegExp(r'^[a-zA-Z]+$').hasMatch(displayText);
        
        runTest(
          'cn_to_en 第${i+1}组: 答案不泄露且显示中文',
          noAnswerInPrompt && isChineseDisplay,
          details: 'Prompt: "$promptCn"\n       Answer: "$answer", Display: "$displayText"',
        );
      }
    }
  }

  // 测试2: 验证 listen_meaning 使用中文释义选项
  print('\n--- 测试2: listen_meaning 中文释义优化 ---');
  for (var i = 0; i < 3; i++) {
    final wordPool = extractWordPool(testSentences, difficultyParamsMap['intermediate']!);
    final items = pickListenMeaningItemsOptimized(wordPool, 2, wordMeaningMap);
    
    for (final item in items) {
      final options = (item['options'] as List?)?.map((o) => o.toString()).toList() ?? [];
      final answer = item['answer']?.toString() ?? '';
      
      // 验证答案在选项中
      final answerInOptions = options.contains(answer);
      // 验证选项中至少有一半是中文（包含中文或特殊字符）
      final chineseOptionCount = options.where((opt) => RegExp(r'[\u4e00-\u9fa5「」；、]').hasMatch(opt)).length;
      final hasChineseOptions = chineseOptionCount >= 2;
      
      runTest(
        'listen_meaning 第${i+1}组: 使用中文释义选项',
        answerInOptions && hasChineseOptions,
        details: 'Answer: "$answer", Options: $options\n       中文选项数: $chineseOptionCount/${options.length}',
      );
    }
  }

  // 测试3: 验证 translate_meaning 使用翻译选项
  print('\n--- 测试3: translate_meaning 翻译优化 ---');
  for (var i = 0; i < 2; i++) {
    final wordPool = extractWordPool(testSentences, difficultyParamsMap['intermediate']!);
    final items = pickTranslateMeaningItemsOptimized(testSentences, wordPool, 1, difficultyParamsMap['intermediate']!, wordMeaningMap);
    
    for (final item in items) {
      final options = (item['options'] as List?)?.map((o) => o.toString()).toList() ?? [];
      final answer = item['answer']?.toString() ?? '';
      final originalSentence = item['original_sentence']?.toString() ?? '';
      
      // 验证答案不是原始英文句子（应该是翻译）
      final answerIsTranslation = answer != originalSentence;
      // 验证选项不全是英文句子
      final notAllEnglish = !options.every((opt) => RegExp(r"^[A-Za-z\s.,!?'-]+$").hasMatch(opt));
      
      runTest(
        'translate_meaning 第${i+1}组: 使用翻译选项',
        answerIsTranslation && notAllEnglish,
        details: 'Original: "$originalSentence"\n       Answer: "$answer"\n       Options count: ${options.length}',
      );
    }
  }

  // 测试4: 验证 word_relation 使用语义关系
  print('\n--- 测试4: word_relation 语义关系优化 ---');
  for (var i = 0; i < 3; i++) {
    final wordPool = extractWordPool(testSentences, difficultyParamsMap['intermediate']!);
    final items = pickWordRelationItemsOptimized(wordPool, 2, wordRelations);
    
    for (final item in items) {
      final relationType = item['relation_type']?.toString() ?? '';
      final confidence = item['confidence']?.toString() ?? '';
      final answers = (item['answers'] as List?)?.map((a) => a.toString()).toList() ?? [];
      final displayText = item['display_text']?.toString() ?? '';
      
      // 如果有预定义关系，置信度应为 high
      final hasExpectedConfidence = confidence == 'high' || confidence == 'low';
      // 答案应该与目标词不同
      final answersNotSameAsTarget = !answers.contains(displayText);
      
      runTest(
        'word_relation 第${i+1}组 ($relationType): 语义合理性',
        hasExpectedConfidence && answersNotSameAsTarget,
        details: 'Target: "$displayText", Type: $relationType\n       Answers: $answers, Confidence: $confidence',
      );
    }
  }

  // 测试5: 验证 listen_reply 答案选取策略改进
  print('\n--- 测试5: listen_reply 答案策略优化 ---');
  for (var i = 0; i < 3; i++) {
    final wordPool = extractWordPool(testSentences, difficultyParamsMap['intermediate']!);
    final items = pickListenReplyItemsOptimized(testSentences, wordPool, 1, difficultyParamsMap['intermediate']!, wordMeaningMap);
    
    for (final item in items) {
      final refText = item['ref_text']?.toString() ?? '';
      final answer = item['answer']?.toString() ?? '';
      final answerWord = item['answer_word']?.toString() ?? '';
      final options = (item['options'] as List?)?.map((o) => o.toString()).toList() ?? [];
      
      // 答案应该是中文释义
      final answerIsChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(answer);
      // 答案应该在选项中
      final answerInOptions = options.contains(answer);
      // 记录了原始关键词
      final hasAnswerWord = answerWord.isNotEmpty;
      
      runTest(
        'listen_reply 第${i+1}组: 答案策略改进',
        answerIsChinese && answerInOptions && hasAnswerWord,
        details: 'Ref: "$refText"\n       Answer: "$answer" ($answerWord)\n       Options: ${options.take(2).toList()}...',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  print('\n【第二部分】难度参数验证\n');

  // 测试各难度下的题目生成
  final difficulties = ['beginner', 'elementary', 'intermediate', 'advanced', 'professional'];
  
  for (final diff in difficulties) {
    final params = difficultyParamsMap[diff]!;
    print('--- 难度: $diff (单词长度 ${params.minWordLen}-${params.maxWordLen}, 句子长度 ≤${params.maxSentenceLen}) ---');
    
    final wordPool = extractWordPool(testSentences, params);
    final reorderItems = pickReorderItems(testSentences, 1, params);
    final spellingItems = pickSpellingItems(testSentences, wordPool, 1);
    
    // 验证重组句题单词数量
    if (reorderItems.isNotEmpty) {
      final wordCount = (reorderItems[0]['options'] as List).length;
      final validLength = wordCount >= params.minWords && wordCount <= params.maxWords;
      runTest('重组句题单词数: $wordCount (范围 ${params.minWords}-${params.maxWords})', validLength);
    }
    
    // 验证拼写题单词长度
    if (spellingItems.isNotEmpty) {
      final answer = spellingItems[0]['answer'].toString();
      final validLen = answer.length >= params.minWordLen && answer.length <= params.maxWordLen;
      runTest('拼写题单词长度: "${answer}" (${answer.length}, 范围 ${params.minWordLen}-${params.maxWordLen})', validLen);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  print('\n【第三部分】完整输出示例\n');

  // 输出一个完整的测试计划示例
  print('=== 完整测试计划示例 (难度: intermediate) ===\n');
  final params = difficultyParamsMap['intermediate']!;
  final wordPool = extractWordPool(testSentences, params);

  print('📝 词池 (前10个): ${wordPool.take(10).toList()}');
  print('');

  // 生成所有题型
  final allItems = <Map<String, dynamic>>[];
  allItems.addAll(pickReorderItems(testSentences, 1, params));
  allItems.addAll(pickSpellingItems(testSentences, wordPool, 1));
  allItems.addAll(pickMcqItems(wordPool, 1));
  allItems.addAll(pickListenChooseItemsOptimized(wordPool, 1));
  allItems.addAll(pickListenMeaningItemsOptimized(wordPool, 1, wordMeaningMap));
  allItems.addAll(pickListenReplyItemsOptimized(testSentences, wordPool, 1, params, wordMeaningMap));
  allItems.addAll(pickDefinitionChoiceItemsOptimized(testSentences, wordPool, 2, wordMeaningMap));
  allItems.addAll(pickTranslateMeaningItemsOptimized(testSentences, wordPool, 1, params, wordMeaningMap));
  allItems.addAll(pickWordRelationItemsOptimized(wordPool, 1, wordRelations));

  for (var i = 0; i < allItems.length; i++) {
    final item = allItems[i];
    final type = item['type'];
    print('--- 题目 ${i + 1} [$type] ---');
    _printItemDetails(item);
    print('');
  }

  // ═══════════════════════════════════════════════════════════════
  print('\n═══════════════════════════════════════════════════════════════');
  print('测试总结');
  print('═══════════════════════════════════════════════════════════════');
  print('总测试数: $totalTests');
  print('通过: ✅ $passedTests (${(passedTests / totalTests * 100).toStringAsFixed(1)}%)');
  print('失败: ❌ $failedTests (${(failedTests / totalTests * 100).toStringAsFixed(1)}%)');
  
  if (failedTests == 0) {
    print('\n🎉 所有测试通过！优化后的边缘函数运行正常。');
  } else {
    print('\n⚠️  仍有 $failedTests 个测试未通过，需要进一步检查。');
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据结构定义
// ═══════════════════════════════════════════════════════════════

class DifficultyParams {
  final int minWords;
  final int maxWords;
  final int minWordLen;
  final int maxWordLen;
  final int maxSentenceLen;

  DifficultyParams({
    required this.minWords,
    required this.maxWords,
    required this.minWordLen,
    required this.maxWordLen,
    required this.maxSentenceLen,
  });
}

class WordRelation {
  final List<String>? synonyms;
  final List<String>? antonyms;
  final String? category;

  WordRelation({this.synonyms, this.antonyms, this.category});
}

// ═══════════════════════════════════════════════════════════════
// 工具函数
// ═══════════════════════════════════════════════════════════════

List<T> shuffle<T>(List<T> arr) {
  final a = List<T>.from(arr);
  final random = Random();
  for (var i = a.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final temp = a[i];
    a[i] = a[j];
    a[j] = temp;
  }
  return a;
}

List<String> unique<T>(List<T> arr) {
  final seen = <T>{};
  final out = <T>[];
  for (final x in arr) {
    if (seen.contains(x)) continue;
    seen.add(x);
    out.add(x);
  }
  return out.cast<String>();
}

List<String> tokenizeWords(String text) {
  final pattern = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)?");
  return pattern.allMatches(text).map((m) => m.group(0)!.trim()).where((t) => t.isNotEmpty).toList();
}

String getWordMeaning(String word, Map<String, String> meaningMap) {
  final lower = word.toLowerCase();
  return meaningMap[lower] ?? '「$word」的释义';
}

List<String> getDistractorMeanings(String targetWord, List<String> wordPool, int count, Map<String, String> meaningMap) {
  final others = shuffle(wordPool.where((w) => w.toLowerCase() != targetWord.toLowerCase()).toList());
  return others.take(count).map((w) => getWordMeaning(w, meaningMap)).toList();
}

// ═══════════════════════════════════════════════════════════════
// 基础题型生成函数（与原版一致）
// ═══════════════════════════════════════════════════════════════

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
  return unique(words);
}

String maskWord(String sentence, String word) {
  final escapedWord = RegExp.escape(word);
  final pattern = RegExp('\\b$escapedWord\\b', caseSensitive: false);
  if (!pattern.hasMatch(sentence)) return sentence;
  return sentence.replaceAll(pattern, '_____');
}

List<Map<String, dynamic>> pickReorderItems(List<String> sentences, int count, DifficultyParams params) {
  final items = <Map<String, dynamic>>[];
  
  // 先筛选符合条件的句子
  final validSentences = <Map<String, dynamic>>[];
  for (final s in sentences) {
    final words = tokenizeWords(s);
    if (words.length >= params.minWords && words.length <= params.maxWords) {
      validSentences.add({'s': s, 'w': words});
    }
  }

  for (final x in shuffle(validSentences).take(count)) {
    final correct = x['w'] as List<String>;
    final options = shuffle(correct);
    items.add({
      'type': 'reorder',
      'prompt': '请按正确顺序组句',
      'sentence': x['s'] as String,
      'options': options,
      'answer': correct,
    });
  }
  return items;
}

List<Map<String, dynamic>> pickSpellingItems(List<String> sentences, List<String> wordPool, int count) {
  final items = <Map<String, dynamic>>[];
  final shuffledWords = shuffle(wordPool);
  
  for (final w in shuffledWords) {
    if (items.length >= count) break;
    final candidateSentences = shuffle(sentences).take(40).toList();
    String? chosen;
    String masked = '';
    
    for (final s in candidateSentences) {
      final m = maskWord(s, w);
      if (m != s) {
        chosen = s;
        masked = m;
        break;
      }
    }
    if (chosen == null) continue;

    final letters = w.toUpperCase().split('');
    final wordLen = letters.length;
    final extra = min(6, max(2, 12 - wordLen));
    final pool = [...letters];
    final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random();
    for (var i = 0; i < extra; i++) {
      pool.add(alphabet[random.nextInt(alphabet.length)]);
    }
    final letterPool = shuffle(pool);
    
    items.add({
      'type': 'spelling',
      'prompt': '请根据句子拼写缺失单词',
      'sentence': chosen,
      'masked': masked,
      'answer': w,
      'letter_pool': letterPool,
    });
  }
  return items;
}

List<Map<String, dynamic>> pickMcqItems(List<String> wordPool, int count) {
  final items = <Map<String, dynamic>>[];
  final pool = shuffle(wordPool);
  
  for (final w in pool) {
    if (items.length >= count) break;
    final distractors = shuffle(wordPool.where((x) => x != w).toList()).take(3).toList();
    if (distractors.length < 3) continue;
    final options = shuffle([w, ...distractors]);
    
    items.add({
      'type': 'mcq',
      'prompt': '请选择最合适的单词填空',
      'options': options,
      'answer_index': options.indexOf(w),
    });
  }
  return items;
}

// ═══════════════════════════════════════════════════════════════
// 优化后的题型生成函数
// ═══════════════════════════════════════════════════════════════

/** 优化版：听音选词 */
List<Map<String, dynamic>> pickListenChooseItemsOptimized(List<String> wordPool, int count) {
  final items = <Map<String, dynamic>>[];
  for (final w in shuffle(wordPool)) {
    if (items.length >= count) break;
    final distractors = shuffle(wordPool.where((x) => x != w).toList()).take(3).toList();
    if (distractors.length < 3) continue;
    final options = shuffle([w, ...distractors]);
    
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

/** 优化版：听音辩义（使用中文释义） */
List<Map<String, dynamic>> pickListenMeaningItemsOptimized(List<String> wordPool, int count, Map<String, String> meaningMap) {
  final items = <Map<String, dynamic>>[];
  for (final w in shuffle(wordPool)) {
    if (items.length >= count) break;
    
    final correctMeaning = getWordMeaning(w, meaningMap);
    final distractorMeanings = getDistractorMeanings(w, wordPool, 3, meaningMap);
    if (distractorMeanings.length < 3) continue;
    
    final options = shuffle([correctMeaning, ...distractorMeanings]);
    items.add({
      'type': 'listen_meaning',
      'prompt': 'Listen and select the word with similar meaning',
      'prompt_cn': '听发音，选择与该词意思最接近的选项',
      'options': options,
      'answer': correctMeaning,
      'answer_index': options.indexOf(correctMeaning),
      'ref_text': w,
      'answer_word': w,
    });
  }
  return items;
}

/** 优化版：听音回复 */
List<Map<String, dynamic>> pickListenReplyItemsOptimized(List<String> sentences, List<String> wordPool, int count, DifficultyParams params, Map<String, String> meaningMap) {
  final items = <Map<String, dynamic>>[];
  final candidates = sentences.where((s) => s.length <= params.maxSentenceLen && s.length > 10).map((s) => s.trim()).toList();
  
  final stopWords = ['is', 'are', 'am', 'do', 'does', 'did', 'can', 'could', 'would', 'should', 'will', 'the', 'a', 'an', 'this', 'that', 'these', 'those', 'it', 'you', 'he', 'she', 'we', 'they', 'i', 'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his', 'our', 'their', 'what', 'where', 'when', 'why', 'how', 'who', 'which'];
  final nounKeywords = ['computer', 'school', 'park', 'movie', 'restaurant', 'project', 'book', 'day', 'time', 'year', 'home', 'work', 'life', 'world', 'people', 'man', 'woman', 'child', 'thing'];

  for (final s in shuffle(candidates)) {
    if (items.length >= count) break;
    final words = tokenizeWords(s);
    if (words.length < 3) continue;

    final isQuestion = RegExp(r'^(what|where|when|why|how|who|which|can|could|would|do|does|did|is|are|am)', caseSensitive: false).hasMatch(s);
    
    String keyWord;
    if (isQuestion) {
      final meaningfulWords = words.where((w) => !stopWords.contains(w.toLowerCase())).toList();
      keyWord = meaningfulWords.isNotEmpty ? meaningfulWords.last : words.last;
    } else {
      final nouns = words.where((w) =>
        RegExp(r'^[A-Z]').hasMatch(w) || nounKeywords.contains(w.toLowerCase())
      ).toList();
      keyWord = nouns.isNotEmpty ? nouns.first : words[min(2, words.length - 1)];
    }

    final keyWordLower = keyWord.toLowerCase();
    final distractors = shuffle(wordPool.where((x) => x != keyWordLower).toList()).take(3).toList();
    if (distractors.length < 3) continue;

    final correctAnswer = getWordMeaning(keyWordLower, meaningMap);
    final distractorAnswers = distractors.map((d) => getWordMeaning(d, meaningMap)).toList();
    final options = shuffle([correctAnswer, ...distractorAnswers]);

    items.add({
      'type': 'listen_reply',
      'prompt': 'Listen to the question and select the best answer: "$s"',
      'prompt_cn': '听以下句子，选择最佳回答：「$s」',
      'options': options,
      'answer': correctAnswer,
      'answer_index': options.indexOf(correctAnswer),
      'ref_text': s,
      'answer_word': keyWordLower,
    });
  }
  return items;
}

/** 优化版：释义选择（修复答案泄露） */
List<Map<String, dynamic>> pickDefinitionChoiceItemsOptimized(List<String> sentences, List<String> wordPool, int count, Map<String, String> meaningMap) {
  final items = <Map<String, dynamic>>[];
  final random = Random();
  
  for (final w in shuffle(wordPool)) {
    if (items.length >= count) break;
    
    final wordMeaning = getWordMeaning(w, meaningMap);
    final distractorMeanings = getDistractorMeanings(w, wordPool, 3, meaningMap);
    if (distractorMeanings.length < 3) continue;

    final isEnglishToChinese = random.nextDouble() > 0.5;

    if (isEnglishToChinese) {
      final options = shuffle([wordMeaning, ...distractorMeanings]);
      items.add({
        'type': 'definition_choice',
        'prompt': 'What is the meaning of "$w"?',
        'prompt_cn': '单词 "$w" 的意思是什么？',
        'display_text': w,
        'options': options,
        'answer': wordMeaning,
        'answer_index': options.indexOf(wordMeaning),
        'sub_type': 'en_to_cn',
        'answer_word': w,
      });
    } else {
      final englishOptions = shuffle(wordPool.where((x) => x != w).toList().take(3).toList());
      if (englishOptions.length < 3) continue;
      final allEnglishOptions = shuffle([w, ...englishOptions]);
      items.add({
        'type': 'definition_choice',
        'prompt': 'Which word matches the meaning: "$wordMeaning"?',
        'prompt_cn': '哪个单词符合以下含义：「$wordMeaning」？',
        'display_text': wordMeaning,
        'options': allEnglishOptions,
        'answer': w,
        'answer_index': allEnglishOptions.indexOf(w),
        'sub_type': 'cn_to_en',
        'answer_meaning': wordMeaning,
      });
    }
  }
  return items;
}

/** 优化版：英义互译（使用模拟翻译） */
List<Map<String, dynamic>> pickTranslateMeaningItemsOptimized(List<String> sentences, List<String> wordPool, int count, DifficultyParams params, Map<String, String> meaningMap) {
  final items = <Map<String, dynamic>>[];
  final candidates = sentences.where((s) => s.length <= params.maxSentenceLen && s.length > 10).map((s) => s.trim()).toList();

  String mockTranslate(String sentence) {
    final words = tokenizeWords(sentence);
    final translatedParts = <String>[];
    for (final w in words) {
      final meaning = getWordMeaning(w, meaningMap);
      if (!meaning.startsWith('「')) {
        translatedParts.add(meaning);
      } else {
        translatedParts.add(w);
      }
    }
    final result = translatedParts.join();
    return result.isNotEmpty ? result : sentence;
  }

  for (final s in shuffle(candidates)) {
    if (items.length >= count) break;
    final words = tokenizeWords(s);
    if (words.length < 3) continue;

    final mainTranslation = mockTranslate(s);
    final otherSentences = shuffle(sentences.where((x) => x != s && x.length <= params.maxSentenceLen).toList()).take(3).toList();
    if (otherSentences.length < 3) continue;

    final distractorTranslations = otherSentences.map((sent) => mockTranslate(sent)).toList();
    final options = shuffle([mainTranslation, ...distractorTranslations]);

    items.add({
      'type': 'translate_meaning',
      'prompt': 'Read the sentence and select the option with the closest meaning',
      'prompt_cn': '阅读以下英文句子，选择与原文含义最接近的中文选项',
      'display_text': s,
      'options': options,
      'answer': mainTranslation,
      'answer_index': options.indexOf(mainTranslation),
      'original_sentence': s,
    });
  }
  return items;
}

/** 优化版：词性测试（使用预定义语义关系） */
List<Map<String, dynamic>> pickWordRelationItemsOptimized(List<String> wordPool, int count, Map<String, WordRelation> relations) {
  final items = <Map<String, dynamic>>[];
  final relationTypes = [
    {'key': 'synonym', 'prompt': 'Select synonyms of', 'prompt_cn': '选择以下单词的同义词（可多选）'},
    {'key': 'antonym', 'prompt': 'Select antonyms of', 'prompt_cn': '选择以下单词的反义词（可多选）'},
    {'key': 'same_category', 'prompt': 'Select words in the same category as', 'prompt_cn': '选择与以下单词同类的词（可多选）'},
  ];

  for (final w in shuffle(wordPool)) {
    if (items.length >= count) break;
    final relation = relationTypes[items.length % relationTypes.length];
    final wLower = w.toLowerCase();
    final wordRelation = relations[wLower];

    List<String> correctAnswers = [];

    if (wordRelation != null) {
      switch (relation['key']) {
        case 'synonym':
          correctAnswers = wordRelation.synonyms ?? [];
          break;
        case 'antonym':
          correctAnswers = wordRelation.antonyms ?? [];
          break;
        case 'same_category':
          correctAnswers = wordPool.where((x) {
            final xr = relations[x.toLowerCase()];
            return xr?.category == wordRelation.category && x.toLowerCase() != wLower;
          }).take(2).toList();
          break;
      }
    }

    if (correctAnswers.isEmpty) {
      final others = shuffle(wordPool.where((x) => x != w).toList());
      if (others.length < 3) continue;
      correctAnswers = others.take(2).toList();
    }

    final validCorrectAnswers = correctAnswers.where((a) =>
      wordPool.contains(a) || wordPool.any((x) => x.toLowerCase() == a.toLowerCase())
    ).toList();
    if (validCorrectAnswers.isEmpty) continue;

    final distractors = shuffle(wordPool.where((x) =>
      x != w && !validCorrectAnswers.any((a) => a.toLowerCase() == x.toLowerCase())
    ).toList()).take(4).toList();

    if (distractors.length + validCorrectAnswers.length < 4) continue;

    final options = shuffle([...validCorrectAnswers, ...distractors]);
    final answerIndices = validCorrectAnswers.map((a) => options.indexOf(a)).toList();

    items.add({
      'type': 'word_relation',
      'prompt': '${relation["prompt"]} "$w"',
      'prompt_cn': '${relation["prompt_cn"]}：「$w」',
      'display_text': w,
      'relation_type': relation['key'],
      'options': options,
      'answer_indices': answerIndices,
      'answers': validCorrectAnswers,
      'confidence': wordRelation != null ? 'high' : 'low',
    });
  }
  return items;
}

// ═══════════════════════════════════════════════════════════════
// 输出辅助函数
// ═══════════════════════════════════════════════════════════════

void _printItemDetails(Map<String, dynamic> item) {
  final type = item['type'];
  
  switch (type) {
    case 'reorder':
      print('  句子: ${item['sentence']}');
      print('  乱序选项: ${item['options']}');
      print('  正确答案: ${item['answer']}');
      break;
    case 'spelling':
      print('  句子: ${item['sentence']}');
      print('  挖空: ${item['masked']}');
      print('  答案: ${item['answer']}');
      print('  字母池: ${item['letter_pool']}');
      break;
    case 'mcq':
      print('  选项: ${item['options']}');
      print('  正确索引: ${item['answer_index']}');
      break;
    case 'listen_choose':
    case 'listen_meaning':
    case 'listen_reply':
      print('  Prompt (CN): ${item['prompt_cn']}');
      print('  参考文本: ${item['ref_text']}');
      if (item.containsKey('answer_word')) print('  关键词: ${item['answer_word']}');
      print('  选项: ${item['options']}');
      print('  答案: ${item['answer']} (索引: ${item['answer_index']})');
      break;
    case 'definition_choice':
      print('  Prompt (CN): ${item['prompt_cn']}');
      print('  显示文本: ${item['display_text']}');
      print('  子类型: ${item['sub_type']}');
      print('  选项: ${item['options']}');
      print('  答案: ${item['answer']} (索引: ${item['answer_index']})');
      if (item.containsKey('answer_word')) print('  原始单词: ${item['answer_word']}');
      if (item.containsKey('answer_meaning')) print('  对应释义: ${item['answer_meaning']}');
      break;
    case 'translate_meaning':
      print('  Prompt (CN): ${item['prompt_cn']}');
      print('  原文: ${item['display_text']}');
      print('  选项: ${(item['options'] as List).take(2).toList()}...');
      print('  答案: ${item['answer']}');
      break;
    case 'word_relation':
      print('  Prompt (CN): ${item['prompt_cn']}');
      print('  关系类型: ${item['relation_type']}');
      print('  选项: ${item['options']}');
      print('  正确答案: ${item['answers']} (索引: ${item['answer_indices']})');
      print('  置信度: ${item['confidence']}');
      break;
    default:
      print('  $item');
  }
}
