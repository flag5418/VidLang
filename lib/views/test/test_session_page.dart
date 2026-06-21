import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:vidlang/models/test_models.dart';
import 'package:vidlang/providers/test_provider.dart';
import 'package:vidlang/services/evaluation_api.dart';
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
  String _appDir = '';

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
                icon: const Icon(Icons.volume_up),
                onPressed: () => _playPromptAudio(item),
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

  // ─── 跟读录音 ───

  Widget _buildPronunciationArea() {
    return Column(
      children: [
        if (_recordingPath != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('录音完成'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _playRecording(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(() => _recordingPath = null),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _submitRecording(),
            child: const Text('提交评测'),
          ),
        ] else
          GestureDetector(
            onTapDown: (_) => _startRecording(),
            onTapUp: (_) => _stopRecording(),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Icon(
                Icons.mic,
                size: 48,
                color: _isRecording ? Colors.white : Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
      ],
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
                  _answerController.clear();
                  _recordingPath = null;
                  _ttsPlayed = false;
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
                  _answerController.clear();
                  _recordingPath = null;
                  _ttsPlayed = false;
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

    // TTS 类型：动态合成后播放
    if (_isTtsType(item.type)) {
      try {
        final base64Audio = await EvaluationApi.getTtsAudio(item.refText);
        if (base64Audio == null || base64Audio.isEmpty) return;
        final bytes = base64Decode(base64Audio);
        final file = File('$_appDir/tts_${item.itemOrder}.mp3');
        await file.writeAsBytes(bytes);
        await _audioPlayer.play(DeviceFileSource(file.path));
        setState(() => _ttsPlayed = true);
      } catch (e) {
        debugPrint('TTS error: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        setState(() => _isRecording = true);
        final path = '$_appDir/pron_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        _recordingPath = path;
      }
    } catch (e) {
      debugPrint('Recording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      setState(() => _isRecording = false);
      await _audioRecorder.stop();
    } catch (e) {
      debugPrint('Stop recording error: $e');
    }
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

  Future<void> _submitRecording() async {
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);
      await ref.read(testProvider.notifier).submitAnswer(
            userAnswer: _recordingPath,
            userAudioPath: _recordingPath,
            audioBase64: base64Audio,
          );
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

  bool _isTtsType(QuestionType type) {
    return type == QuestionType.listenChoose ||
        type == QuestionType.listenMeaning ||
        type == QuestionType.listenReply ||
        type == QuestionType.sentenceDictation;
  }
}
