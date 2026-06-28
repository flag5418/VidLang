import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 本地模型状态管理服务
/// 只检查 MarianMT 翻译模型是否存在于沙盒中
class LocalModelService {
  static LocalModelService? _instance;
  static LocalModelService get instance => _instance ??= LocalModelService._();
  LocalModelService._();

  // 模型状态
  bool _isInitialized = false;
  bool _hasAllModels = false;
  bool _isChecking = false;

  // 状态流
  final _statusController = StreamController<LocalModelStatus>.broadcast();
  Stream<LocalModelStatus> get statusStream => _statusController.stream;

  // 当前状态
  LocalModelStatus _currentStatus = LocalModelStatus.unknown;
  LocalModelStatus get currentStatus => _currentStatus;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;
    await checkModelsStatus();
    _isInitialized = true;
  }

  /// 检查 MarianMT 模型是否存在
  Future<LocalModelStatus> checkModelsStatus() async {
    if (_isChecking) return _currentStatus;
    _isChecking = true;

    try {
      // 检查沙盒中的 MarianMT 模型
      final appDir = await getApplicationDocumentsDirectory();
      final marianmtPath = '${appDir.path}/models/marianmt-onnx/encoder_model.onnx';
      final marianmtExists = await File(marianmtPath).exists();

      debugPrint('=== 模型检测详情 ===');
      debugPrint('MarianMT 存在: $marianmtExists');

      if (marianmtExists) {
        _currentStatus = LocalModelStatus.ready;
        _hasAllModels = true;
        debugPrint('状态设置为 LocalModelStatus.ready');
      } else {
        _currentStatus = LocalModelStatus.missing;
        _hasAllModels = false;
        debugPrint('状态设置为 LocalModelStatus.missing');
      }

      _statusController.add(_currentStatus);
      return _currentStatus;
    } catch (e) {
      debugPrint('检查模型状态失败: $e');
      _currentStatus = LocalModelStatus.error;
      _statusController.add(_currentStatus);
      return _currentStatus;
    } finally {
      _isChecking = false;
    }
  }

  /// 是否有所有必需模型
  bool get hasAllModels => _hasAllModels;

  /// 是否可以使用 AI 功能
  bool get canUseAiFeatures => _hasAllModels && _currentStatus == LocalModelStatus.ready;

  /// 重置状态（强制重新检查）
  Future<void> reset() async {
    _isInitialized = false;
    _currentStatus = LocalModelStatus.unknown;
    _hasAllModels = false;
    await initialize();
  }

  /// 销毁
  void dispose() {
    _statusController.close();
  }
}

/// 本地模型状态
enum LocalModelStatus {
  unknown,
  missing,
  ready,
  error,
}

/// 模型状态扩展
extension LocalModelStatusExtension on LocalModelStatus {
  String get displayName {
    switch (this) {
      case LocalModelStatus.unknown:
        return '检查中...';
      case LocalModelStatus.missing:
        return '需要下载模型';
      case LocalModelStatus.ready:
        return '模型已就绪';
      case LocalModelStatus.error:
        return '检查失败';
    }
  }

  String get description {
    switch (this) {
      case LocalModelStatus.unknown:
        return '正在检查模型状态...';
      case LocalModelStatus.missing:
        return '本地缺少翻译模型，请检查 assets 中的 MarianMT 模型是否正确打包';
      case LocalModelStatus.ready:
        return '翻译模型已就绪';
      case LocalModelStatus.error:
        return '检查模型状态时出错';
    }
  }

  bool get shouldShowDownloadDialog {
    return this == LocalModelStatus.missing;
  }

  bool get canUseAiFeatures {
    return this == LocalModelStatus.ready;
  }
}
