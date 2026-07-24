import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/components/ui/loading_widget.dart';
import 'package:vidlang/models/forum/forum_follow.dart';
import 'package:vidlang/models/forum/forum_tag_follow.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/forum/providers/forum_providers.dart';

/// 我的关注页 — V2.0: 关注用户 + 关注标签
class ForumFollowsPage extends ConsumerStatefulWidget {
  const ForumFollowsPage({super.key});

  @override
  ConsumerState<ForumFollowsPage> createState() => _ForumFollowsPageState();
}

class _ForumFollowsPageState extends ConsumerState<ForumFollowsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<ForumFollow> _userFollows = [];
  List<ForumTagFollow> _tagFollows = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(forumServiceProvider);

      final userRes = await service.getMyFollows();
      _userFollows = userRes.data;

      final tagRes = await service.getMyTagFollows();
      _tagFollows = tagRes;
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppNavBar(
        title: '我的关注',
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          tabs: const [
            Tab(text: '关注的用户'),
            Tab(text: '关注的标签'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: LoadingWidget())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserTab(colors),
                _buildTagTab(colors),
              ],
            ),
    );
  }

  Widget _buildUserTab(AppColorsData colors) {
    if (_userFollows.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.people_outline,
          title: '暂无关注的用户',
          description: '在帖子详情页可以关注作者',
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(8)),
      itemCount: _userFollows.length,
      itemBuilder: (context, index) {
        final follow = _userFollows[index];
        return _buildUserItem(context, colors, follow, index);
      },
    );
  }

  Widget _buildUserItem(
    BuildContext context,
    AppColorsData colors,
    ForumFollow follow,
    int index,
  ) {
    return BaseCard.outlined(
      margin: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(4),
      ),
      padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
      child: Row(
        children: [
          Avatar(
            imageUrl: follow.avatar,
            text: follow.nickname,
            size: AvatarSize.sm,
          ),
          SizedBox(width: adaptive.Adaptive.w(10)),
          Expanded(
            child: Text(
              follow.nickname,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(15),
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _unfollowUser(follow, index),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.Adaptive.w(12),
                vertical: adaptive.Adaptive.h(5),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                '已关注',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(12),
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagTab(AppColorsData colors) {
    if (_tagFollows.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.label_outline,
          title: '暂无关注的标签',
          description: '在论坛首页可以关注感兴趣的标签',
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(8)),
      itemCount: _tagFollows.length,
      itemBuilder: (context, index) {
        final tagFollow = _tagFollows[index];
        return _buildTagItem(context, colors, tagFollow, index);
      },
    );
  }

  Widget _buildTagItem(
    BuildContext context,
    AppColorsData colors,
    ForumTagFollow tagFollow,
    int index,
  ) {
    return BaseCard.outlined(
      margin: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(4),
      ),
      padding: EdgeInsets.all(adaptive.Adaptive.w(12)),
      child: Row(
        children: [
          Container(
            width: adaptive.Adaptive.w(36),
            height: adaptive.Adaptive.h(36),
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
            ),
            child: Icon(
              Icons.label,
              size: adaptive.Adaptive.sp(18),
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(10)),
          Expanded(
            child: Text(
              tagFollow.tagName,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(15),
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _unfollowTag(tagFollow, index),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.Adaptive.w(12),
                vertical: adaptive.Adaptive.h(5),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                '已关注',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(12),
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _unfollowUser(ForumFollow follow, int index) async {
    try {
      final service = ref.read(forumServiceProvider);
      await service.toggleFollow(follow.followingId);
      setState(() => _userFollows.removeAt(index));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取消关注失败: $e')));
      }
    }
  }

  Future<void> _unfollowTag(ForumTagFollow tagFollow, int index) async {
    try {
      final service = ref.read(forumServiceProvider);
      await service.toggleTagFollow(tagFollow.tagId);
      setState(() => _tagFollows.removeAt(index));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('取消关注失败: $e')));
      }
    }
  }
}
