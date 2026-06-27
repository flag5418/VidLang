import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:vidlang/services/model_path_service.dart';

/// 内置模型资产提取器
/// 将 assets/models/ 下的模型文件释放到应用沙盒目录
class AssetsExtractor {
  /// 需要释放的内置模型资产列表
  /// 路径相对于 assets/ 目录
  static const List<String> _builtInModels = [
    // MarianMT 翻译模型
    'assets/models/marianmt-onnx/config.json',
    'assets/models/marianmt-onnx/decoder_model.onnx',
    'assets/models/marianmt-onnx/encoder_model.onnx',
    'assets/models/marianmt-onnx/generation_config.json',
    'assets/models/marianmt-onnx/source.spm',
    'assets/models/marianmt-onnx/special_tokens_map.json',
    'assets/models/marianmt-onnx/target.spm',
    'assets/models/marianmt-onnx/token_to_id.json',
    'assets/models/marianmt-onnx/tokenizer_config.json',
    'assets/models/marianmt-onnx/tokenizer_data.json',
    'assets/models/marianmt-onnx/vocab.json',

    // Supertonic TTS 模型
    'assets/models/supertonic/onnx/duration_predictor.onnx',
    'assets/models/supertonic/onnx/text_encoder.onnx',
    'assets/models/supertonic/onnx/tts.json',
    'assets/models/supertonic/onnx/unicode_indexer.bin',
    'assets/models/supertonic/onnx/vector_estimator.onnx',
    'assets/models/supertonic/onnx/vocoder.onnx',
    'assets/models/supertonic/voice.bin',

    // STT 模型
    'assets/models/stt/decoder.onnx',
    'assets/models/stt/encoder.onnx',
    'assets/models/stt/tokens.txt',
  ];

  /// 检查是否需要释放资产
  static Future<bool> _needsExtraction() async {
    // 检查所有模型是否完整
    final ttsComplete = await ModelPathService.isTtsModelComplete;
    final sttComplete = await ModelPathService.isSttModelComplete;
    final marianmtComplete = await ModelPathService.isMarianmtModelComplete;

    if (ttsComplete && sttComplete && marianmtComplete) {
      debugPrint('内置模型资产已存在于沙盒，跳过释放');
      return false;
    }

    debugPrint('模型资产不完整，需要释放: TTS=$ttsComplete, STT=$sttComplete, MarianMT=$marianmtComplete');
    return true;
  }

  /// 释放内置模型资产到沙盒
  static Future<void> extractBuiltInModelsIfNeed() async {
    try {
      if (!await _needsExtraction()) {
        return;
      }

      debugPrint('开始释放内置模型资产到沙盒...');
      int successCount = 0;
      int failCount = 0;

      // 获取应用文档目录（不是 models 子目录）
      final appDir = await getApplicationDocumentsDirectory();
      final baseDir = appDir.path;

      for (final assetPath in _builtInModels) {
        // 将 assets/xxx 转换为沙盒路径 xxx
        final relativePath = assetPath.replaceFirst('assets/', '');
        final targetFile = File('$baseDir/$relativePath');

        if (await targetFile.exists()) {
          successCount++;
          continue;
        }

        // 确保上级目录存在
        await targetFile.parent.create(recursive: true);

        try {
          final data = await rootBundle.load(assetPath);
          await targetFile.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            flush: true,
          );
          successCount++;
          debugPrint('释放文件成功: $assetPath');
        } catch (e) {
          failCount++;
          debugPrint('无法释放内置资产 $assetPath: $e');
        }
      }

      debugPrint('内置模型资产释放完成: 成功 $successCount, 失败 $failCount');
    } catch (e) {
      debugPrint('释放内置模型资产出错: $e');
    }
  }
}
