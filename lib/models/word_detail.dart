import 'dart:convert';

import 'package:vidlang/models/word_book.dart';

/// 词汇难度等级
enum DifficultyLevel {
  primary,       // 小学
  juniorHigh,    // 初中
  seniorHigh,    // 高中
  cet4,          // 大学英语四级
  cet6,          // 大学英语六级
  postgraduate,  // 考研
  ielts,         // 雅思
  toefl,         // 托福
  gre,           // GRE
  unknown,       // 未知

}

/// DifficultyLevel 扩展：中文标签与颜色编码
extension DifficultyLevelX on DifficultyLevel {
  String get label {
    switch (this) {
      case DifficultyLevel.primary:       return '小学';
      case DifficultyLevel.juniorHigh:    return '初中';
      case DifficultyLevel.seniorHigh:    return '高中';
      case DifficultyLevel.cet4:          return 'CET4';
      case DifficultyLevel.cet6:          return 'CET6';
      case DifficultyLevel.postgraduate:  return '考研';
      case DifficultyLevel.ielts:         return '雅思';
      case DifficultyLevel.toefl:         return '托福';
      case DifficultyLevel.gre:           return 'GRE';
      case DifficultyLevel.unknown:       return '未知';
    }
  }

  int get colorValue {
    switch (this) {
      case DifficultyLevel.primary:
      case DifficultyLevel.juniorHigh:
      case DifficultyLevel.seniorHigh:    return 0xFF8BC34A;
      case DifficultyLevel.cet4:          return 0xFF4284FC;
      case DifficultyLevel.cet6:          return 0xFF7C4DFF;
      case DifficultyLevel.postgraduate:  return 0xFFFF6B6B;
      case DifficultyLevel.ielts:         return 0xFFFF8E53;
      case DifficultyLevel.toefl:         return 0xFFFF5252;
      case DifficultyLevel.gre:           return 0xFFE91E63;
      case DifficultyLevel.unknown:       return 0xFF999999;
    }
  }

  static DifficultyLevel fromString(String? raw) {
    if (raw == null || raw.isEmpty) return DifficultyLevel.unknown;
    final n = raw.trim().toLowerCase().replaceAll('-', '').replaceAll('_', '');
    switch (n) {
      case 'primary':       return DifficultyLevel.primary;
      case 'juniorhigh':
      case 'junior':        return DifficultyLevel.juniorHigh;
      case 'seniorhigh':
      case 'senior':        return DifficultyLevel.seniorHigh;
      case 'cet4':          return DifficultyLevel.cet4;
      case 'cet6':          return DifficultyLevel.cet6;
      case 'postgraduate':
      case 'kaoyan':
      case '考研':          return DifficultyLevel.postgraduate;
      case 'ielts':         return DifficultyLevel.ielts;
      case 'toefl':         return DifficultyLevel.toefl;
      case 'gre':           return DifficultyLevel.gre;
      default:              return DifficultyLevel.unknown;
    }
  }

}

/// 发音信息
class PronounceInfo {
  final String? ukPhonetic;
  final String? usPhonetic;
  final String? ukAudioUrl;
  final String? usAudioUrl;

  const PronounceInfo({
    this.ukPhonetic,
    this.usPhonetic,
    this.ukAudioUrl,
    this.usAudioUrl,
  });

  Map<String, dynamic> toJson() => {
    'uk_phonetic': ukPhonetic,
    'us_phonetic': usPhonetic,
    'uk_audio_url': ukAudioUrl,
    'us_audio_url': usAudioUrl,
  };

  factory PronounceInfo.fromJson(Map<String, dynamic> json) => PronounceInfo(
    ukPhonetic: json['uk_phonetic'] as String? ?? json['ukPhonetic'] as String?,
    usPhonetic: json['us_phonetic'] as String? ?? json['usPhonetic'] as String?,
    ukAudioUrl: json['uk_audio_url'] as String? ?? json['ukAudioUrl'] as String?,
    usAudioUrl: json['us_audio_url'] as String? ?? json['usAudioUrl'] as String?,
  );
}

/// 例句
class WordExample {
  final String english;
  final String chinese;
  final String? exampleAudioUrl;

  const WordExample({
    required this.english,
    required this.chinese,
    this.exampleAudioUrl,
  });

  Map<String, dynamic> toJson() => {
    'english': english,
    'chinese': chinese,
    'example_audio_url': exampleAudioUrl,
  };

  factory WordExample.fromJson(Map<String, dynamic> json) => WordExample(
    english: json['english'] as String? ?? json['en'] as String? ?? '',
    chinese: json['chinese'] as String? ?? json['zh'] as String? ?? '',
    exampleAudioUrl: json['example_audio_url'] as String? ?? json['exampleAudioUrl'] as String?,
  );
}

/// 词形变化
class WordMorphology {
  final String? plural;
  final String? pastTense;
  final String? pastParticiple;
  final String? presentParticiple;
  final String? thirdPerson;
  final String? comparative;
  final String? superlative;
  final List<String> synonyms;
  final List<String> antonyms;

  const WordMorphology({
    this.plural,
    this.pastTense,
    this.pastParticiple,
    this.presentParticiple,
    this.thirdPerson,
    this.comparative,
    this.superlative,
    this.synonyms = const [],
    this.antonyms = const [],
  });

  Map<String, dynamic> toJson() => {
    if (plural != null) 'plural': plural,
    if (pastTense != null) 'past_tense': pastTense,
    if (pastParticiple != null) 'past_participle': pastParticiple,
    if (presentParticiple != null) 'present_participle': presentParticiple,
    if (thirdPerson != null) 'third_person': thirdPerson,
    if (comparative != null) 'comparative': comparative,
    if (superlative != null) 'superlative': superlative,
    'synonyms': synonyms,
    'antonyms': antonyms,
  };

  factory WordMorphology.fromJson(Map<String, dynamic> json) => WordMorphology(
    plural: json['plural'] as String?,
    pastTense: json['past_tense'] as String?,
    pastParticiple: json['past_participle'] as String?,
    presentParticiple: json['present_participle'] as String?,
    thirdPerson: json['third_person'] as String?,
    comparative: json['comparative'] as String?,
    superlative: json['superlative'] as String?,
    synonyms: (json['synonyms'] as List?)?.cast<String>() ?? [],
    antonyms: (json['antonyms'] as List?)?.cast<String>() ?? [],
  );
}

/// 单词释义
class WordDefinition {
  final String? partOfSpeech;
  final String chineseMeaning;
  final String? englishMeaning;
  final List<WordExample> examples;

  const WordDefinition({
    this.partOfSpeech,
    required this.chineseMeaning,
    this.englishMeaning,
    this.examples = const [],
  });

  Map<String, dynamic> toJson() => {
    'part_of_speech': partOfSpeech,
    'chinese_meaning': chineseMeaning,
    if (englishMeaning != null) 'english_meaning': englishMeaning,
    'examples': examples.map((e) => e.toJson()).toList(),
  };

  factory WordDefinition.fromJson(Map<String, dynamic> json) => WordDefinition(
    partOfSpeech: json['part_of_speech'] as String? ?? json['partOfSpeech'] as String?,
    chineseMeaning: (json['chinese_meaning'] as String? ??
            json['chineseMeaning'] as String? ??
            json['meaning'] as String? ??
            '')
        .trim(),
    englishMeaning: json['english_meaning'] as String? ?? json['englishMeaning'] as String?,
    examples: (json['examples'] as List?)
            ?.whereType<Map>()
            .map((e) => WordExample.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const [],
  );
}

/// 统一词条详情模型
///
/// 替代旧版 [WordCardData]，统一承载 AI 返回、本地词典、错误回退三种数据来源。
class WordDetail {
  final String word;
  final PronounceInfo pronounce;
  final List<WordDefinition> definitions;
  final List<WordExample> standaloneExamples;
  final DifficultyLevel difficulty;
  final WordMorphology? morphology;
  final String? mnemonic;
  final String? contextSentence;
  final String? sentenceTranslation;
  final String? wordMeaningInContext;
  final String? translation;
  final bool success;
  final String? error;
  final double? costCny;
  final double? balanceAfter;
  final String source;

  const WordDetail({
    required this.word,
    this.pronounce = const PronounceInfo(),
    this.definitions = const [],
    this.standaloneExamples = const [],
    this.difficulty = DifficultyLevel.unknown,
    this.morphology,
    this.mnemonic,
    this.contextSentence,
    this.sentenceTranslation,
    this.wordMeaningInContext,
    this.translation,
    this.success = true,
    this.error,
    this.costCny,
    this.balanceAfter,
    this.source = 'native',
  });

  /// 快速获取首选音标
  String? get displayPhonetic => pronounce.ukPhonetic ?? pronounce.usPhonetic;

  /// 是否为余额不足错误
  bool get isInsufficientBalance => !success && error != null && source == 'ai';

  // ─── 工厂方法 ─────────────────────────────────

  /// 从 AI Edge Function 响应构造
  factory WordDetail.fromAiResult(Map<String, dynamic> result, {double? costCny, double? balanceAfter}) {
    // pronounce
    final pronounce = result['pronounce'] is Map
        ? PronounceInfo.fromJson(result['pronounce'] as Map<String, dynamic>)
        : PronounceInfo(
            ukPhonetic: result['phonetic_uk'] as String? ?? result['uk_phonetic'] as String?,
            usPhonetic: result['phonetic_us'] as String? ?? result['us_phonetic'] as String?,
            ukAudioUrl: result['uk_audio_url'] as String?,
            usAudioUrl: result['us_audio_url'] as String?,
          );

    // definitions
    final defsRaw = result['definitions'];
    final List<WordDefinition> definitions = [];
    if (defsRaw is List) {
      for (final d in defsRaw) {
        if (d is Map) {
          definitions.add(WordDefinition.fromJson(d.cast<String, dynamic>()));
        }
      }
    }

    // standalone_examples
    final examplesRaw = result['standalone_examples'];
    final List<WordExample> standaloneExamples = [];
    if (examplesRaw is List) {
      for (final e in examplesRaw) {
        if (e is Map) {
          standaloneExamples.add(WordExample.fromJson(e.cast<String, dynamic>()));
        }
      }
    }

    // morphology
    WordMorphology? morphology;
    if (result['morphology'] is Map) {
      morphology = WordMorphology.fromJson(result['morphology'] as Map<String, dynamic>);
    }

    // ── context_sentence_info（当前句高亮信息）──
    String? contextSentence;
    String? sentenceTranslation;
    String? wordMeaningInContext;

    // 优先从新的 context_sentence_info 结构中解析
    final contextInfo = result['context_sentence_info'];
    if (contextInfo is Map) {
      // 使用高亮后的句子（单词已用【】包裹）
      contextSentence = contextInfo['word_highlighted_sentence'] as String?
          ?? contextInfo['original_sentence'] as String?;
      // 使用高亮后的翻译
      sentenceTranslation = contextInfo['sentence_translation'] as String?;
      // 语境中的词义
      wordMeaningInContext = contextInfo['word_meaning_in_context'] as String?;
    }

    // 降级：如果没有 context_sentence_info，尝试旧字段
    contextSentence ??= result['context_sentence'] as String? ?? result['contextSentence'] as String?;
    sentenceTranslation ??= result['sentence_translation'] as String? ?? result['sentenceTranslation'] as String?;
    wordMeaningInContext ??= result['word_meaning_in_context'] as String? ?? result['wordMeaningInContext'] as String?;

    final word = (result['word'] as String? ?? '').trim();
    return WordDetail(
      word: word.isNotEmpty ? word : (result['text'] as String? ?? ''),
      pronounce: pronounce,
      definitions: definitions,
      standaloneExamples: standaloneExamples,
      difficulty: DifficultyLevelX.fromString(result['difficulty'] as String?),
      morphology: morphology,
      mnemonic: result['mnemonic'] as String?,
      contextSentence: contextSentence,
      sentenceTranslation: sentenceTranslation,
      wordMeaningInContext: wordMeaningInContext,
      translation: result['translation'] as String? ?? result['translatedText'] as String?,
      success: true,
      costCny: costCny,
      balanceAfter: balanceAfter,
      source: 'ai',
    );
  }

  /// 从本地词典 WordBook 构造
  factory WordDetail.fromNativeDict(WordBook entry) {
    // 尝试解析 definitionsJson
    List<WordDefinition> definitions = [];
    if (entry.definitionsJson != null && entry.definitionsJson!.isNotEmpty) {
      try {
        final parsed = jsonDecode(entry.definitionsJson!);
        if (parsed is List) {
          for (final d in parsed) {
            if (d is Map) {
              definitions.add(WordDefinition(
                partOfSpeech: d['part_of_speech'] as String? ?? d['partOfSpeech'] as String?,
                chineseMeaning: d['chinese_meaning'] as String? ?? d['meaning'] as String? ?? '',
                englishMeaning: d['english_meaning'] as String?,
              ));
            }
          }
        }
      } catch (_) {}
    }

    // 尝试解析 morphologyJson
    WordMorphology? morphology;
    if (entry.morphologyJson != null && entry.morphologyJson!.isNotEmpty) {
      try {
        final parsed = jsonDecode(entry.morphologyJson!);
        if (parsed is Map) {
          morphology = WordMorphology.fromJson(parsed as Map<String, dynamic>);
        }
      } catch (_) {}
    }

    return WordDetail(
      word: entry.word,
      pronounce: PronounceInfo(
        ukPhonetic: entry.phoneticUk,
        usPhonetic: entry.phoneticUs,
      ),
      definitions: definitions,
      difficulty: DifficultyLevelIndex.fromIndex(entry.difficulty),
      morphology: morphology,
      mnemonic: entry.mnemonic,
      contextSentence: entry.contextSentence,
      source: 'native',
    );
  }

  /// 错误构造
  factory WordDetail.error(String word, String error, {bool isInsufficientBalance = false, double? requiredCny, double? balanceCny}) {
    return WordDetail(
      word: word,
      success: false,
      error: error,
      costCny: requiredCny,
      balanceAfter: balanceCny,
      source: isInsufficientBalance ? 'ai' : 'native',
    );
  }

  // ─── 序列化 ─────────────────────────────────

  Map<String, dynamic> toJson() => {
    'word': word,
    'pronounce': pronounce.toJson(),
    'definitions': definitions.map((d) => d.toJson()).toList(),
    'standalone_examples': standaloneExamples.map((e) => e.toJson()).toList(),
    'difficulty': difficulty.name,
    if (morphology != null) 'morphology': morphology!.toJson(),
    if (mnemonic != null) 'mnemonic': mnemonic,
    if (contextSentence != null) 'context_sentence': contextSentence,
    if (sentenceTranslation != null) 'sentence_translation': sentenceTranslation,
    if (wordMeaningInContext != null) 'word_meaning_in_context': wordMeaningInContext,
    if (translation != null) 'translation': translation,
    'success': success,
    if (error != null) 'error': error,
    if (costCny != null) 'cost_cny': costCny,
    if (balanceAfter != null) 'balance_after': balanceAfter,
    'source': source,
  };

  factory WordDetail.fromJson(Map<String, dynamic> json) => WordDetail(
    word: json['word'] as String? ?? '',
    pronounce: json['pronounce'] is Map
        ? PronounceInfo.fromJson(json['pronounce'] as Map<String, dynamic>)
        : const PronounceInfo(),
    definitions: (json['definitions'] as List?)
        ?.map((d) => WordDefinition.fromJson(d as Map<String, dynamic>))
        .toList() ?? [],
    standaloneExamples: (json['standalone_examples'] as List?)
        ?.map((e) => WordExample.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    difficulty: DifficultyLevelX.fromString(json['difficulty'] as String?),
    morphology: json['morphology'] is Map
        ? WordMorphology.fromJson(json['morphology'] as Map<String, dynamic>)
        : null,
    mnemonic: json['mnemonic'] as String?,
    contextSentence: json['context_sentence'] as String?,
    sentenceTranslation: json['sentence_translation'] as String?,
    wordMeaningInContext: json['word_meaning_in_context'] as String?,
    translation: json['translation'] as String?,
    success: json['success'] as bool? ?? true,
    error: json['error'] as String?,
    costCny: _toDouble(json['cost_cny']),
    balanceAfter: _toDouble(json['balance_after']),
    source: json['source'] as String? ?? 'native',
  );

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// DifficultyLevel 与 WordBook 整数难度的双向映射
extension DifficultyLevelIndex on DifficultyLevel {
  static DifficultyLevel fromIndex(int? index) {
    if (index == null) return DifficultyLevel.unknown;
    const map = <int, DifficultyLevel>{
      1: DifficultyLevel.primary,
      2: DifficultyLevel.juniorHigh,
      3: DifficultyLevel.seniorHigh,
      4: DifficultyLevel.cet4,
      5: DifficultyLevel.cet6,
      6: DifficultyLevel.postgraduate,
      7: DifficultyLevel.ielts,
      8: DifficultyLevel.toefl,
      9: DifficultyLevel.gre,
    };
    return map[index] ?? DifficultyLevel.unknown;
  }

  int get toIndex {
    switch (this) {
      case DifficultyLevel.primary:       return 1;
      case DifficultyLevel.juniorHigh:    return 2;
      case DifficultyLevel.seniorHigh:    return 3;
      case DifficultyLevel.cet4:          return 4;
      case DifficultyLevel.cet6:          return 5;
      case DifficultyLevel.postgraduate:  return 6;
      case DifficultyLevel.ielts:         return 7;
      case DifficultyLevel.toefl:         return 8;
      case DifficultyLevel.gre:           return 9;
      case DifficultyLevel.unknown:       return 0;
    }
  }
}
