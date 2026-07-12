import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/unified_translation_service.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/widgets/app_dialogs.dart';

/// AI 释义测试工具
///
/// 用法：在任意页面调用 AiTestTool.run(context)
/// 或在 main.dart 的 DevTools 中调用
class AiTestTool {
  static final List<Map<String, dynamic>> _results = [];

  /// 测试单词列表（覆盖不同难度）
  static const _testWords = [
    'apple',
    'unprecedented',
    'serendipity',
    'however',
    'beautiful',
  ];

  /// 运行完整测试
  static Future<void> run(BuildContext context) async {
    _results.clear();

    // 测试 1: 免费模式（本地 MarianMT）
    await _testBatch('免费模式', SubscriptionMode.free);

    // 测试 2: 收费模式（云端 AI）
    await _testBatch('收费模式', SubscriptionMode.premium);

    // 显示结果
    _showResults(context);
  }

  /// 批量测试
  static Future<void> _testBatch(String label, SubscriptionMode mode) async {
    dev.log('═══ 开始测试: $label ═══', name: 'AiTest');

    for (final word in _testWords) {
      final stopwatch = Stopwatch()..start();
      WordDetail detail;
      String? error;

      try {
        if (mode == SubscriptionMode.free) {
          // 免费模式：走 UnifiedTranslationService（本地 MarianMT）
          detail = await UnifiedTranslationService.instance.translate(
            text: word,
            mode: mode,
          );
        } else {
          // 收费模式：走 AiService.getDefinition（云端 AI）
          detail = await AiService.getDefinition(
            word: word,
            billing: {'mode': 'premium'},
          );
        }
      } catch (e) {
        detail = WordDetail.error(word, '异常: $e');
        error = e.toString();
      }

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      // 分析结果
      final hasChinese = detail.definitions.any(
        (d) => _containsChinese(d.chineseMeaning),
      );
      final hasTranslation = detail.translation != null &&
          detail.translation!.trim().isNotEmpty;
      final chineseSource = hasChinese
          ? 'definitions.chineseMeaning'
          : hasTranslation
              ? 'translation'
              : '无中文';

      final result = {
        'mode': label,
        'word': word,
        'elapsedMs': elapsedMs,
        'success': detail.success,
        'error': error,
        'hasChinese': hasChinese || hasTranslation,
        'chineseSource': chineseSource,
        'source': detail.source,
        'definitionsCount': detail.definitions.length,
        'examplesCount': detail.standaloneExamples.length,
        'firstChineseMeaning': detail.definitions.isNotEmpty
            ? detail.definitions.first.chineseMeaning
            : detail.translation ?? 'N/A',
      };

      _results.add(result);

      dev.log(
        '[$label] $word: ${elapsedMs}ms | '
        'success=${detail.success} | '
        'hasChinese=${hasChinese || hasTranslation} | '
        'source=${detail.source} | '
        'chineseMeaning=${result['firstChineseMeaning']}',
        name: 'AiTest',
      );
    }
  }

  /// 检查是否包含中文字符
  static bool _containsChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  /// 显示测试结果弹窗 — 使用 AppConfirmDialog (TDesign 规范，支持 contentWidget)
  static void _showResults(BuildContext context) {
    AppConfirmDialog.show(
      context,
      title: 'AI 释义测试结果',
      content: '',
      confirmText: '复制并关闭',
      cancelText: '关闭',
      contentWidget: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _results.length,
          itemBuilder: (ctx, i) {
            final r = _results[i];
            return ListTile(
              dense: true,
              title: Text(
                '${r['mode']} - ${r['word']}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: r['success'] == true ? Colors.green : Colors.red,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('耗时: ${r['elapsedMs']}ms | 来源: ${r['source']}'),
                  Text('中文: ${r['firstChineseMeaning']}'),
                  if (r['error'] != null)
                    Text('错误: ${r['error']}', style: const TextStyle(color: Colors.red)),
                ],
              ),
            );
          },
        ),
      ),
      onConfirm: () {
        // 复制结果到剪贴板
        final buffer = StringBuffer();
        buffer.writeln('AI 释义测试结果');
        buffer.writeln('═══════════════════════');
        for (final r in _results) {
          buffer.writeln('模式: ${r['mode']}');
          buffer.writeln('单词: ${r['word']}');
          buffer.writeln('耗时: ${r['elapsedMs']}ms');
          buffer.writeln('成功: ${r['success']}');
          buffer.writeln('来源: ${r['source']}');
          buffer.writeln('中文: ${r['firstChineseMeaning']}');
          if (r['error'] != null) buffer.writeln('错误: ${r['error']}');
          buffer.writeln('───────────────────────');
        }
        Clipboard.setData(ClipboardData(text: buffer.toString()));
        AppToast.show(context, '结果已复制到剪贴板', type: ToastType.success);
      },
    );
  }

  /// 快速测试单个单词（用于调试）
  static Future<void> testSingleWord(
    String word, {
    SubscriptionMode mode = SubscriptionMode.premium,
  }) async {
    dev.log('═══ 快速测试: $word (${mode.name}) ═══', name: 'AiTest');

    final stopwatch = Stopwatch()..start();
    WordDetail detail;

    try {
      detail = await AiService.getDefinition(
        word: word,
        billing: mode == SubscriptionMode.premium ? {'mode': 'premium'} : null,
      );
    } catch (e) {
      detail = WordDetail.error(word, '异常: $e');
    }

    stopwatch.stop();

    dev.log(
      '结果: ${detail.success ? '✅' : '❌'} | '
      '${stopwatch.elapsedMilliseconds}ms | '
      'source=${detail.source} | '
      'definitions=${detail.definitions.length} | '
      'examples=${detail.standaloneExamples.length}',
      name: 'AiTest',
    );

    for (final d in detail.definitions) {
      dev.log(
        '  [${d.partOfSpeech}] ${d.chineseMeaning} | en=${d.englishMeaning}',
        name: 'AiTest',
      );
    }
  }
}
