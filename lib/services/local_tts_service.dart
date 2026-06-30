import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';


/// 本地 TTS 服务
/// 使用 flutter_tts 封装的 iOS/Android 原生 TTS 引擎
class LocalTtsService {
  static LocalTtsService? _instance;
  static LocalTtsService get instance => _instance ??= LocalTtsService._();
  LocalTtsService._();

  FlutterTts? _tts;
  bool _isInitialized = false;
  bool _isLoading = false;

  // 可用声音列表
  List<Map<String, String>> _availableVoices = [];
  int _currentSpeakerId = 0;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 可用声音列表
  List<Map<String, String>> get availableVoices => List.unmodifiable(_availableVoices);

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
    final index = _availableVoices.indexWhere((v) => v['name'] == voiceName);
    if (index >= 0) {
      _currentSpeakerId = index;
    }
  }

  /// 初始化 TTS 引擎
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;

    _isLoading = true;

    try {
      _tts = FlutterTts();

      await _loadAvailableVoices();

      if (_availableVoices.isNotEmpty && _currentSpeakerId >= _availableVoices.length) {
        _currentSpeakerId = 0;
      }

      if (_currentSpeakerId >= 0 && _currentSpeakerId < _availableVoices.length) {
        await _tts!.setVoice(_availableVoices[_currentSpeakerId]);
      }

      _isInitialized = true;
      debugPrint('Native TTS 引擎初始化成功，可用声音: ${_availableVoices.length}');
    } catch (e) {
      debugPrint('TTS 引擎初始化失败: $e');
      _isInitialized = false;
    } finally {
      _isLoading = false;
    }
  }

  /// 加载可用声音列表
  Future<void> _loadAvailableVoices() async {
    try {
      final voices = await _tts!.getVoices;
      if (voices is List) {
        _availableVoices = voices.map((v) => Map<String, String>.from(v as Map)).toList();
      }
      debugPrint('加载声音列表成功: 共 ${_availableVoices.length} 个声音');
    } catch (e) {
      debugPrint('加载声音列表失败: $e');
      _availableVoices = [];
    }
  }

  /// 设置语言
  Future<void> setLanguage(String language) async {
    await _tts?.setLanguage(language);
  }

  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    await _tts?.setSpeechRate(rate);
  }

  /// 设置音量
  Future<void> setVolume(double volume) async {
    await _tts?.setVolume(volume);
  }

  /// 设置音调
  Future<void> setPitch(double pitch) async {
    await _tts?.setPitch(pitch);
  }

  /// 合成语音并保存为文件
  ///
  /// 使用 flutter_tts 的 synthesizeToFile API 将文本合成为音频文件。
  /// iOS: 通过 AVSpeechSynthesizer 写入 .caf 文件，然后返回路径
  /// Android: 通过 TextToSpeech.synthesizeToFile 写入 .wav 文件
  Future<String?> synthesizeToFile({
    required String text,
    String outputPath = '',
    int? speakerId,
  }) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) {
        debugPrint('TTS 模型未初始化');
        return null;
      }
    }

    try {
      // 构建输出路径
      if (outputPath.isEmpty) {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'tts_${DateTime.now().millisecondsSinceEpoch}.m4a';
        outputPath = '${tempDir.path}/$fileName';
      }

      if (speakerId != null && speakerId >= 0 && speakerId < _availableVoices.length) {
        await _tts!.setVoice(_availableVoices[speakerId]);
      }

      // 使用 flutter_tts 的 synthesizeToFile 方法（不是 speak！）
      // speak() 只会通过扬声器播放，不会写入文件
      final result = await _tts!.synthesizeToFile(text, outputPath);

      // 验证文件是否真的被创建
      if (result == 1) {
        final file = File(outputPath);
        if (await file.exists() && await file.length() > 0) {
          debugPrint('✅ [NativeTTS] 合成成功: ${file.length()} bytes → ${outputPath.split('/').last}');
          return outputPath;
        }
      }

      // synthesizeToFile 返回失败或文件不存在 → 降级方案：使用 speak + 系统录音不可行
      // 直接返回 null 让上层处理
      debugPrint('⚠️ [NativeTTS] synthesizeToFile 未生成有效文件 (result=$result), path=$outputPath');
      return null;
    } catch (e, stack) {
      debugPrint('❌ [NativeTTS] 合成异常: $e\n$stack');
      return null;
    }
  }

  /// 合成语音并返回音频数据
  Future<Uint8List?> synthesizeToAudio({
    required String text,
    int? speakerId,
  }) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) {
        debugPrint('TTS 模型未初始化');
        return null;
      }
    }

    try {
      if (speakerId != null && speakerId >= 0 && speakerId < _availableVoices.length) {
        await _tts!.setVoice(_availableVoices[speakerId]);
      }

      await _tts!.speak(text);
      return null;
    } catch (e) {
      debugPrint('TTS 合成失败: $e');
      return null;
    }
  }

  /// 停止 TTS
  Future<void> stop() async {
    await _tts?.stop();
  }

  /// 随机选择一个声音
  int getRandomSpeakerId() {
    if (_availableVoices.isEmpty) return 0;
    return DateTime.now().millisecondsSinceEpoch % _availableVoices.length;
  }

  /// 释放资源
  void dispose() {
    _tts?.stop();
    _tts = null;
    _isInitialized = false;
  }
}
