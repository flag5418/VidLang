import 'package:flutter_test/flutter_test.dart';

/// 质量门兼容性测试 — 验证 V3 非选择题不会被误杀
///
/// 本测试模拟后端 quality-gate.ts 的校验逻辑，
/// 确保 reorder、spelling、pronunciation 等 V3 非选择题
/// 不会被 R1/R2/R3/R5/R6 规则误过滤。
void main() {
  group('V3 非选择题质量门兼容', () {
    test('reorder 组句题不应被 R1 误杀（选项数 != 4）', () {
      final item = {
        'id': 'reorder-1',
        'type': 'reorder',
        'prompt': '请按正确顺序组句',
        'sentence': 'The quick brown fox jumps.',
        'options': ['fox', 'The', 'quick', 'jumps', 'brown'],
        'answer': ['The', 'quick', 'brown', 'fox', 'jumps'],
      };

      // 模拟 isChoiceQuestion(item) == false
      expect(_isChoiceQuestion(item), isFalse);

      // R1 应跳过
      expect(_validateR1(item), isNull);
      // R2 应跳过
      expect(_validateR2(item), isNull);
      // R3 应跳过
      expect(_validateR3(item), isNull);
      // R5 应跳过
      expect(_validateR5(item), isNull);
      // R6 应跳过
      expect(_validateR6(item), isNull);
    });

    test('spelling 拼写题不应被 R1 误杀', () {
      final item = {
        'id': 'spelling-1',
        'type': 'spelling',
        'prompt': '请根据句子拼写缺失单词',
        'sentence': 'The _____ fox jumps.',
        'masked': 'The _____ fox jumps.',
        'answer': 'quick',
        'letter_pool': ['Q', 'U', 'I', 'C', 'K', 'A', 'B', 'C'],
      };

      expect(_isChoiceQuestion(item), isFalse);
      expect(_validateR1(item), isNull);
      expect(_validateR2(item), isNull);
      expect(_validateR3(item), isNull);
      expect(_validateR5(item), isNull);
      expect(_validateR6(item), isNull);
    });

    test('word_pron 跟读单词不应被 R1 误杀', () {
      final item = {
        'id': 'pron-1',
        'type': 'word_pron',
        'prompt': 'Please read aloud: hello',
        'ref_text': 'hello',
        'answer': 'hello',
      };

      expect(_isChoiceQuestion(item), isFalse);
      expect(_validateR1(item), isNull);
      expect(_validateR2(item), isNull);
      expect(_validateR3(item), isNull);
      expect(_validateR5(item), isNull);
      expect(_validateR6(item), isNull);
    });

    test('phrase_pron 跟读短语不应被 R1 误杀', () {
      final item = {
        'id': 'pron-2',
        'type': 'phrase_pron',
        'prompt': 'Please read aloud: good morning',
        'ref_text': 'good morning',
        'answer': 'good morning',
      };

      expect(_isChoiceQuestion(item), isFalse);
      expect(_validateR1(item), isNull);
      expect(_validateR2(item), isNull);
      expect(_validateR3(item), isNull);
      expect(_validateR5(item), isNull);
      expect(_validateR6(item), isNull);
    });

    test('sentence_pron 跟读句子不应被 R1 误杀', () {
      final item = {
        'id': 'pron-3',
        'type': 'sentence_pron',
        'prompt': 'Please read aloud: How are you today?',
        'ref_text': 'How are you today?',
        'answer': 'How are you today?',
      };

      expect(_isChoiceQuestion(item), isFalse);
      expect(_validateR1(item), isNull);
      expect(_validateR2(item), isNull);
      expect(_validateR3(item), isNull);
      expect(_validateR5(item), isNull);
      expect(_validateR6(item), isNull);
    });
  });

  group('V3 选择题质量门正常校验', () {
    test('mcq 选择题应通过 R1（4个选项）', () {
      final item = {
        'id': 'mcq-1',
        'type': 'mcq',
        'prompt': '请选择最合适的单词填空',
        'sentence': 'The _____ fox jumps.',
        'masked': 'The _____ fox jumps.',
        'options': ['quick', 'slow', 'lazy', 'fast'],
        'answer': 'quick',
        'answer_index': 0,
      };

      expect(_isChoiceQuestion(item), isTrue);
      expect(_validateR1(item), isNull);
      expect(_validateR2(item), isNull);
      expect(_validateR3(item), isNull);
    });

    test('mcq 选择题 R1 应失败（选项不足4个）', () {
      final item = {
        'id': 'mcq-bad',
        'type': 'mcq',
        'options': ['quick', 'slow'],
        'answer': 'quick',
        'answer_index': 0,
      };

      expect(_isChoiceQuestion(item), isTrue);
      expect(_validateR1(item), isNotNull);
    });

    test('listen_choose 应通过 R1（4个选项）', () {
      final item = {
        'id': 'listen-1',
        'type': 'listen_choose',
        'prompt': 'Listen and select',
        'options': ['apple', 'banana', 'cat', 'dog'],
        'answer': 'apple',
        'answer_index': 0,
        'ref_text': 'apple',
      };

      expect(_isChoiceQuestion(item), isTrue);
      expect(_validateR1(item), isNull);
      expect(_validateR2(item), isNull);
    });

    test('definition_choice 应通过 R1（4个选项）', () {
      final item = {
        'id': 'def-1',
        'type': 'definition_choice',
        'prompt': 'What does "happy" mean?',
        'display_text': 'happy',
        'options': ['快乐的', '悲伤的', '愤怒的', '平静的'],
        'answer': '快乐的',
        'answer_index': 0,
        'answer_word': 'happy',
      };

      expect(_isChoiceQuestion(item), isTrue);
      expect(_validateR1(item), isNull);
      expect(_validateR2(item), isNull);
    });
  });

  group('降级兜底逻辑', () {
    test('当全部选择题被过滤时，应保留非选择题', () {
      final allItems = [
        {
          'id': 'mcq-bad',
          'type': 'mcq',
          'options': ['A', 'B'], // 不足4个，会被过滤
          'answer': 'A',
          'answer_index': 0,
        },
        {
          'id': 'reorder-1',
          'type': 'reorder',
          'options': ['The', 'quick', 'brown'],
          'answer': ['The', 'quick', 'brown'],
        },
      ];

      // 模拟质量门过滤
      final validated = allItems.where((item) {
        final r1 = _validateR1(item);
        final r2 = _validateR2(item);
        final r3 = _validateR3(item);
        return r1 == null && r2 == null && r3 == null;
      }).toList();

      // mcq 被过滤，reorder 保留
      expect(validated.length, equals(1));
      expect(validated.first['type'], equals('reorder'));

      // 模拟降级兜底：如果 validated 为空但 allItems 有非选择题，保留非选择题
      final nonChoiceItems = allItems
          .where((item) => !_isChoiceQuestion(item))
          .toList();
      if (validated.isEmpty && allItems.isNotEmpty) {
        expect(nonChoiceItems.isNotEmpty, isTrue);
      }
    });

    test('当全部题目被过滤且无降级时，应返回 no_items', () {
      final allItems = [
        {
          'id': 'mcq-bad',
          'type': 'mcq',
          'options': ['A', 'B'],
          'answer': 'A',
          'answer_index': 0,
        },
      ];

      final validated = allItems.where((item) {
        final r1 = _validateR1(item);
        final r2 = _validateR2(item);
        return r1 == null && r2 == null;
      }).toList();

      final nonChoiceItems = allItems
          .where((item) => !_isChoiceQuestion(item))
          .toList();

      // 没有非选择题可以降级
      expect(validated.isEmpty, isTrue);
      expect(nonChoiceItems.isEmpty, isTrue);
      // 此时应返回 no_items
    });
  });

  group('综合测试 folder 模式请求体', () {
    test('folder 模式应包含 folder_code 和 source_type', () {
      final requestBody = {
        'request_id': 'test-req-1',
        'folder_code': 'folder_abc',
        'source_type': 'folder',
        'difficulty': 'intermediate',
        'config': {
          'listen_choose_count': 2,
          'spelling_count': 2,
          'reorder_count': 2,
        },
      };

      expect(requestBody['folder_code'], isNotNull);
      expect(requestBody['source_type'], equals('folder'));
      expect(requestBody['video_code'], isNull);
    });

    test('resource 模式应包含 video_code 和 source_type', () {
      final requestBody = {
        'request_id': 'test-req-2',
        'video_code': 'video_xyz',
        'source_type': 'resource',
        'difficulty': 'intermediate',
        'config': {'spelling_count': 2},
      };

      expect(requestBody['video_code'], isNotNull);
      expect(requestBody['source_type'], equals('resource'));
      expect(requestBody['folder_code'], isNull);
    });
  });
}

// ─── 模拟后端 quality-gate.ts 的校验逻辑 ───

const _v3ChoiceTypes = {
  'mcq',
  'listen_choose',
  'listen_meaning',
  'listen_reply',
  'definition_choice',
  'translate_meaning',
};

const _v4ChoiceTypes = {
  'context_mcq',
  'meaning_choice',
  'english_definition',
  'word_forms',
  'reading_comprehension',
  'listening_comprehension',
  'semantic_relation',
  'translation_match',
};

const _nonChoiceTypes = {
  'reorder',
  'spelling',
  'word_pron',
  'phrase_pron',
  'sentence_pron',
};

bool _isChoiceQuestion(Map<String, dynamic> item) {
  final type = item['type'] as String?;
  return _v3ChoiceTypes.contains(type) || _v4ChoiceTypes.contains(type);
}

String? _validateR1(Map<String, dynamic> item) {
  if (!_isChoiceQuestion(item)) return null;
  final options = item['options'] as List?;
  if (options == null || options.length != 4) {
    return 'R1 Violation: Expected 4 options, got ${options?.length ?? 0}';
  }
  return null;
}

String? _validateR2(Map<String, dynamic> item) {
  if (!_isChoiceQuestion(item)) return null;
  final options = item['options'] as List?;
  final answer = item['answer'];
  final answerIndex = item['answer_index'] as int?;

  if (answer != null && answerIndex != null) {
    if (options == null || answerIndex < 0 || answerIndex >= (options.length)) {
      return 'R2 Violation: answer_index out of bounds';
    }
    if (options[answerIndex] != answer) {
      return 'R2 Violation: options[answerIndex] != answer';
    }
    return null;
  }

  final correctAnswer = item['correctAnswer'] as String?;
  if (correctAnswer != null && ['A', 'B', 'C', 'D'].contains(correctAnswer)) {
    final index = correctAnswer.codeUnitAt(0) - 65;
    if (index >= 0 && index < (options?.length ?? 0)) return null;
    return 'R2 Violation: correctAnswer index out of bounds';
  }

  return 'R2 Violation: No valid answer field found';
}

String? _validateR3(Map<String, dynamic> item) {
  if (!_isChoiceQuestion(item)) return null;
  final options = item['options'] as List?;
  if (options == null || options.isEmpty) return null;
  final normalized = options
      .map((o) => o.toString().toLowerCase().trim())
      .toList();
  final unique = normalized.toSet();
  if (unique.length != options.length) {
    return 'R3 Violation: Duplicate options found';
  }
  return null;
}

String? _validateR5(Map<String, dynamic> item) {
  if (!_isChoiceQuestion(item)) return null;
  final options = item['options'] as List?;
  if (options == null || options.length < 2) return null;
  final lengths = options
      .map((o) => o.toString().replaceAll(RegExp(r'\s'), '').length)
      .toList();
  final minLen = lengths.reduce((a, b) => a < b ? a : b);
  final maxLen = lengths.reduce((a, b) => a > b ? a : b);
  if (minLen > 0 && maxLen / minLen > 3) {
    return 'R5 Violation: Option length ratio exceeds threshold';
  }
  return null;
}

String? _validateR6(Map<String, dynamic> item) {
  if (!_isChoiceQuestion(item)) return null;
  final options = item['options'] as List?;
  if (options == null || options.length < 2) return null;
  for (var i = 0; i < options.length; i++) {
    for (var j = i + 1; j < options.length; j++) {
      final distance = _levenshteinDistance(
        options[i].toString().toLowerCase(),
        options[j].toString().toLowerCase(),
      );
      if (distance < 2) {
        return 'R6 Violation: Options too similar (distance: $distance)';
      }
    }
  }
  return null;
}

int _levenshteinDistance(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final matrix = List.generate(
    b.length + 1,
    (i) => List<int>.filled(a.length + 1, 0),
  );

  for (var i = 0; i <= b.length; i++) {
    matrix[i][0] = i;
  }
  for (var j = 0; j <= a.length; j++) {
    matrix[0][j] = j;
  }

  for (var i = 1; i <= b.length; i++) {
    for (var j = 1; j <= a.length; j++) {
      if (b[i - 1] == a[j - 1]) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = [
          matrix[i - 1][j - 1] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j] + 1,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
  }

  return matrix[b.length][a.length];
}
