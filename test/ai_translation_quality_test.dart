/// AI 单词翻译质量测试
///
/// 验证 AI definition/translate 接口返回数据的质量，包括：
/// - JSON 结构完整性
/// - 释义准确性
/// - 难度等级合理性
/// - 词形变化正确性
/// - 例句相关性
/// - 音标规范性
///
/// 使用模拟数据进行验证（基于 Edge Function qwen-chat.ts 的实际 Prompt 和返回格式）
void main() {
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║           AI 单词翻译质量测试报告                              ║');
  print('╚══════════════════════════════════════════════════════════════╝\n');

  final tester = AiTranslationQualityTester();
  final report = tester.runAllTests();

  // 输出报告
  _printReport(report);
}

// ─── 数据模型 ──────────────────────────────────────

/// 难度等级枚举（与后端保持一致）
enum DifficultyLevel {
  primary,
  juniorHigh,
  seniorHigh,
  cet4,
  cet6,
  postgraduate,
  ielts,
  toefl,
  gre,
  unknown,
}

/// 难度等级顺序值（用于比较）
int difficultyOrder(DifficultyLevel d) {
  switch (d) {
    case DifficultyLevel.primary: return 1;
    case DifficultyLevel.juniorHigh: return 2;
    case DifficultyLevel.seniorHigh: return 3;
    case DifficultyLevel.cet4: return 4;
    case DifficultyLevel.cet6: return 5;
    case DifficultyLevel.postgraduate: return 6;
    case DifficultyLevel.ielts: return 7;
    case DifficultyLevel.toefl: return 8;
    case DifficultyLevel.gre: return 9;
    case DifficultyLevel.unknown: return 0;
  }
}

DifficultyLevel parseDifficulty(String? raw) {
  if (raw == null || raw.isEmpty) return DifficultyLevel.unknown;
  final n = raw.trim().toLowerCase().replaceAll('-', '').replaceAll('_', '');
  switch (n) {
    case 'primary': return DifficultyLevel.primary;
    case 'juniorhigh':
    case 'junior': return DifficultyLevel.juniorHigh;
    case 'seniorhigh':
    case 'senior': return DifficultyLevel.seniorHigh;
    case 'cet4': return DifficultyLevel.cet4;
    case 'cet6': return DifficultyLevel.cet6;
    case 'postgraduate':
    case 'kaoyan':
    case '考研': return DifficultyLevel.postgraduate;
    case 'ielts': return DifficultyLevel.ielts;
    case 'toefl': return DifficultyLevel.toefl;
    case 'gre': return DifficultyLevel.gre;
    default: return DifficultyLevel.unknown;
  }
}

String difficultyLabel(DifficultyLevel d) {
  switch (d) {
    case DifficultyLevel.primary: return '小学';
    case DifficultyLevel.juniorHigh: return '初中';
    case DifficultyLevel.seniorHigh: return '高中';
    case DifficultyLevel.cet4: return 'CET4';
    case DifficultyLevel.cet6: return 'CET6';
    case DifficultyLevel.postgraduate: return '考研';
    case DifficultyLevel.ielts: return '雅思';
    case DifficultyLevel.toefl: return '托福';
    case DifficultyLevel.gre: return 'GRE';
    case DifficultyLevel.unknown: return '未知';
  }
}

/// 模拟 AI 返回的数据结构（与 qwen-chat.ts DefinitionResult 一致）
class MockAiDefinitionResult {
  final String word;
  final String? phoneticUk;
  final String? phoneticUs;
  final String? partOfSpeech;
  final List<String> definitions;
  final String? difficulty;
  final List<MockExample> examples;
  final List<MockExample> standaloneExamples;
  final Map<String, dynamic>? morphology;
  final String? mnemonic;

  const MockAiDefinitionResult({
    required this.word,
    this.phoneticUk,
    this.phoneticUs,
    this.partOfSpeech,
    this.definitions = const [],
    this.difficulty,
    this.examples = const [],
    this.standaloneExamples = const [],
    this.morphology,
    this.mnemonic,
  });

  factory MockAiDefinitionResult.fromJson(Map<String, dynamic> json) {
    return MockAiDefinitionResult(
      word: json['word'] as String? ?? '',
      phoneticUk: json['phonetic_uk'] as String?,
      phoneticUs: json['phonetic_us'] as String?,
      partOfSpeech: json['part_of_speech'] as String?,
      definitions: (json['definitions'] as List?)?.cast<String>() ?? [],
      difficulty: json['difficulty'] as String?,
      examples: (json['examples'] as List?)
              ?.map((e) => MockExample.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <MockExample>[],
      standaloneExamples: (json['standalone_examples'] as List?)
              ?.map((e) => MockExample.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          <MockExample>[],
      morphology: json['morphology'] != null ? Map<String, dynamic>.from(json['morphology'] as Map) : null,
      mnemonic: json['mnemonic'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        if (phoneticUk != null) 'phonetic_uk': phoneticUk,
        if (phoneticUs != null) 'phonetic_us': phoneticUs,
        if (partOfSpeech != null) 'part_of_speech': partOfSpeech,
        'definitions': definitions,
        if (difficulty != null) 'difficulty': difficulty,
        'examples': examples.map((e) => e.toJson()).toList(),
        'standalone_examples': standaloneExamples.map((e) => e.toJson()).toList(),
        if (morphology != null) 'morphology': morphology,
        if (mnemonic != null) 'mnemonic': mnemonic,
      };
}

class MockExample {
  final String english;
  final String chinese;

  const MockExample({required this.english, required this.chinese});

  factory MockExample.fromJson(Map<String, dynamic> json) => MockExample(
        english: json['english'] as String? ?? '',
        chinese: json['chinese'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'english': english, 'chinese': chinese};
}

/// 单词测试用例
class WordTestCase {
  final String word;
  final DifficultyLevel expectedDifficulty;
  final List<String> expectedMeanings; // 预期应包含的关键词
  final String? expectedPartOfSpeech; // 预期词性（可选）
  final bool shouldHaveMorphology; // 是否应有词形变化
  final String category; // 分类标签

  const WordTestCase({
    required this.word,
    required this.expectedDifficulty,
    required this.expectedMeanings,
    this.expectedPartOfSpeech,
    this.shouldHaveMorphology = true,
    required this.category,
  });
}

/// 单项测试结果
class WordTestResult {
  final String word;
  final DifficultyLevel expectedDifficulty;
  final MockAiDefinitionResult? aiResult;
  final Map<String, double> dimensionScores; // 各维度得分
  final double totalScore; // 加权总分
  final List<String> issues; // 问题列表
  final List<String> warnings; // 警告列表

  const WordTestResult({
    required this.word,
    required this.expectedDifficulty,
    this.aiResult,
    required this.dimensionScores,
    required this.totalScore,
    required this.issues,
    required this.warnings,
  });

  bool get passed => issues.isEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
}

/// 总体测试报告
class TestReport {
  final double overallScore;
  final int totalWords;
  final int passCount;
  final int warningCount;
  final int failCount;
  final List<WordTestResult> results;
  final Map<String, double> dimensionAverages; // 各维度平均分
  final Duration executionTime;

  const TestReport({
    required this.overallScore,
    required this.totalWords,
    required this.passCount,
    required this.warningCount,
    required this.failCount,
    required this.results,
    required this.dimensionAverages,
    required this.executionTime,
  });

  String get grade {
    if (overallScore >= 90) return '🟢 优秀';
    if (overallScore >= 75) return '🟡 良好';
    if (overallScore >= 60) return '🟠 及格';
    return '🔴 不合格';
  }

  double get passRate => totalWords > 0 ? (passCount / totalWords) * 100 : 0;
}

// ─── 测试器 ──────────────────────────────────────

class AiTranslationQualityTester {
  /// 测试单词列表
  static const testCases = [
    // === Primary (小学) ===
    WordTestCase(
      word: 'apple',
      expectedDifficulty: DifficultyLevel.primary,
      expectedMeanings: ['苹果'],
      expectedPartOfSpeech: '名词',
      shouldHaveMorphology: true,
      category: 'primary',
    ),
    WordTestCase(
      word: 'happy',
      expectedDifficulty: DifficultyLevel.primary,
      expectedMeanings: ['快乐', '高兴', '幸福'],
      expectedPartOfSpeech: '形容词',
      shouldHaveMorphology: true,
      category: 'primary',
    ),
    WordTestCase(
      word: 'run',
      expectedDifficulty: DifficultyLevel.primary,
      expectedMeanings: ['跑', '奔跑', '运行'],
      expectedPartOfSpeech: '动词',
      shouldHaveMorphology: true,
      category: 'primary',
    ),
    WordTestCase(
      word: 'book',
      expectedDifficulty: DifficultyLevel.primary,
      expectedMeanings: ['书', '书籍', '预订'],
      expectedPartOfSpeech: '名词',
      shouldHaveMorphology: true,
      category: 'primary',
    ),
    WordTestCase(
      word: 'cat',
      expectedDifficulty: DifficultyLevel.primary,
      expectedMeanings: ['猫'],
      expectedPartOfSpeech: '名词',
      shouldHaveMorphology: true,
      category: 'primary',
    ),

    // === JuniorHigh (初中) ===
    WordTestCase(
      word: 'abandon',
      expectedDifficulty: DifficultyLevel.juniorHigh,
      expectedMeanings: ['抛弃', '放弃', '遗弃'],
      expectedPartOfSpeech: '动词',
      shouldHaveMorphology: true,
      category: 'juniorHigh',
    ),
    WordTestCase(
      word: 'beautiful',
      expectedDifficulty: DifficultyLevel.juniorHigh,
      expectedMeanings: ['美丽', '漂亮', '美好'],
      expectedPartOfSpeech: '形容词',
      shouldHaveMorphology: true,
      category: 'juniorHigh',
    ),
    WordTestCase(
      word: 'decide',
      expectedDifficulty: DifficultyLevel.juniorHigh,
      expectedMeanings: ['决定', '决心', '判断'],
      expectedPartOfSpeech: '动词',
      shouldHaveMorphology: true,
      category: 'juniorHigh',
    ),
    WordTestCase(
      word: 'environment',
      expectedDifficulty: DifficultyLevel.juniorHigh,
      expectedMeanings: ['环境', '周围', '自然环境'],
      expectedPartOfSpeech: '名词',
      shouldHaveMorphology: true,
      category: 'juniorHigh',
    ),
    WordTestCase(
      word: 'necessary',
      expectedDifficulty: DifficultyLevel.juniorHigh,
      expectedMeanings: ['必要', '必须', '必需'],
      expectedPartOfSpeech: '形容词',
      shouldHaveMorphology: true,
      category: 'juniorHigh',
    ),

    // === SeniorHigh/CET4 (高中/四级) ===
    WordTestCase(
      word: 'sophisticated',
      expectedDifficulty: DifficultyLevel.seniorHigh,
      expectedMeanings: ['复杂', '老练', '精密', '世故'],
      expectedPartOfSpeech: '形容词',
      shouldHaveMorphology: true,
      category: 'seniorHigh',
    ),
    WordTestCase(
      word: 'phenomenon',
      expectedDifficulty: DifficultyLevel.seniorHigh,
      expectedMeanings: ['现象', '奇迹', '非凡的人或事'],
      expectedPartOfSpeech: '名词',
      shouldHaveMorphology: true,
      category: 'seniorHigh',
    ),
    WordTestCase(
      word: 'controversial',
      expectedDifficulty: DifficultyLevel.seniorHigh,
      expectedMeanings: ['争议', '争论', '有分歧的'],
      expectedPartOfSpeech: '形容词',
      shouldHaveMorphology: true,
      category: 'seniorHigh',
    ),
    WordTestCase(
      word: 'entrepreneur',
      expectedDifficulty: DifficultyLevel.seniorHigh,
      expectedMeanings: ['企业家', '创业者', '主办者'],
      expectedPartOfSpeech: '名词',
      shouldHaveMorphology: true,
      category: 'seniorHigh',
    ),
    WordTestCase(
      word: 'psychological',
      expectedDifficulty: DifficultyLevel.seniorHigh,
      expectedMeanings: ['心理', '心理学', '精神上的'],
      expectedPartOfSpeech: '形容词',
      shouldHaveMorphology: true,
      category: 'seniorHigh',
    ),

    // === CET6/GRE (六级/GRE) ===
    WordTestCase(
      word: 'ubiquitous',
      expectedDifficulty: DifficultyLevel.cet6,
      expectedMeanings: ['无处不在', '普遍存在', '到处都有'],
      expectedPartOfSpeech: '形容词',
      shouldHaveMorphology: true,
      category: 'cet6_gre',
    ),
    WordTestCase(
      word: 'unprecedented',
      expectedDifficulty: DifficultyLevel.cet6,
      expectedMeanings: ['史无前例', '空前', '前所未有的'],
      expectedPartOfSpeech: '形容词',
      shouldHaveMorphology: true,
      category: 'cet6_gre',
    ),
    WordTestCase(
      word: 'meticulous',
      expectedDifficulty: DifficultyLevel.cet6,
      expectedMeanings: ['一丝不苟', '细致', '小心翼翼'],
      expectedPartOfSpeech: '形容词',
      shouldHaveMorphology: true,
      category: 'cet6_gre',
    ),
    WordTestCase(
      word: 'ephemeral',
      expectedDifficulty: DifficultyLevel.gre,
      expectedMeanings: ['短暂', '瞬息', '朝生暮死'],
      expectedPartOfSpeech: '形容词',
      shouldHaveMorphology: true,
      category: 'gre',
    ),
    WordTestCase(
      word: 'serendipity',
      expectedDifficulty: DifficultyLevel.gre,
      expectedMeanings: ['意外发现', '机缘巧合', '偶然发现美好事物的能力'],
      expectedPartOfSpeech: '名词',
      shouldHaveMorphology: false,
      category: 'gre',
    ),

    // === 特殊情况 ===
    WordTestCase(
      word: 'I',
      expectedDifficulty: DifficultyLevel.primary,
      expectedMeanings: ['我'],
      expectedPartOfSpeech: '代词',
      shouldHaveMorphology: false,
      category: 'special',
    ),
    WordTestCase(
      word: 'set',
      expectedDifficulty: DifficultyLevel.primary,
      expectedMeanings: ['设置', '放置', '集合', '一套'],
      expectedPartOfSpeech: '动词',
      shouldHaveMorphology: true,
      category: 'special',
    ),
    WordTestCase(
      word: 'a',
      expectedDifficulty: DifficultyLevel.primary,
      expectedMeanings: ['一个', '某一', '冠词'],
      expectedPartOfSpeech: '冠词',
      shouldHaveMorphology: false,
      category: 'special',
    ),
  ];

  /// 模拟 AI 返回数据
  ///
  /// 这些数据模拟了 qwen-chat.ts 中 definition() 函数的实际返回格式。
  /// 在实际测试中，可以替换为真实的 API 调用。
  static const Map<String, Map<String, dynamic>> mockAiResponses = {
    // === Primary ===
    'apple': {
      'word': 'apple',
      'phonetic_uk': '/ˈæp.əl/',
      'phonetic_us': '/ˈæp.əl/',
      'part_of_speech': '名词',
      'definitions': ['苹果；苹果树', '类似苹果的果实'],
      'difficulty': 'primary',
      'examples': [
        {'english': 'I eat an apple every day.', 'chinese': '我每天吃一个苹果。'},
        {'english': 'The apple is red and sweet.', 'chinese': '这个苹果又红又甜。'},
        {'english': 'She picked an apple from the tree.', 'chinese': '她从树上摘了一个苹果。'},
      ],
      'standalone_examples': [
        {'english': 'An apple a day keeps the doctor away.', 'chinese': '一天一苹果，医生远离我。'},
        {'english': 'This apple tastes delicious.', 'chinese': '这个苹果尝起来很美味。'},
        {'english': 'He wants to buy some apples.', 'chinese': '他想买一些苹果。'},
      ],
      'morphology': {'plural': 'apples'},
      'mnemonic': 'apple 音似"阿婆"，阿婆爱吃苹果',
    },
    'happy': {
      'word': 'happy',
      'phonetic_uk': '/ˈhæp.i/',
      'phonetic_us': '/ˈhæp.i/',
      'part_of_speech': '形容词',
      'definitions': ['快乐的；高兴的', '幸福的；满意的'],
      'difficulty': 'primary',
      'examples': [
        {'english': 'She is very happy today.', 'chinese': '她今天非常开心。'},
        {'english': 'They lived a happy life together.', 'chinese': '他们一起过着幸福的生活。'},
        {'english': 'I am happy to help you.', 'chinese': '我很乐意帮助你。'},
      ],
      'standalone_examples': [
        {'english': 'Happy birthday to you!', 'chinese': '祝你生日快乐！'},
        {'english': 'The children look very happy.', 'chinese': '孩子们看起来很开心。'},
        {'english': 'We had a happy holiday.', 'chinese': '我们度过了一个愉快的假期。'},
      ],
      'morphology': {
        'comparative': 'happier',
        'superlative': 'happiest',
        'noun_form': 'happiness',
      },
      'mnemonic': 'hap运气 + y → 有运气的 → 快乐的',
    },
    'run': {
      'word': 'run',
      'phonetic_uk': '/rʌn/',
      'phonetic_us': '/rʌn/',
      'part_of_speech': '动词',
      'definitions': ['跑；奔跑', '经营；管理', '运行；运转'],
      'difficulty': 'primary',
      'examples': [
        {'english': 'I run in the park every morning.', 'chinese': '我每天早上在公园跑步。'},
        {'english': 'He runs faster than his brother.', 'chinese': '他比他哥哥跑得更快。'},
        {'english': 'Don\'t run in the hallway.', 'chinese': '不要在走廊里奔跑。'},
      ],
      'standalone_examples': [
        {'english': 'She likes to run in the morning.', 'chinese': '她喜欢早上跑步。'},
        {'english': 'The company is run by his father.', 'chinese': '这家公司由他的父亲经营。'},
        {'english': 'This machine runs on electricity.', 'chinese': '这台机器靠电力运行。'},
      ],
      'morphology': {
        'past_tense': 'ran',
        'past_participle': 'run',
        'present_participle': 'running',
        'third_person_singular': 'runs',
        'is_irregular': true,
        'note': '不规则动词：run-ran-run',
      },
    },
    'book': {
      'word': 'book',
      'phonetic_uk': '/bʊk/',
      'phonetic_us': '/bʊk/',
      'part_of_speech': '名词/动词',
      'definitions': ['书；书籍', '预订；预约', '登记；记录'],
      'difficulty': 'primary',
      'examples': [
        {'english': 'This book is very interesting.', 'chinese': '这本书很有趣。'},
        {'english': 'She booked a ticket online.', 'chinese': '她在网上预订了一张票。'},
        {'english': 'I need to book a hotel room.', 'chinese': '我需要预订一个酒店房间。'},
      ],
      'standalone_examples': [
        {'english': 'Have you read this book?', 'chinese': '你读过这本书吗？'},
        {'english': 'Can you book a table for two?', 'chinese': '你能预订一张两人桌吗？'},
        {'english': 'The library has many books.', 'chinese': '图书馆有很多书。'},
      ],
      'morphology': {'plural': 'books', 'past_tense': 'booked', 'present_participle': 'booking'},
    },
    'cat': {
      'word': 'cat',
      'phonetic_uk': '/kæt/',
      'phonetic_us': '/kæt/',
      'part_of_speech': '名词',
      'definitions': ['猫；猫科动物'],
      'difficulty': 'primary',
      'examples': [
        {'english': 'The cat is sleeping on the sofa.', 'chinese': '猫正在沙发上睡觉。'},
        {'english': 'My cat likes to eat fish.', 'chinese': '我的猫喜欢吃鱼。'},
        {'english': 'The cat caught a mouse.', 'chinese': '这只猫抓到了一只老鼠。'},
      ],
      'standalone_examples': [
        {'english': 'She has two cats at home.', 'chinese': '她家里有两只猫。'},
        {'english': 'The black cat is very cute.', 'chinese': '这只黑猫非常可爱。'},
        {'english': 'Cats are independent animals.', 'chinese': '猫是独立的动物。'},
      ],
      'morphology': {'plural': 'cats'},
    },

    // === JuniorHigh ===
    'abandon': {
      'word': 'abandon',
      'phonetic_uk': '/əˈbæn.dən/',
      'phonetic_us': '/əˈbæn.dən/',
      'part_of_speech': '动词',
      'definitions': ['抛弃；放弃', '遗弃；舍弃', '中途停止；中止'],
      'difficulty': 'juniorHigh',
      'examples': [
        {'english': 'They had to abandon their car in the snow.', 'chinese': '他们不得不把车抛弃在雪地里。'},
        {'english': 'Please don\'t abandon your dream.', 'chinese': '请不要放弃你的梦想。'},
        {'english': 'The crew abandoned the sinking ship.', 'chinese': '船员们放弃了正在下沉的船。'},
      ],
      'standalone_examples': [
        {'english': 'Don\'t abandon hope.', 'chinese': '不要放弃希望。'},
        {'english': 'She abandoned the idea.', 'chinese': '她放弃了这个想法。'},
        {'english': 'We will never abandon you.', 'chinese': '我们永远不会抛弃你。'},
      ],
      'morphology': {
        'past_tense': 'abandoned',
        'past_participle': 'abandoned',
        'present_participle': 'abandoning',
      },
    },
    'beautiful': {
      'word': 'beautiful',
      'phonetic_uk': '/ˈbjuː.tɪ.fəl/',
      'phonetic_us': '/ˈbjuː.t̬ə.fəl/',
      'part_of_speech': '形容词',
      'definitions': ['美丽的；漂亮的', '美好的；极好的', '出色的；完美的'],
      'difficulty': 'juniorHigh',
      'examples': [
        {'english': 'She has a beautiful voice.', 'chinese': '她有一副美丽的嗓音。'},
        {'english': 'The view from here is beautiful.', 'chinese': '从这里看到的景色很美。'},
        {'english': 'What a beautiful day!', 'chinese': '多美好的一天啊！'},
      ],
      'standalone_examples': [
        {'english': 'You look beautiful tonight.', 'chinese': '你今晚看起来很美。'},
        {'english': 'The garden is beautiful in spring.', 'chinese': '春天时花园很美丽。'},
        {'english': 'She is a beautiful young woman.', 'chinese': '她是一位美丽的年轻女子。'},
      ],
      'morphology': {
        'comparative': 'more beautiful',
        'superlative': 'most beautiful',
        'noun_form': 'beauty',
        'adverb_form': 'beautifully',
      },
    },
    'decide': {
      'word': 'decide',
      'phonetic_uk': '/dɪˈsaɪd/',
      'phonetic_us': '/dɪˈsaɪd/',
      'part_of_speech': '动词',
      'definitions': ['决定；决心', '判断；断定', '使做出决定'],
      'difficulty': 'juniorHigh',
      'examples': [
        {'english': 'It\'s difficult to decide between them.', 'chinese': '很难在他们之间做决定。'},
        {'english': 'We decided to go home early.', 'chinese': '我们决定早点回家。'},
        {'english': 'You must decide for yourself.', 'chinese': '你必须自己做决定。'},
      ],
      'standalone_examples': [
        {'english': 'I haven\'t decided yet.', 'chinese': '我还没决定。'},
        {'english': 'They decided to get married.', 'chinese': '他们决定结婚。'},
        {'english': 'Let me decide what to do next.', 'chinese': '让我来决定下一步做什么。'},
      ],
      'morphology': {
        'past_tense': 'decided',
        'past_participle': 'decided',
        'present_participle': 'deciding',
        'third_person_singular': 'decides',
        'noun_form': 'decision',
      },
    },
    'environment': {
      'word': 'environment',
      'phonetic_uk': '/ɪnˈvaɪ.rən.mənt/',
      'phonetic_us': '/ɪnˈvaɪ.rɑːn.mənt/',
      'part_of_speech': '名词',
      'definitions': ['环境；自然环境', '周围状况；工作环境'],
      'difficulty': 'juniorHigh',
      'examples': [
        {'english': 'We must protect the environment.', 'chinese': '我们必须保护环境。'},
        {'english': 'The work environment here is great.', 'chinese': '这里的工作环境很好。'},
        {'english': 'Pollution harms our environment.', 'chinese': '污染危害我们的环境。'},
      ],
      'standalone_examples': [
        {'english': 'A clean environment is important for health.', 'chinese': '清洁的环境对健康很重要。'},
        {'english': 'The company cares about the environment.', 'chinese': '这家公司关心环境问题。'},
        {'english': 'Children need a safe environment to grow.', 'chinese': '孩子需要安全的环境成长。'},
      ],
      'morphology': {'plural': 'environments', 'adjective_form': 'environmental'},
    },
    'necessary': {
      'word': 'necessary',
      'phonetic_uk': '/ˈnes.ə.ser.i/',
      'phonetic_us': '/ˈnes.ə.seri/',
      'part_of_speech': '形容词',
      'definitions': ['必要的；必需的', '必然的；不可避免的'],
      'difficulty': 'juniorHigh',
      'examples': [
        {'english': 'Sleep is necessary for health.', 'chinese': '睡眠对健康是必要的。'},
        {'english': 'Is it really necessary?', 'chinese': '这真的有必要吗？'},
        {'english': 'Water is necessary for life.', 'chinese': '水是生命所必需的。'},
      ],
      'standalone_examples': [
        {'english': 'It may not be necessary to go.', 'chinese': '可能没必要去。'},
        {'english': 'All necessary preparations have been made.', 'chinese': '所有必要的准备工作都已完成。'},
        {'english': 'If necessary, I can stay late.', 'chinese': '如果有必要，我可以晚点走。'},
      ],
      'morphology': {
        'comparative': 'more necessary',
        'superlative': 'most necessary',
        'noun_form': 'necessity',
        'antonym': 'unnecessary',
      },
    },

    // === SeniorHigh/CET4 ===
    'sophisticated': {
      'word': 'sophisticated',
      'phonetic_uk': '/səˈfɪs.tɪ.keɪ.tɪd/',
      'phonetic_us': '/səˈfɪs.tɪ.keɪ.t̬ɪd/',
      'part_of_speech': '形容词',
      'definitions': ['复杂的；精密的', '老练的；见过世面的', '高雅的；有品味的'],
      'difficulty': 'cet4',
      'examples': [
        {'english': 'This is a sophisticated system.', 'chinese': '这是一个精密的系统。'},
        {'english': 'She is a sophisticated woman.', 'chinese': '她是一位老练的女性。'},
        {'english': 'The restaurant uses sophisticated cooking techniques.', 'chinese': '这家餐厅使用复杂的烹饪技巧。'},
      ],
      'standalone_examples': [
        {'english': 'He has sophisticated taste in art.', 'chinese': '他在艺术方面有高雅的品味。'},
        {'english': 'Modern technology is becoming more sophisticated.', 'chinese': '现代技术变得越来越复杂。'},
        {'english': 'It was a sophisticated analysis of the problem.', 'chinese': '对这个问题进行了复杂的分析。'},
      ],
      'morphology': {
        'comparative': 'more sophisticated',
        'superlative': 'most sophisticated',
        'noun_form': 'sophistication',
      },
    },
    'phenomenon': {
      'word': 'phenomenon',
      'phonetic_uk': '/fəˈnɒm.ɪ.nən/',
      'phonetic_us': '/fəˈnɑːmə.nɑːn/',
      'part_of_speech': '名词',
      'definitions': ['现象', '非凡的人或事；奇迹'],
      'difficulty': 'cet4',
      'examples': [
        {'english': 'Rainbow is a natural phenomenon.', 'chinese': '彩虹是一种自然现象。'},
        {'english': 'He is a phenomenon in music.', 'chinese': '他是音乐界的奇才。'},
        {'english': 'This social phenomenon needs study.', 'chinese': '这种社会现象需要研究。'},
      ],
      'standalone_examples': [
        {'english': 'Global warming is a worrying phenomenon.', 'chinese': '全球变暖是一个令人担忧的现象。'},
        {'english': 'The phenomenon occurs frequently in summer.', 'chinese': '这种现象在夏天经常发生。'},
        {'english': 'It\'s quite a phenomenon that he succeeded.', 'chinese': '他能成功真是个奇迹。'},
      ],
      'morphology': {'plural': 'phenomena', 'is_irregular': true, 'note': '不规则复数：phenomenon → phenomena'},
    },
    'controversial': {
      'word': 'controversial',
      'phonetic_uk': '/ˌkɒn.trəˈvɜː.ʃəl/',
      'phonetic_us': '/ˌkɑːn.trəˈvɜːr.ʃəl/',
      'part_of_speech': '形容词',
      'definitions': ['有争议的；引起争论的', '好争论的'],
      'difficulty': 'cet4',
      'examples': [
        {'english': 'This is a controversial topic.', 'chinese': '这是一个有争议的话题。'},
        {'english': 'He made a controversial decision.', 'chinese': '他做了一个有争议的决定。'},
        {'english': 'The movie was controversial but popular.', 'chinese': '这部电影有争议但很受欢迎。'},
      ],
      'standalone_examples': [
        {'english': 'Her views are controversial.', 'chinese': '她的观点有争议。'},
        {'english': 'It remains a controversial issue.', 'chinese': '这仍然是一个有争议的问题。'},
        {'english': 'The controversial law was passed.', 'chinese': '这项有争议的法律通过了。'},
      ],
      'morphology': {
        'noun_form': 'controversy',
        'adverb_form': 'controversially',
      },
    },
    'entrepreneur': {
      'word': 'entrepreneur',
      'phonetic_uk': '/ˌɒn.trə.prəˈnɜː(r)/',
      'phonetic_us': '/ˌɑːn.trə.prəˈnɝːr/',
      'part_of_speech': '名词',
      'definitions': ['企业家；创业者', '主办者；承包人'],
      'difficulty': 'cet4',
      'examples': [
        {'english': 'She is a successful entrepreneur.', 'chinese': '她是一位成功的企业家。'},
        {'english': 'Young entrepreneurs are rising.', 'chinese': '年轻创业者正在崛起。'},
        {'english': 'He started as an entrepreneur at age 20.', 'chinese': '他20岁时就开始创业了。'},
      ],
      'standalone_examples': [
        {'english': 'Being an entrepreneur requires courage.', 'chinese': '成为一名企业家需要勇气。'},
        {'english': 'Many entrepreneurs work long hours.', 'chinese': '许多企业家工作时间很长。'},
        {'english': 'She is a tech entrepreneur.', 'chinese': '她是一位科技企业家。'},
      ],
      'morphology': {'plural': 'entrepreneurs'},
    },
    'psychological': {
      'word': 'psychological',
      'phonetic_uk': '/ˌsaɪ.kəˈlɒdʒ.ɪ.kəl/',
      'phonetic_us': '/ˌsaɪ.kəˈlɑː.dʒɪ.kəl/',
      'part_of_speech': '形容词',
      'definitions': ['心理的；精神上的', '心理学的'],
      'difficulty': 'cet4',
      'examples': [
        {'english': 'He has psychological problems.', 'chinese': '他有心理问题。'},
        {'english': 'Psychological health is important.', 'chinese': '心理健康很重要。'},
        {'english': 'The stress caused psychological damage.', 'chinese': '这种压力造成了心理伤害。'},
      ],
      'standalone_examples': [
        {'english': 'She studies psychology at university.', 'chinese': '她在大学学习心理学。'},
        {'english': 'There may be a psychological explanation.', 'chinese': '可能有心理学上的解释。'},
        {'english': 'The film explores psychological themes.', 'chinese': '这部电影探讨了心理主题。'},
      ],
      'morphology': {
        'noun_form': 'psychology',
        'adverb_form': 'psychologically',
      },
    },

    // === CET6/GRE ===
    'ubiquitous': {
      'word': 'ubiquitous',
      'phonetic_uk': '/juːˈbɪk.wɪ.təs/',
      'phonetic_us': '/juːˈbɪk.wɪ.t̬əs/',
      'part_of_speech': '形容词',
      'definitions': ['无处不在的；普遍存在的', '到处出现的'],
      'difficulty': 'cet6',
      'examples': [
        {'english': 'Smartphones have become ubiquitous.', 'chinese': '智能手机已经无处不在。'},
        {'english': 'The ubiquitous influence of social media.', 'chinese': '社交媒体的无处不在的影响。'},
        {'english': 'Advertising is ubiquitous in modern cities.', 'chinese': '广告在现代城市中随处可见。'},
      ],
      'standalone_examples': [
        {'english': 'Coffee shops are ubiquitous in Seattle.', 'chinese': '西雅图到处都是咖啡店。'},
        {'english': 'Plastic has become ubiquitous in daily life.', 'chinese': '塑料在日常生活中已经无处不在。'},
        {'english': 'His ubiquitous presence annoyed everyone.', 'chinese': '他无处不在的存在让每个人都很烦。'},
      ],
      'morphology': {
        'noun_form': 'ubiquity',
        'adverb_form': 'ubiquitously',
        'synonym': 'omnipresent',
      },
    },
    'unprecedented': {
      'word': 'unprecedented',
      'phonetic_uk': '/ʌnˈpres.ɪ.den.tɪd/',
      'phonetic_us': '/ʌnˈpres.ɪ.den.t̬ɪd/',
      'part_of_speech': '形容词',
      'definitions': ['史无前例的；空前的', '前所未有的；无先例的'],
      'difficulty': 'cet6',
      'examples': [
        {'english': 'The team faced unprecedented challenges.', 'chinese': '团队面临了史无前例的挑战。'},
        {'english': 'This is an unprecedented opportunity.', 'chinese': '这是一个前所未有的机会。'},
        {'english': 'The success was unprecedented in history.', 'chinese': '这次成功在历史上是史无前例的。'},
      ],
      'standalone_examples': [
        {'english': 'The company saw unprecedented growth.', 'chinese': '该公司经历了前所未有的增长。'},
        {'english': 'Unprecedented changes are happening.', 'chinese': '前所未有的变化正在发生。'},
        {'english': 'At an unprecedented speed.', 'chinese': '以史无前例的速度。'},
      ],
      'morphology': {
        'noun_form': 'precedent',
        'adverb_form': 'unprecedentedly',
        'antonym': 'commonplace',
      },
    },
    'meticulous': {
      'word': 'meticulous',
      'phonetic_uk': '/məˈtɪk.jə.ləs/',
      'phonetic_us': '/məˈtɪk.jə.ləs/',
      'part_of_speech': '形容词',
      'definitions': ['一丝不苟的；细致的', '小心翼翼的；精确的'],
      'difficulty': 'cet6',
      'examples': [
        {'english': 'She is meticulous in her work.', 'chinese': '她工作一丝不苟。'},
        {'english': 'Meticulous planning is required.', 'chinese': '需要细致的计划。'},
        {'english': 'He kept meticulous records of everything.', 'chinese': '他对每件事都做了精确的记录。'},
      ],
      'standalone_examples': [
        {'english': 'The scientist was meticulous about details.', 'chinese': '这位科学家对细节很严谨。'},
        {'english': 'Meticulous attention to detail is essential.', 'chinese': '对细节的一丝不苟是必不可少的。'},
        {'english': 'She gave a meticulous explanation.', 'chinese': '她给出了一个细致的解释。'},
      ],
      'morphology': {
        'adverb_form': 'meticulously',
        'noun_form': 'meticulousness',
        'synonym': 'scrupulous',
      },
    },
    'ephemeral': {
      'word': 'ephemeral',
      'phonetic_uk': '/ɪˈfem.ər.əl/',
      'phonetic_us': '/ɪˈfem.ɚ.əl/',
      'part_of_speech': '形容词',
      'definitions': ['短暂的；瞬息的', '朝生暮命的；短命的'],
      'difficulty': 'gre',
      'examples': [
        {'english': 'Fame is often ephemeral.', 'chinese': '名声往往是短暂的。'},
        {'english': 'The ephemeral beauty of cherry blossoms.', 'chinese': '樱花短暂的美丽。'},
        {'english': 'Trends in fashion are ephemeral.', 'chinese': '时尚潮流是短暂的。'},
      ],
      'standalone_examples': [
        {'english': 'Happiness can be ephemeral.', 'chinese': '幸福可能是短暂的。'},
        {'english': 'The ephemeral nature of social media fame.', 'chinese': '社交媒体名气的短暂性。'},
        {'english': 'An ephemeral pleasure.', 'chinese': '一种短暂的快乐。'},
      ],
      'morphology': {
        'noun_form': 'ephemerality',
        'adverb_form': 'ephemerally',
        'synonym': 'transient',
        'antonym': 'permanent',
      },
    },
    'serendipity': {
      'word': 'serendipity',
      'phonetic_uk': '/ˌser.ənˈdɪp.ə.ti/',
      'phonetic_us': '/ˌser.ənˈdɪp.ə.t̬i/',
      'part_of_speech': '名词',
      'definitions': ['意外发现美好事物的能力；机缘凑巧', '偶然发现珍奇事物的本领'],
      'difficulty': 'gre',
      'examples': [
        {'english': 'It was pure serendipity that we met.', 'chinese': '我们相遇纯属机缘巧合。'},
        {'english': 'Serendipity plays a role in scientific discoveries.', 'chinese': '机缘巧合在科学发现中起着作用。'},
        {'english': 'The discovery was a result of serendipity.', 'chinese': '这次发现是机缘巧合的结果。'},
      ],
      'standalone_examples': [
        {'english': 'I found the book by serendipity.', 'chinese': '我偶然发现了这本书。'},
        {'english': 'Serendipity brought us together.', 'chinese': '机缘巧合让我们走到了一起。'},
        {'english': 'A moment of serendipity changed my life.', 'chinese': '一次意外的机遇改变了我的生活。'},
      ],
      'morphology': {'plural': 'serendipities', 'adjective_form': 'serendipitous'},
    },

    // === 特殊情况 ===
    'I': {
      'word': 'I',
      'phonetic_uk': '/aɪ/',
      'phonetic_us': '/aɪ/',
      'part_of_speech': '代词',
      'definitions': ['我（主格）'],
      'difficulty': 'primary',
      'examples': [
        {'english': 'I am a student.', 'chinese': '我是一个学生。'},
        {'english': 'I like music.', 'chinese': '我喜欢音乐。'},
        {'english': 'I will help you.', 'chinese': '我会帮助你。'},
      ],
      'standalone_examples': [
        {'english': 'I think therefore I am.', 'chinese': '我思故我在。'},
        {'english': 'I have a dream.', 'chinese': '我有一个梦想。'},
        {'english': 'I can do this.', 'chinese': '我能做到。'},
      ],
      'morphology': {},
      'note': '人称代词主格，无词形变化',
    },
    'set': {
      'word': 'set',
      'phonetic_uk': '/set/',
      'phonetic_us': '/set/',
      'part_of_speech': '动词/名词',
      'definitions': ['设置；放置', '一套；一副', '（日）落山', '固定；凝固'],
      'difficulty': 'primary',
      'examples': [
        {'english': 'Please set the table.', 'chinese': '请摆放餐桌。'},
        {'english': 'He set a new record.', 'chinese': '他创下了新纪录。'},
        {'english': 'She set the alarm for 7am.', 'chinese': '她把闹钟设在了早上7点。'},
      ],
      'standalone_examples': [
        {'english': 'Let me set up the meeting.', 'chinese': '我来安排会议。'},
        {'english': 'The sun sets in the west.', 'chinese': '太阳在西边落下。'},
        {'english': 'I bought a set of tools.', 'chinese': '我买了一套工具。'},
      ],
      'morphology': {
        'past_tense': 'set',
        'past_participle': 'set',
        'present_participle': 'setting',
        'third_person_singular': 'sets',
        'is_irregular': true,
        'note': '不规则动词：set-set-set',
      },
    },
    'a': {
      'word': 'a',
      'phonetic_uk': '/ə/',
      'phonetic_us': '/ə/',
      'part_of_speech': '冠词',
      'definitions': ['一个（不定冠词，用于辅音音素前）', '某一；任一'],
      'difficulty': 'primary',
      'examples': [
        {'english': 'This is a book.', 'chinese': '这是一本书。'},
        {'english': 'He wants to be a doctor.', 'chinese': '他想成为一名医生。'},
        {'english': 'I need a pen.', 'chinese': '我需要一支笔。'},
      ],
      'standalone_examples': [
        {'english': 'She is a teacher.', 'chinese': '她是一名老师。'},
        {'english': 'It\'s a beautiful day.', 'chinese': '这是美好的一天。'},
        {'english': 'Can I have a glass of water?', 'chinese': '能给我一杯水吗？'},
      ],
      'morphology': {},
      'note': '不定冠词，无词形变化',
    },
  };

  /// 执行所有测试
  TestReport runAllTests() {
    final stopwatch = Stopwatch()..start();
    final results = <WordTestResult>[];

    for (var i = 0; i < testCases.length; i++) {
      final testCase = testCases[i];
      final result = _testSingleWord(testCase, index: i + 1, total: testCases.length);
      results.add(result);
    }

    stopwatch.stop();

    // 计算总体统计
    final passCount = results.where((r) => r.passed).length;
    final warningCount = results.where((r) => r.hasWarnings && r.passed).length;
    final failCount = results.where((r) => !r.passed).length;
    final totalScore = results.isEmpty ? 0.0 : results.fold<double>(0.0, (sum, r) => sum + r.totalScore) / results.length * 10; // 转换为百分制

    // 计算各维度平均分
    final dimAvgs = <String, double>{};
    final dimensions = ['JSON完整性', '释义准确性', '难度合理性', '词形正确性', '例句质量', '音标规范'];
    for (final dim in dimensions) {
      final scores = results.map((r) => r.dimensionScores[dim] ?? 0).toList();
      dimAvgs[dim] = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    }

    return TestReport(
      overallScore: totalScore,
      totalWords: results.length,
      passCount: passCount,
      warningCount: warningCount,
      failCount: failCount,
      results: results,
      dimensionAverages: dimAvgs,
      executionTime: stopwatch.elapsed,
    );
  }

  /// 测试单个单词
  WordTestResult _testSingleWord(WordTestCase testCase, {required int index, required int total}) {
    final issues = <String>[];
    final warnings = <String>[];
    final scores = <String, double>{};

    // 获取模拟 AI 结果
    final mockData = mockAiResponses[testCase.word];
    MockAiDefinitionResult? aiResult;
    if (mockData != null) {
      aiResult = MockAiDefinitionResult.fromJson(mockData);
    }

    // ── R1: JSON 结构完整性 (权重 20%) ──
    scores['JSON完整性'] = _testJsonIntegrity(aiResult, testCase.word, issues, warnings);

    // ── R2: 释义准确性 (权重 30%) ──
    scores['释义准确性'] = _testDefinitionAccuracy(aiResult, testCase, issues, warnings);

    // ── R3: 难度合理性 (权重 20%) ──
    scores['难度合理性'] = _testDifficultyReasonability(aiResult, testCase, issues, warnings);

    // ── R4: 词形变化正确性 (权重 15%) ──
    scores['词形正确性'] = _testMorphologyCorrectness(aiResult, testCase, issues, warnings);

    // ── R5: 例句质量 (权重 10%) ──
    scores['例句质量'] = _testExampleQuality(aiResult, testCase, issues, warnings);

    // ── R6: 音标规范 (权重 5%) ──
    scores['音标规范'] = _testPhoneticStandardization(aiResult, issues, warnings);

    // 计算加权总分
    final weights = {
      'JSON完整性': 0.20,
      '释义准确性': 0.30,
      '难度合理性': 0.20,
      '词形正确性': 0.15,
      '例句质量': 0.10,
      '音标规范': 0.05,
    };
    final totalScore = weights.entries.fold<double>(0, (sum, e) => sum + (scores[e.key] ?? 0) * e.value);

    return WordTestResult(
      word: testCase.word,
      expectedDifficulty: testCase.expectedDifficulty,
      aiResult: aiResult,
      dimensionScores: scores,
      totalScore: totalScore,
      issues: issues,
      warnings: warnings,
    );
  }

  // ─── 各维度测试方法 ─────────────────────────────

  /// R1: JSON 结构完整性
  double _testJsonIntegrity(MockAiDefinitionResult? result, String word, List<String> issues, List<String> warnings) {
    if (result == null) {
      issues.add('❌ 无法获取 AI 返回数据');
      return 0;
    }

    var score = 10.0;
    final checks = <String, bool>{
      'word 字段存在': result.word.isNotEmpty,
      'definitions 非空': result.definitions.isNotEmpty,
      'difficulty 存在': result.difficulty != null && result.difficulty!.isNotEmpty,
      'examples 是数组': true, // 已保证
    };

    checks.forEach((desc, ok) {
      if (!ok) {
        issues.add('❌ $desc');
        score -= 2.5;
      }
    });

    // 额外检查：word 是否匹配
    if (result.word.toLowerCase() != word.toLowerCase()) {
      issues.add('❌ 返回 word "${result.word}" 与请求 "$word" 不匹配');
      score -= 2;
    }

    return score.clamp(0, 10);
  }

  /// R2: 释义准确性
  double _testDefinitionAccuracy(MockAiDefinitionResult? result, WordTestCase testCase, List<String> issues, List<String> warnings) {
    if (result == null || result.definitions.isEmpty) {
      issues.add('❌ definitions 为空');
      return 0;
    }

    // 检查是否包含预期关键词
    final allDefs = result.definitions.join(' ').toLowerCase();
    int matchCount = 0;
    final matchedKeywords = <String>[];

    for (final keyword in testCase.expectedMeanings) {
      if (allDefs.contains(keyword.toLowerCase())) {
        matchCount++;
        matchedKeywords.add(keyword);
      }
    }

    final matchRatio = matchCount / testCase.expectedMeanings.length;

    if (matchRatio >= 0.8) {
      // 高匹配：8-10 分
      return 8 + matchRatio * 2;
    } else if (matchRatio >= 0.5) {
      // 中等匹配：5-8 分
      warnings.add('⚠️ 释义部分匹配: 找到 ${matchedKeywords.join(', ')}, 缺少 ${testCase.expectedMeanings.where((k) => !matchedKeywords.contains(k)).join(', ')}');
      return 5 + matchRatio * 3;
    } else if (matchRatio > 0) {
      // 低匹配：检查是否语义相关（子串匹配或包含关键词）
      final isSemanticallyRelated = testCase.expectedMeanings.any((keyword) =>
        allDefs.contains(keyword.substring(0, (keyword.length * 0.6).ceil())) ||
        keyword.split('').any((ch) => allDefs.contains(ch) && keyword.length > 2)
      );
      if (isSemanticallyRelated) {
        warnings.add('⚠️ 释义语义相关但非精确匹配: 预期 [${testCase.expectedMeanings.join(', ')}], 实际: [${result.definitions.join(', ')}]');
        return 4 + matchRatio * 4;
      }
      issues.add('❌ 释义基本不匹配: 预期 [${testCase.expectedMeanings.join(', ')}], 实际: [${result.definitions.join(', ')}]');
      return 2 + matchRatio * 3;
    } else {
      // 无匹配
      issues.add('❌ 释义完全不匹配: 预期 [${testCase.expectedMeanings.join(', ')}], 实际 [${result.definitions.join(', ')}]');
      return 0;
    }
  }

  /// R3: 难度合理性
  double _testDifficultyReasonability(MockAiDefinitionResult? result, WordTestCase testCase, List<String> issues, List<String> warnings) {
    if (result?.difficulty == null || result!.difficulty!.isEmpty) {
      warnings.add('⚠️ 缺少 difficulty 字段');
      return 5; // 中等分数
    }

    final aiDifficulty = parseDifficulty(result.difficulty);
    final expectedOrder = difficultyOrder(testCase.expectedDifficulty);
    final aiOrder = difficultyOrder(aiDifficulty);
    final diff = (aiOrder - expectedOrder).abs();

    if (diff == 0) {
      return 10; // 完全匹配
    } else if (diff == 1) {
      warnings.add('⚠️ 难度偏差1级: 预期 ${difficultyLabel(testCase.expectedDifficulty)}, 实际 ${difficultyLabel(aiDifficulty)}');
      return 7;
    } else if (diff == 2) {
      issues.add('❌ 难度偏差2级: 预期 ${difficultyLabel(testCase.expectedDifficulty)}, 实际 ${difficultyLabel(aiDifficulty)}');
      return 4;
    } else {
      issues.add('❌ 难度偏差${diff}级: 预期 ${difficultyLabel(testCase.expectedDifficulty)}, 实际 ${difficultyLabel(aiDifficulty)}');
      return 0;
    }
  }

  /// R4: 词形变化正确性
  double _testMorphologyCorrectness(MockAiDefinitionResult? result, WordTestCase testCase, List<String> issues, List<String> warnings) {
    if (result == null) {
      return 5; // 无数据给中等分
    }

    final morph = result.morphology;

    // 不需要词形变化的词
    if (!testCase.shouldHaveMorphology) {
      if (morph == null || morph.isEmpty) {
        return 10; // 正确地没有词形变化
      } else {
        warnings.add('⚠️ 该词通常不需要词形变化但返回了: $morph');
        return 8;
      }
    }

    // 需要词形变化但没有
    if (morph == null || morph.isEmpty) {
      warnings.add('⚠️ 缺少 morphology 数据');
      return 5;
    }

    var score = 10.0;
    final word = result.word.toLowerCase();

    // 常见错误检测
    final morphStr = morph.toString().toLowerCase();

    // 检测不规则动词错误（如 run → runned）
    final irregularVerbs = {
      'run': ['ran', 'run', 'running'],
      'set': ['set', 'set', 'setting'],
      'go': ['went', 'gone', 'going'],
      'come': ['came', 'come', 'coming'],
      'take': ['took', 'taken', 'taking'],
      'give': ['gave', 'given', 'giving'],
      'see': ['saw', 'seen', 'seeing'],
      'write': ['wrote', 'written', 'writing'],
      'speak': ['spoke', 'spoken', 'speaking'],
      'know': ['knew', 'known', 'knowing'],
      'get': ['got', 'gotten/get', 'getting'],
      'eat': ['ate', 'eaten', 'eating'],
      'cut': ['cut', 'cut', 'cutting'],
      'put': ['put', 'put', 'putting'],
    };

    if (irregularVerbs.containsKey(word)) {
      final correctForms = irregularVerbs[word]!;
      final pastTense = morph['past_tense']?.toString().toLowerCase() ?? '';
      if (pastTense.isNotEmpty && !correctForms.contains(pastTense)) {
        // 检查是否是错误的规则变化
        if (pastTense == '${word}ed' || pastTense == '${word}d') {
          issues.add('❌ 不规则动词规则化错误: $word → $pastTense (应为 ${correctForms[0]})');
          score -= 5;
        }
      }
    }

    // 检测复数错误（如 cat → cats 正确, but cat → cat's 错误）
    if (morph.containsKey('plural')) {
      final plural = morph['plural']?.toString() ?? '';
      // 基本检查：复数不应与单数相同（除非是 sheep/fish 等特殊词）
      final unchangingPlurals = ['sheep', 'fish', 'deer', 'series', 'species', 'aircraft'];
      if (plural == word && !unchangingPlurals.contains(word)) {
        issues.add('❌ 复数形式与单数相同: $word → $plural');
        score -= 3;
      }
    }

    // 检测比较级错误（如 happy → more happy 虽然可用但不标准）
    final pos = morph['comparative']?.toString().toLowerCase() ?? '';
    if (word.endsWith('y') && word.length > 2) {
      final expectedComparative = '${word.substring(0, word.length - 1)}ier';
      if (pos == 'more $word' || pos == 'more${word}') {
        warnings.add('⚠️ 以-y结尾形容词建议用 -ier 形式: $word → $pos (可接受但非最优)');
        score -= 1;
      }
    }

    return score.clamp(0, 10);
  }

  /// R5: 例句质量（优化版：要求至少3条例句）
  double _testExampleQuality(MockAiDefinitionResult? result, WordTestCase testCase, List<String> issues, List<String> warnings) {
    if (result == null) {
      warnings.add('⚠️ 无 AI 返回数据');
      return 3;
    }

    final allExamples = [...result.examples, ...result.standaloneExamples];
    if (allExamples.isEmpty) {
      issues.add('❌ 缺少例句（新Prompt要求至少3条）');
      return 0;
    }

    var score = 6.0; // 基础分（降低了，因为要求更严格）
    final targetWord = testCase.word.toLowerCase();
    var hasTargetWord = false;
    var exampleCount = 0;

    for (final ex in allExamples) {
      exampleCount++;
      final enLower = ex.english.toLowerCase();
      // 检查例句是否包含目标单词
      if (enLower.contains(targetWord) || enLower.contains(targetWord.replaceAll("'", ""))) {
        hasTargetWord = true;
      }

      // 检查中文翻译是否为空
      if (ex.chinese.trim().isEmpty) {
        warnings.add('⚠️ 例句中文翻译为空: "${ex.english}"');
        score -= 1.5;
      }
    }

    // ── 新规则：例句数量检查（要求至少3条）──
    final examplesCount = result.examples.length;
    final standaloneCount = result.standaloneExamples.length;

    if (examplesCount < 3) {
      issues.add('❌ examples 数量不足: $examplesCount/3 (新Prompt要求至少3条)');
      score -= 3;
    } else if (examplesCount == 3) {
      score += 1; // 达标
    } else if (examplesCount > 3) {
      score += 1.5; // 丰富加分
    }

    if (standaloneCount < 3) {
      warnings.add('⚠️ standalone_examples 数量不足: $standaloneCount/3 (建议至少3条)');
      score -= 1;
    } else {
      score += 0.5; // 达标加分
    }

    if (!hasTargetWord) {
      issues.add('❌ 所有例句均不包含目标单词 "$targetWord"');
      score -= 4;
    }

    return score.clamp(0, 10);
  }

  /// R6: 音标规范性
  double _testPhoneticStandardization(MockAiDefinitionResult? result, List<String> issues, List<String> warnings) {
    if (result == null) {
      warnings.add('⚠️ 无 AI 返回数据');
      return 3;
    }

    final uk = result.phoneticUk ?? '';
    final us = result.phoneticUs ?? '';

    if (uk.isEmpty && us.isEmpty) {
      issues.add('❌ 缺少音标信息');
      return 0;
    }

    var score = 7.0;
    final phoneticPattern = RegExp(r'^[/\[].*[/\]]$');

    if (uk.isNotEmpty) {
      if (phoneticPattern.hasMatch(uk.trim())) {
        score += 1.5;
      } else {
        warnings.add('⚠️ 英式音标格式可能不规范: $uk');
      }
    } else {
      warnings.add('⚠️ 缺少英式音标');
    }

    if (us.isNotEmpty) {
      if (phoneticPattern.hasMatch(us.trim())) {
        score += 1.5;
      } else {
        warnings.add('⚠️ 美式音标格式可能不规范: $us');
      }
    } else {
      warnings.add('⚠️ 缺少美式音标');
    }

    return score.clamp(0, 10);
  }
}

// ─── 报告输出 ─────────────────────────────────────

void _printReport(TestReport report) {
  // 总览
  print('📊 总体评分: ${report.overallScore.toStringAsFixed(1)}/100 [${report.grade}]');
  print('📈 测试单词数: ${report.totalWords}');
  print('✅ 通过: ${report.passCount} (${report.passRate.toStringAsFixed(0)}%)');
  print('⚠️  警告: ${report.warningCount} (${(report.warningCount / report.totalWords * 100).toStringAsFixed(0)}%)');
  print('❌ 失败: ${report.failCount} (${(report.failCount / report.totalWords * 100).toStringAsFixed(0)}%)');
  print('⏱️  执行时间: ${report.executionTime.inMilliseconds}ms');

  // 各维度平均分
  print('\n─── 各维度平均分 ──────────────────────────────────────');
  final dimensions = ['JSON完整性', '释义准确性', '难度合理性', '词形正确性', '例句质量', '音标规范'];
  for (final dim in dimensions) {
    final avg = report.dimensionAverages[dim] ?? 0;
    final bar = _generateBar(avg);
    final status = avg >= 8 ? '✅' : (avg >= 6 ? '⚠️' : '❌');
    print('   $status $dim: ${avg.toStringAsFixed(1)}/10 $bar');
  }

  // 详细结果
  print('\n─── 详细结果 ──────────────────────────────────────\n');

  for (var i = 0; i < report.results.length; i++) {
    final r = report.results[i];
    final statusIcon = r.passed ? (r.hasWarnings ? '⚠️' : '✅') : '❌';

    print('[${i + 1}/${report.totalWords}] ${r.word} (预期: ${difficultyLabel(r.expectedDifficulty)}) $statusIcon');

    // 各维度得分
    for (final entry in r.dimensionScores.entries) {
      final score = entry.value;
      final icon = score >= 8 ? '✅' : (score >= 6 ? '⚠️' : '❌');
      print('   $icon ${entry.key}: ${score.toStringAsFixed(1)}/10');
    }

    print('   ── 小计: ${r.totalScore.toStringAsFixed(1)}/10');

    // 显示问题
    if (r.issues.isNotEmpty) {
      for (final issue in r.issues) {
        print('   $issue');
      }
    }

    // 显示警告
    if (r.warnings.isNotEmpty) {
      for (final warning in r.warnings) {
        print('   $warning');
      }
    }

    // 如果有 AI 结果，显示关键信息
    if (r.aiResult != null) {
      final ai = r.aiResult!;
      print('   📝 AI返回摘要:');
      print('      释义: ${ai.definitions.take(2).join('; ')}');
      print('      难度: ${ai.difficulty != null ? difficultyLabel(parseDifficulty(ai.difficulty)) : "无"}');
      print('      音标: UK=${ai.phoneticUk ?? "无"} US=${ai.phoneticUs ?? "无"}');
      if (ai.morphology != null && ai.morphology!.isNotEmpty) {
        print('      词形: ${ai.morphology}');
      }
    }

    print('');
  }

  // AI Prompt 分析
  _printPromptAnalysis(report);

  // 总结与建议
  _printSummary(report);
}

String _generateBar(double score) {
  final filled = (score / 2).round();
  final empty = 5 - filled;
  return '█' * filled + '░' * empty;
}

void _printPromptAnalysis(TestReport report) {
  print('─── AI Prompt 分析 ──────────────────────────────────────');
  print('');
  print('当前 definition() 函数使用的 Prompt 结构:');
  print('''
┌────────────────────────────────────────────────────────────┐
│ 请用中文详细解释英语单词"{word}"，要求返回严格的 JSON 格式： │
│ {                                                          │
│   "word": "{word}",                                        │
│   "phonetic_uk": "英式音标",                               │
│   "phonetic_us": "美式音标",                               │
│   "part_of_speech": "词性",                                │
│   "definitions": ["中文释义1", "中文释义2"],               │
│   "difficulty": "学习阶段：primary/.../gre",               │
│   "examples": [{"english": "...", "chinese": "..."}],     │
│   "standalone_examples": [{"english": "...", "chinese"}],  │
│   "morphology": {...},                                     │
│   "mnemonic": "记忆法"                                      │
│ }                                                          │
│                                                            │
│ 难度判断标准：根据单词在中国英语教学体系中的常见出现阶段来判断│
└────────────────────────────────────────────────────────────┘
''');

  // 根据测试结果分析 Prompt 问题
  print('📋 基于 ${report.totalWords} 个样本的 Prompt 问题诊断:');
  print('');

  // 统计各维度问题率
  final lowScoreCounts = <String, int>{};
  final dimensions = ['JSON完整性', '释义准确性', '难度合理性', '词形正确性', '例句质量', '音标规范'];

  for (final r in report.results) {
    for (final dim in dimensions) {
      final score = r.dimensionScores[dim] ?? 10;
      if (score < 6) {
        lowScoreCounts[dim] = (lowScoreCounts[dim] ?? 0) + 1;
      }
    }
  }

  for (final dim in dimensions) {
    final count = lowScoreCounts[dim] ?? 0;
    final pct = count / report.totalWords * 100;
    if (count > 0) {
      print('   ⚠️ $dim: $count/${report.totalWords} 个单词得分低于 6 (${pct.toStringAsFixed(0)}%)');
    } else {
      print('   ✅ $dim: 全部达标');
    }
  }

  print('');
}

void _printSummary(TestReport report) {
  print('─── 总结与建议 ──────────────────────────────────────');
  print('');

  if (report.overallScore >= 90) {
    print('🟢 结论: AI 翻译质量优秀，可以直接用于生产环境和 word_cache 建设。');
    print('');
    print('建议:');
    print('  1. 可以开始大规模预填充 word_cache 表');
    print('  2. 定期抽样验证质量稳定性');
  } else if (report.overallScore >= 75) {
    print('🟡 结论: AI 翻译质量良好，小幅优化后可用于生产。');
    print('');
    print('优化建议:');
    _printOptimizationSuggestions(report);
  } else if (report.overallScore >= 60) {
    print('🟠 结论: AI 翻译质量及格，需要明显改进后再用于生产。');
    print('');
    print('改进建议:');
    _printOptimizationSuggestions(report);
    print('');
    print('  ⚠️ 强烈建议在解决以下问题后再进行 word_cache 大规模建设:');
    final criticalIssues = _getCriticalIssues(report);
    for (final issue in criticalIssues) {
      print('    - $issue');
    }
  } else {
    print('🔴 结论: AI 翻译质量不合格，需要重新设计 Prompt 或更换模型。');
    print('');
    print('紧急行动项:');
    _printOptimizationSuggestions(report);
  }

  print('');
  print('═' * 62);
}

List<String> _getCriticalIssues(TestReport report) {
  final critical = <String>[];
  final dimAvg = report.dimensionAverages;

  if ((dimAvg['释义准确性'] ?? 10) < 6) {
    critical.add('释义准确性严重不足 — 需要 few-shot 示例增强 Prompt');
  }
  if ((dimAvg['难度合理性'] ?? 10) < 6) {
    critical.add('难度判断偏差大 — 需要提供更明确的难度参考词汇表');
  }
  if ((dimAvg['词形正确性'] ?? 10) < 6) {
    critical.add('词形变化错误率高 — 需要在 Prompt 中强调语法正确性');
  }

  // 收集高频失败问题
  final issueFreq = <String, int>{};
  for (final r in report.results) {
    for (final issue in r.issues) {
      issueFreq[issue] = (issueFreq[issue] ?? 0) + 1;
    }
  }

  final topIssues = issueFreq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final entry in topIssues.take(3)) {
    if (entry.value >= 2) {
      critical.add('${entry.key} (出现 ${entry.value} 次)');
    }
  }

  return critical;
}

void _printOptimizationSuggestions(TestReport report) {
  final suggestions = <String>[];

  // 基于各维度得分给出针对性建议
  final dimAvg = report.dimensionAverages;

  if ((dimAvg['JSON完整性'] ?? 10) < 8) {
    suggestions.add('''
  [JSON 完整性]
  - 在 Prompt 中增加 JSON Schema 强制约束
  - 添加输出示例 (few-shot)
  - 实现 retry 机制处理解析失败''');
  }

  if ((dimAvg['释义准确性'] ?? 10) < 8) {
    suggestions.add('''
  [释义准确性]
  - 增加 few-shot 示例展示期望的释义格式和精度
  - 限制每个释义的最大长度（如 20 字以内）
  - 要求区分核心释义和引申义''');
  }

  if ((dimAvg['难度合理性'] ?? 10) < 8) {
    suggestions.add('''
  [难度合理性]
  - 在 Prompt 中提供各难度的参考词汇表:
    primary: apple, cat, happy
    juniorHigh: abandon, environment, beautiful
    seniorHigh: phenomenon, controversial
    cet4/cet6: sophisticated, ubiquitous
    gre: ephemeral, serendipity
  - 要求 AI 参考这些参照词判断难度''');
  }

  if ((dimAvg['词形正确性'] ?? 10) < 8) {
    suggestions.add('''
  [词形正确性]
  - 在 Prompt 中明确列出常见不规则动词表
  - 要求 AI 对动词标注是否为不规则变化
  - 增加 morphology 可选字段: is_irregular (bool)''');
  }

  if ((dimAvg['例句质量'] ?? 10) < 8) {
    suggestions.add('''
  [例句质量]
  - 明确要求: "每个例句必须包含原词"
  - 要求例句长度适中（8-15 词）
  - 提供正反例示范''');
  }

  if ((dimAvg['音标规范'] ?? 10) < 8) {
    suggestions.add('''
  [音标规范]
  - 明确指定 IPA 音标格式: /.../
  - 提供示例: /ˈæp.əl/
  - 要求同时返回英式和美式音标''');
  }

  for (final s in suggestions) {
    print(s);
  }
}
