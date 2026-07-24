import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/forum/forum_tag.dart';
import 'package:vidlang/views/forum/providers/forum_providers.dart';
import 'package:vidlang/services/forum/forum_tag_follow_local_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 标签管理弹窗 — 分「已关注」和「未关注」两区，参考频道选择器风格
///
/// 设计要点：
/// - 居中弹出（非底部抽屉）
/// - 点击遮罩层关闭
/// - 已关注区：标签可直接点击取消关注
/// - 未关注区：标签带 + 号，点击添加关注
/// - 4 列网格布局，标签尺寸符合设计规范
///
/// 数据持久化策略：
/// - 每次操作（关注/取消）立即写入本地数据库
/// - 首次打开时检查并初始化（默认全量关注）
/// - 操作失败时明确提示用户
class ForumTagManageSheet extends ConsumerStatefulWidget {
  const ForumTagManageSheet({super.key});

  @override
  ConsumerState<ForumTagManageSheet> createState() =>
      _ForumTagManageSheetState();

  /// 显示标签管理弹窗（静态入口）
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const ForumTagManageSheet(),
    );
  }
}

class _ForumTagManageSheetState extends ConsumerState<ForumTagManageSheet> {
  final ForumTagFollowLocalService _localService =
      ForumTagFollowLocalService.instance;

  Set<int> _followedIds = {};
  List<ForumTag>? _allTags;
  bool _isLoading = true;
  bool _isInitialized = false; // 标记数据库是否可用
  final Set<int> _togglingIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // 1. 始终从远程获取最新标签列表
      final service = ref.read(forumServiceProvider);
      final remoteTags = await service.getTags();

      if (remoteTags.isEmpty) {
        if (mounted) {
          setState(() {
            _allTags = [];
            _isLoading = false;
            _isInitialized = true;
          });
        }
        return;
      }

      _allTags = remoteTags;

      // 2. 尝试初始化本地数据（仅首次需要）
      final initSuccess = await _localService.initializeIfNeeded(remoteTags);
      _isInitialized = initSuccess;

      if (!initSuccess) {
        debugPrint('ForumTagManageSheet: 初始化失败，将使用内存态');
      }

      // 3. 从数据库读取已关注的标签 ID
      try {
        _followedIds = await _localService.getFollowedTagIds();
      } catch (e) {
        debugPrint('ForumTagManageSheet: 读取关注状态失败: $e');
        if (_isInitialized) {
          // 数据库应该可用但读取失败 → 返回空集
          _followedIds = {};
        } else {
          // 数据库不可用 → 默认全部关注（纯内存态）
          _followedIds = remoteTags.map((t) => t.id).toSet();
        }
      }

      // 4. 如果数据库刚被创建（之前不可用），后台刷新 provider
      if (mounted && initSuccess) {
        ref.invalidate(forumTagsProvider);
      }
    } catch (e) {
      debugPrint('ForumTagManageSheet: 加载标签失败: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// 已关注的标签列表
  List<ForumTag> get _followedTags =>
      _allTags?.where((t) => _followedIds.contains(t.id)).toList() ?? [];

  /// 未关注的标签列表
  List<ForumTag> get _unfollowedTags =>
      _allTags?.where((t) => !_followedIds.contains(t.id)).toList() ?? [];

  /// 切换关注状态
  Future<void> _toggleTag(ForumTag tag) async {
    if (_togglingIds.contains(tag.id)) return;

    final wasFollowing = _followedIds.contains(tag.id);

    // 乐观更新 UI
    setState(() {
      if (wasFollowing) {
        _followedIds.remove(tag.id);
      } else {
        _followedIds.add(tag.id);
      }
      _togglingIds.add(tag.id);
    });

    try {
      // 直接调用数据库操作（不再套额外的 try-catch）
      if (wasFollowing) {
        await _localService.unfollow(tag.id);
      } else {
        await _localService.follow(tag);
      }
      // 成功：保持乐观更新的状态
    } catch (e) {
      debugPrint('ForumTagManageSheet: 操作数据库失败: $e');

      // 失败：回滚 UI
      if (mounted) {
        setState(() {
          if (wasFollowing) {
            _followedIds.add(tag.id);
          } else {
            _followedIds.remove(tag.id);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isInitialized ? '操作失败，请重试' : '保存失败（数据库不可用）'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingIds.remove(tag.id));
      }
    }

    // 通知全局刷新（让论坛首页标签栏同步更新）
    if (mounted) {
      ref.invalidate(forumTagsProvider);
      ref.invalidate(forumPostsProvider(
        ForumPostsParams(followed: true, page: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isPad = adaptive.isIPad();
    final dialogWidth = isPad ? adaptive.Adaptive.w(560) : double.infinity;
    final maxHeight = MediaQuery.of(context).size.height * (isPad ? 0.75 : 0.8);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: dialogWidth,
          margin: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(20)),
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withAlpha(12),
                offset: const Offset(0, 4),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                _buildHeader(colors),

                // 分割线
                Divider(height: 1, color: colors.border.withAlpha(80)),

                // 内容区
                Flexible(
                  child: _isLoading
                      ? Padding(
                          padding:
                              EdgeInsets.all(adaptive.Adaptive.h(40)),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _buildContent(colors),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 标题栏 — 关闭 | 标题+副标题
  Widget _buildHeader(AppColorsData colors) {
    final isPad = adaptive.isIPad();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        adaptive.Adaptive.w(16),
        adaptive.Adaptive.h(14),
        adaptive.Adaptive.w(12),
        adaptive.Adaptive.h(10),
      ),
      child: Row(
        children: [
          // 关闭按钮
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.close,
              size: adaptive.Adaptive.icon(isPad ? 24 : 22),
              color: colors.textPrimary,
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          // 标题区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '我的频道',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(isPad ? 17 : 15),
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(width: adaptive.Adaptive.w(8)),
                    Text(
                      '点击进入频道',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(isPad ? 13 : 11),
                        color: colors.textWeak,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 右侧留空
        ],
      ),
    );
  }

  /// 内容区 — 两区域网格布局
  Widget _buildContent(AppColorsData colors) {
    if (_allTags == null || _allTags!.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.h(32)),
        child: Center(
          child: Text(
            '暂无可用标签',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(14),
              color: colors.textSecondary,
            ),
          ),
        ),
      );
    }

    final followed = _followedTags;
    final unfollowed = _unfollowedTags;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: adaptive.Adaptive.w(16),
        vertical: adaptive.Adaptive.h(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ════════════════════════════════════════
          // 第一部分：已关注的标签
          // ════════════════════════════════════════
          if (followed.isNotEmpty) ...[
            _buildSectionHeader(colors, '已关注', followed.length, isFirst: true),
            SizedBox(height: adaptive.Adaptive.h(6)),
            _buildFollowedGrid(colors, followed),
          ],

          // ════════════════════════════════════════
          // 第二部分：未关注的标签（更多推荐）
          // ════════════════════════════════════════
          if (unfollowed.isNotEmpty) ...[
            if (followed.isNotEmpty) ...[
              SizedBox(height: adaptive.Adaptive.h(12)),
              Divider(height: 1, color: colors.border.withAlpha(60)),
              SizedBox(height: adaptive.Adaptive.h(12)),
            ],
            _buildSectionHeader(colors, '更多标签', unfollowed.length, isFirst: followed.isEmpty),
            SizedBox(height: adaptive.Adaptive.h(6)),
            _buildUnfollowedGrid(colors, unfollowed),
          ],

          // 底部安全间距
          SizedBox(height: adaptive.Adaptive.h(16)),
        ],
      ),
    );
  }

  /// 区域标题行
  Widget _buildSectionHeader(AppColorsData colors, String title, int count, {required bool isFirst}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(14),
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        if (count > 0) ...[
          SizedBox(width: adaptive.Adaptive.w(6)),
          Text(
            '$count',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(12),
              color: colors.textWeak,
            ),
          ),
        ],
      ],
    );
  }

  /// 已关注标签网格 — 点击取消关注
  Widget _buildFollowedGrid(AppColorsData colors, List<ForumTag> tags) {
    return _TagGrid(
      tags: tags,
      followedIds: _followedIds,
      togglingIds: _togglingIds,
      isFollowedSection: true,
      onToggle: _toggleTag,
      colors: colors,
    );
  }

  /// 未关注标签网格 — 带 + 号，点击添加关注
  Widget _buildUnfollowedGrid(AppColorsData colors, List<ForumTag> tags) {
    return _TagGrid(
      tags: tags,
      followedIds: _followedIds,
      togglingIds: _togglingIds,
      isFollowedSection: false,
      onToggle: _toggleTag,
      colors: colors,
    );
  }
}

/// ══════════════════════════════════════════════════════════════════════════════
/// 标签网格组件 — 4 列自适应布局
/// ══════════════════════════════════════════════════════════════════════════════

class _TagGrid extends StatelessWidget {
  final List<ForumTag> tags;
  final Set<int> followedIds;
  final Set<int> togglingIds;
  final bool isFollowedSection;
  final ValueChanged<ForumTag> onToggle;
  final AppColorsData colors;

  const _TagGrid({
    required this.tags,
    required this.followedIds,
    required this.togglingIds,
    required this.isFollowedSection,
    required this.onToggle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isPad = adaptive.isIPad();

    final screenWidth = MediaQuery.of(context).size.width -
        adaptive.Adaptive.w(32);
    final spacing = adaptive.Adaptive.w(isPad ? 12 : 10);
    final itemWidth = (screenWidth - spacing * 3) / 4;
    final itemHeight = adaptive.Adaptive.h(isPad ? 44 : 40);

    return Wrap(
      spacing: spacing,
      runSpacing: adaptive.Adaptive.h(isPad ? 10 : 8),
      alignment: WrapAlignment.start,
      children: tags.map((tag) {
        final isToggling = togglingIds.contains(tag.id);
        final tagColor = _parseColor(tag.color);

        return SizedBox(
          width: itemWidth,
          height: itemHeight,
          child: _buildTagItem(tag, tagColor, isToggling, isPad),
        );
      }).toList(),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4ADE80);
    }
  }

  Widget _buildTagItem(ForumTag tag, Color tagColor, bool isToggling, bool isPad) {
    final isEnabled = !isToggling;

    if (isFollowedSection) {
      return GestureDetector(
        onTap: isEnabled ? () => onToggle(tag) : null,
        child: Container(
          decoration: BoxDecoration(
            color: tagColor.withAlpha(20),
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(isPad ? 8 : 6)),
            border: Border.all(
              color: tagColor.withAlpha(40),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            tag.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(isPad ? 14 : 13),
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: isEnabled ? () => onToggle(tag) : null,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(isPad ? 8 : 6)),
            border: Border.all(
              color: colors.border.withAlpha(100),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(4)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  tag.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(isPad ? 14 : 13),
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(width: adaptive.Adaptive.w(2)),
              Icon(
                Icons.add,
                size: adaptive.Adaptive.sp(isPad ? 16 : 14),
                color: colors.textWeak,
              ),
            ],
          ),
        ),
      );
    }
  }
}
