/// AI 出题系统测试脚本
///
/// 使用方法：
/// 1. 在 Flutter 项目根目录运行: dart run test_ai_test_plan.dart
/// 2. 或者在 Dart PAD 中运行此代码
///
/// 功能：
/// - 随机选择一个已有字幕的视频资源
/// - 调用 ai-test-plan Edge Function 生成题目
/// - 详细打印请求和响应，便于调试
library;

import 'dart:convert';
import 'dart:io';

// Supabase 配置
const String supabaseUrl = 'https://tqehcadjuwodbmgmxzmf.supabase.co';
const String supabaseAnonKey = 'sb_publishable_aKICDtmL2aisDtOpNh88jQ_IZ3m_fuB';

/// 主测试函数
Future<void> main() async {
  print('🚀 AI 出题系统测试开始\n');
  print('=' * 60);

  // 1. 获取用户 ID（需要先登录）
  final userId = await _getUserId();
  if (userId == null) {
    print('❌ 无法获取用户 ID，请检查登录状态');
    return;
  }
  print('✅ 用户 ID: $userId');

  // 2. 查找可用的视频资源（有字幕的）
  final videoCode = await _findVideoWithSubtitles(userId);
  if (videoCode == null) {
    print('❌ 没有找到有字幕的视频资源');
    return;
  }
  print('✅ 选择视频: $videoCode');

  // 3. 测试出题功能
  await _testGeneratePlan(userId, videoCode);

  print('\n${'=' * 60}');
  print('🎉 测试完成');
}

/// 获取当前登录用户 ID
Future<String?> _getUserId() async {
  try {
    // 尝试从本地存储读取用户信息
    // 这里简化处理，实际应该通过 Supabase Auth 获取
    final result = await _supabaseGet('/auth/v1/user');
    if (result != null && result['id'] != null) {
      return result['id'] as String;
    }
    return null;
  } catch (e) {
    print('⚠️ 获取用户失败: $e');
    return null;
  }
}

/// 查找一个有字幕的视频资源
Future<String?> _findVideoWithSubtitles(String userId) async {
  print('\n🔍 正在查找有字幕的视频资源...');

  try {
    // 调用 subtitle-storage 的 list 操作列出所有字幕文件
    final response = await _invokeFunction('subtitle-storage', {
      'op': 'list',
      'folder_code': '', // 列出所有字幕
    });

    if (response == null || response['ok'] != true) {
      print('⚠️ 无法获取字幕列表: $response');
      return null;
    }

    final files = response['files'] as List?;
    if (files == null || files.isEmpty) {
      print('⚠️ 没有找到任何字幕文件');
      return null;
    }

    print('📁 找到 ${files.length} 个字幕文件:');
    for (var i = 0; i < files.length.clamp(0, 10); i++) {
      final file = files[i] as Map<String, dynamic>;
      print('   ${i + 1}. ${file['video_code']} (${file['size']} bytes)');
    }

    if (files.isNotEmpty) {
      // 返回第一个视频的 code
      final firstFile = files.first as Map<String, dynamic>;
      return firstFile['video_code'] as String?;
    }

    return null;
  } catch (e) {
    print('❌ 查找视频失败: $e');
    return null;
  }
}

/// 测试生成题目
Future<void> _testGeneratePlan(String userId, String videoCode) async {
  print('\n${'=' * 60}');
  print('📝 开始测试 AI 出题...');
  print('视频 Code: $videoCode');
  print('=' * 60);

  // 构造请求体（模拟 TestPage 的请求）
  final requestBody = {
    'request_id': 'test_${DateTime.now().millisecondsSinceEpoch}',
    'video_code': videoCode,
    'source_type': 'resource',
    'difficulty': 'intermediate',
    'config': {
      // 听力题型
      'listen_choose_count': 1,
      'listen_meaning_count': 1,
      'listen_reply_count': 0,
      // 阅读题型
      'definition_choice_count': 1,
      'spelling_count': 1,
      'reorder_count': 1,
      'translate_meaning_count': 1,
      'word_relation_count': 0,
      // 口语题型
      'word_pron_count': 0,
      'phrase_pron_count': 0,
      'sentence_pron_count': 0,
      // MCQ（旧版兼容）
      'mcq_count': 1,
    },
  };

  print('\n📤 请求体:');
  print(JsonEncoder.withIndent('  ').convert(requestBody));

  try {
    final startTime = DateTime.now();
    final response = await _invokeFunction('ai-test-plan', requestBody);
    final duration = DateTime.now().difference(startTime);

    print('\n📥 响应 (耗时 ${duration.inMilliseconds}ms):');
    if (response == null) {
      print('❌ 响应为空');
      return;
    }

    print(JsonEncoder.withIndent('  ').convert(response));

    // 解析响应
    final ok = response['ok'] as bool? ?? false;
    if (!ok) {
      final error = response['error'] as String? ?? 'unknown';
      final message = response['message'] as String? ?? '';
      print('\n❌ 出题失败!');
      print('   错误码: $error');
      print('   错误信息: $message');
      return;
    }

    // 成功的情况
    final billing = response['billing'] as Map<String, dynamic>?;
    final plan = response['plan'] as Map<String, dynamic>?;
    final title = response['title'] as String? ?? 'N/A';

    print('\n✅ 出题成功!');
    print('   标题: $title');

    if (billing != null) {
      print('   计费规则: ${billing['rule_code']}');
      print('   价格: ¥${billing['price_cny']}');
      print(
        '   余额变化: ${billing['balance_before']} → ${billing['balance_after']}',
      );
    }

    if (plan != null) {
      final items = plan['items'] as List?;
      if (items != null && items.isNotEmpty) {
        print('\n📊 生成的题目 (${items.length} 道):');
        for (var i = 0; i < items.length; i++) {
          final item = items[i] as Map<String, dynamic>;
          final type = item['type'] as String? ?? 'unknown';
          final refText =
              item['ref_text'] as String? ??
              item['sentence'] as String? ??
              item['display_text'] as String? ??
              item['masked'] as String? ??
              'N/A';

          print('\n   【题目 ${i + 1}】$type');
          print(
            '   参考文本: ${refText.length > 50 ? '${refText.substring(0, 50)}...' : refText}',
          );

          // 打印选项（如果有）
          final options = item['options'] as List?;
          if (options != null && options.isNotEmpty) {
            print('   选项: ${options.take(4).join(', ')}');
          }

          // 打印答案
          final answer = item['answer'];
          if (answer != null) {
            print('   答案: $answer');
          }
        }
      } else {
        print('⚠️ 没有生成任何题目');
      }
    }

    // 验证题目质量
    _validateItems(plan?['items']);
  } catch (e, stackTrace) {
    print('\n💥 测试异常:');
    print('   错误: $e');
    print('   堆栈: $stackTrace');
  }
}

/// 验证生成的题目质量
void _validateItems(dynamic items) {
  if (items is! List || items.isEmpty) {
    print('\n⚠️ 无法验证题目质量：题目列表为空');
    return;
  }

  print('\n🔍 题目质量验证:');
  int validCount = 0;
  int issueCount = 0;

  for (var i = 0; i < items.length; i++) {
    final item = items[i] as Map<String, dynamic>;
    final type = item['type'] as String? ?? 'unknown';
    List<String> issues = [];

    // 检查必要字段
    if (item['type'] == null) issues.add('缺少 type 字段');

    // 根据题型检查特定字段
    switch (type) {
      case 'listen_choose':
      case 'listen_meaning':
        if (item['ref_text'] == null && item['sentence'] == null) {
          issues.add('缺少参考文本');
        }
        break;
      case 'spelling':
        if (item['answer'] == null) issues.add('缺少答案');
        if (item['letter_pool'] == null) issues.add('缺少字母池');
        break;
      case 'reorder':
        if (item['options'] == null) issues.add('缺少选项');
        if (item['answer'] == null) issues.add('缺少正确顺序');
        break;
      case 'definition_choice':
        if (item['options'] == null) issues.add('缺少选项');
        break;
      default:
        break;
    }

    if (issues.isEmpty) {
      validCount++;
      print('   ✅ 题目 ${i + 1} ($type): 通过');
    } else {
      issueCount++;
      print('   ❌ 题目 ${i + 1} ($type): ${issues.join('; ')}');
    }
  }

  print(
    '\n📈 验证结果: $validCount/${items.length} 通过, $issueCount/${items.length} 有问题',
  );
}

/// 调用 Supabase Edge Function
Future<Map<String, dynamic>?> _invokeFunction(
  String functionName,
  Map<String, dynamic> body,
) async {
  try {
    final functionUrl = Uri.parse('$supabaseUrl/functions/v1/$functionName');

    print('\n🌐 调用 Edge Function: $functionName');
    print('   URL: $functionUrl');

    final client = HttpClient();
    final request = await client.postUrl(functionUrl);
    request.headers.set('Authorization', 'Bearer $supabaseAnonKey');
    request.headers.set('Content-Type', 'application/json');
    request.write(jsonEncode(body));
    final response = await request.close();

    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(responseBody) as Map<String, dynamic>;
    } else {
      print('⚠️ HTTP ${response.statusCode}: $responseBody');
      return jsonDecode(responseBody) as Map<String, dynamic>?;
    }
  } catch (e) {
    print('❌ 调用 Function 失败: $e');
    return null;
  }
}

/// GET 请求辅助
Future<Map<String, dynamic>?> _supabaseGet(String path) async {
  try {
    final getUrl = Uri.parse('$supabaseUrl$path');
    final client = HttpClient();
    final request = await client.getUrl(getUrl);
    request.headers.set('apikey', supabaseAnonKey);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close();

    if (response.statusCode == 200) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    return null;
  } catch (e) {
    return null;
  }
}
