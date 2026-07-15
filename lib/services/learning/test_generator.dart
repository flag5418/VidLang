import 'dart:convert';
import 'dart:math';

import 'package:vidlang/models/test_models.dart';

/// 本地题型生成引擎
///
/// 根据单词列表 + 难度 + 题型配置，生成评测题目。
/// 不依赖网络，离线即可出题（发音题型除外）。
class TestGenerator {
  final Random _random = Random();

  // ─── 题目生成入口 ───

  /// 生成一次评测的所有题目
  /// [words]: 被评测单词列表（至少含 word 字段）
  /// [config]: 各题型题目数量配置
  /// [difficulty]: 难度级别
  List<TestItem> generateTest({
    required List<Map<String, String>> words,
    required Map<QuestionType, int> config,
    required String difficulty,
    int testSessionId = 0,
  }) {
    final items = <TestItem>[];
    int order = 0;
    final allWords = words.map((w) => w['word'] ?? '').where((w) => w.isNotEmpty).toList();

    for (final entry in config.entries) {
      final type = entry.key;
      final count = entry.value;
      for (int i = 0; i < count && words.isNotEmpty; i++) {
        final word = words[_random.nextInt(words.length)];
        final item = _generateItem(type, word, allWords, order++, testSessionId);
        if (item != null) {
          items.add(item);
        }
      }
    }

    // 打乱顺序
    items.shuffle(_random);
    for (int i = 0; i < items.length; i++) {
      items[i].itemOrder = i;
    }

    return items;
  }

  // ─── 单题生成 ───

  TestItem? _generateItem(
    QuestionType type,
    Map<String, String> word,
    List<String> allWords,
    int order,
    int testSessionId,
  ) {
    final targetWord = word['word'] ?? '';
    if (targetWord.isEmpty) return null;

    final translation = word['translation'] ?? word['meaning'] ?? '';
    final sentence = word['sentence'] ?? '';

    switch (type) {
      case QuestionType.listenChoose:
        return _genListenChoose(targetWord, translation, allWords, order, testSessionId);
      case QuestionType.meaningWrite:
        return _genMeaningWrite(targetWord, translation, order, testSessionId);
      case QuestionType.sentenceDictation:
        return _genSentenceDictation(
            targetWord, sentence, order, testSessionId);
      case QuestionType.translateBoth:
        return _genTranslateBoth(
            targetWord, translation, sentence, order, testSessionId);
      case QuestionType.wordPron:
        return _genPronunciation(targetWord, 'word', order, testSessionId);
      case QuestionType.phrasePron:
        return _genPronunciation(targetWord, 'phrase', order, testSessionId);
      case QuestionType.sentencePron:
        return _genPronunciation(
            sentence.isNotEmpty ? sentence : targetWord,
            'sentence',
            order,
            testSessionId);
      case QuestionType.reorder:
        return _genReorder(sentence.isNotEmpty ? sentence : targetWord, order,
            testSessionId);
      case QuestionType.spelling:
        return _genSpelling(targetWord, order, testSessionId);
      case QuestionType.mcq:
        return _genMcq(targetWord, translation, allWords, order, testSessionId);
      // 新题型通过 Edge Function 出题，本地生成器暂不支持
      case QuestionType.listenMeaning:
      case QuestionType.listenReply:
      case QuestionType.definitionChoice:
      case QuestionType.translateMeaning:
      case QuestionType.wordRelation:
        return null;
    }
  }

  // ─── 听音选词 ───

  TestItem _genListenChoose(
    String targetWord,
    String translation,
    List<String> allWords,
    int order,
    int testSessionId,
  ) {
    final options = generateDistractors(targetWord, allWords, 3);
    return TestItem(
      testSessionId: testSessionId,
      questionType: QuestionType.listenChoose.name,
      itemOrder: order,
      refText: targetWord,
      prompt: '听发音，选择正确的单词',
      promptAudioPath: null,
      correctAnswer: targetWord,
      distractorsJson: _jsonEncode(options),
      userAnswer: null,
    );
  }

  // ─── 看义写词 ───

  TestItem _genMeaningWrite(
    String targetWord,
    String translation,
    int order,
    int testSessionId,
  ) {
    final prompt = translation.isNotEmpty
        ? '请根据中文释义拼写单词：$translation'
        : '请拼写单词 "$targetWord"';

    return TestItem(
      testSessionId: testSessionId,
      questionType: QuestionType.meaningWrite.name,
      itemOrder: order,
      refText: targetWord,
      prompt: prompt,
      correctAnswer: targetWord,
      userAnswer: null,
    );
  }

  // ─── 句中听写 ───

  TestItem _genSentenceDictation(
    String targetWord,
    String sentence,
    int order,
    int testSessionId,
  ) {
    final text = sentence.isNotEmpty ? sentence : targetWord;
    return TestItem(
      testSessionId: testSessionId,
      questionType: QuestionType.sentenceDictation.name,
      itemOrder: order,
      refText: targetWord,
      prompt: '听句子，写出你听到的内容。提示词：$targetWord',
      correctAnswer: text,
      userAnswer: null,
    );
  }

  // ─── 中英互译 ───

  TestItem _genTranslateBoth(
    String targetWord,
    String translation,
    String sentence,
    int order,
    int testSessionId,
  ) {
    final direction = _random.nextBool();
    if (direction && translation.isNotEmpty) {
      return TestItem(
        testSessionId: testSessionId,
        questionType: QuestionType.translateBoth.name,
        itemOrder: order,
        refText: targetWord,
        prompt: '将以下中文翻译为英文：$translation',
        correctAnswer: targetWord,
        userAnswer: null,
      );
    } else {
      final text = sentence.isNotEmpty ? sentence : targetWord;
      return TestItem(
        testSessionId: testSessionId,
        questionType: QuestionType.translateBoth.name,
        itemOrder: order,
        refText: text,
        prompt: '将以下英文翻译为中文：$text',
        correctAnswer: translation.isNotEmpty ? translation : text,
        userAnswer: null,
      );
    }
  }

  // ─── 跟读类 ───

  TestItem _genPronunciation(
    String text,
    String scope,
    int order,
    int testSessionId,
  ) {
    final type = scope == 'word'
        ? QuestionType.wordPron
        : scope == 'phrase'
            ? QuestionType.phrasePron
            : QuestionType.sentencePron;

    return TestItem(
      testSessionId: testSessionId,
      questionType: type.name,
      itemOrder: order,
      refText: text,
      prompt: '请跟读以下内容：$text',
      correctAnswer: text,
      userAnswer: null,
    );
  }

  // ─── 组句题 ───

  TestItem _genReorder(
    String sentence,
    int order,
    int testSessionId,
  ) {
    return TestItem(
      testSessionId: testSessionId,
      questionType: QuestionType.reorder.name,
      itemOrder: order,
      refText: sentence,
      prompt: '将以下单词按正确顺序排列',
      correctAnswer: sentence,
      userAnswer: null,
    );
  }

  // ─── 拼写填空 ───

  TestItem _genSpelling(
    String targetWord,
    int order,
    int testSessionId,
  ) {
    // 挖空策略：随机隐藏部分字母
    final chars = targetWord.split('');
    final maskedCount = max(1, chars.length ~/ 3);
    final maskedIndices = <int>{};
    while (maskedIndices.length < maskedCount) {
      maskedIndices.add(_random.nextInt(chars.length));
    }

    final masked = chars.asMap().entries.map((e) {
      return maskedIndices.contains(e.key) ? '_' : e.value;
    }).join('');

    return TestItem(
      testSessionId: testSessionId,
      questionType: QuestionType.spelling.name,
      itemOrder: order,
      refText: targetWord,
      prompt: '请拼写完整单词：$masked',
      correctAnswer: targetWord,
      userAnswer: null,
    );
  }

  // ─── 选择题 ───

  TestItem _genMcq(
    String targetWord,
    String translation,
    List<String> allWords,
    int order,
    int testSessionId,
  ) {
    final options = generateDistractors(targetWord, allWords, 3);
    return TestItem(
      testSessionId: testSessionId,
      questionType: QuestionType.mcq.name,
      itemOrder: order,
      refText: targetWord,
      prompt: translation.isNotEmpty
          ? '"$translation" 对应的英文是？'
          : '"$targetWord" 的中文意思是？',
      correctAnswer: translation.isNotEmpty ? targetWord : translation,
      distractorsJson: _jsonEncode(options),
      userAnswer: null,
    );
  }

  // ─── 辅助 ───

  String _jsonEncode(List<String> list) => jsonEncode(list);

  /// 生成干扰选项列表
  List<String> generateDistractors(
    String correct,
    List<String> pool,
    int count,
  ) {
    final candidates = pool.where((w) => w != correct).toList();
    candidates.shuffle(_random);
    final distractors = candidates.take(count).toList();

    // 如果干扰项不够，用随机字符串补
    while (distractors.length < count) {
      distractors.add('option_${distractors.length + 1}');
    }

    final options = [...distractors, correct]..shuffle(_random);
    return options;
  }
}
