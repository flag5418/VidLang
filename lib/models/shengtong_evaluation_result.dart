import 'package:flutter/material.dart';
import 'package:vidlang/theme/theme.dart';

/// 声通语音评测结果解析器
/// 
/// 将声通返回的原始 JSON 解析为结构化的评测数据，
/// 支持单词级、音素级、句子级的详细分析。
///
/// 声通评测维度（基于PPT文档）：
/// - 总分 (overall)
/// - 流利度 (fluency) - 节奏、流畅度
/// - 完整度 (integrity) - 漏读/多读检测
/// - 准确度 (accuracy) - 音素级匹配
/// - 发音得分 (pronunciation)
/// - 音标得分 - 音素发音准确性
/// - 单词重音 - 重音位置是否正确
/// - 连读 - 连读是否自然
/// - 爆破音 - 爆破音是否到位
/// - 韵律度 - 语调韵律
/// - 句末语调 - 句末语调是否正确
/// - 逻辑准确性 - 语义逻辑
class ShengtongEvaluationResult {
  /// 原始评测结果 JSON
  final Map<String, dynamic> rawResult;
  
  /// 评分唯一ID
  final String? recordId;
  
  /// 总分 (0-100)
  final double? overall;
  
  /// 流利度 (0-100) - 节奏、流畅度
  final double? fluency;
  
  /// 完整度 (0-100) - 漏读/多读检测
  final double? integrity;
  
  /// 准确度 (0-100) - 音素级匹配
  final double? accuracy;
  
  /// 发音得分 (0-100)
  final double? pronunciation;
  
  /// 单词级评分详情
  final List<WordEvaluation> words;
  
  /// 句子级评分详情（段落评测时）
  final List<SentenceEvaluation>? sentences;
  
  /// 参考文本
  final String? refText;
  
  /// 识别文本（用户实际朗读）
  final String? recognizedText;
  
  /// 音频下载地址（如开启 attachAudioUrl）
  final String? audioUrl;
  
  /// 是否返回了请求参数
  final Map<String, dynamic>? requestParams;

  ShengtongEvaluationResult({
    required this.rawResult,
    this.recordId,
    this.overall,
    this.fluency,
    this.integrity,
    this.accuracy,
    this.pronunciation,
    this.words = const [],
    this.sentences,
    this.refText,
    this.recognizedText,
    this.audioUrl,
    this.requestParams,
  });

  /// 从声通原始响应解析
  factory ShengtongEvaluationResult.fromJson(Map<String, dynamic> json) {
    // 声通返回结构：result 字段包含实际评测结果
    final result = json['result'] as Map<String, dynamic>? ?? json;
    
    // 解析单词级详情
    final wordsJson = result['words'] as List<dynamic>?;
    final words = wordsJson?.map((w) => WordEvaluation.fromJson(w as Map<String, dynamic>)).toList() ?? [];
    
    // 解析句子级详情（段落评测）
    final sentencesJson = result['sentences'] as List<dynamic>?;
    final sentences = sentencesJson?.map((s) => SentenceEvaluation.fromJson(s as Map<String, dynamic>)).toList();
    
    return ShengtongEvaluationResult(
      rawResult: json,
      recordId: result['recordId'] as String?,
      overall: (result['overall'] as num?)?.toDouble(),
      fluency: (result['fluency'] as num?)?.toDouble(),
      integrity: (result['integrity'] as num?)?.toDouble(),
      accuracy: (result['accuracy'] as num?)?.toDouble(),
      pronunciation: (result['pronunciation'] as num?)?.toDouble(),
      words: words,
      sentences: sentences,
      refText: result['refText'] as String?,
      recognizedText: result['recogText'] as String? ?? result['recognizedText'] as String?,
      audioUrl: result['audioUrl'] as String?,
      requestParams: result['requestParams'] as Map<String, dynamic>?,
    );
  }

  /// 获取主要维度分数映射（用于可视化展示）
  Map<String, double?> get dimensionScores => {
    '总分': overall,
    '流利度': fluency,
    '完整度': integrity,
    '准确度': accuracy,
    '发音': pronunciation,
  };

  /// 获取薄弱维度（分数最低的维度）
  List<MapEntry<String, double?>> get weakDimensions {
    final scores = dimensionScores.entries.where((e) => e.value != null).toList();
    scores.sort((a, b) => (a.value ?? 0).compareTo(b.value ?? 0));
    return scores;
  }

  /// 获取错误单词列表（得分低于阈值的单词）
  List<WordEvaluation> getErrorWords({double threshold = 70}) {
    return words.where((w) => (w.score ?? 0) < threshold).toList();
  }

  /// 获取漏读单词列表
  List<WordEvaluation> getMissingWords() {
    return words.where((w) => w.readType == 'miss').toList();
  }

  /// 获取发音错误详情（音素级）
  List<PhonemeError> getPhonemeErrors() {
    final errors = <PhonemeError>[];
    for (final word in words) {
      for (final phoneme in word.phonemes) {
        if (phoneme.score != null && phoneme.score! < 70) {
          errors.add(PhonemeError(
            word: word.word,
            phoneme: phoneme.phoneme,
            expectedPhoneme: phoneme.expectedPhoneme,
            score: phoneme.score!,
            position: phoneme.position,
          ));
        }
      }
    }
    return errors;
  }

  /// 获取重音错误列表
  List<WordEvaluation> getStressErrors() {
    return words.where((w) => w.wordStress == false).toList();
  }

  /// 生成 AI 分析所需的结构化数据
  Map<String, dynamic> toAiAnalysisData() {
    return {
      'overall_score': overall,
      'dimensions': {
        'fluency': fluency,
        'integrity': integrity,
        'accuracy': accuracy,
        'pronunciation': pronunciation,
      },
      'weak_dimensions': weakDimensions.take(2).map((e) => {
        'name': e.key,
        'score': e.value,
      }).toList(),
      'error_words': getErrorWords().map((w) => {
        'word': w.word,
        'score': w.score,
        'read_type': w.readType,
        'phoneme_errors': w.phonemes.where((p) => (p.score ?? 0) < 70).map((p) => {
          'phoneme': p.phoneme,
          'expected': p.expectedPhoneme,
          'score': p.score,
        }).toList(),
      }).toList(),
      'missing_words': getMissingWords().map((w) => w.word).toList(),
      'stress_errors': getStressErrors().map((w) => w.word).toList(),
      'total_words': words.length,
      'correct_words': words.where((w) => (w.score ?? 0) >= 70).length,
    };
  }

  /// 生成用户友好的评测摘要
  String generateSummary() {
    final buffer = StringBuffer();
    
    if (overall != null) {
      buffer.writeln('总分: ${overall!.toStringAsFixed(1)}分');
    }
    
    final weakDims = weakDimensions;
    if (weakDims.isNotEmpty) {
      buffer.writeln('需要加强: ${weakDims.first.key}(${weakDims.first.value?.toStringAsFixed(1)}分)');
    }
    
    final errorWords = getErrorWords();
    if (errorWords.isNotEmpty) {
      buffer.writeln('发音待改进: ${errorWords.take(3).map((w) => w.word).join(', ')}${errorWords.length > 3 ? '...' : ''}');
    }
    
    final missing = getMissingWords();
    if (missing.isNotEmpty) {
      buffer.writeln('漏读: ${missing.map((w) => w.word).join(', ')}');
    }
    
    return buffer.toString().trim();
  }
}

/// 单词级评测详情
class WordEvaluation {
  /// 单词文本
  final String word;
  
  /// 单词得分 (0-100)
  final double? score;
  
  /// 朗读类型
  /// - 'normal': 正常朗读
  /// - 'miss': 漏读
  /// - 'repeat': 重复读
  /// - 'insert': 多读
  final String? readType;
  
  /// 单词重音是否正确
  final bool? wordStress;
  
  /// 音素级评分
  final List<PhonemeEvaluation> phonemes;
  
  /// 单词在句子中的起始时间（毫秒）
  final int? beginTime;
  
  /// 单词在句子中的结束时间（毫秒）
  final int? endTime;
  
  /// 单词音标（KK/CMU/IPA88）
  final String? phonetic;

  WordEvaluation({
    required this.word,
    this.score,
    this.readType,
    this.wordStress,
    this.phonemes = const [],
    this.beginTime,
    this.endTime,
    this.phonetic,
  });

  factory WordEvaluation.fromJson(Map<String, dynamic> json) {
    // 解析音素数据 - 支持两种结构：
    // 1. sent.eval: phonemes 数组 [{phoneme: "l", pronunciation: 80}]
    // 2. word.eval: scores.stress 数组 [{spell: "vi", phonetic: "vɪ", overall: 31}]
    List<PhonemeEvaluation> phonemes = [];
    
    // 尝试解析 sent.eval 结构
    final phonemesJson = json['phonemes'] as List<dynamic>? ?? json['phones'] as List<dynamic>?;
    if (phonemesJson != null && phonemesJson.isNotEmpty) {
      phonemes = phonemesJson.map((p) => PhonemeEvaluation.fromJson(p as Map<String, dynamic>)).toList();
    }
    
    // 尝试解析 word.eval 结构 (scores.stress)
    if (phonemes.isEmpty && json['scores'] != null && json['scores'] is Map) {
      final scores = json['scores'] as Map<String, dynamic>;
      final stressList = scores['stress'] as List<dynamic>?;
      if (stressList != null && stressList.isNotEmpty) {
        phonemes = stressList.map((s) => PhonemeEvaluation.fromStressJson(s as Map<String, dynamic>)).toList();
      }
    }
    
    // 处理声通 WebSocket 响应结构
    // scores.overall → score
    double? score;
    if (json['scores'] != null && json['scores'] is Map) {
      final scores = json['scores'] as Map<String, dynamic>;
      score = (scores['overall'] as num?)?.toDouble();
    } else {
      score = (json['score'] as num?)?.toDouble();
    }
    
    // 处理 readType：声通返回整数 (0=正常, 3=漏读, 4=重复读)，转为字符串
    String? readType;
    if (json['readType'] != null) {
      final rt = json['readType'];
      if (rt is int) {
        switch (rt) {
          case 0: readType = 'normal'; break;
          case 3: readType = 'miss'; break;
          case 4: readType = 'repeat'; break;
          default: readType = 'normal';
        }
      } else if (rt is String) {
        readType = rt;
      }
    } else if (json['read_type'] != null) {
      readType = json['read_type'] as String?;
    }
    
    // 解析单词音标 (word.eval 时 phonetic 在 word_parts 中)
    String? phonetic;
    if (json['phonetic'] != null) {
      phonetic = json['phonetic'] as String?;
    } else if (json['word_parts'] != null && json['word_parts'] is List) {
      final parts = json['word_parts'] as List;
      if (parts.isNotEmpty) {
        phonetic = parts.map((p) => p['phonetic'] as String? ?? '').join('');
      }
    }
    
    return WordEvaluation(
      word: json['word'] as String? ?? '',
      score: score,
      readType: readType,
      wordStress: json['wordStress'] as bool? ?? json['word_stress'] as bool?,
      phonemes: phonemes,
      beginTime: json['beginTime'] as int? ?? json['begin_time'] as int?,
      endTime: json['endTime'] as int? ?? json['end_time'] as int?,
      phonetic: phonetic,
    );
  }
}

/// 音素级评测详情
class PhonemeEvaluation {
  /// 音素符号（如 /æ/, /θ/ 等）
  final String phoneme;
  
  /// 拼写（word.eval 时为音节拼写，如 "vi", "de"）
  final String? spelling;
  
  /// 标准音素（期望用户发音的音素）
  final String? expectedPhoneme;
  
  /// 音素得分 (0-100)
  final double? score;
  
  /// 音素在单词中的位置
  final int? position;
  
  /// 是否为重读音素
  final bool? isStress;

  PhonemeEvaluation({
    required this.phoneme,
    this.spelling,
    this.expectedPhoneme,
    this.score,
    this.position,
    this.isStress,
  });

  factory PhonemeEvaluation.fromJson(Map<String, dynamic> json) {
    // 处理声通 WebSocket 响应结构
    // pronunciation 字段是音素得分
    double? score;
    if (json['pronunciation'] != null) {
      score = (json['pronunciation'] as num?)?.toDouble();
    } else if (json['overall'] != null) {
      score = (json['overall'] as num?)?.toDouble();
    } else {
      score = (json['score'] as num?)?.toDouble();
    }
    
    return PhonemeEvaluation(
      phoneme: json['phoneme'] as String? ?? json['phone'] as String? ?? '',
      expectedPhoneme: json['expectedPhoneme'] as String? ?? json['expected_phone'] as String?,
      score: score,
      position: json['position'] as int?,
      isStress: json['isStress'] as bool? ?? json['is_stress'] as bool?,
    );
  }
  
  /// 从 word.eval 的 scores.stress 数组解析
  /// 结构: {"spell":"vi","phonetic":"vɪ","phoneme_offset":0,"stress":0,"overall":31,"ref_stress":1}
  factory PhonemeEvaluation.fromStressJson(Map<String, dynamic> json) {
    return PhonemeEvaluation(
      phoneme: json['phonetic'] as String? ?? '',
      spelling: json['spell'] as String?,
      expectedPhoneme: json['spell'] as String?,
      score: (json['overall'] as num?)?.toDouble(),
      position: json['phoneme_offset'] as int?,
      isStress: json['stress'] == 1,
    );
  }
}

/// 音素错误（用于AI分析）
class PhonemeError {
  final String word;
  final String phoneme;
  final String? expectedPhoneme;
  final double score;
  final int? position;

  PhonemeError({
    required this.word,
    required this.phoneme,
    this.expectedPhoneme,
    required this.score,
    this.position,
  });

  Map<String, dynamic> toJson() => {
    'word': word,
    'phoneme': phoneme,
    'expected': expectedPhoneme,
    'score': score,
    'position': position,
  };
}

/// 句子级评测详情（段落评测时使用）
class SentenceEvaluation {
  /// 句子文本
  final String text;
  
  /// 句子得分
  final double? score;
  
  /// 句子流利度
  final double? fluency;
  
  /// 句子完整度
  final double? integrity;
  
  /// 单词级详情
  final List<WordEvaluation> words;

  SentenceEvaluation({
    required this.text,
    this.score,
    this.fluency,
    this.integrity,
    this.words = const [],
  });

  factory SentenceEvaluation.fromJson(Map<String, dynamic> json) {
    final wordsJson = json['words'] as List<dynamic>? ?? json['details'] as List<dynamic>?;
    final words = wordsJson?.map((w) => WordEvaluation.fromJson(w as Map<String, dynamic>)).toList() ?? [];
    
    return SentenceEvaluation(
      text: json['text'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
      fluency: (json['fluency'] as num?)?.toDouble(),
      integrity: (json['integrity'] as num?)?.toDouble(),
      words: words,
    );
  }
}

/// 评测结果展示工具类
class EvaluationDisplayHelper {
  /// 根据分数获取颜色
  static Color getScoreColor(double score) {
    if (score >= 90) return const Color(0xFF4CAF50); // 绿色-优秀
    if (score >= 80) return const Color(0xFF8BC34A); // 浅绿-良好
    if (score >= 70) return const Color(0xFFFFC107); // 黄色-及格
    if (score >= 60) return const Color(0xFFFF9800); // 橙色-待改进
    return const Color(0xFFF44336); // 红色-需加强
  }

  /// 根据分数获取等级标签
  static String getScoreLabel(double score) {
    if (score >= 90) return '优秀';
    if (score >= 80) return '良好';
    if (score >= 70) return '及格';
    if (score >= 60) return '待改进';
    return '需加强';
  }

  /// 根据分数获取图标
  static IconData getScoreIcon(double score) {
    if (score >= 90) return AppIcons.sentimentVerySatisfied;
    if (score >= 80) return AppIcons.sentimentSatisfied;
    if (score >= 70) return AppIcons.sentimentNeutral;
    if (score >= 60) return AppIcons.sentimentDissatisfied;
    return AppIcons.sentimentVeryDissatisfied;
  }

  /// 获取维度图标
  static IconData getDimensionIcon(String dimension) {
    switch (dimension) {
      case '总分':
      case 'overall':
        return AppIcons.star;
      case '流利度':
      case 'fluency':
        return AppIcons.speed;
      case '完整度':
      case 'integrity':
        return AppIcons.checkCircle;
      case '准确度':
      case 'accuracy':
        return AppIcons.gpsFixed;
      case '发音':
      case 'pronunciation':
        return AppIcons.recordVoiceOver;
      default:
        return AppIcons.analytics;
    }
  }

  /// 获取维度描述
  static String getDimensionDescription(String dimension) {
    switch (dimension) {
      case '流利度':
      case 'fluency':
        return '反映朗读的流畅性和节奏感';
      case '完整度':
      case 'integrity':
        return '检测是否有漏读或多读的内容';
      case '准确度':
      case 'accuracy':
        return '音素级发音匹配程度';
      case '发音':
      case 'pronunciation':
        return '整体发音质量评估';
      default:
        return '';
    }
  }

  /// 获取朗读类型中文描述
  static String getReadTypeDescription(String? readType) {
    switch (readType) {
      case 'normal':
        return '正常';
      case 'miss':
        return '漏读';
      case 'repeat':
        return '重复';
      case 'insert':
        return '多读';
      default:
        return readType ?? '未知';
    }
  }

  /// 获取朗读类型颜色
  static Color getReadTypeColor(String? readType) {
    switch (readType) {
      case 'normal':
        return const Color(0xFF4CAF50);
      case 'miss':
        return const Color(0xFFF44336);
      case 'repeat':
        return const Color(0xFFFF9800);
      case 'insert':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }
}
