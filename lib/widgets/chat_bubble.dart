import 'package:flutter/material.dart';
import 'package:vidlang/models/conversation_message.dart';

/// AI 对话消息气泡
class ChatBubble extends StatelessWidget {
  final ConversationMessage message;
  final bool showTranslation;

  const ChatBubble({
    super.key,
    required this.message,
    this.showTranslation = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAi = message.role == MessageRole.ai;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isAi) _buildAvatar(colorScheme),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                _buildBubble(isAi, colorScheme),
                if (isAi && showTranslation && message.translation != null)
                  _buildTranslation(colorScheme),
                _buildTimestamp(colorScheme),
              ],
            ),
          ),
          if (!isAi) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Icon(Icons.smart_toy, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildBubble(bool isAi, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isAi
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isAi ? 4 : 16),
          bottomRight: Radius.circular(isAi ? 16 : 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          if (message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: colorScheme.primary,
                ),
              ),
            ),
          if (message.isTranscribing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, size: 14, color: colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '识别中...',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTranslation(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(
        message.translation!,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildTimestamp(ColorScheme colorScheme) {
    final time = message.timestamp;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        timeStr,
        style: TextStyle(
          color: colorScheme.outline,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// 用户语音识别预览气泡（识别中的中间态）
class TranscriptionPreview extends StatelessWidget {
  final String preview;

  const TranscriptionPreview({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (preview.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      preview,
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 15,
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
}
