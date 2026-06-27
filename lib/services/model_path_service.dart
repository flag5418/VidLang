import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 统一模型路径管理服务
/// 所有模型相关的路径都通过此类获取，避免硬编码路径
class ModelPathService {
  ModelPathService._();

  static String? _modelsDir;

  /// 获取模型根目录（沙盒中的 models/ 目录）
  static Future<String> get modelsDir async {
    if (_modelsDir != null) return _modelsDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _modelsDir = '${appDir.path}/models';
    return _modelsDir!;
  }

  /// 获取 TTS 模型目录
  static Future<String> get ttsModelDir async {
    return '${await modelsDir}/supertonic';
  }

  /// 获取 STT 模型目录
  static Future<String> get sttModelDir async {
    return '${await modelsDir}/stt';
  }

  /// 获取 MarianMT 翻译模型目录
  static Future<String> get marianmtModelDir async {
    return '${await modelsDir}/marianmt-onnx';
  }

  /// 获取 TTS 模型文件路径
  static Future<Map<String, String>> get ttsModelPaths async {
    final dir = await ttsModelDir;
    return {
      'durationPredictor': '$dir/onnx/duration_predictor.onnx',
      'textEncoder': '$dir/onnx/text_encoder.onnx',
      'vectorEstimator': '$dir/onnx/vector_estimator.onnx',
      'vocoder': '$dir/onnx/vocoder.onnx',
      'ttsJson': '$dir/onnx/tts.json',
      'unicodeIndexer': '$dir/onnx/unicode_indexer.bin',
      'voiceStyle': '$dir/voice.bin',
    };
  }

  /// 获取 STT 模型文件路径
  static Future<Map<String, String>> get sttModelPaths async {
    final dir = await sttModelDir;
    return {
      'encoder': '$dir/encoder.onnx',
      'decoder': '$dir/decoder.onnx',
      'tokens': '$dir/tokens.txt',
    };
  }

  /// 获取 MarianMT 模型文件路径
  static Future<Map<String, String>> get marianmtModelPaths async {
    final dir = await marianmtModelDir;
    return {
      'encoder': '$dir/encoder_model.onnx',
      'decoder': '$dir/decoder_model.onnx',
      'config': '$dir/config.json',
      'sourceSpm': '$dir/source.spm',
      'targetSpm': '$dir/target.spm',
    };
  }

  /// 检查模型文件是否存在
  static Future<bool> checkModelFiles(Map<String, String> paths) async {
    for (final entry in paths.entries) {
      final file = File(entry.value);
      if (!await file.exists()) {
        return false;
      }
    }
    return true;
  }

  /// 检查 TTS 模型是否完整
  static Future<bool> get isTtsModelComplete async {
    return checkModelFiles(await ttsModelPaths);
  }

  /// 检查 STT 模型是否完整
  static Future<bool> get isSttModelComplete async {
    return checkModelFiles(await sttModelPaths);
  }

  /// 检查 MarianMT 模型是否完整
  static Future<bool> get isMarianmtModelComplete async {
    return checkModelFiles(await marianmtModelPaths);
  }
}
