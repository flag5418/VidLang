import 'package:flutter/material.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vidlang/models/test_models.dart';
import 'package:vidlang/providers/test_provider.dart';
import 'package:vidlang/views/test/test_session_page.dart';

/// 评测首页 - 选择评测类型和题目配置
class TestHomePage extends ConsumerStatefulWidget {
  final List<Map<String, String>> words;
  final String? resourceCode;
  final String? resourceType;

  const TestHomePage({
    super.key,
    required this.words,
    this.resourceCode,
    this.resourceType,
  });

  @override
  ConsumerState<TestHomePage> createState() => _TestHomePageState();
}

class _TestHomePageState extends ConsumerState<TestHomePage> {
  String _testType = 'mixed';
  String _difficulty = 'intermediate';

  // 题型默认配比
  int _listenChooseCount = 3;
  int _meaningWriteCount = 3;
  int _sentenceDictationCount = 2;
  int _translateBothCount = 2;
  int _wordPronCount = 3;
  int _phrasePronCount = 2;
  int _sentencePronCount = 1;
  int _reorderCount = 2;
  int _spellingCount = 2;
  int _mcqCount = 3;

  int get _totalCount =>
      _listenChooseCount +
      _meaningWriteCount +
      _sentenceDictationCount +
      _translateBothCount +
      _wordPronCount +
      _phrasePronCount +
      _sentencePronCount +
      _reorderCount +
      _spellingCount +
      _mcqCount;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('评测设置'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSelector(),
                  SizedBox(height: adaptive.Adaptive.h(20)),
                  _buildDifficultySelector(),
                  SizedBox(height: adaptive.Adaptive.h(20)),
                  _buildQuestionConfig(),
                  SizedBox(height: adaptive.Adaptive.h(24)),
                  _buildStartButton(),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        state.error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('评测类型', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: adaptive.Adaptive.h(8)),
        Wrap(
          spacing: 8,
          children: [
            _choiceChip('综合', 'mixed'),
            _choiceChip('发音专项', 'pronunciation'),
            _choiceChip('词汇专项', 'vocabulary'),
            _choiceChip('语法专项', 'grammar'),
          ],
        ),
      ],
    );
  }

  Widget _choiceChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _testType == value,
      onSelected: (s) => setState(() => _testType = value),
    );
  }

  Widget _buildDifficultySelector() {
    const levels = ['beginner', 'elementary', 'intermediate', 'advanced', 'professional'];
    const labels = ['入门', '初级', '中级', '高级', '专业'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('难度', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: adaptive.Adaptive.h(8)),
        Wrap(
          spacing: 8,
          children: List.generate(levels.length, (i) {
            return ChoiceChip(
              label: Text(labels[i]),
              selected: _difficulty == levels[i],
              onSelected: (s) => setState(() => _difficulty = levels[i]),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildQuestionConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('题型配比（共 $_totalCount 题）',
            style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: adaptive.Adaptive.h(12)),
        _sliderRow('听音选词', _listenChooseCount, (v) => _listenChooseCount = v),
        _sliderRow('看义写词', _meaningWriteCount, (v) => _meaningWriteCount = v),
        _sliderRow('句中听写', _sentenceDictationCount, (v) => _sentenceDictationCount = v),
        _sliderRow('中英互译', _translateBothCount, (v) => _translateBothCount = v),
        _sliderRow('跟读单词', _wordPronCount, (v) => _wordPronCount = v),
        _sliderRow('跟读短语', _phrasePronCount, (v) => _phrasePronCount = v),
        _sliderRow('跟读句子', _sentencePronCount, (v) => _sentencePronCount = v),
        _sliderRow('组句题', _reorderCount, (v) => _reorderCount = v),
        _sliderRow('拼写填空', _spellingCount, (v) => _spellingCount = v),
        _sliderRow('选择题', _mcqCount, (v) => _mcqCount = v),
      ],
    );
  }

  Widget _sliderRow(String title, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(title, style: TextStyle(fontSize: adaptive.Adaptive.sp(13)))),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: '$value 题',
            onChanged: (v) => setState(() => onChanged(v.round())),
          ),
        ),
        SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: _totalCount == 0 ? null : _startTest,
        child: Text('开始评测 ($_totalCount 题)'),
      ),
    );
  }

  Future<void> _startTest() async {
    final config = <QuestionType, int>{
      if (_listenChooseCount > 0) QuestionType.listenChoose: _listenChooseCount,
      if (_meaningWriteCount > 0) QuestionType.meaningWrite: _meaningWriteCount,
      if (_sentenceDictationCount > 0)
        QuestionType.sentenceDictation: _sentenceDictationCount,
      if (_translateBothCount > 0)
        QuestionType.translateBoth: _translateBothCount,
      if (_wordPronCount > 0) QuestionType.wordPron: _wordPronCount,
      if (_phrasePronCount > 0) QuestionType.phrasePron: _phrasePronCount,
      if (_sentencePronCount > 0) QuestionType.sentencePron: _sentencePronCount,
      if (_reorderCount > 0) QuestionType.reorder: _reorderCount,
      if (_spellingCount > 0) QuestionType.spelling: _spellingCount,
      if (_mcqCount > 0) QuestionType.mcq: _mcqCount,
    };

    await ref.read(testProvider.notifier).startTest(
          words: widget.words,
          config: config,
          difficulty: _difficulty,
          testType: _testType,
          resourceCode: widget.resourceCode,
          resourceType: widget.resourceType,
        );

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TestSessionPage()),
      );
    }
  }
}
