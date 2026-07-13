// ignore_for_file: unused_field
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/providers/test_provider.dart';
import 'package:vidlang/services/shengtong_http_evaluator.dart';
import 'package:vidlang/widgets/app_dialogs.dart';

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
  final bool _isRecording = false;
  String? _recordingPath;
  final bool _ttsPlayed = false;
  final bool _isPlayingTts = false;
  String _appDir = '';

  // ─── 跟读评分状态（参考 test_page.dart 实现） ───
  // idle → recording → evaluating → scored
  final AudioRecorder _pronRecorder = AudioRecorder();
  String? _pronRecordingPath;
  double? _pronScore;
  String? _pronFeedback;
  final int _pronRecordingSeconds = 0;
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

  // ... (保留原有方法，只修改 _evaluatePronunciation)

  Future<void> _evaluatePronunciation(
    String audioPath,
    String refText,
    String typeName,
  ) async {
    if (refText.isEmpty) {
      if (mounted) {
        return;
      }
    }

    try {
      // 确定评测类型
      final coreType = typeName.contains('word') ? 'word.eval' : 'sent.eval';

      // 从 AppKeysService 获取动态密钥
      final stAppKey = AppKeysService.instance.shengtongAppKey;
      final stSecretKey = AppKeysService.instance.shengtongSecretKey;

      if (stAppKey == null ||
          stAppKey.isEmpty ||
          stSecretKey == null ||
          stSecretKey.isEmpty) {
        debugPrint('⚠️ [TestSession] 声通密钥未就绪，请确认已登录且 app_settings 已配置');
        if (mounted) {
          setState(() {
            _pronScore = 0.0;
            _pronFeedback = '声通服务未配置，请联系管理员';
          });
        }
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
        userId: 'test_user_${DateTime.now().millisecondsSinceEpoch}',
      );

      final overall = (result['overall'] as num?)?.toDouble();
      if (mounted) {
        setState(() {
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
    } catch (e) {
      debugPrint('❌ [TestSession] 声通评测异常: $e');
      if (mounted) {
        setState(() {
          _pronScore = null;
        });
        AppToast.show(context, '评测失败: $e', type: ToastType.error);
      }
    } finally {
      // 清理临时文件
      try {
        await File(audioPath).delete();
      } catch (_) {}
    }
  }

  /// 提交跟读评分结果
  Future<void> _submitPronResult(double score) async {
    await ref
        .read(testProvider.notifier)
        .submitAnswer(
          userAnswer: 'pron_score_${score.round()}',
          userAudioPath: _pronRecordingPath,
        );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('测试')),
      body: const Center(child: Text('Test Session Page')),
    );
  }
}
