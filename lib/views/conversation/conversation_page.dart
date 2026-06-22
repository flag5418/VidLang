import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/conversation_message.dart';
import 'package:vidlang/providers/conversation_provider.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_spacing.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        backgroundColor: isDark ? AppColors.surface : AppColors.lightSurface,
        appBar: _buildAppBar(convState),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildMessageList(convState, isDark)),
              _buildBottomBar(convState, isDark),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ConversationStateData convState) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      backgroundColor: isDark ? AppColors.surface : AppColors.lightSurface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: colorScheme.primary, size: 20),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Text(
        widget.sourceTitle ?? 'AI Conversation',
        style: TextStyle(
          color: isDark ? AppColors.onSurface : AppColors.lightOnSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        SizedBox(width: AppSpacing.space4),
        _buildConversationListButton(convState, isDark),
        SizedBox(width: AppSpacing.space4),
      ],
    );
  }

  Widget _buildConversationListButton(ConversationStateData convState, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.space6)),
            ),
            padding: EdgeInsets.all(AppSpacing.space6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.outline : const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: AppSpacing.space4),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.space4),
                  child: Text(
                    '对话历史',
                    style: TextStyle(
                      color: isDark ? AppColors.onSurface : AppColors.lightOnSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.space4),
                ListTile(
                  leading: Icon(Icons.history, color: colorScheme.primary),
                  title: Text(
                    '查看历史对话',
                    style: TextStyle(
                      color: isDark ? AppColors.onSurface : AppColors.lightOnSurface,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('对话历史功能开发中...')),
                    );
                  },
                ),
                SizedBox(height: AppSpacing.space6),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHighest,
          borderRadius: BorderRadius.circular(AppSpacing.space3),
        ),
        child: Icon(
          Icons.format_list_bulleted,
          size: 18,
          color: isDark ? AppColors.onSurfaceVariant : AppColors.lightOnSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMessageList(ConversationStateData convState, bool isDark) {
    if (convState.state == ConversationState.connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: AppSpacing.space4),
            Text(
              '正在连接 AI 助手...',
              style: TextStyle(
                color: isDark ? AppColors.onSurfaceVariant : AppColors.lightOnSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (convState.state == ConversationState.error) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 48),
              SizedBox(height: AppSpacing.space4),
              Text(
                convState.errorMessage ?? '连接出错',
                style: TextStyle(
                  color: isDark ? AppColors.onSurface : AppColors.lightOnSurface,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.space4),
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: const Text('重新连接'),
              ),
            ],
          ),
        ),
      );
    }

    if (convState.messages.isEmpty && convState.userTranscriptionPreview == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.space6),
          child: Text(
            'AI 助手正在准备提问...\n请等待 AI 说话',
            style: TextStyle(
              color: isDark ? AppColors.onSurfaceVariant : AppColors.lightOnSurfaceVariant,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space4,
      ),
      itemCount: convState.messages.length +
          (convState.userTranscriptionPreview != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < convState.messages.length) {
          return ChatBubble(
            message: convState.messages[index],
            showTranslation: convState.showTranslation,
            isDark: isDark,
          );
        }
        return TranscriptionPreview(
          preview: convState.userTranscriptionPreview ?? '',
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildBottomBar(ConversationStateData convState, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(AppSpacing.space4, AppSpacing.space3, AppSpacing.space4, AppSpacing.space4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.outline : const Color(0xFFDDDDDD),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusBar(convState, isDark),
          SizedBox(height: AppSpacing.space3),
          _buildRecordButton(convState, isDark),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ConversationStateData convState, bool isDark) {
    String statusText;
    Color statusColor;

    switch (convState.state) {
      case ConversationState.idle:
        statusText = '准备中';
        statusColor = isDark ? AppColors.onSurfaceVariant : AppColors.lightOnSurfaceDisabled;
        break;
      case ConversationState.connecting:
        statusText = '连接中...';
        statusColor = AppColors.warning;
        break;
      case ConversationState.aiSpeaking:
        statusText = 'AI 正在说话';
        statusColor = AppColors.primary;
        break;
      case ConversationState.listening:
        statusText = '轮到你说话了';
        statusColor = AppColors.success;
        break;
      case ConversationState.processing:
        statusText = 'AI 思考中...';
        statusColor = AppColors.warning;
        break;
      case ConversationState.error:
        statusText = '连接出错';
        statusColor = AppColors.error;
        break;
      case ConversationState.disconnected:
        statusText = '已断开';
        statusColor = isDark ? AppColors.onSurfaceDisabled : AppColors.lightOnSurfaceDisabled;
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
        SizedBox(width: AppSpacing.space2),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 13,
          ),
        ),
        SizedBox(width: AppSpacing.space3),
        Text(
          durationStr,
          style: TextStyle(
            color: isDark ? AppColors.onSurfaceVariant : AppColors.lightOnSurfaceVariant,
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        SizedBox(width: AppSpacing.space3),
        Text(
          '${convState.turnCount} 轮',
          style: TextStyle(
            color: isDark ? AppColors.onSurfaceVariant : AppColors.lightOnSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton(ConversationStateData convState, bool isDark) {
    final isDisabled = convState.state == ConversationState.connecting ||
        convState.state == ConversationState.error ||
        convState.state == ConversationState.disconnected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isHoldingRecord)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.space2),
            child: Icon(
              Icons.graphic_eq,
              color: AppColors.primary,
              size: 32,
            ),
          ),
        Text(
          _isHoldingRecord ? '松开结束' : '按住说话',
          style: TextStyle(
            color: isDisabled
                ? (isDark ? AppColors.onSurfaceDisabled : AppColors.lightOnSurfaceDisabled)
                : (isDark ? AppColors.onSurfaceVariant : AppColors.lightOnSurfaceVariant),
            fontSize: 13,
          ),
        ),
        SizedBox(height: AppSpacing.space2),
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
                  ? AppColors.primary
                  : (isDisabled
                      ? (isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHighest)
                      : AppColors.primary.withValues(alpha: 0.15)),
              shape: BoxShape.circle,
              border: Border.all(
                color: _isHoldingRecord
                    ? AppColors.primary
                    : (isDisabled
                        ? (isDark ? AppColors.outline : const Color(0xFFDDDDDD))
                        : AppColors.primary),
                width: 2,
              ),
            ),
            child: Icon(
              _isHoldingRecord ? Icons.stop : Icons.mic,
              color: _isHoldingRecord
                  ? AppColors.onPrimary
                  : (isDisabled
                      ? (isDark ? AppColors.onSurfaceDisabled : AppColors.lightOnSurfaceDisabled)
                      : AppColors.primary),
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
