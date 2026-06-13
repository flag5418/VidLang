import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/conversation_message.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/database_service.dart';

/// 对话会话管理服务
/// 负责调用 Edge Function 创建会话、结算会话
class ConversationService {
  static const _uuid = Uuid();

  /// 创建对话会话
  /// 调用 ai-conversation Edge Function
  /// 返回会话信息（含 WebSocket URL、API Key、instructions）
  static Future<ConversationSession> createSession({
    required String sourceType, // 'subtitle' | 'article'
    required String sourceCode,
    String voice = 'Ethan',
    String difficulty = 'intermediate',
  }) async {
    // 排他性登录校验
    AuthService.instance.ensureActiveSession();

    final client = sb.Supabase.instance.client;

    String? sourceTitle;
    List<Map<String, dynamic>>? subtitleItems;
    if (sourceType == 'subtitle') {
      try {
        final videos = await DatabaseService.findByCondition(
          () => VideoInfo(),
          where: 'code = ? AND is_deleted = 0',
          whereArgs: [sourceCode],
          limit: 1,
        );
        sourceTitle = videos.isNotEmpty ? videos.first.name : null;

        final subs = await DatabaseService.findByCondition(
          () => Subtitles(),
          where: 'video_code = ? AND is_deleted = 0',
          whereArgs: [sourceCode],
          orderBy: 'start_position ASC',
        );

        const maxItems = 250;
        const maxChars = 20000;
        var chars = 0;
        subtitleItems = [];
        for (final s in subs) {
          if (subtitleItems.length >= maxItems) break;
          final text = s.content.trim();
          if (text.isEmpty) continue;
          chars += text.length;
          if (chars > maxChars) break;
          subtitleItems.add({'content': text, 'content_translate': (s.contentTranslate ?? '').trim()});
        }
      } catch (_) {
        subtitleItems = null;
      }
    }

    final response = await client.functions.invoke(
      'ai-conversation',
      body: {
        'source_type': sourceType,
        'source_code': sourceCode,
        'voice': voice,
        'difficulty': difficulty,
        'source_title': ?sourceTitle,
        'subtitle_items': ?subtitleItems,
      },
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('AI 对话服务响应异常');
    }

    final ok = data['ok'] as bool? ?? false;
    if (!ok) {
      final error = data['error'] as String? ?? '';
      final message = data['message'] as String? ?? 'AI 对话服务调用失败';

      if (error == 'insufficient_balance') {
        throw InsufficientBalanceException(
          message: message,
          balanceCny: (data['balance_cny'] as num?)?.toDouble(),
          requiredCny: (data['required_cny'] as num?)?.toDouble(),
        );
      }
      throw Exception(message);
    }

    return ConversationSession.fromJson(data);
  }

  static Future<void> uploadSubtitlesToCloud(String videoCode) async {
    try {
      AuthService.instance.ensureActiveSession();
      final videos = await DatabaseService.findByCondition(() => VideoInfo(), where: 'code = ? AND is_deleted = 0', whereArgs: [videoCode], limit: 1);
      final title = videos.isNotEmpty ? videos.first.name : '';
      final list = await DatabaseService.findByCondition(
        () => Subtitles(),
        where: 'video_code = ? AND is_deleted = 0',
        whereArgs: [videoCode],
        orderBy: 'start_position ASC',
      );
      if (list.isEmpty) return;

      final items = list
          .map(
            (s) => {'start_position': s.startPosition, 'end_position': s.endPosition, 'content': s.content, 'content_translate': s.contentTranslate},
          )
          .toList();

      final client = sb.Supabase.instance.client;
      await client.functions.invoke('subtitle-storage', body: {'op': 'upload', 'video_code': videoCode, 'title': title, 'items': items});
    } catch (_) {}
  }

  static Future<void> deleteSubtitlesFromCloud(String videoCode) async {
    try {
      AuthService.instance.ensureActiveSession();
      final client = sb.Supabase.instance.client;
      await client.functions.invoke('subtitle-storage', body: {'op': 'delete', 'video_code': videoCode});
    } catch (_) {}
  }

  static Future<void> settleSession({
    required String conversationId,
    required int turnCount,
    required int durationSeconds,
    String? sourceType,
    String? sourceCode,
    String? sourceTitle,
  }) async {
    try {
      AuthService.instance.ensureActiveSession();

      final client = sb.Supabase.instance.client;
      final requestId = _uuid.v4();

      await client.functions.invoke(
        'ai-proxy',
        body: {
          'rule_code': 'ai_conversation_settle',
          'scene': 'conversation',
          'entry': 'end_session',
          'request_id': requestId,
          'params': {
            'conversation_id': conversationId,
            'turn_count': turnCount,
            'duration_seconds': durationSeconds,
            'billing': _billingMeta(sourceType: sourceType, sourceCode: sourceCode, sourceTitle: sourceTitle, actionName: 'end_session'),
          },
        },
      );
    } catch (e) {
      print('conversation settle error: $e');
    }
  }

  static Future<void> billTurn({
    required String conversationId,
    required int turnIndex,
    required bool isQuestion,
    String? sourceType,
    String? sourceCode,
    String? sourceTitle,
  }) async {
    try {
      AuthService.instance.ensureActiveSession();

      final client = sb.Supabase.instance.client;
      final ruleCode = isQuestion ? 'ai_conversation_question' : 'ai_conversation_answer';
      final requestId = 'conv_${conversationId}_${ruleCode}_$turnIndex';

      final response = await client.functions.invoke(
        'ai-proxy',
        body: {
          'rule_code': ruleCode,
          'scene': 'conversation',
          'entry': isQuestion ? 'question' : 'answer',
          'request_id': requestId,
          'params': {
            'conversation_id': conversationId,
            'turn_index': turnIndex,
            'billing': _billingMeta(
              sourceType: sourceType,
              sourceCode: sourceCode,
              sourceTitle: sourceTitle,
              actionName: isQuestion ? 'question' : 'answer',
            ),
          },
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('对话计费响应异常');
      }

      final ok = data['ok'] as bool? ?? false;
      if (!ok) {
        final error = data['error'] as String? ?? '';
        final message = data['message'] as String? ?? '对话计费失败';
        if (error == 'insufficient_balance') {
          throw InsufficientBalanceException(
            message: message,
            balanceCny: (data['balance_cny'] as num?)?.toDouble(),
            requiredCny: (data['required_cny'] as num?)?.toDouble(),
          );
        }
        throw Exception(message);
      }
    } catch (e) {
      rethrow;
    }
  }
}

Map<String, dynamic> _billingMeta({String? sourceType, String? sourceCode, String? sourceTitle, required String actionName}) {
  return {
    'action_key': 'ai_conversation',
    'action_label': 'AI 对话',
    'resource_type': sourceType == 'subtitle' ? 'video' : (sourceType ?? ''),
    'resource_code': sourceCode ?? '',
    'resource_title': sourceTitle ?? '',
    'source_page': 'conversation_page',
    'action_name': actionName,
  };
}

/// 余额不足异常
class InsufficientBalanceException implements Exception {
  final String message;
  final double? balanceCny;
  final double? requiredCny;

  InsufficientBalanceException({required this.message, this.balanceCny, this.requiredCny});

  @override
  String toString() => message;
}
