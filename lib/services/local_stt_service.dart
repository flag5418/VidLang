import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:vidlang/services/local_model_service.dart';

/// 本地 STT 服务
/// 使用 Whisper 模型进行语音识别
class LocalSttService {
  static LocalSttService? _instance;
  static LocalSttService get instance => _instance ??= LocalSttService._();
  LocalSttService._();

  sherpa_onnx.OfflineRecognizer? _recognizer;
  bool _isInitialized = false;
  bool _isLoading = false;
  
  // 模型路径
  String? _modelPath;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 是否正在加载模型
  bool get isLoading => _isLoading;

  /// 初始化 STT 引擎
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;
    
    _isLoading = true;
    
    try {
      // 模拟器上跳过 sherpa_onnx 初始化（避免 native crash）
      if (Platform.isIOS) {
        final appDir = await getApplicationDocumentsDirectory();
        if (appDir.path.contains('CoreSimulator')) {
          debugPrint('STT: iOS 模拟器环境，跳过 sherpa_onnx 初始化');
          return;
        }
      }

      // 获取模型路径
      _modelPath = await LocalModelService.instance.getSttModelPath();
      
      if (_modelPath == null || !await File(_modelPath!).exists()) {
        debugPrint('STT 模型文件不存在');
        return;
      }
      
      // 初始化 sherpa-onnx
      sherpa_onnx.initBindings();
      
      // 查找 tokens.txt 文件
      final modelDir = File(_modelPath!).parent;
      final tokensFile = '${modelDir.path}/tokens.txt';
      
      // 创建 Whisper 模型配置
      final whisper = sherpa_onnx.OfflineWhisperModelConfig(
        encoder: '${modelDir.path}/encoder.onnx',
        decoder: '${modelDir.path}/decoder.onnx',
      );
      
      // 创建模型配置
      final modelConfig = sherpa_onnx.OfflineModelConfig(
        whisper: whisper,
        tokens: tokensFile,
        numThreads: 4,
        provider: 'coreml',
        debug: false,
      );
      
      // 创建 STT 配置
      final config = sherpa_onnx.OfflineRecognizerConfig(
        model: modelConfig,
        maxActivePaths: 4,
      );
      
      // 初始化 STT
      _recognizer = sherpa_onnx.OfflineRecognizer(config);
      _isInitialized = true;
      debugPrint('STT 引擎初始化成功');
    } catch (e) {
      debugPrint('STT 引擎初始化失败: $e');
      _isInitialized = false;
    } finally {
      _isLoading = false;
    }
  }

  /// 识别音频文件
  Future<String> recognizeFromFile({
    required String filePath,
    String language = 'en',
  }) async {
    if (!_isInitialized || _recognizer == null) {
      await initialize();
      if (!_isInitialized) {
        return '模型未初始化，请先下载模型';
      }
    }
    
    try {
      // 读取音频文件
      final file = File(filePath);
      final audioData = await file.readAsBytes();
      
      // 转换为 Float32List（假设是 16kHz 16bit PCM）
      final audio = _bytesToFloat32(audioData);
      
      // 创建流式识别器
      final stream = _recognizer!.createStream();
      
      // 添加音频数据
      stream.acceptWaveform(
        samples: audio,
        sampleRate: 16000,
      );
      
      // 解码
      _recognizer!.decode(stream);
      
      // 获取结果
      final result = _recognizer!.getResult(stream);
      
      // 释放资源
      stream.free();
      
      return result.text;
    } catch (e) {
      debugPrint('STT 识别失败: $e');
      return '识别失败: $e';
    }
  }

  /// 识别音频数据
  Future<String> recognizeFromAudio({
    required Float32List audio,
    int sampleRate = 16000,
  }) async {
    if (!_isInitialized || _recognizer == null) {
      await initialize();
      if (!_isInitialized) {
        return '模型未初始化，请先下载模型';
      }
    }
    
    try {
      // 创建流式识别器
      final stream = _recognizer!.createStream();
      
      // 添加音频数据
      stream.acceptWaveform(
        samples: audio,
        sampleRate: sampleRate,
      );
      
      // 解码
      _recognizer!.decode(stream);
      
      // 获取结果
      final result = _recognizer!.getResult(stream);
      
      // 释放资源
      stream.free();
      
      return result.text;
    } catch (e) {
      debugPrint('STT 识别失败: $e');
      return '识别失败: $e';
    }
  }

  /// 从麦克风实时识别（返回流）
  Stream<String> recognizeFromMicrophone({
    int sampleRate = 16000,
  }) async* {
    if (!_isInitialized || _recognizer == null) {
      await initialize();
      if (!_isInitialized) {
        yield '模型未初始化，请先下载模型';
        return;
      }
    }
    
    try {
      // 创建流式识别器
      final stream = _recognizer!.createStream();
      
      // 模拟实时音频流（实际需要从麦克风获取）
      // 这里只是一个示例，实际实现需要集成录音功能
      
      // 释放资源
      stream.free();
    } catch (e) {
      debugPrint('STT 实时识别失败: $e');
      yield '识别失败: $e';
    }
  }

  /// 字节数据转换为 Float32List
  Float32List _bytesToFloat32(Uint8List bytes) {
    // 假设是 16-bit PCM 格式
    final int16List = Int16List.view(bytes.buffer);
    final float32List = Float32List(int16List.length);
    
    for (var i = 0; i < int16List.length; i++) {
      // 将 [-32768, 32767] 转换为 [-1.0, 1.0]
      float32List[i] = int16List[i] / 32768.0;
    }
    
    return float32List;
  }

  /// 释放资源
  void dispose() {
    _recognizer?.free();
    _recognizer = null;
    _isInitialized = false;
  }
}
