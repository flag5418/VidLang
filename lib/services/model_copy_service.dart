import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 模型文件复制服务
/// 负责将打包在 assets 中的模型文件复制到应用沙盒目录
/// 因为 ONNX Runtime 需要从文件系统路径加载模型，无法直接从 assets 加载
class ModelCopyService {
  ModelCopyService._();
  static final ModelCopyService instance = ModelCopyService._();

  bool _hasCopied = false;

  /// 需要复制的模型文件列表（相对于 assets/models/marianmt-onnx/）
  static const List<String> _modelFiles = [
    'encoder_model.onnx',
    'decoder_model.onnx',
    'tokenizer_data.json',
    'vocab.json',
    'config.json',
    'source.spm',
    'target.spm',
    'special_tokens_map.json',
    'tokenizer_config.json',
    'generation_config.json',
    'token_to_id.json',
  ];

  /// 将模型文件从 assets 复制到沙盒
  /// 应在 LocalTranslationService 初始化之前调用
  Future<bool> copyModelsIfNeeded() async {
    if (_hasCopied) return true;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(p.join(appDir.path, 'models', 'marianmt-onnx'));

      // 检查目标目录是否已存在且完整
      if (await _isModelDirComplete(targetDir)) {
        debugPrint('模型文件已在沙盒中，跳过复制');
        _hasCopied = true;
        return true;
      }

      // 创建目标目录
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      debugPrint('开始从 assets 复制模型文件到沙盒...');

      // 复制每个文件
      int copiedCount = 0;
      for (final fileName in _modelFiles) {
        final assetPath = 'assets/models/marianmt-onnx/$fileName';
        final targetPath = p.join(targetDir.path, fileName);

        try {
          final ByteData data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List();
          await File(targetPath).writeAsBytes(bytes);
          copiedCount++;
          debugPrint('已复制: $fileName (${bytes.length} bytes)');
        } catch (e) {
          // 某些文件可能不存在于 assets 中，记录但不中断
          debugPrint('复制 $fileName 失败（可能 assets 中不存在）: $e');
        }
      }

      // 检查核心文件是否都存在
      final isComplete = await _isModelDirComplete(targetDir);
      if (isComplete) {
        debugPrint('模型文件复制完成，共 $copiedCount 个文件');
        _hasCopied = true;
        return true;
      } else {
        debugPrint('模型文件复制后仍不完整，请检查 assets 配置');
        return false;
      }
    } catch (e) {
      debugPrint('模型文件复制服务出错: $e');
      return false;
    }
  }

  /// 检查模型目录是否完整（包含核心必需文件）
  Future<bool> _isModelDirComplete(Directory dir) async {
    if (!await dir.exists()) return false;

    final coreFiles = [
      'encoder_model.onnx',
      'decoder_model.onnx',
      'tokenizer_data.json',
      'vocab.json',
    ];

    for (final fileName in coreFiles) {
      final file = File(p.join(dir.path, fileName));
      if (!await file.exists()) {
        return false;
      }
    }

    return true;
  }

  /// 强制重新复制（用于调试或重置）
  Future<bool> forceCopy() async {
    _hasCopied = false;
    return copyModelsIfNeeded();
  }

  /// 获取沙盒中的模型目录路径
  static Future<String> getModelDirPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'models', 'marianmt-onnx');
  }
}
