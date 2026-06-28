import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 本地 STT 服务（已移除 Whisper 模型）
/// 免费模式下 STT 功能不可用，请使用收费模式（云端声通）
class LocalSttService {
  static LocalSttService? _instance;
  static LocalSttService get instance => _instance ??= LocalSttService._();
  LocalSttService._();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isLoading => false;

  Future<void> initialize() async {
    _isInitialized = false;
    debugPrint('STT 本地模型已移除，请使用云端模式');
  }

  Future<String> recognizeFromFile({
    required String filePath,
    String language = 'en',
  }) async {
    return 'STT 本地模型已移除，请使用云端模式';
  }

  void dispose() {}
}
