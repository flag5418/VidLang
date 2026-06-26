import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

/// T5 本地翻译服务
/// 使用 ONNX Runtime 运行 T5-translate 模型
/// 支持英文→中文翻译
class LocalTranslationService {
  static LocalTranslationService? _instance;
  static LocalTranslationService get instance =>
      _instance ??= LocalTranslationService._();
  LocalTranslationService._();

  OrtSession? _encoderSession;
  OrtSession? _decoderSession;
  bool _isInitialized = false;
  bool _isLoading = false;

  // Tokenizer 相关
  Map<int, String> _idToToken = {};
  Map<String, int> _tokenToId = {};
  int _padTokenId = 0;
  int _eosTokenId = 1;
  int _maxLength = 512;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否正在加载
  bool get isLoading => _isLoading;

  /// 初始化翻译服务
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;

    _isLoading = true;

    try {
      // 查找模型目录
      final modelDir = await _findModelDir();
      if (modelDir == null) {
        debugPrint('T5 翻译模型目录不存在');
        _isLoading = false;
        return;
      }

      // 初始化 ONNX Runtime
      OrtEnv.instance.init();

      // 加载 tokenizer
      await _loadTokenizer(modelDir);

      // 加载 encoder
      final encoderPath = '$modelDir/encoder_model.onnx';
      if (!await File(encoderPath).exists()) {
        debugPrint('encoder_model.onnx 不存在');
        _isLoading = false;
        return;
      }

      final encoderOptions = OrtSessionOptions()
        ..setIntraOpNumThreads(4)
        ..setSessionGraphOptimizationLevel(
            GraphOptimizationLevel.ortEnableAll);
      _encoderSession = OrtSession.fromFile(File(encoderPath), encoderOptions);

      // 加载 decoder
      final decoderPath = '$modelDir/decoder_model_merged.onnx';
      if (!await File(decoderPath).exists()) {
        // 回退到普通 decoder
        final fallbackPath = '$modelDir/decoder_model.onnx';
        if (!await File(fallbackPath).exists()) {
          debugPrint('decoder_model.onnx 不存在');
          _isLoading = false;
          return;
        }
        final decoderOptions = OrtSessionOptions()
          ..setIntraOpNumThreads(4)
          ..setSessionGraphOptimizationLevel(
              GraphOptimizationLevel.ortEnableAll);
        _decoderSession =
            OrtSession.fromFile(File(fallbackPath), decoderOptions);
      } else {
        final decoderOptions = OrtSessionOptions()
          ..setIntraOpNumThreads(4)
          ..setSessionGraphOptimizationLevel(
              GraphOptimizationLevel.ortEnableAll);
        _decoderSession =
            OrtSession.fromFile(File(decoderPath), decoderOptions);
      }

      _isInitialized = true;
      debugPrint('T5 翻译服务初始化成功');
      debugPrint('Encoder inputs: ${_encoderSession!.inputNames}');
      debugPrint('Decoder inputs: ${_decoderSession!.inputNames}');
    } catch (e) {
      debugPrint('T5 翻译服务初始化失败: $e');
      _isInitialized = false;
    } finally {
      _isLoading = false;
    }
  }

  /// 查找模型目录
  Future<String?> _findModelDir() async {
    try {
      // 开发环境
      final currentDir = Directory.current.path;
      final devPath = '$currentDir/models/t5-translate-onnx';
      if (await Directory(devPath).exists()) {
        return devPath;
      }

      // 生产环境
      final appDir = await getApplicationDocumentsDirectory();
      final prodPath = '${appDir.path}/models/t5-translate-onnx';
      if (await Directory(prodPath).exists()) {
        return prodPath;
      }

      return null;
    } catch (e) {
      debugPrint('查找 T5 模型目录失败: $e');
      return null;
    }
  }

  /// 加载 tokenizer
  Future<void> _loadTokenizer(String modelDir) async {
    try {
      // 读取 spiece.model（SentencePiece）
      final spiecePath = '$modelDir/spiece.model';
      if (!await File(spiecePath).exists()) {
        debugPrint('spiece.model 不存在');
        return;
      }

      // 简化的 tokenizer 初始化
      // 实际应该解析 spiece.model，这里用简化版本
      _idToToken = {};
      _tokenToId = {};

      // 读取 tokenizer_config.json
      final configPath = '$modelDir/tokenizer_config.json';
      if (await File(configPath).exists()) {
        debugPrint('Tokenizer config loaded');
      }

      // 基础 token 映射（T5 标准）
      _padTokenId = 0;
      _eosTokenId = 1;
      _tokenToId['<pad>'] = 0;
      _tokenToId['</s>'] = 1;
      _tokenToId['<unk>'] = 2;
      _idToToken[0] = '<pad>';
      _idToToken[1] = '</s>';
      _idToToken[2] = '<unk>';
    } catch (e) {
      debugPrint('加载 tokenizer 失败: $e');
    }
  }

  /// 翻译文本
  Future<String> translate({
    required String text,
    String sourceLanguage = 'English',
    String targetLanguage = 'Chinese',
  }) async {
    if (!_isInitialized || _encoderSession == null || _decoderSession == null) {
      await initialize();
      if (!_isInitialized) {
        return '翻译模型未就绪';
      }
    }

    try {
      // 构建翻译前缀
      final prefix = 'translate $sourceLanguage to $targetLanguage: ';
      final inputText = '$prefix$text';

      // Tokenize
      final inputIds = _tokenize(inputText);
      if (inputIds.isEmpty) {
        return 'Tokenization 失败';
      }

      // Encoder 推理
      final encoderOutput = await _runEncoder(inputIds);

      // Decoder 推理（贪心解码）
      final outputIds = await _runDecoder(encoderOutput, inputIds.length);

      // Detokenize
      final result = _detokenize(outputIds);

      return result;
    } catch (e) {
      debugPrint('翻译失败: $e');
      return '翻译失败: $e';
    }
  }

  /// Tokenize 输入文本
  List<int> _tokenize(String text) {
    // 简化的 tokenization
    // 实际应该用 SentencePiece tokenizer
    final tokens = <int>[];

    // 添加 BOS token
    tokens.add(_padTokenId);

    // 简单的字符级 tokenization（仅用于演示）
    for (var i = 0; i < text.length && tokens.length < _maxLength - 1; i++) {
      final char = text[i];
      if (_tokenToId.containsKey(char)) {
        tokens.add(_tokenToId[char]!);
      } else {
        // 使用 UNK token
        tokens.add(2);
      }
    }

    // 添加 EOS token
    tokens.add(_eosTokenId);

    return tokens;
  }

  /// 运行 Encoder
  Future<OrtValueTensor> _runEncoder(List<int> inputIds) async {
    final inputIdsArray = Int64List.fromList(inputIds);
    final attentionMask = Int64List.fromList(
        List.generate(inputIds.length, (i) => i < inputIds.length ? 1 : 0));

    final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
      inputIdsArray,
      [1, inputIds.length],
    );
    final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(
      attentionMask,
      [1, inputIds.length],
    );

    final inputs = {
      'input_ids': inputIdsTensor,
      'attention_mask': attentionMaskTensor,
    };

    final runOptions = OrtRunOptions();
    final outputs = _encoderSession!.run(runOptions, inputs);

    // 获取 encoder 输出
    final encoderOutput = outputs[0] as OrtValueTensor;

    inputIdsTensor.release();
    attentionMaskTensor.release();
    runOptions.release();

    return encoderOutput;
  }

  /// 运行 Decoder（贪心解码）
  Future<List<int>> _runDecoder(
      OrtValueTensor encoderOutput, int inputLength) async {
    final outputIds = <int>[_padTokenId]; // decoder_start_token_id
    final maxLength = 128;

    for (var step = 0; step < maxLength; step++) {
      final decoderInputIds = Int64List.fromList(outputIds);

      final decoderInputTensor = OrtValueTensor.createTensorWithDataList(
        decoderInputIds,
        [1, outputIds.length],
      );

      final inputs = {
        'input_ids': decoderInputTensor,
        'encoder_hidden_states': encoderOutput,
      };

      final runOptions = OrtRunOptions();
      final outputs = _decoderSession!.run(runOptions, inputs);

      // 获取 logits
      final logitsTensor = outputs[0] as OrtValueTensor;
      final logits = logitsTensor.value as List<double>;

      // 获取最后一个 token 的 logits
      final vocabSize = logits.length ~/ outputIds.length;
      final lastTokenLogits =
          logits.sublist((outputIds.length - 1) * vocabSize, outputIds.length * vocabSize);

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
      if (maxIndex == _eosTokenId) {
        break;
      }

      outputIds.add(maxIndex);

      decoderInputTensor.release();
      runOptions.release();
    }

    return outputIds;
  }

  /// Detokenize 输出
  String _detokenize(List<int> tokenIds) {
    final buffer = StringBuffer();
    for (final id in tokenIds) {
      if (id == _padTokenId || id == _eosTokenId) continue;
      if (_idToToken.containsKey(id)) {
        buffer.write(_idToToken[id]);
      } else {
        buffer.write('<$id>');
      }
    }
    return buffer.toString().trim();
  }

  /// 释放资源
  void dispose() {
    _encoderSession?.release();
    _decoderSession?.release();
    OrtEnv.instance.release();
    _isInitialized = false;
  }
}
