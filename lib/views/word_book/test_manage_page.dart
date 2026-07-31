import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/providers/test_basket_provider.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/services/word_book/word_tag_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/views/test/test_page.dart';

/// 测试管理页面（购物车式）
///
/// 布局：
/// - 左侧：标签分类导航
/// - 右侧：已添加的单词列表
/// - 右上角：+ 增加按钮（弹出双栏选择弹窗）
/// - 底部：全选 + 开始测试控制栏
class TestManagePage extends ConsumerStatefulWidget {
  const TestManagePage({super.key});

  @override
  ConsumerState<TestManagePage> createState() => _TestManagePageState();
}

class _TestManagePageState extends ConsumerState<TestManagePage> {
  /// 所有标签列表（含"全部"）
  List<WordTag> _allTags = [];
  
  /// 当前选中的标签 code，null 表示全部
  String? _selectedTagCode;
  
  /// 全选 checkbox 状态
  bool _isAllSelected = false;
  
  @override
  void initState() {
    super.initState();
    _loadTags();
  }
  
  Future<void> _loadTags() async {
    final tags = await WordTagService.listTags();
    if (mounted) {
      setState(() => _allTags = tags);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;
    final basketState = ref.watch(testBasketProvider);
    
    // 根据当前标签筛选显示的单词
    final displayWords = _filterWordsByTag(basketState.words);
    
    return Scaffold(
      backgroundColor: AppColors.getSurfaceHighest(brightness: Theme.of(context).brightness),
      appBar: AppBar(
        title: Text(
          '测试管理',
          style: textStyles.heading.copyWith(color: cs.onSurface),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrowBack, color: cs.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // + 增加按钮
          IconButton(
            onPressed: () => _showAddWordDialog(context, basketState),
            icon: Icon(AppIcons.add, color: cs.primary),
            tooltip: '添加单词',
          ),
        ],
      ),
      body: Column(
        children: [
          // ═══ 主内容区：左侧标签 + 右侧单词列表 ═══
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 左侧：标签导航 ──
                _buildTagSidebar(cs, colorScheme, textStyles, basketState),
                
                // 分隔线
                Container(width: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
                
                // ── 右侧：单词列表 ──
                Expanded(child: _buildWordList(displayWords, cs, colorScheme, textStyles)),
              ],
            ),
          ),
          
          // ═══ 底部控制栏：全选 + 开始测试 ═══
          _buildBottomBar(basketState, cs, colorScheme, textStyles),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 左侧标签导航
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTagSidebar(AppColorsData cs, ColorScheme colorScheme, AppTextStylesData textStyles, TestBasketState basketState) {
    return Container(
      width: Adaptive.w(140),
      color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          // "全部"选项
          _buildTagItem(
            cs, textStyles,
            name: '全部',
            count: basketState.count,
            isSelected: _selectedTagCode == null,
            onTap: () => setState(() => _selectedTagCode = null),
          ),
          
          // 标签列表
          ..._allTags.map((tag) {
            final count = _countByTag(tag.code, basketState);
            return _buildTagItem(
              cs, textStyles,
              name: tag.name,
              count: count,
              isSelected: _selectedTagCode == tag.code,
              onTap: () => setState(() => _selectedTagCode = tag.code),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTagItem(AppColorsData cs, AppTextStylesData textStyles, {
    required String name,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? AppIcons.folderOpen : AppIcons.folder,
              size: Adaptive.icon(18),
              color: isSelected ? colorScheme.primary : cs.onSurfaceVariant,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                name,
                style: textStyles.body.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count > 0)
              Container(
                constraints: BoxConstraints(minWidth: Adaptive.w(20), minHeight: Adaptive.h(18)),
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary.withValues(alpha: 0.15) : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.tag),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: textStyles.micro.copyWith(color: isSelected ? colorScheme.primary : cs.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _countByTag(String? tagCode, TestBasketState basketState) {
    if (tagCode == null || tagCode.isEmpty) return basketState.count;
    return basketState.words.where((w) {
      // 这里需要根据实际关联关系判断，暂时返回 0
      // TODO: 实现单词-标签关联查询
      return false;
    }).length;
  }

  List<WordBook> _filterWordsByTag(List<WordBook> words) {
    if (_selectedTagCode == null) return words;
    // TODO: 实现按标签筛选
    return words;
  }

  // ═══════════════════════════════════════════════════════════════
  // 右侧单词列表
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWordList(List<WordBook> words, AppColorsData cs, ColorScheme colorScheme, AppTextStylesData textStyles) {
    if (words.isEmpty) {
      return _buildEmptyList(cs, colorScheme, textStyles);
    }
    
    final notifier = ref.read(testBasketProvider.notifier);
    
    return ListView.separated(
      padding: EdgeInsets.all(AppSpacing.md),
      itemCount: words.length,
      separatorBuilder: (_, _) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (ctx, index) {
        final word = words[index];
        
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onLongPress: () => _showWordDetail(word),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.cardInner),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  // 待测图标
                  Icon(
                    AppIcons.checkCircle,
                    size: Adaptive.icon(20),
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  
                  // 单词信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          word.word,
                          style: textStyles.body.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
                        ),
                        if ((word.sourceTitle ?? '').isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              word.sourceTitle!,
                              style: textStyles.caption.copyWith(color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // 移除按钮
                  GestureDetector(
                    onTap: () => notifier.remove(word.code!),
                    child: Container(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        AppIcons.close,
                        size: Adaptive.icon(16),
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
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
  }

  Widget _buildEmptyList(AppColorsData cs, ColorScheme colorScheme, AppTextStylesData textStyles) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            AppIcons.quiz,
            size: Adaptive.icon(48),
            color: colorScheme.primary.withValues(alpha: 0.25),
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            '暂无待测单词',
            style: textStyles.heading.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            '点击右上角「+」添加单词',
            style: textStyles.caption.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 底部控制栏
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBottomBar(TestBasketState basketState, AppColorsData cs, ColorScheme colorScheme, AppTextStylesData textStyles) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageH,
        AppSpacing.sm,
        AppSpacing.pageH,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: AppShadows.card,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ── 全选 checkbox ──
            GestureDetector(
              onTap: () => _toggleSelectAll(basketState),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: Adaptive.w(24),
                    height: Adaptive.w(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isAllSelected && basketState.isNotEmpty ? cs.primary : Colors.transparent,
                      border: Border.all(
                        color: _isAllSelected && basketState.isNotEmpty ? cs.primary : cs.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                    child: _isAllSelected && basketState.isNotEmpty
                        ? Icon(AppIcons.check, size: Adaptive.sp(14), color: AppColors.onPrimary)
                        : null,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text('全选', style: textStyles.body.copyWith(color: cs.onSurface)),
                ],
              ),
            ),
            
            const Spacer(),
            
            // ── 已选数量 ──
            if (basketState.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(right: AppSpacing.md),
                child: Text(
                  '已选 ${basketState.count}/50',
                  style: textStyles.caption.copyWith(fontWeight: FontWeight.w600, color: cs.primary),
                ),
              ),
            
            // ── 开始测试按钮 ──
            FilledButton.icon(
              onPressed: basketState.isEmpty ? null : () => _startTest(context),
              icon: Icon(AppIcons.quiz, size: Adaptive.icon(18)),
              label: Text('开始测试', style: textStyles.body.copyWith(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.buttonPaddingHorizontal,
                  vertical: AppSpacing.buttonPaddingVertical,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelectAll(TestBasketState basketState) {
    if (_isAllSelected || basketState.isEmpty) {
      // 取消全选 → 清空测试篮
      ref.read(testBasketProvider.notifier).clear();
      setState(() => _isAllSelected = false);
    } else {
      // 全选 → 当前已显示的全部加入（已经是全部了）
      setState(() => _isAllSelected = true);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 添加单词弹窗（双栏选择器）
  // ═══════════════════════════════════════════════════════════════

  Future<void> _showAddWordDialog(BuildContext context, TestBasketState currentBasket) async {
    // 使用 Builder 获取包含 Overlay 的 context
    final result = await showDialog<List<WordBook>>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) => AddWordDialog(currentInBasket: currentBasket.words),
    );

    if (result != null && result.isNotEmpty && mounted) {
      ref.read(testBasketProvider.notifier).addAll(result);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 开始测试
  // ═══════════════════════════════════════════════════════════════

  Future<void> _startTest(BuildContext context) async {
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

    if (changed == true && mounted) {
      ref.read(testBasketProvider.notifier).clear();
      Navigator.of(context)..pop()..pop();
    }
  }

  Future<void> _showWordDetail(WordBook word) async {
    // TODO: 显示单词详情
  }
}

// ════════════════════════════════════════════════════════════════════
// 添加单词对话框（双栏选择器）
// ════════════════════════════════════════════════════════════════════

class AddWordDialog extends StatefulWidget {
  /// 当前已在测试篮中的单词（用于排除）
  final List<WordBook> currentInBasket;

  const AddWordDialog({super.key, this.currentInBasket = const []});

  @override
  State<AddWordDialog> createState() => _AddWordDialogState();
}

class _AddWordDialogState extends State<AddWordDialog> {
  /// 所有可选择的单词（排除已加入的）
  List<WordBook> _availableWords = [];
  
  /// 所有标签
  List<WordTag> _allTags = [];
  
  /// 当前选中的标签（用于过滤）
  String? _selectedTagCode;
  
  /// 本次新选择的单词
  final Set<String> _newSelections = {};
  
  /// 是否全选当前过滤结果
  bool _isSelectAll = false;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 加载所有未掌握的单词
    final words = await WordBookService.queryWords(WordBookFilter(status: 'learning'));
    final tags = await WordTagService.listTags();
    
    // 排除已在测试篮中的
    final inBasketCodes = widget.currentInBasket.map((w) => w.code).toSet();
    final filtered = words.where((w) => !inBasketCodes.contains(w.code)).toList();

    if (mounted) {
      setState(() {
        _availableWords = filtered;
        _allTags = tags;
        _isLoading = false;
      });
    }
  }

  /// 获取当前过滤后的待选单词
  List<WordBook> get _filteredWords {
    if (_selectedTagCode == null) return _availableWords;
    // TODO: 按标签筛选
    return _availableWords;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyles = context.textStyles;
    final filteredWords = _filteredWords;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: Adaptive.w(16)),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: Adaptive.h(540)),
        decoration: BoxDecoration(
          color: Colors.white, // 纯白背景，清晰干净
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══ 标题栏 ═══
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm + AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Text('添加单词', style: textStyles.heading.copyWith(color: const Color(0xFF1A1A2E))),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '已选 ${_newSelections.length}/50',
                      style: textStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(height: 1, color: const Color(0xFFF0F0F5)),
            
            // ═══ 双栏内容（对称布局）═══
            Flexible(
              child: SizedBox(
                height: Adaptive.h(360),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 左侧：待选单词（对称布局）──
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          // 标签滚动条
                          _buildTagFilterBar(cs, colorScheme, textStyles),
                          
                          Divider(height: 1, color: const Color(0xFFF5F5FA)),
                          
                          // 单词列表
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B6EFF)))
                                : filteredWords.isEmpty
                                    ? _buildNoAvailableWords(cs, textStyles)
                                    : _buildAvailableList(filteredWords, cs, colorScheme, textStyles),
                          ),
                        ],
                      ),
                    ),
                    
                    // 中间分隔线（更明显）
                    Container(width: 1, color: const Color(0xFFF0F0F5)),
                    
                    // ── 右侧：已选择（对称布局） ──
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          // 操作按钮行（与左侧标签条等高）
                          Container(
                            height: Adaptive.h(36),
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FB),
                            ),
                            child: Row(
                              children: [
                                // 全选 / 反选
                                TextButton.icon(
                                  onPressed: () => _toggleDialogSelectAll(filteredWords),
                                  icon: Icon(_isSelectAll ? AppIcons.close : AppIcons.checkCircle, size: Adaptive.icon(14), color: colorScheme.primary),
                                  label: Text(_isSelectAll ? '反选' : '全选', style: textStyles.caption.copyWith(color: colorScheme.primary)),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size(Adaptive.w(48), 0),
                                  ),
                                ),
                                const Spacer(),
                                // 清空
                                if (_newSelections.isNotEmpty)
                                  TextButton(
                                    onPressed: () => setState(() => _newSelections.clear()),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                    child: Text('清空', style: textStyles.caption.copyWith(color: const Color(0xFFEF4444))),
                                  ),
                              ],
                            ),
                          ),
                          
                          Divider(height: 1, color: const Color(0xFFF5F5FA)),
                          
                          // 已选列表
                          Expanded(
                            child: _newSelections.isEmpty
                                ? _buildEmptySelection(cs, textStyles)
                                : _buildSelectedList(cs, textStyles),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Divider(height: 1, color: const Color(0xFFF0F0F5)),
            
            // ═══ 底部按钮 ═══
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + AppSpacing.xs),
                    ),
                    child: Text('取消', style: textStyles.body.copyWith(color: const Color(0xFF64748B))),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _newSelections.isEmpty ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3B6EFF),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm + AppSpacing.xs),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                    ),
                    child: Text('确定 (${_newSelections.length})', style: textStyles.body.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ 标签过滤条 ═══
  Widget _buildTagFilterBar(AppColorsData cs, ColorScheme colorScheme, AppTextStylesData textStyles) {
    return SizedBox(
      height: Adaptive.h(36),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          // "全部"
          _buildFilterChip(cs, textStyles, '全部', _selectedTagCode == null, () => setState(() => _selectedTagCode = null)),
          ..._allTags.map((tag) => Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: _buildFilterChip(cs, textStyles, tag.name, _selectedTagCode == tag.code, () => setState(() => _selectedTagCode = tag.code)),
          )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(AppColorsData cs, AppTextStylesData textStyles, String label, bool selected, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label, style: textStyles.micro),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primary.withValues(alpha: 0.15),
      checkmarkColor: colorScheme.primary,
      labelStyle: TextStyle(
        color: selected ? colorScheme.primary : cs.onSurfaceVariant,
        fontSize: Adaptive.sp(AppTypography.fontSizeXSmall),
      ),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // ═══ 待选列表 ═══
  Widget _buildAvailableList(List<WordBook> words, AppColorsData cs, ColorScheme colorScheme, AppTextStylesData textStyles) {
    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.sm),
      itemCount: words.length,
      itemBuilder: (ctx, index) {
        final word = words[index];
        final isSelected = _newSelections.contains(word.code);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (_) => _toggleWordSelection(word.code!),
          activeColor: colorScheme.primary,
          dense: true,
          title: Text(word.word, style: textStyles.caption.copyWith(fontWeight: FontWeight.w500)),
          subtitle: (word.sourceTitle ?? '').isNotEmpty
              ? Text(word.sourceTitle!, style: textStyles.micro.copyWith(color: cs.onSurfaceVariant))
              : null,
        );
      },
    );
  }

  Widget _buildNoAvailableWords(AppColorsData cs, AppTextStylesData textStyles) {
    return Center(
      child: Text('没有更多可添加的单词', style: textStyles.body.copyWith(color: cs.onSurfaceVariant)),
    );
  }

  // ═══ 已选列表 ═══
  Widget _buildEmptySelection(AppColorsData cs, AppTextStylesData textStyles) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.addCircleOutline, size: Adaptive.icon(32), color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          SizedBox(height: AppSpacing.sm),
          Text('从左侧选择单词', style: textStyles.caption.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildSelectedList(AppColorsData cs, AppTextStylesData textStyles) {
    final selectedWords = _availableWords.where((w) => _newSelections.contains(w.code)).toList();

    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.sm),
      itemCount: selectedWords.length,
      itemBuilder: (ctx, index) {
        final word = selectedWords[index];

        return ListTile(
          dense: true,
          title: Text(word.word, style: textStyles.caption.copyWith(fontWeight: FontWeight.w500)),
          trailing: GestureDetector(
            onTap: () => setState(() => _newSelections.remove(word.code)),
            child: Icon(AppIcons.close, size: Adaptive.icon(16), color: cs.error),
          ),
        );
      },
    );
  }

  // ═══ 操作方法 ═══
  void _toggleWordSelection(String code) {
    setState(() {
      if (_newSelections.contains(code)) {
        _newSelections.remove(code);
      } else {
        if (_newSelections.length >= 50) return; // 上限
        _newSelections.add(code);
      }
      _updateSelectAllState();
    });
  }

  void _toggleDialogSelectAll(List<WordBook> filteredWords) {
    setState(() {
      if (_isSelectAll) {
        // 反选：清空
        _newSelections.clear();
        _isSelectAll = false;
      } else {
        // 全选当前过滤结果
        for (final w in filteredWords) {
          if (w.code != null && _newSelections.length < 50) {
            _newSelections.add(w.code!);
          }
        }
        _isSelectAll = true;
      }
    });
  }

  void _updateSelectAllState() {
    final filtered = _filteredWords;
    _isSelectAll = filtered.isNotEmpty && filtered.every((w) => _newSelections.contains(w.code));
  }

  void _confirm() {
    final selectedWords = _availableWords.where((w) => _newSelections.contains(w.code)).toList();
    Navigator.of(context).pop(selectedWords);
  }
}
