import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/ui/loading_widget.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/forum/providers/forum_providers.dart';

/// 我的收藏页 — V2.0
class ForumFavoritesPage extends ConsumerStatefulWidget {
  const ForumFavoritesPage({super.key});

  @override
  ConsumerState<ForumFavoritesPage> createState() =>
      _ForumFavoritesPageState();
}

class _ForumFavoritesPageState extends ConsumerState<ForumFavoritesPage> {
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
      final response = await service.getMyFavorites(page: _page);
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
      appBar: AppBar(
        title: const Text('我的收藏'),
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 1,
      ),
      body: _posts.isEmpty && _isLoading
          ? const Center(child: LoadingWidget())
          : _posts.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.star_outline,
                    title: '暂无收藏',
                    description: '浏览帖子时可以点击收藏',
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
                      return _buildFavoriteCard(context, colors, post, index);
                    },
                  ),
                ),
    );
  }

  Widget _buildFavoriteCard(
    BuildContext context,
    AppColorsData colors,
    ForumPost post,
    int index,
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
                    Icon(Icons.thumb_up_outlined,
                        size: adaptive.Adaptive.sp(12),
                        color: colors.textWeak),
                    SizedBox(width: adaptive.Adaptive.w(2)),
                    Text(
                      '${post.likeCount}',
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
          GestureDetector(
            onTap: () => _unfavorite(post, index),
            child: const Icon(Icons.star, color: Colors.amber, size: 22),
          ),
        ],
      ),
    );
  }

  Future<void> _unfavorite(ForumPost post, int index) async {
    try {
      final service = ref.read(forumServiceProvider);
      await service.toggleFavorite(post.id);
      setState(() => _posts.removeAt(index));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取消收藏失败: $e')));
      }
    }
  }
}
