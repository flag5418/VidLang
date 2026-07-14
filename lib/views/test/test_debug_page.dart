import 'dart:convert';
import 'package:vidlang/utils/adaptive.dart' as adaptive;


import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/video_info.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/theme/theme.dart';

/// AI 出题系统调试页面
///
/// 用于测试和验证 ai-test-plan Edge Function 的逻辑
/// 可以在 App 内直接调用并查看详细的请求/响应日志
class TestDebugPage extends StatefulWidget {
  const TestDebugPage({super.key});

  @override
  State<TestDebugPage> createState() => _TestDebugPageState();
}

class _TestDebugPageState extends State<TestDebugPage> {
  final _uuid = const Uuid();
  bool _loading = false;
  String _log = '';
  List<Map<String, dynamic>>? _videoList;

  // 题型配置
  int _listenChooseCount = 1;
  int _listenMeaningCount = 1;
  int _listenReplyCount = 0;
  int _definitionChoiceCount = 1;
  int _spellingCount = 1;
  int _reorderCount = 1;
  int _translateMeaningCount = 1;
  int _wordRelationCount = 0;
  int _wordPronCount = 0;
  int _phrasePronCount = 0;
  int _sentencePronCount = 0;
  int _mcqCount = 1;

  String _difficulty = 'intermediate';
  String? _selectedVideoCode;

  @override
  void initState() {
    super.initState();
    _loadVideoList();
    _addLog('🚀 AI 出题调试页面已初始化');
  }

  Future<void> _loadVideoList() async {
    try {
      _addLog('🔍 正在加载视频资源列表...');
      final videos = await DatabaseService.findByCondition(
        () => VideoInfo(),
        where: 'is_deleted = 0',
        orderBy: 'updated_at DESC',
        limit: 20,
      );

      if (videos.isNotEmpty) {
        setState(() {
          _videoList = videos.map((v) {
            return {'code': v.code, 'name': v.name, 'type': 'video'};
          }).toList();
          _selectedVideoCode = _videoList!.first['code'] as String?;
        });
        _addLog('✅ 加载了 ${videos.length} 个视频资源');
      } else {
        _addLog('⚠️ 没有找到视频资源');
      }
    } catch (e) {
      _addLog('❌ 加载视频列表失败: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _log = '[$timestamp] $message\n$_log';
    });
    debugPrint('[TestDebug] $message');
  }

  Future<void> _testGeneratePlan() async {
    if (_selectedVideoCode == null || _selectedVideoCode!.isEmpty) {
      _addLog('❌ 请先选择一个视频资源');
      return;
    }

    setState(() => _loading = true);
    _addLog('\n${'=' * 60}');
    _addLog('📝 开始测试 AI 出题...');
    _addLog('视频 Code: $_selectedVideoCode');
    _addLog('难度: $_difficulty');

    try {
      final client = sb.Supabase.instance.client;
      final requestId = _uuid.v4();

      // 构造配置
      final config = {
        'listen_choose_count': _listenChooseCount,
        'listen_meaning_count': _listenMeaningCount,
        'listen_reply_count': _listenReplyCount,
        'definition_choice_count': _definitionChoiceCount,
        'spelling_count': _spellingCount,
        'reorder_count': _reorderCount,
        'translate_meaning_count': _translateMeaningCount,
        'word_relation_count': _wordRelationCount,
        'word_pron_count': _wordPronCount,
        'phrase_pron_count': _phrasePronCount,
        'sentence_pron_count': _sentencePronCount,
        'mcq_count': _mcqCount,
      };

      final requestBody = {
        'request_id': requestId,
        'video_code': _selectedVideoCode,
        'source_type': 'resource',
        'difficulty': _difficulty,
        'config': config,
      };

      _addLog('📤 请求体:');
      _addLog(const JsonEncoder.withIndent('  ').convert(requestBody));

      final startTime = DateTime.now();
      final res = await client.functions.invoke(
        'ai-test-plan',
        body: requestBody,
      );
      final duration = DateTime.now().difference(startTime);

      final data = res.data;

      _addLog('📥 响应 (耗时 ${duration.inMilliseconds}ms):');
      if (data != null) {
        _addLog(const JsonEncoder.withIndent('  ').convert(data));
      } else {
        _addLog('⚠️ 响应为空');
      }

      // 分析结果
      if (data is Map<String, dynamic>) {
        final ok = data['ok'] as bool? ?? false;
        if (ok) {
          _addLog('\n✅ 出题成功!');
          _analyzeSuccessResponse(data);
        } else {
          final error = data['error'] as String? ?? 'unknown';
          final message = data['message'] as String? ?? '';
          _addLog('\n❌ 出题失败!');
          _addLog('   错误码: $error');
          _addLog('   错误信息: $message');

          // 针对常见错误给出建议
          switch (error) {
            case 'no_content':
              _addLog('💡 建议: 该视频没有上传字幕，请先导入字幕并上传到云端');
              break;
            case 'insufficient_balance':
              _addLog('💡 建议: 余额不足，请充值后重试');
              break;
            case 'unauthorized':
              _addLog('💡 建议: 用户未登录或 token 已过期，请重新登录');
              break;
            default:
              _addLog('💡 请查看上方完整错误信息');
          }
        }
      }
    } catch (e, stackTrace) {
      _addLog('\n💥 异常:');
      _addLog('   错误: $e');
      _addLog('   堆栈: $stackTrace');
      _addLog('');
      _addLog('💡 可能的原因:');
      _addLog('   1. 网络连接问题');
      _addLog('   2. Edge Function 未部署或版本不兼容');
      _addLog('   3. 数据库 Migration 未执行');
      _addLog('   4. 用户认证问题');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _analyzeSuccessResponse(Map<String, dynamic> data) {
    try {
      final billing = data['billing'] as Map<String, dynamic>?;
      final plan = data['plan'] as Map<String, dynamic>?;
      final title = data['title'] as String? ?? 'N/A';

      _addLog('   标题: $title');

      if (billing != null) {
        _addLog('   计费规则: ${billing['rule_code']}');
        _addLog('   价格: ¥${billing['price_cny']}');
        if (billing['balance_before'] != null) {
          _addLog(
            '   余额变化: ${billing['balance_before']} → ${billing['balance_after']}',
          );
        }
      }

      if (plan != null) {
        final items = plan['items'] as List?;
        if (items != null && items.isNotEmpty) {
          _addLog('\n📊 生成的题目 (${items.length} 道):');

          for (var i = 0; i < items.length; i++) {
            final item = items[i] as Map<String, dynamic>;
            final type = item['type'] as String? ?? 'unknown';
            final refText =
                item['ref_text'] as String? ??
                item['sentence'] as String? ??
                item['display_text'] as String? ??
                item['masked'] as String? ??
                'N/A';

            final displayText = refText.length > 50
                ? '${refText.substring(0, 50)}...'
                : refText;

            _addLog('\n   【题目 ${i + 1}】$type');
            _addLog('   参考文本: $displayText');

            // 打印选项（如果有）
            final options = item['options'] as List?;
            if (options != null && options.isNotEmpty) {
              final optsStr = options
                  .take(4)
                  .map(
                    (o) => o.toString().substring(
                      0,
                      o.toString().length > 15 ? 15 : o.toString().length,
                    ),
                  )
                  .join(', ');
              _addLog('   选项: $optsStr');
            }

            // 打印答案
            final answer = item['answer'];
            if (answer != null) {
              _addLog('   答案: $answer');
            }
          }

          // 质量验证
          _validateItems(items);
        } else {
          _addLog('⚠️ 没有生成任何题目');
        }
      }
    } catch (e) {
      _addLog('⚠️ 解析响应时出错: $e');
    }
  }

  void _validateItems(List<dynamic> items) {
    _addLog('\n🔍 题目质量验证:');

    int validCount = 0;
    int issueCount = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i] as Map<String, dynamic>;
      final type = item['type'] as String? ?? 'unknown';
      List<String> issues = [];

      // 检查必要字段
      if (item['type'] == null) issues.add('缺少 type 字段');
      if (item['id'] == null) issues.add('缺少 id 字段');

      // 检查选项类题目的通用规则
      final options = item['options'] as List?;
      if (options != null) {
        // R1: 选项数量检查
        if (options.length != 4) {
          issues.add('选项数量应为4，实际为${options.length}');
        }

        // R3: 检查重复选项
        final uniqueOptions = options.toSet();
        if (uniqueOptions.length < options.length) {
          issues.add('选项有重复');
        }

        // R2: 答案有效性检查
        final answer = item['answer'];
        if (answer != null) {
          final answerStr = answer.toString();
          if (!options.contains(answerStr) &&
              !options.contains(int.tryParse(answerStr))) {
            issues.add('答案不在选项中');
          }
        }

        // R8: 检查答案泄露（选项中不应包含正确答案的文本）
        final answerText = item['answer_text'] as String? ??
            item['correct_text'] as String? ??
            item['word'] as String?;
        if (answerText != null && answerText.isNotEmpty) {
          for (final opt in options) {
            final optStr = opt.toString().toLowerCase();
            if (optStr.contains(answerText.toLowerCase()) &&
                optStr != answerText.toLowerCase()) {
              issues.add('选项可能泄露答案: $opt');
              break;
            }
          }
        }
      }

      // 根据题型检查特定字段
      switch (type) {
        case 'listen_choose':
        case 'listen_meaning':
          if (item['ref_text'] == null && item['sentence'] == null) {
            issues.add('缺少参考文本');
          }
          if (options == null || options.isEmpty) {
            issues.add('缺少选项');
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
        case 'translate_meaning':
        case 'context_mcq':
        case 'word_relation':
          if (options == null || options.isEmpty) issues.add('缺少选项');
          if (item['answer'] == null) issues.add('缺少答案');
          break;
        case 'listen_reply':
          if (item['sentence'] == null && item['ref_text'] == null) {
            issues.add('缺少问句');
          }
          if (item['answer'] == null) issues.add('缺少答案');
          break;
        case 'word_pron':
        case 'phrase_pron':
        case 'sentence_pron':
          if (item['ref_text'] == null) issues.add('缺少参考文本');
          break;
        default:
          break;
      }

      if (issues.isEmpty) {
        validCount++;
        _addLog('   ✅ 题目 ${i + 1} ($type): 通过');
      } else {
        issueCount++;
        _addLog('   ❌ 题目 ${i + 1} ($type): ${issues.join('; ')}');
      }
    }

    _addLog(
      '\n📈 验证结果: $validCount/${items.length} 通过, $issueCount/${items.length} 有问题',
    );

    // 如果问题率超过 50%，给出警告
    if (items.isNotEmpty && issueCount / items.length > 0.5) {
      _addLog('⚠️ 警告: 问题率超过50%，建议检查 Edge Function 逻辑或更换测试素材');
    }
  }

  void _clearLog() {
    setState(() {
      _log = '';
    });
    _addLog('📝 日志已清空');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 出题调试'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.delete),
            tooltip: '清空日志',
            onPressed: _clearLog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 视频选择
            Card(
              child: Padding(
                padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📹 选择视频资源',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: adaptive.Adaptive.h(context, 8)),
                    if (_videoList == null)
                      const Center(child: CircularProgressIndicator())
                    else if (_videoList!.isEmpty)
                      const Text(
                        '没有可用的视频资源',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedVideoCode,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: _videoList!.map((video) {
                          return DropdownMenuItem<String>(
                            value: video['code'] as String?,
                            child: Text('${video['name']} (${video['code']})'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedVideoCode = value);
                        },
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: adaptive.Adaptive.h(context, 12)),

            // 难度选择
            Card(
              child: Padding(
                padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎯 难度级别',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: adaptive.Adaptive.h(context, 8)),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'beginner', label: Text('初级')),
                        ButtonSegment(value: 'elementary', label: Text('初中级')),
                        ButtonSegment(value: 'intermediate', label: Text('中级')),
                        ButtonSegment(value: 'advanced', label: Text('高级')),
                        ButtonSegment(value: 'professional', label: Text('专业')),
                      ],
                      selected: {_difficulty},
                      onSelectionChanged: (s) {
                        setState(() => _difficulty = s.first);
                      },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: adaptive.Adaptive.h(context, 12)),

            // 题型配置
            Card(
              child: Padding(
                padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📝 题型配置',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: adaptive.Adaptive.h(context, 8)),

                    // 听力
                    _buildSectionHeader('👂 听力'),
                    _buildCountSlider(
                      '听音选词',
                      _listenChooseCount,
                      (v) => _listenChooseCount = v,
                    ),
                    _buildCountSlider(
                      '听音选义',
                      _listenMeaningCount,
                      (v) => _listenMeaningCount = v,
                    ),
                    _buildCountSlider(
                      '听音回复',
                      _listenReplyCount,
                      (v) => _listenReplyCount = v,
                    ),

                    const Divider(),

                    // 阅读
                    _buildSectionHeader('📖 阅读'),
                    _buildCountSlider(
                      '释义选择',
                      _definitionChoiceCount,
                      (v) => _definitionChoiceCount = v,
                    ),
                    _buildCountSlider(
                      '拼写填空',
                      _spellingCount,
                      (v) => _spellingCount = v,
                    ),
                    _buildCountSlider(
                      '组句排序',
                      _reorderCount,
                      (v) => _reorderCount = v,
                    ),
                    _buildCountSlider(
                      '翻译配对',
                      _translateMeaningCount,
                      (v) => _translateMeaningCount = v,
                    ),
                    _buildCountSlider(
                      '词汇关系',
                      _wordRelationCount,
                      (v) => _wordRelationCount = v,
                    ),

                    const Divider(),

                    // 口语
                    _buildSectionHeader('🗣️ 口语'),
                    _buildCountSlider(
                      '单词跟读',
                      _wordPronCount,
                      (v) => _wordPronCount = v,
                    ),
                    _buildCountSlider(
                      '短语跟读',
                      _phrasePronCount,
                      (v) => _phrasePronCount = v,
                    ),
                    _buildCountSlider(
                      '句子跟读',
                      _sentencePronCount,
                      (v) => _sentencePronCount = v,
                    ),

                    const Divider(),

                    // MCQ（旧版兼容）
                    _buildSectionHeader('📚 MCQ（旧版）'),
                    _buildCountSlider(
                      'MCQ 选择题',
                      _mcqCount,
                      (v) => _mcqCount = v,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: adaptive.Adaptive.h(context, 16)),

            // 测试按钮
            ElevatedButton.icon(
              onPressed: _loading ? null : _testGeneratePlan,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.play),
              label: Text(_loading ? '正在测试...' : '🚀 开始测试出题'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(context, 14)),
                textStyle: TextStyle(
                  fontSize: adaptive.Adaptive.sp(context, 16),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            SizedBox(height: adaptive.Adaptive.h(context, 16)),

            // 日志输出
            Card(
              color: AppColors.lightSurfaceElevated,
              child: Padding(
                padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '📋 日志输出',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: _clearLog,
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                    SizedBox(height: adaptive.Adaptive.h(context, 8)),
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 200,
                        maxHeight: 400,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 8)),
                      ),
                      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
                      child: SelectableText(
                        _log.isEmpty ? '点击"开始测试出题"按钮开始调试...' : _log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: adaptive.Adaptive.sp(context, 12),
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: adaptive.Adaptive.h(context, 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(top: adaptive.Adaptive.h(context, 8), bottom: adaptive.Adaptive.h(context, 4)),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCountSlider(
    String label,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(context, 4)),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              label: value.toString(),
              onChanged: (v) {
                setState(() => onChanged(v.toInt()));
              },
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
