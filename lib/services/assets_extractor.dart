import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class AssetsExtractor {
  static const List<String> _builtInModels = [
    'models/marianmt-onnx/config.json',
    'models/marianmt-onnx/decoder_model.onnx',
    'models/marianmt-onnx/decoder_with_past_model.onnx',
    'models/marianmt-onnx/encoder_model.onnx',
    'models/marianmt-onnx/generation_config.json',
    'models/marianmt-onnx/source.spm',
    'models/marianmt-onnx/special_tokens_map.json',
    'models/marianmt-onnx/target.spm',
    'models/marianmt-onnx/token_to_id.json',
    'models/marianmt-onnx/tokenizer_config.json',
    'models/marianmt-onnx/tokenizer_data.json',
    'models/marianmt-onnx/vocab.json',

    'models/supertonic/onnx/duration_predictor.onnx',
    'models/supertonic/onnx/text_encoder.onnx',
    'models/supertonic/onnx/tts.json',
    'models/supertonic/onnx/unicode_indexer.json',
    'models/supertonic/onnx/vector_estimator.onnx',
    'models/supertonic/onnx/vocoder.onnx',

    'models/supertonic/voice_styles/F1.json',
    'models/supertonic/voice_styles/F2.json',
    'models/supertonic/voice_styles/F3.json',
    'models/supertonic/voice_styles/M1.json',
    'models/supertonic/voice_styles/M2.json',
    'models/supertonic/voice_styles/M3.json',
  ];

  static Future<void> extractBuiltInModelsIfNeed() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');

      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      // 检查标识文件，如果已释放过则跳过
      final flagFile = File('${modelsDir.path}/.extracted_flag');
      if (await flagFile.exists()) {
        debugPrint('内置模型资产已释放过，跳过释放');
        return;
      }

      debugPrint('开始释放内置模型资产到沙盒...');
      for (final assetPath in _builtInModels) {
        final targetFile = File('${appDir.path}/$assetPath');
        if (await targetFile.exists()) continue;

        // 确保上级目录存在
        await targetFile.parent.create(recursive: true);

        try {
          final data = await rootBundle.load(assetPath);
          await targetFile.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            flush: true,
          );
          debugPrint('释放文件成功: $assetPath');
        } catch (e) {
          debugPrint('无法释放内置资产 $assetPath: $e');
        }
      }

      // 写入成功标识
      await flagFile.writeAsString('done');
      debugPrint('内置模型资产释放完成');
    } catch (e) {
      debugPrint('释放内置模型资产出错: $e');
    }
  }
}
