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
    // 监听 provider 变化，驱动 PageView 翻页
    ref.listen<int>(navigationIndexProvider, (previous, next) {
      if (previous != next && mounted) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      }
    });
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
    final brightness = Theme.of(context).brightness;

    final pages = [const HomePage(), const FileListPage(), const CollectionPage(), const ProfilePage()];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          ref.read(navigationIndexProvider.notifier).setIndex(index);
        },
        physics: const ClampingScrollPhysics(),
        children: pages,
      ),
      bottomNavigationBar: BottomAppBar(
        color: colorScheme.surface,
        child: Row(
          children: [
            ...navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = currentIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                    );
                    ref.read(navigationIndexProvider.notifier).setIndex(index);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (item.id == NavigationPage.home)
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedHome01,
                          color: isActive ? AppColors.iconActive : AppColors.iconDefault,
                          size: 24.w,
                        )
                      else
                        Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive ? AppColors.iconActive : AppColors.iconDefault,
                          size: 24.w,
                        ),
                      SizedBox(height: 2.h),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? AppColors.iconActive : AppColors.iconDefault,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
