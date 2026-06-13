import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/word_book_service.dart';

class TestPage extends StatefulWidget {
  final String? videoCode;
  final String videoTitle;
  final List<Map<String, dynamic>> seedWords;

  const TestPage({super.key, this.videoCode, required this.videoTitle, this.seedWords = const []});

  bool get isWordBookMode => videoCode == null;

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  static const _uuid = Uuid();

  int _reorderCount = 2;
  int _spellingCount = 2;
  int _mcqCount = 2;

  bool _loading = false;
  String? _error;

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
      final difficulty = prefs.getString('app_difficulty_level') ?? 'intermediate';
      final config = {'reorder_count': widget.isWordBookMode ? 0 : _reorderCount, 'spelling_count': _spellingCount, 'mcq_count': _mcqCount};
      final res = await client.functions.invoke(
        'ai-test-plan',
        body: widget.isWordBookMode
            ? {'request_id': requestId, 'source_type': 'word_book', 'difficulty': difficulty, 'config': config, 'seed_words': widget.seedWords}
            : {'request_id': requestId, 'video_code': widget.videoCode, 'difficulty': difficulty, 'config': config},
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
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.videoTitle,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12.h),
            if (!widget.isWordBookMode) ...[
              _CounterRow(title: '组句题', value: _reorderCount, onChanged: (v) => setState(() => _reorderCount = v)),
              SizedBox(height: 10.h),
            ],
            _CounterRow(title: '拼写填空', value: _spellingCount, onChanged: (v) => setState(() => _spellingCount = v)),
            SizedBox(height: 10.h),
            _CounterRow(title: '选择题', value: _mcqCount, onChanged: (v) => setState(() => _mcqCount = v)),
            if (widget.isWordBookMode) ...[
              SizedBox(height: 10.h),
              Text(
                '生词本测试按所选单词出题，提交后会累计复习次数。',
                style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
              ),
            ],
            SizedBox(height: 16.h),
            if (_error != null)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(12.r)),
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 13.sp, color: colorScheme.onErrorContainer),
                ),
              ),
            const Spacer(),
            SizedBox(
              height: 48.h,
              child: FilledButton(
                onPressed: _loading ? null : _start,
                child: _loading
                    ? SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                      )
                    : Text('开始', style: TextStyle(fontSize: 15.sp)),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              '每次题目都是随机，请认真作答',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.sp, color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  const _CounterRow({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurface),
            ),
          ),
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
        width: 34.r,
        height: 34.r,
        decoration: BoxDecoration(
          color: disabled ? colorScheme.surfaceContainerHighest : colorScheme.primary,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, size: 18.sp, color: disabled ? colorScheme.onSurfaceVariant : colorScheme.onPrimary),
      ),
    );
  }
}

class _TestRunPage extends StatefulWidget {
  final String videoTitle;
  final Map<String, dynamic> billing;
  final List<Map<String, dynamic>> items;
  final bool isWordBookMode;

  const _TestRunPage({required this.videoTitle, required this.billing, required this.items, required this.isWordBookMode});

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

  Map<String, dynamic> get _item => widget.items[_index];

  void _resetAnswer() {
    _reorderSelected.clear();
    _spellingTyped = '';
    _mcqSelected = null;
    _submitted = false;
    _isCorrect = false;
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
    } else if (type == 'mcq') {
      final idx = _item['answer_index'] as int? ?? -1;
      ok = _mcqSelected != null && _mcqSelected == idx;
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
          _wordResults.entries.map((entry) => WordBookTestResult(wordBookCode: entry.key, correct: entry.value, reviewedAt: DateTime.now())).toList(),
        );
      }
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('完成', style: TextStyle(fontSize: 16.sp)),
            content: Text('得分：$_correct / ${widget.items.length}', style: TextStyle(fontSize: 14.sp)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('返回'))],
          );
        },
      ).then((_) {
        if (mounted) navigator.pop(true);
      });
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
    if (type == 'mcq') {
      return _mcqSelected != null;
    }
    return false;
  }

  Widget _buildQuestion() {
    final type = (_item['type'] as String?) ?? '';
    if (type == 'reorder') return _buildReorder();
    if (type == 'spelling') return _buildSpelling();
    if (type == 'mcq') return _buildMcq();
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
}
