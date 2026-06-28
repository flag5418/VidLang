import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidlang/services/sentencepiece_tokenizer.dart';

/// MarianMT 本地翻译服务
/// 使用 MarianMT ONNX 模型进行英文→中文翻译
/// 模型加载后永久驻留，不自动释放
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

      final sourceIds = tokenizer.encode(text);
      if (sourceIds.isEmpty) {
        return 'Tokenization 失败';
      }

      final inputIds = [5, ...sourceIds];
      final attentionMask = List<int>.filled(inputIds.length, 1);

      const maxEncLen = 128;
      final paddedIds = [...inputIds, ...List<int>.filled(maxEncLen - inputIds.length, 0)];
      final paddedMask = [...attentionMask, ...List<int>.filled(maxEncLen - attentionMask.length, 0)];

      final encoderOutputs = await _runEncoder(paddedIds, paddedMask);

      final outputIds = await _runDecoder(encoderOutputs, paddedMask);

      for (final o in encoderOutputs) {
        (o as OrtValueTensor).release();
      }

      final result = tokenizer.decode(outputIds);
      return result;
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

  /// 运行 Decoder（贪心解码）
  Future<List<int>> _runDecoder(List<dynamic> encoderOutputs, List<int> encoderAttentionMask) async {
    final encoderOutput = encoderOutputs[0] as OrtValueTensor;
    final encoderAttentionMaskArray = Int64List.fromList(encoderAttentionMask);

    final encoderAttentionMaskTensor = OrtValueTensor.createTensorWithDataList(encoderAttentionMaskArray, [1, encoderAttentionMask.length]);

    final outputIds = <int>[decoderStartTokenId];
    const maxLength = 64;

    for (var step = 0; step < maxLength; step++) {
      final decoderInputIds = Int64List.fromList(outputIds);
      final decoderInputTensor = OrtValueTensor.createTensorWithDataList(decoderInputIds, [1, outputIds.length]);

      final inputs = {'input_ids': decoderInputTensor, 'encoder_hidden_states': encoderOutput, 'encoder_attention_mask': encoderAttentionMaskTensor};

      final runOptions = OrtRunOptions();
      final outputs = _decoderSession!.run(runOptions, inputs);

      final logitsTensor = outputs[0] as OrtValueTensor;
      final dynamic rawValue = logitsTensor.value;
      List<double> lastTokenLogits;

      if (rawValue is List && rawValue.isNotEmpty) {
        final batch = rawValue[0];
        if (batch is List && batch.isNotEmpty) {
          final lastToken = batch.last;
          if (lastToken is List) {
            lastTokenLogits = lastToken.map((e) => (e as num).toDouble()).toList();
          } else {
            throw Exception('Unexpected tensor structure: lastToken is not a List');
          }
        } else {
          throw Exception('Unexpected tensor structure: batch is not a List');
        }
      } else {
        throw Exception('Unexpected tensor structure: root is not a List');
      }

      for (final o in outputs) {
        (o as OrtValueTensor).release();
      }

      var maxLogit = lastTokenLogits[0];
      var maxIndex = 0;
      for (var i = 1; i < lastTokenLogits.length; i++) {
        if (lastTokenLogits[i] > maxLogit) {
          maxLogit = lastTokenLogits[i];
          maxIndex = i;
        }
      }

      if (maxIndex == eosTokenId) {
        decoderInputTensor.release();
        runOptions.release();
        break;
      }

      outputIds.add(maxIndex);
      decoderInputTensor.release();
      runOptions.release();
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
