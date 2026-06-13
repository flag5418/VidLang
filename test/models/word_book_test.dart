import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/models/word_book.dart';

void main() {
  test('reviewing 状态读取时自动回落为 learning', () {
    final model = WordBook().fromMap({
      'id': 1,
      'code': 'wb1',
      'word': 'focus',
      'source_type': 'video',
      'source_code': 'v1',
      'difficulty': 1,
      'review_count': 0,
      'correct_count': 0,
      'mastery_level': 'reviewing',
      'is_deleted': 0,
    }) as WordBook;

    expect(model.masteryLevel, 'learning');
  });

  test('新建单词默认是 learning', () {
    final model = WordBook(word: 'focus', sourceCode: 'v1');
    expect(model.masteryLevel, 'learning');
  });
}
