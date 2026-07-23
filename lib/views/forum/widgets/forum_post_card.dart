import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 论坛帖子卡片组件 — V2.0: tagName 替代 tags 列表
class ForumPostCard extends ConsumerWidget {
  final ForumPost post;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ForumPostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: BaseCard.outlined(
        padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
        margin: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(16),
          vertical: adaptive.Adaptive.h(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.isPinned) _buildPinnedBadge(colors),
            _buildTitleRow(context, colors),
            SizedBox(height: adaptive.Adaptive.h(6)),
            _buildSummary(colors),
            SizedBox(height: adaptive.Adaptive.h(8)),
            _buildFooter(context, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedBadge(AppColorsData colors) {
    return Padding(
      padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(6)),
      child: Row(
        children: [
          Icon(
            Icons.push_pin,
            size: adaptive.Adaptive.sp(14),
            color: colors.error,
          ),
          SizedBox(width: adaptive.Adaptive.w(4)),
          Text(
            '置顶',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(12),
              color: colors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context, AppColorsData colors) {
    return Text(
      post.title,
      style: TextStyle(
        fontSize: adaptive.Adaptive.sp(16),
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSummary(AppColorsData colors) {
    final summary = post.content
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAll(RegExp(r'[*_~`]'), '')
        .replaceAll('\n', ' ')
        .trim();
    return Text(
      summary,
      style: TextStyle(
        fontSize: adaptive.Adaptive.sp(13),
        color: colors.textSecondary,
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter(BuildContext context, AppColorsData colors) {
    return Row(
      children: [
        Avatar(
          imageUrl: post.authorAvatar,
          text: post.authorName,
          size: AvatarSize.xs,
        ),
        SizedBox(width: adaptive.Adaptive.w(6)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorName,
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(12),
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: adaptive.Adaptive.h(2)),
              Row(
                children: [
                  Text(
                    _formatRelativeTime(post.createdAt),
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(11),
                      color: colors.textWeak,
                    ),
                  ),
                  if (post.tagName != null) ...[
                    SizedBox(width: adaptive.Adaptive.w(6)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: adaptive.Adaptive.w(6),
                        vertical: adaptive.Adaptive.h(1),
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(adaptive.Adaptive.r(4)),
                      ),
                      child: Text(
                        post.tagName!,
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(10),
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: adaptive.Adaptive.w(8)),
        _buildStat(Icons.remove_red_eye_outlined, post.viewCount, colors),
        SizedBox(width: adaptive.Adaptive.w(8)),
        _buildStat(Icons.chat_bubble_outline, post.replyCount, colors),
        SizedBox(width: adaptive.Adaptive.w(8)),
        _buildLikeStat(colors),
      ],
    );
  }

  Widget _buildStat(IconData icon, int count, AppColorsData colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: adaptive.Adaptive.sp(14), color: colors.textWeak),
        SizedBox(width: adaptive.Adaptive.w(2)),
        Text(
          _formatCount(count),
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(11),
            color: colors.textWeak,
          ),
        ),
      ],
    );
  }

  Widget _buildLikeStat(AppColorsData colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          post.isLikedByCurrentUser
              ? Icons.thumb_up
              : Icons.thumb_up_outlined,
          size: adaptive.Adaptive.sp(14),
          color: post.isLikedByCurrentUser ? colors.primary : colors.textWeak,
        ),
        SizedBox(width: adaptive.Adaptive.w(2)),
        Text(
          _formatCount(post.likeCount),
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(11),
            color: post.isLikedByCurrentUser
                ? colors.primary
                : colors.textWeak,
          ),
        ),
      ],
    );
  }

  static String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月前';
    return '${(diff.inDays / 365).floor()}年前';
  }

  static String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
