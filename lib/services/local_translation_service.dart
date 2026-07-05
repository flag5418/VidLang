import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidlang/services/model_copy_service.dart';
import 'package:vidlang/services/sentencepiece_tokenizer.dart';

/// MarianMT 本地翻译服务
/// 使用 MarianMT ONNX 模型进行英文→中文翻译
/// 模型加载后常驻内存，不自动释放
class LocalTranslationService {
  static LocalTranslationService? _instance;
  static LocalTranslationService get instance => _instance ??= LocalTranslationService._();
  LocalTranslationService._();

  OrtSession? _encoderSession;
  OrtSession? _decoderSession;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _modelDir;

  /// decoder_start_token_id = 65000 (pad)
  static const int decoderStartTokenId = 65000;

  /// eos_token_id = 0
  static const int eosTokenId = 0;

  /// vocab_size = 65001
  static const int vocabSize = 65001;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  /// 初始化翻译服务
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;

    _isLoading = true;

    try {
      // 首先确保模型文件已从 assets 复制到沙盒
      final modelsReady = await ModelCopyService.instance.copyModelsIfNeeded();
      if (!modelsReady) {
        debugPrint('模型文件复制失败，翻译服务无法初始化');
        _isLoading = false;
        return;
      }

      final tokenizerReady = await SentencePieceTokenizer.instance.initialize();
      if (!tokenizerReady) {
        debugPrint('SentencePiece tokenizer 初始化失败');
        _isLoading = false;
        return;
      }

      final modelDir = await _findModelDir();
      if (modelDir == null) {
        debugPrint('MarianMT 模型目录不存在');
        _isLoading = false;
        return;
      }

      _modelDir = modelDir;

      OrtEnv.instance.init();

      final encoderPath = '$_modelDir/encoder_model.onnx';
      final decoderPath = '$_modelDir/decoder_model.onnx';
      if (!await File(encoderPath).exists()) {
        debugPrint('encoder_model.onnx 不存在');
        _isLoading = false;
        return;
      }
      if (!await File(decoderPath).exists()) {
        debugPrint('decoder_model.onnx 不存在');
        _isLoading = false;
        return;
      }

      _isInitialized = true;
      debugPrint('MarianMT 翻译服务初始化成功');
    } catch (e) {
      debugPrint('MarianMT 翻译服务初始化失败: $e');
      _isInitialized = false;
    } finally {
      _isLoading = false;
    }
  }

  /// 查找模型目录
  Future<String?> _findModelDir() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final prodPath = '${appDir.path}/models/marianmt-onnx';
      if (await Directory(prodPath).exists()) {
        if (await File('$prodPath/encoder_model.onnx').exists() &&
            await File('$prodPath/decoder_model.onnx').exists() &&
            await File('$prodPath/tokenizer_data.json').exists()) {
          return prodPath;
        }
      }

      final currentDir = Directory.current.path;
      if (currentDir != '/' && currentDir != '//') {
        final devPath = '$currentDir/models/marianmt-onnx';
        if (await Directory(devPath).exists()) {
          if (await File('$devPath/encoder_model.onnx').exists() &&
              await File('$devPath/decoder_model.onnx').exists() &&
              await File('$devPath/tokenizer_data.json').exists()) {
            return devPath;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('查找 MarianMT 模型目录失败: $e');
      return null;
    }
  }

  /// 延迟加载 ONNX 模型（首次翻译时才加载）
  bool _ensureModelsLoaded() {
    if (_encoderSession != null && _decoderSession != null) {
      return true;
    }
    if (_modelDir == null) return false;

    try {
      if (_encoderSession == null) {
        final encoderPath = '$_modelDir/encoder_model.onnx';
        final encoderOptions = OrtSessionOptions()
          ..setIntraOpNumThreads(1)
          ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
        _encoderSession = OrtSession.fromFile(File(encoderPath), encoderOptions);
        debugPrint('MarianMT encoder 已加载');
      }

      if (_decoderSession == null) {
        final decoderPath = '$_modelDir/decoder_model.onnx';
        final decoderOptions = OrtSessionOptions()
          ..setIntraOpNumThreads(1)
          ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
        _decoderSession = OrtSession.fromFile(File(decoderPath), decoderOptions);
        debugPrint('MarianMT decoder 已加载');
      }

      return true;
    } catch (e) {
      debugPrint('MarianMT 模型加载失败: $e');
      return false;
    }
  }

  /// 翻译英文→中文
  Future<String> translate({required String text}) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) {
        return '翻译模型未就绪';
      }
    }

    if (!_ensureModelsLoaded()) {
      return '翻译模型加载失败';
    }

    try {
      final tokenizer = SentencePieceTokenizer.instance;

      var sourceIds = tokenizer.encode(text);

      // 单词/短语 tokenize 失败时，尝试添加上下文帮助分词
      if (sourceIds.isEmpty) {
        final words = text.split(RegExp(r'\s+'));
        if (words.length <= 3) {
          // 尝试多种上下文模式
          final contexts = [
            'the $text',
            '$text is',
            'I $text',
            'a $text',
          ];
          for (final ctx in contexts) {
            sourceIds = tokenizer.encode(ctx);
            if (sourceIds.isNotEmpty) break;
          }
        }
      }

      // tokenizer 失败 → 直接返回，不走 code-unit 兜底（会 produce 垃圾结果）
      if (sourceIds.isEmpty) {
        debugPrint('📝 [MarianMT] tokenizer 分词失败: "$text"');
        return '翻译失败';
      }

      // 输入长度限制：encoder 最大 128 token（含 BOS）
      if (sourceIds.length > 126) {
        debugPrint('📝 [MarianMT] 输入过长 (${sourceIds.length} tokens)，截断到 126');
        sourceIds = sourceIds.sublist(0, 126);
      }

      debugPrint('📝 [MarianMT] 输入: "$text" → sourceIds=$sourceIds');

      // MarianMT 编码器输入格式: [>>cmn_Hans<<, ...source_tokens]
      final inputIds = [5, ...sourceIds];
      final attentionMask = List<int>.filled(inputIds.length, 1);

      const maxEncLen = 128;
      final paddedIds = [...inputIds, ...List<int>.filled(maxEncLen - inputIds.length, 0)];
      final paddedMask = [...attentionMask, ...List<int>.filled(maxEncLen - attentionMask.length, 0)];

      debugPrint('📝 [MarianMT] paddedIds length=${paddedIds.length}');

      final encoderOutputs = await _runEncoder(paddedIds, paddedMask);

      debugPrint('📝 [MarianMT] encoder outputs count=${encoderOutputs.length}');

      final outputIds = await _runDecoder(encoderOutputs, paddedMask);

      debugPrint('📝 [MarianMT] decoder outputIds=$outputIds');

      for (final o in encoderOutputs) {
        (o as OrtValueTensor).release();
      }

      final result = tokenizer.decode(outputIds);
      debugPrint('📝 [MarianMT] 解码结果: "$result"');
      return result;
    } on RangeError catch (e) {
      debugPrint('翻译 RangeError: $e');
      return '翻译失败';
    } catch (e) {
      debugPrint('翻译失败: $e');
      return '翻译失败';
    }
  }

  /// 运行 Encoder
  Future<List<dynamic>> _runEncoder(List<int> inputIds, List<int> attentionMask) async {
    final inputIdsArray = Int64List.fromList(inputIds);
    final attentionMaskArray = Int64List.fromList(attentionMask);

    final inputIdsTensor = OrtValueTensor.createTensorWithDataList(inputIdsArray, [1, inputIds.length]);
    final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(attentionMaskArray, [1, attentionMask.length]);

    final inputs = {'input_ids': inputIdsTensor, 'attention_mask': attentionMaskTensor};

    final runOptions = OrtRunOptions();
    final outputs = _encoderSession!.run(runOptions, inputs);

    inputIdsTensor.release();
    attentionMaskTensor.release();
    runOptions.release();

    return outputs;
  }

  /// 运行 Decoder（贪心解码，支持 merged decoder with cache）
  Future<List<int>> _runDecoder(List<dynamic> encoderOutputs, List<int> encoderAttentionMask) async {
    final encoderOutput = encoderOutputs[0] as OrtValueTensor;
    final encoderAttentionMaskArray = Int64List.fromList(encoderAttentionMask);

    final encoderAttentionMaskTensor = OrtValueTensor.createTensorWithDataList(encoderAttentionMaskArray, [1, encoderAttentionMask.length]);

    final outputIds = <int>[decoderStartTokenId];
    const maxLength = 64;
    const numLayers = 6;
    const headDim = 64;
    const numHeads = 8;

    int lastToken = -1;
    int repeatCount = 0;

    // 用于缓存的 past_key_values（初始为零）
    List<OrtValueTensor> pastKeys = [];
    List<OrtValueTensor> pastValues = [];

    for (var step = 0; step < maxLength; step++) {
      final decoderInputIds = Int64List.fromList(outputIds);
      final decoderInputTensor = OrtValueTensor.createTensorWithDataList(decoderInputIds, [1, outputIds.length]);

      // 构建 inputs（包含 cache）
      final inputs = <String, OrtValueTensor>{
        'input_ids': decoderInputTensor,
        'encoder_hidden_states': encoderOutput,
        'encoder_attention_mask': encoderAttentionMaskTensor,
      };

      // 添加 past_key_values（merged decoder 需要）
      for (var i = 0; i < numLayers; i++) {
        // Decoder self-attention cache
        final decKeyShape = [1, numHeads, outputIds.length, headDim];
        final decKeyData = Float32List(1 * numHeads * outputIds.length * headDim);
        inputs['past_key_values.$i.decoder.key'] = OrtValueTensor.createTensorWithDataList(decKeyData, decKeyShape);
        inputs['past_key_values.$i.decoder.value'] = OrtValueTensor.createTensorWithDataList(decKeyData, decKeyShape);

        // Encoder-decoder cross-attention cache
        final encKeyShape = [1, numHeads, 128, headDim]; // 128 = encoder max len
        final encKeyData = Float32List(1 * numHeads * 128 * headDim);
        inputs['past_key_values.$i.encoder.key'] = OrtValueTensor.createTensorWithDataList(encKeyData, encKeyShape);
        inputs['past_key_values.$i.encoder.value'] = OrtValueTensor.createTensorWithDataList(encKeyData, encKeyShape);
      }

      // use_cache_branch
      final useCacheData = Int64List.fromList([1]);
      inputs['use_cache_branch'] = OrtValueTensor.createTensorWithDataList(useCacheData, [1]);

      final runOptions = OrtRunOptions();
      final outputs = _decoderSession!.run(runOptions, inputs);

      final logitsTensor = outputs[0] as OrtValueTensor;
      final dynamic rawValue = logitsTensor.value;
      List<double> lastTokenLogits;

      if (rawValue is List && rawValue.isNotEmpty) {
        final batch = rawValue[0];
        if (batch is List && batch.isNotEmpty) {
          final lastTokenLogit = batch.last;
          if (lastTokenLogit is List) {
            lastTokenLogits = lastTokenLogit.map((e) => (e as num).toDouble()).toList();
          } else {
            throw Exception('Unexpected tensor structure: lastToken is not a List');
          }
        } else {
          throw Exception('Unexpected tensor structure: batch is not a List');
        }
      } else {
        throw Exception('Unexpected tensor structure: root is not a List');
      }

      // 释放所有 inputs
      for (final o in outputs) {
        (o as OrtValueTensor).release();
      }
      for (final input in inputs.values) {
        input.release();
      }

      var maxLogit = lastTokenLogits[0];
      var maxIndex = 0;
      for (var i = 1; i < lastTokenLogits.length; i++) {
        if (lastTokenLogits[i] > maxLogit) {
          maxLogit = lastTokenLogits[i];
          maxIndex = i;
        }
      }

      // 死循环检测：连续重复同一 token 超过 5 次，强制停止
      if (maxIndex == lastToken) {
        repeatCount++;
        if (repeatCount >= 5) {
          debugPrint('⚠️ [Decoder] 死循环检测: token $maxIndex 重复 $repeatCount 次，停止');
          break;
        }
      } else {
        lastToken = maxIndex;
        repeatCount = 1;
      }

      debugPrint('🔍 [Decoder] step=$step maxIndex=$maxIndex maxLogit=${maxLogit.toStringAsFixed(2)} vocabSize=$vocabSize logitsLen=${lastTokenLogits.length}');

      // 跳过无效 token ID（-100 是 PyTorch ignore_index，>= vocabSize 越界）
      if (maxIndex < 0 || maxIndex >= vocabSize) {
        debugPrint('⚠️ [MarianMT] decoder 输出无效 token ID: $maxIndex, 跳过');
        break;
      }

      if (maxIndex == eosTokenId) {
        break;
      }

      outputIds.add(maxIndex);
    }

    encoderAttentionMaskTensor.release();
    return outputIds;
  }

  /// 释放资源
  void dispose() {
    _encoderSession?.release();
    _encoderSession = null;
    _decoderSession?.release();
    _decoderSession = null;
    OrtEnv.instance.release();
    _isInitialized = false;
  }
}
