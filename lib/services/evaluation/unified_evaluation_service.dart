import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vidlang/models/evaluation_models.dart';
import 'package:vidlang/providers/subscription_provider.dart';
// import 'package:vidlang/services/evaluation/shengtong_evaluator.dart'; // WebSocket 评测器（暂未使用）
import 'package:vidlang/services/evaluation/shengtong_http_evaluator.dart';
import 'package:vidlang/services/native/ios_native_features.dart';

/// 统一评测服务
///
/// 对标 UnifiedTtsService / UnifiedTranslationService，
/// 提供统一的评测入口，根据 SubscriptionMode 自动分流：
/// - Free (iOS): 使用原生 STT（Speech Framework），返回基础识别结果
/// - Premium: 使用声通评测引擎，返回详细评分结果
///
/// 使用示例：
/// ```dart
/// final result = await UnifiedEvaluationService.instance.evaluate(
///   refText: 'Hello world',
///   mode: subscriptionMode,
///   audioBytes: recordedAudio,
/// );
///
/// if (result.isSuccess) {
///   showScore(result.overallScore);
///   if (result.hasDetail) {
///     showDetailPanel(result.detail!);
///   }
/// }
/// ```
class UnifiedEvaluationService {
  static final UnifiedEvaluationService _instance = UnifiedEvaluationService._internal();
  static UnifiedEvaluationService get instance => _instance;
  UnifiedEvaluationService._internal();

  /// 声通 HTTP 评测器（懒加载）
  ShengtongHttpEvaluator? _httpEvaluator;

  /// 获取或创建声通 HTTP 评测器
  Future<ShengtongHttpEvaluator?> _getHttpEvaluator() async {
    if (_httpEvaluator != null) return _httpEvaluator;
    
    // TODO: 从 AppKeysService 加载声通配置
    // final appKey = AppKeysService.instance.shengtongAppKey;
    // final secretKey = AppKeysService.instance.shengtongSecretKey;
    // if (appKey == null || secretKey == null) return null;
    
    // _httpEvaluator = ShengtongHttpEvaluator(
    //   appKey: appKey,
    //   secretKey: secretKey,
    // );
    
    return _httpEvaluator;
  }

  /// 执行评测（统一入口）
  ///
  /// [refText] 参考文本（用户应该朗读的内容）
  /// [mode] 订阅模式（决定使用哪种评测引擎）
  /// [audioBytes] 音频数据（内存中的 PCM/WAV 数据）
  /// [audioPath] 音频文件路径（可选，优先级低于 audioBytes）
  ///
  /// 返回统一的 UnifiedEvaluationResult，前端根据 hasDetail 决定 UI 展示深度
  Future<UnifiedEvaluationResult> evaluate({
    required String refText,
    required SubscriptionMode mode,
    Uint8List? audioBytes,
    String? audioPath,
  }) async {
    if (refText.trim().isEmpty) {
      return UnifiedEvaluationResult.error('参考文本不能为空', code: 'EMPTY_TEXT');
    }

    switch (mode) {
      case SubscriptionMode.free:
        return await _evaluateFree(refText: refText, audioBytes: audioBytes, audioPath: audioPath);
      
      case SubscriptionMode.premium:
        return await _evaluatePremium(refText: refText, audioBytes: audioBytes, audioPath: audioPath);
    }
  }

  /// Free 模式：使用原生 STT（iOS Speech Framework）
  ///
  /// 功能限制：
  /// - 只能进行语音识别，无法给出详细评分
  /// - 返回识别文本和基于文本匹配的相似度分数
  /// - 无法提供单词级、音素级的评分详情
  ///
  /// 注意：原生 STT 是实时流式的，需要先调用 startSpeechRecognition() 开始录音，
  /// 然后通过 onSpeechResult Stream 获取识别结果。
  /// 此方法适用于已有音频文件/数据需要离线识别的场景，
  /// 如果是实时跟读场景，应该直接使用 IosNativeFeatures.startSpeechRecognition()。
  Future<UnifiedEvaluationResult> _evaluateFree({
    required String refText,
    Uint8List? audioBytes,
    String? audioPath,
  }) async {
    try {
      // 检查平台支持性
      final isAvailable = await IosNativeFeatures.isSpeechRecognitionAvailable();
      if (!isAvailable) {
        return UnifiedEvaluationResult.error(
          '当前设备不支持免费模式评测，请升级到 Premium 模式',
          code: 'NOT_SUPPORTED',
        );
      }

      // Free 模式下，原生 STT 主要用于**实时跟读**场景
      // 对于离线音频文件的识别，当前原生功能暂不支持
      // 这里返回一个提示性的结果，引导用户使用实时跟读功能
      
      if (audioBytes != null || audioPath != null) {
        // 离线音频：Free 模式暂不支持离线评测
        return UnifiedEvaluationResult.error(
          '免费模式仅支持实时跟读评测，请使用麦克风进行跟读',
          code: 'REALTIME_ONLY',
        );
      }

      // 实时模式：返回提示，让前端调用 IosNativeFeatures.startSpeechRecognition()
      return UnifiedEvaluationResult.error(
        'FREE_MODE_REALTIME', 
        code: 'USE_NATIVE_STT_STREAM',
      );
    } catch (e, stack) {
      debugPrint('❌ [UnifiedEvaluation] Free 模式评测失败: $e');
      debugPrint(stack.toString());
      return UnifiedEvaluationResult.error(
        '评测失败: ${e.toString()}',
        code: 'EVALUATION_ERROR',
      );
    }
  }

  /// 处理原生 STT 实时识别结果（Free 模式专用）
  ///
  /// 将原生 STT 的识别结果转换为统一的评测结果
  /// 前端在监听到 onSpeechResult 的最终结果后调用此方法
  static UnifiedEvaluationResult processNativeSttResult({
    required String refText,
    required SpeechRecognitionResult sttResult,
  }) {
    if (!sttResult.success || sttResult.text.trim().isEmpty) {
      return UnifiedEvaluationResult.error(
        sttResult.error ?? '语音识别失败',
        code: 'STT_ERROR',
      );
    }

    final recognizedText = sttResult.text.trim();
    
    // 计算文本相似度作为基础评分
    final similarityScore = _calculateTextSimilarityStatic(refText, recognizedText);

    return UnifiedEvaluationResult.success(
      referenceText: refText,
      recognizedText: recognizedText,
      overallScore: similarityScore,
      isPremium: false,
    );
  }

  /// 静态版本的文本相似度计算（用于静态方法中）
  static double _calculateTextSimilarityStatic(String source, String target) {
    if (source.isEmpty && target.isEmpty) return 100.0;
    if (source.isEmpty || target.isEmpty) return 0.0;

    final sourceLower = source.toLowerCase().trim();
    final targetLower = target.toLowerCase().trim();

    final sourceWords = sourceLower.split(RegExp(r'\s+'));
    final targetWords = targetLower.split(RegExp(r'\s+'));

    if (sourceWords.isEmpty || targetWords.isEmpty) return 0.0;

    int matchCount = 0;
    for (final sw in sourceWords) {
      if (targetWords.any((tw) => tw.contains(sw) || sw.contains(tw))) {
        matchCount++;
      }
    }

    final similarity = matchCount / sourceWords.length;
    return (similarity * 100).clamp(0.0, 100.0);
  }

  /// Premium 模式：使用声通评测引擎
  ///
  /// 提供详细的评分结果：
  /// - 总分、流利度、准确度、完整度
  /// - 单词级评分详情
  /// - 音素级评分（如果开启）
  Future<UnifiedEvaluationResult> _evaluatePremium({
    required String refText,
    Uint8List? audioBytes,
    String? audioPath,
  }) async {
    try {
      final evaluator = await _getHttpEvaluator();
      
      if (evaluator == null) {
        return UnifiedEvaluationResult.error(
          '声通服务未配置，请联系管理员',
          code: 'SERVICE_NOT_CONFIGURED',
        );
      }

      // 根据输入类型选择调用方式
      Map<String, dynamic> shengtongResult;
      
      if (audioBytes != null) {
        // 使用内存中的音频数据（调用 evaluateBytes）
        shengtongResult = await evaluator.evaluateBytes(
          coreType: 'sent.eval',  // 自动选择：句子评测
          refText: refText,
          audioBytes: audioBytes,
        );
      } else if (audioPath != null) {
        final path = audioPath;
        if (File(path).existsSync()) {
          // 使用音频文件路径（调用 evaluateAuto）
          shengtongResult = await evaluator.evaluateAuto(
            refText: refText,
            audioPath: path,
          );
        } else {
          return UnifiedEvaluationResult.error(
            '音频文件不存在: $path',
            code: 'FILE_NOT_FOUND',
          );
        }
      } else {
        return UnifiedEvaluationResult.error(
          '请提供音频数据或文件路径',
          code: 'NO_AUDIO_INPUT',
        );
      }

      // 解析声通结果为统一格式
      return _parseShengtongResult(shengtongResult, refText);
    } catch (e, stack) {
      debugPrint('❌ [UnifiedEvaluation] Premium 模式评测失败: $e');
      debugPrint(stack.toString());
      return UnifiedEvaluationResult.error(
        '评测失败: ${e.toString()}',
        code: 'EVALUATION_ERROR',
      );
    }
  }

  /// 解析声通原始结果为统一的 UnifiedEvaluationResult
  UnifiedEvaluationResult _parseShengtongResult(
    Map<String, dynamic> shengtongResult,
    String refText,
  ) {
    try {
      final result = shengtongResult['result'] as Map<String, dynamic>? ?? shengtongResult;
      
      final overall = (result['overall'] as num?)?.toDouble() ?? 0.0;
      final fluency = (result['fluency'] as num?)?.toDouble();
      final accuracy = (result['accuracy'] as num?)?.toDouble();
      final integrity = (result['integrity'] as num?)?.toDouble();
      final pronunciation = (result['pronunciation'] as num?)?.toDouble();
      
      // 解析单词级评分
      final wordsJson = result['words'] as List<dynamic>?;
      final wordEvaluations = wordsJson?.map((w) {
        final wordMap = w as Map<String, dynamic>;
        return WordEvaluation(
          word: wordMap['word'] as String? ?? '',
          score: (wordMap['score'] as num?)?.toDouble() ?? 0.0,
          isCorrect: (wordMap['is_correct'] as bool?) ?? ((wordMap['score'] as num?)?.toDouble() ?? 0.0) >= 60,
          phonemeBreakdown: wordMap['phoneme_breakdown'] as String?,
          suggestion: wordMap['suggestion'] as String?,
        );
      }).toList() ?? [];

      // 识别文本（用户实际朗读的内容）
      final recognizedText = result['recognized_text'] as String? ??
                           result['refText'] as String? ?? 
                           refText;

      return UnifiedEvaluationResult.success(
        referenceText: refText,
        recognizedText: recognizedText,
        overallScore: overall,
        isPremium: true,
        detail: EvaluationDetail(
          fluency: fluency,
          accuracy: accuracy,
          completeness: integrity,
          pronunciation: pronunciation,
          wordEvaluations: wordEvaluations,
          rawResult: shengtongResult,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [UnifiedEvaluation] 解析声通结果失败: $e');
      // 解析失败时返回基础信息
      return UnifiedEvaluationResult.success(
        referenceText: refText,
        recognizedText: refText,
        overallScore: 0.0,
        isPremium: true,
      );
    }
  }

  /// 计算文本相似度（用于 Free 模式的基础评分）
  ///
  /// 基于单词匹配率算法计算两个字符串的相似度，返回 0-100 的分数
  /// 注意：此方法当前未使用，保留供未来离线评测场景使用
  /// @deprecated 使用 [_calculateTextSimilarityStatic] 替代
  // ignore: unused_element
  double _calculateTextSimilarity(String source, String target) {
    if (source.isEmpty && target.isEmpty) return 100.0;
    if (source.isEmpty || target.isEmpty) return 0.0;

    final sourceLower = source.toLowerCase().trim();
    final targetLower = target.toLowerCase().trim();

    // 简单实现：基于单词匹配率
    final sourceWords = sourceLower.split(RegExp(r'\s+'));
    final targetWords = targetLower.split(RegExp(r'\s+'));

    if (sourceWords.isEmpty || targetWords.isEmpty) return 0.0;

    int matchCount = 0;
    for (final sw in sourceWords) {
      if (targetWords.any((tw) => tw.contains(sw) || sw.contains(tw))) {
        matchCount++;
      }
    }

    final similarity = matchCount / sourceWords.length;
    return (similarity * 100).clamp(0.0, 100.0);
  }

  /// 释放资源
  void dispose() {
    _httpEvaluator = null;
  }
}

/// 统一评测结果
///
/// 前端只需要关心这个类，不关心底层是原生 STT 还是声通评测。
/// 通过 isSuccess 判断是否成功，通过 hasDetail 判断是否有详细评分。
class UnifiedEvaluationResult {
  final bool success;
  final String? error;
  final String? code;

  /// 参考文本（用户应该朗读的内容）
  final String referenceText;

  /// 识别文本（用户实际朗读的内容，STT 结果）
  final String recognizedText;

  /// 总分 (0-100)
  final double overallScore;

  /// 是否为 Premium 模式的结果
  final bool isPremium;

  /// 详细评分（仅 Premium 模式有值，Free 模式为 null）
  final EvaluationDetail? detail;

  /// 评级标签
  String get gradeLabel {
    if (overallScore >= 90) return '优秀';
    if (overallScore >= 80) return '良好';
    if (overallScore >= 70) return '一般';
    if (overallScore >= 60) return '较差';
    return '需改进';
  }

  /// 是否有详细评分（Premium 模式专属）
  bool get hasDetail => detail != null;

  const UnifiedEvaluationResult._({
    required this.success,
    this.error,
    this.code,
    required this.referenceText,
    required this.recognizedText,
    required this.overallScore,
    required this.isPremium,
    this.detail,
  });

  /// 成功结果工厂方法
  factory UnifiedEvaluationResult.success({
    required String referenceText,
    required String recognizedText,
    required double overallScore,
    required bool isPremium,
    EvaluationDetail? detail,
  }) {
    return UnifiedEvaluationResult._(
      success: true,
      referenceText: referenceText,
      recognizedText: recognizedText,
      overallScore: overallScore,
      isPremium: isPremium,
      detail: detail,
    );
  }

  /// 错误结果工厂方法
  factory UnifiedEvaluationResult.error(String error, {String? code}) {
    return UnifiedEvaluationResult._(
      success: false,
      error: error,
      code: code,
      referenceText: '',
      recognizedText: '',
      overallScore: 0.0,
      isPremium: false,
    );
  }
}

/// 详细评分（Premium 模式专属）
///
/// 包含声通评测的多维度评分数据。
/// Free 模式下此对象为 null，前端需要判断 hasDetail 再展示。
class EvaluationDetail {
  /// 流利度 (0-100) - 节奏、流畅度
  final double? fluency;

  /// 准确度 (0-100) - 音素级匹配
  final double? accuracy;

  /// 完整度 (0-100) - 漏读/多读检测
  final double? completeness;

  /// 发音得分 (0-100)
  final double? pronunciation;

  /// 单词级评分列表
  final List<WordEvaluation> wordEvaluations;

  /// 原始评测结果（保留用于调试或高级功能）
  final Map<String, dynamic>? rawResult;

  const EvaluationDetail({
    this.fluency,
    this.accuracy,
    this.completeness,
    this.pronunciation,
    this.wordEvaluations = const [],
    this.rawResult,
  });

  /// 是否有单词级评分
  bool get hasWordEvaluations => wordEvaluations.isNotEmpty;

  /// 获取需要重点练习的单词（分数 < 70）
  List<WordEvaluation> get weakWords =>
      wordEvaluations.where((w) => w.score < 70).toList();

  /// 获取表现优秀的单词（分数 >= 90)
  List<WordEvaluation> get excellentWords =>
      wordEvaluations.where((w) => w.score >= 90).toList();
}
