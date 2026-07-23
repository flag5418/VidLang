import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/services/word_book/word_tag_service.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/app_globals.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/views/test/test_page.dart';
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
import 'word_book_review_page.dart';

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
  String _selectionAction = 'test';
  bool _selectionMode = false;
  final Set<String> _selectedWordCodes = <String>{};
  final TextEditingController _searchController = TextEditingController();
  int _todayReviewed = 0;
  int _totalWords = 0;
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
    final isPad = AppGlobals.isTablet;

    return GestureDetector(
      onTap: _selectionMode ? _cancelSelection : null,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.getSurfaceHighest(brightness: brightness),
        drawer: !isPad ? _buildDrawer(context) : null,
        bottomNavigationBar: _selectionMode
            ? _buildSelectionBar(context)
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    if (!isPad) ...[
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
                    ],
                    Text(
                      _isKnowledgeBase ? '知识库' : '生词本',
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
                        '${_allWords.length}${_isKnowledgeBase ? '句' : '词'}',
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
              if (_selectionMode)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.Adaptive.r(16),
                    vertical: adaptive.Adaptive.h(6),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: adaptive.Adaptive.w(12),
                      vertical: adaptive.Adaptive.h(8),
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(
                        adaptive.Adaptive.r(10),
                      ),
                    ),
                    child: Text(
                      '已选择 ${_selectedWordCodes.length}/${_words.length}，点击下方按钮开始，或点击任意位置取消',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: adaptive.Adaptive.sp(12),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          adaptive.Adaptive.r(16),
                          adaptive.Adaptive.h(12),
                          adaptive.Adaptive.r(16),
                          adaptive.Adaptive.h(8),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide =
                                constraints.maxWidth >=
                                adaptive.Adaptive.w(900);
                            if (wide) {
                              return Row(
                                children: [
                                  SizedBox(
                                    width: adaptive.Adaptive.w(240),
                                    child: _buildNavPanel(),
                                  ),
                                  SizedBox(width: adaptive.Adaptive.w(16)),
                                  Expanded(
                                    child: _words.isEmpty
                                        ? _buildEmptyState(colorScheme)
                                        : _buildWordList(),
                                  ),
                                ],
                              );
                            }
                            return _words.isEmpty
                                ? _buildEmptyState(colorScheme)
                                : _buildWordList();
                          },
                        ),
                      ),
              ),
              if (!_selectionMode && _allWords.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: adaptive.Adaptive.r(16),
                    vertical: adaptive.Adaptive.h(10),
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
          _buildTabChip('单词', AppIcons.spellcheck, 0, cs),
          SizedBox(width: adaptive.Adaptive.w(3)),
          _buildTabChip('知识库', AppIcons.libraryBooks, 1, cs),
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
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              SizedBox(width: adaptive.Adaptive.w(4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: adaptive.Adaptive.sp(13),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
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
    final wordPattern = RegExp(r"^[a-zA-Z']+$");
    if (!wordPattern.hasMatch(keyword)) return;
    if (!mounted) return;
    await WordCard.show(
      context,
      word: keyword,
      sourceType: 'word_book',
      sourceCode: '',
    );
  }

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
            icon: Icon(AppIcons.quiz, size: adaptive.Adaptive.icon(18)),
            label: const Text('测试'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.tertiaryContainer,
              foregroundColor: colorScheme.onTertiaryContainer,
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.Adaptive.w(16),
                vertical: adaptive.Adaptive.h(10),
              ),
            ),
          ),
          SizedBox(width: adaptive.Adaptive.w(12)),
        ],
        FilledButton.icon(
          onPressed: () => _enterSelectionMode('review'),
          icon: Icon(AppIcons.refresh, size: adaptive.Adaptive.icon(18)),
          label: const Text('复习'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            padding: EdgeInsets.symmetric(
              horizontal: adaptive.Adaptive.w(16),
              vertical: adaptive.Adaptive.h(10),
            ),
          ),
        ),
      ],
    );
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
        return CollectionWordCard(
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
          await snippet.save();
        },
        onEditTags: () async {
          Navigator.of(context).pop();
          await _editItemTags(snippet);
        },
      ),
    );
  }

  void _showCollectionDetail(WordBook word) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => CollectionDetailSheet(
        word: word,
        onClose: () => Navigator.of(context).pop(),
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
          horizontal: adaptive.Adaptive.w(12),
          vertical: adaptive.Adaptive.h(8),
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
            SizedBox(
              width: adaptive.Adaptive.w(36),
              height: adaptive.Adaptive.h(36),
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
            SizedBox(width: adaptive.Adaptive.w(4)),
            Text(
              '$selectedCount/$totalCount',
              style: TextStyle(
                fontSize: adaptive.Adaptive.sp(13),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
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
                      if (changed == true && mounted) await _reload();
                    },
              icon: Icon(
                _selectionAction == 'review' ? AppIcons.refresh : AppIcons.quiz,
                size: adaptive.Adaptive.sp(18),
              ),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: adaptive.Adaptive.w(20),
                  vertical: adaptive.Adaptive.h(10),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(adaptive.Adaptive.r(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
