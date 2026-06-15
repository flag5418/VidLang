library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/services/word_tag_service.dart';
import 'package:vidlang/views/test/test_page.dart';
import 'package:vidlang/views/word_book/widgets/snippet_detail_sheet.dart';
import 'package:vidlang/views/word_book/widgets/snippet_list_card.dart';
import 'package:vidlang/views/word_book/widgets/word_book_list_card.dart';
import 'package:vidlang/views/word_book/widgets/word_book_nav_panel.dart';

import 'word_book_detail_sheet.dart';
import 'word_book_lookup_sheet.dart';
import 'word_book_review_page.dart';

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> with TickerProviderStateMixin {
  // Tab: 0 = 单词, 1 = 知识库
  int _currentTab = 0;

  List<WordBook> _words = [];
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
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final tags = await WordTagService.listTagsForWords(rows.map((word) => word.code).whereType<String>().toList());
      final todayReviewed = await WordBookService.countTodayReviewed();
      final totalWords = await WordBookService.countTotalWords();

      if (!mounted) return;
      setState(() {
        _learningNavItems = learningItems;
        _masteredNavItems = masteredItems;
        _words = rows;
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
    final colorScheme = Theme.of(context).colorScheme;
    final isNarrow = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colorScheme.surface,
      drawer: isNarrow ? _buildDrawer(context) : null,
      bottomNavigationBar: _selectionMode ? _buildSelectionBar(context) : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, isNarrow),
              SizedBox(height: 10.h),
              _buildTabBar(context),
              SizedBox(height: 10.h),
              _buildSearchBar(context),
              SizedBox(height: 10.h),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 900.w;
                          if (wide) {
                            return Row(
                              children: [
                                SizedBox(width: 240.w, child: _buildNavPanel()),
                                SizedBox(width: 16.w),
                                Expanded(child: _words.isEmpty ? _buildEmptyState(context) : _buildWordList()),
                              ],
                            );
                          }
                          return _words.isEmpty ? _buildEmptyState(context) : _buildWordList();
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      width: 280.w,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12.r),
          child: _buildNavPanel(),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isNarrow) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _isKnowledgeBase ? '知识库' : '生词本';
    final unitLabel = _isKnowledgeBase ? '句' : '词';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isNarrow)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: IconButton(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu),
                  tooltip: '导航',
                ),
              ),
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    '${_words.length}$unitLabel',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colorScheme.primary),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // 知识库 Tab 隐藏测试按钮
            if (!_isKnowledgeBase)
              FilledButton.tonalIcon(
                onPressed: () => _enterSelectionMode('test'),
                icon: const Icon(Icons.quiz_outlined),
                label: const Text('测试'),
              ),
            if (!_isKnowledgeBase) SizedBox(width: 8.w),
            FilledButton.icon(
              onPressed: () => _enterSelectionMode('review'),
              icon: const Icon(Icons.refresh),
              label: const Text('复习'),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          '今日已复习 $_todayReviewed/$_totalWords $unitLabel',
          style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.all(4.r),
      child: Row(
        children: [
          _buildTabChip(context, '单词', 0),
          _buildTabChip(context, '知识库', 1),
        ],
      ),
    );
  }

  Widget _buildTabChip(BuildContext context, String label, int tabIndex) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _currentTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(tabIndex),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hint = _isKnowledgeBase ? '搜索句子或备注' : '搜索单词或上下文';
    return TextField(
      controller: _searchController,
      onSubmitted: (_) => _handleSearch(),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  _reload();
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
      ),
    );
  }

  Future<void> _handleSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    if (_isKnowledgeBase) {
      await _reload();
      return;
    }

    // For word tab: first search locally
    final rows = await WordBookService.queryWords(
      WordBookFilter(status: _selectedStatus, tagCode: _selectedTagCode, contentType: 'word', keyword: keyword),
    );

    if (rows.isNotEmpty) {
      await _reload();
      return;
    }

    // No local result — check if it looks like a single English word
    final wordPattern = RegExp(r"^[a-zA-Z']+$");
    if (!wordPattern.hasMatch(keyword)) {
      await _reload();
      return;
    }

    // Trigger lookup
    final isPaid = AppConfig.currentUser?.authProvider == 'supabase';
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => WordBookLookupSheet(
        word: keyword,
        isPaidMode: isPaid,
      ),
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

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = _isKnowledgeBase ? '当前分类下暂无句子' : '当前分类下暂无单词';
    final hint = _isKnowledgeBase ? '在播放器或文章阅读时收藏句子即可加入知识库' : '在播放器里长按单词即可加入生词本';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 44.sp, color: colorScheme.outline),
          SizedBox(height: 12.h),
          Text(
            message,
            style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 4.h),
          Text(
            hint,
            style: TextStyle(fontSize: 12.sp, color: colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList() {
    return ListView.separated(
      itemCount: _words.length,
      separatorBuilder: (_, _) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final item = _words[index];
        final tags = _tagsByWordCode[item.code] ?? const <WordTag>[];
        if (_isKnowledgeBase) {
          return SnippetListCard(
            snippet: item,
            tags: tags,
            selectionMode: _selectionMode,
            selected: item.code != null && _selectedWordCodes.contains(item.code),
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
    final ok = await WordBookService.updateMastery(wordBookCode: code, recognized: recognized);
    if (!ok || !mounted) return;
    await _reload();
  }

  Future<void> _editItemTags(WordBook item) async {
    final code = item.code;
    if (code == null) return;
    final tags = await WordTagService.listTags();
    if (!mounted) return;
    final selectedCodes = (_tagsByWordCode[code] ?? const <WordTag>[]).map((tag) => tag.code).whereType<String>().toSet();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '管理标签',
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 12.h),
                    if (tags.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: Text('当前还没有标签，后续可从管理页创建。', style: TextStyle(fontSize: 13.sp)),
                      ),
                    ...tags.map((tag) {
                      final tagCode = tag.code;
                      final selected = tagCode != null && selectedCodes.contains(tagCode);
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        title: Text(tag.name),
                        onChanged: tagCode == null
                            ? null
                            : (_) {
                                setModalState(() {
                                  if (selected) {
                                    selectedCodes.remove(tagCode);
                                  } else {
                                    selectedCodes.add(tagCode);
                                  }
                                });
                              },
                      );
                    }),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          await WordTagService.replaceTags(code, selectedCodes.toList());
                          if (!mounted) return;
                          navigator.pop();
                          await _reload();
                        },
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _enterSelectionMode(String action) {
    if (_words.isEmpty) return;
    setState(() {
      _selectionAction = action;
      _selectionMode = true;
      _selectedWordCodes.clear();
    });
  }

  Future<Map<String, dynamic>?> _showTestConfigDialog(int selectedCount) async {
    final colorScheme = Theme.of(context).colorScheme;
    final questionTypes = <String>{'definition_choice'};
    var questionsPerWord = 2;
    var difficulty = 'standard';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final totalQuestions = selectedCount * questionsPerWord;
            final estimatedMinutes = (totalQuestions * 0.4).ceil();
            return Dialog(
              backgroundColor: colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              child: Padding(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('测试设置',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    SizedBox(height: 16.h),
                    Text('已选单词: $selectedCount 个',
                        style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurfaceVariant)),
                    SizedBox(height: 16.h),
                    Text('题型选择',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    SizedBox(height: 8.h),
                    _buildQuestionTypeCheckbox(ctx, setDialogState, '释义选择（四选一）', 'definition_choice', questionTypes, colorScheme),
                    _buildQuestionTypeCheckbox(ctx, setDialogState, '拼写填空', 'spelling', questionTypes, colorScheme),
                    _buildQuestionTypeCheckbox(ctx, setDialogState, '例句填空', 'example_cloze', questionTypes, colorScheme),
                    _buildQuestionTypeCheckbox(ctx, setDialogState, '跟读评分', 'speaking', questionTypes, colorScheme),
                    SizedBox(height: 16.h),
                    Text('每词出题数',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    SizedBox(height: 8.h),
                    Row(
                      children: [1, 2, 3].map((n) {
                        final selected = questionsPerWord == n;
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: ChoiceChip(
                            label: Text('$n'),
                            selected: selected,
                            selectedColor: colorScheme.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                                color: selected ? colorScheme.primary : colorScheme.onSurface,
                                fontWeight: FontWeight.w600),
                            onSelected: (_) => setDialogState(() => questionsPerWord = n),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16.h),
                    Text('难度',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        {'label': '简单', 'value': 'easy'},
                        {'label': '标准', 'value': 'standard'},
                        {'label': '困难', 'value': 'hard'},
                      ].map((item) {
                        final selected = difficulty == item['value'];
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: ChoiceChip(
                            label: Text(item['label']!),
                            selected: selected,
                            selectedColor: colorScheme.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                                color: selected ? colorScheme.primary : colorScheme.onSurface,
                                fontWeight: FontWeight.w600),
                            onSelected: (_) => setDialogState(() => difficulty = item['value']!),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16.h),
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8.r)),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 16.sp, color: colorScheme.onSurfaceVariant),
                          SizedBox(width: 6.w),
                          Text(
                            '预计: ${totalQuestions}题 · 约${estimatedMinutes}分钟',
                            style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(null),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                            ),
                            child: const Text('取消'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: FilledButton(
                            onPressed: questionTypes.isEmpty
                                ? null
                                : () => Navigator.of(ctx).pop({
                                      'questionTypes': questionTypes.toList(),
                                      'questionsPerWord': questionsPerWord,
                                      'difficulty': difficulty,
                                    }),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                            ),
                            child: const Text('开始'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuestionTypeCheckbox(
    BuildContext ctx,
    StateSetter setDialogState,
    String label,
    String value,
    Set<String> selected,
    ColorScheme cs,
  ) {
    final checked = selected.contains(value);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: TextStyle(fontSize: 14.sp, color: cs.onSurface)),
      value: checked,
      activeColor: cs.primary,
      onChanged: (_) {
        setDialogState(() {
          if (checked) {
            selected.remove(value);
          } else {
            selected.add(value);
          }
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unitLabel = _isKnowledgeBase ? '句' : '词';
    final actionLabel = _isKnowledgeBase || _selectionAction == 'review' ? '开始复习' : '开始测试';

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
        ),
        child: Row(
          children: [
            Text(
              '已选 ${_selectedWordCodes.length} $unitLabel',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedWordCodes.length == _words.length) {
                    _selectedWordCodes.clear();
                  } else {
                    _selectedWordCodes
                      ..clear()
                      ..addAll(_words.map((item) => item.code).whereType<String>());
                  }
                });
              },
              child: const Text('全选'),
            ),
            SizedBox(width: 8.w),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectedWordCodes.clear();
                });
              },
              child: const Text('取消'),
            ),
            SizedBox(width: 8.w),
            FilledButton(
              onPressed: _selectedWordCodes.isEmpty
                  ? null
                  : () async {
                      final selectedItems = _words
                          .where((item) => item.code != null && _selectedWordCodes.contains(item.code))
                          .toList();

                      // 知识库 Tab 或复习：直接进入复习页，跳过测试配置
                      if (_isKnowledgeBase || _selectionAction == 'review') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WordBookReviewPage(words: selectedItems),
                          ),
                        );
                        setState(() {
                          _selectionMode = false;
                          _selectedWordCodes.clear();
                        });
                        await _reload();
                        return;
                      }

                      // 单词 Tab 测试：弹出配置窗口
                      if (!mounted) return;
                      final config = await _showTestConfigDialog(selectedItems.length);
                      if (config == null || !mounted) return;
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TestPage(
                            videoTitle: '生词本测试',
                            seedWords: selectedItems
                                .map(
                                  (item) => {
                                    'word': item.word,
                                    'context_sentence': item.contextSentence ?? item.word,
                                    'word_book_code': item.code,
                                  },
                                )
                                .toList(),
                            questionTypes: config['questionTypes'] as List<String>,
                            questionsPerWord: config['questionsPerWord'] as int,
                            difficulty: config['difficulty'] as String,
                          ),
                        ),
                      );
                      if (changed == true && mounted) {
                        await _reload();
                      }
                    },
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
