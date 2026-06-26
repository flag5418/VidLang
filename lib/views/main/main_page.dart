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

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _hasCheckedModels = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    
    // 延迟检查模型状态，避免阻塞UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkModelStatus();
    });
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
        color: colorScheme.surface,
        padding: EdgeInsets.zero,
        child: SafeArea(
          child: Row(
            children: [
              ...navigationItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isActive = currentIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onTabTapped(index),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Icon(
                              isActive ? item.activeIcon : item.icon, 
                              color: isActive ? AppColors.iconActive : AppColors.iconDefault, 
                              size: 26.w
                            ),
                          ),
                          SizedBox(height: 4.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                color: isActive ? AppColors.iconActive : AppColors.iconDefault,
                              ),
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
      ),
    );
  }
}
