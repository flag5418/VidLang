import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidlang/services/sentencepiece_tokenizer.dart';

/// MarianMT 本地翻译服务
/// 使用 MarianMT ONNX 模型进行英文→中文翻译
/// encoder_model.onnx + decoder_model.onnx
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
      // 初始化 tokenizer
      final tokenizerReady = await SentencePieceTokenizer.instance.initialize();
      if (!tokenizerReady) {
        debugPrint('SentencePiece tokenizer 初始化失败');
        _isLoading = false;
        return;
      }

      // 查找模型目录
      final modelDir = await _findModelDir();
      if (modelDir == null) {
        debugPrint('MarianMT 模型目录不存在');
        _isLoading = false;
        return;
      }

      _modelDir = modelDir;

      // 初始化 ONNX Runtime
      OrtEnv.instance.init();

      // 仅验证文件存在，不立即加载（避免内存压力）
      final encoderPath = '$modelDir/encoder_model.onnx';
      final decoderPath = '$modelDir/decoder_model.onnx';
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
      // 只有在真的初始化了 session 后才打印 inputNames
      if (_encoderSession != null) {
        debugPrint('Encoder inputs: ${_encoderSession!.inputNames}');
      }
      if (_decoderSession != null) {
        debugPrint('Decoder inputs: ${_decoderSession!.inputNames}');
      }
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
      // 优先从 applicationDocumentsDirectory 查找（模拟器和真机都适用）
      final appDir = await getApplicationDocumentsDirectory();
      final prodPath = '${appDir.path}/models/marianmt-onnx';
      if (await Directory(prodPath).exists()) {
        // 确认关键文件存在
        if (await File('$prodPath/encoder_model.onnx').exists() &&
            await File('$prodPath/decoder_model.onnx').exists() &&
            await File('$prodPath/tokenizer_data.json').exists()) {
          return prodPath;
        }
      }

      // 回退：从 Directory.current 查找（仅在 macOS 开发时有效）
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

  /// 模型保活计时器，用于按需释放
  Timer? _releaseTimer;

  /// 保活时间（翻译完成后多久释放模型）
  static const _modelKeepAliveMs = 60000; // 60秒

  /// 延迟加载 ONNX 模型（首次翻译时才加载）
  bool _ensureModelsLoaded() {
    if (_encoderSession != null && _decoderSession != null) {
      // 取消之前的释放计时器
      _releaseTimer?.cancel();
      return true;
    }
    if (_modelDir == null) return false;

    try {
      // 加载 encoder
      if (_encoderSession == null) {
        final encoderPath = '$_modelDir/encoder_model.onnx';
        final encoderOptions = OrtSessionOptions()
          ..setIntraOpNumThreads(1)
          ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
        _encoderSession = OrtSession.fromFile(File(encoderPath), encoderOptions);
        debugPrint('MarianMT encoder 已加载');
      }

      // 加载 decoder
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

  /// 保活：取消即将执行的模型释放
  void keepAlive() {
    _releaseTimer?.cancel();
  }

  /// 启动模型释放计时器（翻译完成后调用）
  void _scheduleRelease() {
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(milliseconds: _modelKeepAliveMs), () {
      debugPrint('MarianMT 模型 60秒未使用，释放内存');
      _releaseModels();
    });
  }

  /// 释放 ONNX 模型内存（保留初始化状态，仅释放 session）
  void _releaseModels() {
    _encoderSession?.release();
    _encoderSession = null;
    _decoderSession?.release();
    _decoderSession = null;
    debugPrint('MarianMT 模型已释放');
  }

  /// 翻译英文→中文
  Future<String> translate({required String text}) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) {
        return '翻译模型未就绪';
      }
    }

    // 延迟加载 ONNX 模型（首次翻译时才加载，避免启动时内存压力）
    if (!_ensureModelsLoaded()) {
      return '翻译模型加载失败';
    }

    try {
      final tokenizer = SentencePieceTokenizer.instance;

      // 编码输入
      final sourceIds = tokenizer.encode(text);
      if (sourceIds.isEmpty) {
        return 'Tokenization 失败';
      }

      // MarianMT opus-mt-en-zh 翻译为中文需要添加目标语言 token
      // 5 对应 >>cmn_Hans<<
      final inputIds = [5, ...sourceIds];

      final attentionMask = List<int>.filled(inputIds.length, 1);

      // Pad to max length
      const maxEncLen = 128;
      final paddedIds = [...inputIds, ...List<int>.filled(maxEncLen - inputIds.length, 0)];
      final paddedMask = [...attentionMask, ...List<int>.filled(maxEncLen - attentionMask.length, 0)];

      // Encoder 推理
      final encoderOutputs = await _runEncoder(paddedIds, paddedMask);

      // Decoder 推理（贪心解码）
      final outputIds = await _runDecoder(encoderOutputs, paddedMask);

      // 释放 encoder 输出 tensor 内存
      for (final o in encoderOutputs) {
        (o as OrtValueTensor).release();
      }

      // 解码输出
      final result = tokenizer.decode(outputIds);

      // 启动模型释放计时器（60秒后释放内存）
      _scheduleRelease();

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

      // 获取 logits
      final logitsTensor = outputs[0] as OrtValueTensor;
      // ONNX 返回的多维数组实际上是 List 的嵌套，比如 [batch, seq_len, vocab_size]
      // 这里将其逐层解包，取出最后一个 token 的 logits
      final dynamic rawValue = logitsTensor.value;
      List<double> lastTokenLogits;

      if (rawValue is List && rawValue.isNotEmpty) {
        final batch = rawValue[0];
        if (batch is List && batch.isNotEmpty) {
          // batch 是一系列 tokens，我们取最后一个 token
          final lastToken = batch.last;
          if (lastToken is List) {
            // 确保将其安全转换为 List<double>
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

      // 释放 outputs（包括 logitsTensor，它们是同一个对象）
      for (final o in outputs) {
        (o as OrtValueTensor).release();
      }

      // 贪心解码
      var maxLogit = lastTokenLogits[0];
      var maxIndex = 0;
      for (var i = 1; i < lastTokenLogits.length; i++) {
        if (lastTokenLogits[i] > maxLogit) {
          maxLogit = lastTokenLogits[i];
          maxIndex = i;
        }
      }

      // 检查 EOS
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
    _decoderSession?.release();
    OrtEnv.instance.release();
    _isInitialized = false;
  }
}
