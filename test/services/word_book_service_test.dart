import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/word_book_service.dart';

void main() {
  test('认识后写入 mastered 和 masteredAt', () {
    final wb = WordBook(word: 'focus', sourceType: 'video', sourceCode: 'v1');
    wb.masteryLevel = 'learning';

    final updated = WordBookService.applyMastery(
      wb,
      recognized: true,
      reviewedAt: DateTime(2026, 6, 13),
    );

    expect(updated.masteryLevel, 'mastered');
    expect(updated.masteredAt, isNotNull);
  });

  test('同一场测试累计一次 reviewCount', () {
    final before = WordBook(
      word: 'focus',
      sourceType: 'video',
      sourceCode: 'v1',
      reviewCount: 2,
      correctCount: 1,
    );

    final result = WordBookService.mergeTestResult(
      before,
      reviewed: true,
      correct: true,
    );

    expect(result.reviewCount, 3);
    expect(result.correctCount, 2);
  });
}
