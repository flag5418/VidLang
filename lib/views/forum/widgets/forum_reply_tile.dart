import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/models/forum/forum_reply.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 论坛回复列表项组件
class ForumReplyTile extends ConsumerWidget {
  final ForumReply reply;
  final bool isOwner;
  final VoidCallback? onReplyTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onDeleteTap;
  final VoidCallback? onReportTap;

  const ForumReplyTile({
    super.key,
    required this.reply,
    this.isOwner = false,
    this.onReplyTap,
    this.onLikeTap,
    this.onDeleteTap,
    this.onReportTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(10),
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          Avatar(
            imageUrl: reply.authorAvatar,
            text: reply.authorName,
            size: AvatarSize.sm,
          ),
          SizedBox(width: adaptive.Adaptive.w(10)),
          // 内容区
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 用户名 + 时间
                Row(
                  children: [
                    Text(
                      reply.authorName,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(14),
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    Text(
                      _formatRelativeTime(reply.createdAt),
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(11),
                        color: colors.textWeak,
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz,
                        size: adaptive.Adaptive.sp(18),
                        color: colors.textWeak,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      itemBuilder: (_) => [
                        if (isOwner)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('删除'),
                          ),
                        const PopupMenuItem(
                          value: 'report',
                          child: Text('举报'),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') onDeleteTap?.call();
                        if (value == 'report') onReportTap?.call();
                      },
                    ),
                  ],
                ),
                SizedBox(height: adaptive.Adaptive.h(4)),
                // 回复内容
                if (reply.isDeleted)
                  Text(
                    '该回复已被删除',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(13),
                      color: colors.textWeak,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Text(
                    reply.content,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(14),
                      color: colors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                // 图片 — V2.0 回复模型已移除 imageUrls 字段
                const SizedBox.shrink(),
                SizedBox(height: adaptive.Adaptive.h(6)),
                // 底部操作
                Row(
                  children: [
                    _buildActionButton(
                      icon: reply.isLikedByCurrentUser
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      label: _formatCount(reply.likeCount),
                      color: reply.isLikedByCurrentUser
                          ? colors.primary
                          : colors.textWeak,
                      onTap: onLikeTap,
                    ),
                    SizedBox(width: adaptive.Adaptive.w(16)),
                    _buildActionButton(
                      icon: Icons.reply_outlined,
                      label: '回复',
                      color: colors.textWeak,
                      onTap: onReplyTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: adaptive.Adaptive.sp(15), color: color),
          SizedBox(width: adaptive.Adaptive.w(3)),
          Text(
            label,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(12),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${(diff.inDays / 30).floor()}个月前';
  }

  static String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
