import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/ui/loading_widget.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/models/forum/forum_tag.dart';
import 'package:vidlang/views/forum/providers/forum_providers.dart';
import 'package:vidlang/services/forum/forum_service.dart';
import 'package:vidlang/views/forum/widgets/forum_post_card.dart';
import 'package:vidlang/views/forum/forum_post_detail_page.dart';
import 'package:vidlang/views/forum/forum_create_post_page.dart';
import 'package:vidlang/views/forum/forum_search_page.dart';
import 'package:vidlang/views/forum/forum_notifications_page.dart';
import 'package:vidlang/views/forum/forum_my_page.dart';
import 'package:vidlang/views/forum/widgets/forum_tag_manage_sheet.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 论坛首页 — V2.0 标签驱动（今日头条风格：关注 + 标签 Tab）
class ForumHomePage extends ConsumerStatefulWidget {
  /// 可选：指定初始标签 ID（0 为关注）
  final int? initialTagId;

  const ForumHomePage({
    super.key,
    this.initialTagId,
  });

  @override
  ConsumerState<ForumHomePage> createState() => _ForumHomePageState();
}

class _ForumHomePageState extends ConsumerState<ForumHomePage> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;
  final List<ForumPost> _posts = [];
  int? _activeTagId;
  bool _isFollowedTab = false;

  ForumPostsParams get _params => ForumPostsParams(
        tagId: _isFollowedTab ? null : _activeTagId,
        followed: _isFollowedTab,
        page: _currentPage,
      );

  @override
  void initState() {
    super.initState();
    if (widget.initialTagId != null) {
      _activeTagId = widget.initialTagId;
      _isFollowedTab = widget.initialTagId == 0;
    } else {
      _isFollowedTab = true;
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(forumPostsProvider(_params));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !ref.read(forumPostsProvider(_params)).isLoading) {
        setState(() => _currentPage++);
      }
    }
  }

  void _switchTab({int? tagId, bool isFollowed = false}) {
    if (isFollowed && _isFollowedTab) return;
    if (!isFollowed && _activeTagId == tagId) return;
    setState(() {
      _isFollowedTab = isFollowed;
      _activeTagId = tagId;
      _currentPage = 1;
      _posts.clear();
      _hasMore = true;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _currentPage = 1;
      _posts.clear();
      _hasMore = true;
    });
    ref.invalidate(forumPostsProvider(_params));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tagsAsync = ref.watch(forumTagsProvider);
    final postsAsync = ref.watch(forumPostsProvider(_params));

    ref.listen(forumPostsProvider(_params), (_, next) {
      next.whenData((response) {
        if (_currentPage == 1) _posts.clear();
        _posts.addAll(response.data);
        _hasMore = response.pagination.hasMore;
      });
    });

    // 首次加载
    if (tagsAsync.isLoading && postsAsync.isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: _buildAppBar(context, colors),
        body: const Center(child: LoadingWidget()),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: _buildAppBar(context, colors),
      body: Column(
        children: [
          _buildTagTabs(context, colors, tagsAsync),
          Expanded(
            child: _buildPostList(context, colors, postsAsync),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreatePost(context),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        child: const Icon(Icons.edit),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppColorsData colors,
  ) {
    final isPad = adaptive.isIPad();
    final iconSize = adaptive.Adaptive.icon(isPad ? 26 : 22);
    final titleSize = adaptive.Adaptive.sp(isPad ? 20 : 17);
    final btnPadding = EdgeInsets.all(adaptive.Adaptive.w(isPad ? 10 : 6));

    return AppBar(
      title: Text(
        '学习论坛',
        style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600),
      ),
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      elevation: 1,
      titleSpacing: adaptive.Adaptive.w(isPad ? 12 : 4),
      actions: [
        // 搜索按钮
        _buildAppBarAction(
          icon: Icons.search,
          iconSize: iconSize,
          padding: btnPadding,
          onTap: () => _navigateToSearch(context),
        ),
        // 通知按钮（带未读角标）
        Stack(
          children: [
            _buildAppBarAction(
              icon: Icons.notifications_outlined,
              iconSize: iconSize,
              padding: btnPadding,
              onTap: () => _navigateToNotifications(context),
            ),
            const _UnreadBadge(),
          ],
        ),
        // 个人中心按钮
        _buildAppBarAction(
          icon: Icons.person_outline,
          iconSize: iconSize,
          padding: btnPadding,
          onTap: () => _navigateToMyPage(context),
        ),
      ],
    );
  }

  /// 自适应 AppBar 操作按钮 — 统一尺寸和点击区域
  Widget _buildAppBarAction({
    required IconData icon,
    required double iconSize,
    required EdgeInsets padding,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, size: iconSize),
      padding: padding,
      constraints: BoxConstraints(
        minWidth: adaptive.Adaptive.w(44),
        minHeight: adaptive.Adaptive.h(44),
      ),
      onPressed: onTap,
    );
  }

  Widget _buildTagTabs(
    BuildContext context,
    AppColorsData colors,
    AsyncValue<List<ForumTag>> tagsAsync,
  ) {
    return tagsAsync.when(
      loading: () => const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (tags) {
        return Container(
          height: adaptive.Adaptive.h(44),
          color: colors.surface,
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(
                      left: adaptive.Adaptive.w(12)),
                  itemCount: tags.length + 1,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: adaptive.Adaptive.w(4)),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // 第一个 tab 是「全部」
                      return _buildTabChip(
                        context, colors, '全部',
                        isActive: _isFollowedTab,
                        onTap: () => _switchTab(isFollowed: true),
                      );
                    }
                    final tag = tags[index - 1];
                    return _buildTabChip(
                      context, colors, tag.name,
                      isActive: !_isFollowedTab && _activeTagId == tag.id,
                      onTap: () => _switchTab(tagId: tag.id),
                    );
                  },
                ),
              ),
              // 标签管理按钮（固定在标签栏右侧，始终可见）
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: colors.border.withAlpha(80),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showTagManageSheet(context),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: adaptive.Adaptive.w(10),
                      ),
                      child: Icon(
                        Icons.more_horiz,
                        size: adaptive.Adaptive.sp(22),
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabChip(
    BuildContext context,
    AppColorsData colors,
    String label, {
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(12),
          vertical: adaptive.Adaptive.h(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(14),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? colors.primary : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPostList(
    BuildContext context,
    AppColorsData colors,
    AsyncValue<PaginatedResponse<ForumPost>> postsAsync,
  ) {
    if (_posts.isEmpty && postsAsync.isLoading) {
      return const Center(child: LoadingWidget());
    }

    if (_posts.isEmpty && postsAsync.hasError) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline,
          title: '加载失败',
          description: postsAsync.error.toString(),
          actionLabel: '重试',
          onAction: _refresh,
        ),
      );
    }

    if (_posts.isEmpty) {
      return EmptyState(
        icon: Icons.forum_outlined,
        title: '暂无帖子',
        description: _isFollowedTab
            ? '关注一些用户或标签，这里会显示他们的最新动态'
            : '快来发布第一个帖子吧',
        actionLabel: '发布帖子',
        onAction: () => _navigateToCreatePost(context),
      );
    }

    final pinned = _posts.where((p) => p.isPinned).toList();
    final normal = _posts.where((p) => !p.isPinned).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(
          top: adaptive.Adaptive.h(8),
          bottom: adaptive.Adaptive.h(80),
        ),
        itemCount: pinned.length + normal.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < pinned.length) {
            return ForumPostCard(
              post: pinned[index],
              onTap: () => _navigateToDetail(context, pinned[index].id),
            );
          }
          final normalIndex = index - pinned.length;
          if (normalIndex >= normal.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return ForumPostCard(
            post: normal[normalIndex],
            onTap: () => _navigateToDetail(context, normal[normalIndex].id),
          );
        },
      ),
    );
  }

  void _navigateToDetail(BuildContext context, int postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForumPostDetailPage(postId: postId),
      ),
    );
  }

  void _navigateToCreatePost(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForumCreatePostPage()),
    );
  }

  void _navigateToSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForumSearchPage()),
    );
  }

  void _navigateToNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForumNotificationsPage()),
    );
  }

  void _navigateToMyPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForumMyPage()),
    );
  }

  void _showTagManageSheet(BuildContext context) {
    ForumTagManageSheet.show(context).then((_) {
      // 关闭后刷新标签和帖子列表，使关注变更生效
      ref.invalidate(forumTagsProvider);
      ref.invalidate(forumPostsProvider(_params));
    });
  }
}

class _UnreadBadge extends ConsumerWidget {
  const _UnreadBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(forumUnreadCountProvider);
    return unreadAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (count) {
        if (count <= 0) return const SizedBox.shrink();
        return Positioned(
          right: adaptive.Adaptive.w(4),
          top: adaptive.Adaptive.h(4),
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(5)),
            constraints:
                BoxConstraints(minWidth: adaptive.Adaptive.w(16)),
            height: adaptive.Adaptive.h(16),
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(10),
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
