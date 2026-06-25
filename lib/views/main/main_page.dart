library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  int _currentPage = 0;

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

  void _onTabTapped(int index) {
    if (_currentPage == index) return;
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOutCubic);
    ref.read(navigationIndexProvider.notifier).setIndex(index);
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
          if (_currentPage != index) {
            _currentPage = index;
            ref.read(navigationIndexProvider.notifier).setIndex(index);
          }
        },
        physics: const ClampingScrollPhysics(),
        children: pages,
      ),
      bottomNavigationBar: BottomAppBar(
        height: 80,
        color: colorScheme.surface,
        child: Row(
          children: [
            ...navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = currentIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabTapped(index),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isActive ? item.activeIcon : item.icon, color: isActive ? AppColors.iconActive : AppColors.iconDefault, size: 28.w),
                        SizedBox(height: 4.h),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? AppColors.iconActive : AppColors.iconDefault,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
