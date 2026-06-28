library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/services/local_model_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/views/files/file_list_page.dart';
import 'package:vidlang/views/home/home_page.dart';
import 'package:vidlang/views/profile/profile_page.dart';
import 'package:vidlang/views/word_book/collection_page.dart';
import 'package:vidlang/widgets/model_download_dialog.dart';

/// 主页面 - 基于 Pencil UI Design Skill 重构
/// 
/// 改进点：
/// - 底部导航栏使用统一的颜色和间距规范
/// - 添加页面切换动画
/// - 导航项组件化，便于维护
/// - 支持安全区域适配
class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;
  bool _hasCheckedModels = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    
    // Pencil Skill: 页面切换动画控制器
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300), // Pencil Skill: 正常动画时长
      vsync: this,
    );
    
    // 延迟检查模型状态，避免阻塞UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkModelStatus();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// 检查模型状态，如果需要下载则显示弹窗
  Future<void> _checkModelStatus() async {
    if (_hasCheckedModels) return;
    _hasCheckedModels = true;
    
    try {
      final localModelService = LocalModelService.instance;
      final status = await localModelService.checkModelsStatus();
      
      debugPrint('=== 模型状态检查 ===');
      debugPrint('状态: $status');
      debugPrint('shouldShowDownloadDialog: ${status.shouldShowDownloadDialog}');
      debugPrint('canUseAiFeatures: ${status.canUseAiFeatures}');
      
      // 如果需要下载模型，显示弹窗
      if (status.shouldShowDownloadDialog && mounted) {
        debugPrint('显示下载弹窗，状态: $status');
        // 延迟显示弹窗，确保页面完全加载
        await Future.delayed(Duration(milliseconds: 500));
        
        if (mounted) {
          await ModelDownloadDialog.show(
            context,
            forceShow: status == LocalModelStatus.missing, // 缺少模型时强制下载
            onDownloadComplete: () {
              // 下载完成后刷新状态
              localModelService.reset();
            },
          );
        }
      }
    } catch (e) {
      debugPrint('检查模型状态失败: $e');
    }
  }


  /// 切换Tab（带动画）
  void _onTabTapped(int index) {
    if (_currentPage == index) return;
    
    // Pencil Skill: 使用 easeInOutCubic 缓动曲线
    _pageController.animateToPage(
      index, 
      duration: Duration(milliseconds: 300), // Pencil Skill: 正常动画时长
      curve: Curves.easeInOutCubic,
    );
    ref.read(navigationIndexProvider.notifier).setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final theme = Theme.of(context);

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
      // Pencil Skill: 使用自定义底部导航栏，统一设计规范
      bottomNavigationBar: _buildBottomNavBar(currentIndex, theme),
    );
  }

  /// 构建底部导航栏（Pencil Skill 规范）
  Widget _buildBottomNavBar(int currentIndex, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        // Pencil Skill: 顶部边框分隔线
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: List.generate(navigationItems.length, (index) {
            final item = navigationItems[index];
            final isActive = currentIndex == index;
            
            return Expanded(
              child: _NavItem(
                item: item,
                isActive: isActive,
                onTap: () => _onTabTapped(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// 导航项组件（Pencil Skill 规范）
class _NavItem extends StatelessWidget {
  final NavigationItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200), // Pencil Skill: 快速动画
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pencil Skill: 图标使用 Material Symbols Rounded 风格
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 26.w,
              color: isActive ? AppColors.primaryBrand : AppColors.textTertiary, // Pencil Skill: 使用品牌色和三级文本色
            ),
            SizedBox(height: 4.h),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primaryBrand : AppColors.textTertiary, // Pencil Skill: 统一颜色规范
              ),
            ),
          ],
        ),
      ),
    );
  }
}
