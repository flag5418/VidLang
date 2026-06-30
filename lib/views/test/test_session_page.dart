import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/models/test_models.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/providers/test_provider.dart';
import 'package:vidlang/services/shengtong_evaluator.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/views/test/test_result_page.dart';
import 'package:vidlang/utils/dialog_utils.dart';

/// 逐题作答页面
class TestSessionPage extends ConsumerStatefulWidget {
  const TestSessionPage({super.key});

  @override
  ConsumerState<TestSessionPage> createState() => _TestSessionPageState();
}

class _TestSessionPageState extends ConsumerState<TestSessionPage> {
  final _answerController = TextEditingController();
  final _audioPlayer = AudioPlayer();
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordingPath;
  bool _ttsPlayed = false;
  bool _isPlayingTts = false;
  String _appDir = '';

  // ─── 跟读评分状态（参考 test_page.dart 实现） ───
  String _pronState = 'idle'; // idle → recording → evaluating → scored
  final AudioRecorder _pronRecorder = AudioRecorder();
  String? _pronRecordingPath;
  double? _pronScore;
  String? _pronFeedback;
  int _pronRecordingSeconds = 0;
  Timer? _pronRecordingTimer;

  @override
  void initState() {
    super.initState();
    _initAppDir();
  }

  Future<void> _initAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    _appDir = dir.path;
  }

  @override
  void dispose() {
    _answerController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _pronRecordingTimer?.cancel();
    _pronRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(testProvider);
    final item = state.currentItem;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('评测')),
        body: const Center(child: Text('暂无题目')),
      );
    }

    final type = item.type;

    return Scaffold(
      appBar: AppBar(
        title: Text('${type.label} (${state.currentIndex + 1}/${state.items.length})'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitDialog(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: state.progress),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPrompt(item),
            const SizedBox(height: 24),
            _buildAnswerArea(type),
            const SizedBox(height: 24),
            _buildNavigation(state),
          ],
        ),
      ),
    );
  }

  Widget _buildPrompt(TestItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              item.prompt,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (_isSpeechType(item.type)) ...[
              const SizedBox(height: 12),
              Text(
                item.refText,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
            if (_isTtsType(item.type)) ...[
              const SizedBox(height: 12),
              IconButton.filled(
                icon: _isPlayingTts
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.volume_up),
                onPressed: _isPlayingTts ? null : () => _playPromptAudio(item),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerArea(QuestionType type) {
    switch (type) {
      case QuestionType.listenChoose:
      case QuestionType.listenMeaning:
      case QuestionType.listenReply:
      case QuestionType.mcq:
      case QuestionType.definitionChoice:
      case QuestionType.translateMeaning:
        return _buildMcqArea();
      case QuestionType.meaningWrite:
      case QuestionType.sentenceDictation:
      case QuestionType.translateBoth:
        return _buildTextInputArea();
      case QuestionType.wordPron:
      case QuestionType.phrasePron:
      case QuestionType.sentencePron:
        return _buildPronunciationArea();
      case QuestionType.spelling:
        return _buildSpellingArea();
      case QuestionType.reorder:
        return _buildReorderArea();
      case QuestionType.wordRelation:
        return _buildMcqArea(); // 复用选择题区域，后续改为多选
    }
  }

  // ─── 选择题/听音选词 ───

  Widget _buildMcqArea() {
    final item = ref.read(testProvider).currentItem!;

    // 听音选词：必须先播放 TTS 才能看到选项
    if (item.type == QuestionType.listenChoose && !_ttsPlayed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('请先点击上方喇叭按钮播放音频'),
        ),
      );
    }

    final options = _parseDistractors(item);
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      children: options.map((option) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: () => _submitWithAnswer(option),
            child: Text(option),
          ),
        );
      }).toList(),
    );
  }

  List<String> _parseDistractors(TestItem item) {
    if (item.distractorsJson == null || item.distractorsJson!.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(item.distractorsJson!) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── 文本输入 ───

  Widget _buildTextInputArea() {
    return Column(
      children: [
        TextField(
          controller: _answerController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '请输入答案...',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _submitWithAnswer(_answerController.text),
          child: const Text('提交'),
        ),
      ],
    );
  }

  // ─── 跟读录音（参考 test_page.dart 完整实现） ───

  Widget _buildPronunciationArea() {
    final colorScheme = Theme.of(context).colorScheme;
    final item = ref.read(testProvider).currentItem!;
    final refText = item.refText;
    final type = item.type;
    final typeLabel = type == QuestionType.wordPron
        ? '跟读单词'
        : type == QuestionType.phrasePron
        ? '跟读短语'
        : '跟读句子';
    final isRecording = _pronState == 'recording';
    final isEvaluating = _pronState == 'evaluating';
    final isScored = _pronState == 'scored';

    return Column(
      children: [
        // 显示参考文本
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(fontSize: 13, color: colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  refText,
                  style: TextStyle(
                    fontSize: type == QuestionType.wordPron ? 24 : 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 评分结果
        if (isScored && _pronScore != null) ...[
          _buildPronScoreResult(colorScheme),
          const SizedBox(height: 16),
        ],

        // 录音按钮（参考 test_page.dart 状态机）
        Center(
          child: GestureDetector(
            onTapDown: (_) => _startPronRecording(),
            onTapUp: (_) => _stopAndEvaluatePronunciation(),
            onTapCancel: () => _cancelPronRecording(),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isRecording
                    ? Colors.red
                    : (isScored ? colorScheme.outline : colorScheme.primary),
                shape: BoxShape.circle,
                boxShadow: isRecording
                    ? [BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 4)]
                    : null,
              ),
              child: isRecording
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mic, size: 28, color: Colors.white),
                        const SizedBox(height: 2),
                        Text(
                          '${_pronRecordingSeconds}s',
                          style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : isScored
                      ? const Icon(Icons.replay_rounded, size: 32)
                      : const Icon(Icons.mic, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isRecording ? '松开结束录音' : (isScored ? '点击重新录音' : '按住录音'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        if (isEvaluating) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text('正在评分...', style: TextStyle(fontSize: 12, color: colorScheme.primary)),
            ],
          ),
        ],
      ],
    );
  }

  /// 构建跟读评分结果（与 test_page.dart 一致）
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: scoreColor.withValues(alpha: 0.15)),
            child: Center(
              child: Text(
                '${score.round()}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scoreColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score >= 90 ? '优秀！' : score >= 75 ? '良好' : score >= 60 ? '及格' : '继续加油',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                if (_pronFeedback != null && _pronFeedback!.isNotEmpty)
                  Text(
                    _pronFeedback!,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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

  // ─── 拼写填空 ───

  Widget _buildSpellingArea() {
    final item = ref.read(testProvider).currentItem!;
    final masked = item.prompt.replaceAll('请拼写完整单词：', '').trim();

    return Column(
      children: [
        Text(
          masked,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                letterSpacing: 6,
              ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _answerController,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '输入完整单词',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _submitWithAnswer(_answerController.text),
          child: const Text('提交'),
        ),
      ],
    );
  }

  // ─── 组句题 ───

  Widget _buildReorderArea() {
    final item = ref.read(testProvider).currentItem!;
    // 首次进入时打乱词序
    if (_answerController.text.isEmpty) {
      final shuffled = item.refText.split(' ')..shuffle();
      _answerController.text = shuffled.join(' ');
    }

    final words = _answerController.text.split(' ');

    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: words.map((w) {
            return ActionChip(
              label: Text(w),
              onPressed: () {
                // 点击词条追加到下方输入框
                final current = _answerController.text;
                final newText = current.replaceFirst(w, '').replaceAll(RegExp(r'\s+'), ' ').trim();
                _answerController.text = '$newText $w'.trim();
                setState(() {});
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _answerController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '按正确顺序输入句子',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => _submitWithAnswer(_answerController.text),
          child: const Text('提交'),
        ),
      ],
    );
  }

  // ─── 导航 ───

  Widget _buildNavigation(TestState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: state.currentIndex > 0
              ? () {
                    ref.read(testProvider.notifier).previousItem();
                  _resetPronState();
                  _answerController.clear();
                  _recordingPath = null;
                  _ttsPlayed = false;
                  _isPlayingTts = false;
                  setState(() {});
                }
              : null,
          child: const Text('上一题'),
        ),
        ElevatedButton(
          onPressed: state.isLastItem
              ? () async {
                  await ref.read(testProvider.notifier).finishTest();
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const TestResultPage()),
                    );
                  }
                }
              : () {
                    ref.read(testProvider.notifier).nextItem();
                    _resetPronState();
                    _answerController.clear();
                    _recordingPath = null;
                    _ttsPlayed = false;
                    _isPlayingTts = false;
                  setState(() {});
                },
          child: Text(state.isLastItem ? '完成评测' : '下一题'),
        ),
      ],
    );
  }

  // ─── 音频操作 ───

  Future<void> _playPromptAudio(TestItem item) async {
    // 有本地音频则直接播放
    if (item.promptAudioPath != null) {
      await _audioPlayer.play(DeviceFileSource(item.promptAudioPath!));
      return;
    }

    // TTS 类型：使用统一 TtsService（与视频播放器清晰朗读一致）
    if (_isTtsType(item.type)) {
      if (_isPlayingTts) return; // 防止重复点击
      setState(() => _isPlayingTts = true);

      try {
        final subState = ref.read(subscriptionProvider);
        await TtsService().speakClarity(
          text: item.refText,
          mode: subState.mode,
          onComplete: () {
            if (!mounted) return;
            setState(() {
              _ttsPlayed = true;
              _isPlayingTts = false;
            });
          },
        );
        // 如果 speakClarity 同步返回，也标记状态
        if (mounted && !_ttsPlayed) {
          setState(() {
            _ttsPlayed = true;
            _isPlayingTts = false;
          });
        }
      } catch (e) {
        debugPrint('TTS error: $e');
        if (mounted) setState(() => _isPlayingTts = false);
      }
    }
  }

  // ─── 跟读录音控制方法（参考 test_page.dart） ───

  /// 开始跟读录音
  Future<void> _startPronRecording() async {
    if (_pronState == 'recording') return;

    final hasPermission = await _pronRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('需要麦克风权限才能跟读')));
      }
      return;
    }

    setState(() {
      _pronState = 'recording';
      _pronRecordingSeconds = 0;
    });

    try {
      final tmpDir = await getTemporaryDirectory();
      _pronRecordingPath = '${tmpDir.path}/pron_${DateTime.now().millisecondsSinceEpoch}.wav';
      // 使用 WAV 格式录制（声通要求 16000Hz/16bit/单声道 WAV）
      await _pronRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _pronRecordingPath!,
      );

      _pronRecordingTimer?.cancel();
      _pronRecordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _pronRecordingSeconds++);
      });
    } catch (e) {
      debugPrint('Start pronunciation recording error: $e');
      if (mounted) setState(() => _pronState = 'idle');
    }
  }

  /// 停止录音并评分
  Future<void> _stopAndEvaluatePronunciation() async {
    if (_pronState != 'recording') return;
    _pronRecordingTimer?.cancel();

    try {
      await _pronRecorder.stop();
    } catch (e) {
      debugPrint('Stop pronunciation recording error: $e');
    }

    if (!mounted || _pronRecordingPath == null || _pronRecordingSeconds < 1) {
      if (mounted) setState(() => _pronState = 'idle');
      return;
    }

    // 显示评估中状态
    setState(() => _pronState = 'evaluating');

    final item = ref.read(testProvider).currentItem!;
    await _evaluatePronunciation(_pronRecordingPath!, item.refText, item.type.name);
  }

  /// 取消录音
  void _cancelPronRecording() {
    if (_pronState != 'recording') return;
    _pronRecordingTimer?.cancel();
    _pronRecorder.stop();
    if (mounted) setState(() => _pronState = 'idle');
  }

  /// 声通实时评测（本地 WebSocket 直连，支持流式评分）
  ///
  /// 密钥从 AppKeysService 动态加载（登录时从 app_settings 表读取），
  /// 与 TTS 的 DashScopeTtsService 架构保持一致。
  Future<void> _evaluatePronunciation(String audioPath, String refText, String typeName) async {
    if (refText.isEmpty) {
      if (mounted) setState(() => _pronState = 'idle');
      return;
    }

    try {
      // 确定评测类型
      final coreType = typeName.contains('word') ? 'word.eval' : 'sent.eval';

      // 从 AppKeysService 获取动态密钥（与 TTS 统一架构）
final stAppKey = AppKeysService.instance.shengtongAppKey;
final stSecretKey = AppKeysService.instance.shengtongSecretKey;

      if (stAppKey == null || stAppKey.isEmpty || stSecretKey == null || stSecretKey.isEmpty) {
        debugPrint('⚠️ [TestSession] 声通密钥未就绪，请确认已登录且 app_settings 已配置');
        if (mounted) {
          setState(() {
            _pronState = 'scored';
            _pronScore = 0.0;
            _pronFeedback = '声通服务未配置，请联系管理员';
          });
        }
        return;
      }

      // 使用 ShengtongEvaluator 本地 WebSocket 直连（支持实时流式评测）
      final evaluator = ShengtongEvaluator(
        appKey: stAppKey,
        secretKey: stSecretKey,
        baseUrl: AppKeysService.shengtongBaseUrl,
      );

      final completer = Completer<Map<String, dynamic>?>();
      evaluator.onResult = (r) {
        if (!completer.isCompleted) completer.complete(r);
      };
      evaluator.onError = (e) {
        debugPrint('❌ [TestSession] 声通评测错误: $e');
        if (!completer.isCompleted) completer.complete(null);
      };

      // 连接并开始评测
      await evaluator.connect(coreType);
      await evaluator.start(
        coreType: coreType,
        refText: refText,
        userId: 'test_user',
      );

      // 发送音频数据
      final file = File(audioPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        evaluator.feed(bytes);
      }

      // 停止评测并等待结果
      evaluator.stop();
      final result = await completer.future.timeout(const Duration(seconds: 15));
      evaluator.dispose();

      if (result != null) {
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
          _submitPronResult(overall ?? 0);
        }
      } else {
        debugPrint('⚠️ [TestSession] 声通评测返回空结果');
        if (mounted) {
          setState(() {
            _pronState = 'scored';
            _pronScore = 0.0;
            _pronFeedback = '评分失败，请重试';
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [TestSession] 声通评测异常: $e');
      if (mounted) {
        setState(() {
          _pronState = 'idle';
          _pronScore = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('评测失败: $e')));
      }
    } finally {
      // 清理临时文件
      try { await File(audioPath).delete(); } catch (_) {}
    }
  }

  /// 提交跟读评分结果
  Future<void> _submitPronResult(double score) async {
    await ref.read(testProvider.notifier).submitAnswer(
      userAnswer: 'pron_score_${score.round()}',
      userAudioPath: _pronRecordingPath,
    );
    setState(() {});
  }

  Future<void> _playRecording() async {
    if (_recordingPath != null) {
      await _audioPlayer.play(DeviceFileSource(_recordingPath!));
    }
  }

  // ─── 提交 ───

  Future<void> _submitWithAnswer(String answer) async {
    await ref.read(testProvider.notifier).submitAnswer(userAnswer: answer);
    _answerController.clear();
    setState(() {});
  }

  // 保留旧方法以兼容（但不再使用）
  Future<void> _submitRecording() async {
    // 已迁移到 _submitPronResult
    if (_pronScore != null) {
      await _submitPronResult(_pronScore!);
    }
  }

  void _showExitDialog() {
    DialogUtils.show(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('退出评测'),
        content: const Text('退出后进度不会保存，确定退出？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('继续评测')),
          TextButton(
            onPressed: () {
              ref.read(testProvider.notifier).reset();
              Navigator.pop(c);
              Navigator.pop(context);
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  bool _isSpeechType(QuestionType type) {
    return type == QuestionType.wordPron ||
        type == QuestionType.phrasePron ||
        type == QuestionType.sentencePron;
  }

  /// 重置跟读状态（切换题目时调用）
  void _resetPronState() {
    _pronRecordingTimer?.cancel();
    _pronState = 'idle';
    _pronScore = null;
    _pronFeedback = null;
    _pronRecordingPath = null;
    _pronRecordingSeconds = 0;
  }

  bool _isTtsType(QuestionType type) {
    return type == QuestionType.listenChoose ||
        type == QuestionType.listenMeaning ||
        type == QuestionType.listenReply ||
        type == QuestionType.sentenceDictation;
  }
}
