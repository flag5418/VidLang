import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/ui/loading_widget.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/models/forum/forum_reply.dart';
import 'package:vidlang/services/forum/forum_service.dart';
import 'package:vidlang/views/forum/providers/forum_providers.dart';
import 'package:vidlang/views/forum/widgets/forum_reply_tile.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 帖子详情页 — V2.0: 收藏/关注/单层回复
class ForumPostDetailPage extends ConsumerStatefulWidget {
  final int postId;

  const ForumPostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<ForumPostDetailPage> createState() =>
      _ForumPostDetailPageState();
}

class _ForumPostDetailPageState extends ConsumerState<ForumPostDetailPage> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _replyPage = 1;
  bool _hasMoreReplies = true;
  bool _isSubmittingReply = false;
  final List<ForumReply> _replies = [];

  ({int postId, int page}) get _replyParams =>
      (postId: widget.postId, page: _replyPage);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMoreReplies &&
          !ref.read(forumRepliesProvider(_replyParams)).isLoading) {
        setState(() => _replyPage++);
      }
    }
  }

  Future<void> _refreshReplies() async {
    setState(() {
      _replyPage = 1;
      _replies.clear();
      _hasMoreReplies = true;
    });
    ref.invalidate(forumRepliesProvider(_replyParams));
    await ref
        .read(forumRepliesProvider(_replyParams).future)
        .catchError((_) => const PaginatedResponse<ForumReply>(
            data: [], pagination: PaginationInfo()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final postAsync = ref.watch(forumPostDetailProvider(widget.postId));
    final repliesAsync = ref.watch(forumRepliesProvider(_replyParams));

    ref.listen(forumRepliesProvider(_replyParams), (_, next) {
      next.whenData((response) {
        if (_replyPage == 1) _replies.clear();
        _replies.addAll(response.data);
        _hasMoreReplies = response.pagination.hasMore;
      });
    });

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppNavBar(
        title: '帖子详情',
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => _showReportDialog(context),
          ),
        ],
      ),
      body: postAsync.when(
        loading: () => const Center(child: LoadingWidget()),
        error: (e, _) => Center(
          child: EmptyState(
            icon: Icons.error_outline,
            title: '加载失败',
            description: e.toString(),
            actionLabel: '重试',
            onAction: () =>
                ref.invalidate(forumPostDetailProvider(widget.postId)),
          ),
        ),
        data: (post) =>
            _buildContent(context, colors, post, repliesAsync),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppColorsData colors,
    ForumPost post,
    AsyncValue<PaginatedResponse<ForumReply>> repliesAsync,
  ) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildPostBody(context, colors, post)),
              SliverToBoxAdapter(
                child: Container(
                  height: adaptive.Adaptive.h(8),
                  color: colors.surfaceContainer,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.Adaptive.w(16),
                    vertical: adaptive.Adaptive.h(12),
                  ),
                  child: Text(
                    '回复 (${post.replyCount})',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(15),
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (_replies.isEmpty && repliesAsync.isLoading)
                const SliverFillRemaining(
                  child: Center(child: LoadingWidget()),
                )
              else if (_replies.isEmpty)
                SliverFillRemaining(
                  child: EmptyState.compact(
                    icon: Icons.chat_outlined,
                    title: '暂无回复',
                    description: '快来发表第一条回复吧',
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _replies.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final reply = _replies[index];
                      final currentUserId = _getCurrentUserId();
                      return ForumReplyTile(
                        reply: reply,
                        isOwner: reply.authorId == currentUserId,
                        onReplyTap: () {
                          FocusScope.of(context).requestFocus();
                        },
                        onLikeTap: () => _toggleReplyLike(reply),
                        onDeleteTap: () => _deleteReply(reply),
                        onReportTap: () =>
                            _showReplyReportDialog(context, reply),
                      );
                    },
                    childCount: _replies.length + (_hasMoreReplies ? 1 : 0),
                  ),
                ),
            ],
          ),
        ),
        _buildReplyBar(context, colors, post),
      ],
    );
  }

  Widget _buildPostBody(
    BuildContext context,
    AppColorsData colors,
    ForumPost post,
  ) {
    return Padding(
      padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(20),
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: adaptive.Adaptive.h(10)),
          Row(
            children: [
              Avatar(
                imageUrl: post.authorAvatar,
                text: post.authorName,
                size: AvatarSize.sm,
              ),
              SizedBox(width: adaptive.Adaptive.w(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(14),
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      _formatTime(post.createdAt),
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(12),
                        color: colors.textWeak,
                      ),
                    ),
                  ],
                ),
              ),
              // V2.0: 关注作者按钮
              GestureDetector(
                onTap: () => _toggleFollow(post),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.Adaptive.w(12),
                    vertical: adaptive.Adaptive.h(5),
                  ),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(adaptive.Adaptive.r(16)),
                    border: Border.all(
                      color: post.authorIsFollowed
                          ? colors.primary
                          : colors.border,
                    ),
                    color: post.authorIsFollowed
                        ? colors.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                  ),
                  child: Text(
                    post.authorIsFollowed ? '已关注' : '+ 关注',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(12),
                      color: post.authorIsFollowed
                          ? colors.primary
                          : colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: adaptive.Adaptive.w(8)),
              _buildLikeButton(context, colors, post),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(14)),
          MarkdownBody(
            data: post.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                fontSize: adaptive.Adaptive.sp(15),
                color: colors.textPrimary,
                height: 1.7,
              ),
              h1: TextStyle(
                fontSize: adaptive.Adaptive.sp(20),
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              h2: TextStyle(
                fontSize: adaptive.Adaptive.sp(18),
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              h3: TextStyle(
                fontSize: adaptive.Adaptive.sp(16),
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              code: TextStyle(
                fontSize: adaptive.Adaptive.sp(13),
                backgroundColor: colors.surfaceContainer,
                color: colors.textPrimary,
              ),
              codeblockDecoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
              ),
              blockquote: TextStyle(
                fontSize: adaptive.Adaptive.sp(14),
                color: colors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
              a: TextStyle(color: colors.primary),
              listBullet: TextStyle(color: colors.textSecondary),
            ),
          ),
          if (post.imageUrls.isNotEmpty) ...[
            SizedBox(height: adaptive.Adaptive.h(12)),
            _buildImageGrid(context, post.imageUrls),
          ],
          SizedBox(height: adaptive.Adaptive.h(12)),
          // V2.0: 底部操作栏 — 收藏 + 分享
          Row(
            children: [
              _buildFavoriteButton(context, colors, post),
              const Spacer(),
              Text(
                '${post.viewCount} 次浏览',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(12),
                  color: colors.textWeak,
                ),
              ),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(16)),
          Divider(color: colors.border, height: 1),
        ],
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context, List<String> urls) {
    final displayUrls = urls.take(9).toList();
    if (displayUrls.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = displayUrls.length == 1
          ? 1
          : displayUrls.length <= 4
              ? 2
              : 3;
      final maxWidth = constraints.maxWidth;
      const spacing = 4.0;
      final imageSize =
          (maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: displayUrls.map((url) {
          return GestureDetector(
            onTap: () => _showImageViewer(context, urls, urls.indexOf(url)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
              child: Image.network(
                url,
                width: imageSize,
                height: crossAxisCount == 1 ? imageSize * 0.6 : imageSize,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: imageSize,
                  height: imageSize,
                  color: context.colors.surfaceContainer,
                  child: Icon(
                    Icons.broken_image,
                    color: context.colors.textWeak,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  // V2.0: 收藏按钮
  Widget _buildFavoriteButton(
    BuildContext context,
    AppColorsData colors,
    ForumPost post,
  ) {
    return GestureDetector(
      onTap: () => _toggleFavorite(post),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              post.isFavorited ? Icons.star : Icons.star_outline,
              size: adaptive.Adaptive.sp(20),
              color: post.isFavorited ? Colors.amber : colors.textSecondary,
            ),
            SizedBox(width: adaptive.Adaptive.w(4)),
            Text(
              post.isFavorited ? '已收藏' : '收藏',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(13),
                color: post.isFavorited ? Colors.amber : colors.textSecondary,
              ),
            ),
            if (post.favoriteCount > 0) ...[
              SizedBox(width: adaptive.Adaptive.w(2)),
              Text(
                post.favoriteCount.toString(),
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(12),
                  color: colors.textWeak,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLikeButton(
    BuildContext context,
    AppColorsData colors,
    ForumPost post,
  ) {
    return GestureDetector(
      onTap: () => _togglePostLike(post),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(14),
          vertical: adaptive.Adaptive.h(6),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(20)),
          border: Border.all(
            color:
                post.isLikedByCurrentUser ? colors.primary : colors.border,
          ),
          color: post.isLikedByCurrentUser
              ? colors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              post.isLikedByCurrentUser
                  ? Icons.thumb_up
                  : Icons.thumb_up_outlined,
              size: adaptive.Adaptive.sp(16),
              color: post.isLikedByCurrentUser
                  ? colors.primary
                  : colors.textSecondary,
            ),
            SizedBox(width: adaptive.Adaptive.w(4)),
            Text(
              post.likeCount.toString(),
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(13),
                color: post.isLikedByCurrentUser
                    ? colors.primary
                    : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBar(
    BuildContext context,
    AppColorsData colors,
    ForumPost post,
  ) {
    return Container(
      padding: EdgeInsets.only(
        left: adaptive.Adaptive.w(12),
        right: adaptive.Adaptive.w(8),
        bottom: MediaQuery.of(context).padding.bottom,
        top: adaptive.Adaptive.h(8),
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: adaptive.Adaptive.h(100)),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(20)),
              ),
              padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(12)),
              child: TextField(
                controller: _replyController,
                maxLines: 4,
                minLines: 1,
                enabled: !_isSubmittingReply,
                style: TextStyle(fontSize: adaptive.Adaptive.sp(14)),
                decoration: InputDecoration(
                  hintText: '写下你的回复...',
                  hintStyle: TextStyle(
                    color: colors.textWeak,
                    fontSize: adaptive.Adaptive.sp(14),
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(10)),
                ),
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(8)),
          IconButton(
            icon: _isSubmittingReply
                ? SizedBox(
                    width: adaptive.Adaptive.sp(20),
                    height: adaptive.Adaptive.sp(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  )
                : Icon(Icons.send, color: colors.primary),
            onPressed:
                _isSubmittingReply ? null : () => _submitReply(context, post),
          ),
        ],
      ),
    );
  }

  // ─── 操作 ──────────────────────────────────

  Future<void> _toggleFavorite(ForumPost post) async {
    try {
      final service = ref.read(forumServiceProvider);
      await service.toggleFavorite(post.id);
      ref.invalidate(forumPostDetailProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _toggleFollow(ForumPost post) async {
    try {
      final service = ref.read(forumServiceProvider);
      await service.toggleFollow(post.authorId);
      ref.invalidate(forumPostDetailProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  Future<void> _togglePostLike(ForumPost post) async {
    try {
      final service = ref.read(forumServiceProvider);
      await service.toggleLike('post', post.id);
      ref.invalidate(forumPostDetailProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('点赞失败: $e')));
      }
    }
  }

  Future<void> _toggleReplyLike(ForumReply reply) async {
    try {
      final service = ref.read(forumServiceProvider);
      await service.toggleLike('reply', reply.id);
      _replyPage = 1;
      ref.invalidate(forumRepliesProvider(_replyParams));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('点赞失败: $e')));
      }
    }
  }

  Future<void> _deleteReply(ForumReply reply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('删除回复', style: TextStyle(fontSize: adaptive.Adaptive.sp(17))),
        content: const Text('确定删除此回复吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final service = ref.read(forumServiceProvider);
      await service.deleteReply(reply.id);
      _replyPage = 1;
      _replies.clear();
      ref.invalidate(forumRepliesProvider(_replyParams));
      ref.invalidate(forumPostDetailProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  Future<void> _submitReply(BuildContext context, ForumPost post) async {
    final content = _replyController.text.trim();
    if (content.isEmpty || _isSubmittingReply) return;

    setState(() => _isSubmittingReply = true);
    try {
      final service = ref.read(forumServiceProvider);
      // V2.0: 单层回复，无 parentId
      await service.createReply(
        postId: post.id,
        content: content,
      );
      _replyController.clear();
      await _refreshReplies();
      ref.invalidate(forumPostDetailProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('回复失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReply = false);
    }
  }

  void _showReportDialog(BuildContext context) {
    _showReport(context, 'post', widget.postId);
  }

  void _showReplyReportDialog(BuildContext context, ForumReply reply) {
    _showReport(context, 'reply', reply.id);
  }

  void _showReport(BuildContext context, String targetType, int targetId) {
    String detail = '';
    String? reason;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('举报', style: TextStyle(fontSize: adaptive.Adaptive.sp(17))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: reason,
                items: const [
                  DropdownMenuItem(value: 'spam', child: Text('垃圾广告')),
                  DropdownMenuItem(value: 'abuse', child: Text('人身攻击')),
                  DropdownMenuItem(value: 'illegal', child: Text('违法违规')),
                  DropdownMenuItem(value: 'porn', child: Text('色情低俗')),
                  DropdownMenuItem(value: 'other', child: Text('其他')),
                ],
                onChanged: (v) => setDialogState(() => reason = v),
                decoration: const InputDecoration(
                  hintText: '选择举报原因',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 3,
                onChanged: (v) => detail = v,
                decoration: const InputDecoration(
                  hintText: '补充说明（选填）',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (reason == null) return;
                try {
                  final service = ref.read(forumServiceProvider);
                  await service.createReport(
                      targetType, targetId, reason!, detail);
                  if (mounted) {
                    Navigator.pop(ctx);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('举报已提交')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('举报失败: $e')),
                    );
                  }
                }
              },
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageViewer(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: PageView.builder(
            itemCount: urls.length,
            controller: PageController(initialPage: initialIndex),
            itemBuilder: (_, index) {
              return InteractiveViewer(
                child: Center(
                  child: Image.network(urls[index], fit: BoxFit.contain),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String? _getCurrentUserId() {
    return ref.read(supabaseProvider).auth.currentUser?.id;
  }

  static String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
