import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/ui/loading_widget.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/forum/providers/forum_providers.dart';

/// 我的帖子页
class ForumMyPostsPage extends ConsumerStatefulWidget {
  const ForumMyPostsPage({super.key});

  @override
  ConsumerState<ForumMyPostsPage> createState() => _ForumMyPostsPageState();
}

class _ForumMyPostsPageState extends ConsumerState<ForumMyPostsPage> {
  final ScrollController _scrollController = ScrollController();
  final List<ForumPost> _posts = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        _page++;
        _loadData();
      }
    }
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final service = ref.read(forumServiceProvider);
      final response = await service.getMyPosts(page: _page);
      setState(() {
        _posts.addAll(response.data);
        _hasMore = response.pagination.hasMore;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _page = 1;
      _posts.clear();
      _hasMore = true;
    });
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
appBar: AppNavBar(
  title: '我的帖子',
  backgroundColor: colors.surface,
  foregroundColor: colors.textPrimary,
  elevation: 1,
),
      body: _posts.isEmpty && _isLoading
          ? const Center(child: LoadingWidget())
          : _posts.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.article_outlined,
                    title: '暂无帖子',
                    description: '去发帖页面创建你的第一个帖子吧',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding:
                        EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(8)),
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final post = _posts[index];
                      return _buildPostCard(context, colors, post);
                    },
                  ),
                ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    AppColorsData colors,
    ForumPost post,
  ) {
    return BaseCard.outlined(
      padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
      margin: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(6),
      ),
      onTap: () {
        Navigator.pushNamed(context, '/forum/post/${post.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(15),
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: adaptive.Adaptive.h(6)),
          if (post.content.isNotEmpty)
            Text(
              post.content,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(13),
                color: colors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Row(
            children: [
              _buildStat(
                  Icons.remove_red_eye_outlined, '${post.viewCount}', colors),
              SizedBox(width: adaptive.Adaptive.w(12)),
              _buildStat(
                  Icons.chat_bubble_outline, '${post.replyCount}', colors),
              SizedBox(width: adaptive.Adaptive.w(12)),
              _buildStat(Icons.thumb_up_outlined, '${post.likeCount}', colors),
              SizedBox(width: adaptive.Adaptive.w(12)),
              _buildStat(
                  Icons.star_outline, '${post.favoriteCount}', colors),
              const Spacer(),
              if (post.tagName != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.Adaptive.w(8),
                    vertical: adaptive.Adaptive.h(3),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(adaptive.Adaptive.r(10)),
                  ),
                  child: Text(
                    post.tagName!,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(11),
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String count, AppColorsData colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: adaptive.Adaptive.sp(13), color: colors.textWeak),
        SizedBox(width: adaptive.Adaptive.w(3)),
        Text(
          count,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(11),
            color: colors.textWeak,
          ),
        ),
      ],
    );
  }
}
