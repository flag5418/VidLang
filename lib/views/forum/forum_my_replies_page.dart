import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/ui/loading_widget.dart';
import 'package:vidlang/models/forum/forum_reply.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/forum/providers/forum_providers.dart';

/// 我的回复页
class ForumMyRepliesPage extends ConsumerStatefulWidget {
  const ForumMyRepliesPage({super.key});

  @override
  ConsumerState<ForumMyRepliesPage> createState() =>
      _ForumMyRepliesPageState();
}

class _ForumMyRepliesPageState extends ConsumerState<ForumMyRepliesPage> {
  final ScrollController _scrollController = ScrollController();
  final List<ForumReply> _replies = [];
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
      final response = await service.getMyReplies(page: _page);
      setState(() {
        _replies.addAll(response.data);
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
      _replies.clear();
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
  title: '我的回复',
  backgroundColor: colors.surface,
  foregroundColor: colors.textPrimary,
  elevation: 1,
),
      body: _replies.isEmpty && _isLoading
          ? const Center(child: LoadingWidget())
          : _replies.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.chat_outlined,
                    title: '暂无回复',
                    description: '在帖子详情页可以发表回复',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                        vertical: adaptive.Adaptive.h(8)),
                    itemCount: _replies.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _replies.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      final reply = _replies[index];
                      return _buildReplyCard(context, colors, reply);
                    },
                  ),
                ),
    );
  }

  Widget _buildReplyCard(
    BuildContext context,
    AppColorsData colors,
    ForumReply reply,
  ) {
    return BaseCard.outlined(
      padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
      margin: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(6),
      ),
      onTap: () {
        Navigator.pushNamed(context, '/forum/post/${reply.postId}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.reply,
                  size: adaptive.Adaptive.sp(14), color: colors.textWeak),
              SizedBox(width: adaptive.Adaptive.w(4)),
              Text(
                '回复了帖子 #${reply.postId}',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(12),
                  color: colors.textWeak,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right,
                  size: adaptive.Adaptive.sp(16), color: colors.textWeak),
            ],
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Text(
            reply.isDeleted ? '[该回复已被删除]' : reply.content,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              color: reply.isDeleted ? colors.textWeak : colors.textPrimary,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: adaptive.Adaptive.h(8)),
          Row(
            children: [
              Icon(Icons.thumb_up_outlined,
                  size: adaptive.Adaptive.sp(12), color: colors.textWeak),
              SizedBox(width: adaptive.Adaptive.w(2)),
              Text(
                '${reply.likeCount}',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(11),
                  color: colors.textWeak,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(reply.createdAt),
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(11),
                  color: colors.textWeak,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
