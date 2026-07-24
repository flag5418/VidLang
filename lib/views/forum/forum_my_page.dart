import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 论坛「我的」页面 — V2.0: 帖子/回复/收藏/关注/反馈入口
class ForumMyPage extends ConsumerWidget {
  const ForumMyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppNavBar(
        title: '我的论坛',
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 1,
      ),
      body: ListView(
        padding: EdgeInsets.all(adaptive.Adaptive.w(16)),
        children: [
          _buildSectionHeader(colors, '内容管理'),
          SizedBox(height: adaptive.Adaptive.h(8)),
          _buildMenuItem(
            context,
            colors,
            icon: Icons.article_outlined,
            title: '我的帖子',
            subtitle: '查看和管理我发布的帖子',
            onTap: () => Navigator.pushNamed(context, '/forum/my/posts'),
          ),
          _buildMenuItem(
            context,
            colors,
            icon: Icons.chat_outlined,
            title: '我的回复',
            subtitle: '查看我发表的回复',
            onTap: () => Navigator.pushNamed(context, '/forum/my/replies'),
          ),
          _buildMenuItem(
            context,
            colors,
            icon: Icons.thumb_up_outlined,
            title: '我的点赞',
            subtitle: '查看我点赞过的帖子',
            onTap: () => Navigator.pushNamed(context, '/forum/my/likes'),
          ),
          SizedBox(height: adaptive.Adaptive.h(20)),
          _buildSectionHeader(colors, '社交'),
          SizedBox(height: adaptive.Adaptive.h(8)),
          _buildMenuItem(
            context,
            colors,
            icon: Icons.star_outline,
            title: '我的收藏',
            subtitle: '收藏的帖子',
            onTap: () => Navigator.pushNamed(context, '/forum/favorites'),
          ),
          _buildMenuItem(
            context,
            colors,
            icon: Icons.people_outline,
            title: '我的关注',
            subtitle: '关注的用户和标签',
            onTap: () => Navigator.pushNamed(context, '/forum/follows'),
          ),
          SizedBox(height: adaptive.Adaptive.h(20)),
          _buildSectionHeader(colors, '反馈与帮助'),
          SizedBox(height: adaptive.Adaptive.h(8)),
          _buildMenuItem(
            context,
            colors,
            icon: Icons.feedback_outlined,
            title: '提交反馈',
            subtitle: '报告问题或提出建议',
            onTap: () => Navigator.pushNamed(context, '/forum/feedback'),
          ),
          _buildMenuItem(
            context,
            colors,
            icon: Icons.list_alt,
            title: '我的反馈',
            subtitle: '查看反馈处理进度',
            onTap: () => Navigator.pushNamed(context, '/forum/feedback/list'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(AppColorsData colors, String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(4)),
      child: Text(
        title,
        style: TextStyle(
          fontSize: adaptive.Adaptive.sp(13),
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    AppColorsData colors, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return BaseCard.outlined(
      margin: EdgeInsets.only(bottom: adaptive.Adaptive.h(8)),
      padding: EdgeInsets.all(adaptive.Adaptive.w(14)),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: adaptive.Adaptive.w(40),
            height: adaptive.Adaptive.h(40),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
            ),
            child: Icon(icon, size: adaptive.Adaptive.sp(20), color: colors.primary),
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(15),
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(2)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(12),
                    color: colors.textWeak,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.textWeak),
        ],
      ),
    );
  }
}
