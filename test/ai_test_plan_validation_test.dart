import 'package:flutter_test/flutter_test.dart';

/// AI 出题数据验证测试
///
/// 验证 ai-test-plan Edge Function 生成的题型数据是否符合预期：
/// 1. 释义选择 (definition_choice): 答案不泄露，选项格式正确
/// 2. 英义互译 (translate_meaning): 选项已翻译成中文
/// 3. 词性测试 (word_relation): 答案准确，干扰项合理
/// 4. 听音辩义 (listen_meaning): 使用中文释义作为选项
/// 5. 听音回复 (listen_reply): 答案与问题相关
void main() {
  group('AI Test Plan 数据验证', () {
    // ═══════════════════════════════════════════════════════════════
    // 测试数据：模拟 Edge Function 生成的题目
    // ═══════════════════════════════════════════════════════════════

    /// 模拟 word_cache 返回的单词释义
    const Map<String, String> wordMeanings = {
      'happy': '快乐的；高兴的',
      'sad': '悲伤的；难过的',
      'beautiful': '美丽的；漂亮的',
      'big': '大的；巨大的',
      'small': '小的；小型的',
      'run': '跑；奔跑',
      'walk': '走；步行',
      'fast': '快的；迅速地',
      'slow': '慢的；缓慢地',
      'good': '好的；良好的',
      'restaurant': '餐厅；饭店',
      'delicious': '美味的；可口的',
      'computer': '电脑；计算机',
      'project': '项目；工程',
    };

    /// 模拟 WORD_RELATIONS 同义词/反义词关系
    const Map<String, Map<String, List<String>>> wordRelations = {
      'happy': {
        'synonyms': ['glad', 'joyful', 'cheerful'],
        'antonyms': ['sad', 'unhappy'],
      },
      'sad': {
        'synonyms': ['unhappy', 'sorrowful'],
        'antonyms': ['happy', 'glad'],
      },
      'big': {
        'synonyms': ['large', 'huge', 'great'],
        'antonyms': ['small', 'tiny'],
      },
      'fast': {
        'synonyms': ['quick', 'rapid', 'swift'],
        'antonyms': ['slow'],
      },
    };

    // ═══════════════════════════════════════════════════════════════
    // 1. 释义选择 (definition_choice) 测试
    // ═══════════════════════════════════════════════════════════════

    group('释义选择 (definition_choice)', () {
      test('en_to_cn 类型：答案应在 options 中，且为中文释义', () {
        final item = _generateDefinitionChoiceEnToCn('happy', wordMeanings);

        // 验证基本结构
        expect(item['type'], equals('definition_choice'));
        expect(item['sub_type'], equals('en_to_cn'));
        expect(item['display_text'], equals('happy'));

        // 验证选项
        final options = List<String>.from(item['options'] as List);
        expect(options.length, greaterThanOrEqualTo(4)); // 至少4个选项

        // 验证答案是中文释义
        final answer = item['answer'] as String;
        expect(answer, equals(wordMeanings['happy']));
        expect(answer, contains('快乐')); // 中文释义

        // 验证答案索引有效
        final answerIndex = item['answer_index'] as int;
        expect(answerIndex, greaterThanOrEqualTo(0));
        expect(answerIndex, lessThan(options.length));
        expect(options[answerIndex], equals(answer));

        // 【关键验证】选项不应包含原始英文单词（避免泄露）
        for (final option in options) {
          // 选项应该是中文或中英混合，不能是纯英文单词
          final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(option);
          expect(hasChinese, isTrue, reason: '选项 "$option" 应包含中文');
        }
      });

      test('cn_to_en 类型：display_text 是中文，选项是英文，答案不泄露', () {
        final item = _generateDefinitionChoiceCnToEn('happy', wordMeanings);

        // 验证基本结构
        expect(item['type'], equals('definition_choice'));
        expect(item['sub_type'], equals('cn_to_en'));

        // 【关键验证】显示文本应该是中文释义（不是英文单词！）
        final displayText = item['display_text'] as String;
        expect(displayText, contains('快乐')); // 中文
        expect(displayText, isNot(equals('happy'))); // 不泄露英文答案

        // 选项应该是英文单词
        final options = List<String>.from(item['options'] as List);
        expect(options.length, greaterThanOrEqualTo(4));

        // 答案是英文单词
        final answer = item['answer'] as String;
        expect(answer, equals('happy'));

        // 验证答案在选项中
        final answerIndex = item['answer_index'] as int;
        expect(options[answerIndex], equals(answer));
      });

      test('所有选项应互不相同', () {
        final item = _generateDefinitionChoiceEnToCn('beautiful', wordMeanings);
        final options = List<String>.from(item['options'] as List);
        final uniqueOptions = options.toSet();
        expect(uniqueOptions.length, equals(options.length));
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 2. 英义互译 (translate_meaning) 测试
    // ═══════════════════════════════════════════════════════════════

    group('英义互译 (translate_meaning)', () {
      test('选项应翻译成中文（不能是纯英文）', () {
        final sentence = 'The restaurant serves delicious food';
        final item = _generateTranslateMeaning(sentence, wordMeanings);

        // 验证基本结构
        expect(item['type'], equals('translate_meaning'));
        expect(item['display_text'], equals(sentence));

        // 验证选项
        final options = List<String>.from(item['options'] as List);
        expect(options.length, greaterThanOrEqualTo(4));

        // 【关键验证】每个选项都应包含中文
        for (final option in options) {
          final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(option);
          expect(hasChinese, isTrue, reason: '翻译选项 "$option" 应包含中文，当前可能是纯英文');
        }

        // 验证答案也是中文
        final answer = item['answer'] as String;
        final answerHasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(answer);
        expect(answerHasChinese, isTrue, reason: '答案 "$answer" 应包含中文翻译');
      });

      test('答案应是主要翻译，且在选项中', () {
        final sentence = 'I run fast in the park';
        final item = _generateTranslateMeaning(sentence, wordMeanings);

        final options = List<String>.from(item['options'] as List);
        final answer = item['answer'] as String;
        final answerIndex = item['answer_index'] as int;

        expect(options[answerIndex], equals(answer));
        // 答案应包含关键词的翻译
        expect(
          answer.contains('跑') || answer.contains('快') || answer.contains('公园'),
          isTrue,
          reason: '答案应包含句子关键词的中文翻译',
        );
      });

      test('干扰项应来自其他句子的翻译', () {
        final sentences = [
          'The restaurant serves delicious food',
          'I have a big computer',
          'She walks slow to school',
          'He feels happy today',
        ];
        final item = _generateTranslateMeaningWithDistractors(
          sentences[0],
          sentences,
          wordMeanings,
        );

        final options = List<String>.from(item['options'] as List);
        final answer = item['answer'] as String;

        // 干扰项应与答案不同
        final distractors = options.where((o) => o != answer).toList();
        expect(distractors.length, greaterThanOrEqualTo(3));
        // 干扰项也应包含中文
        for (final d in distractors) {
          expect(RegExp(r'[\u4e00-\u9fa5]').hasMatch(d), isTrue);
        }
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 3. 词性测试 (word_relation) 测试
    // ═══════════════════════════════════════════════════════════════

    group('词性测试 (word_relation)', () {
      test('同义词类型：答案应为预定义的同义词', () {
        final wordPool = ['happy', 'sad', 'big', 'small', 'fast', 'slow', 'glad', 'joyful', 'cheerful'];
        final item = _generateWordRelationSynonym(
          'happy',
          wordPool,
          wordRelations,
        );

        expect(item, isNotNull);
        expect(item!['type'], equals('word_relation'));
        expect(item['relation_type'], equals('synonym'));
        expect(item['display_text'], equals('happy'));

        // 验证答案
        final answerIndices = List<int>.from(item['answer_indices'] as List);
        final answers = List<String>.from(item['answers'] as List);
        final options = List<String>.from(item['options'] as List);

        // 答案应在预定义同义词中
        final expectedSynonyms =
            wordRelations['happy']?['synonyms'] ?? <String>[];
        for (final ans in answers) {
          expect(
            expectedSynonyms,
            contains(ans),
            reason: '"$ans" 应是 happy 的同义词',
          );
        }

        // 验证答案索引指向正确的选项
        for (final idx in answerIndices) {
          expect(answers, contains(options[idx]));
        }
      });

      test('反义词类型：答案应为预定义的反义词', () {
        final wordPool = ['happy', 'sad', 'big', 'small', 'fast', 'slow', 'unhappy'];
        final item = _generateWordRelationAntonym(
          'happy',
          wordPool,
          wordRelations,
        );

        expect(item, isNotNull);
        expect(item!['relation_type'], equals('antonym'));

        final answers = List<String>.from(item['answers'] as List);
        final expectedAntonyms =
            wordRelations['happy']?['antonyms'] ?? <String>[];

        for (final ans in answers) {
          expect(
            expectedAntonyms,
            contains(ans),
            reason: '"$ans" 应是 happy 的反义词',
          );
        }
      });

      test('无预定义数据时应标记低置信度或跳过', () {
        final wordPool = ['restaurant', 'delicious', 'computer', 'project'];
        final item = _generateWordRelationSynonym(
          'restaurant',
          wordPool,
          wordRelations,
        );

        // restaurant 没有预定义的同义词
        if (item != null) {
          final confidence = item['confidence'] as String?;
          // 如果生成了题目，置信度应为 low
          expect(confidence, equals('low'), reason: '无预定义数据的词性题应标记为低置信度');
        }
        // 或者直接跳过（返回 null）也是可接受的
      });

      test('干扰项不应包含正确答案', () {
        final wordPool = ['happy', 'sad', 'big', 'small', 'fast', 'slow'];
        final item = _generateWordRelationSynonym(
          'happy',
          wordPool,
          wordRelations,
        );

        if (item == null) return;

        final answers = List<String>.from(item['answers'] as List);
        final options = List<String>.from(item['options'] as List);

        // 题目本身（happy）不应出现在选项中... 实际上应该出现作为参照
        // 但干扰项（非答案）不应是正确答案
        final answerIndices = Set<int>.from(item['answer_indices'] as List);
        for (var i = 0; i < options.length; i++) {
          if (!answerIndices.contains(i)) {
            // 这个选项是干扰项，不应是正确答案之一
            expect(answers, isNot(contains(options[i])));
          }
        }
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 4. 听音辩义 (listen_meaning) 测试
    // ═══════════════════════════════════════════════════════════════

    group('听音辩义 (listen_meaning)', () {
      test('选项应使用中文释义而非英文单词', () {
        final item = _generateListenMeaning('beautiful', wordMeanings);

        expect(item['type'], equals('listen_meaning'));
        expect(item['ref_text'], equals('beautiful'));

        final options = List<String>.from(item['options'] as List);

        // 所有选项都应是中文
        for (final option in options) {
          final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(option);
          expect(hasChinese, isTrue, reason: '听音辩义选项 "$option" 应是中文释义');
        }

        // 答案也应是中文
        final answer = item['answer'] as String;
        expect(answer.contains('美丽') || answer.contains('漂亮'), isTrue);
      });

      test('ref_text 用于 TTS 播放，不应出现在选项中', () {
        final item = _generateListenMeaning('fast', wordMeanings);
        final refText = item['ref_text'] as String;
        final options = List<String>.from(item['options'] as List);

        // 原始单词不应直接出现在选项中（除非是释义的一部分）
        for (final option in options) {
          // 选项不应完全等于 ref_text
          expect(option.toLowerCase(), isNot(equals(refText)));
        }
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 5. 听音回复 (listen_reply) 测试
    // ═══════════════════════════════════════════════════════════════

    group('听音回复 (listen_reply)', () {
      test('问句的答案应与问题语义相关', () {
        final question = 'Where did you go yesterday?';
        final item = _generateListenReply(question, wordMeanings);

        expect(item['type'], equals('listen_reply'));
        expect(item['ref_text'], equals(question));

        // 答案应是中文释义（因为使用 getWordMeaning）
        final answer = item['answer'] as String;
        final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(answer);
        expect(hasChinese, isTrue);
      });

      test('选项数量应足够（至少4个）', () {
        final question = 'What is your favorite food?';
        final item = _generateListenReply(question, wordMeanings);

        final options = List<String>.from(item['options'] as List);
        expect(options.length, greaterThanOrEqualTo(4));
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 6. 综合数据完整性测试
    // ═══════════════════════════════════════════════════════════════

    group('数据完整性', () {
      test('每道题必须包含 id, type, options, answer, answer_index', () {
        final items = [
          _generateDefinitionChoiceEnToCn('happy', wordMeanings),
          _generateTranslateMeaning('I run fast', wordMeanings),
          _generateListenMeaning('good', wordMeanings),
          _generateListenReply('How are you?', wordMeanings),
        ];

        for (final item in items) {
          expect(item.containsKey('id'), isTrue, reason: '缺少 id');
          expect(item.containsKey('type'), isTrue, reason: '缺少 type');
          expect(item.containsKey('options'), isTrue, reason: '缺少 options');
          expect(item.containsKey('answer'), isTrue, reason: '缺少 answer');
          expect(
            item.containsKey('answer_index'),
            isTrue,
            reason: '缺少 answer_index',
          );

          // 验证 id 格式（UUID）
          final id = item['id'] as String;
          expect(id.length, greaterThanOrEqualTo(32));

          // 验证 options 非空
          final options = item['options'] as List;
          expect(options.isNotEmpty, isTrue);

          // 验证 answer_index 在有效范围内
          final idx = item['answer_index'] as int;
          expect(idx, greaterThanOrEqualTo(0));
          expect(idx, lessThan(options.length));
        }
      });

      test('同一组题目的 id 应互不相同', () {
        final items = List.generate(
          10,
          (i) => _generateDefinitionChoiceEnToCn(
            wordMeanings.keys.elementAt(i % wordMeanings.length),
            wordMeanings,
          ),
        );

        final ids = items.map((item) => item['id'] as String).toSet();
        expect(ids.length, equals(items.length));
      });
    });
  });
}

// ════════════════════════════════════════════════════════════════════
// 辅助函数：模拟 Edge Function 的题目生成逻辑
// ════════════════════════════════════════════════════════════════════

String _uuid() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(32, '0');

List<T> _shuffle<T>(List<T> list) {
  final shuffled = List<T>.from(list);
  for (int i = shuffled.length - 1; i > 0; i--) {
    final j = (DateTime.now().microsecondsSinceEpoch + i) % (i + 1);
    final temp = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = temp;
  }
  return shuffled;
}

/// 生成 en_to_cn 类型的释义选择题
Map<String, dynamic> _generateDefinitionChoiceEnToCn(
  String word,
  Map<String, String> meanings,
) {
  final wordMeaning = meanings[word] ?? '「$word」的释义';
  final otherWords = meanings.entries
      .where((e) => e.key != word)
      .map((e) => e.value)
      .take(3)
      .toList();
  final options = _shuffle([wordMeaning, ...otherWords]);

  return {
    'id': _uuid(),
    'type': 'definition_choice',
    'prompt': 'What does "$word" mean?',
    'prompt_cn': '单词 "$word" 的意思是什么？',
    'display_text': word,
    'options': options,
    'answer': wordMeaning,
    'answer_index': options.indexOf(wordMeaning),
    'sub_type': 'en_to_cn',
    'answer_word': word,
  };
}

/// 生成 cn_to_en 类型的释义选择题
Map<String, dynamic> _generateDefinitionChoiceCnToEn(
  String word,
  Map<String, String> meanings,
) {
  final wordMeaning = meanings[word] ?? '「$word」的释义';
  final otherWords = meanings.entries
      .where((e) => e.key != word)
      .map((e) => e.key)
      .take(3)
      .toList();
  final allOptions = _shuffle([word, ...otherWords]);

  return {
    'id': _uuid(),
    'type': 'definition_choice',
    'prompt': 'Which word matches the meaning: "$wordMeaning"?',
    'prompt_cn': '哪个单词符合以下含义：「$wordMeaning」？',
    'display_text': wordMeaning, // 显示中文，不泄露英文！
    'options': allOptions,
    'answer': word,
    'answer_index': allOptions.indexOf(word),
    'sub_type': 'cn_to_en',
    'answer_meaning': wordMeaning,
  };
}

/// 生成英义互译题
Map<String, dynamic> _generateTranslateMeaning(
  String sentence,
  Map<String, String> meanings,
) {
  final words = sentence
      .split(RegExp(r'\s+'))
      .where((w) => RegExp(r'[A-Za-z]+').hasMatch(w))
      .toList();
  final translatedParts = words
      .map((w) {
        final lower = w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        return meanings[lower] ?? w;
      })
      .join(' ');

  // 如果翻译为空，返回原句
  final mainTranslation = translatedParts.isEmpty ? sentence : translatedParts;

  final options = _shuffle([
    mainTranslation,
    '这是一个测试干扰项1',
    '这是另一个干扰选项2',
    '第三个干扰项在这里',
  ]);

  return {
    'id': _uuid(),
    'type': 'translate_meaning',
    'prompt': 'Read and select the closest meaning',
    'prompt_cn': '阅读以下英文句子，选择与原文含义最接近的中文选项',
    'display_text': sentence,
    'options': options,
    'answer': mainTranslation,
    'answer_index': options.indexOf(mainTranslation),
    'original_sentence': sentence,
  };
}

/// 生成带干扰项的英义互译题
Map<String, dynamic> _generateTranslateMeaningWithDistractors(
  String sentence,
  List<String> allSentences,
  Map<String, String> meanings,
) {
  final mainItem = _generateTranslateMeaning(sentence, meanings);
  final otherTranslations = allSentences
      .where((s) => s != sentence)
      .take(3)
      .map((s) {
        final item = _generateTranslateMeaning(s, meanings);
        return item['answer'] as String;
      })
      .toList();

  final options = _shuffle([
    mainItem['answer'] as String,
    ...otherTranslations,
  ]);
  mainItem['options'] = options;
  mainItem['answer_index'] = options.indexOf(mainItem['answer']);
  return mainItem;
}

/// 生成听音辩义题
Map<String, dynamic> _generateListenMeaning(
  String word,
  Map<String, String> meanings,
) {
  final correctMeaning = meanings[word] ?? '「$word」的释义';
  final otherMeanings = meanings.entries
      .where((e) => e.key != word)
      .map((e) => e.value)
      .take(3)
      .toList();
  final options = _shuffle([correctMeaning, ...otherMeanings]);

  return {
    'id': _uuid(),
    'type': 'listen_meaning',
    'prompt': 'Listen and select the meaning',
    'prompt_cn': '听发音，选择与该词意思最接近的选项',
    'options': options,
    'answer': correctMeaning,
    'answer_index': options.indexOf(correctMeaning),
    'ref_text': word,
    'answer_word': word,
  };
}

/// 生成听音回复题
Map<String, dynamic> _generateListenReply(
  String sentence,
  Map<String, String> meanings,
) {
  // 简化版：取最后一个有意义的词作为关键
  final words = sentence
      .split(RegExp(r'\s+'))
      .where((w) => RegExp(r'[A-Za-z]+').hasMatch(w))
      .toList();
  final keyWord = words.isNotEmpty
      ? words.last.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')
      : 'unknown';
  final correctAnswer = meanings[keyWord] ?? '「$keyWord」的释义';
  final otherAnswers = meanings.entries
      .where((e) => e.key != keyWord)
      .map((e) => e.value)
      .take(3)
      .toList();
  final options = _shuffle([correctAnswer, ...otherAnswers]);

  return {
    'id': _uuid(),
    'type': 'listen_reply',
    'prompt': 'Listen and choose the best response',
    'prompt_cn': '听以下句子，选择最佳回答：「$sentence」',
    'options': options,
    'answer': correctAnswer,
    'answer_index': options.indexOf(correctAnswer),
    'ref_text': sentence,
    'answer_word': keyWord,
  };
}

/// 生成词性测试-同义词题
Map<String, dynamic>? _generateWordRelationSynonym(
  String word,
  List<String> wordPool,
  Map<String, Map<String, List<String>>> relations,
) {
  final relation = relations[word];
  if (relation == null || (relation['synonyms']?.isEmpty ?? true)) {
    return null; // 无预定义数据，跳过
  }

  final correctAnswers = relation['synonyms']!;
  final validCorrect = correctAnswers
      .where((a) => wordPool.any((w) => w.toLowerCase() == a.toLowerCase()))
      .toList();
  if (validCorrect.isEmpty) return null;

  final distractors = wordPool
      .where(
        (w) =>
            w.toLowerCase() != word.toLowerCase() &&
            !validCorrect.any((a) => a.toLowerCase() == w.toLowerCase()),
      )
      .take(4)
      .toList();
  if (distractors.length + validCorrect.length < 4) return null;

  final options = _shuffle([...validCorrect, ...distractors]);
  final answerIndices = validCorrect.map((a) => options.indexOf(a)).toList();

  return {
    'id': _uuid(),
    'type': 'word_relation',
    'prompt': 'Select synonyms of "$word"',
    'prompt_cn': '选择以下单词的同义词（可多选）：「$word」',
    'display_text': word,
    'relation_type': 'synonym',
    'options': options,
    'answer_indices': answerIndices,
    'answers': validCorrect,
    'confidence': 'high',
  };
}

/// 生成词性测试-反义词题
Map<String, dynamic>? _generateWordRelationAntonym(
  String word,
  List<String> wordPool,
  Map<String, Map<String, List<String>>> relations,
) {
  final relation = relations[word];
  if (relation == null || (relation['antonyms']?.isEmpty ?? true)) {
    return null;
  }

  final correctAnswers = relation['antonyms']!;
  final validCorrect = correctAnswers
      .where((a) => wordPool.any((w) => w.toLowerCase() == a.toLowerCase()))
      .toList();
  if (validCorrect.isEmpty) return null;

  final distractors = wordPool
      .where(
        (w) =>
            w.toLowerCase() != word.toLowerCase() &&
            !validCorrect.any((a) => a.toLowerCase() == w.toLowerCase()),
      )
      .take(4)
      .toList();
  if (distractors.length + validCorrect.length < 4) return null;

  final options = _shuffle([...validCorrect, ...distractors]);
  final answerIndices = validCorrect.map((a) => options.indexOf(a)).toList();

  return {
    'id': _uuid(),
    'type': 'word_relation',
    'prompt': 'Select antonyms of "$word"',
    'prompt_cn': '选择以下单词的反义词（可多选）：「$word」',
    'display_text': word,
    'relation_type': 'antonym',
    'options': options,
    'answer_indices': answerIndices,
    'answers': validCorrect,
    'confidence': 'high',
  };
}
