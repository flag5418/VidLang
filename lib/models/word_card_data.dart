/// WordCard 弹窗数据模型（免费/付费共用）
class WordCardData {
  /// 单词
  final String word;

  /// 音标（如 /ʌnˈpresɪdentɪd/）
  final String? phonetic;

  /// 词性
  final String? partOfSpeech;

  /// 释义列表
  final List<WordDefinition> definitions;

  /// 例句列表
  final List<WordExample> examples;

  /// 翻译（句子/单词翻译）
  final String? translation;

  /// 是否成功
  final bool success;

  /// 错误信息
  final String? error;

  /// 消耗金额（付费模式下有效）
  final double? costCny;

  /// 扣除后余额
  final double? balanceAfter;

  /// 来源模式
  final String source;

  const WordCardData({
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    this.definitions = const [],
    this.examples = const [],
    this.translation,
    this.success = true,
    this.error,
    this.costCny,
    this.balanceAfter,
    this.source = 'native',
  });

  /// 从 AI Edge Function 响应构造
  factory WordCardData.fromAiResult(String word, Map<String, dynamic> result, {double? costCny, double? balanceAfter}) {
    return WordCardData(
      word: result['word'] as String? ?? word,
      phonetic: result['phonetic_uk'] as String? ?? result['phonetic_us'] as String?,
      partOfSpeech: result['part_of_speech'] as String? ?? result['partOfSpeech'] as String?,
      definitions: _parseDefinitions(result),
      examples: _parseExamples(result),
      translation: result['translated_text'] as String?,
      success: true,
      costCny: costCny,
      balanceAfter: balanceAfter,
      source: 'ai',
    );
  }

  /// 从本地词典/翻译构造
  factory WordCardData.fromNative({
    required String word,
    String? phonetic,
    String? partOfSpeech,
    List<WordDefinition> definitions = const [],
    String? translation,
  }) {
    return WordCardData(
      word: word,
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      definitions: definitions,
      translation: translation,
      success: true,
      source: 'native',
    );
  }

  /// 是否为余额不足错误
  bool get isInsufficientBalance => !success && error != null && source == 'ai';

  /// 错误构造
  factory WordCardData.error(String word, String error, {bool isInsufficientBalance = false, double? requiredCny, double? balanceCny}) {
    return WordCardData(
      word: word,
      success: false,
      error: error,
      costCny: requiredCny,
      balanceAfter: balanceCny,
      source: isInsufficientBalance ? 'ai' : 'native',
    );
  }

  static List<WordDefinition> _parseDefinitions(Map<String, dynamic> result) {
    final defs = result['definitions'];
    if (defs is String && defs.isNotEmpty) {
      return [WordDefinition(partOfSpeech: result['part_of_speech'] as String?, meaning: defs)];
    }
    if (defs is List) {
      return defs.map((d) {
        if (d is Map) {
          return WordDefinition(
            partOfSpeech: d['partOfSpeech'] as String? ?? d['part_of_speech'] as String?,
            meaning: d['meaning'] as String? ?? '',
            example: d['example'] as String?,
          );
        }
        if (d is String) return WordDefinition(meaning: d);
        return WordDefinition(meaning: d.toString());
      }).toList();
    }
    return [];
  }

  static List<WordExample> _parseExamples(Map<String, dynamic> result) {
    final exs = result['examples'];
    if (exs is List) {
      return exs.map((e) {
        if (e is Map) {
          return WordExample(
            english: e['english'] as String? ?? e['example'] as String? ?? '',
            chinese: e['chinese'] as String? ?? e['example_translation'] as String?,
          );
        }
        return WordExample(english: e.toString());
      }).toList();
    }
    final example = result['example'];
    if (example is String && example.isNotEmpty) {
      return [WordExample(
        english: example,
        chinese: result['example_translation'] as String?,
      )];
    }
    return [];
  }
}

class WordDefinition {
  final String? partOfSpeech;
  final String meaning;
  final String? example;

  const WordDefinition({this.partOfSpeech, required this.meaning, this.example});
}

class WordExample {
  final String english;
  final String? chinese;

  const WordExample({required this.english, this.chinese});
}
