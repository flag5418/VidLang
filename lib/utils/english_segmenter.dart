/// 英文文本分词工具
///
/// 用于将没有空格的英文文本拆分成单词列表。
/// 使用贪心最长匹配算法 + 常用词表实现。
class EnglishSegmenter {
  EnglishSegmenter._();

  /// 对文本进行分词
  /// 如果文本已有空格分隔，直接按空格拆分
  /// 如果文本没有空格（单词粘连），使用最长匹配算法拆分
  static List<String> segment(String text) {
    if (text.isEmpty) return [];

    // 直接按空格拆分。不再对无空格的单词进行强制的单字母贪心拆分
    // 因为这会导致正常的单单词（如 "plants"）被拆分为 p, l, a, n, t, s
    final spaceSplit = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return spaceSplit;
  }
}
