import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/local_ai_service.dart';

/// TTS 统一结果
class TtsResult {
  final String audioPath;
  final bool success;
  final String? error;
  final String? format;

  const TtsResult({
    required this.audioPath,
    required this.success,
    this.error,
    this.format,
  });

  factory TtsResult.error(String error, {String? format}) => TtsResult(audioPath: '', success: false, error: error, format: format);
}

/// 统一 TTS 服务
/// 免费模式 → 本地原生 TTS (AVSpeechSynthesizer / Android TTS)
/// 收费模式 → 云端 ai-proxy Edge Function → 阿里云 TTS
class UnifiedTtsService {
  static UnifiedTtsService? _instance;
  static UnifiedTtsService get instance => _instance ??= UnifiedTtsService._();
  UnifiedTtsService._();

  final LocalAiService _localAi = LocalAiService.instance;

  /// 合成语音
  Future<TtsResult> synthesize({
    required String text,
    required SubscriptionMode mode,
  }) async {
    if (mode == SubscriptionMode.free) {
      return await _synthesizeLocal(text: text);
    } else {
      return await _synthesizeCloud(text: text);
    }
  }

  /// 本地 TTS（原生 AVSpeechSynthesizer / Android TTS）
  Future<TtsResult> _synthesizeLocal({required String text}) async {
    try {
      if (!LocalAiService.instance.isInitialized) {
        await LocalAiService.instance.initialize();
      }

      final audioPath = await _localAi.synthesizeToFile(text: text, outputPath: '');
      if (audioPath == null || !await File(audioPath).exists()) {
        return TtsResult.error('TTS 合成失败：无法生成音频');
      }

      return TtsResult(audioPath: audioPath, success: true, format: 'wav');
    } catch (e) {
      debugPrint('本地 TTS 失败: $e');
      return TtsResult.error('本地 TTS 失败: $e');
    }
  }

  /// 云端 TTS（阿里云 via ai-proxy）
  Future<TtsResult> _synthesizeCloud({required String text}) async {
    try {
      final client = sb.Supabase.instance.client;
      final requestId = const Uuid().v4();

      final response = await client.functions.invoke(
        'ai-proxy',
        body: {
          'rule_code': 'ai_tts',
          'scene': 'player',
          'entry': 'tts_btn',
          'request_id': requestId,
          'params': {'text': text},
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['ok'] == true) {
        final result = data['result'] as Map<String, dynamic>?;
        final audioBase64 = result?['audioBase64'] as String?;
        final format = result?['format'] as String? ?? 'mp3';

        if (audioBase64 != null && audioBase64.isNotEmpty) {
          final audioBytes = base64Decode(audioBase64);
          final tempDir = await getTemporaryDirectory();
          final fileName = 'tts_${DateTime.now().millisecondsSinceEpoch}.$format';
          final tempPath = '${tempDir.path}/$fileName';
          await File(tempPath).writeAsBytes(audioBytes);
          return TtsResult(audioPath: tempPath, success: true, format: format);
        }
      }

      return TtsResult.error('云端 TTS 合成失败');
    } catch (e) {
      debugPrint('云端 TTS 失败: $e');
      return TtsResult.error('云端 TTS 失败: $e');
    }
  }
}
