import 'dart:async';

import 'package:flutter/foundation.dart';
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
    
    await checkModelsStatus();
    _isInitialized = true;
  }

  /// 检查所有模型状态
  Future<LocalModelStatus> checkModelsStatus() async {
    if (_isChecking) return _currentStatus;
    
    _isChecking = true;
    
    try {
      // 检查模型类型
      // TTS 是必需的（本地语音合成）
      // STT 和 LLM 可以使用云端回退
      final ttsExists = await _downloadService.isModelDownloaded('tts');
      final sttExists = await _downloadService.isModelDownloaded('stt');
      
      // 获取远程版本信息（失败时不强制要求下载）
      ModelConfigResponse? remoteConfig;
      bool configFetchFailed = false;
      try {
        remoteConfig = await _downloadService.getModelConfig();
      } catch (e) {
        debugPrint('获取远程模型配置失败: $e');
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
      // TTS 是必需的，STT 可选（云端回退）
      if (ttsExists) {
        _currentStatus = LocalModelStatus.ready;
        _hasAllModels = true;
      } else if (needsUpdate) {
        _currentStatus = LocalModelStatus.needsUpdate;
        _hasAllModels = false;
      } else if (!ttsExists) {
        // 只有当远程配置获取成功时才标记为 missing
        // 配置获取失败时标记为 error，不强制弹窗
        _currentStatus = configFetchFailed 
            ? LocalModelStatus.error 
            : LocalModelStatus.missing;
        _hasAllModels = false;
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

  /// 获取本地 LLM 模型路径
  Future<String?> getLlmModelPath() async {
    return await _downloadService.getLocalModelPath('llm');
  }

  /// 获取本地 TTS 模型路径
  Future<String?> getTtsModelPath() async {
    return await _downloadService.getLocalModelPath('tts');
  }

  /// 获取本地 STT 模型路径
  Future<String?> getSttModelPath() async {
    return await _downloadService.getLocalModelPath('stt');
  }

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
  unknown,        // 未知
  missing,        // 缺少模型
  needsUpdate,    // 需要更新
  ready,          // 就绪
  error,          // 错误
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
    return this == LocalModelStatus.missing || 
           this == LocalModelStatus.needsUpdate;
  }

  bool get canUseAiFeatures {
    return this == LocalModelStatus.ready;
  }
}
