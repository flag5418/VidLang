import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// 声通语音评测 HTTP 服务
///
/// 基于声通 HTTP API 文档实现，使用 multipart/form-data 提交音频文件进行评测。
/// 参考文档：https://doc-api.stkouyu.com/docs/index?id=5
///
/// 评测类型说明：
/// - word.eval：英文单词/音标评测（最大录音 20s）
/// - word.eval.pro：英文单词自适应年龄段评测（最大录音 20s）
/// - sent.eval：英文句子评测（最大录音 90s）
/// - sent.eval.pro：英文句子自适应年龄段评测（最大录音 90s）
/// - para.eval：英文段落评测（最大录音 300s）
///
/// 使用示例：
/// ```dart
/// final evaluator = ShengtongHttpEvaluator(
///   appKey: 'your_app_key',
///   secretKey: 'your_secret_key',
/// );
///
/// final result = await evaluator.evaluate(
///   coreType: 'sent.eval',
///   refText: 'Hello world',
///   audioPath: '/path/to/audio.wav',
/// );
/// ```
class ShengtongHttpEvaluator {
  final String appKey;
  final String secretKey;
  final String baseUrl;
  final bool useSSL;

  ShengtongHttpEvaluator({
    required this.appKey,
    required this.secretKey,
    String? baseUrl,
    this.useSSL = false,
  }) : baseUrl =
           baseUrl ??
           (useSSL
               ? 'https://api.stkouyu.com:8443'
               : 'http://api.stkouyu.com:8080') {
    if (appKey.isEmpty) {
      throw ArgumentError('appKey 不能为空');
    }
    if (secretKey.isEmpty) {
      throw ArgumentError('secretKey 不能为空');
    }
  }

  /// 生成 connect sig
  /// 算法：appKey + timestamp + secretKey，SHA1 加密后 HEX 编码
  String _generateConnectSig(String timestamp) {
    final input = '$appKey$timestamp$secretKey';
    return sha1.convert(utf8.encode(input)).toString();
  }

  /// 生成 start sig
  /// 算法：appKey + timestamp + userId + secretKey，SHA1 加密后 HEX 编码
  String _generateStartSig(String timestamp, String userId) {
    final input = '$appKey$timestamp$userId$secretKey';
    return sha1.convert(utf8.encode(input)).toString();
  }

  /// 统一评测接口 — 根据文本长度自动选择评测类型
  ///
  /// 自动选择逻辑：
  /// - 文本长度 <= 1个单词（无空格）：使用 word.eval
  /// - 文本长度 <= 100字符（短句）：使用 sent.eval
  /// - 文本长度 > 100字符（段落）：使用 para.eval
  ///
  /// 如需更精确控制，建议直接调用 [evaluate] 方法指定 coreType
  ///
  /// 参数说明：
  /// [refText] 评测参考文本（单词/句子/段落）
  /// [audioPath] 音频文件路径
  /// [userId] 用户唯一标识，默认 'guest'
  /// [audioType] 音频格式：'wav'（默认）、'mp3'、'opus'、'm4a'
  /// [sampleRate] 采样率，默认 16000
  /// [agegroup] 年龄段（打分标准）：1=幼儿园(3-6岁), 2=小学(6-12岁), 3=初中及以上(>12岁)
  /// [slack] 打分松紧度，范围[-1, 1]，正数加分（更宽松），负数减分（更严格）
  /// [dictType] 返回音素类型：'CMU' / 'KK' / 'IPA88'（默认KK）
  /// [dictDialect] 发音限定：'en_br'（英式）、'en_us'（美式）
  /// [phonemeOutput] 是否返回音素维度：1开启（默认），0关闭
  /// [readtypeDiagnosis] 是否显示重复读/漏读：0关闭（默认），1开启
  /// [attachAudioUrl] 是否返回音频下载地址：0关闭（默认），1开启
  /// [getParam] 是否返回请求参数：1开启（默认），0关闭
  /// [blendPhoneme] 是否合并双元音/辅音：0关闭（默认），1开启
  /// [blendPhonics] 是否合并phonics：0关闭（默认），1开启
  /// [enableDigitByDigitRead] 是否允许数字拆分读：0关闭（默认），1开启
  /// [outputRawtext] 是否保留特殊符号：0关闭（默认），1开启
  /// [sentenceNeedWordStress] 是否显示单词重读音节：0关闭（默认），1开启
  /// [sentenceNeedEmotion] 是否返回情感得分：0关闭（默认），1开启
  /// [paragraphNeedWordScore] 是否返回单词维度：0关闭（默认），1开启
  /// [realtimeFeedback] 是否实时反馈中间结果：0关闭（默认），1开启
  /// [customizedLexicon] 自定义发音词典（CMU音素符号）
  /// [customizedPron] 自定义发音（KK/IPA88）
  ///
  /// 返回结果说明：
  /// 成功时返回 Map<String, dynamic>，包含：
  ///   - recordId：评分唯一ID
  ///   - overall：总分
  ///   - fluency：流利度（句子/段落）
  ///   - accuracy：准确度（单词）
  ///   - integrity：完整度（句子/段落）
  ///   - pronunciation：发音得分
  ///   - words：单词得分详情数组
  ///   - 更多字段参考声通文档
  /// 失败时抛出 Exception
  Future<Map<String, dynamic>> evaluateAuto({
    required String refText,
    required String audioPath,
    String userId = 'guest',
    String audioType = 'wav',
    int sampleRate = 16000,
    int? agegroup,
    double? slack,
    int? scale,
    double? precision,
    String? dictType,
    String? dictDialect,
    int? phonemeOutput,
    int? readtypeDiagnosis,
    int? attachAudioUrl,
    int? getParam,
    int? blendPhoneme,
    int? blendPhonics,
    int? enableDigitByDigitRead,
    int? outputRawtext,
    int? sentenceNeedWordStress,
    int? sentenceNeedEmotion,
    int? paragraphNeedWordScore,
    int? realtimeFeedback,
    Map<String, dynamic>? customizedLexicon,
    Map<String, dynamic>? customizedPron,
  }) async {
    // 自动选择评测类型
    final String coreType;
    final trimmedText = refText.trim();
    
    // 判断是否为单词（无空格且长度较短）
    if (!trimmedText.contains(' ') && trimmedText.length <= 50) {
      coreType = 'word.eval';
    } else if (trimmedText.length <= 100) {
      // 短句/句子（100字符以内）
      coreType = 'sent.eval';
    } else {
      // 长段落（100字符以上）
      coreType = 'para.eval';
    }

    debugPrint('🎤 [Shengtong-HTTP] 🧠 自动选择评测类型: $coreType (文本长度: ${trimmedText.length})');

    return evaluate(
      coreType: coreType,
      refText: refText,
      audioPath: audioPath,
      userId: userId,
      audioType: audioType,
      sampleRate: sampleRate,
      agegroup: agegroup,
      slack: slack,
      scale: scale,
      precision: precision,
      dictType: dictType,
      dictDialect: dictDialect,
      phonemeOutput: phonemeOutput,
      readtypeDiagnosis: readtypeDiagnosis,
      attachAudioUrl: attachAudioUrl,
      getParam: getParam,
      blendPhoneme: blendPhoneme,
      blendPhonics: blendPhonics,
      enableDigitByDigitRead: enableDigitByDigitRead,
      outputRawtext: outputRawtext,
      sentenceNeedWordStress: sentenceNeedWordStress,
      sentenceNeedEmotion: sentenceNeedEmotion,
      paragraphNeedWordScore: paragraphNeedWordScore,
      realtimeFeedback: realtimeFeedback,
      customizedLexicon: customizedLexicon,
      customizedPron: customizedPron,
    );
  }

  /// 评测音频
  ///
  /// 参数说明：
  /// [coreType] 评测内核类型：
  ///   - 'word.eval'：英文单词/音标评测（最大录音 20s）
  ///   - 'word.eval.pro'：英文单词自适应年龄段评测（最大录音 20s）
  ///   - 'sent.eval'：英文句子评测（最大录音 90s）
  ///   - 'sent.eval.pro'：英文句子自适应年龄段评测（最大录音 90s）
  ///   - 'para.eval'：英文段落评测（最大录音 300s）
  /// [refText] 评测参考文本（单词/句子/段落）
  /// [audioPath] 音频文件路径
  /// [userId] 用户唯一标识，默认 'guest'
  /// [audioType] 音频格式：'wav'（默认）、'mp3'、'opus'、'm4a'
  /// [sampleRate] 采样率，默认 16000
  ///
  /// 评测控制参数：
  /// [agegroup] 年龄段（打分标准）：
  ///   - 1：3-6岁（幼儿园）
  ///   - 2：6-12岁（小学）
  ///   - 3：>12岁（初中及以上，默认）
  ///   注：word.eval.pro / sent.eval.pro 时该参数无效（自动适配）
  /// [slack] 打分松紧度，范围[-1, 1]：
  ///   - 正数：加分（更宽松）
  ///   - 负数：减分（更严格）
  ///   - 0.1：加分幅度较小，1：加分幅度较大（默认0）
  /// [scale] 分制，取值范围(0, 100]，默认100分制
  /// [precision] 得分精度，取值范围(0, 1]，默认1（整数）
  ///   - 0.1：保留1位小数
  ///   - 0.01：保留2位小数
  ///
  /// 音频/发音参数：
  /// [dictType] 返回音素类型：'CMU' / 'KK' / 'IPA88'（默认KK）
  /// [dictDialect] 发音限定：'en_br'（英式）、'en_us'（美式），不设置则不限定
  /// [phonemeOutput] 是否返回音素维度：1开启（默认），0关闭
  /// [blendPhoneme] 是否合并双元音/辅音：0关闭（默认），1开启
  ///   - 合并：/ɪə/ /eə/ /ʊə/ /tr/ /ts/ /dr/ /dz/
  /// [blendPhonics] 是否合并phonics：0关闭（默认），1开启
  /// [enableDigitByDigitRead] 是否允许数字拆分读：0关闭（默认），1开启
  ///   - 示例：123 可按 1 2 3 读
  /// [outputRawtext] 是否保留特殊符号：0关闭（默认），1开启
  ///
  /// 句子评测专用参数（sent.eval / sent.eval.pro）：
  /// [readtypeDiagnosis] 是否显示重复读/漏读：0关闭（默认），1开启
  ///   - 开启后 result.words[].readType 标识朗读情况
  /// [sentenceNeedWordStress] 是否显示单词重读音节：0关闭（默认），1开启
  /// [sentenceNeedEmotion] 是否返回情感得分：0关闭（默认），1开启
  ///
  /// 段落评测专用参数（para.eval）：
  /// [paragraphNeedWordScore] 是否返回单词维度：0关闭（默认），1开启
  ///   - 开启后 result.sentences[].details 返回单词得分
  ///
  /// 通用功能参数：
  /// [attachAudioUrl] 是否返回音频下载地址：0关闭（默认），1开启
  ///   - 注：音频保留7天，建议下载到自己服务器
  /// [getParam] 是否返回请求参数：1开启（默认），0关闭
  /// [realtimeFeedback] 是否实时反馈中间结果：0关闭（默认），1开启
  ///
  /// 自定义发音参数：
  /// [customizedLexicon] 自定义发音词典（CMU音素符号）
  ///   示例：{"but": [["B", "AH", "T"], ["B", "UH", "T"]]}
  /// [customizedPron] 自定义发音（KK/IPA88）
  ///   示例：{"type": "KK", "pron": {"but": ["bət", "bʌt"]}}
  ///
  /// 返回结果说明：
  /// 成功时返回 Map<String, dynamic>，包含：
  ///   - recordId：评分唯一ID
  ///   - overall：总分
  ///   - fluency：流利度（句子/段落）
  ///   - accuracy：准确度（单词）
  ///   - integrity：完整度（句子/段落）
  ///   - pronunciation：发音得分
  ///   - words：单词得分详情数组
  ///   - 更多字段参考声通文档
  /// 失败时抛出 Exception
  Future<Map<String, dynamic>> evaluate({
    required String coreType,
    required String refText,
    required String audioPath,
    String userId = 'guest',
    String audioType = 'wav',
    int sampleRate = 16000,
    int? agegroup,
    double? slack,
    int? scale,
    double? precision,
    String? dictType,
    String? dictDialect,
    int? phonemeOutput,
    int? readtypeDiagnosis,
    int? attachAudioUrl,
    int? getParam,
    int? blendPhoneme,
    int? blendPhonics,
    int? enableDigitByDigitRead,
    int? outputRawtext,
    int? sentenceNeedWordStress,
    int? sentenceNeedEmotion,
    int? paragraphNeedWordScore,
    int? realtimeFeedback,
    Map<String, dynamic>? customizedLexicon,
    Map<String, dynamic>? customizedPron,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final connectSig = _generateConnectSig(timestamp);
    final startSig = _generateStartSig(timestamp, userId);

    // 构建 request 参数
    final requestParams = <String, dynamic>{
      'coreType': coreType,
      'refText': refText,
      'tokenId': userId,
    };

    // 添加可选参数（只添加非null的值，减少请求体大小）
    if (agegroup != null) requestParams['agegroup'] = agegroup; // 年龄段
    if (slack != null) requestParams['slack'] = slack; // 打分松紧度
    if (scale != null) requestParams['scale'] = scale; // 分制
    if (precision != null) requestParams['precision'] = precision; // 得分精度
    if (dictType != null) requestParams['dict_type'] = dictType; // 音素类型
    if (dictDialect != null) requestParams['dict_dialect'] = dictDialect; // 发音限定
    if (phonemeOutput != null) requestParams['phoneme_output'] = phonemeOutput; // 音素维度
    if (readtypeDiagnosis != null) requestParams['readtype_diagnosis'] = readtypeDiagnosis; // 重复读/漏读诊断
    if (attachAudioUrl != null) requestParams['attachAudioUrl'] = attachAudioUrl; // 音频下载地址
    if (getParam != null) requestParams['getParam'] = getParam; // 返回请求参数
    if (blendPhoneme != null) requestParams['blend_phoneme'] = blendPhoneme; // 合并双元音/辅音
    if (blendPhonics != null) requestParams['blend_phonics'] = blendPhonics; // 合并phonics
    if (enableDigitByDigitRead != null) requestParams['enable_digit_by_digit_read'] = enableDigitByDigitRead; // 数字拆分读
    if (outputRawtext != null) requestParams['output_rawtext'] = outputRawtext; // 保留特殊符号
    if (sentenceNeedWordStress != null) requestParams['sentence_need_word_stress'] = sentenceNeedWordStress; // 单词重读音节
    if (sentenceNeedEmotion != null) requestParams['sentence_need_emotion'] = sentenceNeedEmotion; // 情感得分
    if (paragraphNeedWordScore != null) requestParams['paragraph_need_word_score'] = paragraphNeedWordScore; // 单词维度
    if (realtimeFeedback != null) requestParams['realtime_feedback'] = realtimeFeedback; // 实时反馈
    if (customizedLexicon != null) requestParams['customized_lexicon'] = customizedLexicon; // 自定义发音词典
    if (customizedPron != null) requestParams['customized_pron'] = customizedPron; // 自定义发音

    // 构建 text 参数（JSON 格式）
    final params = {
      'connect': {
        'cmd': 'connect',
        'param': {
          'sdk': {
            'version': 16777472,
            'source': 4,
            'protocol': 1,
          },
          'app': {
            'applicationId': appKey,
            'sig': connectSig,
            'timestamp': timestamp,
          },
        },
      },
      'start': {
        'cmd': 'start',
        'param': {
          'app': {
            'userId': userId,
            'applicationId': appKey,
            'timestamp': timestamp,
            'sig': startSig,
          },
          'audio': {
            'audioType': audioType,
            'channel': 1,
            'sampleBytes': 2,
            'sampleRate': sampleRate,
          },
          'request': requestParams,
        },
      },
    };

    final textParam = jsonEncode(params);
    debugPrint('🎤 [Shengtong-HTTP] 📤 text 参数: $textParam');

    // 构建 multipart 请求
    final uri = Uri.parse('$baseUrl/$coreType');
    debugPrint('🎤 [Shengtong-HTTP] 🔗 请求地址: $uri');

    final request = http.MultipartRequest('POST', uri);

    // 设置 Header
    request.headers['Request-Index'] = '0';

    // 添加 text 字段
    request.fields['text'] = textParam;

    // 添加音频文件
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw FileSystemException('音频文件不存在', audioPath);
    }

    final audioBytes = await audioFile.readAsBytes();
    debugPrint('🎤 [Shengtong-HTTP] 📎 音频文件: ${audioFile.path}, 大小: ${audioBytes.length} bytes');

    request.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: 'audio',
        contentType: MediaType('application', 'octet-stream'),
      ),
    );

    // 发送请求
    debugPrint('🎤 [Shengtong-HTTP] ⏳ 发送请求...');
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('评测请求超时');
      },
    );

    final response = await http.Response.fromStream(streamedResponse);
    debugPrint('🎤 [Shengtong-HTTP] 📥 响应状态: ${response.statusCode}');
    debugPrint('🎤 [Shengtong-HTTP] 📥 响应体: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('评测失败: HTTP ${response.statusCode}');
    }

    // 解析响应
    try {
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      return result;
    } catch (e) {
      throw FormatException('响应解析失败: ${response.body}');
    }
  }

  /// 评测 Uint8List 音频数据（内存中直接评测，不依赖文件）
  ///
  /// 参数说明同 [evaluate] 方法，只是音频数据通过 [audioBytes] 传入
  Future<Map<String, dynamic>> evaluateBytes({
    required String coreType,
    required String refText,
    required Uint8List audioBytes,
    String userId = 'guest',
    String audioType = 'wav',
    int sampleRate = 16000,
    int? agegroup,
    double? slack,
    int? scale,
    double? precision,
    String? dictType,
    String? dictDialect,
    int? phonemeOutput,
    int? readtypeDiagnosis,
    int? attachAudioUrl,
    int? getParam,
    int? blendPhoneme,
    int? blendPhonics,
    int? enableDigitByDigitRead,
    int? outputRawtext,
    int? sentenceNeedWordStress,
    int? sentenceNeedEmotion,
    int? paragraphNeedWordScore,
    int? realtimeFeedback,
    Map<String, dynamic>? customizedLexicon,
    Map<String, dynamic>? customizedPron,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final connectSig = _generateConnectSig(timestamp);
    final startSig = _generateStartSig(timestamp, userId);

    // 构建 request 参数
    final requestParams = <String, dynamic>{
      'coreType': coreType,
      'refText': refText,
      'tokenId': userId,
    };

    // 添加可选参数
    if (agegroup != null) requestParams['agegroup'] = agegroup;
    if (slack != null) requestParams['slack'] = slack;
    if (scale != null) requestParams['scale'] = scale;
    if (precision != null) requestParams['precision'] = precision;
    if (dictType != null) requestParams['dict_type'] = dictType;
    if (dictDialect != null) requestParams['dict_dialect'] = dictDialect;
    if (phonemeOutput != null) requestParams['phoneme_output'] = phonemeOutput;
    if (readtypeDiagnosis != null) requestParams['readtype_diagnosis'] = readtypeDiagnosis;
    if (attachAudioUrl != null) requestParams['attachAudioUrl'] = attachAudioUrl;
    if (getParam != null) requestParams['getParam'] = getParam;
    if (blendPhoneme != null) requestParams['blend_phoneme'] = blendPhoneme;
    if (blendPhonics != null) requestParams['blend_phonics'] = blendPhonics;
    if (enableDigitByDigitRead != null) requestParams['enable_digit_by_digit_read'] = enableDigitByDigitRead;
    if (outputRawtext != null) requestParams['output_rawtext'] = outputRawtext;
    if (sentenceNeedWordStress != null) requestParams['sentence_need_word_stress'] = sentenceNeedWordStress;
    if (sentenceNeedEmotion != null) requestParams['sentence_need_emotion'] = sentenceNeedEmotion;
    if (paragraphNeedWordScore != null) requestParams['paragraph_need_word_score'] = paragraphNeedWordScore;
    if (realtimeFeedback != null) requestParams['realtime_feedback'] = realtimeFeedback;
    if (customizedLexicon != null) requestParams['customized_lexicon'] = customizedLexicon;
    if (customizedPron != null) requestParams['customized_pron'] = customizedPron;

    final params = {
      'connect': {
        'cmd': 'connect',
        'param': {
          'sdk': {
            'version': 16777472,
            'source': 4,
            'protocol': 1,
          },
          'app': {
            'applicationId': appKey,
            'sig': connectSig,
            'timestamp': timestamp,
          },
        },
      },
      'start': {
        'cmd': 'start',
        'param': {
          'app': {
            'userId': userId,
            'applicationId': appKey,
            'timestamp': timestamp,
            'sig': startSig,
          },
          'audio': {
            'audioType': audioType,
            'channel': 1,
            'sampleBytes': 2,
            'sampleRate': sampleRate,
          },
          'request': requestParams,
        },
      },
    };

    final textParam = jsonEncode(params);
    debugPrint('🎤 [Shengtong-HTTP] 📤 text 参数: $textParam');

    final uri = Uri.parse('$baseUrl/$coreType');
    debugPrint('🎤 [Shengtong-HTTP] 🔗 请求地址: $uri');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Request-Index'] = '0';
    request.fields['text'] = textParam;

    request.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: 'audio',
        contentType: MediaType('application', 'octet-stream'),
      ),
    );

    debugPrint('🎤 [Shengtong-HTTP] ⏳ 发送请求...');
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('评测请求超时');
      },
    );

    final response = await http.Response.fromStream(streamedResponse);
    debugPrint('🎤 [Shengtong-HTTP] 📥 响应状态: ${response.statusCode}');
    debugPrint('🎤 [Shengtong-HTTP] 📥 响应体: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('评测失败: HTTP ${response.statusCode}');
    }

    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('响应解析失败: ${response.body}');
    }
  }
}
