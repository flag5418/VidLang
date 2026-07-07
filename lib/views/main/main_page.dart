library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/services/learning_stats_service.dart';
import 'package:vidlang/services/local_model_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/views/files/file_list_page.dart';
import 'package:vidlang/views/home/home_page.dart';
import 'package:vidlang/views/profile/profile_page.dart';
import 'package:vidlang/views/word_book/collection_page.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;
  bool _hasCheckedModels = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    WidgetsBinding.instance.addObserver(this); // P1: 注册生命周期监听
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkModelStatus();
      // P1: 启动时恢复崩溃/Kill 的未完成学习记录
      LearningStatsService.recoverCrashedSessions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // P1: 移除生命周期监听
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// P1: App 生命周期变化 → 结束活跃学习会话
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    LearningStatsService.instance.handleAppLifecycleChanged(state);
  }

  Future<void> _checkModelStatus() async {
    if (_hasCheckedModels) return;
    _hasCheckedModels = true;
    try {
      final localModelService = LocalModelService.instance;
      final status = await localModelService.checkModelsStatus();
      debugPrint('=== 模型状态检查 ===');
      debugPrint('状态: $status');
      debugPrint('canUseAiFeatures: ${localModelService.canUseAiFeatures}');
      if (status == LocalModelStatus.missing) {
        debugPrint('翻译模型未找到，请检查 iOS 系统翻译设置');
      }
    } catch (e) {
      debugPrint('检查模型状态失败: $e');
    }
  }

  void _onTabTapped(int index) {
    if (_currentPage == index) return;
    _currentPage = index;
    final ipad = isIPad(context);
    // iPad 布局使用 IndexedStack，不需要 PageController
    if (!ipad) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
    ref.read(navigationIndexProvider.notifier).setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final ipad = isIPad(context);

    final pages = [
      HomePage(
        onNavigateToTab: () => _onTabTapped(1),
      ),
      const FileListPage(),
      const CollectionPage(),
      const ProfilePage(),
    ];

    if (ipad) {
      return _buildIpadLayout(currentIndex, pages);
    }
    return _buildIphoneLayout(currentIndex, pages);
  }

  // ═══════════════════════════════════════════════
  // iPhone 布局
  // ═══════════════════════════════════════════════

  Widget _buildIphoneLayout(int currentIndex, List<Widget> pages) {
    final colors = context.colors;

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
      bottomNavigationBar: Container(
        height: 60.0 + MediaQuery.of(context).padding.bottom,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 60.0,
              child: Row(
                children: List.generate(navigationItems.length, (index) {
                  final item = navigationItems[index];
                  final isActive = currentIndex == index;
                  return Expanded(
                    child: _IphoneNavItem(
                      item: item,
                      isActive: isActive,
                      onTap: () => _onTabTapped(index),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // iPad 布局
  // ═══════════════════════════════════════════════

  Widget _buildIpadLayout(int currentIndex, List<Widget> pages) {
    final colors = context.colors;

    return Scaffold(
      body: Row(
        children: [
          // 左侧边栏
          Container(
            width: 220.0.w,
            color: colors.surface,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 20.0.h),
                // 品牌区
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0.w),
                  child: Row(
                    children: [
                      Icon(Icons.school_rounded,
                          size: 28.0.sp, color: colors.primary),
                      SizedBox(width: 10.0.w),
                      Text(
                        'VidLang',
                        style: TextStyle(
                          fontSize: 22.0.sp,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.0.h),
                // 导航项
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: List.generate(navigationItems.length, (index) {
                      final item = navigationItems[index];
                      final isActive = currentIndex == index;
                      return _IpadNavItem(
                        item: item,
                        isActive: isActive,
                        onTap: () => _onTabTapped(index),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          // 分割线
          Container(
            width: 0.5,
            color: colors.border,
          ),
          // 右侧内容区
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// iPhone 导航项
// ═══════════════════════════════════════════════

class _IphoneNavItem extends StatelessWidget {
  final NavigationItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _IphoneNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeColor = colors.primary;
    final inactiveColor = colors.textWeak;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 24.0,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 2.0),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11.0,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// iPad 导航项
// ═══════════════════════════════════════════════

class _IpadNavItem extends StatelessWidget {
  final NavigationItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _IpadNavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeColor = colors.primary;
    final inactiveColor = colors.textWeak;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(horizontal: 12.0.w, vertical: 2.0.h),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 3.0 : 0.0,
                decoration: BoxDecoration(
                  color: isActive ? activeColor : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(2.0),
                    bottomRight: Radius.circular(2.0),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0.w,
                    vertical: 12.0.h,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 22.0,
                        color: isActive ? activeColor : inactiveColor,
                      ),
                      SizedBox(width: 12.0.w),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 15.0.sp,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? activeColor : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
