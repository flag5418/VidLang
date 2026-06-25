import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/providers/display_config_provider.dart';

/// 统一词条详情弹窗组件
///
/// 三种状态：
/// - loading：仅显示单词 + TTS 发音按钮
/// - loaded：渲染完整内容（横屏双栏 / 竖屏垂直滚动）
/// - error：显示错误信息
///
/// 横屏判断：width > height && width >= 600 → 左侧固定导航 + 右侧可滚动内容
class WordDetailPanel extends StatefulWidget {
  final WordDetail data;
  final WordDetailDisplayConfig config;
  final VoidCallback? onSpeak;
  final VoidCallback onClose;
  final bool isSaved;
  final bool saving;
  final VoidCallback? onSaveWord;

  /// 是否处于加载中（data 可传入占位 WordDetail）
  final bool isLoading;

  const WordDetailPanel({
    super.key,
    required this.data,
    required this.config,
    this.onSpeak,
    required this.onClose,
    this.isSaved = false,
    this.saving = false,
    this.onSaveWord,
    this.isLoading = false,
  });

  @override
  State<WordDetailPanel> createState() => _WordDetailPanelState();
}

class _WordDetailPanelState extends State<WordDetailPanel> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _settingsScrollController = ScrollController();
  final Map<WordDetailSection, GlobalKey> _sectionKeys = {};

  WordDetailSection? _currentSection;
  List<WordDetailSection> _effectiveSections = const [];

  // ─── 设置视图状态 ───
  bool _showSettings = false;
  late List<WordDetailSection> _settingsSections;
  bool _settingsSaving = false;

  @override
  void initState() {
    super.initState();
    for (final s in WordDetailSection.values) {
      _sectionKeys[s] = GlobalKey();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 延迟计算 effectiveSections 并初始化 currentSection
    _effectiveSections = _buildEffectiveSections();
    if (_currentSection == null && _effectiveSections.isNotEmpty) {
      _currentSection = _effectiveSections.first;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _settingsScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    WordDetailSection? found;
    for (final s in _effectiveSections) {
      final key = _sectionKeys[s]!;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final scrollableCtx = Scrollable.of(ctx).context;
      final viewport = scrollableCtx.findRenderObject() as RenderBox?;
      if (viewport == null) continue;
      final pos = box.localToGlobal(Offset.zero, ancestor: viewport);
      if (pos.dy <= 60) found = s;
    }
    if (found != null && found != _currentSection) {
      setState(() => _currentSection = found);
    }
  }

  void _scrollToSection(WordDetailSection section) {
    final key = _sectionKeys[section];
    if (key?.currentContext == null) return;
    final box = key!.currentContext!.findRenderObject() as RenderBox?;
    if (box == null) return;
    final scrollableCtx = Scrollable.of(key.currentContext!).context;
    final viewport = scrollableCtx.findRenderObject() as RenderBox?;
    if (viewport == null) return;
    final pos = box.localToGlobal(Offset.zero, ancestor: viewport);
    final targetOffset = (_scrollController.offset + pos.dy - 8).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() => _currentSection = section);
  }

  @override
  Widget build(BuildContext context) {
    _effectiveSections = _buildEffectiveSections();

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: GestureDetector(
        onTap: widget.onClose,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.expand(
          child: Center(
            child: GestureDetector(
              onTap: () {}, // 阻止点击内容区传播到外层
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return _buildLoadingState();
    }
    if (!widget.data.success &&
        widget.data.error != null &&
        !widget.data.isInsufficientBalance) {
      return _buildErrorState();
    }
    return _buildContentLayout();
  }

  // ─── Loading 状态 ─────────────────────────────────

  Widget _buildLoadingState() {
    final cs = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width >= 600;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: isWide ? 600 : screenSize.width * 0.6,
        constraints: BoxConstraints(maxHeight: screenSize.height * 0.6),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xFFF0EDE8)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '正在查询「${widget.data.word}」...',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Error 状态 ─────────────────────────────────

  Widget _buildErrorState() {
    final cs = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width >= 600;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: isWide ? 400 : screenSize.width * 0.6,
        constraints: BoxConstraints(maxHeight: screenSize.height * 0.6),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xFFF0EDE8)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 10),
            Text(
              widget.data.error ?? '查询失败',
              style: TextStyle(color: cs.error, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ─── 统一布局（横竖屏共用） ─────────────────────────────────
  //
  // 结构：顶部 Header + 下方 Row(左导航 + 右内容滚动区)
  // 仅通过尺寸参数区分横竖屏

  Widget _buildContentLayout() {
    final cs = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isLandscape =
        screenSize.width > screenSize.height && screenSize.width >= 600;

    // 横竖屏尺寸参数
    final cardWidth = screenSize.width * (isLandscape ? 0.65 : 0.9);
    final maxHeight = screenSize.height * (isLandscape ? 0.82 : 0.65);
    final navWidth = isLandscape ? 110.0 : 96.0;

    final bgColor = cs.surface;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(maxWidth: 700, maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _showSettings
            ? _buildSettingsView(cs)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部 Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: _buildHeader(),
                  ),
                  Container(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                  // 下方：左导航 + 右内容
                  Flexible(
                    fit: FlexFit.loose,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左侧固定导航
                        SizedBox(
                          width: navWidth,
                          child: _buildNavList(cs, isLandscape),
                        ),
                        // 分割线
                        Container(
                          width: 1,
                          color: cs.outlineVariant.withValues(alpha: 0.2),
                        ),
                        // 右侧可滚动内容
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildAllSections(_effectiveSections),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
      ),
    );
  }

  /// 左侧导航列表（含底部设置按钮）
  Widget _buildNavList(ColorScheme cs, bool isLandscape) {
    final scrollableChildren = _effectiveSections.map((s) {
      final isActive = s == _currentSection;
      return GestureDetector(
        onTap: () => _scrollToSection(s),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: isLandscape ? 10 : 8,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? cs.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            s.label,
            style: TextStyle(
              color: isActive ? cs.primary : cs.onSurfaceVariant,
              fontSize: isLandscape ? 12 : 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: scrollableChildren,
          ),
        ),
        Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
        GestureDetector(
          onTap: _enterSettings,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.settings_rounded,
                  size: isLandscape ? 14 : 12,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '显示设置',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: isLandscape ? 11 : 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── 各个 Section ─────────────────────────────────

  List<Widget> _buildAllSections(List<WordDetailSection> sections) {
    final List<Widget> children = [];
    for (final section in sections) {
      children.add(
        Container(key: _sectionKeys[section], child: _buildSection(section)),
      );
    }
    return children;
  }

  Widget _buildSection(WordDetailSection section) {
    switch (section) {
      case WordDetailSection.chineseMeaning:
        return _buildChineseMeaning();
      case WordDetailSection.sentenceTranslation:
        return _buildSentenceTranslation();
      case WordDetailSection.definitions:
        return _buildDefinitions();
      case WordDetailSection.englishMeaning:
        return _buildEnglishMeaning();
      case WordDetailSection.partOfSpeech:
        return _buildPartOfSpeech();
      case WordDetailSection.examples:
        return _buildExamples();
      case WordDetailSection.difficulty:
        return _buildDifficulty();
      case WordDetailSection.morphology:
        return _buildMorphology();
      case WordDetailSection.mnemonic:
        return _buildMnemonic();
    }
  }

  // ─── Header ─────────────────────────────────

  Widget _buildHeader() {
    final pronounce = widget.data.pronounce;
    final hasPhonetic =
        (pronounce.ukPhonetic != null && pronounce.ukPhonetic!.isNotEmpty) ||
        (pronounce.usPhonetic != null && pronounce.usPhonetic!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.data.word,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: widget.data.word.length > 20 ? 16 : 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: 0.5,
                ),
                maxLines: widget.data.word.length > 20 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 发音按钮
            _buildPronounceButton(
              text: widget.data.word,
              icon: Icons.volume_up_rounded,
              size: 20,
            ),
            const SizedBox(width: 8),
            // 收藏按钮
            _buildSaveButton(),
          ],
        ),
        // 音标
        if (hasPhonetic)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                if (pronounce.ukPhonetic != null &&
                    pronounce.ukPhonetic!.isNotEmpty) ...[
                  Text(
                    'UK ',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '/${pronounce.ukPhonetic!}/',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                if (pronounce.ukPhonetic != null &&
                    pronounce.ukPhonetic!.isNotEmpty &&
                    pronounce.usPhonetic != null &&
                    pronounce.usPhonetic!.isNotEmpty)
                  SizedBox(width: 12),
                if (pronounce.usPhonetic != null &&
                    pronounce.usPhonetic!.isNotEmpty) ...[
                  Text(
                    'US ',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '/${pronounce.usPhonetic!}/',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPronounceButton({
    required String text,
    IconData icon = Icons.volume_up_outlined,
    double size = 16,
  }) {
    return InkWell(
      onTap: () => widget.onSpeak?.call(),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: size,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    if (widget.onSaveWord == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final isSaved = widget.isSaved;
    final isSaving = widget.saving;

    return InkWell(
      onTap: isSaving ? null : () => widget.onSaveWord?.call(),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSaved
              ? cs.primaryContainer.withValues(alpha: 0.3)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: isSaving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : Icon(
                isSaved
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 20,
                color: isSaved ? cs.primary : cs.onSurfaceVariant,
              ),
      ),
    );
  }

  // ─── Section: 中文释义 ─────────────────────────────────

  Widget _buildChineseMeaning() {
    final definitions = widget.data.definitions;
    if (definitions.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    final List<Widget> items = [];
    for (final d in definitions) {
      final meaning = d.chineseMeaning.trim();
      if (meaning.isEmpty) continue;

      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.partOfSpeech != null)
                Container(
                  margin: const EdgeInsets.only(right: 8, top: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    d.partOfSpeech!,
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  meaning,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildSectionContainer(
      title: WordDetailSection.chineseMeaning.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  // ─── Section: 当前句释义 ─────────────────────────────────

  Widget _buildSentenceTranslation() {
    if (widget.data.contextSentence == null &&
        widget.data.sentenceTranslation == null &&
        widget.data.translation == null) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    // 收集所有中文释义用于高亮
    final chineseMeanings = widget.data.definitions
        .map((d) => d.chineseMeaning.trim())
        .where((m) => m.isNotEmpty)
        .toList();
    return _buildSectionContainer(
      title: WordDetailSection.sentenceTranslation.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 英文句子（高亮当前单词）
          if (widget.data.contextSentence != null) ...[
            _buildRichContextSentence(chineseMeanings: chineseMeanings),
            const SizedBox(height: 8),
          ],
          // 中文翻译（高亮中文释义）
          if (widget.data.sentenceTranslation != null ||
              widget.data.translation != null)
            _buildRichChineseTranslation(
              chineseMeanings: chineseMeanings,
              cs: cs,
            ),
        ],
      ),
    );
  }

  /// 高亮英文句子中的单词
  Widget _buildRichContextSentence({required List<String> chineseMeanings}) {
    final sentence = widget.data.contextSentence!;
    final word = widget.data.word;
    // 先尝试精确匹配原词
    final escapedWord = RegExp.escape(word);
    final regex = RegExp(escapedWord, caseSensitive: false);
    final match = regex.firstMatch(sentence);

    if (match == null) {
      return Text(
        sentence,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 14,
          height: 1.5,
        ),
      );
    }

    final start = match.start;
    final end = match.end;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 14,
          height: 1.5,
        ),
        children: [
          TextSpan(text: sentence.substring(0, start)),
          TextSpan(
            text: sentence.substring(start, end),
            style: const TextStyle(
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: sentence.substring(end)),
        ],
      ),
    );
  }

  /// 高亮中文翻译中的释义
  Widget _buildRichChineseTranslation({
    required List<String> chineseMeanings,
    required ColorScheme cs,
  }) {
    final translation =
        widget.data.sentenceTranslation ?? widget.data.translation!;
    if (chineseMeanings.isEmpty) {
      return Text(
        translation,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.4),
      );
    }

    // 找到最长的匹配释义
    String? bestMatch;
    int bestStart = -1;
    int bestEnd = -1;
    for (final meaning in chineseMeanings) {
      final index = translation.indexOf(meaning);
      if (index != -1) {
        if (meaning.length > (bestMatch?.length ?? 0)) {
          bestMatch = meaning;
          bestStart = index;
          bestEnd = index + meaning.length;
        }
      }
    }

    if (bestMatch == null || bestStart == -1) {
      return Text(
        translation,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.4),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.4),
        children: [
          TextSpan(text: translation.substring(0, bestStart)),
          TextSpan(
            text: bestMatch,
            style: const TextStyle(
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: translation.substring(bestEnd)),
        ],
      ),
    );
  }

  // ─── Section: 词典释义 ─────────────────────────────────

  Widget _buildDefinitions() {
    if (widget.data.definitions.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return _buildSectionContainer(
      title: WordDetailSection.definitions.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.data.definitions.map((d) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (d.partOfSpeech != null) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 8, top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          d.partOfSpeech!,
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.chineseMeaning,
                            style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          if (d.englishMeaning != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                d.englishMeaning!,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 释义内嵌例句
                if (d.examples.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: d.examples.map((ex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex.english,
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    Text(
                                      ex.chinese,
                                      style: TextStyle(
                                        color: cs.onSurface.withValues(
                                          alpha: 0.5,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildPronounceButton(text: ex.english),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Section: 英文解释 ─────────────────────────────────

  Widget _buildEnglishMeaning() {
    final cs = Theme.of(context).colorScheme;
    // 从 definitions 中收集所有 englishMeaning
    final meanings = widget.data.definitions
        .where((d) => d.englishMeaning != null && d.englishMeaning!.isNotEmpty)
        .map((d) => d.englishMeaning!)
        .toList();
    if (meanings.isEmpty) return const SizedBox.shrink();
    return _buildSectionContainer(
      title: WordDetailSection.englishMeaning.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: meanings.map((m) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
                Expanded(
                  child: Text(
                    m,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Section: 词性 ─────────────────────────────────

  Widget _buildPartOfSpeech() {
    final cs = Theme.of(context).colorScheme;
    final posSet = <String>{};
    for (final d in widget.data.definitions) {
      if (d.partOfSpeech != null) posSet.add(d.partOfSpeech!);
    }
    if (posSet.isEmpty) {
      return const SizedBox.shrink();
    }
    return _buildSectionContainer(
      title: WordDetailSection.partOfSpeech.label,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: posSet.map((pos) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              pos,
              style: TextStyle(
                color: cs.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Section: 例句 ─────────────────────────────────

  Widget _buildExamples() {
    if (widget.data.standaloneExamples.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return _buildSectionContainer(
      title: WordDetailSection.examples.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.data.standaloneExamples.map((ex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.english,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ex.chinese,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPronounceButton(text: ex.english),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Section: 单词难度 ─────────────────────────────────

  Widget _buildDifficulty() {
    final cs = Theme.of(context).colorScheme;
    final diff = widget.data.difficulty;
    // 始终显示难度 section，即使未知也显示“未知”
    final color = diff == DifficultyLevel.unknown
        ? cs.outline
        : Color(diff.colorValue);
    return _buildSectionContainer(
      title: WordDetailSection.difficulty.label,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  widget.data.difficulty.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section: 词形变化 ─────────────────────────────────

  Widget _buildMorphology() {
    final cs = Theme.of(context).colorScheme;
    final morph = widget.data.morphology;
    if (morph == null) return const SizedBox.shrink();

    final List<Widget> items = [];

    // 词形变化表格
    final forms = <String, String?>{
      '复数': morph.plural,
      '过去式': morph.pastTense,
      '过去分词': morph.pastParticiple,
      '现在分词': morph.presentParticiple,
      '第三人称单数': morph.thirdPerson,
      '比较级': morph.comparative,
      '最高级': morph.superlative,
    };

    final effectiveForms = Map.fromEntries(
      forms.entries.where((e) => e.value != null && e.value!.isNotEmpty),
    );

    if (effectiveForms.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: effectiveForms.entries.map((e) {
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 4,
                    ),
                    child: Text(
                      e.key,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 3,
                      horizontal: 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        e.value!,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      );
    }

    // 同义词
    if (morph.synonyms.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  '同义',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: morph.synonyms.map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          color: Color(0xFF81C784),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 反义词
    if (morph.antonyms.isNotEmpty) {
      items.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 60,
              child: Text(
                '反义',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: morph.antonyms.map((a) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      a,
                      style: const TextStyle(
                        color: Color(0xFFEF9A9A),
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return _buildSectionContainer(
      title: WordDetailSection.morphology.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  // ─── Section: 记忆技巧 ─────────────────────────────────

  Widget _buildMnemonic() {
    if (widget.data.mnemonic == null || widget.data.mnemonic!.isEmpty)
      return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return _buildSectionContainer(
      title: WordDetailSection.mnemonic.label,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.data.mnemonic!,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<WordDetailSection> _buildEffectiveSections() {
    final raw = widget.config.sections;
    final out = <WordDetailSection>[];
    for (final section in raw) {
      if (_shouldShowSection(section)) {
        out.add(section);
      }
    }
    return out;
  }

  bool _shouldShowSection(WordDetailSection section) {
    final data = widget.data;
    switch (section) {
      case WordDetailSection.chineseMeaning:
        return data.definitions.any((d) => d.chineseMeaning.trim().isNotEmpty);
      case WordDetailSection.sentenceTranslation:
        return (data.sentenceTranslation != null &&
                data.sentenceTranslation!.trim().isNotEmpty) ||
            (data.translation != null && data.translation!.trim().isNotEmpty) ||
            (data.wordMeaningInContext != null &&
                data.wordMeaningInContext!.trim().isNotEmpty) ||
            (data.contextSentence != null &&
                data.contextSentence!.trim().isNotEmpty);
      case WordDetailSection.definitions:
        return data.definitions.isNotEmpty;
      case WordDetailSection.englishMeaning:
        return data.definitions.any(
          (d) =>
              d.englishMeaning != null && d.englishMeaning!.trim().isNotEmpty,
        );
      case WordDetailSection.partOfSpeech:
        return data.definitions.any(
          (d) => d.partOfSpeech != null && d.partOfSpeech!.trim().isNotEmpty,
        );
      case WordDetailSection.examples:
        return data.standaloneExamples.isNotEmpty ||
            data.definitions.any((d) => d.examples.isNotEmpty);
      case WordDetailSection.difficulty:
        return true;
      case WordDetailSection.morphology:
        return data.morphology != null;
      case WordDetailSection.mnemonic:
        return data.mnemonic != null && data.mnemonic!.trim().isNotEmpty;
    }
  }

  // ─── 显示设置（内联视图切换） ─────────────────────────────────

  void _enterSettings() {
    setState(() {
      _settingsSections = List.from(widget.config.sections);
      _showSettings = true;
    });
  }

  Future<void> _exitSettings({bool save = true}) async {
    if (_settingsSaving) return;

    if (save) {
      setState(() => _settingsSaving = true);
      final effectiveSections = _settingsSections.isEmpty
          ? [
              WordDetailSection.chineseMeaning,
              WordDetailSection.sentenceTranslation,
            ]
          : _settingsSections;
      final newConfig = widget.config.copyWith(sections: effectiveSections);
      final container = ProviderScope.containerOf(context);
      await newConfig.saveToSettings();
      container.read(displayConfigProvider.notifier).updateConfig(newConfig);
    }

    if (mounted) {
      setState(() {
        _showSettings = false;
        _settingsSaving = false;
      });
    }
  }

  void _settingsMoveUp(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _settingsSections.removeAt(index);
      _settingsSections.insert(index - 1, item);
    });
  }

  void _settingsMoveDown(int index) {
    if (index >= _settingsSections.length - 1) return;
    setState(() {
      final item = _settingsSections.removeAt(index);
      _settingsSections.insert(index + 1, item);
    });
  }

  void _settingsToggle(WordDetailSection section) {
    setState(() {
      if (_settingsSections.contains(section)) {
        _settingsSections.remove(section);
      } else {
        _settingsSections.add(section);
      }
    });
  }

  /// 设置视图：顶部返回+标题 + 可滚动设置列表
  Widget _buildSettingsView(ColorScheme cs) {
    final hidden = WordDetailSection.values
        .where((s) => !_settingsSections.contains(s))
        .toList();

    return Column(
      children: [
        // 顶部栏：返回按钮 + 标题
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: _settingsSaving ? null : () => _exitSettings(save: true),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
                Text(
                  '显示设置',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              const Spacer(),
              if (_settingsSaving)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 16, thickness: 0.5, indent: 16, endIndent: 16),
        // 可滚动设置区域
        Expanded(
          child: SingleChildScrollView(
            controller: _settingsScrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '拖动调整顺序，点击开关控制显示',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                // 已显示的区块
                ..._settingsSections.asMap().entries.map((entry) {
                  final index = entry.key;
                  final section = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.drag_handle,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            section.label,
                            style: TextStyle(fontSize: 14, color: cs.onSurface),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.arrow_upward,
                            size: 14,
                            color: index == 0
                                ? cs.onSurface.withValues(alpha: 0.2)
                                : cs.onSurfaceVariant,
                          ),
                          onPressed: index == 0
                              ? null
                              : () => _settingsMoveUp(index),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.arrow_downward,
                            size: 14,
                            color: index == _settingsSections.length - 1
                                ? cs.onSurface.withValues(alpha: 0.2)
                                : cs.onSurfaceVariant,
                          ),
                          onPressed: index == _settingsSections.length - 1
                              ? null
                              : () => _settingsMoveDown(index),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                        Switch(
                          value: true,
                          onChanged: (_) => _settingsToggle(section),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  );
                }),
                // 未显示的区块
                if (hidden.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, thickness: 0.5),
                  ),
                  Text(
                    '未显示的区块',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...hidden.map((section) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          const SizedBox(width: 24),
                          Expanded(
                            child: Text(
                              section.label,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _settingsToggle(section),
                            icon: const Icon(Icons.add, size: 12),
                            label: const Text(
                              '添加',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── 底部栏 ─────────────────────────────────

  Widget _buildBottomBar() {
    return const SizedBox.shrink();
  }

  // ─── 通用 Section 容器 ─────────────────────────────────

  Widget _buildSectionContainer({
    required String title,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
