import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/providers/test_basket_provider.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/services/word_book/word_tag_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/app_globals.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/test/test_page.dart';
import 'package:vidlang/views/word_book/test_manage_page.dart';
import 'package:vidlang/views/word_book/widgets/collection_detail_sheet.dart';
import 'package:vidlang/views/word_book/widgets/collection_word_card.dart';
import 'package:vidlang/views/word_book/widgets/collection_tag_manager.dart';
import 'package:vidlang/views/word_book/widgets/snippet_detail_sheet.dart';
import 'package:vidlang/views/word_book/widgets/snippet_list_card.dart';
import 'package:vidlang/views/word_book/widgets/word_book_nav_panel.dart';
import 'package:vidlang/views/word_book/widgets/word_card.dart';
import 'package:vidlang/views/word_book/camera_translate_page.dart';
import 'package:vidlang/components/ui/ui_components.dart';
import 'word_book_detail_sheet.dart';

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  int _currentTab = 0;
  List<WordBook> _words = [];
  List<WordBook> _allWords = [];
  List<WordBookNavItem> _learningNavItems = const [];
  List<WordBookNavItem> _masteredNavItems = const [];
  Map<String, List<WordTag>> _tagsByWordCode = const {};
  bool _loading = true;
  String _selectedStatus = 'learning';
  String? _selectedTagCode;
  final TextEditingController _searchController = TextEditingController();
  int _todayReviewed = 0;
  int _totalWords = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isKnowledgeBase => _currentTab == 1;
  String get _currentContentType => _isKnowledgeBase ? 'sentence' : 'word';

  /// Tab 标题映射
  String get _mainTitle => '我的收藏';
  String get _tab0Label => '单词';
  String get _tab1Label => '短语';

  /// 获取测试篮状态
  TestBasketState get _basketState => ref.watch(testBasketProvider);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _reload();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final keyword = _searchController.text.trim().toLowerCase();
    setState(() {
      if (keyword.isEmpty) {
        _words = List.from(_allWords);
      } else {
        _words = _allWords.where((w) {
          return w.word.toLowerCase().contains(keyword) ||
              (w.contextSentence?.toLowerCase().contains(keyword) ?? false) ||
              (w.note?.toLowerCase().contains(keyword) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      // 根据当前 contentType 加载对应的导航数据
      final learningItems = await WordBookService.loadNavItems(
        'learning',
        contentType: _currentContentType,
      );
      final masteredItems = await WordBookService.loadNavItems(
        'mastered',
        contentType: _currentContentType,
      );
      final rows = await WordBookService.queryWords(
        WordBookFilter(
          status: _selectedStatus,
          tagCode: _selectedTagCode,
          contentType: _currentContentType,
          keyword: _searchController.text.trim(),
        ),
      );
      final tags = await WordTagService.listTagsForWords(
        rows.map((word) => word.code).whereType<String>().toList(),
      );
      final todayReviewed = await WordBookService.countTodayReviewed();
      final totalWords = await WordBookService.countTotalWords();

      if (!mounted) return;
      setState(() {
        _learningNavItems = learningItems;
        _masteredNavItems = masteredItems;
        _allWords = rows;
        final keyword = _searchController.text.trim().toLowerCase();
        if (keyword.isEmpty) {
          _words = List.from(rows);
        } else {
          _words = rows.where((w) {
            return w.word.toLowerCase().contains(keyword) ||
                (w.contextSentence?.toLowerCase().contains(keyword) ?? false) ||
                (w.note?.toLowerCase().contains(keyword) ?? false);
          }).toList();
        }
        _tagsByWordCode = tags;
        _todayReviewed = todayReviewed;
        _totalWords = totalWords;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onTabChanged(int tab) {
    if (tab == _currentTab) return;
    setState(() {
      _currentTab = tab;
      _selectedStatus = 'learning';
      _selectedTagCode = null;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colors;
    final brightness = Theme.of(context).brightness;
    final isPad = AppGlobals.isTablet;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
      drawer: !isPad ? _buildDrawer(context) : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ 全局标题栏 ═══
            Container(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
              padding: EdgeInsets.fromLTRB(
                adaptive.Adaptive.r(16),
                adaptive.Adaptive.h(12),
                adaptive.Adaptive.r(16),
                adaptive.Adaptive.h(14),
              ),
              child: Row(
                children: [
                  // ── 左侧按钮：iPad 返回 / iPhone 菜单 ──
                  if (isPad)
                    Padding(
                      padding: EdgeInsets.only(right: adaptive.Adaptive.w(4)),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(AppIcons.arrowBack),
                        constraints: BoxConstraints(
                          minWidth: adaptive.Adaptive.w(36),
                          minHeight: adaptive.Adaptive.h(36),
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: '返回',
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.only(right: adaptive.Adaptive.w(4)),
                      child: IconButton(
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(AppIcons.menu),
                        constraints: BoxConstraints(
                          minWidth: adaptive.Adaptive.w(36),
                          minHeight: adaptive.Adaptive.h(36),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  Text(
                    _mainTitle,
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(22),
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(width: adaptive.Adaptive.w(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: adaptive.Adaptive.w(8),
                      vertical: adaptive.Adaptive.h(3),
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        adaptive.Adaptive.r(999),
                      ),
                    ),
                    child: Text(
                      '${_allWords.length}${_isKnowledgeBase ? "句" : "词"}',
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(13),
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '今日 $_todayReviewed/$_totalWords',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(12),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // ═══ 主内容区域 ═══
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : isPad
                      ? _buildSplitLayout(context, colorScheme)
                      : _buildPhoneLayout(context, colorScheme),
            ),
          ],
        ),
      ),
      // 右下角悬浮 FAB（测试篮入口）
      floatingActionButton: _buildBasketFAB(colorScheme),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 布局构建方法
  // ═══════════════════════════════════════════════════════════════

  /// iPad 左右分栏布局
  Widget _buildSplitLayout(BuildContext context, AppColorsData colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 左侧导航面板 ──
        SizedBox(
          width: adaptive.Adaptive.w(240),
          height: double.infinity,
          child: _buildNavPanel(),
        ),

        SizedBox(width: adaptive.Adaptive.w(16)),

        // ── 右侧内容区 ──
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab 切换 + 搜索框（在右侧内容区内）
              Padding(
                padding: EdgeInsets.fromLTRB(
                  adaptive.Adaptive.r(0),
                  adaptive.Adaptive.h(12),
                  adaptive.Adaptive.r(0),
                  adaptive.Adaptive.h(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabBar(colorScheme),
                    SizedBox(height: adaptive.Adaptive.h(8)),
                    _buildSearchBar(colorScheme),
                  ],
                ),
              ),

              // 单词列表
              Expanded(
                child: _words.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : _buildWordList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// iPhone 上下布局
  Widget _buildPhoneLayout(BuildContext context, AppColorsData colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab 切换 + 搜索框
        Padding(
          padding: EdgeInsets.fromLTRB(
            adaptive.Adaptive.r(16),
            adaptive.Adaptive.h(12),
            adaptive.Adaptive.r(16),
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTabBar(colorScheme),
              SizedBox(height: adaptive.Adaptive.h(8)),
              _buildSearchBar(colorScheme),
            ],
          ),
        ),

        // 单词列表
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              adaptive.Adaptive.r(16),
              adaptive.Adaptive.h(12),
              adaptive.Adaptive.r(16),
              adaptive.Adaptive.h(8),
            ),
            child: _words.isEmpty
                ? _buildEmptyState(colorScheme)
                : _buildWordList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      width: adaptive.Adaptive.w(280),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(adaptive.Adaptive.r(12)),
          child: _buildNavPanel(),
        ),
      ),
    );
  }

  Widget _buildTabBar(AppColorsData cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(10)),
      ),
      padding: EdgeInsets.all(adaptive.Adaptive.r(3)),
      child: Row(
        children: [
          _buildTabChip(_tab0Label, AppIcons.spellcheck, 0, cs),
          SizedBox(width: adaptive.Adaptive.w(3)),
          _buildTabChip(_tab1Label, AppIcons.libraryBooks, 1, cs),
        ],
      ),
    );
  }

  Widget _buildTabChip(
    String label,
    IconData icon,
    int tabIndex,
    AppColorsData cs,
  ) {
    final selected = _currentTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(tabIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(8)),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(8)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: adaptive.Adaptive.sp(16),
                color: selected ? AppColors.onPrimary : cs.onSurfaceVariant,
              ),
              SizedBox(width: adaptive.Adaptive.w(4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(13),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppColorsData cs) {
    final hint = _isKnowledgeBase ? '搜索句子或备注' : '搜索单词或上下文';
    final hasText = _searchController.text.isNotEmpty;
    final isIOS = Platform.isIOS;

    Widget? suffix;
    if (hasText) {
      suffix = IconButton(
        onPressed: () => _searchController.clear(),
        icon: const Icon(AppIcons.close),
      );
    } else if (isIOS && !_isKnowledgeBase) {
      suffix = IconButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CameraTranslatePage()),
          );
          if (mounted) await _reload();
        },
        icon: const Icon(AppIcons.cameraAlt),
      );
    }

    return TextField(
      controller: _searchController,
      onSubmitted: (_) => _handleSearchSubmit(),
      style: TextStyle(fontSize: adaptive.Adaptive.sp(16), color: cs.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: adaptive.Adaptive.sp(15),
          color: cs.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          AppIcons.search,
          size: adaptive.Adaptive.icon(22),
          color: cs.onSurfaceVariant,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: cs.surfaceContainerLow,
        contentPadding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(14),
          vertical: adaptive.Adaptive.h(14),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(14)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _handleSearchSubmit() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty || _isKnowledgeBase) return;
    final wordPattern = RegExp(r"^[a-zA']+$");
    if (!wordPattern.hasMatch(keyword)) return;
    if (!mounted) return;
    await WordCard.show(
      context,
      word: keyword,
      sourceType: 'word_book',
      sourceCode: '',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 悬浮 FAB（测试篮入口）
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBasketFAB(AppColorsData cs) {
    final count = _basketState.count;
    return FloatingActionButton(
      onPressed: () => _handleFABTap(context),
      backgroundColor: cs.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(AppIcons.quiz, size: adaptive.Adaptive.icon(24)),
          if (count > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: adaptive.Adaptive.w(18),
                  minHeight: adaptive.Adaptive.h(18),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: adaptive.Adaptive.w(5),
                  vertical: adaptive.Adaptive.h(2),
                ),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(999)),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: adaptive.Adaptive.sp(10),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 导航与列表相关方法
  // ═══════════════════════════════════════════════════════════════

  Widget _buildNavPanel() {
    return WordBookNavPanel(
      selectedStatus: _selectedStatus,
      selectedTagCode: _selectedTagCode,
      learningItems: _learningNavItems,
      masteredItems: _masteredNavItems,
      onSelect: (item) async {
        setState(() {
          _selectedStatus = item.status;
          _selectedTagCode = item.tagCode;
        });
        await _reload();
      },
    );
  }

  Widget _buildEmptyState(AppColorsData cs) {
    final message = _isKnowledgeBase ? '当前分类下暂无句子' : '当前分类下暂无单词';
    final hint = _isKnowledgeBase
        ? '在播放器或文章阅读时收藏句子即可加入知识库'
        : '在播放器里长按单词即可加入生词本';
    return EmptyState(
      icon: AppIcons.menuBook,
      title: message,
      description: hint,
    );
  }

  Widget _buildWordList() {
    return ListView.separated(
      itemCount: _words.length,
      separatorBuilder: (_, _) => SizedBox(height: adaptive.Adaptive.h(10)),
      itemBuilder: (context, index) {
        final item = _words[index];
        final tags = _tagsByWordCode[item.code] ?? const <WordTag>[];
        final isInBasket = _basketState.isSelected(item.code ?? '');

        if (_isKnowledgeBase) {
          return SnippetListCard(
            snippet: item,
            tags: tags,
            isInBasket: isInBasket,
            onTap: () => _handleItemTap(item),
            onTagTap: () => _editItemTags(item),
          );
        }
        return CollectionWordCard(
          word: item,
          tags: tags,
          isInBasket: isInBasket,
          onTap: () => _handleItemTap(item),
          onTagTap: () => _editItemTags(item),
        );
      },
    );
  }

  void _handleItemTap(WordBook item) {
    // 点击进入详情页（复习操作入口）
    if (_isKnowledgeBase) {
      _showSnippetDetail(item);
    } else if (AppGlobals.isTablet) {
      _showCollectionDetail(item);
    } else {
      _showWordDetail(item);
    }
  }

  // ── 详情弹窗 ──

  Future<void> _showWordDetail(WordBook word) async {
    final tags = _tagsByWordCode[word.code] ?? const <WordTag>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => WordBookDetailSheet(
        word: word,
        tags: tags,
        onRecognized: () async {
          Navigator.of(context).pop();
          await _handleMasteryChange(word, true);
        },
        onUnrecognized: () async {
          Navigator.of(context).pop();
          await _handleMasteryChange(word, false);
        },
        onDelete: word.isMastered
            ? () async {
                Navigator.of(context).pop();
                final ok = await WordBookService.softDeleteWord(word.code!);
                if (!ok || !mounted) return;
                await _reload();
              }
            : null,
      ),
    );
  }

  Future<void> _showSnippetDetail(WordBook snippet) async {
    final tags = _tagsByWordCode[snippet.code] ?? const <WordTag>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => SnippetDetailSheet(
        snippet: snippet,
        tags: tags,
        onRecognized: () async {
          Navigator.of(context).pop();
          await _handleMasteryChange(snippet, true);
        },
        onUnrecognized: () async {
          Navigator.of(context).pop();
          await _handleMasteryChange(snippet, false);
        },
        onDelete: snippet.isMastered
            ? () async {
                Navigator.of(context).pop();
                final ok = await WordBookService.softDeleteWord(snippet.code!);
                if (!ok || !mounted) return;
                await _reload();
              }
            : null,
        onNoteChanged: (note) async {
          snippet.note = note;
          // 使用 DatabaseService 更新备注
          // TODO: 添加 WordBookService.updateNote 方法
        },
        onEditTags: () async {
          Navigator.of(context).pop();
          await _editItemTags(snippet);
        },
      ),
    );
  }

  void _showCollectionDetail(WordBook word) {
    final tags = _tagsByWordCode[word.code] ?? const <WordTag>[];

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => CollectionDetailSheet(
        word: word,
        tags: tags,
        onClose: () => Navigator.of(context).pop(),
        onRecognized: () async {
          Navigator.of(context).pop();
          await _handleMasteryChange(word, true);
        },
        onUnrecognized: () async {
          Navigator.of(context).pop();
          await _handleMasteryChange(word, false);
        },
        onDelete: word.isMastered
            ? () async {
                Navigator.of(context).pop();
                final ok = await WordBookService.softDeleteWord(word.code!);
                if (!ok || !mounted) return;
                await _reload();
              }
            : null,
      ),
    );
  }

  Future<void> _handleMasteryChange(WordBook item, bool recognized) async {
    final code = item.code;
    if (code == null) return;
    final ok = await WordBookService.updateMastery(
      wordBookCode: code,
      recognized: recognized,
    );
    if (!ok || !mounted) return;
    await _reload();
  }

  Future<void> _editItemTags(WordBook item) async {
    final code = item.code;
    if (code == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CollectionTagManager(
        wordCode: code,
        currentTags: _tagsByWordCode[code] ?? const [],
      ),
    );
    await _reload();
  }

  // ═══════════════════════════════════════════════════════════════
  // 测试相关方法
  // ═══════════════════════════════════════════════════════════════

  /// 处理 FAB 点击（导航到测试管理页面）
  Future<void> _handleFABTap(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TestManagePage(),
      ),
    );
  }

  /// 导航到 TestPage（从测试篮获取数据）
  Future<void> _navigateToTest(BuildContext context) async {
    final basketState = ref.read(testBasketProvider);
    if (basketState.isEmpty) return;

    final seedWords = basketState.toSeedWords();

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TestPage(
          videoTitle: '我的收藏测试',
          seedWords: seedWords,
          testScope: TestScope.wordBook,
        ),
      ),
    );

    // 测试完成后清空测试篮并刷新
    if (changed == true && mounted) {
      ref.read(testBasketProvider.notifier).clear();
      await _reload();
    }
  }

}
