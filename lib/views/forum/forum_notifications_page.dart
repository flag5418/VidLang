import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/ui/loading_widget.dart';
import 'package:vidlang/models/forum/forum_notification.dart';
import 'package:vidlang/views/forum/providers/forum_providers.dart';
import 'package:vidlang/services/forum/forum_service.dart';
import 'package:vidlang/views/forum/forum_post_detail_page.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 论坛通知页面
class ForumNotificationsPage extends ConsumerStatefulWidget {
  const ForumNotificationsPage({super.key});

  @override
  ConsumerState<ForumNotificationsPage> createState() =>
      _ForumNotificationsPageState();
}

class _ForumNotificationsPageState
    extends ConsumerState<ForumNotificationsPage> {
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  bool _hasMore = true;
  final List<ForumNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !ref.read(forumNotificationsProvider(_page)).isLoading) {
        setState(() => _page++);
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _page = 1;
      _notifications.clear();
      _hasMore = true;
    });
    ref.invalidate(forumNotificationsProvider(_page));
    await ref
        .read(forumNotificationsProvider(_page).future)
        .catchError((_) => const PaginatedResponse<ForumNotification>(data: [], pagination: PaginationInfo()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final notifAsync = ref.watch(forumNotificationsProvider(_page));

    ref.listen(forumNotificationsProvider(_page), (_, next) {
      next.whenData((response) {
        if (_page == 1) _notifications.clear();
        _notifications.addAll(response.data);
        _hasMore = response.pagination.hasMore;
      });
    });

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppNavBar(
        title: '通知',
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: () => _markAllRead(context),
            child: Text(
              '全部已读',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(13),
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
      body: notifAsync.when(
        loading: () => _notifications.isEmpty
            ? const Center(child: LoadingWidget())
            : _buildListView(context, colors),
        error: (e, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline,
            title: '加载失败',
            description: e.toString(),
            actionLabel: '重试',
            onAction: _refresh,
          ),
        ),
        data: (_) => _notifications.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_none,
                title: '暂无通知',
                description: '当有人回复或点赞时，通知会出现在这里',
              )
            : _buildListView(context, colors),
      ),
    );
  }

  Widget _buildListView(BuildContext context, AppColorsData colors) {
    // 分组显示
    final groups = _groupNotifications(_notifications);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 40),
        itemCount: _buildGroupedItemCount(groups) + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // 展开 groups 为扁平列表
          int offset = 0;
          for (final group in groups.entries) {
            final items = group.value;
            if (index < offset + 1) {
              // 分组标题
              return _buildGroupHeader(context, colors, group.key);
            }
            offset += 1;
            final localIndex = index - offset;
            if (localIndex < items.length) {
              return _buildNotificationItem(context, colors, items[localIndex]);
            }
            offset += items.length;
          }
          // 加载更多指示器
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      ),
    );
  }

  int _buildGroupedItemCount(Map<String, List<ForumNotification>> groups) {
    int count = 0;
    for (final items in groups.values) {
      count += 1 + items.length; // 标题 + 条目
    }
    return count;
  }

  Map<String, List<ForumNotification>> _groupNotifications(
      List<ForumNotification> notifications) {
    final grouped = <String, List<ForumNotification>>{};
    for (final n in notifications) {
      final today = DateTime.now();
      final date = n.createdAt;
      String label;
      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        label = '今天';
      } else if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day - 1) {
        label = '昨天';
      } else {
        label = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
      grouped.putIfAbsent(label, () => []).add(n);
    }
    return grouped;
  }

  Widget _buildGroupHeader(
    BuildContext context,
    AppColorsData colors,
    String label,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(8),
      ),
      color: colors.surfaceContainer,
      child: Text(
        label,
        style: TextStyle(
          fontSize: adaptive.Adaptive.sp(12),
          fontWeight: FontWeight.w600,
          color: colors.textWeak,
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    AppColorsData colors,
    ForumNotification notif,
  ) {
    final isUnread = !notif.isRead;

    return GestureDetector(
      onTap: () => _handleTap(context, notif),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(16),
          vertical: adaptive.Adaptive.h(12),
        ),
        decoration: BoxDecoration(
          color: isUnread
              ? colors.primary.withValues(alpha: 0.04)
              : colors.surface,
          border: Border(
            bottom:
                BorderSide(color: colors.border, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: adaptive.Adaptive.w(36),
              height: adaptive.Adaptive.h(36),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getNotificationColor(notif.type, colors)
                    .withValues(alpha: 0.1),
              ),
              child: Icon(
                _getNotificationIcon(notif.type),
                size: adaptive.Adaptive.sp(18),
                color: _getNotificationColor(notif.type, colors),
              ),
            ),
            SizedBox(width: adaptive.Adaptive.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: adaptive.Adaptive.sp(14),
                            fontWeight:
                                isUnread ? FontWeight.w600 : FontWeight.w400,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: adaptive.Adaptive.w(8),
                          height: adaptive.Adaptive.h(8),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: adaptive.Adaptive.h(4)),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(13),
                      color: colors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: adaptive.Adaptive.h(4)),
                  Text(
                    _formatTime(notif.createdAt),
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(11),
                      color: colors.textWeak,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, ForumNotification notif) async {
    if (!notif.isRead) {
      try {
        final service = ref.read(forumServiceProvider);
        await service.markRead(notif.id);
        ref.invalidate(forumNotificationsProvider);
        ref.invalidate(forumUnreadCountProvider);
      } catch (_) {}
    }

    final postId = notif.metadata['post_id'];
    if (postId != null) {
      Navigator.push(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (_) => ForumPostDetailPage(postId: postId),
        ),
      );
    }
  }

  Future<void> _markAllRead(BuildContext context) async {
    try {
      final service = ref.read(forumServiceProvider);
      await service.markAllRead();
      ref.invalidate(forumNotificationsProvider);
      ref.invalidate(forumUnreadCountProvider);
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'reply':
        return Icons.chat_bubble_outline;
      case 'like':
        return Icons.thumb_up_outlined;
      case 'system':
        return Icons.campaign_outlined;
      case 'report_result':
        return Icons.gavel_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(String type, AppColorsData colors) {
    switch (type) {
      case 'reply':
        return AppColors.info;
      case 'like':
        return AppColors.success;
      case 'system':
        return colors.warning;
      case 'report_result':
        return colors.error;
      default:
        return colors.primary;
    }
  }

  static String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.month}月${date.day}日';
  }
}
