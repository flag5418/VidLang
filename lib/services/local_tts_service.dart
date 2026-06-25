import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;


/// 本地 TTS 服务
/// 使用 Supertonic TTS 引擎进行语音合成（通过 sherpa-onnx）
/// 支持多种声音风格：M1-M3（男声）、F1-F3（女声）
class LocalTtsService {
  static LocalTtsService? _instance;
  static LocalTtsService get instance => _instance ??= LocalTtsService._();
  LocalTtsService._();

  sherpa_onnx.OfflineTts? _tts;
  bool _isInitialized = false;
  bool _isLoading = false;

  // 模型路径
  String? _modelsDir;

  // 可用声音列表
  List<String> _availableVoices = [];
  int _currentSpeakerId = 0;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在加载模型
  bool get isLoading => _isLoading;

  /// 可用声音列表
  List<String> get availableVoices => List.unmodifiable(_availableVoices);

  /// 当前声音 ID
  int get currentSpeakerId => _currentSpeakerId;

  /// 设置声音
  void setSpeaker(int speakerId) {
    if (speakerId >= 0 && speakerId < _availableVoices.length) {
      _currentSpeakerId = speakerId;
    }
  }

  /// 根据名称设置声音
  void setVoiceByName(String voiceName) {
    final index = _availableVoices.indexOf(voiceName);
    if (index >= 0) {
      _currentSpeakerId = index;
    }
  }

  /// 初始化 TTS 引擎
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;

    _isLoading = true;

    try {
      // 查找 Supertonic 模型目录
      _modelsDir = await _findSupertonicModelsDir();

      if (_modelsDir == null) {
        debugPrint('Supertonic TTS 模型目录不存在');
        _isLoading = false;
        return;
      }

      // 初始化 sherpa-onnx
      sherpa_onnx.initBindings();

      // 加载可用声音
      await _loadAvailableVoices();

      // 创建 Supertonic 模型配置
      final supertonic = sherpa_onnx.OfflineTtsSupertonicModelConfig(
        durationPredictor: '$_modelsDir/onnx/duration_predictor.onnx',
        textEncoder: '$_modelsDir/onnx/text_encoder.onnx',
        vectorEstimator: '$_modelsDir/onnx/vector_estimator.onnx',
        vocoder: '$_modelsDir/onnx/vocoder.onnx',
        ttsJson: '$_modelsDir/onnx/tts.json',
        unicodeIndexer: '$_modelsDir/onnx/unicode_indexer.json',
        voiceStyle: _availableVoices.isNotEmpty
            ? '$_modelsDir/voice_styles/${_availableVoices[_currentSpeakerId]}.json'
            : '',
      );

      // 创建模型配置
      final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
        supertonic: supertonic,
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
      debugPrint('Supertonic TTS 引擎初始化成功，可用声音: $_availableVoices');
    } catch (e) {
      debugPrint('TTS 引擎初始化失败: $e');
      _isInitialized = false;
    } finally {
      _isLoading = false;
    }
  }

  /// 查找 Supertonic 模型目录
  Future<String?> _findSupertonicModelsDir() async {
    try {
      // 方法1：从 models/ 目录查找（开发环境）
      final currentDir = Directory.current.path;
      final devPath = '$currentDir/models/supertonic';
      if (await Directory(devPath).exists()) {
        return devPath;
      }

      // 方法2：从 applicationDocumentsDirectory 查找（生产环境）
      final appDir = await getApplicationDocumentsDirectory();
      final prodPath = '${appDir.path}/models/supertonic';
      if (await Directory(prodPath).exists()) {
        return prodPath;
      }

      // 方法3：从 models/ 目录的上级目录查找
      final altPath = '${appDir.parent.path}/models/supertonic';
      if (await Directory(altPath).exists()) {
        return altPath;
      }

      return null;
    } catch (e) {
      debugPrint('查找 Supertonic 模型目录失败: $e');
      return null;
    }
  }

  /// 加载可用声音列表
  Future<void> _loadAvailableVoices() async {
    _availableVoices = [];

    try {
      final voiceStylesDir = Directory('$_modelsDir/voice_styles');
      if (await voiceStylesDir.exists()) {
        await for (final entity in voiceStylesDir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            final fileName = entity.path.split('/').last;
            final voiceName = fileName.replaceAll('.json', '');
            _availableVoices.add(voiceName);
          }
        }
        _availableVoices.sort();
      }
    } catch (e) {
      debugPrint('加载声音列表失败: $e');
    }
  }

  /// 合成语音并保存为文件
  Future<String?> synthesizeToFile({
    required String text,
    String outputPath = '',
    int? speakerId,
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

      // 使用指定的声音或当前声音
      final sid = speakerId ?? _currentSpeakerId;

      // 合成语音
      final audio = _tts!.generate(
        text: text,
        sid: sid,
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
    int? speakerId,
  }) async {
    if (!_isInitialized || _tts == null) {
      await initialize();
      if (!_isInitialized) {
        debugPrint('TTS 模型未初始化');
        return null;
      }
    }

    try {
      // 使用指定的声音或当前声音
      final sid = speakerId ?? _currentSpeakerId;

      // 合成语音
      final audio = _tts!.generate(
        text: text,
        sid: sid,
        speed: 1.0,
      );

      // 转换为 WAV 格式
      return _audioToWav(audio.samples, audio.sampleRate);
    } catch (e) {
      debugPrint('TTS 合成失败: $e');
      return null;
    }
  }

  /// 随机选择一个声音
  int getRandomSpeakerId() {
    if (_availableVoices.isEmpty) return 0;
    final random = Random();
    return random.nextInt(_availableVoices.length);
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
