/// 声通评测结果模型
///
/// 根据声通 sent.eval/sent.eval.pro 文档定义的数据结构。
/// 对应 WebSocket 返回的 eval 消息中的 result 字段。
class ShengtongSentenceResult {
  /// 总分 (0-100)
  final double overall;

  /// 流利度 (0-100)
  final double fluency;

  /// 发音得分 (0-100)
  final double pronunciation;

  /// 完整度 (0-100)
  final double integrity;

  /// 韵律度得分 (0-100)
  final double rhythm;

  /// 语速 (词/分钟)
  final int? speed;

  /// 音频时长 (秒)
  final double? duration;

  /// 音频时长 (数值)
  final double? numericDuration;

  /// 停顿次数
  final int? pauseCount;

  /// 可评分单词总数
  final int? scorableWordCount;

  /// 内核版本
  final String? kernelVersion;

  /// 资源版本
  final String? resourceVersion;

  /// 句末语调: rise=升调, fall=降调
  final String? rearTone;

  /// 情感得分 (需开启 sentence_need_emotion)
  final int? emotion;

  /// 单词级评分结果
  final List<ShengtongWordResult> words;

  /// 连读检测结果 (仅实际发生连读时存在)
  final List<ShengtongLiaison>? liaison;

  /// 不完全爆破检测 (仅实际发生爆破时存在)
  final List<ShengtongPlosion>? plosion;

  /// 音频检测警告信息
  final List<ShengtongWarning>? warning;

  const ShengtongSentenceResult({
    required this.overall,
    required this.fluency,
    required this.pronunciation,
    required this.integrity,
    required this.rhythm,
    this.speed,
    this.duration,
    this.numericDuration,
    this.pauseCount,
    this.scorableWordCount,
    this.kernelVersion,
    this.resourceVersion,
    this.rearTone,
    this.emotion,
    this.words = const [],
    this.liaison,
    this.plosion,
    this.warning,
  });

  factory ShengtongSentenceResult.fromJson(Map<String, dynamic> json) {
    return ShengtongSentenceResult(
      overall: _parseDouble(json['overall']) ?? 0.0,
      fluency: _parseDouble(json['fluency']) ?? 0.0,
      pronunciation: _parseDouble(json['pronunciation']) ?? 0.0,
      integrity: _parseDouble(json['integrity']) ?? 0.0,
      rhythm: _parseDouble(json['rhythm']) ?? 0.0,
      speed: json['speed'] as int?,
      duration: _parseDouble(json['duration']),
      numericDuration: _parseDouble(json['numeric_duration']),
      pauseCount: json['pause_count'] as int?,
      scorableWordCount: json['scorable_word_count'] as int?,
      kernelVersion: json['kernel_version'] as String?,
      resourceVersion: json['resource_version'] as String?,
      rearTone: json['rear_tone'] as String?,
      emotion: json['emotion'] as int?,
      words: (json['words'] as List?)
              ?.map((w) => ShengtongWordResult.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [],
      liaison: (json['liaison'] as List?)
              ?.map((l) => ShengtongLiaison.fromJson(l as Map<String, dynamic>))
              .toList(),
      plosion: (json['plosion'] as List?)
              ?.map((p) => ShengtongPlosion.fromJson(p as Map<String, dynamic>))
              .toList(),
      warning: (json['warning'] as List?)
              ?.map((w) => ShengtongWarning.fromJson(w as Map<String, dynamic>))
              .toList(),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'overall': overall,
      'fluency': fluency,
      'pronunciation': pronunciation,
      'integrity': integrity,
      'rhythm': rhythm,
      'speed': speed,
      'duration': duration,
      'numeric_duration': numericDuration,
      'pause_count': pauseCount,
      'scorable_word_count': scorableWordCount,
      'kernel_version': kernelVersion,
      'resource_version': resourceVersion,
      'rear_tone': rearTone,
      'emotion': emotion,
      'words': words.map((w) => w.toJson()).toList(),
      if (liaison != null) 'liaison': liaison!.map((l) => l.toJson()).toList(),
      if (plosion != null) 'plosion': plosion!.map((p) => p.toJson()).toList(),
      if (warning != null) 'warning': warning!.map((w) => w.toJson()).toList(),
    };
  }
}

/// 单词级评测结果
class ShengtongWordResult {
  /// 单词文本
  final String word;

  /// 字符类型: 0=非标点, 1=标点
  final int charType;

  /// 单词得分详情
  final ShengtongWordScores scores;

  /// 单词在文本中的部分
  final List<ShengtongWordPart> wordParts;

  /// 发音字母组合
  final List<ShengtongPhonic>? phonics;

  /// 音素信息 (需开启 phoneme_output)
  final List<ShengtongPhoneme>? phonemes;

  /// 单词在音轨上的时间范围
  final ShengtongSpan? span;

  /// 停顿信息
  final ShengtongPause? pause;

  /// 朗读类型诊断: 0=正常, 3=漏读, 4=重复读 (需开启 readtype_diagnosis)
  final int? readType;

  /// 连读标准: 1=可连读, 0=非连读
  final int? linkable;

  /// 连读类型
  final int? linkableType;

  /// 实际连读情况: 1=已连读, 0=非连读
  final int? linked;

  const ShengtongWordResult({
    required this.word,
    required this.charType,
    required this.scores,
    this.wordParts = const [],
    this.phonics,
    this.phonemes,
    this.span,
    this.pause,
    this.readType,
    this.linkable,
    this.linkableType,
    this.linked,
  });

  factory ShengtongWordResult.fromJson(Map<String, dynamic> json) {
    return ShengtongWordResult(
      word: json['word'] as String? ?? '',
      charType: json['charType'] as int? ?? 0,
      scores: ShengtongWordScores.fromJson(json['scores'] as Map<String, dynamic>?),
      wordParts: (json['word_parts'] as List?)
              ?.map((p) => ShengtongWordPart.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      phonics: (json['phonics'] as List?)
              ?.map((p) => ShengtongPhonic.fromJson(p as Map<String, dynamic>))
              .toList(),
      phonemes: (json['phonemes'] as List?)
              ?.map((p) => ShengtongPhoneme.fromJson(p as Map<String, dynamic>))
              .toList(),
      span: json['span'] != null
          ? ShengtongSpan.fromJson(json['span'] as Map<String, dynamic>)
          : null,
      pause: json['pause'] != null
          ? ShengtongPause.fromJson(json['pause'] as Map<String, dynamic>)
          : null,
      readType: json['readType'] as int?,
      linkable: json['linkable'] as int?,
      linkableType: json['linkable_type'] as int?,
      linked: json['linked'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'charType': charType,
      'scores': scores.toJson(),
      'word_parts': wordParts.map((p) => p.toJson()).toList(),
      if (phonics != null) 'phonics': phonics!.map((p) => p.toJson()).toList(),
      if (phonemes != null) 'phonemes': phonemes!.map((p) => p.toJson()).toList(),
      if (span != null) 'span': span!.toJson(),
      if (pause != null) 'pause': pause!.toJson(),
      if (readType != null) 'readType': readType,
      if (linkable != null) 'linkable': linkable,
      if (linkableType != null) 'linkable_type': linkableType,
      if (linked != null) 'linked': linked,
    };
  }
}

/// 单词得分详情
class ShengtongWordScores {
  /// 单词总分
  final double overall;

  /// 单词发音得分
  final double pronunciation;

  /// 单词重读程度: 0=非重读, 1=重读
  final int? prominence;

  /// 重读音节信息 (需开启 sentence_need_word_stress)
  final List<ShengtongStress>? stress;

  const ShengtongWordScores({
    this.overall = 0.0,
    this.pronunciation = 0.0,
    this.prominence,
    this.stress,
  });

  factory ShengtongWordScores.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ShengtongWordScores();
    return ShengtongWordScores(
      overall: _toDouble(json['overall']) ?? 0.0,
      pronunciation: _toDouble(json['pronunciation']) ?? 0.0,
      prominence: json['prominence'] as int?,
      stress: (json['stress'] as List?)
              ?.map((s) => ShengtongStress.fromJson(s as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overall': overall,
      'pronunciation': pronunciation,
      if (prominence != null) 'prominence': prominence,
      if (stress != null) 'stress': stress!.map((s) => s.toJson()).toList(),
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// 单词文本部分
class ShengtongWordPart {
  final String part;
  final int charType;
  final int beginIndex;
  final int endIndex;

  const ShengtongWordPart({
    required this.part,
    required this.charType,
    required this.beginIndex,
    required this.endIndex,
  });

  factory ShengtongWordPart.fromJson(Map<String, dynamic> json) {
    return ShengtongWordPart(
      part: json['part'] as String? ?? '',
      charType: json['charType'] as int? ?? 0,
      beginIndex: json['beginIndex'] as int? ?? 0,
      endIndex: json['endIndex'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'part': part,
      'charType': charType,
      'beginIndex': beginIndex,
      'endIndex': endIndex,
    };
  }
}

/// 发音字母组合
class ShengtongPhonic {
  final String spell;
  final List<String> phoneme;
  final double overall;

  const ShengtongPhonic({
    required this.spell,
    required this.phoneme,
    required this.overall,
  });

  factory ShengtongPhonic.fromJson(Map<String, dynamic> json) {
    return ShengtongPhonic(
      spell: json['spell'] as String? ?? '',
      phoneme: (json['phoneme'] as List?)?.map((e) => e as String).toList() ?? [],
      overall: _toDouble(json['overall']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spell': spell,
      'phoneme': phoneme,
      'overall': overall,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// 音素信息
class ShengtongPhoneme {
  final String phoneme;
  final ShengtongSpan span;
  final double pronunciation;
  final int stressMark;

  const ShengtongPhoneme({
    required this.phoneme,
    required this.span,
    required this.pronunciation,
    required this.stressMark,
  });

  factory ShengtongPhoneme.fromJson(Map<String, dynamic> json) {
    return ShengtongPhoneme(
      phoneme: json['phoneme'] as String? ?? '',
      span: ShengtongSpan.fromJson(json['span'] as Map<String, dynamic>),
      pronunciation: _toDouble(json['pronunciation']) ?? 0.0,
      stressMark: json['stress_mark'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phoneme': phoneme,
      'span': span.toJson(),
      'pronunciation': pronunciation,
      'stress_mark': stressMark,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// 音素在音轨上的时间范围 (单位: 10毫秒)
class ShengtongSpan {
  final int start;
  final int end;

  const ShengtongSpan({required this.start, required this.end});

  factory ShengtongSpan.fromJson(Map<String, dynamic> json) {
    return ShengtongSpan(
      start: json['start'] as int? ?? 0,
      end: json['end'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'start': start, 'end': end};
  }
}

/// 停顿信息
class ShengtongPause {
  final int type;
  final int duration;

  const ShengtongPause({required this.type, required this.duration});

  factory ShengtongPause.fromJson(Map<String, dynamic> json) {
    return ShengtongPause(
      type: json['type'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type, 'duration': duration};
  }
}

/// 重读音节信息
class ShengtongStress {
  final String phonetic;
  final String spell;
  final int stress;
  final int refStress;
  final int phonemeOffset;
  final double overall;

  const ShengtongStress({
    required this.phonetic,
    required this.spell,
    required this.stress,
    required this.refStress,
    required this.phonemeOffset,
    required this.overall,
  });

  factory ShengtongStress.fromJson(Map<String, dynamic> json) {
    return ShengtongStress(
      phonetic: json['phonetic'] as String? ?? '',
      spell: json['spell'] as String? ?? '',
      stress: json['stress'] as int? ?? 0,
      refStress: json['ref_stress'] as int? ?? 0,
      phonemeOffset: json['phoneme_offset'] as int? ?? 0,
      overall: _toDouble(json['overall']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phonetic': phonetic,
      'spell': spell,
      'stress': stress,
      'ref_stress': refStress,
      'phoneme_offset': phonemeOffset,
      'overall': overall,
    };
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// 连读检测结果
class ShengtongLiaison {
  /// 第一个单词信息
  final ShengtongLiaisonWord firstWord;

  /// 第二个单词信息
  final ShengtongLiaisonWord secondWord;

  /// 连读类型
  final int linkableType;

  /// 第一个单词的最后一个音素
  final String firstPhoneme;

  /// 第二个单词的第一个音素
  final String secondPhoneme;

  const ShengtongLiaison({
    required this.firstWord,
    required this.secondWord,
    required this.linkableType,
    required this.firstPhoneme,
    required this.secondPhoneme,
  });

  factory ShengtongLiaison.fromJson(Map<String, dynamic> json) {
    return ShengtongLiaison(
      firstWord: ShengtongLiaisonWord.fromJson(json['first'] as Map<String, dynamic>),
      secondWord: ShengtongLiaisonWord.fromJson(json['second'] as Map<String, dynamic>),
      linkableType: json['linkable_type'] as int? ?? -1,
      firstPhoneme: json['first_phoneme'] as String? ?? '',
      secondPhoneme: json['second_phoneme'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first': firstWord.toJson(),
      'second': secondWord.toJson(),
      'linkable_type': linkableType,
      'first_phoneme': firstPhoneme,
      'second_phoneme': secondPhoneme,
    };
  }
}

/// 连读/爆破中的单词信息
class ShengtongLiaisonWord {
  final int index;
  final String word;

  const ShengtongLiaisonWord({required this.index, required this.word});

  factory ShengtongLiaisonWord.fromJson(Map<String, dynamic> json) {
    return ShengtongLiaisonWord(
      index: json['index'] as int? ?? 0,
      word: json['word'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'index': index, 'word': word};
  }
}

/// 不完全爆破检测结果
class ShengtongPlosion {
  final ShengtongLiaisonWord firstWord;
  final ShengtongLiaisonWord secondWord;
  final int linkableType;
  final String firstPhoneme;
  final String secondPhoneme;

  const ShengtongPlosion({
    required this.firstWord,
    required this.secondWord,
    required this.linkableType,
    required this.firstPhoneme,
    required this.secondPhoneme,
  });

  factory ShengtongPlosion.fromJson(Map<String, dynamic> json) {
    return ShengtongPlosion(
      firstWord: ShengtongLiaisonWord.fromJson(json['first'] as Map<String, dynamic>),
      secondWord: ShengtongLiaisonWord.fromJson(json['second'] as Map<String, dynamic>),
      linkableType: json['linkable_type'] as int? ?? -1,
      firstPhoneme: json['first_phoneme'] as String? ?? '',
      secondPhoneme: json['second_phoneme'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first': firstWord.toJson(),
      'second': secondWord.toJson(),
      'linkable_type': linkableType,
      'first_phoneme': firstPhoneme,
      'second_phoneme': secondPhoneme,
    };
  }
}

/// 音频检测警告信息
class ShengtongWarning {
  final int code;
  final String message;

  const ShengtongWarning({required this.code, required this.message});

  factory ShengtongWarning.fromJson(Map<String, dynamic> json) {
    return ShengtongWarning(
      code: json['code'] as int? ?? 0,
      message: json['message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'code': code, 'message': message};
  }
}

/// 声通完整响应消息
///
/// 包含 eval 消息的顶层字段。
class ShengtongEvalMessage {
  /// 时间戳
  final String? timestamp;

  /// 结果标识: 0=中间结果, 1=最终结果
  final int eof;

  /// 评分唯一ID
  final String? recordId;

  /// 评分结果 (最终结果时存在)
  final ShengtongSentenceResult? result;

  /// 错误ID (出错时存在, 此时无 result 字段)
  final int? errId;

  /// 错误信息
  final String? error;

  /// 请求参数
  final Map<String, dynamic>? params;

  /// 终端用户请求ID
  final String? tokenId;

  /// 评测文本
  final String? refText;

  /// 音频下载地址 (需设置 attachAudioUrl=1)
  final String? audioUrl;

  /// 评分结果返回时间
  final String? dtLastResponse;

  /// AppKey
  final String? applicationId;

  const ShengtongEvalMessage({
    this.timestamp,
    this.eof = 0,
    this.recordId,
    this.result,
    this.errId,
    this.error,
    this.params,
    this.tokenId,
    this.refText,
    this.audioUrl,
    this.dtLastResponse,
    this.applicationId,
  });

  factory ShengtongEvalMessage.fromJson(Map<String, dynamic> json) {
    return ShengtongEvalMessage(
      timestamp: json['timestamp'] as String?,
      eof: json['eof'] as int? ?? 0,
      recordId: json['recordId'] as String?,
      result: json['result'] != null
          ? ShengtongSentenceResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      errId: json['errId'] as int?,
      error: json['error'] as String?,
      params: json['params'] as Map<String, dynamic>?,
      tokenId: json['tokenId'] as String?,
      refText: json['refText'] as String?,
      audioUrl: json['audioUrl'] as String?,
      dtLastResponse: json['dtLastResponse'] as String?,
      applicationId: json['applicationId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (timestamp != null) 'timestamp': timestamp,
      'eof': eof,
      if (recordId != null) 'recordId': recordId,
      if (result != null) 'result': result!.toJson(),
      if (errId != null) 'errId': errId,
      if (error != null) 'error': error,
      if (params != null) 'params': params,
      if (tokenId != null) 'tokenId': tokenId,
      if (refText != null) 'refText': refText,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (dtLastResponse != null) 'dtLastResponse': dtLastResponse,
      if (applicationId != null) 'applicationId': applicationId,
    };
  }
}
