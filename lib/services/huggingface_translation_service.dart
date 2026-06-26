import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 免费翻译服务
/// 优先使用 Google Translate 免费 API（无需 token）
/// 备选 HuggingFace Inference API
class FreeTranslationService {
  static FreeTranslationService? _instance;
  static FreeTranslationService get instance =>
      _instance ??= FreeTranslationService._();
  FreeTranslationService._();

  bool _googleAvailable = false;
  bool _hfAvailable = false;
  bool _checked = false;

  /// Google Translate 是否可用
  bool get isAvailable => _googleAvailable || _hfAvailable;

  /// 检查各 API 可用性
  Future<void> checkAvailability() async {
    if (_checked) return;

    // 测试 Google Translate
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      final url = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=zh-CN&dt=t&q=hello');
      final request = await client.getUrl(url);
      final response = await request.close().timeout(
            const Duration(seconds: 5),
          );
      final body = await response.transform(utf8.decoder).join();
      await response.drain();
      client.close();

      _googleAvailable = response.statusCode == 200 && body.contains('你好');
      debugPrint('Google Translate 可用: $_googleAvailable');
    } catch (e) {
      debugPrint('Google Translate 不可达: $e');
    }

    // 测试 HuggingFace (通过 hf-mirror 的 pipeline API)
    if (!_googleAvailable) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 5);
        final url = Uri.parse(
            'https://hf-mirror.com/api/pipeline/models/Helsinki-NLP/opus-mt-en-zh');
        final request = await client.getUrl(url);
        final response = await request.close().timeout(
              const Duration(seconds: 5),
            );
        await response.drain();
        client.close();
        _hfAvailable = response.statusCode == 200;
        debugPrint('HuggingFace pipeline API 可用: $_hfAvailable');
      } catch (e) {
        debugPrint('HuggingFace pipeline API 不可达: $e');
      }
    }

    _checked = true;
  }

  /// 翻译单条文本
  Future<String?> translate(String text) async {
    if (text.trim().isEmpty) return null;

    // 优先 Google Translate
    if (_googleAvailable) {
      final result = await _translateWithGoogle(text);
      if (result != null) return result;
    }

    // 备选 HuggingFace Inference
    if (_hfAvailable) {
      final result = await _translateWithHuggingFace(text);
      if (result != null) return result;
    }

    return null;
  }

  /// 通过 Google Translate 免费 API 翻译
  Future<String?> _translateWithGoogle(String text) async {
    try {
      final encoded = Uri.encodeComponent(text);
      final url = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=zh-CN&dt=t&q=$encoded');

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(url);
      final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200) {
        // 解析 Google Translate 响应格式: [[["你好","hello",null,null,10]],...]
        final List<dynamic> data = jsonDecode(body);
        if (data.isNotEmpty && data[0] is List) {
          final StringBuffer buffer = StringBuffer();
          for (final item in data[0]) {
            if (item is List && item.isNotEmpty) {
              buffer.write(item[0]);
            }
          }
          final result = buffer.toString();
          if (result.isNotEmpty) return result;
        }
      }
    } catch (e) {
      debugPrint('Google Translate 翻译失败: $e');
    }
    return null;
  }

  /// 通过 HuggingFace Inference API 翻译
  Future<String?> _translateWithHuggingFace(String text) async {
    try {
      // 尝试通过 hf-mirror 代理
      final url = Uri.parse(
          'https://hf-mirror.com/models/Helsinki-NLP/opus-mt-en-zh');

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(url);
      request.headers.set('Content-Type', 'application/json');
      request.add(utf8.encode(jsonEncode({'inputs': text})));

      final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(body);
        if (data.isNotEmpty && data[0]['translation_text'] != null) {
          return data[0]['translation_text'] as String;
        }
      }
    } catch (e) {
      debugPrint('HuggingFace 翻译失败: $e');
    }
    return null;
  }

  /// 批量翻译
  Future<List<String>> translateBatch(
    List<String> texts, {
    void Function(int current, int total)? onProgress,
  }) async {
    await checkAvailability();
    final results = <String>[];
    for (int i = 0; i < texts.length; i++) {
      final translated = await translate(texts[i]);
      results.add(translated ?? texts[i]);
      onProgress?.call(i + 1, texts.length);
      if (i < texts.length - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return results;
  }
}
