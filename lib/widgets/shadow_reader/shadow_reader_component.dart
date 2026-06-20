/// 通用跟读组件 — ShadowReader（双页设计）
///
/// 页面1：跟读页 — 字幕 + 识别着色 + 音量 + 两端对齐控制栏
/// 页面2：评价页 — 总分 + 维度 + AI评价 + 操作按钮

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/ai_evaluation_log.dart';
import 'package:vidlang/models/recording_record.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/providers/player_engine_provider.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/audio_recognition_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/shengtong_evaluator.dart';
import 'package:vidlang/services/score_service.dart';
import 'package:vidlang/services/tts_service.dart';
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
  final ScoreCallback? onScore;
  final AiEvaluationCallback? onAiEvaluation;
  final Future<bool?> Function()? getHeadphoneMode;
  final String? audioType;
  final Duration? currentPosition;
  final int? currentSubtitleIndex;
  final Future<void> Function(int)? seekToSubtitle;
  final Future<void> Function()? nextSentence;
  final Future<void> Function()? previousSentence;

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
    this.onScore,
    this.onAiEvaluation,
    this.getHeadphoneMode,
    this.audioType,
    this.currentPosition,
    this.currentSubtitleIndex,
    this.seekToSubtitle,
    this.nextSentence,
    this.previousSentence,
  });
}

// ─── 组件 ─────────────────────────────────────────────
class ShadowReaderComponent extends ConsumerStatefulWidget {
  final ShadowReaderConfig config;
  final bool _isInline;
  final VoidCallback? _onClose;

  const ShadowReaderComponent({super.key, required this.config}) : _isInline = false, _onClose = null;
  const ShadowReaderComponent._inline({super.key, required this.config, VoidCallback? onClose})
      : _isInline = true, _onClose = onClose;

  static void show(BuildContext context, {required ShadowReaderConfig config}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, barrierColor: Colors.black26,
      builder: (_) => ShadowReaderComponent(config: config),
    );
  }

  static Widget inline({
    required ShadowReaderConfig config,
    double heightFactor = 0.55,
    VoidCallback? onClose,
  }) {
    return Builder(builder: (context) {
      final size = MediaQuery.of(context).size;
      final isLandscape = size.width > size.height && size.width >= 600;
      final factor = isLandscape ? 0.70 : heightFactor;
      return SafeArea(child: SizedBox(
        height: size.height * factor,
        child: ShadowReaderComponent._inline(config: config, onClose: onClose),
      ));
    });
  }

  @override
  ConsumerState<ShadowReaderComponent> createState() => _ShadowReaderComponentState();
}

// ─── State ────────────────────────────────────────────
class _ShadowReaderComponentState extends ConsumerState<ShadowReaderComponent>
    with SingleTickerProviderStateMixin {
  late final AudioRecorder _recorder = AudioRecorder();
  ShengtongEvaluator? _evaluator;
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

  double? _overallScore;
  double? _fluencyScore;
  double? _accuracyScore;
  double? _completenessScore;
  Map<String, dynamic>? _rawResult;
  String _aiSummary = '';
  String _aiSuggestions = '';
  List<RecognizedWord> _recognizedWords = [];

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
      initialChildSize: 0.55, minChildSize: 0.4, maxChildSize: 0.85, expand: false,
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
      child: Column(children: [
        // ── 拖拽手柄 / 关闭按钮（内联模式）──
        if (widget._isInline) ...[
          Center(child: Container(
            margin: const EdgeInsets.only(top: 6),
            width: 32, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          )),
          SizedBox(height: 4),
        ],
        // ── 字幕区 ──
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Row 1: 亮色字幕（全宽，与 Row 2 对齐）
            SelectableEnglishLine(
              text: cfg.subtitle.content, fontSize: 16, fontColor: Colors.white,
              selectedBgColor: AppColors.primary.withValues(alpha: 0.3),
              onSelectionChanged: (words) {
                if (cfg.speakSubtitle != null && words.isNotEmpty) {
                  cfg.speakSubtitle!(words.join(' '));
                }
              },
            ),
            const SizedBox(height: 6),
            // Row 2: 参考字幕 / 识别着色（全宽，与 Row 1 对齐）
            _buildRecognitionRow(cfg),
            // 录音计时器
            if (isListening) ...[
              const SizedBox(height: 6),
              Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_formatRecordingTime(_recordingSeconds),
                  style: TextStyle(color: Colors.red, fontSize: 11, fontFamily: 'monospace')),
              ]),
            ],
          ]),
        )),
        const Divider(height: 1, thickness: 0.5, color: Colors.white12),
        // ── 音量行 ──
        _buildVolumeRow(cfg),
        const Divider(height: 1, thickness: 0.5, color: Colors.white12),
        // ── 底部控制栏 ──
        _buildBottomControlBar(context, cfg),
      ]),
    );
  }

  Widget _buildRecognitionRow(ShadowReaderConfig cfg) {
    final sub = cfg.subtitle;
    final hasWords = _recognizedWords.isNotEmpty;
    final refWords = sub.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final refLookup = <String, RecognizedWord>{};
    for (final rw in _recognizedWords) {
      refLookup[rw.word.toLowerCase()] = rw;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
        children: refWords.map((word) {
          final matched = refLookup[word.toLowerCase()];
          Color color;
          if (!hasWords) {
            color = Colors.white30;
          } else if (matched != null) {
            color = matched.correct ? const Color(0xFF4CAF50) : AppColors.error;
          } else {
            color = AppColors.error;
          }
          return Padding(padding: const EdgeInsets.only(right: 6), child: Text(
            word,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w500),
          ));
        }).toList(),
      )),
    );
  }

  Widget _buildVolumeRow(ShadowReaderConfig cfg) {
    final state = ref.read(playerEngineProvider);
    final vol = (state.originalVolume * 100).round();
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Row(children: [
      GestureDetector(
        onTap: () => _toggleMute(cfg),
        behavior: HitTestBehavior.opaque,
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(
          _isMuted ? Icons.volume_off_rounded : Icons.volume_down_rounded,
          size: 18, color: _isMuted ? Colors.white38 : Colors.white54)),
      ),
      const SizedBox(width: 4),
      Expanded(child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          value: state.originalVolume, min: 0.0, max: 1.0, divisions: 10,
          activeColor: AppColors.primary, inactiveColor: Colors.white24,
          onChanged: (v) { cfg.setOriginalVolume?.call(v); if (v > 0 && _isMuted) setState(() => _isMuted = false); },
        ),
      )),
      const SizedBox(width: 4),
      SizedBox(width: 32, child: Text('$vol%', textAlign: TextAlign.right,
        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500))),
    ]));
  }

  Widget _buildBottomControlBar(BuildContext context, ShadowReaderConfig cfg) {
    final isListening = _state == 'listening';
    final hasRecording = _recordingPath != null && File(_recordingPath!).existsSync();
    final isScored = _state == 'scored';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(children: [
        // ── 关闭按钮（内联模式）──
        if (widget._isInline && widget._onClose != null) ...[
          _circleBtn(Icons.close_rounded, Colors.white54, 32, 18,
            onTap: widget._onClose, bg: Colors.white10),
          const SizedBox(width: 6),
        ],
        // ── 左组：导航 ──
        _circleBtn(Icons.skip_previous_rounded, Colors.white70, 36, 18,
          onTap: cfg.previousSentence != null ? () => cfg.previousSentence!() : null,
          bg: Colors.white10),
        const SizedBox(width: 6),
        _circleBtn(Icons.play_arrow_rounded, Colors.white70, 36, 20,
          onTap: () => _replayOriginal(cfg),
          bg: Colors.white10),
        const SizedBox(width: 6),
        _circleBtn(Icons.skip_next_rounded, Colors.white70, 36, 18,
          onTap: cfg.nextSentence != null ? () => cfg.nextSentence!() : null,
          bg: Colors.white10),
        const Spacer(),
        // ── 右组：操作 ──
        _circleBtn(isListening ? Icons.stop_rounded : Icons.mic_rounded,
          isListening ? Colors.white : AppColors.primary, 40, 20,
          onTap: isListening ? () => _stopRecording(context, cfg) : () => _startRecording(context, cfg),
          bg: isListening ? Colors.red : AppColors.primary.withValues(alpha: 0.2)),
        const SizedBox(width: 6),
        _circleBtn(Icons.replay_rounded, Colors.white54, 36, 18,
          onTap: (!isListening && hasRecording) ? () => _playRecording() : null,
          bg: Colors.white10),
        const SizedBox(width: 6),
        _circleBtn(Icons.compare_arrows_rounded, Colors.white54, 36, 18,
          onTap: (!isListening && hasRecording) ? () => _compareAudio(cfg) : null,
          bg: Colors.white10),
        const SizedBox(width: 6),
        _circleBtn(Icons.auto_awesome_rounded, Colors.white54, 36, 18,
          onTap: (!isListening && isScored) ? () => _navigateToEvaluation() : null,
          bg: Colors.white10),
      ]),
    );
  }

  /// 统一圆形按钮组件
  /// [size] 按钮直径, [iconSize] 图标大小, [bg] 背景色
  Widget _circleBtn(IconData icon, Color iconColor, double size, double iconSize, {
    VoidCallback? onTap, Color? bg,
  }) {
    final enabled = onTap != null;
    final bgColor = !enabled ? Colors.white.withValues(alpha: 0.04) : (bg ?? Colors.white10);
    final icColor = !enabled ? Colors.white24 : iconColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, size: iconSize, color: icColor),
      ),
    );
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
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Column(children: [
        // 顶部：返回（竖屏空间足够时显示）
        if (!isLandscape) ...[
          GestureDetector(onTap: () => _navigateBack(), child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_back_ios_rounded, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Text('返回', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ])),
          const SizedBox(height: 8),
        ],
        // 评分区
        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 48, height: 48, child: CustomPaint(
            painter: _ScoreRingPainter(score: _overallScore ?? 0, color: _scoreColor(_overallScore ?? 0)))),
          const SizedBox(width: 12),
          Expanded(child: isLandscape
            ? Wrap(spacing: 12, runSpacing: 6, children: [
                _dimItem('准确度', _accuracyScore), _dimItem('流利度', _fluencyScore),
                _dimItem('完整度', _completenessScore)])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                _dimItem('准确度', _accuracyScore), const SizedBox(height: 6),
                _dimItem('流利度', _fluencyScore), const SizedBox(height: 6),
                _dimItem('完整度', _completenessScore),
              ]),
          ),
        ])),
        // AI 评价
        if (_aiSummary.isNotEmpty || _aiSuggestions.isNotEmpty) ...[
          Container(width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surfaceHighest, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 6),
                Text('AI 评价', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              if (_aiSummary.isNotEmpty) Text(_aiSummary, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
              if (_aiSuggestions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('建议：$_aiSuggestions', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.primary, fontSize: 11, height: 1.3)),
              ],
            ])),
          const SizedBox(height: 8),
        ],
        // 底部操作栏
        Row(children: [
          if (isLandscape)
            GestureDetector(onTap: () => _navigateBack(), child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text('返回', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
          const Spacer(),
          _evalBtn('重新录音', Icons.refresh_rounded, () => _restartFromEvaluation(context, cfg)),
          const SizedBox(width: 8),
          _evalBtn('下一句', Icons.skip_next_rounded, () {
            _navigateBack();
            cfg.nextSentence?.call();
          }),
        ]),
      ])),
    );
  }

  Widget _dimItem(String label, double? score) {
    final s = score ?? 0;
    return Row(children: [
      SizedBox(width: 40, child: Text(label, style: TextStyle(color: Colors.white54, fontSize: 11))),
      const SizedBox(width: 6),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(
        value: s > 0 ? s / 100 : 0, backgroundColor: Colors.white10,
        valueColor: AlwaysStoppedAnimation(_scoreColor(s)), minHeight: 4))),
      const SizedBox(width: 6),
      SizedBox(width: 28, child: Text(score?.round().toString() ?? '--', textAlign: TextAlign.right,
        style: TextStyle(color: _scoreColor(s), fontSize: 13, fontWeight: FontWeight.bold))),
    ]);
  }

  Widget _evalBtn(String label, IconData icon, VoidCallback? onTap) {
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ));
  }

  // ━━━ 导航 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  void _navigateToEvaluation() {
    if (_state != 'scored') return;
    setState(() => _currentPage = 'evaluation');
  }

  void _navigateBack() {
    setState(() => _currentPage = 'recording');
  }

  Future<void> _restartFromEvaluation(BuildContext context, ShadowReaderConfig cfg) async {
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
  Future<void> _startRecording(BuildContext context, ShadowReaderConfig cfg) async {
    if (_isEvaluating) return;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('需要麦克风权限才能跟读')));
      return;
    }
    setState(() { _state = 'listening'; _recognizedWords.clear(); _recordingSeconds = 0; });
    cfg.setRecording?.call(true);
    _recordingStartTime = DateTime.now();
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) setState(() => _recordingSeconds++);
    });
    try {
      final tmpDir = Directory.systemTemp;
      _recordingPath = '${tmpDir.path}/shadow_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: _recordingPath!);
      final defaultVol = cfg.isMusic ? 0.8 : 0.6;
      await cfg.setOriginalVolume?.call(defaultVol);
      if (cfg.getSingleSentencePause != true) await cfg.setSingleSentencePause?.call(true);
      if (cfg.getPosition != null && cfg.togglePlayPause != null) {
        final pos = cfg.getPosition!();
        if (pos.inMilliseconds > 0) await cfg.togglePlayPause!();
      }
      final endMs = cfg.subtitle.endPosition.toInt();
      final bufferMs = cfg.isMusic ? 1000 : 500;
      final remainingMs = endMs - (cfg.currentPosition?.inMilliseconds ?? 0);
      if (remainingMs > 0) {
        _autoStopTimer = Timer(Duration(milliseconds: remainingMs + bufferMs), () {
          if (mounted && _state == 'listening') _stopRecording(context, cfg);
        });
      }
      _startLiveRecognition(cfg);
    } catch (e) {
      _handleRecordingError('录音启动失败: $e', cfg);
    }
  }

  Future<void> _stopRecording(BuildContext context, ShadowReaderConfig cfg) async {
    _autoStopTimer?.cancel();
    _recognitionTimer?.cancel();
    if (_recordingPath == null) return;
    try { await _recorder.stop(); } catch (_) {}
    cfg.setRecording?.call(false);
    await cfg.setOriginalVolume?.call(1.0);
    final path = _recordingPath;
    _recordingPath = null;
    if (path == null || !File(path).existsSync()) return;
    _recordingPath = path; // keep path for replay
    setState(() => _state = 'evaluating');
    _evaluateRecording(path, cfg);
  }

  Future<void> _restartRecording(BuildContext context, ShadowReaderConfig cfg) async {
    _recordingTimer?.cancel();
    setState(() {
      _state = 'idle'; _overallScore = null; _fluencyScore = null;
      _accuracyScore = null; _completenessScore = null; _rawResult = null;
      _aiSummary = ''; _aiSuggestions = ''; _recognizedWords.clear(); _recordingSeconds = 0;
      _currentPage = 'recording';
    });
    await _startRecording(context, cfg);
  }

  void _handleRecordingError(String message, ShadowReaderConfig cfg) {
    cfg.setRecording?.call(false);
    cfg.setOriginalVolume?.call(1.0);
    setState(() => _state = 'idle');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _startLiveRecognition(ShadowReaderConfig cfg) {
    // TODO: 接入声通流式评测实现实时识别
  }

  // ━━━ 评分逻辑 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> _evaluateRecording(String audioPath, ShadowReaderConfig cfg) async {
    if (_isEvaluating) return;
    _isEvaluating = true;
    try {
      _evaluator?.dispose();
      _evaluator = ShengtongEvaluator(appKey: AppConfig.shengtongAppKey, secretKey: AppConfig.shengtongSecretKey);
      final completer = Completer<Map<String, dynamic>?>();
      _evaluator!.onResult = (r) { if (!completer.isCompleted) completer.complete(r); };
      _evaluator!.onError = (e) { if (!completer.isCompleted) completer.complete(null); };
      final coreType = '${cfg.language}.sent.eval';
      await _evaluator!.connect(coreType);
      _evaluator!.start(coreType: coreType, refText: cfg.subtitle.content, userId: 'user');
      final bytes = await File(audioPath).readAsBytes();
      _evaluator!.feed(bytes);
      _evaluator!.stop();
      final result = await completer.future.timeout(const Duration(seconds: 15));
      if (result == null) {
        if (mounted) { setState(() => _state = 'idle'); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评分服务暂时不可用'))); }
        return;
      }
      final overall = (result['overall'] as num?)?.toDouble();
      final fluency = (result['fluency'] as num?)?.toDouble();
      final accuracy = (result['accuracy'] as num?)?.toDouble();
      final completeness = (result['completeness'] as num?)?.toDouble();
      final recordingDurationMs = _recordingStartTime != null ? DateTime.now().difference(_recordingStartTime!).inMilliseconds : 0;
      final record = RecordingRecord(
        resourceCode: cfg.resourceCode, resourceType: cfg.resourceType, scope: cfg.scope,
        chapterCode: cfg.chapterCode, sentenceCode: cfg.subtitle.code, audioPath: audioPath,
        durationMs: recordingDurationMs, overallScore: overall, fluencyScore: fluency,
        accuracyScore: accuracy, completenessScore: completeness, rawResultJson: jsonEncode(result),
        language: cfg.language, refText: cfg.subtitle.content, subtitleIndex: cfg.currentSubtitleIndex,
        speed: cfg.currentSpeed ?? 1.0, headphoneMode: await cfg.getHeadphoneMode?.call(),
      );
      await DatabaseService.insert(record);
      if (overall != null && cfg.setLastFollowScore != null) await cfg.setLastFollowScore!(overall);
      if (cfg.resourceType == 'music' || cfg.resourceType == 'video') {
        final video = cfg.getCurrentVideo?.call();
        if (video != null && overall != null) { video.lastFollowScore = overall; await DatabaseService.update(video); }
      }
      _setRecognitionResult(cfg, result);
      if (mounted) {
        setState(() { _state = 'scored'; _overallScore = overall; _fluencyScore = fluency; _accuracyScore = accuracy; _completenessScore = completeness; _rawResult = result; });
        await cfg.onScore?.call(overall: overall, fluency: fluency, accuracy: accuracy, completeness: completeness, rawResult: result);
      }
      if (recordingDurationMs > 1000) await _requestAiEvaluation(cfg, overall);
    } catch (e) {
      if (mounted) { setState(() => _state = 'idle'); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('评分失败: $e'))); }
    } finally {
      _isEvaluating = false;
    }
  }

  void _setRecognitionResult(ShadowReaderConfig cfg, Map<String, dynamic> result) {
    final wordScores = result['word_scores'] as List<dynamic>?;
    if (wordScores != null) {
      _recognizedWords = wordScores.map((ws) {
        final word = ws['word'] as String? ?? '';
        final score = (ws['score'] as num?)?.toInt() ?? 0;
        return RecognizedWord(word: word, correct: score >= 70, score: score.toDouble());
      }).toList();
    }
  }

  Future<void> _requestAiEvaluation(ShadowReaderConfig cfg, double? overall) async {
    try {
      final breakdown = await ScoreService.getScoreBreakdown(cfg.resourceCode);
      if (breakdown.allRecords.isEmpty) return;
      final resourceScore = breakdown.resourceScore;
      final level = ScoreService.determineLevel(resourceScore);
      final result = await AiService.callAiProxy(
        ruleCode: 'ai_audio_evaluation', scene: 'shadow_reader', entry: 'ai_commentary',
        word: cfg.resourceTitle, sourceType: cfg.resourceType, sourceCode: cfg.resourceCode,
        params: { 'resource_title': cfg.resourceTitle, 'language': cfg.language,
          'sentence_follow_avg': overall?.round(), 'sentence_follow_count': 1,
          'resource_score': resourceScore?.round(), 'level': level },
      );
      if (!result.success) return;
      final summary = result.translation ?? result.wordMeaningInContext ?? result.mnemonic ?? result.word ?? '';
      final suggestions = result.mnemonic ?? '';
      if (mounted) {
        setState(() { _aiSummary = summary; _aiSuggestions = suggestions; });
        final log = AiEvaluationLog(
          resourceCode: cfg.resourceCode, resourceType: cfg.resourceType, resourceTitle: cfg.resourceTitle,
          language: cfg.language, sentenceFollowAvgScore: overall, sentenceFollowCount: 1,
          resourceScore: resourceScore, evaluationJson: jsonEncode(result.toJson()),
          summary: summary, overallLevel: level,
        );
        await DatabaseService.insert(log);
        await cfg.onAiEvaluation?.call(resourceCode: cfg.resourceCode, resourceTitle: cfg.resourceTitle,
          language: cfg.language, overallScore: overall, summary: summary);
      }
    } catch (_) {}
  }

  Future<void> _replayOriginal(ShadowReaderConfig cfg) async {
    final sub = cfg.subtitle;
    if (cfg.resourceType == 'article') {
      if (cfg.speakSubtitle != null) await cfg.speakSubtitle!(sub.content);
    } else {
      if (cfg.seekTo != null && cfg.togglePlayPause != null) {
        await cfg.seekTo!(Duration(milliseconds: sub.startPosition.toInt()));
        await cfg.togglePlayPause!();
      }
    }
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
    final bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.1)..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawCircle(center, radius - 4, bgPaint);
    final progressPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius - 4), -math.pi / 2, (score / 100) * 2 * math.pi, false, progressPaint);
    final tp = TextPainter(text: TextSpan(text: score.round().toString(), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }
  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) => oldDelegate.score != score || oldDelegate.color != color;
}

class RecognizedWord {
  final String word;
  final bool correct;
  final double score;
  const RecognizedWord({required this.word, required this.correct, required this.score});
}

class LyricDisplayWidget {
  LyricDisplayWidget._();
  static List<PronunciationEntry>? parsePronunciationMap(String? json) {
    if (json == null || json.isEmpty) return null;
    try { final list = jsonDecode(json) as List; return list.map((e) => PronunciationEntry(word: e['word'] as String? ?? '', zh: e['zh'] as String? ?? '')).toList(); } catch (_) { return null; }
  }
}

class PronunciationEntry {
  final String word;
  final String zh;
  const PronunciationEntry({required this.word, required this.zh});
}
