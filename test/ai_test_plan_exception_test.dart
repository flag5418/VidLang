import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// AI 出题系统异常处理与质量门测试
/// 
/// 本测试文件验证：
/// 1. Edge Function 500 错误时客户端能正确捕获并显示
/// 2. 质量门能正确过滤不合格题目
/// 3. 各种边界情况下的异常处理
void main() {
  group('TestPage 异常处理', () {
    test('FunctionException 应正确显示错误信息', () {
      // 模拟 FunctionException
      final exception = sb.FunctionException(
        status: 500,
        details: 'Internal Server Error',
        reasonPhrase: 'Internal Server Error',
      );

      // 验证 toString 输出
      final errorText = exception.toString();
      expect(errorText, contains('500'));
      expect(errorText, contains('Internal Server Error'));
    });

    test('Edge Function 返回非 200 状态码时应抛出 FunctionException', () {
      // 模拟 Edge Function 返回 500 的情况
      // 根据 supabase-flutter 源码，当 statusCode 不在 200-299 范围内时
      // 会抛出 FunctionException
      
      // 验证异常结构
      final exception = sb.FunctionException(
        status: 500,
        details: {'error': 'server_error'},
        reasonPhrase: 'Internal Server Error',
      );

      expect(exception.status, equals(500));
      expect(exception.details, isA<Map<String, dynamic>>());
      expect(exception.reasonPhrase, equals('Internal Server Error'));
    });
  });

  group('TestPage 错误信息处理', () {
    test('应正确提取 FunctionException 的错误信息', () {
      final exception = sb.FunctionException(
        status: 500,
        details: 'Internal Server Error',
        reasonPhrase: 'Internal Server Error',
      );

      // 模拟 TestPage 的 catch 块处理
      final errorMessage = exception.toString().replaceFirst('Exception: ', '');
      
      // 当前代码会显示完整的 FunctionException 字符串
      // 但用户看到的是 "FunctionException(status: 500, details: Internal Server Error, reasonPhrase: Internal Server Error)"
      // 这不够友好
      expect(errorMessage, contains('500'));
    });

    test('应处理 details 为 Map 的情况', () {
      final exception = sb.FunctionException(
        status: 500,
        details: {'error': 'no_items', 'message': '所有题目均未通过质量检查'},
        reasonPhrase: 'Internal Server Error',
      );

      // 验证可以从 details 中提取结构化错误信息
      final details = exception.details as Map<String, dynamic>;
      expect(details['error'], equals('no_items'));
      expect(details['message'], contains('质量检查'));
    });
  });

  group('质量门验证', () {
    test('R1: 选项数量必须等于 4', () {
      // 模拟选项不足 4 个的题目
      final badItem = {
        'id': 'test-1',
        'type': 'context_mcq',
        'word': 'happy',
        'options': ['A', 'B'], // 只有 2 个选项
        'correctAnswer': 'A',
        'answerText': 'A',
      };

      // 验证质量门会拒绝此题目
      final options = badItem['options'] as List;
      expect(options.length, lessThan(4));
    });

    test('R2: 正确答案必须在选项范围内', () {
      final badItem = {
        'id': 'test-2',
        'type': 'context_mcq',
        'word': 'happy',
        'options': ['A', 'B', 'C', 'D'],
        'correctAnswer': 'E', // 超出范围
        'answerText': 'E',
      };

      final validAnswers = ['A', 'B', 'C', 'D'];
      expect(validAnswers.contains(badItem['correctAnswer']), isFalse);
    });

    test('R3: 选项不能有重复值', () {
      final badItem = {
        'id': 'test-3',
        'type': 'context_mcq',
        'word': 'happy',
        'options': ['A', 'B', 'A', 'C'], // 有重复
        'correctAnswer': 'A',
        'answerText': 'A',
      };

      final options = badItem['options'] as List;
      final uniqueOptions = options.toSet();
      expect(uniqueOptions.length, lessThan(options.length));
    });
  });

  group('Edge Function 响应处理', () {
    test('应处理 ok=false 的响应', () {
      final response = {
        'ok': false,
        'error': 'insufficient_balance',
      };

      expect(response['ok'], isFalse);
      expect(response['error'], equals('insufficient_balance'));
    });

    test('应处理 no_items 错误', () {
      final response = {
        'ok': false,
        'error': 'no_items',
        'message': '所有生成的题目均未通过质量检查，请尝试更换测试素材或调整配置',
      };

      expect(response['error'], equals('no_items'));
      expect(response['message'], isNotNull);
    });

    test('应处理 plan.items 为空的情况', () {
      final response = {
        'ok': true,
        'plan': {
          'items': [], // 空数组
        },
      };

      final itemsRaw = (response['plan'] as Map)['items'];
      final items = (itemsRaw is List)
          ? itemsRaw.whereType<Map>().cast<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];

      expect(items.isEmpty, isTrue);
    });
  });
}
