// ignore_for_file: unused_field
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/evaluation_models.dart';

/// 评测服务异常类
class EvaluationException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  const EvaluationException(this.message, {this.code, this.originalError});
  
  @override
  String toString() => 'EvaluationException: $message';
}

/// 评测服务状态枚举
enum EvaluationState {
  idle,
  recording,
  processing,
  completed,
  error,
}

/// 评测服务类 - 管理所有评测相关逻辑
class EvaluationService {
  static final EvaluationService _instance = EvaluationService._internal();
  factory EvaluationService() => _instance;
  EvaluationService._internal();

  // 内部状态
  bool _isRecording = false;
  EvaluationState _currentState = EvaluationState.idle;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  String? _lastError;

  // 当前评测结果
  EvaluationResult? _currentResult;

  // 状态变更流
  final StreamController<EvaluationResult> _resultController = 
      StreamController<EvaluationResult>.broadcast();
  
  final StreamController<EvaluationState> _stateController = 
      StreamController<EvaluationState>.broadcast();
  
  final StreamController<String?> _errorController = 
      StreamController<String?>.broadcast();

  // 公开流
  Stream<EvaluationResult> get resultStream => _resultController.stream;
  Stream<EvaluationState> get stateStream => _stateController.stream;
  Stream<String?> get errorStream => _errorController.stream;
  
  // 公开属性
  EvaluationState get currentState => _currentState;
  String? get lastError => _lastError;
  bool get isProcessing => _currentState == EvaluationState.processing;

  /// 开始录音
  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _setState(EvaluationState.recording);

      // TODO: 调用原生录音接口
      // 这里应该是调用MethodChannel与原生代码通信
      // await _channel.invokeMethod('startRecording');
      
      debugPrint('开始录音');
    } catch (e) {
      _isRecording = false;
      debugPrint('录音启动失败: $e');
      rethrow;
    }
  }

  /// 停止录音
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      _isRecording = false;
      _setState(EvaluationState.idle);

      // TODO: 调用原生停止录音接口
      // final result = await _channel.invokeMethod('stopRecording');
      // _currentRecordingPath = result['path'];
      
      debugPrint('停止录音');
      return _currentRecordingPath;
    } catch (e) {
      debugPrint('录音停止失败: $e');
      rethrow;
    }
  }

  /// 播放录音
  Future<void> playRecording() async {
    if (_currentRecordingPath == null) return;

    try {
      // TODO: 调用原生播放接口
      // await _channel.invokeMethod('playRecording', {'path': _currentRecordingPath});
      debugPrint('播放录音: $_currentRecordingPath');
    } catch (e) {
      debugPrint('播放录音失败: $e');
      rethrow;
    }
  }

  /// 执行评测
  Future<EvaluationResult> evaluateRecording({
    required String referenceText,
    required EvaluationMode mode,
    String? audioPath,
  }) async {
    if (referenceText.trim().isEmpty) {
      throw const EvaluationException(
        '评测文本不能为空',
        code: 'EMPTY_TEXT',
      );
    }

    _setState(EvaluationState.processing);

    try {
      // 输入验证
      _validateEvaluationInput(referenceText, mode, audioPath);

      // 模拟评测过程 - 实际应该调用声通或其他评测API
      await Future.delayed(const Duration(seconds: 2));

      // 生成评测结果
      final result = _generateMockEvaluation(
        referenceText: referenceText,
        mode: mode,
        audioPath: audioPath,
      );

      // 验证生成结果
      if (result.wordEvaluations.isEmpty && mode != EvaluationMode.freeSTT) {
        throw const EvaluationException(
          '未能生成有效的评测结果',
          code: 'NO_RESULT',
        );
      }

      _currentResult = result;
      _resultController.add(result);
      _setState(EvaluationState.completed);

      // 保存评测记录
      await _saveEvaluationRecord(result);

      return result;
    } on EvaluationException {
      // 重新抛出自定义异常
      _setState(EvaluationState.error);
      rethrow;
    } catch (e) {
      final errorMessage = '评测失败: $e';
      _setError(errorMessage, code: 'EVALUATION_ERROR');
      throw EvaluationException(
        '语音评测服务暂时不可用，请稍后重试',
        code: 'SERVICE_UNAVAILABLE',
        originalError: e,
      );
    }
  }

  /// 保存录音文件
  Future<void> saveRecording(EvaluationResult result) async {
    try {
      // TODO: 保存录音文件到永久存储
      // 同时保存评测结果到数据库
      debugPrint('保存录音和评测结果');
      
      // 数据库操作
      // await DatabaseService.instance.saveEvaluationRecord(result);
    } catch (e) {
      debugPrint('保存录音失败: $e');
      rethrow;
    }
  }

  /// 获取历史评测记录
  Future<List<EvaluationResult>> getEvaluationHistory({
    int limit = 50,
    EvaluationMode? mode,
  }) async {
    try {
      // TODO: 从数据库查询历史记录
      // final records = await DatabaseService.instance.getEvaluationRecords(
      //   limit: limit,
      //   mode: mode,
      // );
      
      // 模拟数据
      return [];
    } catch (e) {
      debugPrint('获取历史记录失败: $e');
      return [];
    }
  }

  /// 获取评测统计信息
  Future<EvaluationStats> getEvaluationStats() async {
    try {
      // TODO: 从数据库计算统计数据
      // final stats = await DatabaseService.instance.getEvaluationStats();
      
      // 模拟数据
      return EvaluationStats(
        totalEvaluations: 15,
        averageScore: 82.5,
        averageFluency: 78.2,
        averageAccuracy: 85.1,
        averageCompleteness: 81.3,
        lastEvaluated: DateTime.now().subtract(const Duration(hours: 2)),
        modeDistribution: {
          EvaluationMode.freeSTT: 5,
          EvaluationMode.word: 6,
          EvaluationMode.sentence: 3,
          EvaluationMode.paragraph: 1,
        },
      );
    } catch (e) {
      debugPrint('获取统计数据失败: $e');
      rethrow;
    }
  }

  /// 重置当前状态
  void reset() {
    _isRecording = false;
    _currentRecordingPath = null;
    _recordingStartTime = null;
    _currentResult = null;
    _lastError = null;
    _setState(EvaluationState.idle);
  }

  /// 内部状态设置方法
  void _setState(EvaluationState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
      
      // 清理错误状态
      if (newState != EvaluationState.error) {
        _lastError = null;
        _errorController.add(null);
      }
    }
  }

  /// 内部错误设置方法
  void _setError(String error, {String? code}) {
    _lastError = error;
    _setState(EvaluationState.error);
    _errorController.add(error);
    debugPrint('评测服务错误: $error');
  }

  /// 释放资源
  void dispose() {
    _resultController.close();
    _stateController.close();
    _errorController.close();
  }

  // 私有方法

  /// 生成模拟评测结果（用于测试）
  EvaluationResult _generateMockEvaluation({
    required String referenceText,
    required EvaluationMode mode,
    String? audioPath,
  }) {
    final duration = _recordingStartTime != null 
        ? DateTime.now().difference(_recordingStartTime!)
        : const Duration(seconds: 3);

    // 根据模式生成不同的评测结果
    switch (mode) {
      case EvaluationMode.freeSTT:
        return _generateSTTResult(referenceText, audioPath, duration);
      case EvaluationMode.word:
        return _generateWordResult(referenceText, audioPath, duration);
      case EvaluationMode.sentence:
        return _generateSentenceResult(referenceText, audioPath, duration);
      case EvaluationMode.paragraph:
        return _generateParagraphResult(referenceText, audioPath, duration);
    }
  }

  EvaluationResult _generateSTTResult(String text, String? audioPath, Duration duration) {
    // 模拟STT识别结果
    final words = text.split(' ').take(8).toList();
    final evaluations = words.map((word) {
      final score = 60.0 + (40.0 * (word.length / 10)); // 模拟评分
      return WordEvaluation(
        word: word,
        score: score.clamp(0, 100),
        isCorrect: score > 70,
      );
    }).toList();

    final avgScore = evaluations.isEmpty ? 0.0 : 
        evaluations.map((e) => e.score).reduce((a, b) => a + b) / evaluations.length;

    return EvaluationResult(
      referenceText: text,
      mode: EvaluationMode.freeSTT,
      overallScore: avgScore,
      fluencyScore: avgScore * 0.9,
      accuracyScore: avgScore * 1.1,
      completenessScore: avgScore,
      wordEvaluations: evaluations,
      createdAt: DateTime.now(),
      recordingPath: audioPath,
      duration: duration,
    );
  }

  EvaluationResult _generateWordResult(String word, String? audioPath, Duration duration) {
    final score = 75.0 + (25.0 * (word.length / 10)).clamp(0, 100);
    final evaluation = WordEvaluation(
      word: word,
      score: score,
      isCorrect: score > 80,
    );

    return EvaluationResult(
      referenceText: word,
      mode: EvaluationMode.word,
      overallScore: score,
      fluencyScore: score * 0.95,
      accuracyScore: score,
      completenessScore: score,
      wordEvaluations: [evaluation],
      createdAt: DateTime.now(),
      recordingPath: audioPath,
      duration: duration,
    );
  }

  EvaluationResult _generateSentenceResult(String sentence, String? audioPath, Duration duration) {
    final words = sentence.split(' ').take(10).toList();
    final evaluations = words.map((word) {
      final score = 65.0 + (35.0 * (word.length / 12)).clamp(0, 100);
      return WordEvaluation(
        word: word,
        score: score.clamp(0, 100),
        isCorrect: score > 75,
      );
    }).toList();

    final avgScore = evaluations.isEmpty ? 0.0 :
        evaluations.map((e) => e.score).reduce((a, b) => a + b) / evaluations.length;

    return EvaluationResult(
      referenceText: sentence,
      mode: EvaluationMode.sentence,
      overallScore: avgScore,
      fluencyScore: avgScore * 0.85,
      accuracyScore: avgScore * 1.05,
      completenessScore: avgScore * 0.95,
      wordEvaluations: evaluations,
      createdAt: DateTime.now(),
      recordingPath: audioPath,
      duration: duration,
    );
  }

  EvaluationResult _generateParagraphResult(String paragraph, String? audioPath, Duration duration) {
    final words = paragraph.split(' ').take(15).toList();
    final evaluations = words.map((word) {
      final score = 60.0 + (40.0 * (word.length / 15)).clamp(0, 100);
      return WordEvaluation(
        word: word,
        score: score.clamp(0, 100),
        isCorrect: score > 70,
      );
    }).toList();

    final avgScore = evaluations.isEmpty ? 0.0 :
        evaluations.map((e) => e.score).reduce((a, b) => a + b) / evaluations.length;

    return EvaluationResult(
      referenceText: paragraph,
      mode: EvaluationMode.paragraph,
      overallScore: avgScore,
      fluencyScore: avgScore * 0.8,
      accuracyScore: avgScore * 1.0,
      completenessScore: avgScore * 0.9,
      wordEvaluations: evaluations,
      createdAt: DateTime.now(),
      recordingPath: audioPath,
      duration: duration,
    );
  }

  /// 输入验证
  void _validateEvaluationInput(
    String referenceText,
    EvaluationMode mode,
    String? audioPath,
  ) {
    if (referenceText.trim().length > 500) {
      throw const EvaluationException(
        '评测文本过长，建议分段进行评测',
        code: 'TEXT_TOO_LONG',
      );
    }

    switch (mode) {
      case EvaluationMode.word:
        if (!referenceText.contains(' ') && !RegExp(r'^[a-zA-Z]+$').hasMatch(referenceText)) {
          throw const EvaluationException(
            '单词评测只支持英文字母',
            code: 'INVALID_WORD_FORMAT',
          );
        }
        if (referenceText.length > 20) {
          throw const EvaluationException(
            '单词太长，建议使用句子评测模式',
            code: 'WORD_TOO_LONG',
          );
        }
        break;
      case EvaluationMode.sentence:
        if (referenceText.length > 100) {
          throw const EvaluationException(
            '句子过长，请使用段落评测模式',
            code: 'SENTENCE_TOO_LONG',
          );
        }
        break;
      case EvaluationMode.paragraph:
        if (referenceText.length < 50) {
          throw const EvaluationException(
            '段落内容过短，建议使用句子评测',
            code: 'PARAGRAPH_TOO_SHORT',
          );
        }
        break;
      case EvaluationMode.freeSTT:
        // STT模式没有特殊限制
        break;
    }

    if (audioPath != null && audioPath.isEmpty) {
      throw const EvaluationException(
        '音频路径无效',
        code: 'INVALID_AUDIO_PATH',
      );
    }
  }

  /// 保存评测记录到本地存储
  Future<void> _saveEvaluationRecord(EvaluationResult result) async {
    try {
      // TODO: 实现本地数据库存储
      // await DatabaseService.instance.saveEvaluationRecord(result);
      debugPrint('保存评测记录: ${result.referenceText} - ${result.overallScore}%');
    } catch (e) {
      debugPrint('保存评测记录失败: $e');
    }
  }
}

/// 评测模式检测器
class EvaluationModeDetector {
  /// 根据文本特征自动检测最适合的评测模式
  static EvaluationMode detectMode(String text) {
    final trimmed = text.trim();
    
    // 空文本或过短文本使用STT模式
    if (trimmed.isEmpty || trimmed.length < 3) {
      return EvaluationMode.freeSTT;
    }
    
    // 单个单词（无空格且长度合理）
    if (!trimmed.contains(' ') && trimmed.length <= 20) {
      return EvaluationMode.word;
    }
    
    // 短句子（<= 100字符）
    if (trimmed.length <= 100) {
      return EvaluationMode.sentence;
    }
    
    // 长段落（> 100字符）
    if (trimmed.length > 100) {
      return EvaluationMode.paragraph;
    }
    
    // 默认为STT模式
    return EvaluationMode.freeSTT;
  }
  
  /// 检测是否为有效的评测文本
  static bool isValidEvaluationText(String text) {
    final trimmed = text.trim();
    return trimmed.isNotEmpty && trimmed.length >= 2;
  }
  
  /// 获取文本的建议评测模式描述
  static String getModeDescription(EvaluationMode mode) {
    switch (mode) {
      case EvaluationMode.freeSTT:
        return '免费语音识别评测';
      case EvaluationMode.word:
        return '单词精准发音评测';
      case EvaluationMode.sentence:
        return '句子综合评测';
      case EvaluationMode.paragraph:
        return '段落流畅度评测';
    }
  }
}