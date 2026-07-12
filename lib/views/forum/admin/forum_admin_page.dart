import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../../providers/forum_admin_providers.dart';
import '../../../widgets/common/loading_widget.dart';
import '../../../widgets/common/error_widget.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

class ForumAdminPage extends ConsumerStatefulWidget {
  const ForumAdminPage({super.key});

  @override
  ConsumerState<ForumAdminPage> createState() => _ForumAdminPageState();
}

class _ForumAdminPageState extends ConsumerState<ForumAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 检查管理员权限
    final adminStatus = ref.watch(adminAuthProvider);

    return adminStatus.when(
      data: (isAdmin) {
        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('访问被拒绝')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.lock,
                    size: 64,
                    color: AppColors.onSurfaceVariant,
                  ),
                  SizedBox(height: 16),
                  Text('您没有管理员权限'),
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
      loading: () => const Scaffold(body: LoadingWidget(message: '验证管理员权限...')),
      error: (error, stack) => Scaffold(
        body: ErrorDisplayWidget(
          error: '权限验证失败: $error',
          onRetry: () {
            ref.invalidate(adminAuthProvider);
          },
        ),
      ),
    );
  }

  Widget _buildContentModerationTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '待审核帖子'),
              Tab(text: '待审核评论'),
            ],
            labelColor: AppColors.textPrimary,
            indicatorColor: AppColors.primary,
          ),
          Expanded(
            child: TabBarView(
              children: [_buildPendingPostsList(), _buildPendingCommentsList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPostsList() {
    final pendingPostsAsync = ref.watch(pendingPostsProvider);

    return pendingPostsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.checkCircle, size: 64, color: AppColors.success),
                SizedBox(height: 16),
                Text('所有帖子已审核完成'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(Adaptive.w(context, 16)),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              margin: EdgeInsets.only(bottom: Adaptive.h(context, 12)),
              child: Padding(
                padding: EdgeInsets.all(Adaptive.w(context, 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.title,
                            style: TextStyle(
                              fontSize: Adaptive.sp(context, 16),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            post.postType,
                            style: TextStyle(
                              fontSize: Adaptive.sp(context, 10),
                            ),
                          ),
                          backgroundColor: _getPostTypeColor(post.postType),
                        ),
                      ],
                    ),
                    SizedBox(height: Adaptive.h(context, 8)),
                    Text(
                      post.content,
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, 14),
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: Adaptive.h(context, 12)),
                    Row(
                      children: [
                        Text(
                          '作者: ${post.authorName}',
                          style: TextStyle(
                            fontSize: Adaptive.sp(context, 12),
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        // ✅ TDesign 规范：使用 TDButton 替换 TextButton/ElevatedButton
                        TDButton(
                          text: '拒绝',
                          onTap: () => _rejectPost(post.id),
                          type: TDButtonType.text,
                          theme: TDButtonTheme.defaultTheme,
                        ),
                        SizedBox(width: Adaptive.w(context, 8)),
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
          },
        );
      },
      loading: () => const LoadingWidget(message: '加载待审核帖子...'),
      error: (error, stack) => ErrorDisplayWidget(
        error: '加载失败: $error',
        onRetry: () => ref.invalidate(pendingPostsProvider),
      ),
    );
  }

  Widget _buildPendingCommentsList() {
    final pendingCommentsAsync = ref.watch(pendingCommentsProvider);

    return pendingCommentsAsync.when(
      data: (comments) {
        if (comments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.checkCircle, size: 64, color: AppColors.success),
                SizedBox(height: 16),
                Text('所有评论已审核完成'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(Adaptive.w(context, 16)),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return Card(
              margin: EdgeInsets.only(bottom: Adaptive.h(context, 12)),
              child: Padding(
                padding: EdgeInsets.all(Adaptive.w(context, 16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '帖子: ${comment.postTitle}',
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, 14),
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: Adaptive.h(context, 8)),
                    Text(
                      comment.content,
                      style: TextStyle(fontSize: Adaptive.sp(context, 14)),
                    ),
                    SizedBox(height: Adaptive.h(context, 12)),
                    Row(
                      children: [
                        Text(
                          '评论者: ${comment.userName}',
                          style: TextStyle(
                            fontSize: Adaptive.sp(context, 12),
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        // ✅ TDesign 规范：使用 TDButton 替换 TextButton/ElevatedButton
                        TDButton(
                          text: '拒绝',
                          onTap: () => _rejectComment(comment.id),
                          type: TDButtonType.text,
                          theme: TDButtonTheme.defaultTheme,
                        ),
                        SizedBox(width: Adaptive.w(context, 8)),
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
          },
        );
      },
      loading: () => const LoadingWidget(message: '加载待审核评论...'),
      error: (error, stack) => ErrorDisplayWidget(
        error: '加载失败: $error',
        onRetry: () => ref.invalidate(pendingCommentsProvider),
      ),
    );
  }

  Widget _buildUserManagementTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.people, size: 64, color: AppColors.onSurfaceVariant),
          SizedBox(height: 16),
          Text('用户管理功能开发中'),
        ],
      ),
    );
  }

  Widget _buildFeedbackManagementTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.feedback, size: 64, color: AppColors.onSurfaceVariant),
          SizedBox(height: 16),
          Text('反馈管理功能开发中'),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab() {
    final statsAsync = ref.watch(forumStatsProvider);

    return statsAsync.when(
      data: (stats) => Padding(
        padding: EdgeInsets.all(Adaptive.w(context, 16)),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: Adaptive.w(context, 16),
          mainAxisSpacing: Adaptive.h(context, 16),
          children: [
            _buildStatCard(
              '总帖子数',
              stats['total_posts']?.toString() ?? '0',
              AppIcons.article,
            ),
            _buildStatCard(
              '总评论数',
              stats['total_comments']?.toString() ?? '0',
              AppIcons.comment,
            ),
            _buildStatCard(
              '注册用户',
              stats['total_users']?.toString() ?? '0',
              AppIcons.people,
            ),
            _buildStatCard(
              '本周活跃',
              stats['active_users_week']?.toString() ?? '0',
              AppIcons.trendingUp,
            ),
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
        padding: EdgeInsets.all(Adaptive.w(context, 16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: Adaptive.sp(context, 32),
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: Adaptive.h(context, 8)),
            Text(
              value,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 24),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 14),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPostTypeColor(String postType) {
    switch (postType) {
      case 'resource':
        return AppColors.primary.withValues(alpha: 0.2);
      case 'discussion':
        return AppColors.success.withValues(alpha: 0.2);
      case 'feedback':
        return AppColors.warning.withValues(alpha: 0.2);
      case 'help':
        return AppColors.error.withValues(alpha: 0.2);
      default:
        return AppColors.onSurfaceVariant.withValues(alpha: 0.2);
    }
  }

  void _approvePost(int postId) {
    // TODO: 实现帖子通过审核
    print('通过帖子: $postId');
  }

  void _rejectPost(int postId) {
    // TODO: 实现帖子拒绝审核
    print('拒绝帖子: $postId');
  }

  void _approveComment(int commentId) {
    // TODO: 实现评论通过审核
    print('通过评论: $commentId');
  }

  void _rejectComment(int commentId) {
    // TODO: 实现评论拒绝审核
    print('拒绝评论: $commentId');
  }
}
