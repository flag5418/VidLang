import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/local_ai_service.dart';

/// STT 统一结果
class SttResult {
  final String text;           // 识别文本
  final double? score;         // 发音评分（仅收费模式）
  final String? error;
  final bool success;

  const SttResult({
    required this.text,
    this.score,
    this.error,
    required this.success,
  });

  factory SttResult.error(String error) => SttResult(text: '', success: false, error: error);
}

/// 统一 STT 服务
/// 免费模式 → 不可用（本地 Whisper 已移除）
/// 收费模式 → 云端 声通 WebSocket（带发音评分）
class UnifiedSttService {
  static UnifiedSttService? _instance;
  static UnifiedSttService get instance => _instance ??= UnifiedSttService._();
  UnifiedSttService._();

  final LocalAiService _localAi = LocalAiService.instance;

  /// 识别音频文件
  Future<SttResult> recognize({
    required String audioPath,
    required SubscriptionMode mode,
  }) async {
    if (mode == SubscriptionMode.free) {
      return await _recognizeLocal(audioPath: audioPath);
    } else {
      return await _recognizeCloud(audioPath: audioPath);
    }
  }

  /// 本地 STT 已移除，免费模式不可用
  Future<SttResult> _recognizeLocal({required String audioPath}) async {
    return SttResult.error('STT 本地模型已移除，请使用云端模式');
  }

  /// 云端 STT（声通 WebSocket，带发音评分）
  Future<SttResult> _recognizeCloud({required String audioPath}) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        return SttResult.error('音频文件不存在');
      }

      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      final client = sb.Supabase.instance.client;
      final requestId = const Uuid().v4();

      final response = await client.functions.invoke(
        'ai-proxy',
        body: {
          'rule_code': 'ai_scorer',
          'scene': 'shadow_reading',
          'entry': 'recording',
          'request_id': requestId,
          'params': {
            'audio_base64': base64Audio,
          },
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['ok'] == true) {
        final result = data['result'] as Map<String, dynamic>?;
        final text = result?['text'] as String? ?? '';
        final score = (result?['overall_score'] as num?)?.toDouble();

        return SttResult(text: text, score: score, success: true);
      }

      final error = data['error'] as String? ?? data['message'] as String? ?? '声通评分失败';
      return SttResult.error(error);
    } catch (e) {
      debugPrint('云端 STT 失败: $e');
      return SttResult.error('云端 STT 失败: $e');
    }
  }
}
