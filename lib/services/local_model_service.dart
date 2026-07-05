import 'dart:async';

import 'package:flutter/foundation.dart';

/// 本地模型状态管理服务
/// 
/// 现在使用 iOS 系统翻译（MLTranslation，需 iOS 17.4+）
/// 不再需要本地 MarianMT 模型
class LocalModelService {
  static LocalModelService? _instance;
  static LocalModelService get instance => _instance ??= LocalModelService._();
  LocalModelService._();

  // 模型状态
  bool _isInitialized = false;

  // 状态流
  final _statusController = StreamController<LocalModelStatus>.broadcast();
  Stream<LocalModelStatus> get statusStream => _statusController.stream;

  // 当前状态
  LocalModelStatus _currentStatus = LocalModelStatus.unknown;
  LocalModelStatus get currentStatus => _currentStatus;

  /// 是否可以使用 AI 功能
  /// 现在使用 iOS 系统翻译，始终返回 true
  bool get canUseAiFeatures => true;

  /// 所有模型是否就绪
  /// 现在使用 iOS 系统翻译，始终返回 true
  bool get hasAllModels => true;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _currentStatus = LocalModelStatus.ready;
    _isInitialized = true;
    _statusController.add(_currentStatus);
    debugPrint('LocalModelService: 使用 iOS 系统翻译（MLTranslation）');
  }

  /// 检查模型状态
  Future<LocalModelStatus> checkModelsStatus() async {
    _currentStatus = LocalModelStatus.ready;
    _statusController.add(_currentStatus);
    return _currentStatus;
  }

  /// 重置状态
  Future<void> reset() async {
    _isInitialized = false;
    _currentStatus = LocalModelStatus.unknown;
    _statusController.add(_currentStatus);
  }

  /// 释放资源
  void dispose() {
    _statusController.close();
  }
}

/// 本地模型状态
enum LocalModelStatus {
  unknown,    // 未知
  ready,      // 就绪（iOS 系统翻译可用）
  downloading, // 下载中
  missing,    // 缺失
  error,      // 错误
}

/// 本地模型状态扩展
extension LocalModelStatusExtension on LocalModelStatus {
  /// 显示名称
  String get displayName {
    switch (this) {
      case LocalModelStatus.unknown:
        return '未知';
      case LocalModelStatus.ready:
        return '就绪';
      case LocalModelStatus.downloading:
        return '下载中';
      case LocalModelStatus.missing:
        return '缺失';
      case LocalModelStatus.error:
        return '错误';
    }
  }

  /// 描述
  String get description {
    switch (this) {
      case LocalModelStatus.unknown:
        return '模型状态未知';
      case LocalModelStatus.ready:
        return 'iOS 系统翻译已就绪';
      case LocalModelStatus.downloading:
        return '模型正在下载中';
      case LocalModelStatus.missing:
        return '模型文件缺失';
      case LocalModelStatus.error:
        return '模型加载错误';
    }
  }
}
