import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/ui/loading_widget.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/forum/providers/forum_providers.dart';

/// 我的点赞页
class ForumMyLikesPage extends ConsumerStatefulWidget {
  const ForumMyLikesPage({super.key});

  @override
  ConsumerState<ForumMyLikesPage> createState() => _ForumMyLikesPageState();
}

class _ForumMyLikesPageState extends ConsumerState<ForumMyLikesPage> {
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
      final response = await service.getMyLikes(page: _page);
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
  title: '我的点赞',
  backgroundColor: colors.surface,
  foregroundColor: colors.textPrimary,
  elevation: 1,
),
      body: _posts.isEmpty && _isLoading
          ? const Center(child: LoadingWidget())
          : _posts.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.thumb_up_outlined,
                    title: '暂无点赞',
                    description: '浏览帖子时可以点赞喜欢的内容',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                        vertical: adaptive.Adaptive.h(8)),
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
                      return _buildLikeCard(context, colors, post);
                    },
                  ),
                ),
    );
  }

  Widget _buildLikeCard(
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
      child: Row(
        children: [
          Expanded(
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
                SizedBox(height: adaptive.Adaptive.h(4)),
                Row(
                  children: [
                    Avatar(
                      imageUrl: post.authorAvatar,
                      text: post.authorName,
                      size: AvatarSize.xs,
                    ),
                    SizedBox(width: adaptive.Adaptive.w(4)),
                    Text(
                      post.authorName,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(11),
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    Icon(Icons.chat_bubble_outline,
                        size: adaptive.Adaptive.sp(12),
                        color: colors.textWeak),
                    SizedBox(width: adaptive.Adaptive.w(2)),
                    Text(
                      '${post.replyCount}',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(11),
                        color: colors.textWeak,
                      ),
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    Icon(Icons.favorite_outline,
                        size: adaptive.Adaptive.sp(12),
                        color: colors.textWeak),
                    SizedBox(width: adaptive.Adaptive.w(2)),
                    Text(
                      '${post.favoriteCount}',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(11),
                        color: colors.textWeak,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(8)),
          const Icon(Icons.thumb_up, color: AppColors.primary, size: 22),
        ],
      ),
    );
  }
}
