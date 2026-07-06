/// 资源管理页面
///
/// 展示3类资源的文件夹列表
/// 顶部：AppBar 标题 + 类型切换Tab + 搜索栏
/// 主体：网格文件夹卡片
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/components/folder_card.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/providers/file_provider.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/services/wifi_transfer_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/theme/app_radius.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/theme/app_typography.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/widgets/app_dialogs.dart';
import 'package:vidlang/views/files/folder_detail_page.dart';
import 'package:vidlang/views/files/wifi_transfer_page.dart';

class FileListPage extends ConsumerStatefulWidget {
  const FileListPage({super.key});

  @override
  ConsumerState<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends ConsumerState<FileListPage> {
  final TextEditingController _folderNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const _resourceTypes = ['video', 'music', 'article'];
  static const _resourceLabels = ['视频', '音频', '文章'];

  @override
  void dispose() {
    WifiTransferService.instance.removeListener(_onWifiChanged);
    _folderNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(fileProvider.notifier).loadFolders());
    WifiTransferService.instance.addListener(_onWifiChanged);
  }

  void _onWifiChanged() {
    if (!mounted) return;
    ref.read(fileProvider.notifier).refreshFoldersSilently();
  }

  int get _currentTab => ref.watch(resourceTabProvider);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fileProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
      appBar: AppBar(
        title: Text(
          '资源',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
        scrolledUnderElevation: 0.5,
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WifiTransferPage()),
              );
              if (!mounted) return;
              await ref.read(fileProvider.notifier).loadFolders();
            },
            icon: Icon(Icons.wifi_tethering_outlined, size: 22.sp),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 类型切换
              _buildTypeTabs(colorScheme),
              SizedBox(height: AppSpacing.sm),
              // 搜索栏
              _buildSearchBar(colorScheme),
              SizedBox(height: AppSpacing.md),
              // 文件夹列表
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildContent(colorScheme, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeTabs(ColorScheme colorScheme) {
    final currentTab = _currentTab;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(brightness: Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: EdgeInsets.all(5),
      child: Row(
        children: List.generate(_resourceTypes.length, (index) {
          final isSelected = index == currentTab;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(resourceTabProvider.notifier).state = index,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  _resourceLabels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: AppTypography.fontSizeSmall.sp,
      ),
      decoration: InputDecoration(
        hintText: '搜索${_resourceLabels[_currentTab]}...',
        hintStyle: TextStyle(
          color: AppColors.onSurfaceDisabled,
          fontSize: AppTypography.fontSizeSmall.sp,
        ),
        prefixIcon: Icon(
          AppIcons.search,
          size: 18.sp,
          color: colorScheme.onSurfaceVariant,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(
                  Icons.clear,
                  size: 18.sp,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.getSurfaceElevated(
          brightness: Theme.of(context).brightness,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  List<VideoFolder> _filteredFolders(List<VideoFolder> folders) {
    final currentType = _resourceTypes[_currentTab];
    var filtered = folders
        .where((f) => f.folderType.name == currentType)
        .toList();
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered
          .where((f) => f.name.toLowerCase().contains(q))
          .toList();
    }
    return filtered;
  }

  Widget _buildContent(ColorScheme colorScheme, FileState state) {
    final folders = _filteredFolders(state.folders);
    return folders.isEmpty
        ? _buildEmptyState(colorScheme)
        : _buildFolderGrid(folders);
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    final typeColor = AppColors.colorForType(
      _resourceTypes[_currentTab],
      brightness: Theme.of(context).brightness,
    );
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: typeColor.withValues(alpha: 0.06),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 48.sp,
              color: typeColor.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            _searchQuery.isNotEmpty
                ? '没有匹配的文件夹'
                : '暂无${_resourceLabels[_currentTab]}',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              '点击右上角 + 创建',
              style: TextStyle(
                fontSize: 14.sp,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFolderGrid(List<VideoFolder> folders) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.gridSpacing,
        mainAxisSpacing: AppSpacing.gridSpacing,
        childAspectRatio: 1.3,
      ),
      itemCount: folders.length + 1,
      itemBuilder: (context, index) {
        if (index == folders.length) {
          return _buildAddFolderCard();
        }
        final folder = folders[index];
        return FolderCard(
          folder: folder,
          onTap: () => _navigateToDetail(folder),
          onLongPress: () => _showFolderMenu(folder),
        );
      },
    );
  }

  Widget _buildAddFolderCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _showCreateFolderDialog,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          color: AppColors.getSurface(brightness: Theme.of(context).brightness),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Center(
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.add, size: 24.sp, color: colorScheme.primary),
              ),
            ),
            const Spacer(flex: 1),
            Padding(
              padding: EdgeInsets.only(bottom: 14.h),
              child: Text(
                '新建',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog() async {
    final colorScheme = Theme.of(context).colorScheme;
    final currentType = _resourceTypes[_currentTab];
    final typeLabel = _resourceLabels[_currentTab];
    _folderNameController.clear();

    final result = await AppConfirmDialog.show(
      context,
      title: '新建$typeLabel文件夹',
      content: '',
      confirmText: '创建',
      cancelText: '取消',
      contentWidget: TextField(
        controller: _folderNameController,
        autofocus: true,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: '文件夹名称',
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
    if (result == true) {
      final name = _folderNameController.text.trim();
      if (name.isEmpty) return;
      try {
        await ref
            .read(fileProvider.notifier)
            .createFolder(name, contentType: currentType);
      } catch (e) {
        _showMessage('Failed: $e', theme: MessageTheme.error);
      }
    }
  }

  Future<void> _navigateToDetail(VideoFolder folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderDetailPage(folderCode: folder.code!),
      ),
    );
    if (!mounted) return;
    await ref.read(fileProvider.notifier).loadFolders();
  }

  void _showFolderMenu(VideoFolder folder) async {
    await AppBottomSheetMenu.show(
      context,
      items: [
        AppBottomSheetMenuItem(
          text: '重命名',
          icon: Icons.edit_outlined,
          onTap: () => _showRenameDialog(folder),
        ),
        AppBottomSheetMenuItem(
          text: '删除',
          icon: Icons.delete_outline,
          destructive: true,
          onTap: () => _confirmDeleteFolder(folder),
        ),
      ],
    );
  }

  void _showRenameDialog(VideoFolder folder) async {
    final colorScheme = Theme.of(context).colorScheme;
    _folderNameController.text = folder.name;

    final result = await AppConfirmDialog.show(
      context,
      title: '重命名',
      content: '',
      confirmText: '保存',
      cancelText: '取消',
      contentWidget: TextField(
        controller: _folderNameController,
        autofocus: true,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
    if (result == true) {
      final name = _folderNameController.text.trim();
      if (name.isEmpty) return;
      try {
        folder.name = name;
        await folder.save();
        await ref.read(fileProvider.notifier).loadFolders();
      } catch (e) {
        _showMessage('Failed: $e', theme: MessageTheme.error);
      }
    }
  }

  void _confirmDeleteFolder(VideoFolder folder) async {
    final result = await AppConfirmDialog.show(
      context,
      title: '确认删除 "${folder.name}"?',
      content: '该文件夹内的所有资源将被删除。',
      confirmText: '删除',
      cancelText: '取消',
      destructive: true,
    );
    if (result == true) {
      await ref.read(fileProvider.notifier).deleteFolder(folder.code!);
    }
  }

  void _showMessage(String content, {MessageTheme theme = MessageTheme.info}) {
    final type = switch (theme) {
      MessageTheme.error => ToastType.error,
      MessageTheme.warning => ToastType.warning,
      MessageTheme.success => ToastType.success,
      _ => ToastType.info,
    };
    AppToast.show(context, content, type: type);
  }
}
