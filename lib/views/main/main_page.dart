library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/views/files/file_list_page.dart';
import 'package:vidlang/views/home/home_page.dart';
import 'package:vidlang/views/profile/profile_page.dart';
import 'package:vidlang/views/word_book/word_book_page.dart';

/// 主页面
///
/// 应用的主容器页面，包含底部导航栏（4个Tab）：
/// - 首页：仪表盘，快速启动
/// - 资源：资源管理（视频/文章/音频分类切换）
/// - 生词本：单词收藏和复习
/// - 我的：设置、用户管理、免费/付费模式切换
class MainPage extends ConsumerWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final pages = [const HomePage(), const FileListPage(), const WordBookPage(), const ProfilePage()];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            ref.read(navigationIndexProvider.notifier).setIndex(index);
          },
          elevation: 0,
          backgroundColor: colorScheme.surface,
          selectedItemColor: AppColors.iconActive,
          unselectedItemColor: AppColors.iconDefault,
          selectedLabelStyle: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 10.sp),
          type: BottomNavigationBarType.fixed,
          items: navigationItems.map((item) {
            final isActive = currentIndex == navigationItems.indexOf(item);
            return BottomNavigationBarItem(
              icon: Icon(item.icon, color: isActive ? AppColors.iconActive : AppColors.iconDefault, size: 24.w),
              activeIcon: Icon(item.activeIcon, color: AppColors.iconActive, size: 24.w),
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}
