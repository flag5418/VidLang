import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vidlang/models/test_models.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/evaluation_api.dart';
import 'package:vidlang/services/test_generator.dart';

// ─── 状态 ───

class TestState {
  final TestSession? session;
  final List<TestItem> items;
  final int currentIndex;
  final bool isLoading;
  final bool isGeneratingEvaluation;
  final TestEvaluation? evaluation;
  final String? error;

  const TestState({
    this.session,
    this.items = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.isGeneratingEvaluation = false,
    this.evaluation,
    this.error,
  });

  TestState copyWith({
    TestSession? session,
    List<TestItem>? items,
    int? currentIndex,
    bool? isLoading,
    bool? isGeneratingEvaluation,
    TestEvaluation? evaluation,
    String? error,
    bool clearError = false,
  }) {
    return TestState(
      session: session ?? this.session,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      isGeneratingEvaluation:
          isGeneratingEvaluation ?? this.isGeneratingEvaluation,
      evaluation: evaluation ?? this.evaluation,
      error: clearError ? null : (error ?? this.error),
    );
  }

  TestItem? get currentItem =>
      items.isNotEmpty && currentIndex < items.length
          ? items[currentIndex]
          : null;

  bool get isLastItem => currentIndex >= items.length - 1;
  bool get isFinished => session?.status == 'completed';
  double get progress => items.isEmpty ? 0 : (currentIndex + 1) / items.length;
}

// ─── Provider ───

class TestNotifier extends StateNotifier<TestState> {
  final TestGenerator _generator = TestGenerator();

  TestNotifier() : super(const TestState());

  /// 开始新评测
  Future<void> startTest({
    required List<Map<String, String>> words,
    required Map<QuestionType, int> config,
    required String difficulty,
    String testType = 'mixed',
    String? resourceCode,
    String? resourceType,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 创建 session
      final session = TestSession(
        testType: testType,
        difficulty: difficulty,
        resourceCode: resourceCode,
        resourceType: resourceType,
        status: 'in_progress',
      );
      await DatabaseService.insert(session);

      // 生成题目
      final items = _generator.generateTest(
        words: words,
        config: config,
        difficulty: difficulty,
        testSessionId: session.id as int,
      );

      // 保存题目
      session.totalItems = items.length;
      await DatabaseService.update(session);

      for (final item in items) {
        await DatabaseService.insert(item);
      }

      state = TestState(
        session: session,
        items: items,
        currentIndex: 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 提交当前题答案
  Future<void> submitAnswer({
    String? userAnswer,
    String? userAudioPath,
    String? audioBase64,
  }) async {
    final item = state.currentItem;
    if (item == null) return;

    item.userAnswer = userAnswer;
    item.userAudioPath = userAudioPath;

    // 本地判分（非语音类）
    final type = item.type;
    if (_isLocalScoring(type)) {
      _scoreLocally(item);
    } else if (audioBase64 != null && _isSpeechScoring(type)) {
      await _scoreSpeech(item, audioBase64);
    }

    await DatabaseService.update(item);

    // 更新 session
    final session = state.session!;
    session.completedItems = state.currentIndex + 1;
    await DatabaseService.update(session);

    state = state.copyWith(
      session: session,
      items: List.from(state.items),
    );
  }

  /// 下一题
  void nextItem() {
    if (state.isLastItem) return;
    state = state.copyWith(currentIndex: state.currentIndex + 1);
  }

  /// 上一题
  void previousItem() {
    if (state.currentIndex <= 0) return;
    state = state.copyWith(currentIndex: state.currentIndex - 1);
  }

  /// 跳转到指定题目
  void goToItem(int index) {
    if (index < 0 || index >= state.items.length) return;
    state = state.copyWith(currentIndex: index);
  }

  /// 完成评测并生成 AI 评价
  Future<void> finishTest() async {
    state = state.copyWith(isGeneratingEvaluation: true);

    try {
      final session = state.session!;
      final items = state.items;

      // 计算总分
      final scoredItems = items.where((i) => i.score != null);
      double totalScore = 0;
      if (scoredItems.isNotEmpty) {
        totalScore = scoredItems.map((i) => i.score!).reduce((a, b) => a + b) /
            scoredItems.length;
      }

      session.totalScore = totalScore;
      session.completedAt = DateTime.now();
      session.durationSeconds =
          session.completedAt!.difference(session.startedAt).inSeconds;
      session.status = 'completed';
      await DatabaseService.update(session);

      // 生成 AI 评价
      final evalResult = await EvaluationApi.generateEvaluation(
        items: items
            .map((i) => {
                  'question_type': i.questionType,
                  'ref_text': i.refText,
                  'score': i.score ?? 0,
                  'is_correct': i.isCorrect ?? false,
                })
            .toList(),
        difficulty: session.difficulty,
      );

      TestEvaluation? evaluation;
      if (evalResult != null) {
        evaluation = TestEvaluation(
          testSessionId: session.id as int,
          overallScore: (evalResult['overall_score'] as num?)?.toDouble(),
          categoryScoresJson: jsonEncode(evalResult['category_scores']),
          weakPoints: evalResult['weak_points'] as String?,
          suggestions: evalResult['suggestions'] as String?,
        );
        await DatabaseService.insert(evaluation);
      }

      state = TestState(
        session: session,
        items: items,
        currentIndex: state.currentIndex,
        evaluation: evaluation,
        isGeneratingEvaluation: false,
      );
    } catch (e) {
      state = state.copyWith(
        isGeneratingEvaluation: false,
        error: e.toString(),
      );
    }
  }

  /// 加载已有评测
  Future<void> loadTest(int sessionId) async {
    state = state.copyWith(isLoading: true);
    try {
      final session = await DatabaseService.findById<TestSession>(sessionId, () => TestSession());
      final items = await DatabaseService.findByCondition<TestItem>(
        () => TestItem(),
        where: 'test_session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'item_order ASC',
      );
      final evaluations = await DatabaseService.findByCondition<TestEvaluation>(
        () => TestEvaluation(),
        where: 'test_session_id = ?',
        whereArgs: [sessionId],
      );

      state = TestState(
        session: session,
        items: items,
        currentIndex: 0,
        isLoading: false,
        evaluation: evaluations.isNotEmpty ? evaluations.first : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 重置
  void reset() {
    state = const TestState();
  }

  // ─── 内部 ───

  bool _isLocalScoring(QuestionType type) {
    return type == QuestionType.spelling ||
        type == QuestionType.mcq ||
        type == QuestionType.reorder;
  }

  bool _isSpeechScoring(QuestionType type) {
    return type == QuestionType.wordPron ||
        type == QuestionType.phrasePron ||
        type == QuestionType.sentencePron;
  }

  void _scoreLocally(TestItem item) {
    final correct = item.correctAnswer?.trim().toLowerCase() ?? '';
    final user = item.userAnswer?.trim().toLowerCase() ?? '';

    if (item.type == QuestionType.reorder) {
      // 组句题：移除多余空格后比较
      final c = correct.replaceAll(RegExp(r'\s+'), ' ');
      final u = user.replaceAll(RegExp(r'\s+'), ' ');
      item.isCorrect = c == u;
      item.score = item.isCorrect! ? 100.0 : 0.0;
    } else if (item.type == QuestionType.spelling) {
      // 拼写填空：精确匹配
      item.isCorrect = correct == user;
      item.score = item.isCorrect! ? 100.0 : _partialMatchScore(correct, user);
    } else if (item.type == QuestionType.mcq) {
      // 选择题：精确匹配
      item.isCorrect = correct == user;
      item.score = item.isCorrect! ? 100.0 : 0.0;
    }
  }

  double _partialMatchScore(String correct, String user) {
    if (correct.isEmpty) return 0;
    int matches = 0;
    for (int i = 0; i < correct.length && i < user.length; i++) {
      if (correct[i] == user[i]) matches++;
    }
    return (matches / correct.length * 100).clamp(0, 100);
  }

  Future<void> _scoreSpeech(TestItem item, String audioBase64) async {
    try {
final coreType = item.type == QuestionType.wordPron
 ? 'word.eval'
 : 'sent.eval';

      final result = await EvaluationApi.scorePronunciation(
        coreType: coreType,
        refText: item.refText,
        audioBase64: audioBase64,
      );

      if (result != null) {
        item.rawResult = jsonEncode(result);
        // 声通返回 overall 或 score 字段
        final score = (result['overall'] ?? result['score'] ?? 0) as num;
        item.score = score.toDouble();
        item.isCorrect = item.score! >= 60;
        item.aiAnalysis = jsonEncode({
          'accuracy': result['accuracy'],
          'fluency': result['fluency'],
          'integrity': result['integrity'],
          'words': result['words'],
        });
      } else {
        item.score = 0;
        item.isCorrect = false;
      }
    } catch (e) {
      item.score = 0;
      item.isCorrect = false;
      item.rawResult = '{"error": "${e.toString()}"}';
    }
  }
}

// ─── Providers ───

final testProvider =
    StateNotifierProvider<TestNotifier, TestState>((ref) => TestNotifier());
