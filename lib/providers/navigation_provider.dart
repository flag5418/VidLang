import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 底部导航索引状态
final navigationIndexProvider = StateNotifierProvider<NavigationIndexNotifier, int>((ref) {
  return NavigationIndexNotifier();
});

/// 资源管理页面的子Tab类型
final resourceTabProvider = StateProvider<int>((ref) => 0);

class NavigationIndexNotifier extends StateNotifier<int> {
  NavigationIndexNotifier() : super(0);

  void setIndex(int index) {
    state = index;
  }

  /// 切换到指定Tab并设置资源页面的子Tab
  void goToResourceTab(int resourceTabIndex) {
    state = 1; // 资源管理Tab索引
    // 通过全局Provider设置子Tab
  }
}

/// 导航页面类型
enum NavigationPage {
  home,           // 首页
  resources,      // 资源管理
  wordBook,       // 生词本
  profile,        // 我的
}

/// 导航项配置
final navigationItems = [
  NavigationItem(
    id: NavigationPage.home,
    label: '首页',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
  ),
  NavigationItem(
    id: NavigationPage.resources,
    label: '资源',
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder,
  ),
  NavigationItem(
    id: NavigationPage.wordBook,
    label: '生词本',
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book,
  ),
  NavigationItem(
    id: NavigationPage.profile,
    label: '我的',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
  ),
];

class NavigationItem {
  final NavigationPage id;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavigationItem({
    required this.id,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
