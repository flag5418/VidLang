import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vidlang/config.dart';

enum PronunciationPriority {
  ukFirst,
  usFirst,
  wordFirst,
}

class Syllable {
  final String letters;
  final String pronunciation;
  final double durationMs;

  Syllable({
    required this.letters,
    required this.pronunciation,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'letters': letters,
      'pronunciation': pronunciation,
      'durationMs': durationMs,
    };
  }

  factory Syllable.fromJson(Map<String, dynamic> json) {
    return Syllable(
      letters: json['letters'] as String,
      pronunciation: json['pronunciation'] as String,
      durationMs: (json['durationMs'] as num).toDouble(),
    );
  }
}

class Definition {
  final String partOfSpeech;
  final String meaning;
  final String? example;

  Definition({
    required this.partOfSpeech,
    required this.meaning,
    this.example,
  });

  Map<String, dynamic> toJson() {
    return {
      'partOfSpeech': partOfSpeech,
      'meaning': meaning,
      'example': example,
    };
  }

  factory Definition.fromJson(Map<String, dynamic> json) {
    return Definition(
      partOfSpeech: json['partOfSpeech'] as String,
      meaning: json['meaning'] as String,
      example: json['example'] as String?,
    );
  }
}

class Example {
  final String english;
  final String chinese;

  Example({
    required this.english,
    required this.chinese,
  });

  Map<String, dynamic> toJson() {
    return {
      'english': english,
      'chinese': chinese,
    };
  }

  factory Example.fromJson(Map<String, dynamic> json) {
    return Example(
      english: json['english'] as String,
      chinese: json['chinese'] as String,
    );
  }
}

class SentenceContext {
  final String englishSentence;
  final String englishWord;
  final String chineseSentence;
  final String chineseWord;

  SentenceContext({
    required this.englishSentence,
    required this.englishWord,
    required this.chineseSentence,
    required this.chineseWord,
  });

  Map<String, dynamic> toJson() {
    return {
      'englishSentence': englishSentence,
      'englishWord': englishWord,
      'chineseSentence': chineseSentence,
      'chineseWord': chineseWord,
    };
  }

  factory SentenceContext.fromJson(Map<String, dynamic> json) {
    return SentenceContext(
      englishSentence: json['englishSentence'] as String,
      englishWord: json['englishWord'] as String,
      chineseSentence: json['chineseSentence'] as String,
      chineseWord: json['chineseWord'] as String,
    );
  }
}

enum WordRelationType {
  synonyms,
  antonyms,
  coHyponyms,
  hypernym,
  hyponyms,
  meronyms,
  collocations,
  wordFamily,
  confusables,
}

class WordRelation {
  final WordRelationType type;
  final String label;
  final List<String> words;

  WordRelation({
    required this.type,
    required this.label,
    required this.words,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'label': label,
      'words': words,
    };
  }

  factory WordRelation.fromJson(Map<String, dynamic> json) {
    return WordRelation(
      type: WordRelationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => WordRelationType.synonyms,
      ),
      label: json['label'] as String,
      words: List<String>.from(json['words'] as List),
    );
  }
}

class Phase1Response {
  final String word;
  final String? ukPronunciation;
  final String? usPronunciation;
  final String? wordPronunciation;
  final String? ukPhonetic;
  final String? usPhonetic;
  final String? partOfSpeech;
  final List<Syllable>? syllables;
  final bool success;
  final String? error;

  Phase1Response({
    required this.word,
    this.ukPronunciation,
    this.usPronunciation,
    this.wordPronunciation,
    this.ukPhonetic,
    this.usPhonetic,
    this.partOfSpeech,
    this.syllables,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'ukPronunciation': ukPronunciation,
      'usPronunciation': usPronunciation,
      'wordPronunciation': wordPronunciation,
      'ukPhonetic': ukPhonetic,
      'usPhonetic': usPhonetic,
      'partOfSpeech': partOfSpeech,
      'syllables': syllables?.map((s) => s.toJson()).toList(),
      'success': success,
      'error': error,
    };
  }

  factory Phase1Response.fromJson(Map<String, dynamic> json) {
    return Phase1Response(
      word: json['word'] as String,
      ukPronunciation: json['ukPronunciation'] as String?,
      usPronunciation: json['usPronunciation'] as String?,
      wordPronunciation: json['wordPronunciation'] as String?,
      ukPhonetic: json['ukPhonetic'] as String?,
      usPhonetic: json['usPhonetic'] as String?,
      partOfSpeech: json['partOfSpeech'] as String?,
      syllables: (json['syllables'] as List?)
          ?.map((s) => Syllable.fromJson(s as Map<String, dynamic>))
          .toList(),
      success: json['success'] as bool,
      error: json['error'] as String?,
    );
  }

  factory Phase1Response.error(String word, String error) {
    return Phase1Response(
      word: word,
      success: false,
      error: error,
    );
  }
}

class Phase2Response {
  final String word;
  final SentenceContext? sentenceContext;
  final List<Definition>? definitions;
  final List<Example>? examples;
  final List<String>? memoryTips;
  final bool success;
  final String? error;

  Phase2Response({
    required this.word,
    this.sentenceContext,
    this.definitions,
    this.examples,
    this.memoryTips,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'sentenceContext': sentenceContext?.toJson(),
      'definitions': definitions?.map((d) => d.toJson()).toList(),
      'examples': examples?.map((e) => e.toJson()).toList(),
      'memoryTips': memoryTips,
      'success': success,
      'error': error,
    };
  }

  factory Phase2Response.fromJson(Map<String, dynamic> json) {
    return Phase2Response(
      word: json['word'] as String,
      sentenceContext: json['sentenceContext'] != null
          ? SentenceContext.fromJson(json['sentenceContext'] as Map<String, dynamic>)
          : null,
      definitions: (json['definitions'] as List?)
          ?.map((d) => Definition.fromJson(d as Map<String, dynamic>))
          .toList(),
      examples: (json['examples'] as List?)
          ?.map((e) => Example.fromJson(e as Map<String, dynamic>))
          .toList(),
      memoryTips: json['memoryTips'] != null
          ? List<String>.from(json['memoryTips'] as List)
          : null,
      success: json['success'] as bool,
      error: json['error'] as String?,
    );
  }

  factory Phase2Response.error(String word, String error) {
    return Phase2Response(
      word: word,
      success: false,
      error: error,
    );
  }
}

class Phase3Response {
  final String word;
  final List<WordRelation>? wordRelations;
  final bool success;
  final String? error;

  Phase3Response({
    required this.word,
    this.wordRelations,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'wordRelations': wordRelations?.map((r) => r.toJson()).toList(),
      'success': success,
      'error': error,
    };
  }

  factory Phase3Response.fromJson(Map<String, dynamic> json) {
    return Phase3Response(
      word: json['word'] as String,
      wordRelations: (json['wordRelations'] as List?)
          ?.map((r) => WordRelation.fromJson(r as Map<String, dynamic>))
          .toList(),
      success: json['success'] as bool,
      error: json['error'] as String?,
    );
  }

  factory Phase3Response.error(String word, String error) {
    return Phase3Response(
      word: word,
      success: false,
      error: error,
    );
  }
}

class WordTranslationResult {
  final String word;
  final String? ukPronunciation;
  final String? usPronunciation;
  final String? wordPronunciation;
  final String? ukPhonetic;
  final String? usPhonetic;
  final String? partOfSpeech;
  final List<Syllable>? syllables;
  final SentenceContext? sentenceContext;
  final List<Definition>? definitions;
  final List<Example>? examples;
  final List<String>? memoryTips;
  final List<WordRelation>? wordRelations;
  final String? error;
  final bool success;

  WordTranslationResult({
    required this.word,
    this.ukPronunciation,
    this.usPronunciation,
    this.wordPronunciation,
    this.ukPhonetic,
    this.usPhonetic,
    this.partOfSpeech,
    this.syllables,
    this.sentenceContext,
    this.definitions,
    this.examples,
    this.memoryTips,
    this.wordRelations,
    this.error,
    required this.success,
  });

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'ukPronunciation': ukPronunciation,
      'usPronunciation': usPronunciation,
      'wordPronunciation': wordPronunciation,
      'ukPhonetic': ukPhonetic,
      'usPhonetic': usPhonetic,
      'partOfSpeech': partOfSpeech,
      'syllables': syllables?.map((s) => s.toJson()).toList(),
      'sentenceContext': sentenceContext?.toJson(),
      'definitions': definitions?.map((d) => d.toJson()).toList(),
      'examples': examples?.map((e) => e.toJson()).toList(),
      'memoryTips': memoryTips,
      'wordRelations': wordRelations?.map((r) => r.toJson()).toList(),
      'error': error,
      'success': success,
    };
  }

  factory WordTranslationResult.fromJson(Map<String, dynamic> json) {
    return WordTranslationResult(
      word: json['word'] as String,
      ukPronunciation: json['ukPronunciation'] as String?,
      usPronunciation: json['usPronunciation'] as String?,
      wordPronunciation: json['wordPronunciation'] as String?,
      ukPhonetic: json['ukPhonetic'] as String?,
      usPhonetic: json['usPhonetic'] as String?,
      partOfSpeech: json['partOfSpeech'] as String?,
      syllables: (json['syllables'] as List?)
          ?.map((s) => Syllable.fromJson(s as Map<String, dynamic>))
          .toList(),
      sentenceContext: json['sentenceContext'] != null
          ? SentenceContext.fromJson(json['sentenceContext'] as Map<String, dynamic>)
          : null,
      definitions: (json['definitions'] as List?)
          ?.map((d) => Definition.fromJson(d as Map<String, dynamic>))
          .toList(),
      examples: (json['examples'] as List?)
          ?.map((e) => Example.fromJson(e as Map<String, dynamic>))
          .toList(),
      memoryTips: json['memoryTips'] != null
          ? List<String>.from(json['memoryTips'] as List)
          : null,
      wordRelations: (json['wordRelations'] as List?)
          ?.map((r) => WordRelation.fromJson(r as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
      success: json['success'] as bool,
    );
  }

  factory WordTranslationResult.error(String word, String error) {
    return WordTranslationResult(
      word: word,
      error: error,
      success: false,
    );
  }
}

class TranslationConfig {
  final PronunciationPriority pronunciationPriority;
  final bool showPronunciation;
  final bool showPhonetic;
  final bool showSyllable;
  final bool showPartOfSpeech;
  final bool showDefinitions;
  final bool showSentenceContext;
  final bool showExamples;
  final int maxExamples;
  final bool showMemoryTips;
  final bool showWordRelations;
  final bool showSynonyms;
  final bool showAntonyms;
  final bool showCoHyponyms;
  final bool showHypernym;
  final bool showHyponyms;
  final bool showMeronyms;
  final bool showCollocations;
  final bool showWordFamily;
  final bool showConfusables;
  final int maxRelationsPerType;

  const TranslationConfig({
    this.pronunciationPriority = PronunciationPriority.ukFirst,
    this.showPronunciation = true,
    this.showPhonetic = true,
    this.showSyllable = true,
    this.showPartOfSpeech = true,
    this.showDefinitions = true,
    this.showSentenceContext = true,
    this.showExamples = true,
    this.maxExamples = 3,
    this.showMemoryTips = true,
    this.showWordRelations = true,
    this.showSynonyms = true,
    this.showAntonyms = true,
    this.showCoHyponyms = true,
    this.showHypernym = true,
    this.showHyponyms = true,
    this.showMeronyms = true,
    this.showCollocations = true,
    this.showWordFamily = true,
    this.showConfusables = true,
    this.maxRelationsPerType = 3,
  });

  Map<String, dynamic> toJson() {
    return {
      'pronunciationPriority': pronunciationPriority.name,
      'showPronunciation': showPronunciation,
      'showPhonetic': showPhonetic,
      'showSyllable': showSyllable,
      'showPartOfSpeech': showPartOfSpeech,
      'showDefinitions': showDefinitions,
      'showSentenceContext': showSentenceContext,
      'showExamples': showExamples,
      'maxExamples': maxExamples,
      'showMemoryTips': showMemoryTips,
      'showWordRelations': showWordRelations,
      'showSynonyms': showSynonyms,
      'showAntonyms': showAntonyms,
      'showCoHyponyms': showCoHyponyms,
      'showHypernym': showHypernym,
      'showHyponyms': showHyponyms,
      'showMeronyms': showMeronyms,
      'showCollocations': showCollocations,
      'showWordFamily': showWordFamily,
      'showConfusables': showConfusables,
      'maxRelationsPerType': maxRelationsPerType,
    };
  }
}

class QwenResponse {
  final String content;
  final String? error;
  final bool success;

  QwenResponse({
    required this.content,
    this.error,
    required this.success,
  });
}

class QwenConfig {
  final String? apiKey;
  final String model;
  final String baseUrl;
  final double temperature;
  final int maxTokens;
  final int timeoutMs;

  const QwenConfig({
    this.apiKey,
    this.model = 'qwen-plus',
    this.baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    this.temperature = 0.3,
    this.maxTokens = 4096,
    this.timeoutMs = 30000,
  });

  /// 获取实际使用的 API Key，优先使用传入的，否则使用 AppConfig 中的 aliDashScopeApiKey
  String get effectiveApiKey => apiKey ?? AppConfig.aliDashScopeApiKey;
}

class QwenApi {
  final QwenConfig config;
  final List<Map<String, String>> _history = [];
  static const int _maxHistorySize = 10;
  CancelableCompleter<QwenResponse?>? _currentRequest;

  QwenApi({required this.config});

  String get _systemPrompt {
    return '''
你是一个专业的英语学习AI助手。请按照JSON格式输出单词学习内容。

输出格式要求：
1. 必须返回有效的JSON格式
2. 不要添加任何额外说明文字
3. 使用双引号，确保JSON语法正确
4. 没有数据的字段返回null或空数组
5. 音节时长单位为毫秒（ms）

响应结构定义：
{
  "word": "单词",
  "ukPronunciation": "英式发音音标或URL",
  "usPronunciation": "美式发音音标或URL",
  "wordPronunciation": "单词整体发音（当英美发音都无时返回）",
  "ukPhonetic": "英式音标",
  "usPhonetic": "美式音标",
  "partOfSpeech": "词性（noun/verb/adjective等）",
  "syllables": [
    {"letters": "音节字母组合", "pronunciation": "音节发音", "durationMs": 时长}
  ],
  "sentenceContext": {
    "englishSentence": "当前英文句子",
    "englishWord": "当前词（英文）",
    "chineseSentence": "中文释义",
    "chineseWord": "当前词（中文）"
  },
  "definitions": [
    {"partOfSpeech": "词性", "meaning": "中文释义", "example": "例句（可选）"}
  ],
  "examples": [
    {"english": "英文例句", "chinese": "中文翻译"}
  ],
  "memoryTips": ["记忆技巧1", "记忆技巧2"],
  "wordRelations": [
    {
      "type": "synonyms|antonyms|coHyponyms|hypernym|hyponyms|meronyms|collocations|wordFamily|confusables",
      "label": "关系标签",
      "words": ["词1", "词2", "词3"]
    }
  ],
  "success": true,
  "error": null
}

注意：
- syllables数组中每个音节的字母组合应正确划分
- 词性使用标准英文缩写：noun(n), verb(v), adjective(adj), adverb(adv)等
- 词联关系每类最多返回3个单词
- 如果没有当前句上下文，sentenceContext设为null
''';
  }

  List<Map<String, String>> _buildMessages(String word, String? sentence, TranslationConfig config) {
    final prompt = jsonEncode({
      'word': word,
      'sentence': sentence,
      'config': config.toJson(),
    });

    final list = <Map<String, String>>[];
    list.add({'role': 'system', 'content': _systemPrompt});
    list.addAll(_history);
    list.add({'role': 'user', 'content': prompt});

    return list;
  }

  Future<QwenResponse> _sendRequest(List<Map<String, String>> messages) async {
    cancelRequest();
    _currentRequest = CancelableCompleter<QwenResponse?>();

    final effectiveApiKey = config.effectiveApiKey;
    if (effectiveApiKey.isEmpty) {
      return QwenResponse(
        content: '',
        error: 'API Key 未设置，请在 config.dart 中设置 aliDashScopeApiKey',
        success: false,
      );
    }

    try {
      final uri = Uri.parse('${config.baseUrl}/chat/completions');
      final client = HttpClient()
        ..connectionTimeout = Duration(milliseconds: config.timeoutMs);

      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');
      request.headers.set('Authorization', 'Bearer $effectiveApiKey');

      final body = jsonEncode({
        'model': config.model,
        'messages': messages,
        'temperature': config.temperature,
        'max_tokens': config.maxTokens,
        'response_format': {'type': 'json_object'},
      });

      request.add(utf8.encode(body));

      final responseFuture = request.close().timeout(
        Duration(milliseconds: config.timeoutMs),
        onTimeout: () => throw TimeoutException('请求超时'),
      );

      final response = await responseFuture;

      if (response.statusCode != 200) {
        final body = await response.transform(utf8.decoder).join();
        client.close();
        return QwenResponse(
          content: '',
          error: '请求失败: ${response.statusCode} - $body',
          success: false,
        );
      }

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (responseBody.isEmpty) {
        return QwenResponse(
          content: '',
          error: '响应为空',
          success: false,
        );
      }

      final dynamic parsedResponse = jsonDecode(responseBody);
      if (parsedResponse is! Map<String, dynamic>) {
        return QwenResponse(
          content: '',
          error: '响应格式不正确',
          success: false,
        );
      }

      final choices = parsedResponse['choices'];

      if (choices is! List<dynamic> || choices.isEmpty) {
        return QwenResponse(
          content: '',
          error: '未获取到响应',
          success: false,
        );
      }

      final firstChoice = choices[0];
      if (firstChoice is! Map<String, dynamic>) {
        return QwenResponse(
          content: '',
          error: '响应格式不正确',
          success: false,
        );
      }

      final message = firstChoice['message'];
      if (message is! Map<String, dynamic>) {
        return QwenResponse(
          content: '',
          error: '响应格式不正确',
          success: false,
        );
      }

      final content = message['content'];
      if (content is! String) {
        return QwenResponse(
          content: '',
          error: '响应内容为空或格式不正确',
          success: false,
        );
      }

      _history.add({'role': 'assistant', 'content': content});
      if (_history.length > _maxHistorySize) {
        _history.removeRange(0, _history.length - _maxHistorySize);
      }

      return QwenResponse(content: content, success: true);

    } on TimeoutException {
      return QwenResponse(content: '', error: '请求超时', success: false);
    } on CancelException {
      return QwenResponse(content: '', error: '请求已取消', success: false);
    } catch (e) {
      return QwenResponse(content: '', error: '请求异常: $e', success: false);
    } finally {
      _currentRequest?.complete(null);
      _currentRequest = null;
    }
  }

  void cancelRequest() {
    _currentRequest?.cancel();
    _currentRequest = null;
  }

  void clearHistory() {
    _history.clear();
  }

  Future<Phase1Response> getPhase1Data({
    required String word,
    TranslationConfig config = const TranslationConfig(),
  }) async {
    try {
      final phase1Config = TranslationConfig(
        pronunciationPriority: config.pronunciationPriority,
        showPronunciation: true,
        showPhonetic: true,
        showSyllable: true,
        showPartOfSpeech: true,
        showDefinitions: false,
        showSentenceContext: false,
        showExamples: false,
        showMemoryTips: false,
        showWordRelations: false,
      );

      final messages = _buildMessages(word, null, phase1Config);
      final response = await _sendRequest(messages);

      if (!response.success) {
        return Phase1Response.error(word, response.error ?? '未知错误');
      }

      final jsonResult = jsonDecode(response.content) as Map<String, dynamic>;
      return Phase1Response.fromJson(jsonResult);

    } catch (e) {
      return Phase1Response.error(word, '解析失败: $e');
    }
  }

  Future<Phase2Response> getPhase2Data({
    required String word,
    String? sentence,
    TranslationConfig config = const TranslationConfig(),
  }) async {
    try {
      final phase2Config = TranslationConfig(
        pronunciationPriority: config.pronunciationPriority,
        showPronunciation: false,
        showPhonetic: false,
        showSyllable: false,
        showPartOfSpeech: false,
        showDefinitions: config.showDefinitions,
        showSentenceContext: config.showSentenceContext,
        showExamples: config.showExamples,
        maxExamples: config.maxExamples,
        showMemoryTips: config.showMemoryTips,
        showWordRelations: false,
      );

      final messages = _buildMessages(word, sentence, phase2Config);
      final response = await _sendRequest(messages);

      if (!response.success) {
        return Phase2Response.error(word, response.error ?? '未知错误');
      }

      final jsonResult = jsonDecode(response.content) as Map<String, dynamic>;
      return Phase2Response.fromJson(jsonResult);

    } catch (e) {
      return Phase2Response.error(word, '解析失败: $e');
    }
  }

  Future<Phase3Response> getPhase3Data({
    required String word,
    TranslationConfig config = const TranslationConfig(),
  }) async {
    try {
      final phase3Config = TranslationConfig(
        pronunciationPriority: config.pronunciationPriority,
        showPronunciation: false,
        showPhonetic: false,
        showSyllable: false,
        showPartOfSpeech: false,
        showDefinitions: false,
        showSentenceContext: false,
        showExamples: false,
        showMemoryTips: false,
        showWordRelations: config.showWordRelations,
        showSynonyms: config.showSynonyms,
        showAntonyms: config.showAntonyms,
        showCoHyponyms: config.showCoHyponyms,
        showHypernym: config.showHypernym,
        showHyponyms: config.showHyponyms,
        showMeronyms: config.showMeronyms,
        showCollocations: config.showCollocations,
        showWordFamily: config.showWordFamily,
        showConfusables: config.showConfusables,
        maxRelationsPerType: config.maxRelationsPerType,
      );

      final messages = _buildMessages(word, null, phase3Config);
      final response = await _sendRequest(messages);

      if (!response.success) {
        return Phase3Response.error(word, response.error ?? '未知错误');
      }

      final jsonResult = jsonDecode(response.content) as Map<String, dynamic>;
      return Phase3Response.fromJson(jsonResult);

    } catch (e) {
      return Phase3Response.error(word, '解析失败: $e');
    }
  }

  Stream<dynamic> translateWordStream({
    required String word,
    String? sentence,
    TranslationConfig config = const TranslationConfig(),
  }) async* {
    final phase1 = await getPhase1Data(word: word, config: config);
    yield {'phase': 1, 'data': phase1.toJson()};

    if (!phase1.success) return;

    final phase2 = await getPhase2Data(word: word, sentence: sentence, config: config);
    yield {'phase': 2, 'data': phase2.toJson()};

    if (!phase2.success || !config.showWordRelations) return;

    final phase3 = await getPhase3Data(word: word, config: config);
    yield {'phase': 3, 'data': phase3.toJson()};
  }

  Future<WordTranslationResult> translateWord({
    required String word,
    String? sentence,
    TranslationConfig config = const TranslationConfig(),
  }) async {
    try {
      final messages = _buildMessages(word, sentence, config);
      final response = await _sendRequest(messages);

      if (!response.success) {
        return WordTranslationResult.error(word, response.error ?? '未知错误');
      }

      final jsonResult = jsonDecode(response.content) as Map<String, dynamic>;
      return WordTranslationResult.fromJson(jsonResult);

    } catch (e) {
      return WordTranslationResult.error(word, '解析失败: $e');
    }
  }
}

class QwenService {
  static QwenApi? _instance;

  static QwenApi init({
    String? apiKey,
    String model = 'qwen-plus',
    String baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    double temperature = 0.3,
    int maxTokens = 4096,
    int timeoutMs = 30000,
  }) {
    final config = QwenConfig(
      apiKey: apiKey,
      model: model,
      baseUrl: baseUrl,
      temperature: temperature,
      maxTokens: maxTokens,
      timeoutMs: timeoutMs,
    );
    _instance = QwenApi(config: config);
    return _instance!;
  }

  static QwenApi? get instance => _instance;
}

class CancelException implements Exception {
  final String message;
  CancelException([this.message = '请求已取消']);
  @override
  String toString() => message;
}

class CancelableCompleter<T> {
  Completer<T> _completer = Completer<T>();
  bool _isCanceled = false;

  Future<T> get future => _completer.future;

  void complete(T value) {
    if (!_isCanceled) _completer.complete(value);
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_isCanceled) _completer.completeError(error, stackTrace);
  }

  void cancel() {
    _isCanceled = true;
    _completer.completeError(CancelException());
    _completer = Completer<T>();
  }

  bool get isCanceled => _isCanceled;
}
