library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/views/files/file_list_page.dart';
import 'package:vidlang/views/home/home_page.dart';
import 'package:vidlang/views/profile/profile_page.dart';
import 'package:vidlang/views/word_book/collection_page.dart';

/// 主页面
///
/// 应用的主容器页面，包含底部导航栏（4个Tab）：
/// - 首页：仪表盘，快速启动
/// - 资源：资源管理（视频/文章/音频分类切换）
/// - 收藏：单词收藏和知识库
/// - 我的：设置、用户管理、免费/付费模式切换
class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final pages = [const HomePage(), const FileListPage(), const CollectionPage(), const ProfilePage()];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          ref.read(navigationIndexProvider.notifier).setIndex(index);
        },
        physics: const ClampingScrollPhysics(),
        children: List.generate(pages.length, (index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              final position = _pageController.position;
              final pageOffset = position.hasPixels ? (position.pixels - index * position.viewportDimension) / position.viewportDimension : 0.0;
              final isVisible = index == currentIndex;
              final scale = isVisible ? 1.0 : 1.0 - pageOffset.abs().clamp(0.0, 0.05);
              final opacity = isVisible ? 1.0 : 1.0 - pageOffset.abs().clamp(0.0, 0.15);

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: pages[index],
                ),
              );
            },
          );
        }),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
            );
            ref.read(navigationIndexProvider.notifier).setIndex(index);
          },
          elevation: 0,
          backgroundColor: colorScheme.surface,
          selectedItemColor: AppColors.iconActive,
          unselectedItemColor: AppColors.iconDefault,
          selectedLabelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 12.sp),
          type: BottomNavigationBarType.fixed,
          items: navigationItems.map((item) {
            final isActive = currentIndex == navigationItems.indexOf(item);

            if (item.id == NavigationPage.home) {
              return BottomNavigationBarItem(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedHome01,
                  color: isActive ? AppColors.iconActive : AppColors.iconDefault,
                  size: 24.w,
                ),
                activeIcon: HugeIcon(
                  icon: HugeIcons.strokeRoundedHome01,
                  color: AppColors.iconActive,
                  size: 24.w,
                ),
                label: item.label,
              );
            }

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
