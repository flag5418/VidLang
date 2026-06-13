import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/conversation_message.dart';
import 'package:vidlang/providers/conversation_provider.dart';
import 'package:vidlang/widgets/chat_bubble.dart';

/// AI 英语口语对话页面
///
/// 入口参数：
/// - [sourceType] 'subtitle' 或 'article'
/// - [sourceCode] 视频/文章 code
/// - [sourceTitle] 显示在顶部的标题
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

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isHoldingRecord = false;

  @override
  void initState() {
    super.initState();
    // 自动开始对话
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationProvider.notifier).startConversation(
            sourceType: widget.sourceType,
            sourceCode: widget.sourceCode,
            sourceTitle: widget.sourceTitle,
            voice: widget.voice,
          );
    });
  }

  @override
  void dispose() {
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
    final colorScheme = Theme.of(context).colorScheme;

    // 消息变化时滚动到底部
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
        backgroundColor: colorScheme.surface,
        appBar: _buildAppBar(convState),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildMessageList(convState)),
              _buildBottomBar(convState),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ConversationStateData convState) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: colorScheme.primary, size: 20),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Column(
        children: [
          Text(
            'AI English Conversation',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (convState.sourceTitle != null)
            Text(
              convState.sourceTitle!,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      centerTitle: true,
      actions: [
        // 字幕对话开关
        _buildTranslationToggle(convState),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTranslationToggle(ConversationStateData convState) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        ref.read(conversationProvider.notifier).toggleTranslation();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: convState.showTranslation
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: convState.showTranslation
                ? colorScheme.primary
                : colorScheme.outline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.subtitles,
              size: 14,
              color: convState.showTranslation
                  ? Colors.white
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '字幕对话',
              style: TextStyle(
                color: convState.showTranslation
                    ? Colors.white
                    : colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ConversationStateData convState) {
    final colorScheme = Theme.of(context).colorScheme;

    if (convState.state == ConversationState.connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '正在连接 AI 助手...',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (convState.state == ConversationState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                convState.errorMessage ?? '连接出错',
                style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(conversationProvider.notifier).startConversation(
                        sourceType: widget.sourceType,
                        sourceCode: widget.sourceCode,
                        sourceTitle: widget.sourceTitle,
                        voice: widget.voice,
                      );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('重新连接'),
              ),
            ],
          ),
        ),
      );
    }

    if (convState.messages.isEmpty &&
        convState.userTranscriptionPreview == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'AI 助手正在准备提问...\n请等待 AI 说话',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: convState.messages.length +
          (convState.userTranscriptionPreview != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < convState.messages.length) {
          return ChatBubble(
            message: convState.messages[index],
            showTranslation: convState.showTranslation,
          );
        }
        // 用户语音识别预览
        return TranscriptionPreview(
          preview: convState.userTranscriptionPreview ?? '',
        );
      },
    );
  }

  Widget _buildBottomBar(ConversationStateData convState) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 状态指示
          _buildStatusBar(convState),
          const SizedBox(height: 12),
          // 录音按钮
          _buildRecordButton(convState),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ConversationStateData convState) {
    final colorScheme = Theme.of(context).colorScheme;
    String statusText;
    Color statusColor;

    switch (convState.state) {
      case ConversationState.idle:
        statusText = '准备中';
        statusColor = colorScheme.onSurfaceVariant;
        break;
      case ConversationState.connecting:
        statusText = '连接中...';
        statusColor = Colors.orange;
        break;
      case ConversationState.aiSpeaking:
        statusText = 'AI 正在说话';
        statusColor = colorScheme.primary;
        break;
      case ConversationState.listening:
        statusText = '等待你说话';
        statusColor = Colors.green;
        break;
      case ConversationState.processing:
        statusText = 'AI 思考中...';
        statusColor = Colors.orange;
        break;
      case ConversationState.error:
        statusText = '连接出错';
        statusColor = colorScheme.error;
        break;
      case ConversationState.disconnected:
        statusText = '已断开';
        statusColor = colorScheme.outline;
        break;
    }

    final durationStr = _formatDuration(convState.duration);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          statusText,
          style: TextStyle(color: statusColor, fontSize: 13),
        ),
        const SizedBox(width: 12),
        Text(
          durationStr,
          style: TextStyle(
            color: colorScheme.outline,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${convState.turnCount} 轮',
          style: TextStyle(
            color: colorScheme.outline,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton(ConversationStateData convState) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = convState.state == ConversationState.connecting ||
        convState.state == ConversationState.error ||
        convState.state == ConversationState.disconnected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 波形图标
        if (_isHoldingRecord)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Icon(
              Icons.graphic_eq,
              color: colorScheme.primary,
              size: 32,
            ),
          ),
        // 提示文字
        Text(
          _isHoldingRecord ? '松开结束' : '按住说话',
          style: TextStyle(
            color: isDisabled
                ? colorScheme.outline
                : colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        // 录音按钮
        GestureDetector(
          onTapDown: isDisabled
              ? null
              : (_) {
                  setState(() => _isHoldingRecord = true);
                  ref.read(conversationProvider.notifier).startRecording();
                },
          onTapUp: isDisabled
              ? null
              : (_) {
                  setState(() => _isHoldingRecord = false);
                  ref.read(conversationProvider.notifier).stopRecording();
                },
          onTapCancel: isDisabled
              ? null
              : () {
                  setState(() => _isHoldingRecord = false);
                  ref.read(conversationProvider.notifier).stopRecording();
                },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _isHoldingRecord
                  ? colorScheme.primary
                  : (isDisabled
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primary.withValues(alpha: 0.15)),
              shape: BoxShape.circle,
              border: Border.all(
                color: _isHoldingRecord
                    ? colorScheme.primary
                    : (isDisabled
                        ? colorScheme.outline
                        : colorScheme.primary),
                width: 2,
              ),
            ),
            child: Icon(
              _isHoldingRecord ? Icons.stop : Icons.mic,
              color: _isHoldingRecord
                  ? Colors.white
                  : (isDisabled
                      ? colorScheme.outline
                      : colorScheme.primary),
              size: 32,
            ),
          ),
        ),
      ],
    );
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
