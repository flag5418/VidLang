import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/widgets/app_dialogs.dart';

class TestPage extends StatefulWidget {
  final String? videoCode;
  final String videoTitle;
  final List<Map<String, dynamic>> seedWords;
  final List<String>? questionTypes;
  final int? questionsPerWord;
  final String? difficulty;

  const TestPage({
    super.key,
    this.videoCode,
    required this.videoTitle,
    this.seedWords = const [],
    this.questionTypes,
    this.questionsPerWord,
    this.difficulty,
  });

  bool get isWordBookMode => videoCode == null;

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  static const _uuid = Uuid();

  // 听
  int _listenChooseCount = 2;
  int _listenMeaningCount = 2;
  int _listenReplyCount = 2;

  // 读
  int _definitionChoiceCount = 2;
  int _spellingCount = 2;
  int _reorderCount = 2;
  int _translateMeaningCount = 2;
  int _wordRelationCount = 2;

  // 说
  int _wordPronCount = 0;
  int _phrasePronCount = 0;
  int _sentencePronCount = 0;

  bool _loading = false;
  String? _error;

  int get _totalCount =>
      _listenChooseCount +
      _listenMeaningCount +
      _listenReplyCount +
      _definitionChoiceCount +
      _spellingCount +
      _reorderCount +
      _translateMeaningCount +
      _wordRelationCount +
      _wordPronCount +
      _phrasePronCount +
      _sentencePronCount;

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      AuthService.instance.ensureActiveSession();
      if (!AuthService.instance.isLoggedIn) {
        throw Exception('未登录 Supabase');
      }
      if (widget.isWordBookMode && widget.seedWords.isEmpty) {
        throw Exception('请选择要测试的生词');
      }

      final client = sb.Supabase.instance.client;
      final requestId = _uuid.v4();
      final prefs = await SharedPreferences.getInstance();
      final difficulty = widget.difficulty ?? prefs.getString('app_difficulty_level') ?? 'intermediate';

      final config = {
        'listen_choose_count': _listenChooseCount,
        'listen_meaning_count': _listenMeaningCount,
        'listen_reply_count': _listenReplyCount,
        'definition_choice_count': _definitionChoiceCount,
        'spelling_count': _spellingCount,
        'reorder_count': widget.isWordBookMode ? 0 : _reorderCount,
        'translate_meaning_count': _translateMeaningCount,
        'word_relation_count': _wordRelationCount,
        'word_pron_count': _wordPronCount,
        'phrase_pron_count': _phrasePronCount,
        'sentence_pron_count': _sentencePronCount,
      };
      final res = await client.functions.invoke(
        'ai-test-plan',
        body: widget.isWordBookMode
            ? {
                'request_id': requestId,
                'source_type': 'word_book',
                'difficulty': difficulty,
                'config': config,
                'seed_words': widget.seedWords,
              }
            : {
                'request_id': requestId,
                'video_code': widget.videoCode,
                'difficulty': difficulty,
                'config': config,
              },
      );

      final data = res.data;
      if (data is! Map) throw Exception('服务响应异常');
      final ok = data['ok'] as bool? ?? false;
      if (!ok) {
        final error = data['error'] as String? ?? 'unknown_error';
        if (error == 'insufficient_balance') {
          throw Exception('余额不足，无法生成题目');
        }
        if (error == 'no_content') {
          throw Exception('云端没有该视频字幕内容，请先导入字幕并完成上传');
        }
        throw Exception('生成失败: $error');
      }

      final plan = data['plan'];
      final itemsRaw = (plan is Map) ? plan['items'] : null;
      final items = (itemsRaw is List) ? itemsRaw.whereType<Map>().cast<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
      if (items.isEmpty) throw Exception('没有生成任何题目');

      final billing = (data['billing'] is Map) ? (data['billing'] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final title = (data['title'] as String?)?.trim();

      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _TestRunPage(
            videoTitle: title != null && title.isNotEmpty ? title : widget.videoTitle,
            billing: billing,
            items: items,
            isWordBookMode: widget.isWordBookMode,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('综合测试', style: TextStyle(fontSize: 16.sp)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部标题
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            child: Text(
              widget.videoTitle,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
          ),
          // 题型配置滚动区域
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isWordBookMode) ...[
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '生词本测试按所选单词出题，提交后会累计复习次数。',
                        style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                  // 听
                  _QuestionGroupSection(
                    icon: Icons.headphones,
                    title: '听',
                    children: [
                      _QuestionTypeCard(
                        title: '原音选择',
                        description: '播放音频，选择当前播放的内容',
                        value: _listenChooseCount,
                        onChanged: (v) => setState(() => _listenChooseCount = v),
                      ),
                      _QuestionTypeCard(
                        title: '听音辩义',
                        description: '播放音频，选择和原义类似的解释',
                        value: _listenMeaningCount,
                        onChanged: (v) => setState(() => _listenMeaningCount = v),
                      ),
                      _QuestionTypeCard(
                        title: '听音回复',
                        description: '播放一个问题，根据听到的内容选择回答',
                        value: _listenReplyCount,
                        onChanged: (v) => setState(() => _listenReplyCount = v),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // 读
                  _QuestionGroupSection(
                    icon: Icons.menu_book,
                    title: '读',
                    children: [
                      _QuestionTypeCard(
                        title: '释义选择',
                        description: '根据给出的单词或翻译，选择正确的释义',
                        value: _definitionChoiceCount,
                        onChanged: (v) => setState(() => _definitionChoiceCount = v),
                      ),
                      _QuestionTypeCard(
                        title: '拼写填空',
                        description: '根据句子提示，拼写缺失的单词',
                        value: _spellingCount,
                        onChanged: (v) => setState(() => _spellingCount = v),
                      ),
                      if (!widget.isWordBookMode)
                        _QuestionTypeCard(
                          title: '组句',
                          description: '将打乱的词块排列成正确语序的句子',
                          value: _reorderCount,
                          onChanged: (v) => setState(() => _reorderCount = v),
                        ),
                      _QuestionTypeCard(
                        title: '英义互译',
                        description: '阅读英文段落，选择与原文类似的中文解释',
                        value: _translateMeaningCount,
                        onChanged: (v) => setState(() => _translateMeaningCount = v),
                      ),
                      _QuestionTypeCard(
                        title: '词性测试',
                        description: '根据单词选择同义词、反义词等（可多选）',
                        value: _wordRelationCount,
                        onChanged: (v) => setState(() => _wordRelationCount = v),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // 说
                  _QuestionGroupSection(
                    icon: Icons.mic,
                    title: '说',
                    children: [
                      _QuestionTypeCard(
                        title: '跟读单词',
                        description: '跟读展示的单词，录音评分',
                        value: _wordPronCount,
                        onChanged: (v) => setState(() => _wordPronCount = v),
                      ),
                      _QuestionTypeCard(
                        title: '跟读短语',
                        description: '跟读展示的短语，录音评分',
                        value: _phrasePronCount,
                        onChanged: (v) => setState(() => _phrasePronCount = v),
                      ),
                      _QuestionTypeCard(
                        title: '跟读句子',
                        description: '跟读展示的句子，录音评分',
                        value: _sentencePronCount,
                        onChanged: (v) => setState(() => _sentencePronCount = v),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // 错误提示
                  if (_error != null)
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(12.r)),
                      child: Text(
                        _error!,
                        style: TextStyle(fontSize: 13.sp, color: colorScheme.onErrorContainer),
                      ),
                    ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),
          // 底部操作栏
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.quiz_outlined, size: 14.sp, color: colorScheme.onSurfaceVariant),
                    SizedBox(width: 6.w),
                    Text(
                      '共 $_totalCount 题 · 每次随机出题，请认真作答',
                      style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                SizedBox(
                  height: 48.h,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_loading || _totalCount == 0) ? null : _start,
                    child: _loading
                        ? SizedBox(
                            width: 18.r,
                            height: 18.r,
                            child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                          )
                        : Text('开始', style: TextStyle(fontSize: 15.sp)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 题型分组区域
class _QuestionGroupSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _QuestionGroupSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 18.sp, color: colorScheme.primary),
            SizedBox(width: 6.w),
            Text(
              title,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colorScheme.primary),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        ...children.expand((child) => [child, SizedBox(height: 8.h)]),
      ],
    );
  }
}

/// 题型配置卡片：标题 + 说明 + 数量计数器
class _QuestionTypeCard extends StatelessWidget {
  final String title;
  final String description;
  final int value;
  final ValueChanged<int> onChanged;

  const _QuestionTypeCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                ),
                SizedBox(height: 2.h),
                Text(
                  description,
                  style: TextStyle(fontSize: 11.sp, color: colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          _StepButton(icon: Icons.remove, onTap: value <= 0 ? null : () => onChanged(value - 1)),
          SizedBox(width: 10.w),
          SizedBox(
            width: 28.w,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
          ),
          SizedBox(width: 10.w),
          _StepButton(icon: Icons.add, onTap: value >= 20 ? null : () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

/// 步进按钮
class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.r,
        height: 32.r,
        decoration: BoxDecoration(
          color: disabled ? colorScheme.surfaceContainerHighest : colorScheme.primary,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(icon, size: 16.sp, color: disabled ? colorScheme.onSurfaceVariant : colorScheme.onPrimary),
      ),
    );
  }
}

class _TestRunPage extends StatefulWidget {
  final String videoTitle;
  final Map<String, dynamic> billing;
  final List<Map<String, dynamic>> items;
  final bool isWordBookMode;

  const _TestRunPage({
    required this.videoTitle,
    required this.billing,
    required this.items,
    required this.isWordBookMode,
  });

  @override
  State<_TestRunPage> createState() => _TestRunPageState();
}

class _TestRunPageState extends State<_TestRunPage> {
  int _index = 0;
  int _correct = 0;
  bool _submitted = false;
  bool _isCorrect = false;
  final Map<String, bool> _wordResults = <String, bool>{};

  final List<String> _reorderSelected = [];
  String _spellingTyped = '';
  int? _mcqSelected;
  final Set<int> _multiSelected = {};
  bool _ttsPlayed = false;

  Map<String, dynamic> get _item => widget.items[_index];

  void _resetAnswer() {
    _reorderSelected.clear();
    _spellingTyped = '';
    _mcqSelected = null;
    _multiSelected.clear();
    _ttsPlayed = false;
    _submitted = false;
    _isCorrect = false;
  }

  bool _isPronType(String type) {
    return type == 'word_pron' || type == 'phrase_pron' || type == 'sentence_pron';
  }

  void _submit() {
    if (_submitted) return;
    final type = (_item['type'] as String?) ?? '';
    bool ok = false;

    if (type == 'reorder') {
      final answer = (_item['answer'] as List?)?.whereType<String>().toList() ?? const <String>[];
      ok = _reorderSelected.length == answer.length && _listEquals(_reorderSelected, answer);
    } else if (type == 'spelling') {
      final ans = (_item['answer'] as String?)?.toLowerCase() ?? '';
      ok = _spellingTyped.toLowerCase() == ans;
    } else if (type == 'mcq' || type == 'listen_choose' || type == 'listen_meaning' ||
        type == 'listen_reply' || type == 'definition_choice' || type == 'translate_meaning') {
      final idx = _item['answer_index'] as int? ?? -1;
      ok = _mcqSelected != null && _mcqSelected == idx;
    } else if (type == 'word_relation') {
      final answerIndices = (_item['answer_indices'] as List?)?.whereType<int>().toSet() ?? <int>{};
      ok = _multiSelected.length == answerIndices.length &&
          _multiSelected.every((i) => answerIndices.contains(i));
    } else if (_isPronType(type)) {
      // 跟读题暂不评分（需声通API）
      ok = true;
    }

    setState(() {
      _submitted = true;
      _isCorrect = ok;
      if (ok) _correct += 1;
    });
    _recordWordResult(ok);
  }

  /// 下一题：已提交则直接跳转，未提交但有答案则自动提交后跳转
  void _goNext() {
    if (!_submitted && _canSubmit()) {
      _submit();
    }
    if (!_submitted) return;
    _next();
  }

  Future<void> _next() async {
    if (_index >= widget.items.length - 1) {
      final navigator = Navigator.of(context);
      if (widget.isWordBookMode && _wordResults.isNotEmpty) {
        await WordBookService.recordTestResults(
          _wordResults.entries
              .map(
                (entry) => WordBookTestResult(
                  wordBookCode: entry.key,
                  correct: entry.value,
                  reviewedAt: DateTime.now(),
                ),
              )
              .toList(),
        );
      }
      if (!mounted) return;
      AppAlertDialog.show(
        context,
        title: '完成',
        content: '得分：$_correct / ${widget.items.length}',
        buttonText: '返回',
        onAction: () {
          if (mounted) navigator.pop(true);
        },
      );
      return;
    }
    setState(() {
      _index += 1;
      _resetAnswer();
    });
  }

  List<String> _remainingOptions(List<String> options, List<String> selected) {
    final total = <String, int>{};
    for (final w in options) {
      total[w] = (total[w] ?? 0) + 1;
    }
    final used = <String, int>{};
    for (final w in selected) {
      used[w] = (used[w] ?? 0) + 1;
    }
    final remaining = <String>[];
    for (final e in total.entries) {
      final left = e.value - (used[e.key] ?? 0);
      for (var i = 0; i < left; i++) {
        remaining.add(e.key);
      }
    }
    return remaining;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _recordWordResult(bool correct) {
    final wordBookCode = (_item['word_book_code'] as String?)?.trim();
    if (wordBookCode == null || wordBookCode.isEmpty) return;
    _wordResults[wordBookCode] = (_wordResults[wordBookCode] ?? false) || correct;
  }

  @override
  void initState() {
    super.initState();
    _resetAnswer();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = widget.items.length;
    final answered = _index + (_submitted ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('测试：${widget.videoTitle}', style: TextStyle(fontSize: 16.sp)),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '第 ${_index + 1} / $total 题',
                    style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Expanded(child: _buildQuestion()),
            SizedBox(height: 12.h),
            if (_submitted)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: _isCorrect ? colorScheme.tertiaryContainer : colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  _isCorrect ? '正确' : '错误',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _isCorrect ? colorScheme.onTertiaryContainer : colorScheme.onErrorContainer,
                  ),
                ),
              ),
            SizedBox(height: 12.h),
            SizedBox(
              height: 48.h,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitted || _canSubmit() ? _goNext : null,
                      child: Text(_index >= total - 1 ? '完成' : '下一题', style: TextStyle(fontSize: 14.sp)),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: FilledButton(
                      onPressed: _canSubmit() ? _submit : null,
                      child: Text(_submitted ? '已提交' : '提交', style: TextStyle(fontSize: 14.sp)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              '当前得分：$_correct / $answered',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.sp, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }

  bool _canSubmit() {
    if (_submitted) return false;
    final type = (_item['type'] as String?) ?? '';
    if (type == 'reorder') {
      final answer = (_item['answer'] as List?)?.whereType<String>().toList() ?? const <String>[];
      return _reorderSelected.length == answer.length && answer.isNotEmpty;
    }
    if (type == 'spelling') {
      final ans = (_item['answer'] as String?) ?? '';
      return _spellingTyped.length == ans.length && ans.isNotEmpty;
    }
    if (type == 'mcq' || type == 'listen_choose' || type == 'listen_meaning' ||
        type == 'listen_reply' || type == 'definition_choice' || type == 'translate_meaning') {
      return _mcqSelected != null;
    }
    if (type == 'word_relation') {
      return _multiSelected.isNotEmpty;
    }
    if (_isPronType(type)) {
      return true; // 跟读题直接提交
    }
    return false;
  }

  Widget _buildQuestion() {
    final type = (_item['type'] as String?) ?? '';
    if (type == 'reorder') return _buildReorder();
    if (type == 'spelling') return _buildSpelling();
    if (type == 'mcq') return _buildMcq();
    if (type == 'listen_choose') return _buildListenMcq('听发音，选择你听到的单词');
    if (type == 'listen_meaning') return _buildListenMcq('听发音，选择与该词意思最接近的选项');
    if (type == 'listen_reply') return _buildListenMcq('听问题，选择最佳回答');
    if (type == 'definition_choice') return _buildDefinitionChoice();
    if (type == 'translate_meaning') return _buildTranslateMeaning();
    if (type == 'word_relation') return _buildWordRelation();
    if (_isPronType(type)) return _buildPronunciation();
    return Center(child: Text('未知题型: $type'));
  }

  Widget _buildReorder() {
    final colorScheme = Theme.of(context).colorScheme;
    final prompt = (_item['prompt'] as String?) ?? '组句';
    final options = (_item['options'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final answer = (_item['answer'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final remaining = _remainingOptions(options, _reorderSelected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
          child: Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final w in _reorderSelected)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999.r)),
                  child: Text(
                    w,
                    style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurface),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reorderSelected.isEmpty || _submitted
                    ? null
                    : () => setState(() {
                        _reorderSelected.removeLast();
                      }),
                child: Text('撤销', style: TextStyle(fontSize: 13.sp)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: OutlinedButton(
                onPressed: _submitted
                    ? null
                    : () => setState(() {
                        _reorderSelected.clear();
                      }),
                child: Text('清空', style: TextStyle(fontSize: 13.sp)),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Text(
          '可选词',
          style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final w in remaining)
                  GestureDetector(
                    onTap: _submitted
                        ? null
                        : () => setState(() {
                            if (_reorderSelected.length < answer.length) _reorderSelected.add(w);
                          }),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999.r)),
                      child: Text(
                        w,
                        style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurface),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_submitted && !_isCorrect)
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Text(
              '正确答案：${answer.join(' ')}',
              style: TextStyle(fontSize: 12.sp, color: colorScheme.outline),
            ),
          ),
      ],
    );
  }

  Widget _buildSpelling() {
    final colorScheme = Theme.of(context).colorScheme;
    final prompt = (_item['prompt'] as String?) ?? '拼写';
    final masked = (_item['masked'] as String?) ?? '';
    final answer = (_item['answer'] as String?) ?? '';
    final letters = (_item['letter_pool'] as List?)?.whereType<String>().toList() ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
          child: Text(masked, style: TextStyle(fontSize: 14.sp, height: 1.4)),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
                child: Text(
                  _spellingTyped.padRight(answer.length, '•'),
                  style: TextStyle(fontSize: 16.sp, letterSpacing: 2.w),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            GestureDetector(
              onTap: _submitted || _spellingTyped.isEmpty
                  ? null
                  : () => setState(() {
                      _spellingTyped = _spellingTyped.substring(0, _spellingTyped.length - 1);
                    }),
              child: Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: _submitted || _spellingTyped.isEmpty ? colorScheme.surfaceContainerHighest : colorScheme.primary,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.backspace_outlined,
                  size: 18.sp,
                  color: _submitted || _spellingTyped.isEmpty ? colorScheme.onSurfaceVariant : colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                for (final l in letters)
                  GestureDetector(
                    onTap: _submitted || _spellingTyped.length >= answer.length
                        ? null
                        : () => setState(() {
                            _spellingTyped += l;
                          }),
                    child: Container(
                      width: 44.r,
                      height: 44.r,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
                      child: Text(
                        l,
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_submitted && !_isCorrect)
          Padding(
            padding: EdgeInsets.only(top: 10.h),
            child: Text(
              '正确答案：$answer',
              style: TextStyle(fontSize: 12.sp, color: colorScheme.outline),
            ),
          ),
      ],
    );
  }

  Widget _buildMcq() {
    final colorScheme = Theme.of(context).colorScheme;
    final prompt = (_item['prompt'] as String?) ?? '选择题';
    final masked = (_item['masked'] as String?) ?? '';
    final options = (_item['options'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final answerIndex = _item['answer_index'] as int? ?? -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
          child: Text(masked, style: TextStyle(fontSize: 14.sp, height: 1.4)),
        ),
        SizedBox(height: 12.h),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => SizedBox(height: 10.h),
            itemBuilder: (context, i) {
              final selected = _mcqSelected == i;
              final showCorrect = _submitted && i == answerIndex;
              final showWrong = _submitted && selected && i != answerIndex;
              final bg = showCorrect
                  ? colorScheme.tertiaryContainer
                  : showWrong
                  ? colorScheme.errorContainer
                  : selected
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : colorScheme.surfaceContainerHighest;
              final fg = showCorrect
                  ? colorScheme.onTertiaryContainer
                  : showWrong
                  ? colorScheme.onErrorContainer
                  : colorScheme.onSurface;

              return GestureDetector(
                onTap: _submitted ? null : () => setState(() => _mcqSelected = i),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12.r)),
                  child: Row(
                    children: [
                      Container(
                        width: 22.r,
                        height: 22.r,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          String.fromCharCode(65 + i),
                          style: TextStyle(fontSize: 12.sp, color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          options[i],
                          style: TextStyle(fontSize: 14.sp, color: fg),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── 听力类题型（带TTS播放按钮 + 单选） ───

  Widget _buildListenMcq(String hint) {
    final colorScheme = Theme.of(context).colorScheme;
    final promptCn = (_item['prompt_cn'] as String?) ?? '';
    final options = (_item['options'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final answerIndex = _item['answer_index'] as int? ?? -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TTS播放按钮
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _ttsPlayed = true),
                child: Container(
                  width: 56.r,
                  height: 56.r,
                  decoration: BoxDecoration(
                    color: _ttsPlayed ? colorScheme.primary.withValues(alpha: 0.15) : colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _ttsPlayed ? Icons.replay : Icons.volume_up,
                    size: 24.sp,
                    color: _ttsPlayed ? colorScheme.primary : colorScheme.onPrimary,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                _ttsPlayed ? '点击重新播放' : '点击播放音频',
                style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        if (promptCn.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(promptCn, style: TextStyle(fontSize: 12.sp, color: colorScheme.outline)),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => SizedBox(height: 10.h),
            itemBuilder: (context, i) => _buildOptionTile(colorScheme, i, options[i], answerIndex),
          ),
        ),
      ],
    );
  }

  // ─── 释义选择 ───

  Widget _buildDefinitionChoice() {
    final colorScheme = Theme.of(context).colorScheme;
    final prompt = (_item['prompt'] as String?) ?? '';
    final promptCn = (_item['prompt_cn'] as String?) ?? '';
    final displayText = (_item['display_text'] as String?) ?? '';
    final options = (_item['options'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final answerIndex = _item['answer_index'] as int? ?? -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
          child: Column(
            children: [
              Text(displayText, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              SizedBox(height: 6.h),
              Text(prompt, style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        if (promptCn.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(promptCn, style: TextStyle(fontSize: 12.sp, color: colorScheme.outline)),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => SizedBox(height: 10.h),
            itemBuilder: (context, i) => _buildOptionTile(colorScheme, i, options[i], answerIndex),
          ),
        ),
      ],
    );
  }

  // ─── 英义互译 ───

  Widget _buildTranslateMeaning() {
    final colorScheme = Theme.of(context).colorScheme;
    final promptCn = (_item['prompt_cn'] as String?) ?? '';
    final displayText = (_item['display_text'] as String?) ?? '';
    final options = (_item['options'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final answerIndex = _item['answer_index'] as int? ?? -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
          child: Text(displayText, style: TextStyle(fontSize: 14.sp, height: 1.5, color: colorScheme.onSurface)),
        ),
        SizedBox(height: 8.h),
        if (promptCn.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(promptCn, style: TextStyle(fontSize: 12.sp, color: colorScheme.outline)),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => SizedBox(height: 10.h),
            itemBuilder: (context, i) => _buildOptionTile(colorScheme, i, options[i], answerIndex, maxLines: 3),
          ),
        ),
      ],
    );
  }

  // ─── 词性测试（多选） ───

  Widget _buildWordRelation() {
    final colorScheme = Theme.of(context).colorScheme;
    final prompt = (_item['prompt'] as String?) ?? '';
    final promptCn = (_item['prompt_cn'] as String?) ?? '';
    final displayText = (_item['display_text'] as String?) ?? '';
    final options = (_item['options'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final answerIndices = (_item['answer_indices'] as List?)?.whereType<int>().toSet() ?? <int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
          child: Column(
            children: [
              Text(displayText, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              SizedBox(height: 6.h),
              Text(prompt, style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        if (promptCn.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: Text(promptCn, style: TextStyle(fontSize: 12.sp, color: colorScheme.outline)),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Text('（可多选）', style: TextStyle(fontSize: 11.sp, color: colorScheme.primary)),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => SizedBox(height: 10.h),
            itemBuilder: (context, i) {
              final selected = _multiSelected.contains(i);
              final showCorrect = _submitted && answerIndices.contains(i);
              final showWrong = _submitted && selected && !answerIndices.contains(i);
              final bg = showCorrect
                  ? colorScheme.tertiaryContainer
                  : showWrong
                      ? colorScheme.errorContainer
                      : selected
                          ? colorScheme.primary.withValues(alpha: 0.12)
                          : colorScheme.surfaceContainerHighest;
              return GestureDetector(
                onTap: _submitted
                    ? null
                    : () => setState(() {
                          if (_multiSelected.contains(i)) {
                            _multiSelected.remove(i);
                          } else {
                            _multiSelected.add(i);
                          }
                        }),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12.r)),
                  child: Row(
                    children: [
                      Container(
                        width: 22.r,
                        height: 22.r,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? colorScheme.primary : Colors.transparent,
                          border: Border.all(color: selected ? colorScheme.primary : colorScheme.outline, width: 1.5),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: selected ? Icon(Icons.check, size: 14.sp, color: colorScheme.onPrimary) : null,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(child: Text(options[i], style: TextStyle(fontSize: 14.sp))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── 跟读题 ───

  Widget _buildPronunciation() {
    final colorScheme = Theme.of(context).colorScheme;
    final promptCn = (_item['prompt_cn'] as String?) ?? '';
    final refText = (_item['ref_text'] as String?) ?? '';
    final type = (_item['type'] as String?) ?? '';
    final typeLabel = type == 'word_pron' ? '跟读单词' : type == 'phrase_pron' ? '跟读短语' : '跟读句子';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(typeLabel, style: TextStyle(fontSize: 11.sp, color: colorScheme.primary)),
              ),
              SizedBox(height: 12.h),
              Text(
                refText,
                style: TextStyle(fontSize: type == 'word_pron' ? 24.sp : 18.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              if (promptCn.isNotEmpty)
                Text(promptCn, style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        SizedBox(height: 20.h),
        Center(
          child: GestureDetector(
            onTap: _submitted ? null : () => setState(() => _submitted = true),
            child: Container(
              width: 72.r,
              height: 72.r,
              decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
              child: Icon(Icons.mic, size: 32.sp, color: colorScheme.onPrimary),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          _submitted ? '已录音，点击提交' : '点击录音',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  // ─── 通用选项组件 ───

  Widget _buildOptionTile(ColorScheme colorScheme, int i, String text, int answerIndex, {int maxLines = 1}) {
    final selected = _mcqSelected == i;
    final showCorrect = _submitted && i == answerIndex;
    final showWrong = _submitted && selected && i != answerIndex;
    final bg = showCorrect
        ? colorScheme.tertiaryContainer
        : showWrong
            ? colorScheme.errorContainer
            : selected
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.surfaceContainerHighest;
    return GestureDetector(
      onTap: _submitted ? null : () => setState(() => _mcqSelected = i),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12.r)),
        child: Row(
          children: [
            Container(
              width: 22.r,
              height: 22.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Text(
                String.fromCharCode(65 + i),
                style: TextStyle(fontSize: 12.sp, color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(child: Text(text, style: TextStyle(fontSize: 14.sp), maxLines: maxLines, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
