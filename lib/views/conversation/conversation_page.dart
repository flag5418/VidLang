import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/models/conversation_message.dart';
import 'package:vidlang/providers/conversation_provider.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/views/conversation/conversation_history_page.dart';

/// AI 英语口语对话页面
class ConversationPage extends ConsumerStatefulWidget {
  final String sourceType;
  final String sourceCode;
  final String? sourceTitle;
  final String voice;

  const ConversationPage({
    super.key,
    required this.sourceType,
    required this.sourceCode,
    this.sourceTitle,
    this.voice = 'Ethan',
  });

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  /// 录音开始时间（用于显示录音时长）
  DateTime? _recordingStartTime;

  // 思考中动画控制器（3 个跳跃圆点）
  late final AnimationController _thinkingController;
  late final List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _thinkingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _dotAnimations = List.generate(3, (i) {
      final start = i * 0.15;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _thinkingController,
          curve: Interval(start, end, curve: Curves.easeInOut),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(conversationProvider.notifier)
          .startConversation(
            sourceType: widget.sourceType,
            sourceCode: widget.sourceCode,
            sourceTitle: widget.sourceTitle,
            voice: widget.voice,
          );
    });
  }

  @override
  void dispose() {
    _thinkingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationProvider);
    final colors = context.colors;
    final textStyles = context.textStyles;

    ref.listen<ConversationStateData>(conversationProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          prev?.userTranscriptionPreview != next.userTranscriptionPreview) {
        _scrollToBottom();
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await ref.read(conversationProvider.notifier).endConversation();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: _buildAppBar(convState, colors, textStyles),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildMessageList(convState, colors, textStyles)),
              _buildBottomBar(convState, colors, textStyles),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    ConversationStateData convState,
    AppColorsData colors,
    AppTextStylesData textStyles,
  ) {
    return AppBar(
      backgroundColor: colors.background,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          AppIcons.arrowBackIosNew,
          color: colors.textSecondary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.sourceTitle ?? 'AI Conversation',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        _buildConversationListButton(convState, colors),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildConversationListButton(
    ConversationStateData convState,
    AppColorsData colors,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationHistoryPage(
              sourceType: widget.sourceType,
              sourceCode: widget.sourceCode,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.textWeak.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          AppIcons.formatListBulleted,
          size: 18,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildMessageList(
    ConversationStateData convState,
    AppColorsData colors,
    AppTextStylesData textStyles,
  ) {
    // 连接中（使用 TDesign TDLoading）
    if (convState.state == ConversationState.connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TDLoading(
              size: TDLoadingSize.medium,
              icon: TDLoadingIcon.circle,
            ),
            const SizedBox(height: 12),
            Text(
              '正在连接 AI 助手...',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // 错误
    if (convState.state == ConversationState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.error, color: colors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                convState.errorMessage ?? '连接出错',
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(conversationProvider.notifier)
                      .startConversation(
                        sourceType: widget.sourceType,
                        sourceCode: widget.sourceCode,
                        sourceTitle: widget.sourceTitle,
                        voice: widget.voice,
                      );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('重新连接'),
              ),
            ],
          ),
        ),
      );
    }

    // 空态 - 引导开始练习
    if (convState.messages.isEmpty &&
        convState.userTranscriptionPreview == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.chatBubbleOutline,
                  size: 36,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '开始和 AI 练习口语吧',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _suggestionChip('自我介绍', colors),
                  _suggestionChip('日常对话', colors),
                  _suggestionChip('旅行问路', colors),
                  _suggestionChip('餐厅点餐', colors),
                  _suggestionChip('商务会议', colors),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount:
          convState.messages.length +
          (convState.userTranscriptionPreview != null ? 1 : 0) +
          (convState.state == ConversationState.processing ? 1 : 0),
      itemBuilder: (context, index) {
        // 语音预览
        if (index < (convState.userTranscriptionPreview != null ? 1 : 0)) {
          return _buildTranscriptionPreview(
            convState.userTranscriptionPreview!,
            colors,
          );
        }

        final adjustedIndex =
            index - (convState.userTranscriptionPreview != null ? 1 : 0);

        // AI 思考中动画
        if (convState.state == ConversationState.processing &&
            adjustedIndex >= convState.messages.length) {
          return _buildThinkingDots(colors);
        }

        if (adjustedIndex < convState.messages.length) {
          final msg = convState.messages[adjustedIndex];
          final showDateSep = _shouldShowDateSeparator(
            convState.messages,
            adjustedIndex,
          );
          return Column(
            children: [
              if (showDateSep) _buildDateSeparator(msg.timestamp, colors),
              _buildMessageItem(msg, colors, textStyles),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// 判断是否需要在当前消息前显示日期分隔线
  bool _shouldShowDateSeparator(List<ConversationMessage> messages, int index) {
    if (index == 0) return true;
    final current = messages[index].timestamp;
    final previous = messages[index - 1].timestamp;
    return !_isSameDay(current, previous);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 日期分隔线
  Widget _buildDateSeparator(DateTime? date, AppColorsData colors) {
    if (date == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    String label;
    if (dateDay == today) {
      label = '今天';
    } else if (dateDay == yesterday) {
      label = '昨天';
    } else {
      label = '${date.month}月${date.day}日';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Container(height: 0.5, color: colors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
          Expanded(child: Container(height: 0.5, color: colors.border)),
        ],
      ),
    );
  }

  /// 消息项（带气泡 + 头像）
  Widget _buildMessageItem(
    ConversationMessage message,
    AppColorsData colors,
    AppTextStylesData textStyles,
  ) {
    final isAi = message.role == MessageRole.ai;
    final borderRadius = BorderRadius.circular(16);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isAi
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (isAi) ...[
            // AI 头像
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // AI 气泡
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: borderRadius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: textStyles.body.fontSize,
                        height: 1.6,
                      ),
                    ),
                    if (message.translation != null &&
                        message.translation!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          message.translation!,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: textStyles.caption.fontSize,
                          ),
                        ),
                      ),
                    if (message.isStreaming)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _buildThinkingDots(colors),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 48),
          ] else ...[
            // 用户气泡
            const SizedBox(width: 48),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: borderRadius,
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: colors.textPrimary.withValues(alpha: 0.85),
                    fontSize: textStyles.body.fontSize,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            // 用户头像
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, top: 4),
              decoration: BoxDecoration(
                color: colors.textWeak.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.person,
                size: 18,
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 建议话题按钮
  Widget _suggestionChip(String text, AppColorsData colors) {
    return GestureDetector(
      onTap: () {
        // 话题建议仅作引导，实际对话通过语音进行
        ref.read(conversationProvider.notifier).startRecording();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 3 个跳跃圆点动画
  Widget _buildThinkingDots(AppColorsData colors) {
    return AnimatedBuilder(
      animation: _thinkingController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = _dotAnimations[i].value;
            final translateY =
                -4.0 * (offset < 0.5 ? (offset * 2) : ((1 - offset) * 2));
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  /// 语音识别预览
  Widget _buildTranscriptionPreview(String preview, AppColorsData colors) {
    if (preview.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.outlinedCard),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.mic, size: 16, color: colors.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      preview,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    ConversationStateData convState,
    AppColorsData colors,
    AppTextStylesData textStyles,
  ) {
    final isPad = Adaptive.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        Adaptive.w(context, 16),
        Adaptive.h(context, 8),
        Adaptive.w(context, 16),
        Adaptive.h(context, 12),
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusBar(convState, colors),
          SizedBox(height: Adaptive.h(context, 8)),
          _buildInputArea(convState, colors, textStyles, isPad),
        ],
      ),
    );
  }

  Widget _buildStatusBar(
    ConversationStateData convState,
    AppColorsData colors,
  ) {
    String statusText;
    Color statusColor;

    switch (convState.state) {
      case ConversationState.idle:
        statusText = '准备中';
        statusColor = colors.textSecondary;
        break;
      case ConversationState.connecting:
        statusText = '连接中...';
        statusColor = colors.warning;
        break;
      case ConversationState.aiSpeaking:
        statusText = 'AI 正在说话';
        statusColor = colors.primary;
        break;
      case ConversationState.listening:
        statusText = '轮到你说话了';
        statusColor = colors.primary;
        break;
      case ConversationState.processing:
        statusText = 'AI 思考中...';
        statusColor = colors.warning;
        break;
      case ConversationState.error:
        statusText = '连接出错';
        statusColor = colors.error;
        break;
      case ConversationState.disconnected:
        statusText = '已断开';
        statusColor = colors.textSecondary;
        break;
    }

    final durationStr = _formatDuration(convState.duration);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(statusText, style: TextStyle(color: statusColor, fontSize: 13)),
        const SizedBox(width: 10),
        Text(
          durationStr,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${convState.turnCount} 轮',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  /// 底部输入区域：胶囊形输入栏
  Widget _buildInputArea(
    ConversationStateData convState,
    AppColorsData colors,
    AppTextStylesData textStyles,
    bool isPad,
  ) {
    final isDisabled =
        convState.state == ConversationState.connecting ||
        convState.state == ConversationState.error ||
        convState.state == ConversationState.disconnected;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Row(
        children: [
          // 左侧语音按钮
          SizedBox(
            width: 44,
            height: 44,
            child: _buildMicButton(convState, colors, isDisabled, isPad),
          ),
          // 中间输入提示
          Expanded(
            child: Text(
              _getInputHintText(convState),
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: textStyles.body.fontSize,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // 右侧发送按钮（蓝色圆形）
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? colors.textWeak.withValues(alpha: 0.1)
                      : colors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.send,
                  size: 18,
                  color: isDisabled ? colors.textWeak : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(
    ConversationStateData convState,
    AppColorsData colors,
    bool isDisabled,
    bool isPad,
  ) {
    final isRecording = convState.state == ConversationState.listening;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              if (isRecording) {
                // 再次点击 → 停止录音并发送
                _recordingStartTime = null;
                ref.read(conversationProvider.notifier).stopRecording();
              } else {
                // 点击 → 开始录音
                _recordingStartTime = DateTime.now();
                ref.read(conversationProvider.notifier).startRecording();
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: Adaptive.w(context, 44),
        height: Adaptive.w(context, 44),
        decoration: BoxDecoration(
          color: isRecording
              ? colors
                    .error // 录音中：红色背景
              : (isDisabled
                    ? colors.textWeak.withValues(alpha: 0.1)
                    : colors.primary.withValues(alpha: 0.1)),
          shape: BoxShape.circle,
          border: Border.all(
            color: isRecording
                ? colors.error
                : (isDisabled
                      ? colors.border
                      : colors.primary.withValues(alpha: 0.3)),
            width: 1.5,
          ),
        ),
        child: isRecording
            // 录音中：停止图标 + 可选时长
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.stop,
                    color: Colors.white,
                    size: Adaptive.sp(context, 16),
                  ),
                  if (_recordingStartTime != null)
                    Text(
                      _formatRecordingShortDuration(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: Adaptive.sp(context, 7),
                      ),
                    ),
                ],
              )
            : Icon(
                AppIcons.mic,
                color: isDisabled ? colors.textWeak : colors.primary,
                size: Adaptive.sp(context, 22),
              ),
      ),
    );
  }

  /// 获取输入区域提示文字
  String _getInputHintText(ConversationStateData convState) {
    if (convState.state == ConversationState.listening) {
      return '点击左侧按钮停止录音';
    }
    return '点击左侧按钮开始说话';
  }

  /// 格式化录音时长（简短格式，用于按钮内显示）
  String _formatRecordingShortDuration() {
    if (_recordingStartTime == null) return '0:00';
    final elapsed = DateTime.now().difference(_recordingStartTime!);
    final secs = elapsed.inSeconds.remainder(60);
    return '${elapsed.inMinutes}:$secs'.padLeft(4, '0');
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
