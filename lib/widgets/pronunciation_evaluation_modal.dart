import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // TODO: 后续集成 Riverpod 时启用
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:vidlang/theme/theme.dart';
import '../services/evaluation/unified_evaluation_service.dart';
// import '../providers/subscription_provider.dart'; // TODO: 后续获取订阅模式时启用
import '../models/evaluation_models.dart';
// import 'evaluation_content_widgets.dart'; // TODO: 后续重构各模式 UI 时启用

/// 跟读评测弹窗主组件
/// 统一容器，包含固定区域和可变内容区域
class PronunciationEvaluationModal extends StatefulWidget {
  final String referenceText;
  final EvaluationMode mode;
  final ThemeData? theme;
  final bool dismissible;
  final Function(EvaluationResult)? onEvaluationComplete;

  const PronunciationEvaluationModal({
    super.key,
    required this.referenceText,
    required this.mode,
    this.theme,
    this.dismissible = true,
    this.onEvaluationComplete,
  });

  @override
  State<PronunciationEvaluationModal> createState() =>
      _PronunciationEvaluationModalState();
}

class _PronunciationEvaluationModalState
    extends State<PronunciationEvaluationModal> {
  /// 统一评测服务（单例）
  /// 
  /// TODO: 当前未直接使用，保留供后续录音功能集成时使用
  // ignore: unused_field
  final _unifiedEvaluationService = UnifiedEvaluationService.instance;
  
  UnifiedEvaluationResult? _currentResult;
  bool _isRecording = false;
  double _audioVolume = 0.6; // 默认60%

  @override
  void initState() {
    super.initState();
    // 使用统一评测服务，不再需要手动创建实例
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? Theme.of(context);

    return Dialog.fullscreen(
      child: GestureDetector(
        onTap: widget.dismissible ? () => Navigator.pop(context) : null,
        child: Container(
          color: Colors.black54, // 半透明背景
          child: Center(
            child: GestureDetector(
              onTap: () {}, // 阻止内部点击传递
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                  maxWidth: MediaQuery.of(context).size.width * 0.92,
                ),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor,
                      blurRadius: adaptive.Adaptive.w(20),
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 顶部固定区 - 标题栏
                    _buildHeader(theme),

                    // 中间可变区 - 根据类型显示不同内容
                    Flexible(child: _buildContentArea(theme)),

                    // 综合评分区
                    _buildScoreArea(theme),

                    // 底部固定区 - 控制栏
                    _buildControlArea(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部固定区 (高度: 56dp)
  Widget _buildHeader(ThemeData theme) {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(AppIcons.recordVoiceOver, color: theme.primaryColor, size: adaptive.Adaptive.icon(24)),
          SizedBox(width: adaptive.Adaptive.w(12)),
          Text(
            '跟读评测',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(18),
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(8), vertical: adaptive.Adaptive.h(4)),
            decoration: BoxDecoration(
              color: _getModeColor().withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
            ),
            child: Text(
              _getModeLabel(),
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(12),
                color: _getModeColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(8)),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(AppIcons.close),
            iconSize: 24,
            color: theme.primaryColor,
          ),
        ],
      ),
    );
  }

  /// 中间可变区
  Widget _buildContentArea(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      child: _buildEvaluationContent(),
    );
  }

  /// 根据评测模式显示不同内容
  /// 
  /// TODO: 后续重构为使用 UnifiedEvaluationService，当前暂时显示占位内容
  Widget _buildEvaluationContent() {
    // 暂时返回一个占位组件，后续根据模式渲染不同的评测内容
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.mic,
            size: adaptive.Adaptive.icon(48),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(height: adaptive.Adaptive.h(16)),
          Text(
            '点击下方麦克风开始${_getModeLabel()}',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(16),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Text(
            widget.referenceText,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // TODO: 移除此方法，后续直接在 _buildEvaluationContent 中实现各模式的 UI
  /*
  Widget _buildEvaluationContentForMode() {
    switch (widget.mode) {
      case EvaluationMode.freeSTT:
        return NativeSTTContent(
          referenceText: widget.referenceText,
          onResultUpdate: _onUnifiedResultUpdate,
        );
      case EvaluationMode.word:
        return WordEvaluationContent(
          word: widget.referenceText,
          onResultUpdate: _onUnifiedResultUpdate,
        );
      case EvaluationMode.sentence:
        return SentenceEvaluationContent(
          sentence: widget.referenceText,
          onResultUpdate: _onUnifiedResultUpdate,
        );
      case EvaluationMode.paragraph:
        return ParagraphEvaluationContent(
          text: widget.referenceText,
          onResultUpdate: _onUnifiedResultUpdate,
        );
    }
  }
  */

  /// 综合评分区 (高度: 80dp)
  Widget _buildScoreArea(ThemeData theme) {
    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(16)),
      child: _currentResult != null
          ? Row(
              children: [
                // 综合评分圆环
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: (_currentResult?.overallScore ?? 0) / 100,
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      _getScoreColor(_currentResult?.overallScore ?? 0),
                    ),
                  ),
                ),
                SizedBox(width: adaptive.Adaptive.w(16)),
                // 评分信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '综合评分: ${(_currentResult?.overallScore ?? 0).toInt()}%',
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(18),
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(_currentResult!.overallScore),
                        ),
                      ),
                      SizedBox(height: adaptive.Adaptive.h(4)),
                      LinearProgressIndicator(
                        value: (_currentResult?.overallScore ?? 0) / 100,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                          _getScoreColor(_currentResult?.overallScore ?? 0),
                        ),
                        minHeight: 6,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                '点击录音开始评测',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(16),
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }

  /// 底部固定区 (高度: 120dp)
  Widget _buildControlArea(ThemeData theme) {
    return Container(
      height: 120,
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // 音频控制行
          Row(
            children: [
              Icon(AppIcons.volumeUp, color: theme.primaryColor, size: adaptive.Adaptive.icon(20)),
              SizedBox(width: adaptive.Adaptive.w(8)),
              Text(
                '原音音量',
                style: TextStyle(fontSize: adaptive.Adaptive.sp(14), color: theme.primaryColor),
              ),
              SizedBox(width: adaptive.Adaptive.w(12)),
              Expanded(
                child: Slider(
                  value: _audioVolume,
                  onChanged: (value) {
                    setState(() {
                      _audioVolume = value;
                    });
                  },
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(_audioVolume * 100).toInt()}%',
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _toggleRecording,
                  icon: Icon(
                    _isRecording ? AppIcons.stop : AppIcons.mic,
                    color: Colors.white,
                    size: adaptive.Adaptive.icon(20),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(16)),
          // 控制按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: AppIcons.stop,
                label: '停止',
                onPressed: _isRecording ? _stopRecording : null,
                theme: theme,
              ),
              _buildControlButton(
                icon: AppIcons.refresh,
                label: '重录',
                onPressed: _currentResult != null ? _resetRecording : null,
                theme: theme,
              ),
              _buildControlButton(
                icon: AppIcons.play,
                label: '回放',
                onPressed: _currentResult != null ? _playRecording : null,
                theme: theme,
              ),
              _buildControlButton(
                icon: AppIcons.save,
                label: '保存',
                onPressed: _currentResult != null ? _saveRecording : null,
                theme: theme,
              ),
              if (widget.mode != EvaluationMode.freeSTT)
                _buildControlButton(
                  icon: AppIcons.analytics,
                  label: '详情',
                  onPressed: _currentResult != null ? _showDetails : null,
                  theme: theme,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    required ThemeData theme,
  }) {
    final isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isEnabled
                  ? theme.primaryColor.withValues(alpha: 0.1)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: adaptive.Adaptive.icon(18),
              color: isEnabled
                  ? theme.primaryColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(10),
              color: isEnabled
                  ? theme.primaryColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // 辅助方法
  Color _getModeColor() {
    switch (widget.mode) {
      case EvaluationMode.freeSTT:
        return Colors.blue;
      case EvaluationMode.word:
        return Colors.green;
      case EvaluationMode.sentence:
        return Colors.orange;
      case EvaluationMode.paragraph:
        return Colors.purple;
    }
  }

  String _getModeLabel() {
    switch (widget.mode) {
      case EvaluationMode.freeSTT:
        return '免费识别';
      case EvaluationMode.word:
        return '单词精听';
      case EvaluationMode.sentence:
        return '句子评测';
      case EvaluationMode.paragraph:
        return '段落评测';
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green.shade600;
    if (score >= 80) return Colors.lightGreen.shade600;
    if (score >= 70) return Colors.orange.shade600;
    if (score >= 60) return Colors.red.shade500;
    return Colors.red.shade700;
  }

  // 录音控制方法
  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });
    if (_isRecording) {
      _startRecording();
    } else {
      _stopRecording();
    }
  }

  void _startRecording() async {
    // TODO: 集成录音功能，录制完成后调用统一评测服务
    debugPrint('🎤 [PronunciationModal] 开始录音...');
    
    // Free 模式：使用原生 STT 流式识别
    if (widget.mode == EvaluationMode.freeSTT) {
      // TODO: 调用 IosNativeFeatures.startSpeechRecognition()
      // 然后监听 onSpeechResult Stream
      // 最后调用 UnifiedEvaluationService.processNativeSttResult()
    }
    
    // Premium 模式：使用声通评测（需要先录音再上传）
    else {
      // TODO: 录音完成后调用 _unifiedEvaluationService.evaluate()
    }
  }

  void _stopRecording() {
    // TODO: 实现停止录音逻辑
    debugPrint('⏹️ [PronunciationModal] 停止录音');
  }

  void _resetRecording() {
    setState(() {
      _currentResult = null;
      _isRecording = false;
    });
  }

  void _playRecording() {
    // TODO: 实现播放录音逻辑
    debugPrint('▶️ [PronunciationModal] 播放录音');
  }

  void _saveRecording() {
    // TODO: 实现保存录音逻辑（保存到学习记录）
    if (_currentResult != null && _currentResult!.success) {
      debugPrint('💾 [PronunciationModal] 保存评测结果: ${_currentResult!.overallScore.toInt()}%');
    }
  }

  void _showDetails() {
    if (_currentResult != null && _currentResult!.hasDetail) {
      // TODO: 显示详细评测结果面板（Premium 模式专属）
      debugPrint('📊 [PronunciationModal] 显示详细评分: ${_currentResult!.detail}');
    }
  }

  /// 处理统一评测结果更新
  /// 
  /// TODO: 当前未直接调用，保留供后续各模式 UI 组件集成时使用
  // ignore: unused_element
  void _onUnifiedResultUpdate(UnifiedEvaluationResult result) {
    setState(() {
      _currentResult = result;
    });
    
    // 如果有回调，转换为旧格式（兼容性处理，后续移除）
    if (result.success) {
      final legacyResult = EvaluationResult(
        referenceText: result.referenceText,
        mode: widget.mode,
        overallScore: result.overallScore,
        fluencyScore: result.detail?.fluency ?? 0.0,
        accuracyScore: result.detail?.accuracy ?? 0.0,
        completenessScore: result.detail?.completeness ?? 0.0,
        wordEvaluations: result.detail?.wordEvaluations ?? [],
        createdAt: DateTime.now(),
      );
      widget.onEvaluationComplete?.call(legacyResult);
    }
  }
}

/// 显示评测弹窗的便捷方法
void showPronunciationEvaluation(
  BuildContext context, {
  required String text,
  EvaluationMode? mode,
  Function(EvaluationResult)? onComplete,
}) {
  // TODO: 实现 EvaluationModeDetector 或使用默认模式
  final detectedMode = mode ?? EvaluationMode.sentence; // 默认句子模式

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => PronunciationEvaluationModal(
      referenceText: text,
      mode: detectedMode,
      onEvaluationComplete: onComplete,
    ),
  );
}
