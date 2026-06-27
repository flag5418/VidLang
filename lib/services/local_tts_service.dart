import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:vidlang/services/model_path_service.dart';


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
  Timer? _releaseTimer;
  static const _modelKeepAliveMs = 60000; // 60秒

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
      // 模拟器上跳过 sherpa_onnx 初始化（避免 native crash）
      if (Platform.isIOS) {
        final appDir = await getApplicationDocumentsDirectory();
        if (appDir.path.contains('CoreSimulator')) {
          debugPrint('TTS: iOS 模拟器环境，跳过 sherpa_onnx 初始化');
          _isLoading = false;
          return;
        }
      }

      // 检查模型是否完整
      if (!await ModelPathService.isTtsModelComplete) {
        debugPrint('TTS 模型文件不完整');
        _isLoading = false;
        return;
      }

      // 初始化 sherpa-onnx
      sherpa_onnx.initBindings();

      // 加载可用声音
      await _loadAvailableVoices();

      // 获取模型路径
      final modelPaths = await ModelPathService.ttsModelPaths;

      // 创建 Supertonic 模型配置
      final supertonic = sherpa_onnx.OfflineTtsSupertonicModelConfig(
        durationPredictor: modelPaths['durationPredictor']!,
        textEncoder: modelPaths['textEncoder']!,
        vectorEstimator: modelPaths['vectorEstimator']!,
        vocoder: modelPaths['vocoder']!,
        ttsJson: modelPaths['ttsJson']!,
        unicodeIndexer: modelPaths['unicodeIndexer']!,
        voiceStyle: modelPaths['voiceStyle']!,
      );

      // 创建模型配置
      final modelConfig = sherpa_onnx.OfflineTtsModelConfig(
        supertonic: supertonic,
        numThreads: 2,
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

  /// 加载可用声音列表
  /// 从 voice.bin 文件读取声音数量（voice.bin 包含 n 个 voice styles）
  Future<void> _loadAvailableVoices() async {
    _availableVoices = [];

    try {
      final voiceBinPath = (await ModelPathService.ttsModelPaths)['voiceStyle']!;
      final voiceBinFile = File(voiceBinPath);
      if (!await voiceBinFile.exists()) {
        debugPrint('voice.bin 不存在，无法加载声音列表');
        return;
      }

      // 读取前 8 个字节（第一个 int64，小端序）
      final bytes = await voiceBinFile.openRead(0, 8).first;
      if (bytes.length < 8) {
        debugPrint('voice.bin 文件太小');
        return;
      }

      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      final voiceCount = byteData.getInt64(0, Endian.little);

      if (voiceCount <= 0 || voiceCount > 100) {
        debugPrint('voice.bin 中声音数量异常: $voiceCount');
        return;
      }

      // 生成声音名称列表
      for (int i = 0; i < voiceCount; i++) {
        _availableVoices.add('Voice_$i');
      }

      debugPrint('加载声音列表成功: 共 $voiceCount 个声音');
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

      // 启动释放计时器
      _scheduleRelease();

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

  /// 启动释放计时器（合成完成后调用）
  void _scheduleRelease() {
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(milliseconds: _modelKeepAliveMs), () {
      debugPrint('TTS 模型 60秒未使用，释放内存');
      _releaseModels();
    });
  }

  /// 释放模型内存（保留初始化状态，仅释放 tts）
  void _releaseModels() {
    _tts?.free();
    _tts = null;
    _isInitialized = false;
    debugPrint('TTS 模型已释放');
  }

  /// 释放资源
  void dispose() {
    _releaseTimer?.cancel();
    _tts?.free();
    _tts = null;
    _isInitialized = false;
  }
}
