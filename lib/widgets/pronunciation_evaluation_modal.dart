import 'package:flutter/material.dart';
import 'package:vidlang/theme/theme.dart';
import '../services/evaluation_service.dart';
import '../models/evaluation_models.dart';
import 'evaluation_content_widgets.dart';

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
  late EvaluationService _evaluationService;
  EvaluationResult? _currentResult;
  bool _isRecording = false;
  double _audioVolume = 0.6; // 默认60%

  @override
  void initState() {
    super.initState();
    _evaluationService = EvaluationService();
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
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor,
                      blurRadius: 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(AppIcons.recordVoiceOver, color: theme.primaryColor, size: 24),
          const SizedBox(width: 12),
          Text(
            '跟读评测',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getModeColor().withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getModeLabel(),
              style: TextStyle(
                fontSize: 12,
                color: _getModeColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
      padding: const EdgeInsets.all(16),
      child: _buildEvaluationContent(),
    );
  }

  /// 根据评测模式显示不同内容
  Widget _buildEvaluationContent() {
    switch (widget.mode) {
      case EvaluationMode.freeSTT:
        return NativeSTTContent(
          referenceText: widget.referenceText,
          evaluationService: _evaluationService,
          onResultUpdate: _onResultUpdate,
        );
      case EvaluationMode.word:
        return WordEvaluationContent(
          word: widget.referenceText,
          evaluationService: _evaluationService,
          onResultUpdate: _onResultUpdate,
        );
      case EvaluationMode.sentence:
        return SentenceEvaluationContent(
          sentence: widget.referenceText,
          evaluationService: _evaluationService,
          onResultUpdate: _onResultUpdate,
        );
      case EvaluationMode.paragraph:
        return ParagraphEvaluationContent(
          text: widget.referenceText,
          evaluationService: _evaluationService,
          onResultUpdate: _onResultUpdate,
        );
    }
  }

  /// 综合评分区 (高度: 80dp)
  Widget _buildScoreArea(ThemeData theme) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _currentResult != null
          ? Row(
              children: [
                // 综合评分圆环
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: _currentResult!.overallScore / 100,
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      _getScoreColor(_currentResult!.overallScore),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 评分信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '综合评分: ${_currentResult!.overallScore.toInt()}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(_currentResult!.overallScore),
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _currentResult!.overallScore / 100,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                          _getScoreColor(_currentResult!.overallScore),
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
                  fontSize: 16,
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
      padding: const EdgeInsets.all(16),
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
              Icon(AppIcons.volumeUp, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '原音音量',
                style: TextStyle(fontSize: 14, color: theme.primaryColor),
              ),
              const SizedBox(width: 12),
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
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
              size: 18,
              color: isEnabled
                  ? theme.primaryColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
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

  void _startRecording() {
    // TODO: 实现开始录音逻辑
    _evaluationService.startRecording();
  }

  void _stopRecording() {
    // TODO: 实现停止录音逻辑
    _evaluationService.stopRecording();
  }

  void _resetRecording() {
    setState(() {
      _currentResult = null;
      _isRecording = false;
    });
  }

  void _playRecording() {
    // TODO: 实现播放录音逻辑
    _evaluationService.playRecording();
  }

  void _saveRecording() {
    // TODO: 实现保存录音逻辑
    if (_currentResult != null) {
      _evaluationService.saveRecording(_currentResult!);
    }
  }

  void _showDetails() {
    if (_currentResult != null) {
      // TODO: 显示详细评测结果
    }
  }

  void _onResultUpdate(EvaluationResult result) {
    setState(() {
      _currentResult = result;
    });
    widget.onEvaluationComplete?.call(result);
  }
}

/// 显示评测弹窗的便捷方法
void showPronunciationEvaluation(
  BuildContext context, {
  required String text,
  EvaluationMode? mode,
  Function(EvaluationResult)? onComplete,
}) {
  final detectedMode = mode ?? EvaluationModeDetector.detectMode(text);

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
