/// 通用跟读组件 — ShadowReader（双页设计）
///
/// 页面1：跟读页 — 字幕 + 识别着色 + 音量 + 两端对齐控制栏
/// 页面2：评价页 — 总分 + 维度 + AI评价 + 操作按钮
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:vidlang/services/app_keys_service.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/providers/player_engine_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/learning_stats_service.dart';
import 'package:vidlang/services/ai_evaluation_service.dart';
import 'package:vidlang/services/evaluation_storage_service.dart';
import 'package:vidlang/services/shengtong_http_evaluator.dart';
import 'package:vidlang/models/shengtong_evaluation_result.dart';
import 'package:vidlang/services/speech_to_text_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/widgets/selectable_english_line.dart';

// ─── 回调类型 ───────────────────────────────────────────
typedef ScoreCallback = Future<void> Function({
  required double? overall,
  required double? fluency,
  required double? accuracy,
  required double? completeness,
  required Map<String, dynamic>? rawResult,
});

typedef AiEvaluationCallback = Future<void> Function({
  required String resourceCode,
  required String resourceTitle,
  required String language,
  required double? overallScore,
  required String? summary,
});

// ─── 配置 ─────────────────────────────────────────────
class ShadowReaderConfig {
  final Subtitles subtitle;
  final String resourceType;
  final String resourceCode;
  final String resourceTitle;
  final String language;
  final bool isMusic;
  final String scope;
  final String? chapterCode;
  final Duration Function()? getPosition;
  final Future<void> Function(Duration)? seekTo;
  final Future<void> Function()? togglePlayPause;
  final Future<void> Function()? pause;
  final Future<void> Function()? play;
  final Future<void> Function(double)? setOriginalVolume;
  final Future<void> Function(double)? setSpeed;
  final double? currentSpeed;
  final bool? getSingleSentencePause;
  final Future<void> Function(bool)? setSingleSentencePause;
  final Future<void> Function(bool)? setRecording;
  final Future<void> Function(double)? setLastFollowScore;
  final dynamic Function()? getCurrentVideo;
  final Future<void> Function(String)? speakSubtitle;
  final bool? isTtsSpeaking;
  final void Function(int currentWordIndex)? onTtsWordIndexChanged; // TTS 单词索引变化回调
  final void Function(bool isPlaying)? onTtsPlayingStateChanged; // TTS 播放状态变化回调
  final ScoreCallback? onScore;
  final AiEvaluationCallback? onAiEvaluation;
  final Future<bool?> Function()? getHeadphoneMode;
  final String? audioType;
  final Duration? currentPosition;
  final int? currentSubtitleIndex;
  final Future<void> Function(int)? seekToSubtitle;
  final Future<void> Function()? nextSentence;
  final Future<void> Function()? previousSentence;
  final Future<void> Function(int)? playAtSubtitleIndex;
  final SubscriptionMode? subscriptionMode;
  final Future<void> Function()? onFreeModeSpeechResult;

  String get followLabel => isMusic ? '跟唱' : '跟读';

  const ShadowReaderConfig({
    required this.subtitle,
    required this.resourceType,
    required this.resourceCode,
    required this.resourceTitle,
    this.language = 'en',
    this.isMusic = false,
    this.scope = 'sentence',
    this.chapterCode,
    this.getPosition,
    this.seekTo,
    this.togglePlayPause,
    this.pause,
    this.play,
    this.setOriginalVolume,
    this.setSpeed,
    this.currentSpeed,
    this.getSingleSentencePause,
    this.setSingleSentencePause,
    this.setRecording,
    this.setLastFollowScore,
    this.getCurrentVideo,
    this.speakSubtitle,
    this.isTtsSpeaking,
    this.onTtsWordIndexChanged,
    this.onTtsPlayingStateChanged,
    this.onScore,
    this.onAiEvaluation,
    this.getHeadphoneMode,
    this.audioType,
    this.currentPosition,
    this.currentSubtitleIndex,
    this.seekToSubtitle,
    this.nextSentence,
    this.previousSentence,
    this.playAtSubtitleIndex,
    this.subscriptionMode,
    this.onFreeModeSpeechResult,
  });
}

// ─── 组件 ─────────────────────────────────────────────
class ShadowReaderComponent extends ConsumerStatefulWidget {
  final ShadowReaderConfig config;
  final bool _isInline;
  final VoidCallback? _onClose;

  const ShadowReaderComponent({super.key, required this.config})
    : _isInline = false,
      _onClose = null;
  const ShadowReaderComponent._inline({required this.config, this._onClose})
    : _isInline = true;

  static void show(BuildContext context, {required ShadowReaderConfig config}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (_) => ShadowReaderComponent(config: config),
    );
  }

  static Widget inline({
    required ShadowReaderConfig config,
    double heightFactor = 0.55,
    VoidCallback? onClose,
  }) {
    return Builder(
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final isLandscape = size.width > size.height && size.width >= 600;
        // 横屏时适当增加占比（防止截断），但不超出 65%，避免遮挡视频区域导致"全黑"
        final factor = isLandscape
            ? (heightFactor > 0.6 ? 0.6 : heightFactor)
            : heightFactor;
        return SafeArea(
          bottom: true,
          child: Container(
            height: size.height * factor,
            color: AppColors.surface, // 添加背景色避免黑屏
            child: ShadowReaderComponent._inline(
              config: config,
              onClose: onClose,
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<ShadowReaderComponent> createState() =>
      _ShadowReaderComponentState();
}

// ─── State ────────────────────────────────────────────
class _ShadowReaderComponentState extends ConsumerState<ShadowReaderComponent>
    with SingleTickerProviderStateMixin {
  late final AudioRecorder _recorder = AudioRecorder();
  dynamic _evaluator;
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  Timer? _autoStopTimer;
  Timer? _recognitionTimer;
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;
  String? _recordingPath;
  bool _isEvaluating = false;
  int _recordingSeconds = 0;

  String _state = 'idle'; // idle | listening | evaluating | scored
  String _currentPage = 'recording'; // recording | evaluation
  bool _isMuted = false;
  double _savedVolume = 0.6;
  bool _isComparing = false;
  String _liveTranscription = '';

  double? _overallScore;
  double? _fluencyScore;
  double? _accuracyScore;
  double? _completenessScore;
  List<RecognizedWord> _recognizedWords = [];
  ShengtongEvaluationResult? _lastEvaluationResult;
  
  // AI 分析结果（手动触发）
  AiAnalysisResult? _aiAnalysisResult;
  bool _isAiAnalyzing = false;
  
  // TTS 单词高亮状态
  int _ttsCurrentWordIndex = -1;
  List<String> _ttsWords = [];
  Timer? _ttsTimer;

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _recognitionTimer?.cancel();
    _recordingTimer?.cancel();
    _evaluator?.dispose();
    _audioPlayer.dispose();
    _recorder.stop();
    super.dispose();
  }

  // ─── 主入口 ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    if (widget._isInline) {
      return _currentPage == 'evaluation'
          ? _buildEvaluationPage(context, cfg)
          : _buildRecordingPage(context, cfg);
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, sc) {
        return _currentPage == 'evaluation'
            ? _buildEvaluationPage(context, cfg)
            : _buildRecordingPage(context, cfg);
      },
    );
  }

  // ━━━ 跟读页 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 统一使用逻辑像素（非 ScreenUtil）确保跨设备一致性
  // 按钮: 36px, 图标: 18px, 间距: 8px, 内边距: 12px

  Widget _buildRecordingPage(BuildContext context, ShadowReaderConfig cfg) {
    final isListening = _state == 'listening';
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // ── 拖拽手柄 / 关闭按钮（内联模式）──
          if (widget._isInline) ...[
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          // ── 字幕区（可滚动，避免溢出）──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: 原文字幕（可点击选择单词）
                  Center(
                    child: SelectableEnglishLine(
                      text: cfg.subtitle.content,
                      fontSize: 18,
                      fontColor: Colors.white,
                      selectedBgColor: AppColors.primary.withValues(alpha: 0.3),
                      onSelectionChanged: (words) {
                        if (cfg.speakSubtitle != null && words.isNotEmpty) {
                          cfg.speakSubtitle!(words.join(' '));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 录音声波图（仅在录音时显示）
                  if (isListening) ...[
                    _buildAudioWaveform(),
                    const SizedBox(height: 12),
                  ],
                  // 录音计时器（仅在录音时显示）
                  if (isListening) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatRecordingTime(_recordingSeconds),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Colors.white12),
          // ── 音量行 ──
          _buildVolumeRow(cfg),
          const Divider(height: 1, thickness: 0.5, color: Colors.white12),
          // ── 底部控制栏 ──
          _buildBottomControlBar(context, cfg),
        ],
      ),
    );
  }

  Widget _buildVolumeRow(ShadowReaderConfig cfg) {
    final state = ref.read(playerEngineProvider);
    final vol = (state.originalVolume * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleMute(cfg),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                _isMuted ? Icons.volume_off_rounded : Icons.volume_down_rounded,
                size: 18,
                color: _isMuted ? Colors.white38 : Colors.white54,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: state.originalVolume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                activeColor: AppColors.primary,
                inactiveColor: Colors.white24,
                onChanged: (v) {
                  cfg.setOriginalVolume?.call(v);
                  if (v > 0 && _isMuted) setState(() => _isMuted = false);
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$vol%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControlBar(BuildContext context, ShadowReaderConfig cfg) {
    final isListening = _state == 'listening';
    final hasRecording =
        _recordingPath != null && File(_recordingPath!).existsSync();
    final isScored = _state == 'scored';

    // 获取屏幕方向以决定是否采用更加紧凑的布局
    final isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 6, 12, isLandscape ? 4 : 10),
        child: Row(
          children: [
            // ── 关闭按钮（内联模式）──
            if (widget._isInline && widget._onClose != null) ...[
              _circleBtn(
                Icons.close_rounded,
                Colors.white54,
                32,
                18,
                onTap: widget._onClose,
                bg: Colors.white10,
              ),
              const SizedBox(width: 6),
            ],
            // ── 左组：导航 ──
            _circleBtn(
              Icons.skip_previous_rounded,
              Colors.white70,
              36,
              18,
              onTap: cfg.previousSentence != null
                  ? () {
                      _resetRecordingState();
                      cfg.previousSentence!();
                    }
                  : (cfg.playAtSubtitleIndex != null &&
                            cfg.currentSubtitleIndex != null
                        ? () {
                            _resetRecordingState();
                            cfg.playAtSubtitleIndex!(
                              cfg.currentSubtitleIndex! - 1,
                            );
                          }
                        : null),
              bg: Colors.white10,
            ),
            const SizedBox(width: 6),
            _circleBtn(
              Icons.play_arrow_rounded,
              Colors.white70,
              36,
              20,
              onTap: () => _replayOriginal(cfg),
              bg: Colors.white10,
            ),
            const SizedBox(width: 6),
            _circleBtn(
              Icons.skip_next_rounded,
              Colors.white70,
              36,
              18,
              onTap: cfg.nextSentence != null
                  ? () {
                      _resetRecordingState();
                      cfg.nextSentence!();
                    }
                  : (cfg.playAtSubtitleIndex != null &&
                            cfg.currentSubtitleIndex != null
                        ? () {
                            _resetRecordingState();
                            cfg.playAtSubtitleIndex!(
                              cfg.currentSubtitleIndex! + 1,
                            );
                          }
                        : null),
              bg: Colors.white10,
            ),
            const Spacer(),
            // ── 右组：操作 ──
            _circleBtn(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              isListening ? Colors.white : AppColors.primary,
              40,
              20,
              onTap: isListening
                  ? () => _stopRecording(context, cfg)
                  : () => _startRecording(context, cfg),
              bg: isListening
                  ? Colors.red
                  : AppColors.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 6),
            _circleBtn(
              Icons.replay_rounded,
              Colors.white54,
              36,
              18,
              onTap: (!isListening && hasRecording)
                  ? () => _playRecording()
                  : null,
              bg: Colors.white10,
            ),
            const SizedBox(width: 6),
            _circleBtn(
              Icons.compare_arrows_rounded,
              Colors.white54,
              36,
              18,
              onTap: (!isListening && hasRecording)
                  ? () => _compareAudio(cfg)
                  : null,
              bg: Colors.white10,
            ),
            const SizedBox(width: 6),
            _circleBtn(
              Icons.auto_awesome_rounded,
              Colors.white54,
              36,
              18,
              onTap: (!isListening && isScored)
                  ? () => _navigateToEvaluation()
                  : null,
              bg: Colors.white10,
            ),
          ],
        ),
      ),
    );
  }

  /// 统一圆形按钮组件
  /// [size] 按钮直径, [iconSize] 图标大小, [bg] 背景色
  Widget _circleBtn(
    IconData icon,
    Color iconColor,
    double size,
    double iconSize, {
    VoidCallback? onTap,
    Color? bg,
  }) {
    final enabled = onTap != null;
    final bgColor = !enabled
        ? Colors.white.withValues(alpha: 0.04)
        : (bg ?? Colors.white10);
    final icColor = !enabled ? Colors.white24 : iconColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, size: iconSize, color: icColor),
      ),
    );
  }

  // ━━━ 声波图可视化 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  
  Widget _buildAudioWaveform() {
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: _AudioWaveformAnimator(
        isRecording: _state == 'listening',
        color: AppColors.primary,
      ),
    );
  }

  /// 保存声通评测结果到文件（供分析使用）
  Future<void> _saveEvaluationResult(
    Map<String, dynamic> result,
    ShadowReaderConfig cfg,
  ) async {
    try {
      final tmpDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'shengtong_eval_${cfg.resourceCode}_${timestamp}.json';
      final filePath = '${tmpDir.path}/$fileName';
      
      final saveData = {
        'timestamp': DateTime.now().toIso8601String(),
        'resourceCode': cfg.resourceCode,
        'resourceType': cfg.resourceType,
        'refText': cfg.subtitle.content,
        'result': result,
      };
      
      final file = File(filePath);
      await file.writeAsString(jsonEncode(saveData));
      debugPrint('🎤 [ShadowReader] 评测结果已保存: $filePath');
    } catch (e) {
      debugPrint('🎤 [ShadowReader] 保存评测结果失败: $e');
    }
  }

  /// 保存评测结果到云端（按类型存储 50 条）
  Future<void> _saveEvaluationToCloud(
    ShadowReaderConfig cfg,
    ShengtongEvaluationResult result,
    int durationMs,
  ) async {
    try {
      final evalType = EvaluationStorageService.detectEvaluationType(cfg.subtitle.content);
      debugPrint('🎤 [ShadowReader] 保存评测到云端，类型: $evalType');
      
      final response = await EvaluationStorageService.saveEvaluation(
        evaluationType: evalType,
        result: result,
        resourceType: cfg.resourceType,
        resourceCode: cfg.resourceCode,
        resourceTitle: cfg.resourceTitle,
        refText: cfg.subtitle.content,
        durationMs: durationMs,
        language: cfg.language,
      );
      
      if (response['ok'] == true) {
        debugPrint('🎤 [ShadowReader] 云端保存成功: ${response['record_id']}');
        debugPrint('🎤 [ShadowReader] 该类型总记录数: ${response['summary']?['total_count']}');
      } else {
        debugPrint('⚠️ [ShadowReader] 云端保存失败: ${response['error']}');
      }
    } catch (e) {
      debugPrint('❌ [ShadowReader] 云端保存异常: $e');
    }
  }

  // ━━━ 评价页 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildEvaluationPage(BuildContext context, ShadowReaderConfig cfg) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height && size.width >= 600;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            // 顶部：返回
            if (!isLandscape) ...[
              GestureDetector(
                onTap: () => _navigateBack(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '返回',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 评分区 - 总分 + 维度
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 总分环形图 + 等级
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CustomPaint(
                            painter: _ScoreRingPainter(
                              score: _overallScore ?? 0,
                              color: _scoreColor(_overallScore ?? 0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getScoreLevel(_overallScore),
                                style: TextStyle(
                                  color: _scoreColor(_overallScore ?? 0),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '总分 ${_overallScore?.toStringAsFixed(1) ?? '--'}',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 维度评分条
                    _buildDimensionBar('准确度', _accuracyScore, Icons.gps_fixed),
                    const SizedBox(height: 8),
                    _buildDimensionBar('流利度', _fluencyScore, Icons.speed),
                    const SizedBox(height: 8),
                    _buildDimensionBar('完整度', _completenessScore, Icons.check_circle),
                    const SizedBox(height: 8),
                    _buildDimensionBar('发音', _lastEvaluationResult?.pronunciation, Icons.record_voice_over),
                    const SizedBox(height: 16),
                    // 单词级详情
                    if (_recognizedWords.isNotEmpty) ...[
                      Text(
                        '单词详情',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildWordDetailsList(),
                      const SizedBox(height: 16),
                    ],
                    // 薄弱维度提示
                    if (_lastEvaluationResult != null) ...[
                      _buildWeakDimensionsTip(),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            // AI 分析（手动触发）
            if (_aiAnalysisResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI 发音分析',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiAnalysisResult!.analysis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    if (_aiAnalysisResult!.suggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '改进建议：',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._aiAnalysisResult!.suggestions.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• $s',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      )),
                    ],
                    if (_aiAnalysisResult!.focusAreas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '重点练习：',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._aiAnalysisResult!.focusAreas.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• ${a.area} (${_priorityLabel(a.priority)})',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else if (_isAiAnalyzing) ...[
              // AI 分析加载中
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'AI 分析中...',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              // 手动触发 AI 分析按钮
              GestureDetector(
                onTap: () => _triggerAiAnalysis(cfg),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI 发音分析',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 底部操作栏
            Row(
              children: [
                if (isLandscape)
                  GestureDetector(
                    onTap: () => _navigateBack(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back_ios_rounded,
                          size: 14,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '返回',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                _evalBtn(
                  '重新录音',
                  Icons.refresh_rounded,
                  () => _restartFromEvaluation(context, cfg),
                ),
                const SizedBox(width: 8),
                _evalBtn('下一句', Icons.skip_next_rounded, () {
                  _navigateBack();
                  cfg.nextSentence?.call();
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建维度评分条
  Widget _buildDimensionBar(String label, double? score, IconData icon) {
    final s = score ?? 0;
    final color = EvaluationDisplayHelper.getScoreColor(s);
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 6),
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: s > 0 ? s / 100 : 0,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          s > 0 ? s.toStringAsFixed(1) : '--',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 构建单词详情列表
  Widget _buildWordDetailsList() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _recognizedWords.map((word) {
        final bool hasError = !word.correct || word.hasPhonemeErrors;
        final Color bgColor = hasError 
            ? const Color(0x33F44336) 
            : const Color(0x334CAF50);
        final Color textColor = hasError 
            ? const Color(0xFFF44336) 
            : const Color(0xFF4CAF50);
        
        return GestureDetector(
          onTap: () => _showWordDetailDialog(word),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: textColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  word.word,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (word.readType != null && word.readType != 'normal') ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: word.readTypeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      word.readTypeLabel,
                      style: TextStyle(
                        color: word.readTypeColor,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
                if (word.score > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    word.score.toStringAsFixed(0),
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 显示单词详情弹窗
  void _showWordDetailDialog(RecognizedWord word) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          word.word,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '得分: ${word.score.toStringAsFixed(1)}',
              style: TextStyle(color: Colors.white70),
            ),
            if (word.readType != null) ...[
              const SizedBox(height: 4),
              Text(
                '朗读类型: ${word.readTypeLabel}',
                style: TextStyle(color: word.readTypeColor),
              ),
            ],
            if (word.wordStress != null) ...[
              const SizedBox(height: 4),
              Text(
                '重音: ${word.wordStress! ? '正确' : '错误'}',
                style: TextStyle(
                  color: word.wordStress! ? Colors.green : Colors.red,
                ),
              ),
            ],
            if (word.phonemes != null && word.phonemes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '音素详情:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: word.phonemes!.map((phoneme) {
                  final bool isError = (phoneme.score ?? 100) < 70;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isError 
                          ? const Color(0x33F44336) 
                          : const Color(0x334CAF50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${phoneme.phoneme} ${phoneme.score?.toStringAsFixed(0) ?? ''}',
                      style: TextStyle(
                        color: isError ? Colors.red : Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  /// 构建薄弱维度提示
  Widget _buildWeakDimensionsTip() {
    final weakDims = _lastEvaluationResult!.weakDimensions.take(2);
    if (weakDims.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x33FF9800),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33FF9800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, size: 14, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                '提升建议',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...weakDims.map((dim) {
            final description = EvaluationDisplayHelper.getDimensionDescription(dim.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${dim.key}: ${dim.value?.toStringAsFixed(1)}分 - $description',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _evalBtn(String label, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━ 导航 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _navigateToEvaluation() {
    if (_state != 'scored') return;
    setState(() => _currentPage = 'evaluation');
  }

  void _navigateBack() {
    setState(() => _currentPage = 'recording');
  }

  Future<void> _restartFromEvaluation(
    BuildContext context,
    ShadowReaderConfig cfg,
  ) async {
    _navigateBack();
    await _restartRecording(context, cfg);
  }

  // ━━━ 音频操作 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _toggleMute(ShadowReaderConfig cfg) {
    final state = ref.read(playerEngineProvider);
    if (_isMuted) {
      cfg.setOriginalVolume?.call(_savedVolume);
      setState(() => _isMuted = false);
    } else {
      _savedVolume = state.originalVolume;
      cfg.setOriginalVolume?.call(0.0);
      setState(() => _isMuted = true);
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;
    try {
      await _audioPlayer.setSource(ap.DeviceFileSource(_recordingPath!));
      await _audioPlayer.resume();
    } catch (_) {}
  }

  Future<void> _compareAudio(ShadowReaderConfig cfg) async {
    if (_isComparing) return;
    _isComparing = true;
    try {
      await _replayOriginal(cfg);
      await Future.delayed(const Duration(seconds: 2));
      await _playRecording();
    } finally {
      _isComparing = false;
    }
  }

  String _formatRecordingTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _scoreColor(double score) {
    if (score >= 90) return AppColors.success;
    if (score >= 75) return AppColors.warning;
    if (score >= 60) return const Color(0xFFFF6B3A);
    return AppColors.error;
  }

  // ━━━ 录音逻辑 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> _startRecording(
    BuildContext context,
    ShadowReaderConfig cfg,
  ) async {
    if (_isEvaluating) return;
    
    // 如果正在播放录音，先停止
    try {
      if (_audioPlayer.state == ap.PlayerState.playing) {
        await _audioPlayer.stop();
      }
    } catch (_) {}
    
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('需要麦克风权限才能跟读')));
      }
      return;
    }
    setState(() {
      _state = 'listening';
      _recognizedWords.clear();
      _recordingSeconds = 0;
    });
    cfg.setRecording?.call(true);
    _recordingStartTime = DateTime.now();
    
    debugPrint('🎤 [ShadowReader] ========== 开始录音 ==========');
    debugPrint('🎤 [ShadowReader] 录音状态: 已开始');
    debugPrint('🎤 [ShadowReader] 参考文本: ${cfg.subtitle.content}');
    debugPrint('🎤 [ShadowReader] 订阅模式: ${cfg.subscriptionMode}');
    
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _recordingSeconds++);
    });
    try {
      final tmpDir = Directory.systemTemp;
      _recordingPath =
          '${tmpDir.path}/shadow_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      debugPrint('🎤 [ShadowReader] 录音文件路径: $_recordingPath');
      
      await _recorder.start(const RecordConfig(), path: _recordingPath!);
      
      debugPrint('🎤 [ShadowReader] 录音器启动成功');
      
      final defaultVol = cfg.isMusic ? 0.8 : 0.6;
      await cfg.setOriginalVolume?.call(defaultVol);
      if (cfg.getSingleSentencePause != true) {
        await cfg.setSingleSentencePause?.call(true);
      }
      if (cfg.getPosition != null && cfg.togglePlayPause != null) {
        final pos = cfg.getPosition!();
        if (pos.inMilliseconds > 0) await cfg.togglePlayPause!();
      }
      // 不再设置自动停止计时器，录音时间不受限制
      // 用户需要手动点击停止按钮结束录音
      _startLiveRecognition(cfg);
    } catch (e) {
      debugPrint('❌ [ShadowReader] 录音启动失败: $e');
      _handleRecordingError('录音启动失败: $e', cfg);
    }
  }

  Future<void> _stopRecording(
    BuildContext context,
    ShadowReaderConfig cfg,
  ) async {
    debugPrint('🎤 [ShadowReader] ========== 停止录音 ==========');
    
    _autoStopTimer?.cancel();
    _recognitionTimer?.cancel();
    if (_recordingPath == null) {
      debugPrint('⚠️ [ShadowReader] 录音路径为空，无法停止');
      return;
    }
    try {
      await _recorder.stop();
      debugPrint('🎤 [ShadowReader] 录音器已停止');
    } catch (e) {
      debugPrint('❌ [ShadowReader] 停止录音器失败: $e');
    }
    // 停止系统 speech_to_text 识别
    try {
      SpeechToTextService().stop();
      debugPrint('🎤 [ShadowReader] 语音识别已停止');
    } catch (e) {
      debugPrint('❌ [ShadowReader] 停止语音识别失败: $e');
    }
    cfg.setRecording?.call(false);
    // 恢复用户原来的音量，而不是强制 100%
    await cfg.setOriginalVolume?.call(_savedVolume);
    final path = _recordingPath;
    _recordingPath = null;
    if (path == null || !File(path).existsSync()) {
      debugPrint('⚠️ [ShadowReader] 录音文件不存在，跳过评测');
      return;
    }
    _recordingPath = path; // keep path for replay

    final isPremium = cfg.subscriptionMode == SubscriptionMode.premium;
    debugPrint('🎤 [ShadowReader] 订阅模式: ${cfg.subscriptionMode}');
    debugPrint('🎤 [ShadowReader] 是否付费模式: $isPremium');
    
    if (isPremium) {
      debugPrint('🎤 [ShadowReader] 进入付费模式评测流程');
      setState(() => _state = 'evaluating');
      _evaluateRecording(path, cfg);
    } else {
      debugPrint('🎤 [ShadowReader] 进入免费模式评测流程');
      // 免费模式：直接使用识别结果评分
      setState(() => _state = 'evaluating');
      _evaluateFreeModeRecording(path, cfg);
    }
  }

  Future<void> _restartRecording(
    BuildContext context,
    ShadowReaderConfig cfg,
  ) async {
    _recordingTimer?.cancel();
    setState(() {
      _state = 'idle';
      _overallScore = null;
      _fluencyScore = null;
      _accuracyScore = null;
      _completenessScore = null;
      _recognizedWords.clear();
      _recordingSeconds = 0;
      _currentPage = 'recording';
    });
    await _startRecording(context, cfg);
  }

  /// 切换字幕时重置录音状态，避免显示上次的匹配结果
  void _resetRecordingState() {
    _recordingTimer?.cancel();
    _autoStopTimer?.cancel();
    _recognitionTimer?.cancel();
    _recorder.stop();
    setState(() {
      _state = 'idle';
      _overallScore = null;
      _fluencyScore = null;
      _accuracyScore = null;
      _completenessScore = null;
      _recognizedWords.clear();
      _recordingSeconds = 0;
      _recordingPath = null;
      _liveTranscription = '';
      _currentPage = 'recording';
    });
  }

  void _handleRecordingError(String message, ShadowReaderConfig cfg) {
    cfg.setRecording?.call(false);
    cfg.setOriginalVolume?.call(1.0);
    setState(() => _state = 'idle');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _startLiveRecognition(ShadowReaderConfig cfg) {
    final isPremium = cfg.subscriptionMode == SubscriptionMode.premium;
    if (isPremium) {
      // 付费模式：使用声通流式评测（由 _evaluateRecording 处理）
      // 这里不做任何操作，因为付费模式不需要实时识别
      return;
    }

    // 免费模式：使用系统 speech_to_text 进行实时识别
    _initLiveSpeechToText(cfg);
  }

  /// 初始化系统 speech_to_text 进行实时识别
  Future<void> _initLiveSpeechToText(ShadowReaderConfig cfg) async {
    try {
      final speechService = SpeechToTextService();
      final available = await speechService.init();
      if (!available) {
        debugPrint('系统 speech_to_text 不可用');
        return;
      }

      // 监听识别结果
      speechService.textStream.listen((text) {
        if (mounted) {
          setState(() => _liveTranscription = text);
        }
      });

      // 开始识别
      await speechService.start(
        localeId: cfg.language == 'en' ? 'en-US' : cfg.language,
      );
    } catch (e) {
      debugPrint('启动实时语音识别失败: $e');
    }
  }

  Future<void> _evaluateRecording(
    String audioPath,
    ShadowReaderConfig cfg,
  ) async {
    if (_isEvaluating) return;
    _isEvaluating = true;
    
    debugPrint('🎤 [ShadowReader] ========== 开始声通评测 ==========');
    debugPrint('🎤 [ShadowReader] 音频路径: $audioPath');
    debugPrint('🎤 [ShadowReader] 参考文本: ${cfg.subtitle.content}');
    
    try {
      // 使用 ShengtongHttpEvaluator HTTP 方式评测
      // 密钥从 AppKeysService 动态加载
      final stAppKey = AppKeysService.instance.shengtongAppKey;
      final stSecretKey = AppKeysService.instance.shengtongSecretKey;

      debugPrint('🎤 [ShadowReader] AppKey: ${stAppKey != null && stAppKey.isNotEmpty ? "已配置(${stAppKey.substring(0, math.min(4, stAppKey.length))}...)" : "未配置"}');
      debugPrint('🎤 [ShadowReader] SecretKey: ${stSecretKey != null && stSecretKey.isNotEmpty ? "已配置(${stSecretKey.substring(0, math.min(4, stSecretKey.length))}...)" : "未配置"}');

      if (stAppKey == null ||
          stAppKey.isEmpty ||
          stSecretKey == null ||
          stSecretKey.isEmpty) {
        debugPrint('⚠️ [ShadowReader] 声通密钥未就绪，跳过评测');
        _isEvaluating = false;
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('声通服务未配置')));
        }
        return;
      }

      // 检查音频文件
      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        debugPrint('❌ [ShadowReader] 音频文件不存在: $audioPath');
        _isEvaluating = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('录音文件不存在，请重新录音')));
        }
        return;
      }
      
      final audioSize = await audioFile.length();
      debugPrint('🎤 [ShadowReader] 音频文件大小: $audioSize bytes');
      if (audioSize < 1000) {
        debugPrint('⚠️ [ShadowReader] 音频文件太小，可能录音失败');
      }

      final evaluator = ShengtongHttpEvaluator(
        appKey: stAppKey,
        secretKey: stSecretKey,
      );

      final coreType = 'sent.eval';
      debugPrint('🎤 [ShadowReader] 评测类型: $coreType');
      debugPrint('🎤 [ShadowReader] 开始调用声通 API...');
      
      final result = await evaluator.evaluate(
        coreType: coreType,
        refText: cfg.subtitle.content,
        audioPath: audioPath,
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
      );

      // 使用结构化解析器解析声通评测结果
      final evaluationResult = ShengtongEvaluationResult.fromJson(result);
      
      debugPrint('🎤 [ShadowReader] ========== 声通评测结构化结果 ==========');
      debugPrint('🎤 [ShadowReader] 总分: ${evaluationResult.overall}');
      debugPrint('🎤 [ShadowReader] 流利度: ${evaluationResult.fluency}');
      debugPrint('🎤 [ShadowReader] 完整度: ${evaluationResult.integrity}');
      debugPrint('🎤 [ShadowReader] 准确度: ${evaluationResult.accuracy}');
      debugPrint('🎤 [ShadowReader] 发音: ${evaluationResult.pronunciation}');
      debugPrint('🎤 [ShadowReader] 单词数: ${evaluationResult.words.length}');
      debugPrint('🎤 [ShadowReader] 错误单词: ${evaluationResult.getErrorWords().map((w) => '${w.word}(${w.score})').join(', ')}');
      debugPrint('🎤 [ShadowReader] 漏读单词: ${evaluationResult.getMissingWords().map((w) => w.word).join(', ')}');
      debugPrint('🎤 [ShadowReader] 音素错误: ${evaluationResult.getPhonemeErrors().map((e) => '${e.word}[${e.phoneme}]').join(', ')}');
      debugPrint('🎤 [ShadowReader] 薄弱维度: ${evaluationResult.weakDimensions.take(2).map((d) => '${d.key}(${d.value})').join(', ')}');
      debugPrint('🎤 [ShadowReader] ===========================================');

      final overall = evaluationResult.overall;
      final fluency = evaluationResult.fluency;
      final accuracy = evaluationResult.accuracy;
      final completeness = evaluationResult.integrity;
      
      // 保存评测结果 JSON 到文件（供分析使用）
      await _saveEvaluationResult(result, cfg);
      final recordingDurationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;
      final record = RecordingRecord(
        resourceCode: cfg.resourceCode,
        resourceType: cfg.resourceType,
        scope: cfg.scope,
        chapterCode: cfg.chapterCode,
        sentenceCode: cfg.subtitle.code,
        audioPath: audioPath,
        durationMs: recordingDurationMs,
        overallScore: overall,
        fluencyScore: fluency,
        accuracyScore: accuracy,
        completenessScore: completeness,
        rawResultJson: jsonEncode(result),
        language: cfg.language,
        refText: cfg.subtitle.content,
        subtitleIndex: cfg.currentSubtitleIndex,
        speed: cfg.currentSpeed ?? 1.0,
        headphoneMode: await cfg.getHeadphoneMode?.call(),
      );
      await DatabaseService.insert(record);
      
      // 保存到云端（按类型存储 50 条）
      if (_lastEvaluationResult != null) {
        unawaited(_saveEvaluationToCloud(cfg, _lastEvaluationResult!, recordingDurationMs));
      }
      
      // 通过 LearningStatsService 统一记录跟读评分
      if (overall != null) {
        unawaited(
          LearningStatsService.instance.recordFollowScore(
            resourceCode: cfg.resourceCode,
            score: overall,
            sentenceCode: cfg.subtitle.code ?? '',
            resourceType: cfg.resourceType,
          ),
        );
      }
      // 保留原有的 setLastFollowScore 回调
      if (overall != null && cfg.setLastFollowScore != null) {
        await cfg.setLastFollowScore!(overall);
      }
      _setRecognitionResult(cfg, result);
      if (mounted) {
        setState(() {
          _state = 'scored';
          _overallScore = overall;
          _fluencyScore = fluency;
          _accuracyScore = accuracy;
          _completenessScore = completeness;
          // 重置 AI 分析结果（手动触发）
          _aiAnalysisResult = null;
          _isAiAnalyzing = false;
        });
        await cfg.onScore?.call(
          overall: overall,
          fluency: fluency,
          accuracy: accuracy,
          completeness: completeness,
          rawResult: result,
        );
      }
      // 不再自动触发 AI 分析，改为用户手动点击
    } catch (e, stack) {
      debugPrint('❌ [ShadowReader] 声通评测失败: $e');
      debugPrint('❌ [ShadowReader] 错误堆栈: $stack');
      if (mounted) {
        setState(() => _state = 'idle');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('评分失败: $e')));
      }
    } finally {
      debugPrint('🎤 [ShadowReader] 声通评测流程结束，重置 _isEvaluating = false');
      _isEvaluating = false;
    }
  }

  /// 免费模式评分：使用系统 speech_to_text 实时识别
  Future<void> _evaluateFreeModeRecording(
    String audioPath,
    ShadowReaderConfig cfg,
  ) async {
    if (_isEvaluating) return;
    _isEvaluating = true;
    try {
      String recognizedText = _liveTranscription;

      if (recognizedText.isEmpty) {
        if (mounted) {
          setState(() => _state = 'idle');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('语音识别不可用，请确保已授予麦克风权限并在录音时允许识别')),
          );
        }
        return;
      }

      _liveTranscription = recognizedText;

      final refText = cfg.subtitle.content.trim().toLowerCase();
      final cleanRecognized = recognizedText
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ');
      final cleanRef = refText
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ');

      final refWords = cleanRef.split(' ').where((w) => w.isNotEmpty).toList();
      final recognizedWords = cleanRecognized
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();

      int matchedCount = 0;
      final wordScores = <Map<String, dynamic>>[];

      for (final refWord in refWords) {
        bool found = false;
        for (final recWord in recognizedWords) {
          if (recWord == refWord || _isSimilar(refWord, recWord)) {
            matchedCount++;
            found = true;
            break;
          }
        }
        wordScores.add({'word': refWord, 'score': found ? 90 : 20});
      }

      final accuracy = refWords.isNotEmpty
          ? (matchedCount / refWords.length * 100).toDouble()
          : 0.0;
      final double overall = accuracy;
      final double fluency = accuracy > 70 ? 85 : 60;
      final double completeness = accuracy > 80 ? 90 : 50;

      final recordingDurationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;
      final record = RecordingRecord(
        resourceCode: cfg.resourceCode,
        resourceType: cfg.resourceType,
        scope: cfg.scope,
        chapterCode: cfg.chapterCode,
        sentenceCode: cfg.subtitle.code,
        audioPath: audioPath,
        durationMs: recordingDurationMs,
        overallScore: overall,
        fluencyScore: fluency,
        accuracyScore: accuracy,
        completenessScore: completeness,
        rawResultJson: jsonEncode({
          'recognized_text': _liveTranscription,
          'ref_text': cfg.subtitle.content,
          'matched_words': matchedCount,
          'total_words': refWords.length,
        }),
        language: cfg.language,
        refText: cfg.subtitle.content,
        subtitleIndex: cfg.currentSubtitleIndex,
        speed: cfg.currentSpeed ?? 1.0,
        headphoneMode: await cfg.getHeadphoneMode?.call(),
      );
      await DatabaseService.insert(record);
      // 通过 LearningStatsService 统一记录跟读评分
      unawaited(
        LearningStatsService.instance.recordFollowScore(
          resourceCode: cfg.resourceCode,
          score: overall,
          sentenceCode: cfg.subtitle.code ?? '',
          resourceType: cfg.resourceType,
        ),
      );
      if (cfg.setLastFollowScore != null) {
        await cfg.setLastFollowScore!(overall);
      }

      _setFreeModeRecognitionResult(wordScores);
      if (mounted) {
        setState(() {
          _state = 'scored';
          _overallScore = overall;
          _fluencyScore = fluency;
          _accuracyScore = accuracy;
          _completenessScore = completeness;
        });
        await cfg.onScore?.call(
          overall: overall,
          fluency: fluency,
          accuracy: accuracy,
          completeness: completeness,
          rawResult: {
            'recognized_text': _liveTranscription,
            'ref_text': cfg.subtitle.content,
            'matched_words': matchedCount,
            'total_words': refWords.length,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _state = 'idle');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('评分失败: $e')));
      }
    } finally {
      _isEvaluating = false;
    }
  }

  bool _isSimilar(String word1, String word2) {
    // 简单的相似度判断：编辑距离
    if (word1.length != word2.length) {
      if ((word1.length - word2.length).abs() > 1) return false;
    }
    if (word1 == word2) return true;
    for (int i = 0; i < word1.length; i++) {
      if (word1[i] != word2[i]) {
        if (word1.length == word2.length) {
          return word1.substring(0, i) + word1.substring(i + 1) == word2;
        } else if (word1.length > word2.length) {
          return word1.substring(0, i) + word1.substring(i + 1) == word2;
        } else {
          return word2.substring(0, i) + word2.substring(i + 1) == word1;
        }
      }
    }
    return true;
  }

  /// 手动触发 AI 发音分析
  Future<void> _triggerAiAnalysis(ShadowReaderConfig cfg) async {
    if (_lastEvaluationResult == null || _isAiAnalyzing) return;
    
    setState(() => _isAiAnalyzing = true);
    
    try {
      debugPrint('🎤 [ShadowReader] 🤖 用户触发 AI 发音分析...');
      
      final result = await AiEvaluationService.analyzePronunciation(
        evaluationResult: _lastEvaluationResult!,
        resourceTitle: cfg.resourceTitle,
        refText: cfg.subtitle.content,
        language: cfg.language,
      );
      
      if (result != null && mounted) {
        setState(() => _aiAnalysisResult = result);
        debugPrint('🎤 [ShadowReader] 🤖 AI 分析完成');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 分析失败，请稍后重试')),
        );
      }
    } catch (e) {
      debugPrint('❌ [ShadowReader] AI 分析触发失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 分析失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAiAnalyzing = false);
    }
  }
  
  /// 优先级标签转换
  String _priorityLabel(String priority) {
    switch (priority) {
      case 'high':
        return '高优先级';
      case 'medium':
        return '中优先级';
      case 'low':
        return '低优先级';
      default:
        return priority;
    }
  }

  void _setRecognitionResult(
    ShadowReaderConfig cfg,
    Map<String, dynamic> result,
  ) {
    // 使用结构化解析器解析声通评测结果
    final evaluationResult = ShengtongEvaluationResult.fromJson(result);
    
    // 构建 RecognizedWord 列表，包含详细评分信息
    _recognizedWords = evaluationResult.words.map((wordEval) {
      // 根据朗读类型和得分判断是否正确
      final bool isCorrect;
      if (wordEval.readType == 'miss') {
        isCorrect = false; // 漏读
      } else if (wordEval.readType == 'insert') {
        isCorrect = false; // 多读
      } else {
        isCorrect = (wordEval.score ?? 0) >= 70;
      }
      
      return RecognizedWord(
        word: wordEval.word,
        correct: isCorrect,
        score: wordEval.score ?? 0,
        readType: wordEval.readType,
        phonemes: wordEval.phonemes,
        wordStress: wordEval.wordStress,
      );
    }).toList();
    
    // 保存结构化结果供后续使用
    _lastEvaluationResult = evaluationResult;
  }

  void _setFreeModeRecognitionResult(List<Map<String, dynamic>> wordScores) {
    _recognizedWords = wordScores.map((ws) {
      final word = ws['word'] as String? ?? '';
      final score = (ws['score'] as num?)?.toInt() ?? 0;
      return RecognizedWord(
        word: word,
        correct: score >= 70,
        score: score.toDouble(),
      );
    }).toList();
  }

  /// 根据分数获取等级
  String _getScoreLevel(double? score) {
    if (score == null) return '未知';
    if (score >= 90) return '优秀';
    if (score >= 80) return '良好';
    if (score >= 70) return '及格';
    if (score >= 60) return '待改进';
    return '需加强';
  }

  Future<void> _replayOriginal(ShadowReaderConfig cfg) async {
    // 先停止之前的 TTS 高亮
    _stopTtsHighlight();
    
    if (cfg.resourceType == 'article') {
      if (cfg.speakSubtitle != null) {
        // 解析单词列表用于高亮
        final text = cfg.subtitle.content;
        final wordRegex = RegExp(r'\b\w+\b');
        _ttsWords = wordRegex.allMatches(text).map((m) => m.group(0)!).toList();
        _ttsCurrentWordIndex = _ttsWords.isNotEmpty ? 0 : -1;
        
        // 启动单词高亮定时器
        _startTtsHighlightTimer(text);
        
        await cfg.speakSubtitle!(text);
      }
    } else {
      if (cfg.togglePlayPause != null) {
        await cfg.togglePlayPause!();
      }
    }
  }
  
    /// 启动 TTS 单词高亮定时器
    void _startTtsHighlightTimer(String text) {
      _ttsTimer?.cancel();
      
      if (_ttsWords.isEmpty) return;
      
      // 估算每个单词的持续时间（基于平均语速）
      // 假设平均语速为 150 词/分钟 = 2.5 词/秒 = 400ms/词
      const int avgWordDurationMs = 400;
      
      widget.config.onTtsPlayingStateChanged?.call(true);
      
      _ttsTimer = Timer.periodic(Duration(milliseconds: avgWordDurationMs), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_ttsCurrentWordIndex >= _ttsWords.length - 1) {
          timer.cancel();
          _ttsTimer = null;
          widget.config.onTtsPlayingStateChanged?.call(false);
          return;
        }
        setState(() => _ttsCurrentWordIndex++);
        widget.config.onTtsWordIndexChanged?.call(_ttsCurrentWordIndex);
      });
    }
   
   /// 停止 TTS 高亮
   void _stopTtsHighlight() {
     _ttsTimer?.cancel();
     _ttsTimer = null;
     _ttsCurrentWordIndex = -1;
     _ttsWords = [];
   }
}

// ━━━ 辅助类 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _ScoreRingPainter extends CustomPainter {
  final double score;
  final Color color;
  _ScoreRingPainter({required this.score, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 4, bgPaint);
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi / 2,
      (score / 100) * 2 * math.pi,
      false,
      progressPaint,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: score.round().toString(),
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}

class RecognizedWord {
  final String word;
  final bool correct;
  final double score;
  final String? readType; // 朗读类型: normal/miss/repeat/insert
  final List<PhonemeEvaluation>? phonemes; // 音素级评分
  final bool? wordStress; // 重音是否正确

  const RecognizedWord({
    required this.word,
    required this.correct,
    required this.score,
    this.readType,
    this.phonemes,
    this.wordStress,
  });

  /// 获取该单词的音素错误列表
  List<PhonemeEvaluation> get phonemeErrors {
    if (phonemes == null) return [];
    return phonemes!.where((p) => (p.score ?? 100) < 70).toList();
  }

  /// 是否有音素错误
  bool get hasPhonemeErrors => phonemeErrors.isNotEmpty;

  /// 获取朗读类型中文描述
  String get readTypeLabel {
    switch (readType) {
      case 'normal':
        return '正常';
      case 'miss':
        return '漏读';
      case 'repeat':
        return '重复';
      case 'insert':
        return '多读';
      default:
        return readType ?? '未知';
    }
  }

  /// 获取朗读类型颜色
  Color get readTypeColor {
    switch (readType) {
      case 'normal':
        return const Color(0xFF4CAF50);
      case 'miss':
        return const Color(0xFFF44336);
      case 'repeat':
        return const Color(0xFFFF9800);
      case 'insert':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
  }
}

class LyricDisplayWidget {
  LyricDisplayWidget._();
  static List<PronunciationEntry>? parsePronunciationMap(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final list = jsonDecode(json) as List;
      return list
          .map(
            (e) => PronunciationEntry(
              word: e['word'] as String? ?? '',
              zh: e['zh'] as String? ?? '',
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }
}

class PronunciationEntry {
  final String word;
  final String zh;
  const PronunciationEntry({required this.word, required this.zh});
}

// ━━━ 声波图动画组件 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AudioWaveformAnimator extends StatefulWidget {
  final bool isRecording;
  final Color color;

  const _AudioWaveformAnimator({
    required this.isRecording,
    required this.color,
  });

  @override
  State<_AudioWaveformAnimator> createState() => _AudioWaveformAnimatorState();
}

class _AudioWaveformAnimatorState extends State<_AudioWaveformAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _barHeights = [];
  final int _barCount = 30;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _controller.addListener(_updateBars);
    if (widget.isRecording) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_AudioWaveformAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isRecording && _controller.isAnimating) {
      _controller.stop();
    }
  }

  void _updateBars() {
    if (!mounted) return;
    setState(() {
      _barHeights.clear();
      for (int i = 0; i < _barCount; i++) {
        // 生成模拟的音频波形高度（0.1 到 1.0）
        double height = 0.1 + _random.nextDouble() * 0.9;
        // 中间高两边低的 bell curve 效果
        double center = _barCount / 2;
        double distance = (i - center).abs() / center;
        height = height * (1 - distance * 0.5);
        _barHeights.add(height.clamp(0.1, 1.0));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barCount, (index) {
          double height = 0.1;
          if (index < _barHeights.length) {
            height = _barHeights[index];
          }
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 3,
            height: 8 + height * 44, // 最小 8，最大 52
            decoration: BoxDecoration(
              color: widget.color.withValues(
                alpha: 0.3 + height * 0.7,
              ),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}
