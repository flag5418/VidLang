import 'dart:developer' as dev;

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vidlang/models/shengtong_evaluation_result.dart';

/// 评测结果云端存储服务
///
/// 通过 evaluation-storage Edge Function 统一操作云端数据库，
/// 实现按类型存储 50 条最近记录，自动淘汰旧记录。
class EvaluationStorageService {
  static const _functionName = 'evaluation-storage';

  /// 保存评测结果到云端
  ///
  /// [evaluationType] 评测类型: 'word' | 'sentence' | 'paragraph'
  /// [result] 声通评测结构化结果
  /// [resourceType] 资源类型: video / article / music
  /// [resourceCode] 资源编码
  /// [resourceTitle] 资源标题
  /// [refText] 参考文本
  /// [durationMs] 录音时长（毫秒）
  /// [language] 语言，默认 'en'
  static Future<Map<String, dynamic>> saveEvaluation({
    required String evaluationType,
    required ShengtongEvaluationResult result,
    String? resourceType,
    String? resourceCode,
    String? resourceTitle,
    String? refText,
    int? durationMs,
    String? language,
  }) async {
    try {
      final client = Supabase.instance.client;
      final response = await client.functions.invoke(
        _functionName,
        body: {
          'action': 'save',
          'evaluation_type': evaluationType,
          'resource_type': resourceType,
          'resource_code': resourceCode,
          'resource_title': resourceTitle,
          'ref_text': refText ?? result.refText,
          'overall_score': result.overall,
          'fluency_score': result.fluency,
          'integrity_score': result.integrity,
          'accuracy_score': result.accuracy,
          'pronunciation_score': result.pronunciation,
          'raw_result': result.rawResult,
          'word_summary': result.words.map((w) => {
            'word': w.word,
            'score': w.score,
            'read_type': w.readType,
          }).toList(),
          'weak_dimensions': result.weakDimensions.take(2).map((e) => {
            'name': e.key,
            'score': e.value,
          }).toList(),
          'duration_ms': durationMs,
          'language': language ?? 'en',
        },
      );

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        return {'ok': false, 'error': 'empty_response'};
      }

      dev.log('✅ 评测结果已保存到云端: record_id=${data['record_id']}',
          name: 'EvaluationStorageService');
      return data;
    } catch (e, stack) {
      dev.log('❌ 保存评测结果失败: $e\n$stack',
          name: 'EvaluationStorageService');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// 获取历史评测记录
  ///
  /// [evaluationType] 可选，指定类型过滤
  /// [limit] 返回数量，默认 10
  /// [offset] 偏移量，默认 0
  static Future<Map<String, dynamic>> getHistory({
    String? evaluationType,
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final client = Supabase.instance.client;
      final response = await client.functions.invoke(
        _functionName,
        body: {
          'action': 'history',
          'evaluation_type': evaluationType,
          'limit': limit,
          'offset': offset,
        },
      );

      return response.data as Map<String, dynamic>? ??
          {'ok': false, 'error': 'empty_response'};
    } catch (e, stack) {
      dev.log('❌ 获取历史记录失败: $e\n$stack',
          name: 'EvaluationStorageService');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// 获取用户评测摘要（用于 AI 分析时提供历史上下文）
  ///
  /// [evaluationType] 可选，指定类型
  /// 注意：如果 Edge Function 不存在，静默返回空结果（不影响 AI 分析）
  static Future<Map<String, dynamic>> getSummary({
    String? evaluationType,
  }) async {
    try {
      final client = Supabase.instance.client;
      final response = await client.functions.invoke(
        _functionName,
        body: {
          'action': 'summary',
          'evaluation_type': evaluationType,
        },
      );

      return response.data as Map<String, dynamic>? ??
          {'ok': false, 'error': 'empty_response'};
    } catch (e, stack) {
      // 静默处理 404 错误（Edge Function 不存在时不影响 AI 分析）
      final errorStr = e.toString();
      if (errorStr.contains('404') || errorStr.contains('NOT_FOUND')) {
        return {'ok': false, 'error': 'function_not_found'};
      }
      dev.log('❌ 获取评测摘要失败: $e\n$stack',
          name: 'EvaluationStorageService');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// 检测评测类型（根据参考文本自动判断）
  static String detectEvaluationType(String? refText) {
    if (refText == null || refText.trim().isEmpty) return 'sentence';
    final trimmed = refText.trim();
    // 单词：无空格且长度较短
    if (!trimmed.contains(' ') && trimmed.length <= 50) return 'word';
    // 短句：100字符以内
    if (trimmed.length <= 100) return 'sentence';
    // 段落：100字符以上
    return 'paragraph';
  }
}
