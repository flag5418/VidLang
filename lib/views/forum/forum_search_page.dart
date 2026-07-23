import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/models/forum/forum_post.dart';
import 'package:vidlang/views/forum/providers/forum_providers.dart';
import 'package:vidlang/views/forum/widgets/forum_post_card.dart';
import 'package:vidlang/views/forum/forum_post_detail_page.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 论坛搜索页面 — 使用 getPosts 按板块+分页拉取，用 query 做本地标题/内容过滤
class ForumSearchPage extends ConsumerStatefulWidget {
  const ForumSearchPage({super.key});

  @override
  ConsumerState<ForumSearchPage> createState() => _ForumSearchPageState();
}

class _ForumSearchPageState extends ConsumerState<ForumSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ForumPost> _results = [];
  int _page = 1;
  bool _hasMore = true;
  bool _hasSearched = false;
  String _query = '';
  bool _isLoading = false;
  final List<ForumPost> _allFetched = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && _query.isNotEmpty && !_isLoading) {
        _page++;
        _doSearch();
      }
    }
  }

  Future<void> _doSearch() async {
    if (_query.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(forumServiceProvider);
      final response = await service.getPosts(page: _page, limit: 50, sort: 'latest');

      if (mounted) {
        setState(() {
          _allFetched.addAll(response.data);
          _hasMore = response.pagination.hasMore;

          // Filter locally
          final q = _query.toLowerCase();
          final filtered = _allFetched.where((p) {
            return p.title.toLowerCase().contains(q) ||
                p.content.toLowerCase().contains(q) ||
                (p.authorName.toLowerCase().contains(q));
          }).toList();

          _results
            ..clear()
            ..addAll(filtered);
          _hasSearched = true;

          // If server has no more AND we haven't found enough, stop
          if (!_hasMore && _results.length < 5) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 1,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(fontSize: adaptive.Adaptive.sp(15)),
          decoration: InputDecoration(
            hintText: '搜索帖子标题、内容...',
            hintStyle: TextStyle(color: colors.textWeak),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _results.clear();
                        _allFetched.clear();
                        _hasSearched = false;
                        _query = '';
                        _page = 1;
                        _hasMore = true;
                      });
                    },
                  )
                : null,
          ),
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() {}),
          onSubmitted: (v) {
            _query = v.trim();
            _page = 1;
            _results.clear();
            _allFetched.clear();
            _hasMore = true;
            _doSearch();
          },
        ),
      ),
      body: _buildBody(context, colors),
    );
  }

  Widget _buildBody(BuildContext context, AppColorsData colors) {
    if (!_hasSearched) {
      return EmptyState(
        icon: Icons.search,
        title: '搜索论坛',
        description: '输入关键词搜索帖子',
      );
    }

    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasSearched && _results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: '未找到结果',
        description: '换个关键词试试吧',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        top: adaptive.Adaptive.h(8),
        bottom: adaptive.Adaptive.h(40),
      ),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final post = _results[index];
        return ForumPostCard(
          post: post,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ForumPostDetailPage(postId: post.id),
            ),
          ),
        );
      },
    );
  }
}
