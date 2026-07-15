/// 资源管理页面
///
/// 展示3类资源的文件夹列表
/// 顶部：AppBar 标题 + 类型切换Tab + 搜索栏
/// 主体：网格文件夹卡片
library;

import 'package:flutter/material.dart';import 'package:vidlang/components/ui/ui_components.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:vidlang/views/files/widgets/folder_card.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/video_folder.dart';
import 'package:vidlang/views/files/providers/file_provider.dart';
import 'package:vidlang/providers/navigation_provider.dart';
import 'package:vidlang/services/parsers/article_parser.dart';
import 'package:vidlang/services/ai/conversation_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/files/wifi_transfer_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/theme/app_radius.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/theme/app_typography.dart';
import 'package:vidlang/views/article/article_import_page.dart';
import 'package:vidlang/views/article/article_reader_page.dart';
import 'package:vidlang/components/dialogs/app_dialogs.dart';
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
  bool _isImporting = false;

  /// URL 正则：合法的 http/https 网址
  static final _urlRegExp = RegExp(
    r'^https?://[\w\-]+(\.[\w\-]+)+(:\d+)?(/[\w\-./?%&=+#@!~*(),;:]*)?$',
    caseSensitive: false,
  );

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
            fontSize: adaptive.Adaptive.sp(18),
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
            icon: Icon(AppIcons.wifiTethering, size: adaptive.Adaptive.sp(22)),
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
      padding: EdgeInsets.all(adaptive.Adaptive.w(5)),
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
                    fontSize: adaptive.Adaptive.sp(13),
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
    final isArticleTab = _resourceTypes[_currentTab] == 'article';
    final brightness = Theme.of(context).brightness;

    return TextField(
      controller: _searchController,
      keyboardType: isArticleTab ? TextInputType.url : TextInputType.text,
      onChanged: (v) => setState(() => _searchQuery = v),
      onSubmitted: isArticleTab && _searchQuery.trim().isNotEmpty
          ? (_) => _importFromUrl()
          : null,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeSmall),
      ),
      decoration: InputDecoration(
        hintText: isArticleTab
            ? '请输入链接'
            : '搜索${_resourceLabels[_currentTab]}...',
        hintStyle: TextStyle(
          color: AppColors.onSurfaceDisabled,
          fontSize: adaptive.Adaptive.sp(AppTypography.fontSizeSmall),
        ),
        prefixIcon: Icon(
          isArticleTab ? AppIcons.link : AppIcons.search,
          size: adaptive.Adaptive.sp(18),
          color: colorScheme.onSurfaceVariant,
        ),
        suffixIcon: _buildSearchSuffix(colorScheme, isArticleTab),
        filled: true,
        fillColor: AppColors.getSurface(brightness: brightness),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget? _buildSearchSuffix(ColorScheme colorScheme, bool isArticleTab) {
    // 导入中：显示加载动画
    if (_isImporting) {
      return Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(10)),
        child: SizedBox(
          width: adaptive.Adaptive.sp(16),
          height: adaptive.Adaptive.sp(16),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
      );
    }

    // 无输入：不显示后缀
    if (_searchQuery.isEmpty) return null;

    // 文章 Tab：显示「转入」按钮
    if (isArticleTab) {
      return Padding(
        padding: EdgeInsets.all(adaptive.Adaptive.w(5)),
        child: GestureDetector(
          onTap: _isImporting ? null : _importFromUrl,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: adaptive.Adaptive.w(14), vertical: adaptive.Adaptive.h(4)),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
            ),
            child: Text(
              '转入',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: adaptive.Adaptive.sp(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    // 视频/音频 Tab：显示清除按钮
    return GestureDetector(
      onTap: () {
        _searchController.clear();
        setState(() => _searchQuery = '');
      },
      child: Icon(
        AppIcons.clear,
        size: adaptive.Adaptive.sp(18),
        color: colorScheme.onSurfaceVariant,
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

  /// 从 URL 导入文章
  ///
  /// 调用 Supabase Edge Function（extract-article）提取网页正文，
  /// 通过 ArticleParser 解析后存入数据库，跳转 ArticleReaderPage。
  Future<void> _importFromUrl() async {
    final url = _searchQuery.trim();

    if (!_urlRegExp.hasMatch(url)) {
      _showSnackBar('请输入有效的网址（以 http:// 或 https:// 开头）');
      return;
    }

    setState(() => _isImporting = true);

    try {
      // 调用 Edge Function 提取正文
      final client = sb.Supabase.instance.client;
      final resp = await client.functions.invoke(
        'extract-article',
        body: {'url': url},
      );
      final data = resp.data as Map<String, dynamic>?;

      if (data == null || data['ok'] != true) {
        final msg = data?['message'] as String? ?? '提取失败，请尝试手动复制粘贴';
        setState(() => _isImporting = false);
        _showSnackBarWithAction(msg, '手动复制', () {
          _searchController.clear();
          setState(() => _searchQuery = '');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArticleImportPage()),
          );
        });
        return;
      }

      final title = (data['title'] as String?) ?? '未命名文章';
      final textContent = (data['textContent'] as String?) ?? '';

      if (textContent.isEmpty) {
        setState(() => _isImporting = false);
        _showSnackBarWithAction('提取到的文章内容为空', '手动复制', () {
          _searchController.clear();
          setState(() => _searchQuery = '');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArticleImportPage()),
          );
        });
        return;
      }

      // 复用现有 ArticleParser 解析并保存
      final parsed = ArticleParser.parse(title: title, content: textContent);

      await DatabaseService.insert(parsed.article);
      final articleCode = parsed.article.code!;

      for (final s in parsed.sentences) {
        s.articleCode = articleCode;
      }
      for (final p in parsed.paragraphs) {
        p.articleCode = articleCode;
      }

      if (parsed.sentences.isNotEmpty) {
        await DatabaseService.batchInsert(parsed.sentences);
      }
      if (parsed.paragraphs.isNotEmpty) {
        await DatabaseService.batchInsert(parsed.paragraphs);
      }

      try {
        await ConversationService.uploadArticleContentToCloud(
          articleCode,
          folderCode: parsed.article.folderCode,
        );
      } catch (_) {}

      if (!mounted) return;

      setState(() => _isImporting = false);
      _searchController.clear();
      setState(() => _searchQuery = '');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleReaderPage(articleCode: articleCode),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      _showSnackBarWithAction('导入失败: $e', '手动复制', () {
        _searchController.clear();
        setState(() => _searchQuery = '');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArticleImportPage()),
        );
      });
    }
  }

  void _showSnackBar(String message) {
    // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
    TDToast.showText(message, context: context);
  }

  void _showSnackBarWithAction(
    String message,
    String actionLabel,
    VoidCallback onAction,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
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
  final title = _searchQuery.isNotEmpty
      ? '没有匹配的文件夹'
      : '暂无${_resourceLabels[_currentTab]}';
  final description = _searchQuery.isEmpty ? '点击右上角 + 创建' : null;

  return EmptyState(
    icon: AppIcons.folderOpen,
    title: title,
    description: description,
    iconBackgroundColor: typeColor.withValues(alpha: 0.08),
    iconColor: typeColor.withValues(alpha: 0.6),
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
                width: adaptive.Adaptive.w(40),
                height: adaptive.Adaptive.w(40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  AppIcons.add,
                  size: adaptive.Adaptive.sp(24),
                  color: colorScheme.primary,
                ),
              ),
            ),
            const Spacer(flex: 1),
            Padding(
              padding: EdgeInsets.only(bottom: adaptive.Adaptive.h(14)),
              child: Text(
                '新建',
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(13),
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
          icon: AppIcons.edit,
          onTap: () => _showRenameDialog(folder),
        ),
        AppBottomSheetMenuItem(
          text: '删除',
          icon: AppIcons.delete,
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
