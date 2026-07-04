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
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/learning_stats_service.dart';
import 'package:vidlang/services/ai_evaluation_service.dart';
import 'package:vidlang/services/evaluation_storage_service.dart';
import 'package:vidlang/services/shengtong_evaluator.dart';
import 'package:vidlang/models/shengtong_evaluation_result.dart';
import 'package:vidlang/services/speech_to_text_service.dart';
import 'package:vidlang/theme/theme.dart';

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
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ShadowReaderComponent(config: config),
        ),
      ),
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
  late final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  Timer? _autoStopTimer;
  Timer? _recognitionTimer;
  Timer? _recordingTimer;
  DateTime? _recordingStartTime;
  String? _recordingPath;
  bool _isEvaluating = false;
  String? _evaluationType; // word / sentence / paragraph
  int _recordingSeconds = 0;

  String _state = 'idle'; // idle | listening | evaluating | scored
  String _currentPage = 'recording'; // recording | evaluation
  bool _isMuted = false;
  double _savedVolume = 0.6;

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
  bool _showAiAnalysis = false; // 控制 AI 分析结果的显示/隐藏
  
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
    // 弹窗模式：从底部弹出，固定高度
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: _currentPage == 'evaluation'
          ? _buildEvaluationPage(context, cfg)
          : _buildRecordingPage(context, cfg),
    );
  }

  // ━━━ 跟读页 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 根据设计规范重新实现

  Widget _buildRecordingPage(BuildContext context, ShadowReaderConfig cfg) {
    final isListening = _state == 'listening';
    final isScored = _state == 'scored';
    final isEvaluating = _state == 'evaluating';
    
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // ── 顶部标题栏 ──
          _buildTitleBar(context, cfg),
          Divider(height: 1, thickness: 0.5, color: AppColors.outline),
          
          // ── 主内容区 ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 得分 + 描述区域 ──
                  _buildScoreHeader(isScored, isEvaluating, isListening),
                  const SizedBox(height: 12),
                  
                  // ── 第一块字幕（原文）──
                  _buildSubtitleBlock(
                    text: cfg.subtitle.content,
                    isOriginal: true,
                  ),
                  const SizedBox(height: 8),
                  
                  // ── 第二块字幕（识别结果）──
                  // 录音时显示实时转写（黄色=进行中），结束后显示最终结果（绿/红）
                  if (isScored || _recognizedWords.isNotEmpty)
                    _buildSubtitleBlock(
                      text: _buildRecognizedText(),
                      isOriginal: false,
                      recognizedWords: _recognizedWords,
                    )
                  else if (isListening && _liveTranscription.isNotEmpty)
                    _buildSubtitleBlock(
                      text: _liveTranscription,
                      isOriginal: false,
                      liveTranscribing: true,
                    ),
                  
                  // ── 录音声波图（付费模式单词评测时显示）──
                  if (isListening && cfg.subscriptionMode == SubscriptionMode.premium) ...[
                    const SizedBox(height: 12),
                    _buildAudioWaveform(),
                  ],
                  
                  // ── 录音计时器 ──
                  if (isListening) ...[
                    const SizedBox(height: 8),
                    _buildRecordingTimer(),
                  ],
                ],
              ),
            ),
          ),
          
          Divider(height: 1, thickness: 0.5, color: AppColors.outline),
          // ── 音量行 ──
          _buildVolumeRow(cfg),
          Divider(height: 1, thickness: 0.5, color: AppColors.outline),
          // ── 底部控制栏 ──
          _buildBottomControlBar(context, cfg),
        ],
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildTitleBar(BuildContext context, ShadowReaderConfig cfg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '跟读评测',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          // 关闭按钮：inline 模式使用 onClose 回调，dialog 模式使用 Navigator.pop
          GestureDetector(
            onTap: widget._isInline ? widget._onClose : () => Navigator.of(context).pop(),
            child: Icon(Icons.close, color: AppColors.onSurfaceVariant, size: 20),
          ),
        ],
      ),
    );
  }

  /// 得分 + 描述区域
  Widget _buildScoreHeader(bool isScored, bool isEvaluating, bool isListening) {
    String scoreText;
    String descText;
    Color scoreColor = AppColors.onSurface;
    
    if (isScored && _overallScore != null) {
      scoreText = '${_overallScore!.round()}';
      descText = _getScoreDescription();
      scoreColor = EvaluationDisplayHelper.getScoreColor(_overallScore!);
    } else if (isEvaluating) {
      scoreText = '...';
      descText = '正在分析您的发音...';
    } else if (isListening) {
      scoreText = '录音';
      descText = '正在录音，请大声朗读';
    } else {
      scoreText = '就绪';
      descText = '点击录音开始跟读';
    }
    
    return Row(
      children: [
        // 左侧：得分
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: scoreColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: scoreColor.withValues(alpha: 0.5), width: 2),
          ),
          child: Center(
            child: isEvaluating
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                  )
                : Text(
                    scoreText,
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        // 右侧：描述
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                descText,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  decoration: TextDecoration.none,
                ),
              ),
              if (isScored && _lastEvaluationResult != null) ...[
                const SizedBox(height: 4),
                Text(
                  '流利度 ${_fluencyScore?.round() ?? '-'} · 准确度 ${_accuracyScore?.round() ?? '-'} · 完整度 ${_completenessScore?.round() ?? '-'}',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 获取分数描述
  String _getScoreDescription() {
    if (_overallScore == null) return '';
    if (_overallScore! >= 90) return '发音优秀，继续保持！';
    if (_overallScore! >= 80) return '发音良好，流利度不错';
    if (_overallScore! >= 70) return '发音及格，还有提升空间';
    if (_overallScore! >= 60) return '需要多加练习';
    return '建议重点练习发音';
  }

  /// 字幕区域
  Widget _buildSubtitleBlock({
    required String text,
    required bool isOriginal,
    String? label,
    List<RecognizedWord>? recognizedWords,
    bool liveTranscribing = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOriginal 
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isOriginal ? AppColors.primary : AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Flexible(
            child: recognizedWords != null && recognizedWords.isNotEmpty
                ? _buildColoredRecognizedText(recognizedWords)
                : SingleChildScrollView(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: liveTranscribing ? Colors.amber : AppColors.onSurface,
                        fontSize: 16,
                        height: 1.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 构建带颜色的识别文本
  Widget _buildColoredRecognizedText(List<RecognizedWord> words) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: words.map((word) {
          final color = word.correct ? AppColors.success : AppColors.error;
          return GestureDetector(
            onTap: () => _showWordDetail(word),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                word.word,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 构建识别文本
  String _buildRecognizedText() {
    if (_recognizedWords.isEmpty) return '';
    return _recognizedWords.map((w) => w.word).join(' ');
  }

  /// 显示单词详情弹窗（统一显示逻辑）
  void _showWordDetail(RecognizedWord word) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  word.word,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
                // 得分标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: EvaluationDisplayHelper.getScoreColor(word.score).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${word.score.toStringAsFixed(0)}分',
                    style: TextStyle(
                      color: EvaluationDisplayHelper.getScoreColor(word.score),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 朗读类型标签
                if (word.readType != null && word.readType != 'normal')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: word.readTypeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      word.readTypeLabel,
                      style: TextStyle(
                        color: word.readTypeColor,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 音素得分
            if (word.phonemes != null && word.phonemes!.isNotEmpty) ...[
              Text(
                '音素评分',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: word.phonemes!.map((p) {
                  final phonemeColor = EvaluationDisplayHelper.getScoreColor(p.score ?? 0);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: phonemeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          p.phoneme,
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 16,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(p.score ?? 0).round()}',
                          style: TextStyle(
                            color: phonemeColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            // 重音
            if (word.wordStress != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '重音: ',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, decoration: TextDecoration.none),
                  ),
                  Icon(
                    word.wordStress! ? Icons.check_circle : Icons.cancel,
                    color: word.wordStress! ? AppColors.success : AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    word.wordStress! ? '正确' : '错误',
                    style: TextStyle(
                      color: word.wordStress! ? AppColors.success : AppColors.error,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 录音计时器
  Widget _buildRecordingTimer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _formatRecordingTime(_recordingSeconds),
          style: TextStyle(
            color: AppColors.error,
            fontSize: 12,
            fontFamily: 'monospace',
            decoration: TextDecoration.none,
          ),
        ),
      ],
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
                color: _isMuted ? AppColors.onSurfaceVariant.withValues(alpha: 0.3) : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Material(
              color: Colors.transparent,
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
                  inactiveColor: AppColors.outline,
                  onChanged: (v) {
                    cfg.setOriginalVolume?.call(v);
                    if (v > 0 && _isMuted) setState(() => _isMuted = false);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$vol%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
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
    
    // 判断是否为视频/音频类型，显示上一句/下一句按钮
    final showNavigation = cfg.resourceType == 'video' || cfg.resourceType == 'audio';

    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
            // ── 关闭按钮（内联模式）──
            if (widget._isInline && widget._onClose != null) ...[
              _circleBtn(
                Icons.close_rounded,
                AppColors.onSurfaceVariant,
                32,
                18,
                onTap: widget._onClose,
                bg: AppColors.surfaceElevated,
              ),
              const SizedBox(width: 6),
            ],
            
            // ── 左组：导航（仅视频/音频显示）──
            if (showNavigation) ...[
              _circleBtn(
                Icons.skip_previous_rounded,
                AppColors.onSurfaceVariant,
                36,
                18,
                onTap: cfg.previousSentence != null
                    ? () {
                        _resetRecordingState();
                        cfg.previousSentence!();
                      }
                    : null,
                bg: AppColors.surfaceElevated,
              ),
              const SizedBox(width: 6),
              _circleBtn(
                Icons.play_arrow_rounded,
                AppColors.onSurfaceVariant,
                36,
                20,
                onTap: () => _replayOriginal(cfg),
                bg: AppColors.surfaceElevated,
              ),
              const SizedBox(width: 6),
              _circleBtn(
                Icons.skip_next_rounded,
                AppColors.onSurfaceVariant,
                36,
                18,
                onTap: cfg.nextSentence != null
                    ? () {
                        _resetRecordingState();
                        cfg.nextSentence!();
                      }
                    : null,
                bg: AppColors.surfaceElevated,
              ),
            ] else ...[
              // 非视频/音频类型，显示播放按钮
              _circleBtn(
                Icons.play_arrow_rounded,
                AppColors.onSurfaceVariant,
                36,
                20,
                onTap: () => _replayOriginal(cfg),
                bg: AppColors.surfaceElevated,
              ),
            ],
            
            const Spacer(),
            
            // ── 中间：录音/停止按钮 ──
            _circleBtn(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              isListening ? AppColors.onPrimary : AppColors.primary,
              44,
              22,
              onTap: isListening
                  ? () => _stopRecording(context, cfg)
                  : () => _startRecording(context, cfg),
              bg: isListening
                  ? AppColors.error
                  : AppColors.primary.withValues(alpha: 0.15),
            ),
            
            const SizedBox(width: 6),
            
            // ── 右组：操作按钮 ──
            _circleBtn(
              Icons.replay_rounded,
              AppColors.onSurfaceVariant,
              36,
              18,
              onTap: (!isListening && hasRecording)
                  ? () => _playRecording()
                  : null,
              bg: AppColors.surfaceElevated,
            ),
            const SizedBox(width: 6),
            // 详情按钮（图标）
            _circleBtn(
              Icons.analytics_rounded,
              (!isListening && isScored) ? AppColors.primary : AppColors.onSurfaceVariant.withValues(alpha: 0.3),
              36,
              18,
              onTap: (!isListening && isScored)
                  ? () => _navigateToEvaluation(cfg)
                  : null,
              bg: (!isListening && isScored)
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surfaceElevated,
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
        ? AppColors.surfaceElevated.withValues(alpha: 0.5)
        : (bg ?? AppColors.surfaceElevated);
    final icColor = !enabled ? AppColors.onSurfaceVariant.withValues(alpha: 0.3) : iconColor;
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
      final fileName = 'shengtong_eval_$cfg.resourceCode_$timestamp.json';
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
    // 根据评测类型显示不同的 UI
    if (_evaluationType == 'word' && _recognizedWords.isNotEmpty) {
      return _buildWordEvaluationPage(context, cfg);
    }
    
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            // ── 主内容区 ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 总分 + 维度评分 一行 ──
                    _buildCompactScoreRow(),
                    const SizedBox(height: 12),
                    
                    // ── 语速信息 ──
                    if (_recordingSeconds > 0) ...[
                      _buildSpeechRateInfo(cfg),
                      const SizedBox(height: 12),
                    ],
                    
                    // ── 单词详情（含音素）──
                    if (_recognizedWords.isNotEmpty) ...[
                      _buildWordDetailsList(),
                      const SizedBox(height: 12),
                    ],
                    
                    // ── 薄弱维度提示 ──
                    if (_lastEvaluationResult != null) ...[
                      _buildWeakDimensionsTip(),
                      const SizedBox(height: 12),
                    ],
                    
                    // ── AI 分析结果（内联显示，点击底部按钮切换）──
                    if (_showAiAnalysis && _aiAnalysisResult != null) ...[
                      _buildAiAnalysisResultInline(),
                      const SizedBox(height: 12),
                    ],
                    if (_showAiAnalysis && _isAiAnalyzing) ...[
                      _buildAiAnalysisLoadingInline(),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            
            // ── 底部操作栏（返回 + AI分析 + 重新录音）──
            _buildEvaluationBottomBar(context, cfg),
          ],
        ),
      ),
    );
  }

  // ━━━ 单词评测页（专用 UI）━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildWordEvaluationPage(BuildContext context, ShadowReaderConfig cfg) {
    final word = _recognizedWords.first;
    final score = _overallScore ?? 0;
    final color = _scoreColor(score);
    
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // ── 主内容区 ──
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── 总分 + 播放录音按钮 ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '总分',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 12,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${score.round()}',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                                  child: Text(
                                    '分',
                                    style: TextStyle(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 14,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // 播放录音按钮
                        OutlinedButton.icon(
                          onPressed: _playRecording,
                          icon: Icon(Icons.play_arrow, color: AppColors.success),
                          label: Text(
                            '播放录音',
                            style: TextStyle(color: AppColors.success),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.success.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // ── 单词 + 音标 ──
                    Text(
                      word.word,
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (word.phonemes != null && word.phonemes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '/${word.phonemes!.map((p) => p.phoneme).join('')}/',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 18,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // ── 音素评分表格 ──
                    if (word.phonemes != null && word.phonemes!.isNotEmpty) ...[
                      // 表头
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '音标',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '拼写',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '评分结果',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 音素行
                      ...word.phonemes!.map((p) {
                        final phonemeColor = _scoreColor(p.score ?? 0);
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.outline.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '/${p.phoneme}/',
                                  style: TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 16,
                                    decoration: TextDecoration.none,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  p.spelling ?? p.expectedPhoneme ?? '',
                                  style: TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.none,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${(p.score ?? 0).round()}',
                                  style: TextStyle(
                                    color: phonemeColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.none,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            
            // ── 底部操作栏 ──
            _buildEvaluationBottomBar(context, cfg),
          ],
        ),
      ),
    );
  }

  /// 紧凑的总分+维度评分一行
  Widget _buildCompactScoreRow() {
    final score = _overallScore ?? 0;
    final color = _scoreColor(score);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // 左侧：总分圆环
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(
              painter: _ScoreRingPainter(score: score, color: color),
              child: Center(
                child: Text(
                  '${score.round()}',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 右侧：维度评分
          Expanded(
            child: Column(
              children: [
                _buildCompactDimension('准确', _accuracyScore),
                const SizedBox(height: 4),
                _buildCompactDimension('流利', _fluencyScore),
                const SizedBox(height: 4),
                _buildCompactDimension('完整', _completenessScore),
                if (_lastEvaluationResult?.pronunciation != null) ...[
                  const SizedBox(height: 4),
                  _buildCompactDimension('发音', _lastEvaluationResult!.pronunciation),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 紧凑的维度评分项
  Widget _buildCompactDimension(String label, double? score) {
    final s = score ?? 0;
    final color = EvaluationDisplayHelper.getScoreColor(s);
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11, decoration: TextDecoration.none),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: s > 0 ? s / 100 : 0,
              backgroundColor: AppColors.outline,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text(
            s > 0 ? '${s.round()}' : '--',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// 语速信息
  Widget _buildSpeechRateInfo(ShadowReaderConfig cfg) {
    // 计算语速：单词数 / 时间（秒）× 60 = 词/分钟
    final wordCount = _recognizedWords.length;
    final timeSeconds = _recordingSeconds > 0 ? _recordingSeconds.toDouble() : 1.0;
    final wpm = (wordCount / timeSeconds * 60).round();
    
    // 获取参考文本的词数
    final refWordCount = cfg.subtitle.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem('语速', '$wpm 词/分'),
          Container(width: 1, height: 16, color: AppColors.outline),
          _buildInfoItem('用时', _formatRecordingTime(_recordingSeconds)),
          Container(width: 1, height: 16, color: AppColors.outline),
          _buildInfoItem('识别', '$wordCount/$refWordCount 词'),
        ],
      ),
    );
  }

  /// 信息项
  Widget _buildInfoItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  /// AI 分析结果（内联显示）
  Widget _buildAiAnalysisResultInline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primary),
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
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12, height: 1.4),
          ),
          if (_aiAnalysisResult!.suggestions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '改进建议：',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ..._aiAnalysisResult!.suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• $s', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11, height: 1.3)),
            )),
          ],
        ],
      ),
    );
  }

  /// AI 分析加载中（内联显示）
  Widget _buildAiAnalysisLoadingInline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Text('AI 分析中...', style: TextStyle(color: AppColors.primary, fontSize: 13)),
        ],
      ),
    );
  }

  /// 底部操作栏：返回 + AI分析 + 重新录音
  Widget _buildEvaluationBottomBar(BuildContext context, ShadowReaderConfig cfg) {
    final bool hasAiResult = _aiAnalysisResult != null;
    final bool isAiActive = _showAiAnalysis;
    
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            // 返回按钮（最左边）
            GestureDetector(
              onTap: () => _navigateBack(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('返回', style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            const Spacer(),
            // AI 分析按钮（中间，点击切换显示/隐藏）
            GestureDetector(
              onTap: hasAiResult
                  ? () => setState(() => _showAiAnalysis = !_showAiAnalysis)
                  : () => _triggerAiAnalysis(cfg),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isAiActive
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAiActive
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isAiAnalyzing)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    else
                      Icon(
                        hasAiResult
                            ? (isAiActive ? Icons.visibility : Icons.visibility_off)
                            : Icons.auto_awesome_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _isAiAnalyzing
                          ? '分析中...'
                          : hasAiResult
                              ? (isAiActive ? '收起分析' : '查看分析')
                              : 'AI 分析',
                      style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // 重新录音
            _evalBtn('重新录音', Icons.refresh_rounded, () => _restartFromEvaluation(context, cfg)),
          ],
        ),
      ),
    );
  }

  /// 构建单词详情列表（含音素信息）
  Widget _buildWordDetailsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '单词详情',
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recognizedWords.map((word) {
            final bool isMiss = word.readType == 'miss';
            final bool isInsert = word.readType == 'insert';
            final bool hasError = !word.correct || word.hasPhonemeErrors;
            final Color color = isMiss
                ? AppColors.warning
                : isInsert
                    ? AppColors.primary
                    : hasError
                        ? AppColors.error
                        : AppColors.success;
            
            // 构建音素显示文本
            String phonemeText = '';
            if (word.phonemes != null && word.phonemes!.isNotEmpty) {
              phonemeText = word.phonemes!
                  .map((p) => p.phoneme)
                  .join(' ');
            }
            
            return GestureDetector(
              onTap: () => _showWordDetailDialog(word),
              child: Container(
                width: 72,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 单词（上）
                    Text(
                      word.word,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 音素（中，如果有）
                    if (phonemeText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phonemeText,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.7),
                          fontSize: 9,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    // 得分（下）
                    Text(
                      isMiss
                          ? '漏读'
                          : isInsert
                              ? '多读'
                              : '${word.score.round()}',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 显示单词详情弹窗
  /// 显示单词详情弹窗（统一显示逻辑）
  void _showWordDetailDialog(RecognizedWord word) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  word.word,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Spacer(),
                // 得分标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: EvaluationDisplayHelper.getScoreColor(word.score).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${word.score.toStringAsFixed(0)}分',
                    style: TextStyle(
                      color: EvaluationDisplayHelper.getScoreColor(word.score),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 朗读类型标签
                if (word.readType != null && word.readType != 'normal')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: word.readTypeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      word.readTypeLabel,
                      style: TextStyle(
                        color: word.readTypeColor,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 音素得分
            if (word.phonemes != null && word.phonemes!.isNotEmpty) ...[
              Text(
                '音素评分',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: word.phonemes!.map((p) {
                  final phonemeColor = EvaluationDisplayHelper.getScoreColor(p.score ?? 0);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: phonemeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          p.phoneme,
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 16,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(p.score ?? 0).round()}',
                          style: TextStyle(
                            color: phonemeColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            // 重音
            if (word.wordStress != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    '重音: ',
                    style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, decoration: TextDecoration.none),
                  ),
                  Icon(
                    word.wordStress! ? Icons.check_circle : Icons.cancel,
                    color: word.wordStress! ? AppColors.success : AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    word.wordStress! ? '正确' : '错误',
                    style: TextStyle(
                      color: word.wordStress! ? AppColors.success : AppColors.error,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
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
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                '提升建议',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
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
                style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11, decoration: TextDecoration.none),
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
  void _navigateToEvaluation([ShadowReaderConfig? cfg]) {
    if (_state != 'scored') return;
    // 暂停音频播放 + 停止 TTS + 停止高亮
    cfg?.pause?.call();
    _stopTtsHighlight();
    TtsService().stop();
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

  bool _isPlayingRecording = false;

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;
    if (_isPlayingRecording) return; // 防止连续点击
    _isPlayingRecording = true;
    try {
      // 停止当前播放，复用同一个 AudioPlayer 实例
      if (_audioPlayer.state == ap.PlayerState.playing) {
        await _audioPlayer.stop();
      }
      await _audioPlayer.setSource(ap.DeviceFileSource(_recordingPath!));
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('播放录音失败: $e');
    } finally {
      _isPlayingRecording = false;
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
    } catch (_) {
      // 忽略停止错误
    }
    
      final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('需要麦克风权限才能跟读')),
        );
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
    // 两种模式都需要实时识别用于显示
    // 付费模式：显示实时文本，评测完成后替换为带分数的结果
    // 免费模式：显示实时文本，结束后直接评分
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
    
    debugPrint('🎤 [ShadowReader] ========== 开始声通 WebSocket 评测 ==========');
    debugPrint('🎤 [ShadowReader] 音频路径: $audioPath');
    debugPrint('🎤 [ShadowReader] 参考文本: ${cfg.subtitle.content}');
    
    try {
      // 使用 ShengtongEvaluator WebSocket 方式评测
      // 密钥从 AppKeysService 动态加载
      final stAppKey = AppKeysService.instance.shengtongAppKey;
      // 注意：声通 WebSocket 签名使用 shengtongApiKey 作为 secretKey（与 Python demo 一致）
      final stSecretKey = AppKeysService.instance.shengtongApiKey;

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
      final audioFile = File(_recordingPath!);
      if (!await audioFile.exists()) {
        debugPrint('❌ [ShadowReader] 音频文件不存在: $_recordingPath');
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

      // 创建 WebSocket 评测器
      final evaluator = ShengtongEvaluator(
        appKey: stAppKey,
        secretKey: stSecretKey,
      );
      _evaluator = evaluator;

      // 用于等待评测结果
      final resultCompleter = Completer<Map<String, dynamic>>();

      evaluator.onResult = (result) {
        debugPrint('🎤 [ShadowReader] 收到 WebSocket 评测结果');
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(result);
        }
      };

      evaluator.onError = (error) {
        debugPrint('❌ [ShadowReader] WebSocket 评测错误: $error');
        if (!resultCompleter.isCompleted) {
          resultCompleter.completeError(Exception(error));
        }
      };

      // 根据文本内容自动选择评测类型（与设计文档一致）
      // 单词：无空格且≤50字符 → word.eval（音素级反馈）
      // 短句：≤100字符 → sent.eval
      // 段落：>100字符 → para.eval
      final refText = cfg.subtitle.content;
      final trimmed = refText.trim();
      final coreType = (!trimmed.contains(' ') && trimmed.length <= 50)
          ? 'word.eval'
          : (trimmed.length <= 100 ? 'sent.eval' : 'para.eval');
      
      // 存储评测类型用于 UI 显示
      _evaluationType = coreType == 'word.eval' ? 'word' : (coreType == 'sent.eval' ? 'sentence' : 'paragraph');
      
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('🎤 [ShadowReader] 评测类型: $coreType (文本: "${refText.substring(0, refText.length > 20 ? 20 : refText.length)}...")');
      debugPrint('🎤 [ShadowReader] 开始调用声通 WebSocket API...');
      
      // 根据录音文件扩展名确定音频格式
      final audioType = _recordingPath!.endsWith('.m4a') ? 'm4a' : (_recordingPath!.endsWith('.mp3') ? 'mp3' : 'wav');
      debugPrint('🎤 [ShadowReader] 音频格式: $audioType');
      
      // 发送 start 命令（内部会自动发送 connect）
      final request = jsonEncode({
        'audio': {'audioType': audioType, 'sampleRate': 16000},
        'params': {
          'userId': userId,
          'coreType': coreType,
          'refText': refText,
        },
      });

      final started = await evaluator.start(request);
      if (!started) {
        throw Exception('WebSocket start 命令发送失败');
      }

      // 发送音频数据
      final audioBytes = await audioFile.readAsBytes();
      debugPrint('🎤 [ShadowReader] 发送音频数据: ${audioBytes.length} bytes');
      evaluator.feed(audioBytes);

      // 发送 stop 命令
      debugPrint('🎤 [ShadowReader] 发送 stop 命令');
      evaluator.stop();

      // 等待评测结果（最多 30 秒）
      final result = await resultCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('WebSocket 评测超时');
        },
      );

      // 使用结构化解析器解析声通评测结果
      final evaluationResult = ShengtongEvaluationResult.fromJson(result);
      
      // 从单词得分计算各维度分数（声通 WebSocket 响应可能不包含顶层维度）
      double? pronunciationScore = evaluationResult.pronunciation;
      double? overallScore = evaluationResult.overall;
      double? fluencyScore = evaluationResult.fluency;
      double? integrityScore = evaluationResult.integrity;
      double? accuracyScore = evaluationResult.accuracy;
      
      if (evaluationResult.words.isNotEmpty) {
        final validWords = evaluationResult.words.where((w) => (w.score ?? 0) > 0).toList();
        if (validWords.isNotEmpty) {
          // 计算发音得分（单词平均分）
          final totalScore = validWords.fold<double>(0, (a, b) => a + (b.score ?? 0));
          pronunciationScore = totalScore / validWords.length;
          
          // 如果总分为空，使用发音得分作为总分
          overallScore ??= pronunciationScore;
          
          // 如果流利度为空，从单词得分估算（正常朗读比例）
          fluencyScore ??= validWords.where((w) => w.readType == 'normal' || w.readType == null).length / validWords.length * 100;
          
          // 如果完整度为空，从单词数量估算（识别单词数/预期单词数）
          final expectedWordCount = cfg.subtitle.content.split(RegExp(r'\s+')).length;
          integrityScore ??= (validWords.length / expectedWordCount * 100).clamp(0, 100);
          
          // 如果准确度为空，使用发音得分
          accuracyScore ??= pronunciationScore;
        }
      }
      
      debugPrint('🎤 [ShadowReader] ========== 声通评测结构化结果 ==========');
      debugPrint('🎤 [ShadowReader] 总分: $overallScore');
      debugPrint('🎤 [ShadowReader] 流利度: $fluencyScore');
      debugPrint('🎤 [ShadowReader] 完整度: $integrityScore');
      debugPrint('🎤 [ShadowReader] 准确度: $accuracyScore');
      debugPrint('🎤 [ShadowReader] 发音: $pronunciationScore');
      debugPrint('🎤 [ShadowReader] 单词数: ${evaluationResult.words.length}');
      debugPrint('🎤 [ShadowReader] 错误单词: ${evaluationResult.getErrorWords().map((w) => '${w.word}(${w.score})').join(', ')}');
      debugPrint('🎤 [ShadowReader] 漏读单词: ${evaluationResult.getMissingWords().map((w) => w.word).join(', ')}');
      debugPrint('🎤 [ShadowReader] 音素错误: ${evaluationResult.getPhonemeErrors().map((e) => '${e.word}[${e.phoneme}]').join(', ')}');
      debugPrint('🎤 [ShadowReader] 薄弱维度: ${evaluationResult.weakDimensions.take(2).map((d) => '${d.key}(${d.value})').join(', ')}');
      debugPrint('🎤 [ShadowReader] ===========================================');

      final overall = overallScore;
      final fluency = fluencyScore;
      final accuracy = accuracyScore;
      final completeness = integrityScore;
      
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
      
      // 修正发音得分（如果API未返回，从单词得分计算）
      if (_lastEvaluationResult != null && _lastEvaluationResult!.pronunciation == null) {
        final words = _lastEvaluationResult!.words;
        if (words.isNotEmpty) {
          final validWords = words.where((w) => (w.score ?? 0) > 0).toList();
          if (validWords.isNotEmpty) {
            final totalScore = validWords.fold<double>(0, (a, b) => a + (b.score ?? 0));
            final avgPronunciation = totalScore / validWords.length;
            _lastEvaluationResult = ShengtongEvaluationResult(
              rawResult: _lastEvaluationResult!.rawResult,
              recordId: _lastEvaluationResult!.recordId,
              overall: _lastEvaluationResult!.overall,
              fluency: _lastEvaluationResult!.fluency,
              integrity: _lastEvaluationResult!.integrity,
              accuracy: _lastEvaluationResult!.accuracy,
              pronunciation: avgPronunciation,
              words: words,
              sentences: _lastEvaluationResult!.sentences,
              refText: _lastEvaluationResult!.refText,
              recognizedText: _lastEvaluationResult!.recognizedText,
            );
          }
        }
      }
      
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
      // 释放 WebSocket 评测器资源
      _evaluator?.dispose();
      _evaluator = null;
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
      
      // 免费模式也创建 ShengtongEvaluationResult 供 AI 分析使用
      _lastEvaluationResult = ShengtongEvaluationResult(
        rawResult: {
          'recognized_text': _liveTranscription,
          'ref_text': cfg.subtitle.content,
        },
        overall: overall,
        fluency: fluency,
        accuracy: accuracy,
        integrity: completeness,
        refText: cfg.subtitle.content,
        recognizedText: _liveTranscription,
        words: _recognizedWords.map((w) => WordEvaluation(
          word: w.word,
          score: w.score,
          readType: w.readType,
        )).toList(),
      );
      
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
    debugPrint('🎤 [ShadowReader] 🤖 AI 分析触发: _lastEvaluationResult=${_lastEvaluationResult != null}, _isAiAnalyzing=$_isAiAnalyzing');
    if (_lastEvaluationResult == null || _isAiAnalyzing) {
      debugPrint('🎤 [ShadowReader] 🤖 AI 分析跳过: evaluationResult=${_lastEvaluationResult == null ? "null" : "exists"}, isAnalyzing=$_isAiAnalyzing');
      return;
    }
    
    setState(() {
      _isAiAnalyzing = true;
      _showAiAnalysis = true; // 触发分析时自动显示区域
    });
    
    try {
      debugPrint('🎤 [ShadowReader] 🤖 用户触发 AI 发音分析...');
      
      final result = await AiEvaluationService.analyzePronunciation(
        evaluationResult: _lastEvaluationResult!,
        resourceTitle: cfg.resourceTitle,
        refText: cfg.subtitle.content,
        language: cfg.language,
      );
      
      if (result != null && mounted) {
        setState(() {
          _aiAnalysisResult = result;
          _showAiAnalysis = true; // 分析完成，自动显示结果
        });
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
      ..color = AppColors.outline
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
