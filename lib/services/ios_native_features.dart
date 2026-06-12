import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 检查是否是 iOS 平台
bool _isIOS() => defaultTargetPlatform == TargetPlatform.iOS;

/// 检查是否是 macOS 平台
bool _isMacOS() => defaultTargetPlatform == TargetPlatform.macOS;

/// 检查是否是 Apple 平台（iOS 或 macOS）
bool _isApplePlatform() => _isIOS() || _isMacOS();

/// 当前是否已实现原生功能（iOS端代码已实现原生代码，其他平台返回false）
bool _nativeFeaturesImplemented() => _isIOS();

Object? _normalizePlatformValue(Object? value) {
  if (value is String) {
    final s = value.trim();
    if ((s.startsWith('{') && s.endsWith('}')) || (s.startsWith('[') && s.endsWith(']'))) {
      try {
        return _normalizePlatformValue(jsonDecode(s));
      } catch (_) {}
    }
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _normalizePlatformValue(v)));
  }
  if (value is List) {
    return value.map(_normalizePlatformValue).toList();
  }
  return value;
}

Map<String, dynamic> _asStringKeyMap(Object? value) {
  final normalized = _normalizePlatformValue(value);
  if (normalized is Map) {
    return Map<String, dynamic>.from(normalized);
  }
  throw ArgumentError.value(value, 'value', '期望 Map 类型的返回值');
}

class OcrResult {
  final String text;
  final List<OcrLine> lines;
  final bool success;
  final String? error;

  OcrResult({required this.text, required this.lines, required this.success, this.error});

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      text: json['text'] as String? ?? '',
      lines: (json['lines'] as List?)?.map((e) => OcrLine.fromJson(_asStringKeyMap(e))).toList() ?? [],
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

class OcrLine {
  final String text;
  final double confidence;
  final List<OcrWord> words;

  OcrLine({required this.text, required this.confidence, required this.words});

  factory OcrLine.fromJson(Map<String, dynamic> json) {
    return OcrLine(
      text: json['text'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      words: (json['words'] as List?)?.map((e) => OcrWord.fromJson(_asStringKeyMap(e))).toList() ?? [],
    );
  }
}

class OcrWord {
  final String text;
  final double confidence;

  OcrWord({required this.text, required this.confidence});

  factory OcrWord.fromJson(Map<String, dynamic> json) {
    return OcrWord(text: json['text'] as String? ?? '', confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0);
  }
}

/// 语音识别结果（跟读）
class SpeechRecognitionResult {
  final String text;
  final bool isFinal;
  final bool partial;
  final bool success;
  final String? error;

  const SpeechRecognitionResult({required this.text, required this.isFinal, required this.partial, required this.success, this.error});

  factory SpeechRecognitionResult.fromJson(Map<String, dynamic> json) {
    return SpeechRecognitionResult(
      text: json['text'] as String? ?? '',
      isFinal: json['isFinal'] as bool? ?? false,
      partial: json['partial'] as bool? ?? false,
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

class ImageAnalysisResult {
  final String description;
  final String chineseDescription;
  final List<String> labels;
  final List<String> chineseLabels;
  final bool success;
  final String? error;

  ImageAnalysisResult({
    required this.description,
    required this.chineseDescription,
    required this.labels,
    required this.chineseLabels,
    required this.success,
    this.error,
  });

  factory ImageAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ImageAnalysisResult(
      description: json['description'] as String? ?? '',
      chineseDescription: json['chineseDescription'] as String? ?? '',
      labels: (json['labels'] as List?)?.cast<String>() ?? [],
      chineseLabels: (json['chineseLabels'] as List?)?.cast<String>() ?? [],
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

class SubtitleFrame {
  final String text;
  final String language;
  final double startTime;
  final double endTime;
  final double confidence;

  SubtitleFrame({required this.text, required this.language, required this.startTime, required this.endTime, required this.confidence});

  factory SubtitleFrame.fromJson(Map<String, dynamic> json) {
    return SubtitleFrame(
      text: json['text'] as String? ?? '',
      language: json['language'] as String? ?? '',
      startTime: (json['startTime'] as num?)?.toDouble() ?? 0.0,
      endTime: (json['endTime'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SubtitleExtractionResult {
  final List<SubtitleFrame> frames;
  final String fullText;
  final bool success;
  final String? error;

  SubtitleExtractionResult({required this.frames, required this.fullText, required this.success, this.error});

  factory SubtitleExtractionResult.fromJson(Map<String, dynamic> json) {
    return SubtitleExtractionResult(
      frames: (json['frames'] as List?)?.map((e) => SubtitleFrame.fromJson(_asStringKeyMap(e))).toList() ?? [],
      fullText: json['fullText'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

class TranslationResult {
  final String sourceText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final bool success;
  final String? error;

  TranslationResult({
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.success,
    this.error,
  });

  factory TranslationResult.fromJson(Map<String, dynamic> json) {
    return TranslationResult(
      sourceText: json['sourceText'] as String? ?? '',
      translatedText: json['translatedText'] as String? ?? '',
      sourceLanguage: json['sourceLanguage'] as String? ?? '',
      targetLanguage: json['targetLanguage'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

/// 词典查询结果
class LookUpResult {
  final String word;
  final bool hasDefinition;
  final String definition;
  final bool success;
  final String? error;

  LookUpResult({required this.word, required this.hasDefinition, required this.definition, required this.success, this.error});

  factory LookUpResult.fromJson(Map<String, dynamic> json) {
    return LookUpResult(
      word: json['word'] as String? ?? '',
      hasDefinition: json['hasDefinition'] as bool? ?? false,
      definition: json['definition'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

/// 分词结果
class SegmentWordsResult {
  final List<String> words;
  final bool success;
  final String? error;

  SegmentWordsResult({required this.words, required this.success, this.error});

  factory SegmentWordsResult.fromJson(Map<String, dynamic> json) {
    return SegmentWordsResult(
      words: (json['words'] as List?)?.cast<String>() ?? [],
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }
}

class IosNativeFeatures {
  static const MethodChannel _channel = MethodChannel('com.yzh.vidlang/ios_features');

  /// 获取 iOS 设备类型（"pad" 或 "phone"）
  ///
  /// 仅 iOS 平台有效，其他平台返回 null。
  static Future<String?> getDeviceIdiom() async {
    if (!_nativeFeaturesImplemented()) return null;
    try {
      final result = await _channel.invokeMethod<String>('getDeviceIdiom');
      return result;
    } catch (_) {
      return null;
    }
  }

  /// 翻译文本（iOS 17.4+ 使用系统 NLTranslation，降级到简单翻译）
  static Future<TranslationResult> translate({required String text, String sourceLanguage = 'en', String targetLanguage = 'zh-Hans'}) async {
    if (!_nativeFeaturesImplemented()) {
      return TranslationResult(
        sourceText: text,
        translatedText: '',
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        success: false,
        error: '系统翻译功能尚未实现，请先完成iOS原生代码开发',
      );
    }
    try {
      final result = await _channel.invokeMethod('translate', {'text': text, 'sourceLanguage': sourceLanguage, 'targetLanguage': targetLanguage});
      if (result == null) {
        return TranslationResult(
          sourceText: text,
          translatedText: '',
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          success: false,
          error: '未获取到翻译结果',
        );
      }
      return TranslationResult.fromJson(_asStringKeyMap(result));
    } on PlatformException catch (e) {
      return TranslationResult(
        sourceText: text,
        translatedText: '',
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        success: false,
        error: e.message ?? '翻译失败',
      );
    } catch (e) {
      return TranslationResult(
        sourceText: text,
        translatedText: '',
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        success: false,
        error: '翻译异常: $e',
      );
    }
  }

  /// 查询单词词典定义（使用 iOS 系统词典 UIReferenceLibraryViewController）
  static Future<LookUpResult> lookUp({required String word}) async {
    if (!_nativeFeaturesImplemented()) {
      return LookUpResult(word: word, hasDefinition: false, definition: '', success: false, error: '词典功能仅在 iOS 上可用');
    }
    try {
      final result = await _channel.invokeMethod('lookUp', {'word': word});
      if (result == null) {
        return LookUpResult(word: word, hasDefinition: false, definition: '', success: false, error: '未获取到词典结果');
      }
      return LookUpResult.fromJson(_asStringKeyMap(result));
    } on PlatformException catch (e) {
      return LookUpResult(word: word, hasDefinition: false, definition: '', success: false, error: e.message ?? '词典查询失败');
    } catch (e) {
      return LookUpResult(word: word, hasDefinition: false, definition: '', success: false, error: '词典查询异常: $e');
    }
  }

  /// 使用 iOS NLTokenizer 进行英文分词
  /// 适用于单词粘连的文本（如 "Whoeatsachip" → ["Who", "eats", "a", "chip"]）
  static Future<SegmentWordsResult> segmentWords({required String text}) async {
    if (!_nativeFeaturesImplemented()) {
      return SegmentWordsResult(words: text.split(RegExp(r'\s+')), success: false, error: '分词功能仅在 iOS 上可用');
    }
    try {
      final result = await _channel.invokeMethod('segmentWords', {'text': text});
      if (result == null) {
        return SegmentWordsResult(words: text.split(RegExp(r'\s+')), success: false, error: '未获取到分词结果');
      }
      return SegmentWordsResult.fromJson(_asStringKeyMap(result));
    } on PlatformException catch (e) {
      return SegmentWordsResult(words: text.split(RegExp(r'\s+')), success: false, error: e.message ?? '分词失败');
    } catch (e) {
      return SegmentWordsResult(words: text.split(RegExp(r'\s+')), success: false, error: '分词异常: $e');
    }
  }

  static Future<bool> speak({required String text, String language = 'en-US', double rate = 0.5, double pitch = 1.0, double volume = 1.0}) async {
    if (!_nativeFeaturesImplemented()) return false;
    try {
      final result = await _channel.invokeMethod('speak', {'text': text, 'language': language, 'rate': rate, 'pitch': pitch, 'volume': volume});
      return result as bool? ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopSpeaking() async {
    if (!_nativeFeaturesImplemented()) return;
    try {
      await _channel.invokeMethod('stopSpeaking');
    } catch (_) {}
  }

  static Future<bool> isSpeaking() async {
    if (!_nativeFeaturesImplemented()) return false;
    try {
      final result = await _channel.invokeMethod('isSpeaking');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<OcrResult> extractTextFromImage({required String imagePath, bool recognizeMultipleLines = true}) async {
    if (!_nativeFeaturesImplemented()) {
      return OcrResult(text: '', lines: [], success: false, error: 'OCR功能尚未实现，请先完成iOS原生代码开发');
    }
    try {
      final result = await _channel.invokeMethod('extractTextFromImage', {'imagePath': imagePath, 'recognizeMultipleLines': recognizeMultipleLines});
      if (result == null) return OcrResult(text: '', lines: [], success: false, error: '未获取到识别结果');
      return OcrResult.fromJson(_asStringKeyMap(result));
    } on PlatformException catch (e) {
      return OcrResult(text: '', lines: [], success: false, error: e.message ?? '识别失败');
    } catch (e) {
      return OcrResult(text: '', lines: [], success: false, error: '识别异常: $e');
    }
  }

  static Future<OcrResult> extractTextFromCamera() async {
    if (!_nativeFeaturesImplemented()) {
      return OcrResult(text: '', lines: [], success: false, error: 'OCR功能尚未实现，请先完成iOS原生代码开发');
    }
    try {
      final result = await _channel.invokeMethod('extractTextFromCamera');
      if (result == null) return OcrResult(text: '', lines: [], success: false, error: '未获取到识别结果');
      return OcrResult.fromJson(_asStringKeyMap(result));
    } on PlatformException catch (e) {
      return OcrResult(text: '', lines: [], success: false, error: e.message ?? '识别失败');
    } catch (e) {
      return OcrResult(text: '', lines: [], success: false, error: '识别异常: $e');
    }
  }

  static Future<ImageAnalysisResult> analyzeImage({required String imagePath}) async {
    if (!_nativeFeaturesImplemented()) {
      return ImageAnalysisResult(
        description: '',
        chineseDescription: '',
        labels: [],
        chineseLabels: [],
        success: false,
        error: '图片分析功能尚未实现，请先完成iOS原生代码开发',
      );
    }
    try {
      final result = await _channel.invokeMethod('analyzeImage', {'imagePath': imagePath});
      if (result == null)
        return ImageAnalysisResult(description: '', chineseDescription: '', labels: [], chineseLabels: [], success: false, error: '未获取到分析结果');
      return ImageAnalysisResult.fromJson(_asStringKeyMap(result));
    } on PlatformException catch (e) {
      return ImageAnalysisResult(description: '', chineseDescription: '', labels: [], chineseLabels: [], success: false, error: e.message ?? '分析失败');
    } catch (e) {
      return ImageAnalysisResult(description: '', chineseDescription: '', labels: [], chineseLabels: [], success: false, error: '分析异常: $e');
    }
  }

  static Future<ImageAnalysisResult> analyzeImageFromCamera() async {
    if (!_nativeFeaturesImplemented()) {
      return ImageAnalysisResult(
        description: '',
        chineseDescription: '',
        labels: [],
        chineseLabels: [],
        success: false,
        error: '图片分析功能尚未实现，请先完成iOS原生代码开发',
      );
    }
    try {
      final result = await _channel.invokeMethod('analyzeImageFromCamera');
      if (result == null)
        return ImageAnalysisResult(description: '', chineseDescription: '', labels: [], chineseLabels: [], success: false, error: '未获取到分析结果');
      return ImageAnalysisResult.fromJson(_asStringKeyMap(result));
    } on PlatformException catch (e) {
      return ImageAnalysisResult(description: '', chineseDescription: '', labels: [], chineseLabels: [], success: false, error: e.message ?? '分析失败');
    } catch (e) {
      return ImageAnalysisResult(description: '', chineseDescription: '', labels: [], chineseLabels: [], success: false, error: '分析异常: $e');
    }
  }

  static Future<SubtitleExtractionResult> extractSubtitles({
    required String videoPath,
    int frameInterval = 1000,
    double confidenceThreshold = 0.8,
  }) async {
    if (!_nativeFeaturesImplemented()) {
      return SubtitleExtractionResult(frames: [], fullText: '', success: false, error: '字幕提取功能尚未实现，请先完成iOS原生代码开发');
    }
    try {
      final result = await _channel.invokeMethod('extractSubtitles', {
        'videoPath': videoPath,
        'frameInterval': frameInterval,
        'confidenceThreshold': confidenceThreshold,
      });
      if (result == null) return SubtitleExtractionResult(frames: [], fullText: '', success: false, error: '未获取到字幕结果');
      return SubtitleExtractionResult.fromJson(_asStringKeyMap(result));
    } on PlatformException catch (e) {
      return SubtitleExtractionResult(frames: [], fullText: '', success: false, error: e.message ?? '字幕提取失败');
    } catch (e) {
      return SubtitleExtractionResult(frames: [], fullText: '', success: false, error: '字幕提取异常: $e');
    }
  }

  static Future<List<String>> getAvailableLanguages() async {
    if (!_nativeFeaturesImplemented()) return [];
    try {
      final result = await _channel.invokeMethod('getAvailableLanguages');
      return (result as List?)?.cast<String>() ?? [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> hasCameraPermission() async {
    if (!_nativeFeaturesImplemented()) return false;
    try {
      final result = await _channel.invokeMethod('hasCameraPermission');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestCameraPermission() async {
    if (!_nativeFeaturesImplemented()) return false;
    try {
      final result = await _channel.invokeMethod('requestCameraPermission');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasPhotoLibraryPermission() async {
    if (!_nativeFeaturesImplemented()) return false;
    try {
      final result = await _channel.invokeMethod('hasPhotoLibraryPermission');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPhotoLibraryPermission() async {
    if (!_nativeFeaturesImplemented()) return false;
    try {
      final result = await _channel.invokeMethod('requestPhotoLibraryPermission');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  // ─────── 语音识别（跟读）───────

  /// 检查语音识别权限
  static Future<bool> hasSpeechPermission() async {
    if (!_nativeFeaturesImplemented()) return false;
    try {
      final result = await _channel.invokeMethod('hasSpeechPermission');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 请求语音识别权限
  static Future<bool> requestSpeechPermission() async {
    if (!_nativeFeaturesImplemented()) return false;
    try {
      final result = await _channel.invokeMethod('requestSpeechPermission');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 语音识别是否可用
  static Future<bool> isSpeechRecognitionAvailable() async {
    if (!_nativeFeaturesImplemented()) return false;
    try {
      final result = await _channel.invokeMethod('isSpeechRecognitionAvailable');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 开始语音识别（实时返回部分结果）
  /// 通过 Stream 持续通知 Flutter 端
  static final _speechController = StreamController<SpeechRecognitionResult>.broadcast();

  static Stream<SpeechRecognitionResult> get onSpeechResult => _speechController.stream;

  static Future<void> startSpeechRecognition() async {
    if (!_nativeFeaturesImplemented()) {
      _speechController.add(SpeechRecognitionResult(text: '', isFinal: false, partial: false, success: false, error: '语音识别仅在 iOS 上可用'));
      return;
    }
    try {
      final result = await _channel.invokeMethod('startSpeechRecognition');
      if (result == null) return;
      final map = _asStringKeyMap(result);
      final sr = SpeechRecognitionResult.fromJson(map);
      _speechController.add(sr);
      // 如果 result 里有 partial=true，持续监听后续回调
      // 但 SFSpeechRecognizer 是通过单次 result 返回的，partial 由 Native 端逐个发回
    } catch (e) {
      _speechController.add(SpeechRecognitionResult(text: '', isFinal: true, partial: false, success: false, error: '语音识别启动失败: $e'));
    }
  }

  /// 停止语音识别
  static Future<void> stopSpeechRecognition() async {
    if (!_nativeFeaturesImplemented()) return;
    try {
      await _channel.invokeMethod('stopSpeechRecognition');
    } catch (_) {}
  }
}
