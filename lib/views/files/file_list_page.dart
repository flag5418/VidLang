/// 资源管理页面
///
/// 展示3类资源（视频/文章/音频）的文件夹列表
/// 顶部：类型切换SegmentedControl + 搜索栏
/// 主体：网格文件夹卡片
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:vidlang/components/folder_card.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/providers/file_provider.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/theme/app_typography.dart';
import 'package:vidlang/views/files/folder_detail_page.dart';
import 'package:vidlang/views/files/wifi_transfer_page.dart';

/// 资源管理页面
///
/// 通过类型Tab筛选显示不同类别的文件夹，
/// 支持创建、搜索、WiFi传输等功能。
class FileListPage extends ConsumerStatefulWidget {
  const FileListPage({super.key});

  @override
  ConsumerState<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends ConsumerState<FileListPage> with SingleTickerProviderStateMixin {
  final TextEditingController _folderNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final bool _isImporting = false;
  final int _importCurrent = 0;
  final int _importTotal = 0;

  /// 资源类型标签
  static const _resourceTypes = ['video', 'article', 'music'];
  static const _resourceLabels = ['视频', '文章', '音频'];
  // static const _resourceIcons = [Icons.videocam, Icons.article, Icons.headphones];

  @override
  void dispose() {
    _folderNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(fileProvider.notifier).loadFolders());
  }

  int get _currentTab => ref.watch(resourceTabProvider);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fileProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部标题 + 按钮
              _buildHeader(colorScheme),
              SizedBox(height: AppSpacing.sm),
              // 类型切换 + 搜索
              _buildTypeBar(colorScheme),
              SizedBox(height: AppSpacing.md),
              // 综合测试按钮
              _buildTestButton(colorScheme),
              SizedBox(height: AppSpacing.sm),
              // 文件夹列表
              Expanded(
                child: state.isLoading || _isImporting
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            if (_isImporting && _importTotal > 0) ...[
                              SizedBox(height: AppSpacing.md),
                              Text('正在导入 $_importCurrent / $_importTotal', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                            ],
                          ],
                        ),
                      )
                    : _buildContent(colorScheme, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              '资源',
              style: TextStyle(fontSize: AppTypography.fontSizeLarge, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
            ),
            SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(
                '${_filteredFolders(ref.watch(fileProvider).folders).length}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.primary),
              ),
            ),
          ],
        ),
        Row(
          children: [
            // 综合测试入口
            GestureDetector(
              onTap: () => _showComprehensiveTest(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.green.withValues(alpha: 0.15)),
                child: Icon(Icons.quiz, color: Colors.green, size: 20),
              ),
            ),
            SizedBox(width: AppSpacing.space2),
            // WiFi 传输
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WifiTransferPage())),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: AppColors.surfaceElevated),
                child: AppIcons.getIcon(Icons.wifi_find, color: colorScheme.onSurfaceVariant, size: 20),
              ),
            ),
            SizedBox(width: AppSpacing.space2),
            // 添加按钮
            GestureDetector(
              onTap: _showAddMenu,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: colorScheme.primary),
                child: AppIcons.getIcon(AppIcons.add, color: colorScheme.onPrimary, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeBar(ColorScheme colorScheme) {
    final currentTab = _currentTab;

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.surfaceElevated),
      child: Column(
        children: [
          // 类型切换
          Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: List.generate(_resourceTypes.length, (index) {
                final isSelected = index == currentTab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ref.read(resourceTabProvider.notifier).state = index;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? colorScheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon removed - text only tab
                          Text(
                            _resourceLabels[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: colorScheme.onSurface, fontSize: AppTypography.fontSizeSmall),
              decoration: InputDecoration(
                hintText: '搜索${_resourceLabels[_currentTab]}...',
                hintStyle: TextStyle(color: AppColors.onSurfaceDisabled, fontSize: AppTypography.fontSizeSmall),
                prefixIcon: AppIcons.getIcon(AppIcons.search, size: 18, color: AppColors.onSurfaceDisabled),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.clear, size: 18, color: AppColors.onSurfaceDisabled),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5), width: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: _showComprehensiveTest,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: [Colors.green.withValues(alpha: 0.15), Colors.teal.withValues(alpha: 0.08)]),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.quiz, color: Colors.green, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '综合测试',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  Text('综合测试', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  List<VideoFolder> _filteredFolders(List<VideoFolder> folders) {
    final currentType = _resourceTypes[_currentTab];
    // 先按类型过滤
    var filtered = folders.where((f) => f.folderType.name == currentType).toList();
    // 再按搜索词过滤
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((f) => f.name.toLowerCase().contains(q)).toList();
    }
    return filtered;
  }

  Widget _buildContent(ColorScheme colorScheme, FileState state) {
    final folders = _filteredFolders(state.folders);

    return folders.isEmpty ? _buildEmptyState(colorScheme, _searchQuery.isNotEmpty) : _buildFolderGrid(folders);
  }

  Widget _buildEmptyState(ColorScheme colorScheme, bool isSearch) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSearch ? Icons.search_off : Icons.folder_outlined, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          SizedBox(height: AppSpacing.md),
          Text(isSearch ? '没有匹配的文件夹' : '暂无${_resourceLabels[_currentTab]}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          if (!isSearch) ...[SizedBox(height: AppSpacing.sm), Text('点击右上角 + 创建第一个文件夹', style: TextStyle(fontSize: 13, color: colorScheme.outline))],
        ],
      ),
    );
  }

  Widget _buildFolderGrid(List<VideoFolder> folders) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 600 ? 4 : (screenWidth > 400 ? 3 : 2);
    final aspectRatio = crossAxisCount == 2 ? 1.3 : (crossAxisCount == 3 ? 1.15 : 1.0);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      itemCount: folders.length + 1,
      itemBuilder: (context, index) {
        if (index == folders.length) {
          return _buildAddFolderCard();
        }
        final folder = folders[index];
        return FolderCard(folder: folder, onTap: () => _navigateToDetail(folder), onLongPress: () => _showFolderMenu(folder));
      },
    );
  }

  Widget _buildAddFolderCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _showCreateFolderDialog,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surfaceElevated,
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.onSurfaceDisabled, width: 2),
              ),
              child: Icon(Icons.add, size: 22, color: AppColors.onSurfaceDisabled),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '新建',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceDisabled, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMenu() {
    // 直接弹出创建对话框，预设当前类型
    _showCreateFolderDialog();
  }

  void _showCreateFolderDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    final currentType = _resourceTypes[_currentTab];
    final typeLabel = _resourceLabels[_currentTab];
    _folderNameController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('新建$typeLabel文件夹', style: TextStyle(color: colorScheme.onSurface)),
        content: TextField(
          controller: _folderNameController,
          autofocus: true,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: '文件夹名称',
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              final name = _folderNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final folder = await ref.read(fileProvider.notifier).createFolder(name, contentType: currentType);
              } catch (e) {
                _showMessage('Failed: $e', theme: MessageTheme.error);
              }
            },
            child: Text('创建', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(VideoFolder folder) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FolderDetailPage(folderCode: folder.code!)));
  }

  void _showFolderMenu(VideoFolder folder) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: colorScheme.outlineVariant),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: colorScheme.onSurfaceVariant),
              title: Text('重命名', style: TextStyle(color: colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.quiz_outlined, color: Colors.green),
              title: Text('单元测试', style: TextStyle(color: colorScheme.onSurface)),
              subtitle: Text('测试文件夹内所有资源', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              onTap: () {
                Navigator.pop(ctx);
                _showUnitTest(folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colorScheme.error),
              title: Text('删除', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteFolder(folder);
              },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(VideoFolder folder) {
    final colorScheme = Theme.of(context).colorScheme;
    _folderNameController.text = folder.name;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('重命名', style: TextStyle(color: colorScheme.onSurface)),
        content: TextField(
          controller: _folderNameController,
          autofocus: true,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () async {
              final name = _folderNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                folder.name = name;
                await folder.save();
                await ref.read(fileProvider.notifier).loadFolders();
              } catch (e) {
                _showMessage('Failed: $e', theme: MessageTheme.error);
              }
            },
            child: Text('保存', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(VideoFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: Text('All resources in this folder will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(fileProvider.notifier).deleteFolder(folder.code!);
            },
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showComprehensiveTest() {
    final type = _resourceTypes[_currentTab];
    final label = _resourceLabels[_currentTab];
    _showMessage('Comprehensive test for $label coming soon', theme: MessageTheme.info);
  }

  void _showUnitTest(VideoFolder folder) {
    _showMessage('单元测试 "${folder.name}" coming soon', theme: MessageTheme.info);
  }

  void _showMessage(String content, {MessageTheme theme = MessageTheme.info}) {
    TDMessage.showMessage(context: context, content: content, visible: true, icon: true, theme: theme, duration: 3000);
  }
}
