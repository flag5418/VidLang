library;

import 'dart:io';import 'package:vidlang/utils/adaptive.dart' as adaptive;


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/services/word_tag_service.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/views/test/test_page.dart';
import 'package:vidlang/views/word_book/camera_translate_page.dart';
import 'package:vidlang/views/word_book/widgets/snippet_detail_sheet.dart';
import 'package:vidlang/views/word_book/widgets/snippet_list_card.dart';
import 'package:vidlang/views/word_book/widgets/word_book_list_card.dart';
import 'package:vidlang/views/word_book/widgets/word_book_nav_panel.dart';
import 'package:vidlang/widgets/word_card.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/theme.dart';


import 'word_book_detail_sheet.dart';
import 'word_book_review_page.dart';

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage>
    with TickerProviderStateMixin {
  // Tab: 0 = 单词, 1 = 知识库
  int _currentTab = 0;

  List<WordBook> _words = [];
  List<WordBook> _allWords = [];
  List<WordBookNavItem> _learningNavItems = const [];
  List<WordBookNavItem> _masteredNavItems = const [];
  Map<String, List<WordTag>> _tagsByWordCode = const {};
  bool _loading = true;
  String _selectedStatus = 'learning';
  String? _selectedTagCode;
  String _selectionAction = 'test';
  bool _selectionMode = false;
  final Set<String> _selectedWordCodes = <String>{};
  final TextEditingController _searchController = TextEditingController();
  int _todayReviewed = 0;
  int _totalWords = 0;

  /// 窄屏时控制 Drawer 的 Key
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isKnowledgeBase => _currentTab == 1;

  String get _currentContentType => _isKnowledgeBase ? 'sentence' : 'word';

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

  /// 实时模糊过滤：在本地列表中筛选，不做数据库查询
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
      final learningItems = _isKnowledgeBase
          ? await WordBookService.loadNavItemsForKnowledgeBase('learning')
          : await WordBookService.loadNavItems('learning');
      final masteredItems = _isKnowledgeBase
          ? await WordBookService.loadNavItemsForKnowledgeBase('mastered')
          : await WordBookService.loadNavItems('mastered');

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
        // 应用当前搜索过滤
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
      _selectedWordCodes.clear();
      _selectionMode = false;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colors;
    final brightness = Theme.of(context).brightness;
    final isNarrow = !context.ipad; // iPhone 下使用 Drawer 布局，iPad 使用侧边栏布局

    return GestureDetector(
      onTap: _selectionMode ? _cancelSelection : null,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
        drawer: isNarrow ? _buildDrawer(context) : null,
        bottomNavigationBar: _selectionMode
            ? _buildSelectionBar(context)
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 头部区：独立背景层，与其他区域视觉分离 ──
              Container(
                color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                padding: EdgeInsets.fromLTRB(
                  adaptive.Adaptive.r(context, 16),
                  adaptive.Adaptive.h(context, 12),
                  adaptive.Adaptive.r(context, 16),
                  adaptive.Adaptive.h(context, 14),
                ),
                child: _buildHeader(context, isNarrow),
              ),
              // ── Tab + 搜索：紧凑工具栏层 ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  adaptive.Adaptive.r(context, 16),
                  adaptive.Adaptive.h(context, 12),
                  adaptive.Adaptive.r(context, 16),
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTabBar(context),
                    SizedBox(height: adaptive.Adaptive.h(context, 8)),
                    _buildSearchBar(context),
                  ],
                ),
              ),
              // ── 选择模式提示 ──
              if (_selectionMode)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.Adaptive.r(context, 16),
                    vertical: adaptive.Adaptive.h(context, 6),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: adaptive.Adaptive.w(context, 12),
                      vertical: adaptive.Adaptive.h(context, 8),
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(
                        adaptive.Adaptive.r(context, 10),
                      ),
                    ),
                    child: Text(
                      '已选择 ${_selectedWordCodes.length}/${_words.length}，点击下方按钮开始，或点击任意位置取消',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(context, 12),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              // ── 列表区：占满剩余空间 ──（使用 TDesign TDLoading 替换 CircularProgressIndicator）
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          adaptive.Adaptive.r(context, 16),
                          adaptive.Adaptive.h(context, 12),
                          adaptive.Adaptive.r(context, 16),
                          adaptive.Adaptive.h(context, 8),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide =
                                constraints.maxWidth >=
                                adaptive.Adaptive.w(context, 900);
                            if (wide) {
                              return Row(
                                children: [
                                  SizedBox(
                                    width: adaptive.Adaptive.w(context, 240),
                                    child: _buildNavPanel(),
                                  ),
                                  SizedBox(width: adaptive.Adaptive.w(context, 16)),
                                  Expanded(
                                    child: _words.isEmpty
                                        ? _buildEmptyState(context)
                                        : _buildWordList(),
                                  ),
                                ],
                              );
                            }
                            return _words.isEmpty
                                ? _buildEmptyState(context)
                                : _buildWordList();
                          },
                        ),
                      ),
              ),
              // ── 功能按钮行：固定在列表底部，无单词时隐藏 ──
              if (!_selectionMode && _allWords.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.Adaptive.r(context, 16),
                    vertical: adaptive.Adaptive.h(context, 10),
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                  child: _buildActionBar(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedWordCodes.clear();
    });
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      width: adaptive.Adaptive.w(context, 280),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(adaptive.Adaptive.r(context, 12)),
          child: _buildNavPanel(),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isNarrow) {
    final colorScheme = context.colors;
    final title = _isKnowledgeBase ? '知识库' : '生词本';
    final unitLabel = _isKnowledgeBase ? '句' : '词';

    return Row(
      children: [
        if (isNarrow)
          Padding(
            padding: EdgeInsets.only(right: adaptive.Adaptive.w(context, 4)),
            child: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(AppIcons.menu),
              tooltip: '导航',
              constraints: BoxConstraints(
                minWidth: adaptive.Adaptive.w(context, 36),
                minHeight: adaptive.Adaptive.h(context, 36),
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        Text(
          title,
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(context, 22),
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(width: adaptive.Adaptive.w(context, 8)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: adaptive.Adaptive.w(context, 8),
            vertical: adaptive.Adaptive.h(context, 3),
          ),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 999)),
          ),
          child: Text(
            '${_allWords.length}$unitLabel',
            style: TextStyle(
              fontSize: adaptive.Adaptive.sp(context, 13),
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ),
        const Spacer(),
        Text(
          '今日 $_todayReviewed/$_totalWords',
          style: TextStyle(
            fontSize: adaptive.Adaptive.sp(context, 12),
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final colorScheme = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 10)),
      ),
      padding: EdgeInsets.all(adaptive.Adaptive.r(context, 3)),
      child: Row(
        children: [
          _buildTabChip(context, '单词', AppIcons.spellcheck, 0),
          SizedBox(width: adaptive.Adaptive.w(context, 3)),
          _buildTabChip(context, '知识库', AppIcons.libraryBooks, 1),
        ],
      ),
    );
  }

  Widget _buildTabChip(
    BuildContext context,
    String label,
    IconData icon,
    int tabIndex,
  ) {
    final colorScheme = context.colors;
    final selected = _currentTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(tabIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(context, 8)),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 8)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: adaptive.Adaptive.sp(context, 16),
                color: selected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: adaptive.Adaptive.w(context, 4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(context, 13),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = context.colors;
    final hint = _isKnowledgeBase ? '搜索句子或备注' : '搜索单词或上下文';
    final hasText = _searchController.text.isNotEmpty;
    final isIOS = Platform.isIOS;

    Widget? suffix;
    if (hasText) {
      suffix = IconButton(
        onPressed: () {
          _searchController.clear();
        },
        icon: const Icon(AppIcons.close),
      );
    } else if (isIOS && !_isKnowledgeBase) {
      suffix = IconButton(
        onPressed: _handleCameraTranslate,
        icon: const Icon(AppIcons.cameraAlt),
      );
    }

    return TextField(
      controller: _searchController,
      onSubmitted: (_) => _handleSearchSubmit(),
      style: TextStyle(
        fontSize: adaptive.Adaptive.sp(context, 16),
        color: colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: adaptive.Adaptive.sp(context, 15),
          color: colorScheme.onSurfaceVariant,
        ),
        prefixIcon: Icon(
          AppIcons.search,
          size: adaptive.Adaptive.icon(context, 22),
          color: colorScheme.onSurfaceVariant,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(context, 14),
          vertical: adaptive.Adaptive.h(context, 14),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 14)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// 搜索提交：始终对输入的英文单词弹出翻译弹窗
  Future<void> _handleSearchSubmit() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    // 知识库 Tab 不触发查词
    if (_isKnowledgeBase) return;

    // 非英文单词模式 → 不触发
    final wordPattern = RegExp(r"^[a-zA-Z']+$");
    if (!wordPattern.hasMatch(keyword)) return;

    // 弹出翻译弹窗（复用 WordCard 组件，付费模式由组件内部自主判定）
    if (!mounted) return;
    await WordCard.show(
      context,
      word: keyword,
      onSpeak: () => _speakWord(keyword),
      sourceType: 'word_book',
      sourceCode: '',
    );
  }

  Future<void> _speakWord(String word) async {
    TtsService().speakWord(word);
  }

  /// 功能按钮行：测试、复习
  Widget _buildActionBar(BuildContext context) {
    final colorScheme = context.colors;
    final isPremium =
        ref.watch(subscriptionProvider).mode == SubscriptionMode.premium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_isKnowledgeBase && isPremium) ...[
          FilledButton.icon(
            onPressed: () => _enterSelectionMode('test'),
            icon: Icon(AppIcons.quiz, size: adaptive.Adaptive.icon(context, 18)),
            label: const Text('测试'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.tertiaryContainer,
              foregroundColor: colorScheme.onTertiaryContainer,
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.Adaptive.w(context, 16),
                vertical: adaptive.Adaptive.h(context, 10),
              ),
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(context, 12)),
        ],
        FilledButton.icon(
          onPressed: () => _enterSelectionMode('review'),
          icon: Icon(AppIcons.refresh, size: adaptive.Adaptive.icon(context, 18)),
          label: const Text('复习'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(context, 16),
              vertical: adaptive.Adaptive.h(context, 10),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCameraTranslate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraTranslatePage()),
    );
    if (mounted) await _reload();
  }

  Widget _buildNavPanel() {
    return WordBookNavPanel(
      selectedStatus: _selectedStatus,
      selectedTagCode: _selectedTagCode,
      learningItems: _learningNavItems,
      masteredItems: _masteredNavItems,
      selectionMode: _selectionMode,
      selectedWordCodes: _selectedWordCodes,
      words: _words,
      onSelect: (item) async {
        setState(() {
          _selectedStatus = item.status;
          _selectedTagCode = item.tagCode;
          _selectionMode = false;
          _selectedWordCodes.clear();
        });
        await _reload();
      },
      onSmartSelect: (Set<String> codes) {
        setState(() {
          _selectedWordCodes.clear();
          _selectedWordCodes.addAll(codes);
        });
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = context.colors;
    final message = _isKnowledgeBase ? '当前分类下暂无句子' : '当前分类下暂无单词';
    final hint = _isKnowledgeBase
        ? '在播放器或文章阅读时收藏句子即可加入知识库'
        : '在播放器里长按单词即可加入生词本';
    return Center(
      child: Container(
        margin: EdgeInsets.all(adaptive.Adaptive.w(context, 24)),
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(context, 32),
          vertical: adaptive.Adaptive.h(context, 32),
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.menuBook,
              size: adaptive.Adaptive.sp(context, 48),
              color: colorScheme.outline.withValues(alpha: 0.6),
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 16)),
            Text(
              message,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 16),
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: adaptive.Adaptive.h(context, 6)),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 13),
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordList() {
    return ListView.separated(
      itemCount: _words.length,
      separatorBuilder: (_, _) => SizedBox(height: adaptive.Adaptive.h(context, 10)),
      itemBuilder: (context, index) {
        final item = _words[index];
        final tags = _tagsByWordCode[item.code] ?? const <WordTag>[];
        if (_isKnowledgeBase) {
          return SnippetListCard(
            snippet: item,
            tags: tags,
            selectionMode: _selectionMode,
            selected:
                item.code != null && _selectedWordCodes.contains(item.code),
            onTap: () => _handleItemTap(item),
            onTagTap: () => _editItemTags(item),
          );
        }
        return WordBookListCard(
          word: item,
          tags: tags,
          selectionMode: _selectionMode,
          selected: item.code != null && _selectedWordCodes.contains(item.code),
          onTap: () => _handleItemTap(item),
          onTagTap: () => _editItemTags(item),
        );
      },
    );
  }

  void _handleItemTap(WordBook item) {
    if (_selectionMode) {
      final code = item.code;
      if (code == null) return;
      setState(() {
        if (_selectedWordCodes.contains(code)) {
          _selectedWordCodes.remove(code);
        } else {
          _selectedWordCodes.add(code);
        }
      });
      return;
    }
    if (_isKnowledgeBase) {
      _showSnippetDetail(item);
    } else {
      _showWordDetail(item);
    }
  }

  // ── 单词详情 ──

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

  // ── 知识库句子详情 ──

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
          await snippet.save();
        },
        onEditTags: () async {
          Navigator.of(context).pop();
          await _editItemTags(snippet);
        },
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
    final tags = await WordTagService.listTags();
    if (!mounted) return;
    final selectedCodes = (_tagsByWordCode[code] ?? const <WordTag>[])
        .map((tag) => tag.code)
        .whereType<String>()
        .toSet();
    final newTagController = TextEditingController();
    final cs = context.colors;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 16)),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: adaptive.Adaptive.w(context, 360),
                  maxHeight: adaptive.Adaptive.h(context, 420),
                ),
                child: Padding(
                  padding: EdgeInsets.all(adaptive.Adaptive.r(context, 20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      Row(
                        children: [
                          Icon(
                            AppIcons.labelOutline,
                            size: adaptive.Adaptive.sp(context, 20),
                            color: cs.primary,
                          ),
                          SizedBox(width: adaptive.Adaptive.w(context, 8)),
                          Text(
                            '管理标签',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(context, 16),
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: adaptive.Adaptive.h(context, 12)),
                      // 标签下拉列表
                      if (tags.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: adaptive.Adaptive.h(context, 8),
                          ),
                          child: Text(
                            '暂无标签，请在下方输入创建。',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(context, 13),
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: adaptive.Adaptive.h(context, 200),
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(
                              adaptive.Adaptive.r(context, 12),
                            ),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.symmetric(
                              vertical: adaptive.Adaptive.h(context, 4),
                            ),
                            itemCount: tags.length,
                            itemBuilder: (_, index) {
                              final tag = tags[index];
                              final tagCode = tag.code;
                              final selected =
                                  tagCode != null &&
                                  selectedCodes.contains(tagCode);
                              return InkWell(
                                borderRadius: BorderRadius.circular(
                                  adaptive.Adaptive.r(context, 8),
                                ),
                                onTap: tagCode == null
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          if (selected) {
                                            selectedCodes.remove(tagCode);
                                          } else {
                                            selectedCodes.add(tagCode);
                                          }
                                        });
                                      },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: adaptive.Adaptive.w(context, 12),
                                    vertical: adaptive.Adaptive.h(context, 8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selected
                                            ? AppIcons.checkBox
                                            : AppIcons.checkBoxOutlineBlank,
                                        size: adaptive.Adaptive.sp(context, 20),
                                        color: selected
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                      ),
                                      SizedBox(width: adaptive.Adaptive.w(context, 10)),
                                      Expanded(
                                        child: Text(
                                          tag.name,
                                          style: TextStyle(
                                            fontSize: adaptive.Adaptive.sp(context, 14),
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: selected
                                                ? cs.primary
                                                : cs.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      SizedBox(height: adaptive.Adaptive.h(context, 12)),
                      // 新增标签输入行
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newTagController,
                              style: TextStyle(
                                fontSize: adaptive.Adaptive.sp(context, 14),
                                color: cs.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: '新标签名称',
                                hintStyle: TextStyle(
                                  fontSize: adaptive.Adaptive.sp(context, 13),
                                  color: cs.onSurfaceVariant,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: cs.surfaceContainerLow,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: adaptive.Adaptive.w(context, 12),
                                  vertical: adaptive.Adaptive.h(context, 10),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    adaptive.Adaptive.r(context, 10),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    adaptive.Adaptive.r(context, 10),
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    adaptive.Adaptive.r(context, 10),
                                  ),
                                  borderSide: BorderSide(
                                    color: cs.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onSubmitted: (_) async {
                                final name = newTagController.text.trim();
                                if (name.isEmpty) return;
                                final tag = await WordTagService.createTag(
                                  name,
                                );
                                if (tag != null && tag.code != null) {
                                  final newTag = tag;
                                  setDialogState(() {
                                    tags.add(newTag);
                                    selectedCodes.add(newTag.code!);
                                  });
                                  newTagController.clear();
                                }
                              },
                            ),
                          ),
                          SizedBox(width: adaptive.Adaptive.w(context, 8)),
                          SizedBox(
                            height: adaptive.Adaptive.h(context, 38),
                            child: FilledButton.tonal(
                              onPressed: () async {
                                final name = newTagController.text.trim();
                                if (name.isEmpty) return;
                                final tag = await WordTagService.createTag(
                                  name,
                                );
                                if (tag != null && tag.code != null) {
                                  final newTag = tag;
                                  setDialogState(() {
                                    tags.add(newTag);
                                    selectedCodes.add(newTag.code!);
                                  });
                                  newTagController.clear();
                                }
                              },
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: adaptive.Adaptive.w(context, 14),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    adaptive.Adaptive.r(context, 10),
                                  ),
                                ),
                              ),
                              child: Text(
                                '添加',
                                style: TextStyle(
                                  fontSize: adaptive.Adaptive.sp(context, 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: adaptive.Adaptive.h(context, 16)),
                      // 确定按钮
                      SizedBox(
                        width: double.infinity,
                        height: adaptive.Adaptive.h(context, 44),
                        child: FilledButton(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            await WordTagService.replaceTags(
                              code,
                              selectedCodes.toList(),
                            );
                            if (!mounted) return;
                            navigator.pop();
                            await _reload();
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                adaptive.Adaptive.r(context, 12),
                              ),
                            ),
                          ),
                          child: Text(
                            '确定',
                            style: TextStyle(
                              fontSize: adaptive.Adaptive.sp(context, 15),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    newTagController.dispose();
  }

  void _enterSelectionMode(String action) {
    if (_words.isEmpty) return;
    setState(() {
      _selectionAction = action;
      _selectionMode = true;
      _selectedWordCodes.clear();
    });
  }

  Widget _buildSelectionBar(BuildContext context) {
    final colorScheme = context.colors;
    final actionLabel = _isKnowledgeBase || _selectionAction == 'review'
        ? '开始复习'
        : '开始测试';
    final selectedCount = _selectedWordCodes.length;
    final totalCount = _words.length;
    final allSelected = selectedCount == totalCount && totalCount > 0;
    final someSelected = selectedCount > 0 && selectedCount < totalCount;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: adaptive.Adaptive.w(context, 12),
          vertical: adaptive.Adaptive.h(context, 8),
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            // 左侧：Checkbox 全选/反选
            SizedBox(
              width: adaptive.Adaptive.w(context, 36),
              height: adaptive.Adaptive.h(context, 36),
              child: Checkbox(
                value: allSelected ? true : (someSelected ? null : false),
                tristate: true,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedWordCodes
                        ..clear()
                        ..addAll(
                          _words.map((item) => item.code).whereType<String>(),
                        );
                    } else {
                      _selectedWordCodes.clear();
                    }
                  });
                },
              ),
            ),
            SizedBox(width: adaptive.Adaptive.w(context, 4)),
            Text(
              '$selectedCount/$totalCount',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(context, 13),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            // 右侧：主操作按钮
            FilledButton.icon(
              onPressed: selectedCount == 0
                  ? null
                  : () async {
                      final selectedItems = _words
                          .where(
                            (item) =>
                                item.code != null &&
                                _selectedWordCodes.contains(item.code),
                          )
                          .toList();

                      if (_isKnowledgeBase || _selectionAction == 'review') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                WordBookReviewPage(words: selectedItems),
                          ),
                        );
                        setState(() {
                          _selectionMode = false;
                          _selectedWordCodes.clear();
                        });
                        await _reload();
                        return;
                      }

                      if (!mounted) return;
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TestPage(
                            videoTitle: '生词本测试',
                            seedWords: selectedItems
                                .map(
                                  (item) => {
                                    'word': item.word,
                                    'context_sentence':
                                        item.contextSentence ?? item.word,
                                    'word_book_code': item.code,
                                    'source_type': item.sourceType,
                                    'source_code': item.sourceCode,
                                    'source_title': item.sourceTitle,
                                    'segment_code': item.segmentCode,
                                    'definitions_json': item.definitionsJson,
                                    'phonetic_uk': item.phoneticUk,
                                    'phonetic_us': item.phoneticUs,
                                    'difficulty': item.difficulty,
                                  },
                                )
                                .toList(),
                          ),
                        ),
                      );
                      if (changed == true && mounted) {
                        await _reload();
                      }
                    },
              icon: Icon(
                _selectionAction == 'review' ? AppIcons.refresh : AppIcons.quiz,
                size: adaptive.Adaptive.sp(context, 18),
              ),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: adaptive.Adaptive.w(context, 20),
                  vertical: adaptive.Adaptive.h(context, 10),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(context, 20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
