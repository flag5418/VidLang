import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vidlang/services/assets_extractor.dart';
import 'package:vidlang/services/model_download_service.dart';

/// 本地模型状态管理服务
/// 负责检查本地模型状态、版本匹配等
class LocalModelService {
  static LocalModelService? _instance;
  static LocalModelService get instance => _instance ??= LocalModelService._();
  LocalModelService._();

  final ModelDownloadService _downloadService = ModelDownloadService.instance;

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

    await AssetsExtractor.extractBuiltInModelsIfNeed();

    await checkModelsStatus();
    _isInitialized = true;
  }

  /// 检查所有模型状态
  Future<LocalModelStatus> checkModelsStatus() async {
    if (_isChecking) return _currentStatus;

    _isChecking = true;

    try {
      // 只检查 MarianMT 翻译模型
      final marianmtExists = await _downloadService.isModelDownloaded('marianmt');

      debugPrint('=== 模型检测详情 ===');
      debugPrint('MarianMT 存在: $marianmtExists');

      // 获取远程版本信息（失败时不强制要求下载）
      ModelConfigResponse? remoteConfig;
      bool configFetchFailed = false;
      try {
        remoteConfig = await _downloadService.getModelConfig();
        debugPrint('远程配置获取成功');
      } catch (e) {
        debugPrint('获取远程模型配置失败，尝试离线加载: $e');
        configFetchFailed = true;
      }

      // 检查版本是否匹配
      bool needsUpdate = false;
      if (remoteConfig != null) {
        for (final entry in remoteConfig.models.entries) {
          if (entry.value.required) {
            final localPath = await _downloadService.getLocalModelPath(entry.key);
            if (localPath != null) {
              final needs = await _downloadService.needsUpdate(entry.key, entry.value.version);
              if (needs) {
                needsUpdate = true;
                break;
              }
            }
          }
        }
      }

      // 更新状态
      if (marianmtExists) {
        _currentStatus = LocalModelStatus.ready;
        _hasAllModels = marianmtExists;
        debugPrint('状态设置为 LocalModelStatus.ready (MarianMT: $marianmtExists)');
      } else if (needsUpdate) {
        _currentStatus = LocalModelStatus.needsUpdate;
        _hasAllModels = false;
        debugPrint('状态设置为 needsUpdate');
      } else if (configFetchFailed) {
        _currentStatus = LocalModelStatus.error;
        _hasAllModels = false;
        debugPrint('状态设置为 LocalModelStatus.error (模型缺失且无法连接服务器)');
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
  unknown, // 未知
  missing, // 缺少模型
  needsUpdate, // 需要更新
  ready, // 就绪
  error, // 错误
}

/// 模型状态扩展
extension LocalModelStatusExtension on LocalModelStatus {
  String get displayName {
    switch (this) {
      case LocalModelStatus.unknown:
        return '检查中...';
      case LocalModelStatus.missing:
        return '需要下载模型';
      case LocalModelStatus.needsUpdate:
        return '模型需要更新';
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
        return '本地缺少AI模型，请先下载后再使用相关功能';
      case LocalModelStatus.needsUpdate:
        return '检测到模型版本更新，请重新下载以获得最佳体验';
      case LocalModelStatus.ready:
        return '所有模型已就绪，可以使用AI功能';
      case LocalModelStatus.error:
        return '检查模型状态时出错，请重试';
    }
  }

  bool get shouldShowDownloadDialog {
    return this == LocalModelStatus.missing || this == LocalModelStatus.needsUpdate;
  }

  bool get canUseAiFeatures {
    return this == LocalModelStatus.ready;
  }
}
