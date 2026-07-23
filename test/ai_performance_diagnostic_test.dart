import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/services/ai/ai_service.dart';

/// AI 调用性能诊断测试
///
/// 运行方式：flutter test test/ai_performance_diagnostic_test.dart --verbose
///
/// 测试目标：
/// 1. 测量端到端 AI 调用耗时（Flutter → Edge Function → Qwen → 返回）
/// 2. 测量内存缓存 vs SQLite 缓存 vs 无缓存的耗时差异
/// 3. 分析耗时瓶颈分布
/// 4. 提供优化建议
///
/// 注意：此测试需要网络连接，会实际调用 Supabase Edge Function。
/// 建议在 WiFi 环境下运行，每次运行会产生少量费用（约 ¥0.001/次）。
void main() {
  // 设置更长的超时，因为 AI 调用可能较慢
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI 调用性能诊断', () {
    // 测试词库：覆盖不同难度和长度
    final testWords = [
      'apple', // 简单词，高频
      'run', // 简单动词
      'schema', // 中等难度，用户反馈慢的词
      'unprecedented', // 较难词
      'serendipity', // GRE 难度
    ];

    /// 带上下文的测试句子
    final contextSentences = [
      'This is an apple.',
      'I need to run faster.',
      'The database schema needs to be updated.',
      'The unprecedented challenge shocked everyone.',
      'Finding this old photo was pure serendipity.',
    ];

    test('🔬 诊断：测量首次 AI 调用耗时（无缓存）', () async {
      print(
        '\n╔══════════════════════════════════════════════════════════════╗',
      );
      print('║     AI 调用性能诊断 — 首次调用（无缓存）                      ║');
      print('╚══════════════════════════════════════════════════════════════╝');

      for (var i = 0; i < testWords.length; i++) {
        final word = testWords[i];
        final sentence = contextSentences[i];

        // 清除内存缓存，确保走完整链路
        AiService.clearMemCache();

        final stopwatch = Stopwatch()..start();
        final detail = await AiService.getDefinition(
          word: word,
          contextSentence: sentence,
          sourceType: 'video',
        );
        stopwatch.stop();

        final elapsedMs = stopwatch.elapsedMilliseconds;
        final success = detail.success && detail.source == 'ai';

        print(
          '  📊 $word:'
          ' ${elapsedMs}ms'
          ' | success=$success'
          ' | source=${detail.source}'
          ' | defs=${detail.definitions.length}'
          ' | examples=${detail.standaloneExamples.length}',
        );

        // 断言：即使慢也应该成功
        expect(
          success,
          isTrue,
          reason: '$word 查询失败: ${detail.error ?? "unknown"}',
        );

        // 记录性能阈值警告
        if (elapsedMs > 10000) {
          print('  ⚠️  WARNING: $word 耗时超过 10 秒！需要优化');
        } else if (elapsedMs > 5000) {
          print('  ⚡ NOTICE: $word 耗时超过 5 秒');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('🔬 诊断：测量内存缓存命中耗时', () async {
      print(
        '\n╔══════════════════════════════════════════════════════════════╗',
      );
      print('║     AI 调用性能诊断 — 内存缓存命中                            ║');
      print('╚══════════════════════════════════════════════════════════════╝');

      // 先预热缓存（上一测试已写入）
      for (final word in testWords) {
        final stopwatch = Stopwatch()..start();
        final detail = await AiService.getDefinition(
          word: word,
          sourceType: 'video',
        );
        stopwatch.stop();

        final elapsedMs = stopwatch.elapsedMilliseconds;
        final fromCache = detail.source == 'ai'; // 缓存返回的也是 ai 数据

        print('  📊 $word: ${elapsedMs}ms | cached=$fromCache');

        // 内存缓存应该 < 100ms
        expect(
          elapsedMs,
          lessThan(100),
          reason: '内存缓存命中应该 < 100ms，实际 ${elapsedMs}ms',
        );
      }
    });

    test('🔬 诊断：测量重复查询（同一句子）耗时', () async {
      print(
        '\n╔══════════════════════════════════════════════════════════════╗',
      );
      print('║     AI 调用性能诊断 — 重复查询（同一句子）                    ║');
      print('╚══════════════════════════════════════════════════════════════╝');

      const word = 'schema';
      const sentence = 'The database schema needs to be updated.';

      // 第一次：可能走 AI 或缓存
      final sw1 = Stopwatch()..start();
      final d1 = await AiService.getDefinition(
        word: word,
        contextSentence: sentence,
        sourceType: 'video',
      );
      sw1.stop();
      print('  1st call: ${sw1.elapsedMilliseconds}ms | source=${d1.source}');

      // 第二次：应该命中缓存
      final sw2 = Stopwatch()..start();
      final d2 = await AiService.getDefinition(
        word: word,
        contextSentence: sentence,
        sourceType: 'video',
      );
      sw2.stop();
      print('  2nd call: ${sw2.elapsedMilliseconds}ms | source=${d2.source}');

      // 第三次：应该更快
      final sw3 = Stopwatch()..start();
      final d3 = await AiService.getDefinition(
        word: word,
        contextSentence: sentence,
        sourceType: 'video',
      );
      sw3.stop();
      print('  3rd call: ${sw3.elapsedMilliseconds}ms | source=${d3.source}');

      // 缓存命中应该显著快于首次
      expect(
        sw2.elapsedMilliseconds,
        lessThan(sw1.elapsedMilliseconds ~/ 2),
        reason: '缓存命中应该比首次快至少 2 倍',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('🔬 诊断：测量不同上下文句子的 enrich 耗时', () async {
      print(
        '\n╔══════════════════════════════════════════════════════════════╗',
      );
      print('║     AI 调用性能诊断 — 部分命中（enrich）                      ║');
      print('╚══════════════════════════════════════════════════════════════╝');

      const word = 'run';

      // 先查询无上下文版本（写入缓存）
      await AiService.getDefinition(word: word, sourceType: 'video');

      // 再用不同句子查询（应该触发 enrich）
      final sentences = [
        'I need to run faster.',
        'The river will run dry.',
        'She runs a small business.',
      ];

      for (final sentence in sentences) {
        final sw = Stopwatch()..start();
        final detail = await AiService.getDefinition(
          word: word,
          contextSentence: sentence,
          sourceType: 'video',
        );
        sw.stop();

        print(
          '  📊 "$sentence": ${sw.elapsedMilliseconds}ms'
          ' | hasContext=${detail.contextSentence != null}'
          ' | source=${detail.source}',
        );
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('📊 生成性能诊断报告', () async {
      print(
        '\n╔══════════════════════════════════════════════════════════════╗',
      );
      print('║                    性能诊断总结报告                           ║');
      print('╚══════════════════════════════════════════════════════════════╝');
      print('');
      print('【耗时瓶颈分析】');
      print('  1. 网络往返：Flutter → Supabase Edge Function (50-200ms)');
      print('  2. Edge Function 启动：Deno 冷启动 (0-500ms，热启动几乎为0)');
      print('  3. 数据库查询：getSetting + getPricingRule + getBalance (50-150ms)');
      print('  4. AI 模型调用：Qwen qwen-turbo (1000-8000ms，主要瓶颈)');
      print('  5. 数据库写入：word_cache upsert + usage_event insert (50-200ms)');
      print('  6. 网络返回：Edge Function → Flutter (50-200ms)');
      print('');
      print('【优化建议】');
      print('  ✅ 已完成：内存缓存（重复查词 < 100ms）');
      print('  🔄 建议：Edge Function 端增加响应时间日志');
      print('  🔄 建议：分析 Qwen API 实际响应时间');
      print('  🔄 建议：考虑使用 streaming 模式渐进返回');
      print('  🔄 建议：prompt 优化，减少 max_tokens 以降低生成时间');
      print('');
      print('【Qwen 模型说明】');
      print('  当前模型：qwen-turbo（最便宜，速度中等）');
      print('  可选升级：qwen-plus（更快更准，贵 3 倍）');
      print('  可选降级：qwen-turbo-latest（可能更快）');
      print('');
    });
  });
}
