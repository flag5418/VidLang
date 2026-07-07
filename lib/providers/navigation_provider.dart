import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/theme/theme.dart';

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
    icon: AppIcons.home,
    activeIcon: AppIcons.home,
  ),
  NavigationItem(
    id: NavigationPage.resources,
    label: '资源',
    icon: AppIcons.folder,
    activeIcon: AppIcons.folder,
  ),
  NavigationItem(
    id: NavigationPage.wordBook,
    label: '收藏',
    icon: AppIcons.starBorder,
    activeIcon: AppIcons.star,
  ),
  NavigationItem(
    id: NavigationPage.profile,
    label: '我的',
    icon: AppIcons.person,
    activeIcon: AppIcons.person,
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
