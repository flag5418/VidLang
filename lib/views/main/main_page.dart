library;

import 'package:flutter/material.dart';import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/views/profile/providers/device_type_provider.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/services/learning/learning_stats_service.dart';
import 'package:vidlang/theme/theme.dart';

import 'package:vidlang/views/files/file_list_page.dart';
import 'package:vidlang/views/home/home_page.dart';
import 'package:vidlang/views/profile/profile_page.dart';
import 'package:vidlang/views/word_book/collection_page.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;
  // 本地模型（LocalModelService）已移除，此标记保留以避免重构 _checkModelStatus 调用点
  // ignore: unused_field
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

  // 本地模型（LocalModelService）已移除，模型状态检查不再需要
  // iOS 免费模式使用系统原生功能（MLTranslation / AVSpeechSynthesizer），无需本地模型
  Future<void> _checkModelStatus() async {
    _hasCheckedModels = true; // 标记为已检查，避免重复调用
  }

  void _onTabTapped(int index) {
    if (_currentPage == index) return;
    _currentPage = index;
    final deviceType = ref.read(deviceTypeProvider);
    final isIpad = deviceType.isTablet;

    // iPad 下收藏页面使用独立导航（Navigator.push）
    if (isIpad && index == 2) {
      // 收藏页面的导航在 context 可用时通过 Navigator.push 处理
      // 这里只更新索引状态，实际导航在 _IpadNavItem 中处理
      ref.read(navigationIndexProvider.notifier).setIndex(index);
      return;
    }

    // iPad 布局使用 IndexedStack，不需要 PageController
    if (!isIpad) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
    ref.read(navigationIndexProvider.notifier).setIndex(index);
  }

  /// iPad 下导航到收藏独立页面
  void _navigateToCollection(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CollectionPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final deviceType = ref.watch(deviceTypeProvider);
    final isIpad = deviceType.isTablet;

    final pages = [
      HomePage(onNavigateToTab: () => _onTabTapped(1)),
      const FileListPage(),
      const CollectionPage(),
      const ProfilePage(),
    ];

    if (isIpad) {
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
          // 左侧边栏 (固定宽度，不缩放)
          Container(
            width: adaptive.Adaptive.w(180.0),
            color: colors.surface,
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 20.0),
                // 品牌区
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.schoolFill,
                        size: adaptive.Adaptive.sp(28.0),
                        color: colors.primary,
                      ),
                      SizedBox(width: adaptive.Adaptive.w(10.0)),
                      Text(
                        'VidLang',
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(22.0),
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(32.0)),
                // 导航项
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: List.generate(navigationItems.length, (index) {
                      final item = navigationItems[index];
                      final isActive = currentIndex == index;
                      // iPad 下收藏页面使用独立导航
                      final isCollectionIndex = index == 2;
                      return _IpadNavItem(
                        item: item,
                        isActive: isActive,
                        onTap: isCollectionIndex
                            ? () => _navigateToCollection(context)
                            : () => _onTabTapped(index),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          // 分割线
          Container(width: 0.5, color: colors.border),
          // 右侧内容区
          Expanded(
            child: IndexedStack(index: currentIndex, children: pages),
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
              size: adaptive.Adaptive.icon(24),
              color: isActive ? activeColor : inactiveColor,
            ),
            SizedBox(height: adaptive.Adaptive.h(2.0)),
            Text(
              item.label,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(11.0),
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
        margin: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(12.0),
          vertical: adaptive.Adaptive.h(2.0),
        ),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12.0)),
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
                    horizontal: adaptive.Adaptive.w(16.0),
                    vertical: adaptive.Adaptive.h(14.0),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: adaptive.Adaptive.icon(24.0),
                        color: isActive ? activeColor : inactiveColor,
                      ),
                      SizedBox(width: adaptive.Adaptive.w(12.0)),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(16.0),
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
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
