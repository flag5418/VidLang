import 'package:flutter/material.dart';
import 'package:vidlang/models/conversation_message.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// AI 对话消息气泡 - 微信风格
class ChatBubble extends StatelessWidget {
  final ConversationMessage message;
  final bool showTranslation;
  final bool isDark;

  const ChatBubble({
    super.key,
    required this.message,
    this.showTranslation = true,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = message.role == MessageRole.ai;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isAi
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (isAi) _buildAvatar(context),
          SizedBox(width: AppSpacing.space2),
          Flexible(
            child: Column(
              crossAxisAlignment: isAi
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                _buildBubble(context, isAi),
                if (isAi &&
                    showTranslation &&
                    message.translation != null &&
                    message.translation!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: AppSpacing.space1),
                    child: Text(
                      message.translation!,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.onSurfaceVariant
                            : AppColors.lightOnSurfaceVariant,
                        fontSize: adaptive.Adaptive.sp(12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.space2),
          if (!isAi) _buildUserAvatar(context),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Container(
      width: adaptive.Adaptive.w(36),
      height: adaptive.Adaptive.w(36),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.space2),
      ),
      child: Icon(AppIcons.smartToy, color: Colors.white, size: adaptive.Adaptive.icon(20)),
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    return Container(
      width: adaptive.Adaptive.w(36),
      height: adaptive.Adaptive.w(36),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppSpacing.space2),
      ),
      child: Icon(AppIcons.person, color: Colors.white, size: adaptive.Adaptive.icon(20)),
    );
  }

  Widget _buildBubble(BuildContext context, bool isAi) {
    final bgColor = isAi
        ? (isDark ? AppColors.surfaceHighest : AppColors.lightSurfaceHighest)
        : AppColors.primary;

    final textColor = isAi
        ? (isDark ? AppColors.onSurface : AppColors.lightOnSurface)
        : AppColors.onPrimary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.space3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(color: textColor, fontSize: adaptive.Adaptive.sp(15), height: 1.5),
          ),
          if (message.isStreaming)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.space1),
              child: SizedBox(
                width: adaptive.Adaptive.w(14),
                height: adaptive.Adaptive.w(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isAi ? AppColors.primary : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 用户语音识别预览气泡
class TranscriptionPreview extends StatelessWidget {
  final String preview;
  final bool isDark;

  const TranscriptionPreview({
    super.key,
    required this.preview,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    if (preview.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.space1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.space3),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.mic, size: adaptive.Adaptive.icon(16), color: AppColors.primary),
                  SizedBox(width: AppSpacing.space2),
                  Flexible(
                    child: Text(
                      preview,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.onSurfaceVariant
                            : AppColors.lightOnSurfaceVariant,
                        fontSize: adaptive.Adaptive.sp(14),
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
