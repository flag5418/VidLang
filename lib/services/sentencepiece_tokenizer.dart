import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// SentencePiece UNIGRAM Tokenizer
/// 使用 Viterbi 算法对文本进行分词
/// 配合 MarianMT ONNX 模型使用
class SentencePieceTokenizer {
  static SentencePieceTokenizer? _instance;
  static SentencePieceTokenizer get instance => _instance ??= SentencePieceTokenizer._();
  SentencePieceTokenizer._();

  bool _isInitialized = false;

  /// token_string -> score (log probability)
  Map<String, double> _tokenScores = {};

  /// token_string -> model_id (用于编码，仅包含 Viterbi 分词所需数据)
  Map<String, int> _tokenIds = {};

  /// model_id -> token_string (用于解码，包含完整词表)
  Map<int, String> _idToToken = {};

  int _vocabSize = 0;
  int _maxTokenLength = 0;

  bool get isInitialized => _isInitialized;

  /// 初始化 tokenizer
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final data = await _loadTokenizerData();
      final vocabData = await _loadVocabData();
      if (data == null || vocabData == null) return false;

      _tokenScores = {};
      _tokenIds = {};
      _idToToken = {};

      for (final entry in data.entries) {
        final token = entry.key;
        final values = entry.value as List<dynamic>;
        _tokenScores[token] = (values[0] as num).toDouble();
        _tokenIds[token] = values[1] as int;
        if (token.length > _maxTokenLength) {
          _maxTokenLength = token.length;
        }
      }

      for (final entry in vocabData.entries) {
        final token = entry.key;
        final id = entry.value as int;
        _idToToken[id] = token;
      }

      _vocabSize = vocabData.length;
      _isInitialized = true;
      debugPrint('SentencePiece tokenizer 初始化成功: $_vocabSize tokens');
      return true;
    } catch (e) {
      debugPrint('SentencePiece tokenizer 初始化失败: $e');
      return false;
    }
  }

  /// 加载 tokenizer 数据
  Future<Map<String, dynamic>?> _loadTokenizerData() async {
    try {
      // 优先从 applicationDocumentsDirectory 查找（模拟器和真机都适用）
      final appDir = await getApplicationDocumentsDirectory();
      final prodPath = '${appDir.path}/models/marianmt-onnx/tokenizer_data.json';
      if (await File(prodPath).exists()) {
        final content = await File(prodPath).readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }

      // 回退：从 Directory.current 查找（仅在 macOS 开发时有效）
      final currentDir = Directory.current.path;
      if (currentDir != '/' && currentDir != '//') {
        final devPath = '$currentDir/models/marianmt-onnx/tokenizer_data.json';
        if (await File(devPath).exists()) {
          final content = await File(devPath).readAsString();
          return jsonDecode(content) as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      debugPrint('加载 tokenizer 数据失败: $e');
      return null;
    }
  }

  /// 加载完整的 vocab 数据
  Future<Map<String, dynamic>?> _loadVocabData() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final prodPath = '${appDir.path}/models/marianmt-onnx/vocab.json';
      if (await File(prodPath).exists()) {
        final content = await File(prodPath).readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }

      final currentDir = Directory.current.path;
      if (currentDir != '/' && currentDir != '//') {
        final devPath = '$currentDir/models/marianmt-onnx/vocab.json';
        if (await File(devPath).exists()) {
          final content = await File(devPath).readAsString();
          return jsonDecode(content) as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      debugPrint('加载 vocab 数据失败: $e');
      return null;
    }
  }

  /// SentencePiece 预处理
  /// 1. NFKC normalization
  /// 2. 开头加 ▁
  /// 3. 空格替换为 ▁
  String _preprocess(String text) {
    // 简化的 NFKC normalization
    // 对于英文文本，主要处理常见的 Unicode 字符
    text = text
        .replaceAll('\u2018', "'") // left single quote
        .replaceAll('\u2019', "'") // right single quote
        .replaceAll('\u201C', '"') // left double quote
        .replaceAll('\u201D', '"') // right double quote
        .replaceAll('\u2013', '-') // en dash
        .replaceAll('\u2014', '-') // em dash
        .replaceAll('\u2026', '...') // ellipsis
        .replaceAll('\u00A0', ' ') // non-breaking space
        .replaceAll('\u3000', ' ') // ideographic space
        .replaceAll(RegExp(r'\s+'), ' '); // normalize whitespace

    // 开头加 ▁，空格替换为 ▁
    text = '▁${text.trim().replaceAll(' ', '▁')}';
    return text;
  }

  /// Viterbi 分词算法
  /// 返回最优分词结果 (token 列表)
  List<String> tokenize(String text) {
    if (!_isInitialized) return [];

    text = _preprocess(text);
    final n = text.length;

    if (n == 0) return [];

    // dp[i] = (best_score, best_tokens)
    final scores = List<double>.filled(n + 1, double.negativeInfinity);
    final backpointers = List<List<String>?>.filled(n + 1, null);
    scores[0] = 0.0;
    backpointers[0] = [];

    for (int i = 0; i < n; i++) {
      if (scores[i] == double.negativeInfinity) continue;

      final maxLen = _maxTokenLength.clamp(1, n - i);
      for (int j = i + 1; j <= i + maxLen; j++) {
        final sub = text.substring(i, j);
        final tokenScore = _tokenScores[sub];
        if (tokenScore != null) {
          final newScore = scores[i] + tokenScore;
          if (newScore > scores[j]) {
            scores[j] = newScore;
            backpointers[j] = [...backpointers[i]!, sub];
          }
        }
      }
    }

    return backpointers[n] ?? [];
  }

  /// 将文本转换为 token IDs
  List<int> encode(String text) {
    final tokens = tokenize(text);
    return tokens.map((t) => _tokenIds[t] ?? 1).toList(); // 1 = <unk>
  }

  /// 将 token IDs 转换为文本（用于解码输出）
  String decode(List<int> ids) {
    final buffer = StringBuffer();
    for (final id in ids) {
      if (id == 0 || id == 65000 || id == 5) continue; // skip EOS, PAD, >>cmn_Hans<<
      final token = _idToToken[id];
      if (token != null) {
        buffer.write(token);
      }
    }
    return buffer.toString().replaceAll('▁', ' ').replaceAll(' ', ' ').trim();
  }
}
