import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 模型下载服务
/// 负责从镜像下载模型文件到本地
class ModelDownloadService {
  static ModelDownloadService? _instance;
  static ModelDownloadService get instance => _instance ??= ModelDownloadService._();
  ModelDownloadService._();

  final Dio _dio = Dio();

  // 下载状态回调
  final ValueNotifier<ModelDownloadState> _stateNotifier = ValueNotifier<ModelDownloadState>(ModelDownloadState.idle);
  ValueNotifier<ModelDownloadState> get stateNotifier => _stateNotifier;

  /// 获取模型配置
  Future<ModelConfigResponse> getModelConfig({String? customMirror}) async {
    try {
      final client = Supabase.instance.client;

      // 调用 Edge Function 获取配置
      final response = await client.functions.invoke('model-config', headers: customMirror != null ? {'X-Custom-Mirror': customMirror} : {});

      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? '获取模型配置失败');
      }

      return ModelConfigResponse.fromJson(response.data);
    } catch (e) {
      debugPrint('获取模型配置失败: $e');
      rethrow;
    }
  }

  /// 获取本地模型存储目录
  Future<Directory> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// 检查模型是否已下载
  Future<bool> isModelDownloaded(String modelType) async {
    try {
      // 方法1：检查 applicationDocumentsDirectory
      final modelsDir = await getModelsDirectory();
      debugPrint('检查目录: ${modelsDir.path}');
      if (await _checkModelsInDir(modelsDir, modelType)) {
        debugPrint('在 applicationDocumentsDirectory 找到 $modelType 模型');
        return true;
      }

      // 方法2：检查项目 models/ 目录（开发环境）
      final currentDir = Directory.current.path;
      if (currentDir == '/' || currentDir == '//') {
        debugPrint('未找到 $modelType 模型');
        return false;
      }
      final devModelsDir = Directory('$currentDir/models');
      debugPrint('检查开发目录: ${devModelsDir.path}');
      if (await devModelsDir.exists()) {
        // TTS 模型在 supertonic/ 子目录
        if (modelType == 'tts') {
          final supertonicDir = Directory('${devModelsDir.path}/supertonic');
          debugPrint('检查 Supertonic 目录: ${supertonicDir.path}');
          if (await supertonicDir.exists()) {
            debugPrint('在开发目录找到 TTS 模型');
            return true;
          }
        }
        // STT 模型检查
        if (modelType == 'stt') {
          if (await _checkModelsInDir(devModelsDir, modelType)) {
            debugPrint('在开发目录找到 STT 模型');
            return true;
          }
        }
      }

      debugPrint('未找到 $modelType 模型');
      return false;
    } catch (e) {
      debugPrint('检查模型下载状态失败: $e');
      return false;
    }
  }

  /// 检查目录中是否存在指定类型的模型文件
  Future<bool> _checkModelsInDir(Directory dir, String modelType) async {
    try {
      if (!await dir.exists()) return false;

      final files = await dir.list(recursive: true).toList();
      for (final file in files) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          if (_isModelFile(modelType, fileName)) {
            final stat = await file.stat();
            if (stat.size > 0) {
              return true;
            }
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 获取本地模型文件路径
  Future<String?> getLocalModelPath(String modelType) async {
    try {
      // 方法1：检查 applicationDocumentsDirectory（模拟器和真机都适用）
      final modelsDir = await getModelsDirectory();
      final path = await _findModelInDir(modelsDir, modelType);
      if (path != null) return path;

      // 方法2：检查项目 models/ 目录（仅在 macOS 开发时有效）
      final currentDir = Directory.current.path;
      if (currentDir != '/' && currentDir != '//') {
        final devModelsDir = Directory('$currentDir/models');
        if (await devModelsDir.exists()) {
          // TTS 模型在 supertonic/ 子目录
          if (modelType == 'tts') {
            final supertonicDir = Directory('${devModelsDir.path}/supertonic');
            if (await supertonicDir.exists()) {
              return supertonicDir.path;
            }
          }
          // STT 模型检查
          if (modelType == 'stt') {
            final sttPath = await _findModelInDir(devModelsDir, modelType);
            if (sttPath != null) return sttPath;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('获取本地模型路径失败: $e');
      return null;
    }
  }

  /// 在目录中查找模型文件
  Future<String?> _findModelInDir(Directory dir, String modelType) async {
    try {
      if (!await dir.exists()) return null;

      final files = await dir.list(recursive: true).toList();
      for (final file in files) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          if (_isModelFile(modelType, fileName)) {
            // TTS 需要返回包含 vocoder/text_encoder 等文件的上一级目录
            if (modelType == 'tts') {
              return file.parent.path;
            }
            return file.path;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查是否需要更新
  Future<bool> needsUpdate(String modelType, String remoteVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final localVersion = prefs.getString('model_version_$modelType');

    if (localVersion == null) {
      return true; // 本地没有，需要下载
    }

    return localVersion != remoteVersion; // 版本不一致，需要更新
  }

  /// 下载模型
  Future<void> downloadModel({
    required String modelType,
    required String url,
    required String expectedSize,
    required String version,
    Function(double progress, String speed)? onProgress,
    Function()? onComplete,
    Function(String error)? onError,
  }) async {
    try {
      _stateNotifier.value = ModelDownloadState.downloading;

      final modelsDir = await getModelsDirectory();
      final fileName = _getModelFileName(modelType, url);
      final savePath = '${modelsDir.path}/$fileName';

      // 检查是否已存在临时文件
      final tempPath = '$savePath.tmp';
      int downloadLength = 0;

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        downloadLength = await tempFile.length();
      }

      // 开始下载
      await _dio.download(
        url,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (downloadLength + received) / (downloadLength + total);
            onProgress?.call(progress.clamp(0.0, 1.0), '');
          }
        },
        options: Options(
          headers: {
            'Range': 'bytes=$downloadLength-', // 支持断点续传
          },
          receiveTimeout: Duration(minutes: 30),
        ),
      );

      // 下载完成，重命名文件
      final tempFile2 = File(tempPath);
      if (await tempFile2.exists()) {
        await tempFile2.rename(savePath);
      }

      // 保存版本号
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('model_version_$modelType', version);

      _stateNotifier.value = ModelDownloadState.completed;
      onComplete?.call();
    } catch (e) {
      _stateNotifier.value = ModelDownloadState.error;
      onError?.call(e.toString());
      rethrow;
    }
  }

  /// 下载所有必需模型
  Future<void> downloadAllModels({
    Function(String modelType, double progress, String speed)? onProgress,
    Function(String modelType)? onComplete,
    Function(String modelType, String error)? onError,
  }) async {
    try {
      final config = await getModelConfig();

      for (final entry in config.models.entries) {
        final modelType = entry.key;
        final modelInfo = entry.value;

        if (modelInfo.required) {
          // 检查是否需要更新
          final needsUpdate = await this.needsUpdate(modelType, modelInfo.version);

          if (needsUpdate) {
            await downloadModel(
              modelType: modelType,
              url: modelInfo.url,
              expectedSize: modelInfo.size,
              version: modelInfo.version,
              onProgress: (progress, speed) {
                onProgress?.call(modelType, progress, speed);
              },
              onComplete: () {
                onComplete?.call(modelType);
              },
              onError: (error) {
                onError?.call(modelType, error);
              },
            );
          }
        }
      }
    } catch (e) {
      debugPrint('下载所有模型失败: $e');
      rethrow;
    }
  }

  /// 删除模型
  Future<void> deleteModel(String modelType) async {
    try {
      final modelsDir = await getModelsDirectory();
      final files = await modelsDir.list().toList();

      for (final file in files) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          if (_isModelFile(modelType, fileName)) {
            await file.delete();

            // 清除版本记录
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('model_version_$modelType');
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('删除模型失败: $e');
      rethrow;
    }
  }

  /// 删除所有模型
  Future<void> deleteAllModels() async {
    try {
      final modelsDir = await getModelsDirectory();
      if (await modelsDir.exists()) {
        await modelsDir.delete(recursive: true);
      }

      // 清除所有版本记录
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('model_version_llm');
      await prefs.remove('model_version_tts');
      await prefs.remove('model_version_stt');
    } catch (e) {
      debugPrint('删除所有模型失败: $e');
      rethrow;
    }
  }

  // 辅助方法

  bool _isModelFile(String modelType, String fileName) {
    switch (modelType) {
      case 'llm':
        return fileName.endsWith('.gguf');
      case 'tts':
        // 支持 Piper (amy) 和 Supertonic TTS 模型
        return fileName.endsWith('.onnx') || fileName.endsWith('.json');
      case 'stt':
        return fileName.endsWith('.bin') && fileName.contains('whisper');
      default:
        return false;
    }
  }

  String _getModelFileName(String modelType, String url) {
    // 从 URL 提取文件名
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    return pathSegments.last;
  }
}

/// 模型配置响应
class ModelConfigResponse {
  final String mirror;
  final Map<String, ModelInfo> models;
  final List<MirrorInfo> availableMirrors;

  ModelConfigResponse({required this.mirror, required this.models, required this.availableMirrors});

  factory ModelConfigResponse.fromJson(Map<String, dynamic> json) {
    return ModelConfigResponse(
      mirror: json['mirror'] ?? '',
      models: (json['models'] as Map<String, dynamic>?)?.map((key, value) => MapEntry(key, ModelInfo.fromJson(value))) ?? {},
      availableMirrors: (json['available_mirrors'] as List<dynamic>?)?.map((e) => MirrorInfo.fromJson(e)).toList() ?? [],
    );
  }
}

/// 模型信息
class ModelInfo {
  final String url;
  final String displayName;
  final String size;
  final int sizeBytes;
  final String version;
  final String? sha256;
  final bool required;
  final String repo;
  final String filePath;

  ModelInfo({
    required this.url,
    required this.displayName,
    required this.size,
    required this.sizeBytes,
    required this.version,
    this.sha256,
    required this.required,
    required this.repo,
    required this.filePath,
  });

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      url: json['url'] ?? '',
      displayName: json['display_name'] ?? '',
      size: json['size'] ?? '',
      sizeBytes: json['size_bytes'] ?? 0,
      version: json['version'] ?? '',
      sha256: json['sha256'],
      required: json['required'] ?? true,
      repo: json['repo'] ?? '',
      filePath: json['file_path'] ?? '',
    );
  }
}

/// 镜像信息
class MirrorInfo {
  final String name;
  final String url;
  final bool isDefault;
  final int priority;
  final String? region;

  MirrorInfo({required this.name, required this.url, required this.isDefault, required this.priority, this.region});

  factory MirrorInfo.fromJson(Map<String, dynamic> json) {
    return MirrorInfo(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      isDefault: json['is_default'] ?? false,
      priority: json['priority'] ?? 0,
      region: json['region'],
    );
  }
}

/// 下载状态
enum ModelDownloadState { idle, downloading, completed, error }
