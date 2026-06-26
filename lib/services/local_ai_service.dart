import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vidlang/services/local_llm_service.dart';
import 'package:vidlang/services/local_stt_service.dart';
import 'package:vidlang/services/local_tts_service.dart';
import 'package:vidlang/services/local_translation_service.dart';
import 'package:vidlang/services/local_model_service.dart';

/// 统一本地 AI 服务
/// 封装 LLM、TTS、STT、翻译服务，提供统一的接口
class LocalAiService {
  static LocalAiService? _instance;
  static LocalAiService get instance => _instance ??= LocalAiService._();
  LocalAiService._();

  final LocalLlmService _llm = LocalLlmService.instance;
  final LocalTtsService _tts = LocalTtsService.instance;
  final LocalSttService _stt = LocalSttService.instance;
  final LocalTranslationService _translation = LocalTranslationService.instance;
  final LocalModelService _modelService = LocalModelService.instance;

  bool _isInitialized = false;
  bool _isInitializing = false;

  // 初始化状态流
  final _initController = StreamController<bool>.broadcast();
  Stream<bool> get initStream => _initController.stream;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在初始化
  bool get isInitializing => _isInitializing;

  /// 所有模型是否就绪
  bool get allModelsReady => _modelService.canUseAiFeatures;

  /// 初始化所有本地 AI 服务
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    _initController.add(false);

    try {
      debugPrint('=== 初始化本地 AI 服务 ===');
      
      // 首先检查模型状态
      await _modelService.initialize();
      debugPrint('模型状态检查完成');
      debugPrint('hasAllModels: ${_modelService.hasAllModels}');
      debugPrint('canUseAiFeatures: ${_modelService.canUseAiFeatures}');
      
      // 串行初始化各服务（避免并行加载大模型导致内存崩溃）
      debugPrint('开始初始化 TTS、STT、翻译服务...');
      
      try {
        await _llm.initialize();
        debugPrint('LLM 初始化完成');
      } catch (e) {
        debugPrint('LLM 初始化跳过: $e');
      }
      
      try {
        await _tts.initialize();
        debugPrint('TTS 初始化完成: ${_tts.isInitialized}');
      } catch (e) {
        debugPrint('TTS 初始化失败: $e');
      }
      
      try {
        await _stt.initialize();
        debugPrint('STT 初始化完成: ${_stt.isInitialized}');
      } catch (e) {
        debugPrint('STT 初始化失败: $e');
      }
      
      try {
        await _translation.initialize();
        debugPrint('翻译初始化完成: ${_translation.isInitialized}');
      } catch (e) {
        debugPrint('翻译初始化失败: $e');
      }

      _isInitialized = true;
      _initController.add(true);
      debugPrint('所有本地 AI 服务初始化成功');
    } catch (e) {
      debugPrint('初始化本地 AI 服务失败: $e');
      _isInitialized = false;
      _initController.add(false);
    } finally {
      _isInitializing = false;
    }
  }

  /// 翻译文本（英→中）
  Future<String> translate({
    required String text,
  }) async {
    // 优先使用本地翻译
    if (_translation.isInitialized) {
      return _translation.translate(
        text: text,
      );
    }

    return '本地翻译模型未就绪，请使用云端翻译';
  }

  /// 获取单词释义
  Future<String> getDefinition({
    required String word,
    String? contextSentence,
  }) async {
    if (!_llm.isAvailable) {
      return '本地 LLM 未集成，请使用云端释义';
    }

    return '';
  }

  /// 生成测验题目
  Future<String> generateQuiz({
    required List<String> words,
    int questionCount = 5,
  }) async {
    if (!_llm.isAvailable) {
      return '本地 LLM 未集成，请使用云端出题';
    }

    return '';
  }

  /// 对话
  Future<String> chat({
    required String message,
    List<Map<String, String>>? history,
  }) async {
    if (!_llm.isAvailable) {
      return '本地 LLM 未集成，请使用云端对话';
    }

    return '';
  }

  /// TTS 合成语音并保存为文件
  Future<String?> synthesizeToFile({
    required String text,
    String outputPath = '',
  }) async {
    if (!_isInitialized || !_modelService.canUseAiFeatures) {
      debugPrint('TTS 模型未就绪');
      return null;
    }

    return _tts.synthesizeToFile(
      text: text,
      outputPath: outputPath,
    );
  }

  /// STT 识别音频文件
  Future<String> recognizeFromFile({
    required String filePath,
    String language = 'en',
  }) async {
    if (!_isInitialized || !_modelService.canUseAiFeatures) {
      return 'STT 模型未就绪，请先下载模型';
    }

    return _stt.recognizeFromFile(
      filePath: filePath,
      language: language,
    );
  }

  /// 检查是否可以使用特定功能
  bool canUseFeature(LocalAiFeature feature) {
    if (!_modelService.canUseAiFeatures) return false;

    switch (feature) {
      case LocalAiFeature.llm:
        return _llm.isInitialized;
      case LocalAiFeature.tts:
        return _tts.isInitialized;
      case LocalAiFeature.stt:
        return _stt.isInitialized;
    }
  }

  /// 获取功能状态
  LocalAiFeatureStatus getFeatureStatus(LocalAiFeature feature) {
    if (!_modelService.canUseAiFeatures) {
      return LocalAiFeatureStatus.modelNotReady;
    }

    switch (feature) {
      case LocalAiFeature.llm:
        if (_llm.isLoading) return LocalAiFeatureStatus.loading;
        if (_llm.isInitialized) return LocalAiFeatureStatus.ready;
        return LocalAiFeatureStatus.error;
      case LocalAiFeature.tts:
        if (_tts.isLoading) return LocalAiFeatureStatus.loading;
        if (_tts.isInitialized) return LocalAiFeatureStatus.ready;
        return LocalAiFeatureStatus.error;
      case LocalAiFeature.stt:
        if (_stt.isLoading) return LocalAiFeatureStatus.loading;
        if (_stt.isInitialized) return LocalAiFeatureStatus.ready;
        return LocalAiFeatureStatus.error;
    }
  }

  /// 重置所有服务
  Future<void> reset() async {
    _isInitialized = false;
    _tts.dispose();
    _stt.dispose();
    await _modelService.reset();
  }

  /// 释放资源
  void dispose() {
    _tts.dispose();
    _stt.dispose();
    _translation.dispose();
    _initController.close();
  }
}

/// 本地 AI 功能类型
enum LocalAiFeature {
  llm,    // 大语言模型
  tts,    // 语音合成
  stt,    // 语音识别
}

/// 本地 AI 功能状态
enum LocalAiFeatureStatus {
  unknown,           // 未知
  loading,           // 加载中
  ready,             // 就绪
  error,             // 错误
  modelNotReady,     // 模型未就绪
}

/// 功能状态扩展
extension LocalAiFeatureStatusExtension on LocalAiFeatureStatus {
  String get displayName {
    switch (this) {
      case LocalAiFeatureStatus.unknown:
        return '检查中...';
      case LocalAiFeatureStatus.loading:
        return '加载中...';
      case LocalAiFeatureStatus.ready:
        return '就绪';
      case LocalAiFeatureStatus.error:
        return '错误';
      case LocalAiFeatureStatus.modelNotReady:
        return '模型未就绪';
    }
  }

  bool get canUse => this == LocalAiFeatureStatus.ready;
}
