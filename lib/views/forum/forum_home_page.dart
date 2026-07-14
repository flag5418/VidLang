import 'package:flutter/material.dart';import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../models/forum/forum_post.dart';
import '../../providers/forum_providers.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import 'forum_create_post_page.dart';
import 'package:vidlang/theme/theme.dart';


class ForumHomePage extends ConsumerStatefulWidget {
  const ForumHomePage({super.key});

  @override
  ConsumerState<ForumHomePage> createState() => _ForumHomePageState();
}

class _ForumHomePageState extends ConsumerState<ForumHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // ignore: unused_field
final String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('学习论坛'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(adaptive.Adaptive.h(context, 120)),
          child: Container(
            color: AppColors.surface,
            child: Column(children: [_buildSearchBar(), _buildCategoryTabs()]),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildQuickActions(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostList('all'),
                _buildPostList('resources'),
                _buildPostList('discussion'),
                _buildPostList('feedback'),
                _buildPostList('help'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreatePost(),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(AppIcons.add, color: AppColors.surface),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索帖子、用户或标签...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 8)),
          ),
          filled: true,
          fillColor: AppColors.lightBackground,
          suffixIcon: IconButton(
            icon: const Icon(AppIcons.clear),
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
            },
          ),
        ),
        onSubmitted: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final tabs = ['全部', '资源分享', '学习讨论', '反馈建议', '学习互助'];

    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: Theme.of(context).primaryColor,
      unselectedLabelColor: AppColors.onSurfaceVariant,
      indicatorColor: Theme.of(context).primaryColor,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(
        fontSize: adaptive.Adaptive.sp(context, 14),
        fontWeight: FontWeight.w500,
      ),
      tabs: tabs.map((tab) => Tab(text: tab)).toList(),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: adaptive.Adaptive.h(context, 60),
      margin: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(context, 16),
        vertical: adaptive.Adaptive.h(context, 8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionButton(
              icon: AppIcons.movie,
              label: '分享视频',
              onTap: () => _navigateToCreatePost('resource', 'video'),
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(context, 8)),
          Expanded(
            child: _buildQuickActionButton(
              icon: AppIcons.audioFile,
              label: '分享音频',
              onTap: () => _navigateToCreatePost('resource', 'audio'),
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(context, 8)),
          Expanded(
            child: _buildQuickActionButton(
              icon: AppIcons.chat,
              label: '学习讨论',
              onTap: () => _navigateToCreatePost('discussion'),
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(context, 8)),
          Expanded(
            child: _buildQuickActionButton(
              icon: AppIcons.help,
              label: '求助问答',
              onTap: () => _navigateToCreatePost('help'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(context, 8)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 8)),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: adaptive.Adaptive.sp(context, 20),
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 4)),
            Text(
              label,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 10),
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList(String category) {
    final postsAsync = ref.watch(
      forumPostsProvider(
        ForumPostsParams(
          category: category == 'all' ? null : category,
          search: _searchQuery.isEmpty ? null : _searchQuery,
        ),
      ),
    );

    return postsAsync.when(
      data: (postsResponse) {
        final posts = postsResponse.data;
        if (posts.isEmpty) {
          return _buildEmptyState(category);
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(
              forumPostsProvider(
                ForumPostsParams(
                  category: category == 'all' ? null : category,
                  search: _searchQuery.isEmpty ? null : _searchQuery,
                ),
              ),
            );
          },
          child: ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(context, 16),
              vertical: adaptive.Adaptive.h(context, 8),
            ),
            itemCount: posts.length,
            separatorBuilder: (context, index) =>
                SizedBox(height: adaptive.Adaptive.h(context, 8)),
            itemBuilder: (context, index) {
              return _buildPostCard(posts[index]);
            },
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, stack) => ErrorDisplayWidget(
        error: error.toString(),
        onRetry: () {
          ref.invalidate(
            forumPostsProvider(
              ForumPostsParams(
                category: category == 'all' ? null : category,
                search: _searchQuery.isEmpty ? null : _searchQuery,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String category) {
    String message;
    IconData icon;

    switch (category) {
      case 'resources':
        message = '暂无资源分享';
        icon = AppIcons.movie;
        break;
      case 'discussion':
        message = '暂无学习讨论';
        icon = AppIcons.chat;
        break;
      case 'feedback':
        message = '暂无反馈建议';
        icon = AppIcons.feedback;
        break;
      case 'help':
        message = '暂无求助内容';
        icon = AppIcons.help;
        break;
      default:
        message = '暂无帖子内容';
        icon = AppIcons.forum;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: adaptive.Adaptive.sp(context, 80),
            color: AppColors.onSurfaceVariant,
          ),
          SizedBox(height: adaptive.Adaptive.h(context, 16)),
          Text(
            message,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(context, 16),
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(context, 24)),
          // ✅ TDesign 规范：使用 TDButton 替换 ElevatedButton
          TDButton(
            text: '发布第一个帖子',
            onTap: () => _navigateToCreatePost(category),
            type: TDButtonType.fill,
            theme: TDButtonTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(ForumPost post) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: adaptive.Adaptive.w(context, 8),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToPostDetail(post),
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 12)),
          child: Padding(
            padding: EdgeInsets.all(adaptive.Adaptive.w(context, 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPostHeader(post),
                SizedBox(height: adaptive.Adaptive.h(context, 12)),
                _buildPostContent(post),
                if (post.resourceType != null) ...[
                  SizedBox(height: adaptive.Adaptive.h(context, 12)),
                  _buildResourceInfo(post),
                ],
                SizedBox(height: adaptive.Adaptive.h(context, 12)),
                _buildPostFooter(post),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostHeader(ForumPost post) {
    return Row(
      children: [
        CircleAvatar(
          radius: adaptive.Adaptive.r(context, 16),
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            post.authorName?.substring(0, 1) ?? 'U',
            style: TextStyle(
              color: AppColors.surface,
              fontSize: adaptive.Adaptive.sp(context, 14),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: adaptive.Adaptive.w(context, 8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    post.authorName ?? '未知用户',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(context, 14),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (post.isPinned) ...[
                    SizedBox(width: adaptive.Adaptive.w(context, 8)),
                    Icon(
                      AppIcons.pushPin,
                      size: adaptive.Adaptive.sp(context, 14),
                      color: AppColors.warning,
                    ),
                  ],
                  if (post.isFeatured) ...[
                    SizedBox(width: adaptive.Adaptive.w(context, 4)),
                    Icon(
                      AppIcons.star,
                      size: adaptive.Adaptive.sp(context, 14),
                      color: AppColors.warning,
                    ),
                  ],
                ],
              ),
              Text(
                _formatTime(post.createdAt),
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(context, 12),
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _buildCategoryTag(post),
      ],
    );
  }

  Widget _buildCategoryTag(ForumPost post) {
    Color tagColor;
    String tagText;

    switch (post.postType) {
      case 'resource':
        tagColor = Theme.of(context).primaryColor;
        tagText = '资源';
        break;
      case 'discussion':
        tagColor = AppColors.success;
        tagText = '讨论';
        break;
      case 'feedback':
        tagColor = AppColors.warning;
        tagText = '反馈';
        break;
      case 'help':
        tagColor = AppColors.error;
        tagText = '求助';
        break;
      default:
        tagColor = AppColors.onSurfaceVariant;
        tagText = '其他';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(context, 8),
        vertical: adaptive.Adaptive.h(context, 2),
      ),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 4)),
      ),
      child: Text(
        tagText,
        style: TextStyle(
          fontSize: adaptive.Adaptive.sp(context, 10),
          color: tagColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPostContent(ForumPost post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.title,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(context, 16),
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: adaptive.Adaptive.h(context, 8)),
        Text(
          post.summary ?? post.content,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(context, 14),
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (post.tags.isNotEmpty) ...[
          SizedBox(height: adaptive.Adaptive.h(context, 8)),
          Wrap(
            spacing: adaptive.Adaptive.w(context, 6),
            runSpacing: adaptive.Adaptive.h(context, 4),
            children: post.tags.take(3).map((tag) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: adaptive.Adaptive.w(context, 6),
                  vertical: adaptive.Adaptive.h(context, 2),
                ),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 3)),
                ),
                child: Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(context, 10),
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildResourceInfo(ForumPost post) {
    IconData resourceIcon;
    String resourceLabel;

    switch (post.resourceType) {
      case 'video':
        resourceIcon = AppIcons.movie;
        resourceLabel = '视频资源';
        break;
      case 'audio':
        resourceIcon = AppIcons.audioFile;
        resourceLabel = '音频资源';
        break;
      case 'article':
        resourceIcon = AppIcons.article;
        resourceLabel = '文章资源';
        break;
      default:
        resourceIcon = AppIcons.link;
        resourceLabel = '其他资源';
    }

    return Container(
      padding: EdgeInsets.all(adaptive.Adaptive.w(context, 12)),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 8)),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            resourceIcon,
            size: adaptive.Adaptive.sp(context, 16),
            color: Theme.of(context).primaryColor,
          ),
          SizedBox(width: adaptive.Adaptive.w(context, 8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resourceLabel,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(context, 12),
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                if (post.resourceDescription != null)
                  Text(
                    post.resourceDescription!,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(context, 11),
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostFooter(ForumPost post) {
    return Row(
      children: [
        _buildFooterButton(
          icon: AppIcons.visibility,
          count: post.viewCount,
          label: '浏览',
          onTap: null,
        ),
        SizedBox(width: adaptive.Adaptive.w(context, 16)),
        _buildFooterButton(
          icon: AppIcons.favorite,
          count: post.likeCount,
          label: '点赞',
          onTap: () => _handleLike(post),
          isActive: post.isLikedByCurrentUser,
        ),
        SizedBox(width: adaptive.Adaptive.w(context, 16)),
        _buildFooterButton(
          icon: AppIcons.chat,
          count: post.commentCount,
          label: '评论',
          onTap: () => _navigateToPostDetail(post, focusComment: true),
        ),
        const Spacer(),
        _buildFooterButton(
          icon: AppIcons.bookmarkFill,
          count: 0,
          label: '收藏',
          onTap: () => _handleFavorite(post),
          isActive: post.isFavoritedByCurrentUser,
          showCount: false,
        ),
      ],
    );
  }

  Widget _buildFooterButton({
    required IconData icon,
    required int count,
    required String label,
    VoidCallback? onTap,
    bool isActive = false,
    bool showCount = true,
  }) {
    final color = isActive
        ? Theme.of(context).primaryColor
        : AppColors.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: adaptive.Adaptive.sp(context, 16), color: color),
          if (showCount) ...[
            SizedBox(width: adaptive.Adaptive.w(context, 4)),
            Text(
              count > 0 ? count.toString() : label,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 12),
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToCreatePost([String? postType, String? resourceType]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForumCreatePostPage(
          initialPostType: postType,
          initialResourceType: resourceType,
        ),
      ),
    );
  }

  void _navigateToPostDetail(ForumPost post, {bool focusComment = false}) {
    // TODO: 导航到帖子详情页面
    print('导航到帖子详情: ${post.id}, 聚焦评论: $focusComment');
  }

  void _handleLike(ForumPost post) {
    // TODO: 处理点赞操作
    ref.read(forumServiceProvider).toggleLike(post.id);
  }

  void _handleFavorite(ForumPost post) {
    // TODO: 处理收藏操作
    ref.read(forumServiceProvider).toggleFavorite(post.id);
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}
