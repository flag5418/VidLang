library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/services/word_tag_service.dart';
import 'package:vidlang/views/word_book/widgets/word_book_list_card.dart';
import 'package:vidlang/views/word_book/widgets/word_book_nav_panel.dart';

import 'word_book_detail_sheet.dart';

class WordBookPage extends ConsumerStatefulWidget {
  const WordBookPage({super.key});

  @override
  ConsumerState<WordBookPage> createState() => _WordBookPageState();
}

class _WordBookPageState extends ConsumerState<WordBookPage> {
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
      final learningItems = await WordBookService.loadNavItems('learning');
      final masteredItems = await WordBookService.loadNavItems('mastered');
      final rows = await WordBookService.queryWords(
        WordBookFilter(status: _selectedStatus, tagCode: _selectedTagCode, keyword: _searchController.text.trim()),
      );
      final tags = await WordTagService.listTagsForWords(rows.map((word) => word.code).whereType<String>().toList());

      if (!mounted) return;
      setState(() {
        _learningNavItems = learningItems;
        _masteredNavItems = masteredItems;
        _words = rows;
        _tagsByWordCode = tags;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      bottomNavigationBar: _selectionMode ? _buildSelectionBar(context) : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              SizedBox(height: 12.h),
              _buildSearchBar(context),
              SizedBox(height: 12.h),
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
                          return Column(
                            children: [
                              _buildNavPanel(),
                              SizedBox(height: 12.h),
                              Expanded(child: _words.isEmpty ? _buildEmptyState(context) : _buildWordList()),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                '生词本',
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999.r)),
                child: Text(
                  '${_words.length}词',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colorScheme.primary),
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(onPressed: () => _enterSelectionMode('test'), icon: const Icon(Icons.quiz_outlined), label: const Text('测试')),
        SizedBox(width: 8.w),
        FilledButton.icon(onPressed: () => _enterSelectionMode('review'), icon: const Icon(Icons.refresh), label: const Text('复习')),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _searchController,
      onSubmitted: (_) => _reload(),
      decoration: InputDecoration(
        hintText: '搜索单词或上下文',
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
          _selectionMode = false;
          _selectedWordCodes.clear();
        });
        await _reload();
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 44.sp, color: colorScheme.outline),
          SizedBox(height: 12.h),
          Text(
            '当前分类下暂无单词',
            style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 4.h),
          Text(
            '在播放器里长按单词即可加入生词本',
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
        final word = _words[index];
        final tags = _tagsByWordCode[word.code] ?? const <WordTag>[];
        return WordBookListCard(
          word: word,
          tags: tags,
          selectionMode: _selectionMode,
          selected: word.code != null && _selectedWordCodes.contains(word.code),
          onTap: () => _handleWordTap(word),
          onTagTap: () => _editWordTags(word),
        );
      },
    );
  }

  void _handleWordTap(WordBook word) {
    if (_selectionMode) {
      final code = word.code;
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
    _showWordDetail(word);
  }

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

  Future<void> _handleMasteryChange(WordBook word, bool recognized) async {
    final code = word.code;
    if (code == null) return;
    final ok = await WordBookService.updateMastery(wordBookCode: code, recognized: recognized);
    if (!ok || !mounted) return;
    await _reload();
  }

  Future<void> _editWordTags(WordBook word) async {
    final code = word.code;
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

  Widget _buildSelectionBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
              '已选 ${_selectedWordCodes.length} 词',
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
                      ..addAll(_words.map((word) => word.code).whereType<String>());
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
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_selectionAction == 'review' ? '复习入口下一步接入' : '测试入口下一步接入')));
                    },
              child: Text(_selectionAction == 'review' ? '开始复习' : '开始测试'),
            ),
          ],
        ),
      ),
    );
  }
}
