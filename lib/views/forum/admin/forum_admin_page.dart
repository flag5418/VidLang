import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/models/forum/forum_reply.dart';
import 'package:vidlang/models/forum/forum_report.dart';
import 'package:vidlang/models/forum/forum_feedback.dart';
import 'package:vidlang/models/forum/forum_admin_user.dart';
import 'package:vidlang/views/forum/providers/forum_admin_providers.dart';
import 'package:vidlang/components/ui/loading_widget.dart';
import 'package:vidlang/components/ui/error_widget.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

class ForumAdminPage extends ConsumerStatefulWidget {
  const ForumAdminPage({super.key});

  @override
  ConsumerState<ForumAdminPage> createState() => _ForumAdminPageState();
}

class _ForumAdminPageState extends ConsumerState<ForumAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 搜索控制器
  final _userSearchController = TextEditingController();
  final _feedbackReplyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _userSearchController.dispose();
    _feedbackReplyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminStatus = ref.watch(adminAuthProvider);

    return adminStatus.when(
      data: (isAdmin) {
        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('访问被拒绝')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.lock,
                      size: adaptive.Adaptive.icon(64),
                      color: AppColors.onSurfaceVariant),
                  SizedBox(height: adaptive.Adaptive.h(16)),
                  const Text('您没有管理员权限'),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('论坛管理后台'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 1,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: AppColors.onSurfaceVariant,
              indicatorColor: Theme.of(context).primaryColor,
              isScrollable: true,
              tabs: const [
                Tab(text: '内容审核'),
                Tab(text: '用户管理'),
                Tab(text: '反馈管理'),
                Tab(text: '数据统计'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildContentModerationTab(),
              _buildUserManagementTab(),
              _buildFeedbackManagementTab(),
              _buildStatisticsTab(),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: LoadingWidget(message: '验证管理员权限...')),
      error: (error, stack) => Scaffold(
        body: ErrorDisplayWidget(
          error: '权限验证失败: $error',
          onRetry: () => ref.invalidate(adminAuthProvider),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // Tab 1: 内容审核（帖子 / 评论 / 举报）
  // ═══════════════════════════════════════════════

  Widget _buildContentModerationTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '待审核帖子'),
              Tab(text: '待审核评论'),
              Tab(text: '举报处理'),
            ],
            labelColor: AppColors.textPrimary,
            indicatorColor: AppColors.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPendingPostsList(),
                _buildPendingCommentsList(),
                _buildReportsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 待审核帖子列表 ─────────────────────────────

  Widget _buildPendingPostsList() {
    final pendingPostsAsync = ref.watch(pendingPostsProvider);

    return pendingPostsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.checkCircle,
                    size: adaptive.Adaptive.icon(64), color: AppColors.success),
                SizedBox(height: adaptive.Adaptive.h(16)),
                const Text('所有帖子已审核完成'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          itemCount: posts.length,
          itemBuilder: (context, index) => _buildPostCard(posts[index]),
        );
      },
      loading: () => const LoadingWidget(message: '加载待审核帖子...'),
      error: (error, stack) => ErrorDisplayWidget(
        error: '加载失败: $error',
        onRetry: () => ref.invalidate(pendingPostsProvider),
      ),
    );
  }

  Widget _buildPostCard(ForumPost post) {
    return Card(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(post.title,
                      style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(16),
                          fontWeight: FontWeight.w600)),
                ),
                if (post.tagName != null && post.tagName!.isNotEmpty)
                  Chip(
                    label: Text(post.tagName!,
                        style: TextStyle(fontSize: adaptive.Adaptive.sp(10))),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  ),
              ],
            ),
            SizedBox(height: adaptive.Adaptive.h(8)),
            Text(post.content,
                style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(14),
                    color: AppColors.textSecondary),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            SizedBox(height: adaptive.Adaptive.h(12)),
            Row(
              children: [
                Text('作者: ${post.authorName}',
                    style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(12),
                        color: AppColors.onSurfaceVariant)),
                const Spacer(),
                TDButton(
                  text: '拒绝',
                  onTap: () => _rejectPost(post.id),
                  type: TDButtonType.text,
                  theme: TDButtonTheme.defaultTheme,
                ),
                SizedBox(width: adaptive.Adaptive.w(8)),
                TDButton(
                  text: '通过',
                  onTap: () => _approvePost(post.id),
                  type: TDButtonType.fill,
                  theme: TDButtonTheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 待审核评论列表 ─────────────────────────────

  Widget _buildPendingCommentsList() {
    final pendingCommentsAsync = ref.watch(pendingCommentsProvider);

    return pendingCommentsAsync.when(
      data: (comments) {
        if (comments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.checkCircle,
                    size: adaptive.Adaptive.icon(64), color: AppColors.success),
                SizedBox(height: adaptive.Adaptive.h(16)),
                const Text('所有评论已审核完成'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          itemCount: comments.length,
          itemBuilder: (context, index) =>
              _buildCommentCard(comments[index]),
        );
      },
      loading: () => const LoadingWidget(message: '加载待审核评论...'),
      error: (error, stack) => ErrorDisplayWidget(
        error: '加载失败: $error',
        onRetry: () => ref.invalidate(pendingCommentsProvider),
      ),
    );
  }

  Widget _buildCommentCard(ForumReply comment) {
    return Card(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('帖子 #${comment.postId}',
                style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(14),
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary)),
            SizedBox(height: adaptive.Adaptive.h(8)),
            Text(comment.content,
                style: TextStyle(fontSize: adaptive.Adaptive.sp(14))),
            SizedBox(height: adaptive.Adaptive.h(12)),
            Row(
              children: [
                Text('评论者: ${comment.authorName}',
                    style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(12),
                        color: AppColors.onSurfaceVariant)),
                const Spacer(),
                TDButton(
                  text: '拒绝',
                  onTap: () => _rejectComment(comment.id),
                  type: TDButtonType.text,
                  theme: TDButtonTheme.defaultTheme,
                ),
                SizedBox(width: adaptive.Adaptive.w(8)),
                TDButton(
                  text: '通过',
                  onTap: () => _approveComment(comment.id),
                  type: TDButtonType.fill,
                  theme: TDButtonTheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 举报处理列表 ───────────────────────────────

  Widget _buildReportsList() {
    final reportsAsync = ref.watch(pendingReportsProvider);

    return reportsAsync.when(
      data: (reports) {
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.checkCircle,
                    size: adaptive.Adaptive.icon(64), color: AppColors.success),
                SizedBox(height: adaptive.Adaptive.h(16)),
                const Text('暂无待处理举报'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          itemCount: reports.length,
          itemBuilder: (context, index) =>
              _buildReportCard(reports[index]),
        );
      },
      loading: () => const LoadingWidget(message: '加载举报列表...'),
      error: (error, stack) => ErrorDisplayWidget(
        error: '加载失败: $error',
        onRetry: () => ref.invalidate(pendingReportsProvider),
      ),
    );
  }

  Widget _buildReportCard(ForumReport report) {
    final reasonLabel = _getReportReasonLabel(report.reason);

    return Card(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(report.targetType == 'post' ? '帖子' : '评论',
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(10))),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                ),
                SizedBox(width: adaptive.Adaptive.w(8)),
                Chip(
                  label: Text(reasonLabel,
                      style: TextStyle(fontSize: adaptive.Adaptive.sp(10))),
                  backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                ),
              ],
            ),
            SizedBox(height: adaptive.Adaptive.h(8)),
            Text('目标 ID: #${report.targetId}',
                style: TextStyle(fontSize: adaptive.Adaptive.sp(14))),
            if (report.detail.isNotEmpty) ...[
              SizedBox(height: adaptive.Adaptive.h(4)),
              Text(report.detail,
                  style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(13),
                      color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            SizedBox(height: adaptive.Adaptive.h(8)),
            Text('举报时间: ${_formatDate(report.createdAt)}',
                style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(12),
                    color: AppColors.onSurfaceVariant)),
            SizedBox(height: adaptive.Adaptive.h(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TDButton(
                  text: '驳回举报',
                  onTap: () => _dismissReport(report.id),
                  type: TDButtonType.text,
                  theme: TDButtonTheme.defaultTheme,
                ),
                SizedBox(width: adaptive.Adaptive.w(8)),
                TDButton(
                  text: '确认违规',
                  onTap: () => _resolveReport(report.id),
                  type: TDButtonType.fill,
                  theme: TDButtonTheme.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // Tab 2: 用户管理
  // ═══════════════════════════════════════════════

  Widget _buildUserManagementTab() {
    final usersAsync = ref.watch(adminUsersProvider(
        const AdminUsersParams(page: 1, limit: 50)));

    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          child: TextField(
            controller: _userSearchController,
            decoration: InputDecoration(
              hintText: '搜索用户（昵称/邮箱）',
              prefixIcon: const Icon(AppIcons.search, size: 20),
              suffixIcon: _userSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(AppIcons.close, size: 18),
                      onPressed: () {
                        _userSearchController.clear();
                        ref.invalidate(adminUsersProvider);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(12)),
              isDense: true,
            ),
            onSubmitted: (value) {
              ref.invalidate(adminUsersProvider);
            },
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(child: usersAsync.when(
          data: (response) {
            final users = response.data;
            if (users.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.people,
                        size: adaptive.Adaptive.icon(64),
                        color: AppColors.onSurfaceVariant),
                    SizedBox(height: adaptive.Adaptive.h(16)),
                    const Text('暂无用户数据'),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(16)),
              itemCount: users.length,
              itemBuilder: (context, index) =>
                  _buildUserCard(users[index]),
            );
          },
          loading: () => const LoadingWidget(message: '加载用户列表...'),
          error: (error, stack) => ErrorDisplayWidget(
            error: '加载失败: $error',
            onRetry: () => ref.invalidate(adminUsersProvider),
          ),
        )),
      ],
    );
  }

  Widget _buildUserCard(AdminUser user) {
    return Card(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: adaptive.Adaptive.icon(24),
                  backgroundImage: user.avatar != null
                      ? NetworkImage(user.avatar!)
                      : null,
                  child: user.avatar == null
                      ? Icon(AppIcons.person,
                          size: adaptive.Adaptive.icon(24),
                          color: AppColors.onSurfaceVariant)
                      : null,
                ),
                SizedBox(width: adaptive.Adaptive.w(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName,
                          style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(16),
                              fontWeight: FontWeight.w600)),
                      if (user.email != null)
                        Text(user.email!,
                            style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(13),
                                color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: adaptive.Adaptive.w(10),
                      vertical: adaptive.Adaptive.h(4)),
                  decoration: BoxDecoration(
                    color: user.isBanned
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(user.banStatusText,
                      style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(12),
                          color:
                              user.isBanned ? AppColors.error : AppColors.success,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            if (user.banReason != null && user.banReason!.isNotEmpty) ...[
              SizedBox(height: adaptive.Adaptive.h(8)),
              Text('封禁原因: ${user.banReason}',
                  style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(12),
                      color: AppColors.error)),
            ],
            SizedBox(height: adaptive.Adaptive.h(8)),
            Row(
              children: [
                _buildUserStat('帖子', user.postCount),
                SizedBox(width: adaptive.Adaptive.w(16)),
                _buildUserStat('评论', user.commentCount),
                SizedBox(width: adaptive.Adaptive.w(16)),
                Text('注册: ${_formatDate(user.createdAt)}',
                    style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(12),
                        color: AppColors.textTertiary)),
              ],
            ),
            SizedBox(height: adaptive.Adaptive.h(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (user.isBanned)
                  TDButton(
                    text: '解封用户',
                    onTap: () => _unbanUser(user.id),
                    type: TDButtonType.text,
                    theme: TDButtonTheme.primary,
                  )
                else
                  TDButton(
                    text: '封禁用户',
                    onTap: () => _banUser(user.id),
                    type: TDButtonType.text,
                    theme: TDButtonTheme.danger,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStat(String label, int count) {
    return Text('$label: $count',
        style: TextStyle(
            fontSize: adaptive.Adaptive.sp(12),
            color: AppColors.onSurfaceVariant));
  }

  // ═══════════════════════════════════════════════
  // Tab 3: 反馈管理
  // ═══════════════════════════════════════════════

  String _feedbackStatusFilter = 'all';

  Widget _buildFeedbackManagementTab() {
    final feedbackAsync = ref.watch(adminFeedbackProvider(
        AdminFeedbackParams(status: _feedbackStatusFilter == 'all' ? null : _feedbackStatusFilter)));

    return Column(
      children: [
        // 状态筛选栏
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(16),
              vertical: adaptive.Adaptive.h(8)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('全部', 'all'),
                SizedBox(width: adaptive.Adaptive.w(8)),
                _buildFilterChip('待处理', 'pending'),
                SizedBox(width: adaptive.Adaptive.w(8)),
                _buildFilterChip('处理中', 'processing'),
                SizedBox(width: adaptive.Adaptive.w(8)),
                _buildFilterChip('已解决', 'resolved'),
                SizedBox(width: adaptive.Adaptive.w(8)),
                _buildFilterChip('已关闭', 'closed'),
              ],
            ),
          ),
        ),
        Expanded(child: feedbackAsync.when(
          data: (response) {
            final feedbacks = response.data;
            if (feedbacks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.feedback,
                        size: adaptive.Adaptive.icon(64),
                        color: AppColors.onSurfaceVariant),
                    SizedBox(height: adaptive.Adaptive.h(16)),
                    const Text('暂无反馈'),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding:
                  EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(16)),
              itemCount: feedbacks.length,
              itemBuilder: (context, index) =>
                  _buildFeedbackCard(feedbacks[index]),
            );
          },
          loading: () => const LoadingWidget(message: '加载反馈列表...'),
          error: (error, stack) => ErrorDisplayWidget(
            error: '加载失败: $error',
            onRetry: () => ref.invalidate(adminFeedbackProvider),
          ),
        )),
      ],
    );
  }

  Widget _buildFilterChip(String label, String status) {
    final isSelected = _feedbackStatusFilter == status;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: adaptive.Adaptive.sp(13))),
      selected: isSelected,
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
      onSelected: (_) {
        setState(() => _feedbackStatusFilter = status);
        ref.invalidate(adminFeedbackProvider);
      },
    );
  }

  Widget _buildFeedbackCard(ForumFeedback feedback) {
    final isExpanded = feedback.id == _expandedFeedbackId;
    final typeLabel = _getFeedbackTypeLabel(feedback.type);

    return Card(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(12)),
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedFeedbackId = isExpanded ? null : feedback.id;
          });
        },
        child: Padding(
          padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(typeLabel,
                        style: TextStyle(fontSize: adaptive.Adaptive.sp(10))),
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.1),
                  ),
                  SizedBox(width: adaptive.Adaptive.w(8)),
                  _buildStatusBadge(feedback.status),
                  const Spacer(),
                  Text(_formatDate(feedback.createdAt),
                      style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(12),
                          color: AppColors.textTertiary)),
                ],
              ),
              SizedBox(height: adaptive.Adaptive.h(8)),
              Text(feedback.title,
                  style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(15),
                      fontWeight: FontWeight.w600)),
              SizedBox(height: adaptive.Adaptive.h(4)),
              Text(feedback.content,
                  style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(13),
                      color: AppColors.textSecondary),
                  maxLines: isExpanded ? 50 : 2,
                  overflow: TextOverflow.ellipsis),
              if (feedback.adminReply != null &&
                  feedback.adminReply!.isNotEmpty) ...[
                SizedBox(height: adaptive.Adaptive.h(8)),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(adaptive.Adaptive.w(10)),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('管理员回复: ${feedback.adminReply}',
                      style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(13),
                          color: AppColors.success)),
                ),
              ],
              // 展开时显示操作区
              if (isExpanded) ...[
                SizedBox(height: adaptive.Adaptive.h(12)),
                const Divider(),
                SizedBox(height: adaptive.Adaptive.h(8)),
                // 回复输入
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _feedbackReplyController,
                        decoration: InputDecoration(
                          hintText: '输入回复内容...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: adaptive.Adaptive.w(12),
                              vertical: adaptive.Adaptive.h(8)),
                          isDense: true,
                        ),
                        maxLines: 2,
                        minLines: 1,
                      ),
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    TDButton(
                      text: '回复',
                      onTap: () => _replyFeedback(feedback.id),
                      type: TDButtonType.fill,
                      theme: TDButtonTheme.primary,
                      size: TDButtonSize.small,
                    ),
                  ],
                ),
                SizedBox(height: adaptive.Adaptive.h(8)),
                // 状态变更按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (feedback.status == 'pending')
                      TDButton(
                        text: '标记处理中',
                        onTap: () =>
                            _updateFeedbackStatus(feedback.id, 'processing'),
                        type: TDButtonType.text,
                        theme: TDButtonTheme.defaultTheme,
                        size: TDButtonSize.small,
                      ),
                    if (feedback.status == 'processing') ...[
                      TDButton(
                        text: '标记已解决',
                        onTap: () =>
                            _updateFeedbackStatus(feedback.id, 'resolved'),
                        type: TDButtonType.text,
                        theme: TDButtonTheme.primary,
                        size: TDButtonSize.small,
                      ),
                      SizedBox(width: adaptive.Adaptive.w(8)),
                      TDButton(
                        text: '关闭',
                        onTap: () =>
                            _updateFeedbackStatus(feedback.id, 'closed'),
                        type: TDButtonType.text,
                        theme: TDButtonTheme.defaultTheme,
                        size: TDButtonSize.small,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // Tab 4: 数据统计
  // ═══════════════════════════════════════════════

  Widget _buildStatisticsTab() {
    final statsAsync = ref.watch(forumStatsProvider);

    return statsAsync.when(
      data: (stats) => Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: adaptive.Adaptive.w(16),
          mainAxisSpacing: adaptive.Adaptive.h(16),
          children: [
            _buildStatCard('总帖子数',
                stats['total_posts']?.toString() ?? '0', AppIcons.article),
            _buildStatCard('总评论数',
                stats['total_comments']?.toString() ?? '0', AppIcons.comment),
            _buildStatCard('注册用户',
                stats['total_users']?.toString() ?? '0', AppIcons.people),
            _buildStatCard('本周活跃',
                stats['active_users_week']?.toString() ?? '0',
                AppIcons.trendingUp),
          ],
        ),
      ),
      loading: () => const LoadingWidget(message: '加载统计数据...'),
      error: (error, stack) => ErrorDisplayWidget(
        error: '统计加载失败: $error',
        onRetry: () => ref.invalidate(forumStatsProvider),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: adaptive.Adaptive.sp(32),
                color: Theme.of(context).primaryColor),
            SizedBox(height: adaptive.Adaptive.h(8)),
            Text(value,
                style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(24),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor)),
            Text(title,
                style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(14),
                    color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 操作回调
  // ═══════════════════════════════════════════════

  int? _expandedFeedbackId;

  Future<void> _approvePost(int postId) async {
    final notifier = ref.read(moderatePostProvider.notifier);
    await notifier.approvePost(postId);
    final state = ref.read(moderatePostProvider);
    _handleActionResult(state, '帖子已通过审核', () {
      ref.invalidate(pendingPostsProvider);
      notifier.reset();
    });
  }

  Future<void> _rejectPost(int postId) async {
    _showRejectReasonDialog('拒绝帖子', (reason) async {
      final notifier = ref.read(moderatePostProvider.notifier);
      await notifier.rejectPost(postId, reason: reason);
      final state = ref.read(moderatePostProvider);
      _handleActionResult(state, '帖子已拒绝', () {
        ref.invalidate(pendingPostsProvider);
        notifier.reset();
      });
    });
  }

  Future<void> _approveComment(int commentId) async {
    final notifier = ref.read(moderateCommentProvider.notifier);
    await notifier.approveComment(commentId);
    final state = ref.read(moderateCommentProvider);
    _handleActionResult(state, '评论已通过审核', () {
      ref.invalidate(pendingCommentsProvider);
      notifier.reset();
    });
  }

  Future<void> _rejectComment(int commentId) async {
    _showRejectReasonDialog('拒绝评论', (reason) async {
      final notifier = ref.read(moderateCommentProvider.notifier);
      await notifier.rejectComment(commentId, reason: reason);
      final state = ref.read(moderateCommentProvider);
      _handleActionResult(state, '评论已拒绝', () {
        ref.invalidate(pendingCommentsProvider);
        notifier.reset();
      });
    });
  }

  Future<void> _resolveReport(int reportId) async {
    final notifier = ref.read(handleReportProvider.notifier);
    await notifier.resolveReport(reportId);
    final state = ref.read(handleReportProvider);
    _handleActionResult(state, '举报已确认违规', () {
      ref.invalidate(pendingReportsProvider);
      notifier.reset();
    });
  }

  Future<void> _dismissReport(int reportId) async {
    final notifier = ref.read(handleReportProvider.notifier);
    await notifier.dismissReport(reportId);
    final state = ref.read(handleReportProvider);
    _handleActionResult(state, '举报已驳回', () {
      ref.invalidate(pendingReportsProvider);
      notifier.reset();
    });
  }

  Future<void> _banUser(String userId) async {
    _showConfirmDialog(
      title: '封禁用户',
      content: '确定要封禁该用户吗？封禁后该用户将无法发帖和评论。',
      onConfirm: () async {
        final notifier = ref.read(banUserProvider.notifier);
        await notifier.banUser(userId);
        final state = ref.read(banUserProvider);
        _handleActionResult(state, '用户已封禁', () {
          ref.invalidate(adminUsersProvider);
          notifier.reset();
        });
      },
    );
  }

  Future<void> _unbanUser(String userId) async {
    _showConfirmDialog(
      title: '解封用户',
      content: '确定要解封该用户吗？',
      onConfirm: () async {
        final notifier = ref.read(banUserProvider.notifier);
        await notifier.unbanUser(userId);
        final state = ref.read(banUserProvider);
        _handleActionResult(state, '用户已解封', () {
          ref.invalidate(adminUsersProvider);
          notifier.reset();
        });
      },
    );
  }

  Future<void> _replyFeedback(int feedbackId) async {
    final reply = _feedbackReplyController.text.trim();
    if (reply.isEmpty) {
      _showSnackBar('请输入回复内容');
      return;
    }
    final notifier = ref.read(replyFeedbackProvider.notifier);
    await notifier.reply(feedbackId, reply);
    final state = ref.read(replyFeedbackProvider);
    _handleActionResult(state, '回复已发送', () {
      _feedbackReplyController.clear();
      ref.invalidate(adminFeedbackProvider);
      notifier.reset();
    });
  }

  Future<void> _updateFeedbackStatus(int feedbackId, String status) async {
    final notifier = ref.read(replyFeedbackProvider.notifier);
    await notifier.updateStatus(feedbackId, status);
    final state = ref.read(replyFeedbackProvider);
    _handleActionResult(
        state, '状态已更新为 ${_getStatusLabel(status)}', () {
      ref.invalidate(adminFeedbackProvider);
      notifier.reset();
    });
  }

  // ═══════════════════════════════════════════════
  // 工具方法
  // ═══════════════════════════════════════════════

  void _handleActionResult(
      AdminActionState state, String successMsg, VoidCallback onSuccess) {
    if (state.error != null) {
      _showSnackBar('操作失败: ${state.error}');
    } else if (state.success) {
      _showSnackBar(successMsg);
      onSuccess();
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRejectReasonDialog(
      String title, Function(String reason) onConfirm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入拒绝原因（可选）',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm(controller.text.trim());
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  String _getReportReasonLabel(String reason) {
    switch (reason) {
      case 'spam':
        return '垃圾广告';
      case 'harassment':
        return '骚扰言论';
      case 'inappropriate':
        return '不当内容';
      default:
        return '其他';
    }
  }

  String _getFeedbackTypeLabel(String type) {
    switch (type) {
      case 'bug':
        return 'Bug 反馈';
      case 'feature':
        return '功能建议';
      default:
        return '其他';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return '待处理';
      case 'processing':
        return '处理中';
      case 'resolved':
        return '已解决';
      case 'closed':
        return '已关闭';
      default:
        return status;
    }
  }

  Widget _buildStatusBadge(String status) {
    final (color, label) = switch (status) {
      'pending' => (AppColors.warning, '待处理'),
      'processing' => (AppColors.info, '处理中'),
      'resolved' => (AppColors.success, '已解决'),
      'closed' => (AppColors.textTertiary, '已关闭'),
      _ => (AppColors.onSurfaceVariant, status),
    };
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(8), vertical: adaptive.Adaptive.h(2)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: adaptive.Adaptive.sp(11), color: color)),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
