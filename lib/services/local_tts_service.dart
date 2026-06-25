import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:vidlang/services/local_model_service.dart';

/// 本地 TTS 服务
/// 使用 Piper TTS 引擎进行语音合成
class LocalTtsService {
  static LocalTtsService? _instance;
  static LocalTtsService get instance => _instance ??= LocalTtsService._();
  LocalTtsService._();

  sherpa_onnx.OfflineTts? _tts;
  bool _isInitialized = false;
  bool _isLoading = false;
  
  // 模型路径
  String? _modelPath;
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 是否正在加载模型
  bool get isLoading => _isLoading;

  /// 初始化 TTS 引擎
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;
    
    _isLoading = true;
    
    try {
      // 获取模型路径
      _modelPath = await LocalModelService.instance.getTtsModelPath();
      
      if (_modelPath == null || !await File(_modelPath!).exists()) {
        debugPrint('TTS 模型文件不存在');
        _isLoading = false;
        return;
      }
      
      // 初始化 sherpa-onnx
      sherpa_onnx.initBindings();
      
      // 查找配置文件（与模型同目录）
      final modelDir = File(_modelPath!).parent;
      
      // 查找 tokens.txt 文件
      final tokensFile = '${modelDir.path}/tokens.txt';
      if (!await File(tokensFile).exists()) {
        debugPrint('TTS tokens 文件不存在');
        _isLoading = false;
        return;
      }
      
      // 查找 espeak-ng-data 目录
      final dataDir = '${modelDir.path}/espeak-ng-data';
      if (!await Directory(dataDir).exists()) {
        debugPrint('TTS espeak-ng-data 目录不存在');
        _isLoading = false;
        return;
      }
      
      // 创建 VITS 模型配置
      final vits = sherpa_onnx.OfflineTtsVitsModelConfig(
        model: _modelPath!,
        tokens: tokensFile,
        dataDir: dataDir,
      );
      
      // 创建模型配置
      final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
        vits: vits,
        numThreads: 4,
        debug: false,
      );
      
      // 创建 TTS 配置
      final config = sherpa_onnx.OfflineTtsConfig(
        model: modelConfig,
        maxNumSenetences: 1,
      );
      
      // 初始化 TTS
      _tts = sherpa_onnx.OfflineTts(config);
      _isInitialized = true;
      debugPrint('TTS 引擎初始化成功');
    } catch (e) {
      debugPrint('TTS 引擎初始化失败: $e');
      _isInitialized = false;
    } finally {
      _isLoading = false;
    }
  }

  /// 合成语音并保存为文件
  Future<String?> synthesizeToFile({
    required String text,
    String outputPath = '',
  }) async {
    if (!_isInitialized || _tts == null) {
      await initialize();
      if (!_isInitialized) {
        debugPrint('TTS 模型未初始化');
        return null;
      }
    }
    
    try {
      // 生成输出路径
      if (outputPath.isEmpty) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'tts_${DateTime.now().millisecondsSinceEpoch}.wav';
        outputPath = '${tempDir.path}/$fileName';
      }
      
      // 合成语音
      final audio = _tts!.generate(
        text: text,
        sid: 0,
        speed: 1.0,
      );
      
      // 保存为 WAV 文件
      await _saveAsWav(audio.samples, audio.sampleRate, outputPath);
      
      return outputPath;
    } catch (e) {
      debugPrint('TTS 合成失败: $e');
      return null;
    }
  }

  /// 合成语音并返回音频数据
  Future<Uint8List?> synthesizeToAudio({
    required String text,
  }) async {
    if (!_isInitialized || _tts == null) {
      await initialize();
      if (!_isInitialized) {
        debugPrint('TTS 模型未初始化');
        return null;
      }
    }
    
    try {
      // 合成语音
      final audio = _tts!.generate(
        text: text,
        sid: 0,
        speed: 1.0,
      );
      
      // 转换为 WAV 格式
      return _audioToWav(audio.samples, audio.sampleRate);
    } catch (e) {
      debugPrint('TTS 合成失败: $e');
      return null;
    }
  }

  /// 保存音频为 WAV 文件
  Future<void> _saveAsWav(
    Float32List samples,
    int sampleRate,
    String outputPath,
  ) async {
    final file = File(outputPath);
    final wavData = _audioToWav(samples, sampleRate);
    await file.writeAsBytes(wavData);
  }

  /// 音频数据转换为 WAV 格式
  Uint8List _audioToWav(Float32List samples, int sampleRate) {
    final channels = 1;
    final bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = samples.length * channels * bitsPerSample ~/ 8;
    final fileSize = 36 + dataSize;
    
    final wav = Uint8List(44 + dataSize);
    var offset = 0;
    
    // RIFF header
    wav.setRange(offset, offset + 4, [0x52, 0x49, 0x46, 0x46]); // RIFF
    offset += 4;
    wav.setRange(offset, offset + 4, _intToBytes(fileSize, 4));
    offset += 4;
    wav.setRange(offset, offset + 4, [0x57, 0x41, 0x56, 0x45]); // WAVE
    offset += 4;
    
    // fmt chunk
    wav.setRange(offset, offset + 4, [0x66, 0x6D, 0x74, 0x20]); // fmt 
    offset += 4;
    wav.setRange(offset, offset + 4, _intToBytes(16, 4)); // chunk size
    offset += 4;
    wav.setRange(offset, offset + 2, _intToBytes(1, 2)); // PCM format
    offset += 2;
    wav.setRange(offset, offset + 2, _intToBytes(channels, 2));
    offset += 2;
    wav.setRange(offset, offset + 4, _intToBytes(sampleRate, 4));
    offset += 4;
    wav.setRange(offset, offset + 4, _intToBytes(byteRate, 4));
    offset += 4;
    wav.setRange(offset, offset + 2, _intToBytes(blockAlign, 2));
    offset += 2;
    wav.setRange(offset, offset + 2, _intToBytes(bitsPerSample, 2));
    offset += 2;
    
    // data chunk
    wav.setRange(offset, offset + 4, [0x64, 0x61, 0x74, 0x61]); // data
    offset += 4;
    wav.setRange(offset, offset + 4, _intToBytes(dataSize, 4));
    offset += 4;
    
    // 音频数据（转换为 16-bit PCM）
    for (var i = 0; i < samples.length; i++) {
      // 将 [-1.0, 1.0] 转换为 [-32768, 32767]
      final sample = (samples[i] * 32767).clamp(-32768, 32767).toInt();
      wav[offset++] = sample & 0xFF;
      wav[offset++] = (sample >> 8) & 0xFF;
    }
    
    return wav;
  }

  /// 整数转字节数组
  List<int> _intToBytes(int value, int byteCount) {
    final bytes = <int>[];
    for (var i = 0; i < byteCount; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }

  /// 释放资源
  void dispose() {
    _tts?.free();
    _tts = null;
    _isInitialized = false;
  }
}
