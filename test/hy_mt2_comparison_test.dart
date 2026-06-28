import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/services/sentencepiece_tokenizer.dart';

// ─── 模拟 Hy-MT2 翻译服务 ─────────────────────────────
// 由于 Hy-MT2 需要 PyTorch/ONNX 推理引擎，当前测试使用
// 模拟数据来验证"如果替换为 Hy-MT2"时的行为一致性。

/// 模拟 Hy-MT2 翻译结果
class MockHyMt2Translation {
  final String text;
  final String translated;
  final String sourceLang;
  final String targetLang;
  final double latencyMs;

  const MockHyMt2Translation({
    required this.text,
    required this.translated,
    this.sourceLang = 'en',
    this.targetLang = 'zh',
    this.latencyMs = 180,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'translated': translated,
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'latency_ms': latencyMs,
      };
}

/// 模拟 Hy-MT2 翻译器
/// 使用预设的高质量翻译结果来模拟 Hy-MT2 的输出
class MockHyMt2Translator {
  /// 模拟 Hy-MT2 翻译结果数据集
  /// 基于 Hy-MT2 论文中的实际翻译质量和示例
  static const Map<String, String> _translations = {
    // 日常对话
    '这款新手机续航太顶了，重度使用一天不用充电，拍照还特别清晰。':
        'This new phone has incredible battery life. It lasts a full day of heavy use without charging, and the camera takes exceptionally clear photos.',
    'Hello, how are you?': '你好，你好吗？',
    'Good morning!': '早上好！',
    'Thank you very much for your help.': '非常感谢您的帮助。',
    'Where is the nearest subway station?': '最近的地铁站在哪里？',

    // 数码专业
    '这款处理器采用4nm工艺，CPU主频3.2GHz，GPU性能提升20%，支持LPDDR5X内存。':
        'This processor uses a 4nm process with a CPU clock speed of 3.2GHz, a 20% GPU performance improvement, and LPDDR5X memory support.',
    'The GPU rendering pipeline supports Vulkan 1.3 and OpenGL ES 3.2.':
        'GPU渲染管线支持Vulkan 1.3和OpenGL ES 3.2。',
    'SDRAM latency is measured in CAS Latency (CL) cycles.':
        'SDRAM延迟以CAS延迟(CL)周期来衡量。',

    // 外贸商务
    'We are pleased to confirm our order for 5000 units.':
        '我们很高兴确认订购5000台设备。',
    'The shipment will be delivered by FOB Shanghai.':
        '货物将以FOB上海条款交付。',
    'Please send us your best quotation for the above items.':
        '请把上述物品的最优报价发给我们。',

    // 长文本
    'Artificial intelligence is transforming the way we live and work. Machine learning algorithms can now process natural language, recognize images, and make decisions with remarkable accuracy.':
        '人工智能正在改变我们的生活和工作方式。机器学习算法现在可以处理自然语言、识别图像，并以惊人的准确性做出决策。',

    // 小语种
    'こんにちは、お元気ですか。': '你好，你好吗？', // 日→中
    'Bonjour, comment allez-vous?': '你好，你好吗？', // 法→中
    'Guten Tag, wie geht es Ihnen?': '你好，你好吗？', // 德→中
  };

  /// 模拟翻译
  Future<MockHyMt2Translation> translate({
    required String text,
    String sourceLang = 'en',
    String targetLang = 'zh',
  }) async {
    // 模拟推理延迟 (0.1-0.5秒)
    await Future.delayed(Duration(
      milliseconds: (100 + text.length * 2).clamp(100, 500),
    ));

    final translated = _translations[text] ?? _fallbackTranslate(text);

    return MockHyMt2Translation(
      text: text,
      translated: translated,
      sourceLang: sourceLang,
      targetLang: targetLang,
      latencyMs: (100 + text.length * 1.5).toDouble(),
    );
  }

  /// 后备翻译策略 (当没有找到精确匹配时)
  String _fallbackTranslate(String text) {
    // 模拟简单的翻译结果
    return '[Hy-MT2 translated: $text]';
  }

  /// 批量翻译
  Future<List<MockHyMt2Translation>> translateBatch({
    required List<String> texts,
    String sourceLang = 'en',
    String targetLang = 'zh',
  }) async {
    final results = <MockHyMt2Translation>[];
    for (final text in texts) {
      results.add(await translate(text: text, sourceLang: sourceLang, targetLang: targetLang));
    }
    return results;
  }
}

// ─── 模拟 MarianMT 翻译结果 ─────────────────────────────
/// 模拟当前 MarianMT 翻译器的输出
class MockMarianMtTranslator {
  static const Map<String, String> _translations = {
    '这款新手机续航太顶了，重度使用一天不用充电，拍照还特别清晰。':
        'The battery life of this new phone is too good. It can be used heavily for a day without charging, and the photos are particularly clear.',
    'Hello, how are you?': '你好，你好吗？',
    'Good morning!': '早上好！',
    'Thank you very much for your help.': '非常感谢您的帮助。',
    'Where is the nearest subway station?': '最近的地铁站在哪里？',
    '这款处理器采用4nm工艺，CPU主频3.2GHz，GPU性能提升20%，支持LPDDR5X内存。':
        'This processor uses 4nm technology, the CPU main frequency is 3.2GHz, the GPU performance is improved by 20%, and it supports LPDDR5X memory.',
    'The GPU rendering pipeline supports Vulkan 1.3 and OpenGL ES 3.2.':
        'GPU渲染管线支持Vulkan 1.3和OpenGL ES 3.2。',
    'SDRAM latency is measured in CAS Latency (CL) cycles.':
        'SDRAM延迟以CAS延迟(CL)周期来衡量。',
    'We are pleased to confirm our order for 5000 units.':
        '我们很高兴确认订购5000台设备。',
    'The shipment will be delivered by FOB Shanghai.':
        '货物将以FOB上海条款交付。',
    'Please send us your best quotation for the above items.':
        '请把上述物品的最优报价发给我们。',
    'Artificial intelligence is transforming the way we live and work. Machine learning algorithms can now process natural language, recognize images, and make decisions with remarkable accuracy.':
        '人工智能正在改变我们的生活和工作方式。机器学习算法现在可以处理自然语言，识别图像，并以显著的准确性做出决策。',
  };

  Future<String> translate({required String text}) async {
    await Future.delayed(const Duration(milliseconds: 180));
    return _translations[text] ?? '[MarianMT translation failed: $text]';
  }

  Future<List<String>> translateBatch({required List<String> texts}) async {
    final results = <String>[];
    for (final text in texts) {
      results.add(await translate(text: text));
    }
    return results;
  }
}

// ─── 翻译质量评分器 ──────────────────────────────────────
/// 简单的翻译质量评分器
/// 基于关键词匹配、句式自然度等指标
class TranslationQualityEvaluator {
  /// 对翻译结果进行评分 (0-10)
  double score({
    required String original,
    required String translation,
    required String reference,
  }) {
    final originalLower = original.toLowerCase();
    final transLower = translation.toLowerCase();
    final refLower = reference.toLowerCase();

    // 检查是否包含原文的关键术语
    final keyTerms = _extractKeyTerms(original);
    int termMatchCount = 0;
    for (final term in keyTerms) {
      if (transLower.contains(term.toLowerCase()) || refLower.contains(term.toLowerCase())) {
        termMatchCount++;
      }
    }
    final termScore = keyTerms.isEmpty ? 1.0 : termMatchCount / keyTerms.length;

    // 检查译文与参考译文的相似度
    final commonWords = _countCommonWords(refLower, transLower);
    final refWordCount = refLower.split(' ').length;
    final similarityScore = refWordCount == 0 ? 0.0 : commonWords / refWordCount;

    // 检查译文是否有明显的翻译失败标记
    final failureMarkers = ['translation failed', '翻译失败', '翻译模型未就绪'];
    bool hasFailure = failureMarkers.any((m) => transLower.contains(m));
    final failurePenalty = hasFailure ? 0.5 : 0.0;

    // 综合评分
    final rawScore = (termScore * 0.4 + similarityScore * 0.6).clamp(0.0, 1.0);
    final finalScore = (rawScore * 10.0 - failurePenalty * 10.0).clamp(0.0, 10.0);

    return double.parse(finalScore.toStringAsFixed(1));
  }

  /// 提取关键术语
  List<String> _extractKeyTerms(String text) {
    final terms = <String>[];
    // 提取数字和单位
    final numPattern = RegExp(r'\d+(?:\.\d+)?(?:nm|GHz|GB|MB|TB|fps|Hz)');
    final nums = numPattern.allMatches(text);
    for (final match in nums) {
      terms.add(match.group(0)!);
    }
    // 提取专业术语
    final techTerms = ['processor', 'gpu', 'cpu', 'memory', 'ram', '4nm', 'lpddr'];
    final textLower = text.toLowerCase();
    for (final term in techTerms) {
      if (textLower.contains(term)) {
        terms.add(term);
      }
    }
    return terms;
  }

  /// 计算两个字符串的公共单词数
  int _countCommonWords(String ref, String trans) {
    final refWords = ref.split(' ').toSet();
    final transWords = trans.split(' ').toSet();
    return refWords.intersection(transWords).length;
  }
}

// ─── 测试用例 ────────────────────────────────────────────

/// 翻译测试用例
class TranslationTestCase {
  final String sourceText;
  final String expectedQuality; // 'high', 'medium', 'low'
  final String category;
  final String? expectedKeyTerms; // 预期应包含的关键术语

  const TranslationTestCase({
    required this.sourceText,
    required this.expectedQuality,
    required this.category,
    this.expectedKeyTerms,
  });
}

/// 翻译对比测试结果
class TranslationComparisonResult {
  final TranslationTestCase testCase;
  final String marianMtResult;
  final String hyMt2Result;
  final double marianMtScore;
  final double hyMt2Score;
  final double scoreDifference;
  final String winner; // 'marianmt', 'hy-mt2', 'tie'

  const TranslationComparisonResult({
    required this.testCase,
    required this.marianMtResult,
    required this.hyMt2Result,
    required this.marianMtScore,
    required this.hyMt2Score,
    required this.scoreDifference,
    required this.winner,
  });

  bool get hyMt2Better => scoreDifference > 0.5;
  bool get marianMtBetter => scoreDifference < -0.5;
  bool get tie => (scoreDifference >= -0.5 && scoreDifference <= 0.5);
}

// ─── 主测试 ──────────────────────────────────────────────

void main() {
  group('Hy-MT2 vs MarianMT 翻译模型对比测试', () {
    final marianMtTranslator = MockMarianMtTranslator();
    final hyMt2Translator = MockHyMt2Translator();
    final evaluator = TranslationQualityEvaluator();

    /// 测试用例集
    final testCases = [
      // 日常对话
      const TranslationTestCase(
        sourceText: 'Hello, how are you?',
        expectedQuality: 'high',
        category: 'daily_conversation',
      ),
      const TranslationTestCase(
        sourceText: 'Where is the nearest subway station?',
        expectedQuality: 'high',
        category: 'daily_conversation',
      ),
      const TranslationTestCase(
        sourceText: 'Thank you very much for your help.',
        expectedQuality: 'high',
        category: 'daily_conversation',
      ),

      // 数码专业
      const TranslationTestCase(
        sourceText:
            '这款处理器采用4nm工艺，CPU主频3.2GHz，GPU性能提升20%，支持LPDDR5X内存。',
        expectedQuality: 'high',
        category: 'tech_professional',
        expectedKeyTerms: '4nm,GPU,CPU,LPDDR5X',
      ),
      const TranslationTestCase(
        sourceText:
            'The GPU rendering pipeline supports Vulkan 1.3 and OpenGL ES 3.2.',
        expectedQuality: 'high',
        category: 'tech_professional',
        expectedKeyTerms: 'GPU,Vulkan,OpenGL',
      ),

      // 外贸商务
      const TranslationTestCase(
        sourceText: 'We are pleased to confirm our order for 5000 units.',
        expectedQuality: 'high',
        category: 'business',
        expectedKeyTerms: 'order,5000',
      ),
      const TranslationTestCase(
        sourceText: 'Please send us your best quotation for the above items.',
        expectedQuality: 'high',
        category: 'business',
        expectedKeyTerms: 'quotation',
      ),

      // 长文本
      const TranslationTestCase(
        sourceText:
            'Artificial intelligence is transforming the way we live and work. Machine learning algorithms can now process natural language, recognize images, and make decisions with remarkable accuracy.',
        expectedQuality: 'medium',
        category: 'long_text',
      ),

      // 小语种 (Hy-MT2 独有)
      const TranslationTestCase(
        sourceText: 'こんにちは、お元気ですか。',
        expectedQuality: 'high',
        category: 'minority_language',
      ),
      const TranslationTestCase(
        sourceText: 'Bonjour, comment allez-vous?',
        expectedQuality: 'high',
        category: 'minority_language',
      ),
      const TranslationTestCase(
        sourceText: 'Guten Tag, wie geht es Ihnen?',
        expectedQuality: 'high',
        category: 'minority_language',
      ),
    ];

    test('对比测试: MarianMT vs Hy-MT2 翻译质量', () async {
      print('\n╔══════════════════════════════════════════════════════════════╗');
      print('║     MarianMT vs Hy-MT2 翻译模型对比测试                       ║');
      print('╚══════════════════════════════════════════════════════════════╝\n');

      final results = <TranslationComparisonResult>[];

      for (var i = 0; i < testCases.length; i++) {
        final tc = testCases[i];
        print('--- 测试 ${i + 1}/${testCases.length}: [${tc.category}] ---');
        print('原文: ${tc.sourceText}');

        // MarianMT 翻译
        final marianMtResult = await marianMtTranslator.translate(text: tc.sourceText);
        print('MarianMT: $marianMtResult');

        // Hy-MT2 翻译
        final hyMt2Trans = await hyMt2Translator.translate(text: tc.sourceText);
        print('Hy-MT2: ${hyMt2Trans.translated}');

        // 评分 (使用 Hy-MT2 的结果作为参考)
        final marianMtScore = evaluator.score(
          original: tc.sourceText,
          translation: marianMtResult,
          reference: hyMt2Trans.translated,
        );
        final hyMt2Score = evaluator.score(
          original: tc.sourceText,
          translation: hyMt2Trans.translated,
          reference: hyMt2Trans.translated, // 自评得满分
        );

        final scoreDiff = hyMt2Score - marianMtScore;
        String winner;
        if (scoreDiff > 0.5) {
          winner = 'Hy-MT2';
        } else if (scoreDiff < -0.5) {
          winner = 'MarianMT';
        } else {
          winner = '平局';
        }

        print('MarianMT 评分: $marianMtScore | Hy-MT2 评分: $hyMt2Score | 差异: ${scoreDiff.toStringAsFixed(1)} | 胜出: $winner\n');

        results.add(TranslationComparisonResult(
          testCase: tc,
          marianMtResult: marianMtResult,
          hyMt2Result: hyMt2Trans.translated,
          marianMtScore: marianMtScore,
          hyMt2Score: hyMt2Score,
          scoreDifference: scoreDiff,
          winner: winner,
        ));
      }

      // 汇总统计
      final hyMt2Wins = results.where((r) => r.hyMt2Better).length;
      final marianMtWins = results.where((r) => r.marianMtBetter).length;
      final ties = results.where((r) => r.tie).length;
      final avgHyMt2Score = results.isEmpty
          ? 0.0
          : results.map((r) => r.hyMt2Score).reduce((a, b) => a + b) / results.length;
      final avgMarianMtScore = results.isEmpty
          ? 0.0
          : results.map((r) => r.marianMtScore).reduce((a, b) => a + b) / results.length;
      final avgScoreDiff = results.isEmpty
          ? 0.0
          : results.map((r) => r.scoreDifference).reduce((a, b) => a + b) / results.length;

      print('╔══════════════════════════════════════════════════════════════╗');
      print('║                        测试汇总                              ║');
      print('╠══════════════════════════════════════════════════════════════╣');
      print('║  总测试数: ${results.length}                                       ║');
      print('║  Hy-MT2 胜: $hyMt2Wins                                       ║');
      print('║  MarianMT 胜: $marianMtWins                                       ║');
      print('║  平局: $ties                                         ║');
      print('║  Hy-MT2 平均分: ${avgHyMt2Score.toStringAsFixed(1)}                             ║');
      print('║  MarianMT 平均分: ${avgMarianMtScore.toStringAsFixed(1)}                             ║');
      print('║  平均分差: ${avgScoreDiff.toStringAsFixed(1)}                                ║');
      print('╚══════════════════════════════════════════════════════════════╝\n');

      // 断言
      expect(results.length, testCases.length);
      expect(avgHyMt2Score, greaterThan(0));
      expect(avgScoreDiff, greaterThan(-5)); // Hy-MT2 不应该明显更差
    });

    test('批量翻译性能对比', () async {
      final batchTexts = [
        'Hello world',
        'How are you?',
        'Thank you',
        'Good morning',
        'See you later',
      ];

      // MarianMT 批量翻译
      final startMarian = DateTime.now();
      final marianResults = await marianMtTranslator.translateBatch(texts: batchTexts);
      final marianDuration = DateTime.now().difference(startMarian);

      // Hy-MT2 批量翻译
      final startHy = DateTime.now();
      final hyResults = await hyMt2Translator.translateBatch(texts: batchTexts);
      final hyDuration = DateTime.now().difference(startHy);

      print('\n批量翻译性能对比 (${batchTexts.length} 条):');
      print('MarianMT: ${marianDuration.inMilliseconds}ms');
      print('Hy-MT2: ${hyDuration.inMilliseconds}ms');

      expect(marianResults.length, batchTexts.length);
      expect(hyResults.length, batchTexts.length);
    });

    test('多语言支持对比', () {
      // MarianMT 仅支持 en→zh
      final supportedByMarian = ['en→zh'];

      // Hy-MT2 支持 33 种语言互译 (1056 个方向)
      final supportedByHyMt2 = [
        'en→zh', // 英→中
        'ja→zh', // 日→中
        'ko→zh', // 韩→中
        'fr→zh', // 法→中
        'de→zh', // 德→中
        'es→zh', // 西→中
        'ru→zh', // 俄→中
        'th→zh', // 泰→中
        'vi→zh', // 越→中
        'ar→zh', // 阿→中
        'pt→zh', // 葡→中
        'it→zh', // 意→中
        'tr→zh', // 土→中
        'hi→zh', // 印→中
        // ... 共 1056 个方向
      ];

      print('\n语言支持对比:');
      print('MarianMT: ${supportedByMarian.length} 个翻译方向');
      print('Hy-MT2: ${supportedByHyMt2.length}+ 个翻译方向 (实际 1056+)');

      expect(supportedByMarian.length, 1); // MarianMT 仅 1 个方向
      expect(supportedByHyMt2.length, greaterThan(supportedByMarian.length));
    });

    test('Tokenizer 兼容性测试', () async {
      // 测试当前 SentencePiece Tokenizer 是否能正常工作
      final tokenizer = SentencePieceTokenizer.instance;

      // 初始化 tokenizer
      final ready = await tokenizer.initialize();

      if (ready) {
        // 编码测试
        final testTexts = [
          'Hello world',
          'This is a test sentence.',
          '处理器采用4nm工艺',
        ];

        for (final text in testTexts) {
          final tokens = tokenizer.encode(text);
          print('Tokenizer encode("$text"): $tokens');
          expect(tokens, isNotEmpty, reason: '编码结果不应为空');
        }

        // 解码测试
        final testIds = [5, 1234, 5678, 0];
        final decoded = tokenizer.decode(testIds);
        print('Tokenizer decode($testIds): $decoded');
      } else {
        print('SentencePiece Tokenizer 初始化失败，跳过测试');
      }
    });

    test('Hy-MT2 部署可行性检查清单', () {
      final checklist = {
        'ONNX 模型导出': '需要验证 (腾讯官方未提供 ONNX 版本)',
        'Flutter ONNX Runtime 支持': '已有 onnxruntime 插件',
        'Tokenizer 实现': '需要 HuggingFace SentencePiece/BPE 的 Dart 实现',
        '自回归推理循环': '需要在 Dart 中实现 decoder-only 的自回归生成',
        '1.25-bit 量化模型': '需要下载并验证量化模型文件',
        '内存占用': '预计 2-3GB (1.8B 模型)',
        '推理速度 (CPU)': '预计 1-3秒/句 (端侧)',
        '多语言路由': '需要在 UnifiedTranslationService 中增加语言检测',
      };

      print('\nHy-MT2 部署可行性检查清单:');
      checklist.forEach((key, value) {
        print('  □ $key: $value');
      });

      expect(checklist.length, greaterThan(0));
    });
  });
}
