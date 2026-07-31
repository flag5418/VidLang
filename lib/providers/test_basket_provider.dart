import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_book.dart';

/// 测试篮状态
///
/// 全局状态，用于管理"购物车式测试系统"中待测试的单词集合。
/// 跨标签、跨 Tab（单词/短语）持久化。
class TestBasketState {
  /// 已选单词映射：code -> WordBook
  final Map<String, WordBook> selectedWords;

  const TestBasketState({this.selectedWords = const {}});

  /// 已选数量
  int get count => selectedWords.length;

  /// 是否为空
  bool get isEmpty => selectedWords.isEmpty;

  /// 是否非空
  bool get isNotEmpty => selectedWords.isNotEmpty;

  /// 判断某单词是否已在测试篮中
  bool isSelected(String code) => selectedWords.containsKey(code);

  /// 切换单词选中状态
  TestBasketState toggle(WordBook word) {
    final code = word.code;
    if (code == null) return this;

    final newMap = Map<String, WordBook>.from(selectedWords);
    if (newMap.containsKey(code)) {
      newMap.remove(code);
    } else {
      // 检查上限
      if (newMap.length >= 50) return this;
      newMap[code] = word;
    }
    return TestBasketState(selectedWords: newMap);
  }

  /// 添加单个单词
  TestBasketState add(WordBook word) {
    final code = word.code;
    if (code == null || selectedWords.containsKey(code)) return this;
    if (selectedWords.length >= 50) return this;

    return TestBasketState(
      selectedWords: {...selectedWords, code: word},
    );
  }

  /// 批量添加单词
  TestBasketState addAll(List<WordBook> words) {
    final newMap = Map<String, WordBook>.from(selectedWords);
    for (final word in words) {
      final code = word.code;
      if (code == null || newMap.containsKey(code)) continue;
      if (newMap.length >= 50) break;
      newMap[code] = word;
    }
    return TestBasketState(selectedWords: newMap);
  }

  /// 移除单个单词
  TestBasketState remove(String code) {
    if (!selectedWords.containsKey(code)) return this;

    final newMap = Map<String, WordBook>.from(selectedWords);
    newMap.remove(code);
    return TestBasketState(selectedWords: newMap);
  }

  /// 清空测试篮
  const TestBasketState.clear() : selectedWords = const {};

  /// 获取用于 TestPage.seedWords 的数据
  List<Map<String, dynamic>> toSeedWords() {
    return selectedWords.values.map((word) => {
          'word': word.word,
          'context_sentence': word.contextSentence ?? word.word,
          'word_book_code': word.code,
          'source_type': word.sourceType,
          'source_code': word.sourceCode,
          'source_title': word.sourceTitle,
          'segment_code': word.segmentCode,
          'definitions_json': word.definitionsJson,
          'phonetic_uk': word.phoneticUk,
          'phonetic_us': word.phoneticUs,
          'difficulty': word.difficulty,
        }).toList();
  }

  /// 获取所有已选单词列表
  List<WordBook> get words => selectedWords.values.toList();
}

/// 测试篮 Notifier
class TestBasketNotifier extends StateNotifier<TestBasketState> {
  TestBasketNotifier() : super(const TestBasketState());

  /// 切换单词选中状态
  void toggle(WordBook word) {
    state = state.toggle(word);
  }

  /// 添加单个单词
  void add(WordBook word) {
    state = state.add(word);
  }

  /// 批量添加单词
  void addAll(List<WordBook> words) {
    state = state.addAll(words);
  }

  /// 移除单个单词
  void remove(String code) {
    state = state.remove(code);
  }

  /// 清空测试篮
  void clear() {
    state = const TestBasketState.clear();
  }

  /// 达到上限时返回 true
  bool get isFull => state.count >= 50;
}

/// 测试篮全局 Provider
final testBasketProvider =
    StateNotifierProvider<TestBasketNotifier, TestBasketState>(
  (ref) => TestBasketNotifier(),
);
