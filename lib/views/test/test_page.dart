import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';
import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/services/auth_service.dart';
import 'package:vidlang/services/evaluation_api.dart';
import 'package:vidlang/services/learning_stats_service.dart';
import 'package:vidlang/services/shengtong_http_evaluator.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/widgets/app_dialogs.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 测试范围枚举
///
/// 用于区分单元测试（单个资源）、综合测试（整个文件夹）、生词本测试
enum TestScope {
  /// 单个资源测试（视频/音频/文章）
  resource,

  /// 文件夹综合测试
  folder,

  /// 生词本测试
  wordBook,
}

class TestPage extends StatefulWidget {
  /// 资源 code（resource/folder 模式必填，wordBook 模式为 null）
  final String? videoCode;

  /// 测试标题
  final String videoTitle;

  /// 生词本种子单词（wordBook 模式使用）
  final List<Map<String, dynamic>> seedWords;

  /// 题型筛选
  final List<String>? questionTypes;

  /// 每个单词出题数
  final int? questionsPerWord;

  /// 难度级别
  final String? difficulty;

  /// 测试范围（默认为 resource）
  final TestScope testScope;

  /// 文件夹 code（folder 模式必填）
  final String? folderCode;

  const TestPage({
    super.key,
    this.videoCode,
    required this.videoTitle,
    this.seedWords = const [],
    this.questionTypes,
    this.questionsPerWord,
    this.difficulty,
    this.testScope = TestScope.resource,
    this.folderCode,
  });

  bool get isWordBookMode => testScope == TestScope.wordBook;

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
      final difficulty =
          widget.difficulty ??
          prefs.getString('app_difficulty_level') ??
          'intermediate';

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
      // 根据 TestScope 构造不同的请求体
      final Map<String, dynamic> requestBody;
      switch (widget.testScope) {
        case TestScope.wordBook:
          requestBody = {
            'request_id': requestId,
            'source_type': 'word_book',
            'difficulty': difficulty,
            'config': config,
            'seed_words': widget.seedWords,
          };
        case TestScope.folder:
          requestBody = {
            'request_id': requestId,
            'folder_code': widget.folderCode ?? widget.videoCode!,
            'source_type': 'folder',
            'difficulty': difficulty,
            'config': config,
          };
        case TestScope.resource:
          requestBody = {
            'request_id': requestId,
            'video_code': widget.videoCode,
            'source_type': 'resource',
            'difficulty': difficulty,
            'config': config,
          };
      }

      final res = await client.functions.invoke(
        'ai-test-plan',
        body: requestBody,
      );

      final data = res.data;
      if (data is! Map) throw Exception('服务响应异常');
      final ok = data['ok'] as bool? ?? false;
      if (!ok) {
        final error = data['error'] as String? ?? 'unknown_error';
        final message = data['message'] as String?;
        if (error == 'insufficient_balance') {
          throw Exception('余额不足，无法生成题目');
        }
        if (error == 'no_content') {
          throw Exception('云端没有该视频字幕内容，请先导入字幕并完成上传');
        }
        if (error == 'no_items') {
          throw Exception(message ?? '所有生成的题目均未通过质量检查，请尝试更换测试素材或调整配置');
        }
        throw Exception(message ?? '生成失败: $error');
      }

      final plan = data['plan'];
      if (plan == null) throw Exception('服务响应缺少 plan 数据');
      final itemsRaw = (plan is Map) ? plan['items'] : null;
      final items = (itemsRaw is List)
          ? itemsRaw.whereType<Map>().cast<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      if (items.isEmpty) throw Exception('没有生成任何题目');

      final billing = (data['billing'] is Map)
          ? (data['billing'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final title = (data['title'] as String?)?.trim();

      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _TestRunPage(
            videoTitle: title != null && title.isNotEmpty
                ? title
                : widget.videoTitle,
            billing: billing,
            items: items,
            isWordBookMode: widget.isWordBookMode,
            testScope: widget.testScope,
            videoCode: widget.videoCode,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String errorMsg;
      if (e is sb.FunctionException) {
        // Edge Function 返回非 2xx 状态码
        final details = e.details;
        if (details is Map && details['message'] != null) {
          errorMsg = details['message'] as String;
        } else if (details is String) {
          errorMsg = details;
        } else {
          errorMsg = '出题服务异常 (${e.status})';
        }
      } else {
        errorMsg = e.toString().replaceFirst('Exception: ', '');
      }
      setState(() => _error = errorMsg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('综合测试', style: TextStyle(fontSize: Adaptive.sp(context, 16))),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部标题
          Padding(
            padding: EdgeInsets.fromLTRB(Adaptive.w(context, 16), Adaptive.h(context, 12), Adaptive.w(context, 16), Adaptive.h(context, 8)),
            child: Text(
              widget.videoTitle,
              style: TextStyle(fontSize: Adaptive.sp(context, 16), fontWeight: FontWeight.w600),
            ),
          ),
          // 题型配置滚动区域
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isWordBookMode) ...[
                    Container(
                      padding: EdgeInsets.all(Adaptive.w(context, 12)),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
                      ),
                      child: Text(
                        '生词本测试按所选单词出题，提交后会累计复习次数。',
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 12),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(height: Adaptive.h(context, 12)),
                  ],
                  // 听
                  _QuestionGroupSection(
                    icon: AppIcons.headphones,
                    title: '听',
                    children: [
                      _QuestionTypeCard(
                        title: '原音选择',
                        description: '播放音频，选择当前播放的内容',
                        value: _listenChooseCount,
                        onChanged: (v) =>
                            setState(() => _listenChooseCount = v),
                      ),
                      _QuestionTypeCard(
                        title: '听音辩义',
                        description: '播放音频，选择和原义类似的解释',
                        value: _listenMeaningCount,
                        onChanged: (v) =>
                            setState(() => _listenMeaningCount = v),
                      ),
                      _QuestionTypeCard(
                        title: '听音回复',
                        description: '播放一个问题，根据听到的内容选择回答',
                        value: _listenReplyCount,
                        onChanged: (v) => setState(() => _listenReplyCount = v),
                      ),
                    ],
                  ),
                  SizedBox(height: Adaptive.h(context, 16)),
                  // 读
                  _QuestionGroupSection(
                    icon: AppIcons.menuBook,
                    title: '读',
                    children: [
                      _QuestionTypeCard(
                        title: '释义选择',
                        description: '根据给出的单词或翻译，选择正确的释义',
                        value: _definitionChoiceCount,
                        onChanged: (v) =>
                            setState(() => _definitionChoiceCount = v),
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
                        onChanged: (v) =>
                            setState(() => _translateMeaningCount = v),
                      ),
                      _QuestionTypeCard(
                        title: '词性测试',
                        description: '根据单词选择同义词、反义词等（可多选）',
                        value: _wordRelationCount,
                        onChanged: (v) =>
                            setState(() => _wordRelationCount = v),
                      ),
                    ],
                  ),
                  SizedBox(height: Adaptive.h(context, 16)),
                  // 说
                  _QuestionGroupSection(
                    icon: AppIcons.mic,
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
                        onChanged: (v) =>
                            setState(() => _sentencePronCount = v),
                      ),
                    ],
                  ),
                  SizedBox(height: Adaptive.h(context, 12)),
                  // 错误提示
                  if (_error != null)
                    Container(
                      padding: EdgeInsets.all(Adaptive.w(context, 12)),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 13),
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  SizedBox(height: Adaptive.h(context, 16)),
                ],
              ),
            ),
          ),
          // 底部操作栏
          Container(
            padding: EdgeInsets.fromLTRB(Adaptive.w(context, 16), Adaptive.h(context, 8), Adaptive.w(context, 16), Adaptive.h(context, 16)),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.quiz,
                      size: Adaptive.sp(context, 14),
                      color: colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: Adaptive.w(context, 6)),
                    Text(
                      '共 $_totalCount 题 · 每次随机出题，请认真作答',
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, 12),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Adaptive.h(context, 10)),
                SizedBox(
                  height: Adaptive.h(context, 48),
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_loading || _totalCount == 0) ? null : _start,
                    child: _loading
                        ? SizedBox(
                            width: Adaptive.r(context, 18),
                            height: Adaptive.r(context, 18),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Text('开始', style: TextStyle(fontSize: Adaptive.sp(context, 15))),
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
            Icon(icon, size: Adaptive.sp(context, 18), color: colorScheme.primary),
            SizedBox(width: Adaptive.w(context, 6)),
            Text(
              title,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 15),
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: Adaptive.h(context, 10)),
        ...children.expand((child) => [child, SizedBox(height: Adaptive.h(context, 8))]),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 16), vertical: Adaptive.h(context, 14)),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
          width: 0.5,
        ),
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
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 14),
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: Adaptive.h(context, 4)),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 12),
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: Adaptive.w(context, 12)),
          _StepButton(
            icon: AppIcons.remove,
            onTap: value <= 0 ? null : () => onChanged(value - 1),
          ),
          SizedBox(
            width: Adaptive.w(context, 32),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 15),
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          _StepButton(
            icon: AppIcons.add,
            onTap: value >= 20 ? null : () => onChanged(value + 1),
          ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Adaptive.r(context, 8)),
        child: Container(
          width: Adaptive.r(context, 28),
          height: Adaptive.r(context, 28),
          decoration: BoxDecoration(
            color: disabled
                ? colorScheme.surfaceContainerHighest
                : colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Adaptive.r(context, 8)),
            border: Border.all(
              color: disabled
                  ? Colors.transparent
                  : colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            icon,
            size: Adaptive.sp(context, 16),
            color: disabled
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                : colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _TestRunPage extends StatefulWidget {
  final String videoTitle;
  final Map<String, dynamic> billing;
  final List<Map<String, dynamic>> items;
  final bool isWordBookMode;
  final TestScope testScope;
  final String? videoCode;

  const _TestRunPage({
    required this.videoTitle,
    required this.billing,
    required this.items,
    required this.isWordBookMode,
    this.testScope = TestScope.resource,
    this.videoCode,
  });

  @override
  State<_TestRunPage> createState() => _TestRunPageState();
}

class _TestRunPageState extends State<_TestRunPage> {
  int _index = 0;
  int _correct = 0;
  bool _submitted = false;
  bool _isCorrect = false;
  bool _isPlayingTts = false;
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
    _isPlayingTts = false;
    _submitted = false;
    _isCorrect = false;
  }

  bool _isPronType(String type) {
    return type == 'word_pron' ||
        type == 'phrase_pron' ||
        type == 'sentence_pron';
  }

  void _submit() {
    if (_submitted) return;
    final type = (_item['type'] as String?) ?? '';
    bool ok = false;

    if (type == 'reorder') {
      final answer =
          (_item['answer'] as List?)?.whereType<String>().toList() ??
          const <String>[];
      ok =
          _reorderSelected.length == answer.length &&
          _listEquals(_reorderSelected, answer);
    } else if (type == 'spelling') {
      final ans = (_item['answer'] as String?)?.toLowerCase() ?? '';
      ok = _spellingTyped.toLowerCase() == ans;
    } else if (type == 'mcq' ||
        type == 'listen_choose' ||
        type == 'listen_meaning' ||
        type == 'listen_reply' ||
        type == 'definition_choice' ||
        type == 'translate_meaning') {
      final idx = _item['answer_index'] as int? ?? -1;
      ok = _mcqSelected != null && _mcqSelected == idx;
    } else if (type == 'word_relation') {
      final answerIndices =
          (_item['answer_indices'] as List?)?.whereType<int>().toSet() ??
          <int>{};
      ok =
          _multiSelected.length == answerIndices.length &&
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

      // 通过 LearningStatsService 记录本次测试 session 的汇总得分
      if (widget.videoCode != null && widget.videoCode!.isNotEmpty) {
        unawaited(
          LearningStatsService.instance.completeTestSession(
            resourceCode: widget.videoCode!,
            totalQuestions: widget.items.length,
            correctCount: _correct,
            resourceType: _resourceTypeFromScope(),
          ),
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
    _wordResults[wordBookCode] =
        (_wordResults[wordBookCode] ?? false) || correct;

    // 通过 LearningStatsService 记录单题结果（含资源归属）
    final sourceVideoCode =
        (_item['source_video_code'] as String?)?.trim() ??
        widget.videoCode; // 综合测试时从题目中取 source_video_code
    if (sourceVideoCode != null && sourceVideoCode.isNotEmpty) {
      final questionType = (_item['type'] as String?)?.toString() ?? 'unknown';
      unawaited(
        LearningStatsService.instance.recordQuizResult(
          resourceCode: sourceVideoCode,
          questionType: questionType,
          isCorrect: correct,
          wordBookCode: wordBookCode.isNotEmpty ? wordBookCode : null,
          resourceType: _resourceTypeFromScope(),
        ),
      );
    }
  }

  /// 根据 testScope 推断资源类型
  String _resourceTypeFromScope() {
    switch (widget.testScope) {
      case TestScope.wordBook:
        return 'video'; // 生词本默认关联视频
      case TestScope.folder:
      case TestScope.resource:
        return 'video';
    }
  }

  /// 播放 TTS 音频（参考视频播放器清晰朗读，使用统一 TtsService）
  Future<void> _playTtsAudio() async {
    final refText = (_item['ref_text'] as String?) ?? '';
    if (refText.isEmpty) return;

    setState(() => _isPlayingTts = true);

    try {
      // 使用与视频播放器一致的 TtsService
      await TtsService().speakClarity(
        text: refText,
        onComplete: () {
          if (!mounted) return;
          setState(() {
            _ttsPlayed = true;
            _isPlayingTts = false;
          });
        },
      );
      // 如果 speakClarity 同步返回（未真正播放），也标记为已播放
      if (mounted && !_ttsPlayed) {
        setState(() {
          _ttsPlayed = true;
          _isPlayingTts = false;
        });
      }
    } catch (e) {
      debugPrint('TTS play error: $e');
      if (mounted) {
        setState(() => _isPlayingTts = false);
      }
    }
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '测试：${widget.videoTitle}',
          style: TextStyle(fontSize: Adaptive.sp(context, 16)),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(Adaptive.w(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '第 ${_index + 1} / $total 题',
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 13),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: Adaptive.h(context, 12)),
            Expanded(child: _buildQuestion()),
            SizedBox(height: Adaptive.h(context, 12)),
            if (_submitted)
              Container(
                padding: EdgeInsets.all(Adaptive.w(context, 12)),
                decoration: BoxDecoration(
                  color: _isCorrect
                      ? AppColors.success.withValues(alpha: 0.1)
                      : colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
                  border: Border.all(
                    color: _isCorrect
                        ? AppColors.success.withValues(alpha: 0.3)
                        : colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _isCorrect ? '正确' : '错误',
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 14),
                    fontWeight: FontWeight.w600,
                    color: _isCorrect ? AppColors.success : colorScheme.error,
                  ),
                ),
              ),
            SizedBox(height: Adaptive.h(context, 12)),
            // 底部操作栏
            Container(
              padding: EdgeInsets.fromLTRB(Adaptive.w(context, 4), Adaptive.h(context, 12), Adaptive.w(context, 4), Adaptive.h(context, 12)),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: Adaptive.h(context, 46),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _submitted || _canSubmit() ? _goNext : null,
                            icon: Icon(AppIcons.chevronRight, size: Adaptive.sp(context, 16)),
                            label: Text(
                              _index >= total - 1 ? '完成' : '下一题',
                              style: TextStyle(fontSize: Adaptive.sp(context, 14), fontWeight: FontWeight.w500),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(context, 10))),
                            ),
                          ),
                        ),
                        SizedBox(width: Adaptive.w(context, 12)),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _canSubmit() ? _submit : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: _submitted ? colorScheme.surfaceContainerHighest : colorScheme.primary,
                              foregroundColor: _submitted ? colorScheme.onSurfaceVariant : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(context, 10))),
                            ),
                            child: Text(
                              _submitted ? '已提交' : '提交',
                              style: TextStyle(fontSize: Adaptive.sp(context, 14), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Adaptive.h(context, 8)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.quiz, size: Adaptive.sp(context, 13), color: colorScheme.onSurfaceVariant),
                      SizedBox(width: Adaptive.w(context, 4)),
                      Text(
                        '当前得分：$_correct / $answered',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 12),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
      final answer =
          (_item['answer'] as List?)?.whereType<String>().toList() ??
          const <String>[];
      return _reorderSelected.length == answer.length && answer.isNotEmpty;
    }
    if (type == 'spelling') {
      final ans = (_item['answer'] as String?) ?? '';
      return _spellingTyped.length == ans.length && ans.isNotEmpty;
    }
    if (type == 'mcq' ||
        type == 'listen_choose' ||
        type == 'listen_meaning' ||
        type == 'listen_reply' ||
        type == 'definition_choice' ||
        type == 'translate_meaning') {
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

  Widget _buildQuestionContainer(BuildContext context, Widget child) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(Adaptive.w(context, 16)),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.3),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }

  Widget _buildReorder() {
    final colorScheme = Theme.of(context).colorScheme;
    final prompt = (_item['prompt'] as String?) ?? '组句';
    final options =
        (_item['options'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final answer =
        (_item['answer'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final remaining = _remainingOptions(options, _reorderSelected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: TextStyle(fontSize: Adaptive.sp(context, 15), fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Adaptive.h(context, 12)),
        _buildQuestionContainer(
          context,
          Wrap(
            spacing: Adaptive.w(context, 8),
            runSpacing: Adaptive.h(context, 8),
            children: [
              for (final w in _reorderSelected)
                Builder(
                  builder: (context) {
                    final isWrong = _submitted && !_isCorrect;
                    final isCorrect = _submitted && _isCorrect;
                    Color bg = isWrong
                        ? colorScheme.error.withValues(alpha: 0.1)
                        : (isCorrect
                              ? AppColors.success.withValues(alpha: 0.1)
                              : colorScheme.primary.withValues(alpha: 0.12));
                    Color border = isWrong
                        ? colorScheme.error.withValues(alpha: 0.3)
                        : (isCorrect
                              ? AppColors.success.withValues(alpha: 0.3)
                              : colorScheme.primary.withValues(alpha: 0.2));
                    Color textCol = isWrong
                        ? colorScheme.error
                        : (isCorrect ? AppColors.success : colorScheme.primary);
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Adaptive.w(context, 10),
                        vertical: Adaptive.h(context, 8),
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 999)),
                        border: Border.all(color: border),
                      ),
                      child: Text(
                        w,
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 13),
                          color: textCol,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        SizedBox(height: Adaptive.h(context, 10)),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reorderSelected.isEmpty || _submitted
                    ? null
                    : () => setState(() {
                        _reorderSelected.removeLast();
                      }),
                icon: Icon(AppIcons.backspace, size: Adaptive.sp(context, 14)),
                label: Text('撤销', style: TextStyle(fontSize: Adaptive.sp(context, 13), fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(context, 8))),
                  padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 8)),
                ),
              ),
            ),
            SizedBox(width: Adaptive.w(context, 12)),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitted
                    ? null
                    : () => setState(() {
                        _reorderSelected.clear();
                      }),
                icon: Icon(AppIcons.delete, size: Adaptive.sp(context, 14)),
                label: Text('清空', style: TextStyle(fontSize: Adaptive.sp(context, 13), fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(context, 8))),
                  padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 8)),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: Adaptive.h(context, 12)),
        Text(
          '可选词',
          style: TextStyle(
            fontSize: Adaptive.sp(context, 13),
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: Adaptive.h(context, 8)),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: Adaptive.w(context, 8),
              runSpacing: Adaptive.h(context, 8),
              children: [
                for (final w in remaining)
                  GestureDetector(
                    onTap: _submitted
                        ? null
                        : () => setState(() {
                            if (_reorderSelected.length < answer.length) {
                              _reorderSelected.add(w);
                            }
                          }),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Adaptive.w(context, 10),
                        vertical: Adaptive.h(context, 8),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 999)),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        w,
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 13),
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_submitted && !_isCorrect)
          Padding(
            padding: EdgeInsets.only(top: Adaptive.h(context, 10)),
            child: Text(
              '正确答案：${answer.join(' ')}',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 13),
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
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
    final letters =
        (_item['letter_pool'] as List?)?.whereType<String>().toList() ??
        const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: TextStyle(fontSize: Adaptive.sp(context, 15), fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Adaptive.h(context, 12)),
        _buildQuestionContainer(
          context,
          Text(
            masked,
            style: TextStyle(
              fontSize: Adaptive.sp(context, 15),
              height: 1.4,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(height: Adaptive.h(context, 12)),
        Row(
          children: [
            Expanded(
              child: Builder(
                builder: (context) {
                  final isWrong = _submitted && !_isCorrect;
                  final isCorrect = _submitted && _isCorrect;
                  Color bg = isWrong
                      ? colorScheme.error.withValues(alpha: 0.1)
                      : (isCorrect
                            ? AppColors.success.withValues(alpha: 0.1)
                            : Colors.white);
                  Color border = isWrong
                      ? colorScheme.error.withValues(alpha: 0.3)
                      : (isCorrect
                            ? AppColors.success.withValues(alpha: 0.3)
                            : colorScheme.outlineVariant.withValues(
                                alpha: 0.3,
                              ));
                  Color textCol = isWrong
                      ? colorScheme.error
                      : (isCorrect ? AppColors.success : colorScheme.primary);
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Adaptive.w(context, 12),
                      vertical: Adaptive.h(context, 10),
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      _spellingTyped.padRight(answer.length, '•'),
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, 18),
                        letterSpacing: Adaptive.w(context, 3),
                        color: textCol,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: Adaptive.w(context, 12)),
            GestureDetector(
              onTap: _submitted || _spellingTyped.isEmpty
                  ? null
                  : () => setState(() {
                      _spellingTyped = _spellingTyped.substring(
                        0,
                        _spellingTyped.length - 1,
                      );
                    }),
              child: Container(
                width: Adaptive.r(context, 44),
                height: Adaptive.r(context, 44),
                decoration: BoxDecoration(
                  color: _submitted || _spellingTyped.isEmpty
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primary,
                  borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
                ),
                child: Icon(
                          AppIcons.backspace,
                  size: Adaptive.sp(context, 18),
                  color: _submitted || _spellingTyped.isEmpty
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: Adaptive.h(context, 12)),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: Adaptive.w(context, 8),
              runSpacing: Adaptive.h(context, 8),
              children: [
                for (final l in letters)
                  GestureDetector(
                    onTap: _submitted || _spellingTyped.length >= answer.length
                        ? null
                        : () => setState(() {
                            _spellingTyped += l;
                          }),
                    child: Container(
                      width: Adaptive.r(context, 44),
                      height: Adaptive.r(context, 44),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textPrimary.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        l,
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 16),
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_submitted && !_isCorrect)
          Padding(
            padding: EdgeInsets.only(top: Adaptive.h(context, 10)),
            child: Text(
              '正确答案：$answer',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 13),
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMcq() {
    final colorScheme = Theme.of(context).colorScheme;
    final prompt = (_item['prompt'] as String?) ?? '选择题';
    final masked = (_item['masked'] as String?) ?? '';
    final options =
        (_item['options'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final answerIndex = _item['answer_index'] as int? ?? -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          prompt,
          style: TextStyle(fontSize: Adaptive.sp(context, 15), fontWeight: FontWeight.w600),
        ),
        SizedBox(height: Adaptive.h(context, 12)),
        _buildQuestionContainer(
          context,
          Text(
            masked,
            style: TextStyle(
              fontSize: Adaptive.sp(context, 15),
              height: 1.4,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(height: Adaptive.h(context, 12)),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => SizedBox(height: Adaptive.h(context, 10)),
            itemBuilder: (context, i) =>
                _buildOptionTile(colorScheme, i, options[i], answerIndex),
          ),
        ),
      ],
    );
  }

  // ─── 听力类题型（带TTS播放按钮 + 单选） ───

  Widget _buildListenMcq(String hint) {
    final colorScheme = Theme.of(context).colorScheme;
    final promptCn = (_item['prompt_cn'] as String?) ?? '';
    final options =
        (_item['options'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final answerIndex = _item['answer_index'] as int? ?? -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TTS播放按钮
        _buildQuestionContainer(
          context,
          Column(
            children: [
              GestureDetector(
                onTap: _isPlayingTts ? null : () => _playTtsAudio(),
                child: Container(
                  width: Adaptive.r(context, 56),
                  height: Adaptive.r(context, 56),
                  decoration: BoxDecoration(
                    color: _ttsPlayed
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _isPlayingTts
                      ? SizedBox(
                          width: Adaptive.sp(context, 24),
                          height: Adaptive.sp(context, 24),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Icon(
                          _ttsPlayed ? AppIcons.replay : AppIcons.volumeUp,
                          size: Adaptive.sp(context, 24),
                          color: _ttsPlayed
                              ? colorScheme.primary
                              : colorScheme.onPrimary,
                        ),
                ),
              ),
              SizedBox(height: Adaptive.h(context, 8)),
              Text(
                _isPlayingTts ? '正在播放...' : (_ttsPlayed ? '点击重新播放' : '点击播放音频'),
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 13),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Adaptive.h(context, 8)),
        if (promptCn.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: Adaptive.h(context, 8)),
            child: Text(
              promptCn,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 12),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => SizedBox(height: Adaptive.h(context, 10)),
            itemBuilder: (context, i) =>
                _buildOptionTile(colorScheme, i, options[i], answerIndex),
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
    final options =
        (_item['options'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final answerIndex = _item['answer_index'] as int? ?? -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQuestionContainer(
          context,
          Column(
            children: [
              Text(
                displayText,
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 22),
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: Adaptive.h(context, 6)),
              Text(
                prompt,
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 14),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Adaptive.h(context, 8)),
        if (promptCn.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: Adaptive.h(context, 8)),
            child: Text(
              promptCn,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 12),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => SizedBox(height: Adaptive.h(context, 10)),
            itemBuilder: (context, i) =>
                _buildOptionTile(colorScheme, i, options[i], answerIndex),
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
    final options =
        (_item['options'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final answerIndex = _item['answer_index'] as int? ?? -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQuestionContainer(
          context,
          Text(
            displayText,
            style: TextStyle(
              fontSize: Adaptive.sp(context, 15),
              height: 1.5,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(height: Adaptive.h(context, 8)),
        if (promptCn.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: Adaptive.h(context, 8)),
            child: Text(
              promptCn,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 12),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => SizedBox(height: Adaptive.h(context, 10)),
            itemBuilder: (context, i) => _buildOptionTile(
              colorScheme,
              i,
              options[i],
              answerIndex,
              maxLines: 3,
            ),
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
    final options =
        (_item['options'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final answerIndices =
        (_item['answer_indices'] as List?)?.whereType<int>().toSet() ?? <int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQuestionContainer(
          context,
          Column(
            children: [
              Text(
                displayText,
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 20),
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: Adaptive.h(context, 6)),
              Text(
                prompt,
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 14),
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Adaptive.h(context, 8)),
        if (promptCn.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: Adaptive.h(context, 4)),
            child: Text(
              promptCn,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 12),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: Adaptive.h(context, 8)),
          child: Text(
            '（可多选）',
            style: TextStyle(fontSize: Adaptive.sp(context, 13), color: colorScheme.primary),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: options.length,
            separatorBuilder: (_, _) => SizedBox(height: Adaptive.h(context, 10)),
            itemBuilder: (context, i) {
              final selected = _multiSelected.contains(i);
              final isCorrect = _submitted && answerIndices.contains(i);
              final isWrong =
                  _submitted && selected && !answerIndices.contains(i);

              Color bg;
              Color border;
              if (isCorrect) {
                bg = AppColors.success.withValues(alpha: 0.1);
                border = AppColors.success.withValues(alpha: 0.3);
              } else if (isWrong) {
                bg = colorScheme.error.withValues(alpha: 0.1);
                border = colorScheme.error.withValues(alpha: 0.3);
              } else if (selected) {
                bg = colorScheme.primary.withValues(alpha: 0.08);
                border = colorScheme.primary.withValues(alpha: 0.3);
              } else {
                bg = colorScheme.surface;
                border = colorScheme.outlineVariant.withValues(alpha: 0.5);
              }

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
                  padding: EdgeInsets.symmetric(
                    horizontal: Adaptive.w(context, 12),
                    vertical: Adaptive.h(context, 12),
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: Adaptive.r(context, 22),
                        height: Adaptive.r(context, 22),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? colorScheme.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withValues(
                                    alpha: 0.5,
                                  ),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(Adaptive.r(context, 6)),
                        ),
                        child: selected
                            ? Icon(
                                AppIcons.check,
                                size: Adaptive.sp(context, 14),
                                color: colorScheme.onPrimary,
                              )
                            : null,
                      ),
                      SizedBox(width: Adaptive.w(context, 10)),
                      Expanded(
                        child: Text(
                          options[i],
                          style: TextStyle(
                            fontSize: Adaptive.sp(context, 15),
                            color: isWrong
                                ? colorScheme.error
                                : (isCorrect
                                      ? AppColors.success
                                      : colorScheme.onSurface),
                            fontWeight: (isCorrect || isWrong)
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
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

  // ─── 跟读题（参考 ShadowReaderComponent 实现） ───

  /// 跟读状态: idle → recording → evaluating → scored
  String _pronState = 'idle';
  final AudioRecorder _pronRecorder = AudioRecorder();
  String? _pronRecordingPath;
  double? _pronScore;
  String? _pronFeedback;
  int _pronRecordingSeconds = 0;
  Timer? _pronRecordingTimer;

  Widget _buildPronunciation() {
    final colorScheme = Theme.of(context).colorScheme;
    final promptCn = (_item['prompt_cn'] as String?) ?? '';
    final refText = (_item['ref_text'] as String?) ?? '';
    final type = (_item['type'] as String?) ?? '';
    final typeLabel = type == 'word_pron'
        ? '跟读单词'
        : type == 'phrase_pron'
        ? '跟读短语'
        : '跟读句子';
    final isRecording = _pronState == 'recording';
    final isScored = _pronState == 'scored';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildQuestionContainer(
          context,
          Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 10), vertical: Adaptive.h(context, 4)),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Adaptive.r(context, 999)),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(fontSize: Adaptive.sp(context, 13), color: colorScheme.primary),
                ),
              ),
              SizedBox(height: Adaptive.h(context, 12)),
              Text(
                refText,
                style: TextStyle(
                  fontSize: type == 'word_pron' ? Adaptive.sp(context, 24) : Adaptive.sp(context, 18),
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Adaptive.h(context, 8)),
              if (promptCn.isNotEmpty)
                Text(
                  promptCn,
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 13),
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: Adaptive.h(context, 20)),

        // 跟读控制区域
        if (isScored && _pronScore != null) ...[
          _buildPronScoreResult(colorScheme),
          SizedBox(height: Adaptive.h(context, 16)),
        ],

        Center(
          child: GestureDetector(
            onTapDown: (_) => _startPronRecording(),
            onTapUp: (_) => _stopAndEvaluatePronunciation(),
            onTapCancel: () => _cancelPronRecording(),
            child: Container(
              width: Adaptive.r(context, 80),
              height: Adaptive.r(context, 80),
              decoration: BoxDecoration(
                color: isRecording
                    ? AppColors.error
                    : (_submitted ? colorScheme.outline : colorScheme.primary),
                shape: BoxShape.circle,
                boxShadow: isRecording
                    ? [
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: isRecording
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.mic, size: Adaptive.sp(context, 28), color: AppColors.surface),
                        SizedBox(height: Adaptive.h(context, 2)),
                        Text(
                          '${_pronRecordingSeconds}s',
                          style: TextStyle(
                            fontSize: Adaptive.sp(context, 11),
                            color: AppColors.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : isScored
                  ? Icon(
                      AppIcons.replay,
                      size: Adaptive.sp(context, 32),
                      color: colorScheme.onPrimary,
                    )
                  : Icon(AppIcons.mic, size: Adaptive.sp(context, 32), color: colorScheme.onPrimary),
            ),
          ),
        ),
        SizedBox(height: Adaptive.h(context, 10)),
        Text(
          isRecording ? '松开结束录音' : (isScored ? '点击重新录音' : '按住录音'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: Adaptive.sp(context, 12),
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 构建跟读评分结果
  Widget _buildPronScoreResult(ColorScheme colorScheme) {
    final score = _pronScore ?? 0;
    final scoreColor = score >= 90
        ? const Color(0xFF30D158)
        : score >= 75
        ? const Color(0xFFFFCC00)
        : score >= 60
        ? const Color(0xFFFF8A00)
        : const Color(0xFFFF453A);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 16), vertical: Adaptive.h(context, 12)),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: Adaptive.r(context, 44),
            height: Adaptive.r(context, 44),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                '${score.round()}',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 16),
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
            ),
          ),
          SizedBox(width: Adaptive.w(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score >= 90
                      ? '优秀！'
                      : score >= 75
                      ? '良好'
                      : score >= 60
                      ? '及格'
                      : '继续加油',
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 14),
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (_pronFeedback != null && _pronFeedback!.isNotEmpty)
                  Text(
                    _pronFeedback!,
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 12),
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 开始跟读录音（参考 ShadowReaderComponent._startRecording）
  Future<void> _startPronRecording() async {
    if (_submitted || _pronState == 'recording') return;

    final hasPermission = await _pronRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        AppToast.show(context, '需要麦克风权限才能跟读', type: ToastType.warning);
      }
      return;
    }

    setState(() {
      _pronState = 'recording';
      _pronRecordingSeconds = 0;
    });

    try {
      final tmpDir = await getTemporaryDirectory();
      _pronRecordingPath =
          '${tmpDir.path}/pron_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _pronRecorder.start(
        const RecordConfig(),
        path: _pronRecordingPath!,
      );

      _pronRecordingTimer?.cancel();
      _pronRecordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _pronRecordingSeconds++);
      });
    } catch (e) {
      debugPrint('Start pronunciation recording error: $e');
      if (mounted) setState(() => _pronState = 'idle');
    }
  }

  /// 停止录音并评分（参考 ShadowReaderComponent._evaluateRecording）
  Future<void> _stopAndEvaluatePronunciation() async {
    if (_pronState != 'recording') return;
    _pronRecordingTimer?.cancel();

    try {
      await _pronRecorder.stop();
    } catch (e) {
      debugPrint('Stop pronunciation recording error: $e');
    }

    if (!mounted || _pronRecordingPath == null || _pronRecordingSeconds < 1) {
      // 录音太短，忽略
      if (mounted) setState(() => _pronState = 'idle');
      return;
    }

    // 显示评估中状态
    setState(() => _pronState = 'evaluating');

    await _evaluatePronunciation(_pronRecordingPath!);
  }

  /// 取消录音
  void _cancelPronRecording() {
    if (_pronState != 'recording') return;
    _pronRecordingTimer?.cancel();
    _pronRecorder.stop();
    if (mounted) setState(() => _pronState = 'idle');
  }

  /// 声通评分（参考 ShadowReaderComponent._evaluateRecording 的 ShengtongEvaluator 调用方式）
  Future<void> _evaluatePronunciation(String audioPath) async {
    final refText = (_item['ref_text'] as String?) ?? '';
    final type = (_item['type'] as String?) ?? '';
    if (refText.isEmpty) {
      if (mounted) setState(() => _pronState = 'idle');
      return;
    }

    try {
      // 确定评测类型
      final coreType = type == 'word_pron' ? 'word.eval' : 'sent.eval';

      // 方式1：使用 ShengtongEvaluator WebSocket 直连（key 从 AppKeysService 获取）
final stAppKey = AppKeysService.instance.shengtongAppKey;
final stSecretKey = AppKeysService.instance.shengtongSecretKey;
      if (stAppKey == null || stAppKey.isEmpty || stSecretKey == null || stSecretKey.isEmpty) {
        debugPrint('⚠️ [TestPage] 声通密钥未就绪');
        return;
      }
      // 使用 ShengtongHttpEvaluator HTTP 方式评测
      final evaluator = ShengtongHttpEvaluator(
        appKey: stAppKey,
        secretKey: stSecretKey,
      );

      final result = await evaluator.evaluate(
        coreType: coreType,
        refText: refText,
        audioPath: audioPath,
        userId: 'test_user',
      );

        if (result.isNotEmpty) {
          final overall = (result['overall'] as num?)?.toDouble();

        if (mounted) {
          setState(() {
            _pronState = 'scored';
            _pronScore = overall;
            _pronFeedback = overall != null
                ? (overall >= 90
                      ? '发音非常标准！'
                      : overall >= 75
                      ? '发音不错，继续保持！'
                      : overall >= 60
                      ? '基本正确，注意发音细节。'
                      : '需要多加练习哦。')
                : null;
          });
          // 自动提交跟读分数
          _pronScore = overall;
          if (!_submitted) _submit();
        }
      } else {
        // 声通不可用，降级到 Edge Function 评分
        await _evaluateWithEdgeFunction(audioPath, coreType, refText);
      }
    } catch (e) {
      debugPrint('Shengtong evaluation failed, fallback to Edge Function: $e');
      await _evaluateWithEdgeFunction(
        audioPath,
        type == 'word_pron' ? 'word.eval' : 'sent.eval',
        refText,
      );
    } finally {
      // 清理临时文件
      try {
        await File(audioPath).delete();
      } catch (_) {}
    }
  }

  /// 降级：通过 Edge Function 评分（使用 EvaluationApi）
  Future<void> _evaluateWithEdgeFunction(
    String audioPath,
    String coreType,
    String refText,
  ) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        if (mounted) setState(() => _pronState = 'idle');
        return;
      }

      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      final result = await EvaluationApi.scorePronunciation(
        coreType: coreType,
        refText: refText,
        audioBase64: base64Audio,
      );

      if (result != null) {
        final overall = (result['overall'] ?? result['score'] ?? 0) as num;
        if (mounted) {
          setState(() {
            _pronState = 'scored';
            _pronScore = overall.toDouble();
            _pronFeedback = overall.toDouble() >= 60 ? '完成跟读练习。' : '再试一次吧！';
          });
          _pronScore = overall.toDouble();
          if (!_submitted) _submit();
        }
      } else {
        // Edge Function 返回了非 ok 响应（详情已在 EvaluationApi 中打印）
        debugPrint('Edge Function 评分返回空结果，coreType=$coreType, refText=$refText');
        if (mounted) {
          setState(() {
            _pronState = 'scored';
            _pronScore = 0.0;
            _pronFeedback = '评分服务暂不可用，已记录练习。';
          });
          _pronScore = 0.0;
          if (!_submitted) _submit(); // 仍然允许提交
        }
      }
    } catch (e) {
      debugPrint('Edge Function evaluation error: $e');
      if (mounted) {
        setState(() {
          _pronState = 'idle';
          _pronScore = null;
        });
        AppToast.show(context, '评分失败: $e', type: ToastType.error);
      }
    }
  }

  @override
  void dispose() {
    _pronRecordingTimer?.cancel();
    _pronRecorder.dispose();
    super.dispose();
  }

  // ─── 通用选项组件 ───

  Widget _buildOptionTile(
    ColorScheme colorScheme,
    int i,
    String text,
    int answerIndex, {
    int maxLines = 1,
  }) {
    final selected = _mcqSelected == i;
    final isCorrect = _submitted && i == answerIndex;
    final isWrong = _submitted && selected && i != answerIndex;

    Color bg;
    Color border;
    if (isCorrect) {
      bg = AppColors.success.withValues(alpha: 0.1);
      border = AppColors.success.withValues(alpha: 0.3);
    } else if (isWrong) {
      bg = colorScheme.error.withValues(alpha: 0.1);
      border = colorScheme.error.withValues(alpha: 0.3);
    } else if (selected) {
      bg = colorScheme.primary.withValues(alpha: 0.08);
      border = colorScheme.primary.withValues(alpha: 0.3);
} else {
  bg = Colors.white;
  border = colorScheme.outlineVariant.withValues(alpha: 0.3);
}

return GestureDetector(
onTap: _submitted ? null : () => setState(() => _mcqSelected = i),
child: Container(
padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 12), vertical: Adaptive.h(context, 12)),
decoration: BoxDecoration(
color: bg,
borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
border: Border.all(color: border, width: 0.5),
),
        child: Row(
          children: [
            Container(
              width: Adaptive.r(context, 24),
              height: Adaptive.r(context, 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? colorScheme.primary : colorScheme.surface,
                border: Border.all(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(Adaptive.r(context, 999)),
              ),
              child: Text(
                String.fromCharCode(65 + i),
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 12),
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: Adaptive.w(context, 10)),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 15),
                  color: isWrong
                      ? colorScheme.error
                      : (isCorrect ? AppColors.success : colorScheme.onSurface),
                  fontWeight: (isCorrect || isWrong)
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
