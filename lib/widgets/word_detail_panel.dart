import 'package:flutter/material.dart';
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
  final Map<WordDetailSection, GlobalKey> _sectionKeys = {};

  WordDetailSection? _currentSection;
  bool _isLandscape = false;
  List<WordDetailSection> _effectiveSections = const [];

  @override
  void initState() {
    super.initState();
    for (final s in WordDetailSection.values) {
      _sectionKeys[s] = GlobalKey();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // 从后往前找，确定当前滚动位置对应的 section
    WordDetailSection? found;
    for (final s in _effectiveSections) {
      final key = _sectionKeys[s]!;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final pos = box.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
      // 考虑导航栏高度和 padding，判断该 section 是否在可视区域上方
      if (pos.dy <= 120) {
        found = s;
      }
    }
    if (found != null && found != _currentSection) {
      setState(() => _currentSection = found);
    }
  }

  void _scrollToSection(WordDetailSection section) {
    final key = _sectionKeys[section];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, alignment: 0.0);
    }
  }

  bool _checkLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height && size.width >= 600;
  }

  @override
  Widget build(BuildContext context) {
    _isLandscape = _checkLandscape(context);
    _effectiveSections = _buildEffectiveSections();
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onClose,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: cs.scrim.withValues(alpha: 0.54),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // 阻止点击内容区传播到外层
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return _buildLoadingState();
    }
    if (!widget.data.success && widget.data.error != null && !widget.data.isInsufficientBalance) {
      return _buildErrorState();
    }
    if (_isLandscape) {
      return _buildLandscapeLayout();
    }
    return _buildPortraitLayout();
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
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
            const SizedBox(height: 12),
            Text('正在查询「${widget.data.word}」...', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 16),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Text(
              widget.data.error ?? '查询失败',
              style: TextStyle(color: cs.error, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── 竖屏布局 ─────────────────────────────────

  Widget _buildPortraitLayout() {
    final cs = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: screenSize.width * 0.6,
        constraints: BoxConstraints(maxWidth: 420, maxHeight: screenSize.height * 0.6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 0), child: _buildHeader()),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildAllSections(_effectiveSections)),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ─── 横屏双栏布局 ─────────────────────────────────

  Widget _buildLandscapeLayout() {
    final cs = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: screenSize.width * 0.6,
        constraints: BoxConstraints(maxWidth: 700, maxHeight: screenSize.height * 0.8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 0), child: _buildHeader()),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧固定导航
                  Container(
                    width: 140,
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _effectiveSections.map((s) {
                        final isActive = s == _currentSection;
                        return GestureDetector(
                          onTap: () => _scrollToSection(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isActive ? cs.primary.withValues(alpha: 0.08) : null,
                              border: Border(left: BorderSide(color: isActive ? cs.primary : Colors.transparent, width: 3)),
                            ),
                            child: Text(
                              s.label,
                              style: TextStyle(
                                color: isActive ? cs.primary : cs.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // 右侧可滚动内容
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildAllSections(_effectiveSections)),
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

  // ─── 各个 Section ─────────────────────────────────

  List<Widget> _buildAllSections(List<WordDetailSection> sections) {
    final List<Widget> children = [];
    for (final section in sections) {
      children.add(Container(key: _sectionKeys[section], child: _buildSection(section)));
    }
    return children;
  }

  Widget _buildSection(WordDetailSection section) {
    switch (section) {
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
        (pronounce.ukPhonetic != null && pronounce.ukPhonetic!.isNotEmpty) || (pronounce.usPhonetic != null && pronounce.usPhonetic!.isNotEmpty);

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
                  fontSize: widget.data.word.length > 20 ? 18 : 26,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
                maxLines: widget.data.word.length > 20 ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 发音按钮
            _buildPronounceButton(text: widget.data.word, icon: Icons.volume_up_rounded, size: 22),
            const SizedBox(width: 12),
            // 收藏按钮
            _buildSaveButton(),
          ],
        ),
        // 音标
        if (hasPhonetic)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (pronounce.ukPhonetic != null && pronounce.ukPhonetic!.isNotEmpty) ...[
                  Text('英 ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                  Text(
                    '[${pronounce.ukPhonetic!}]',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w300),
                  ),
                ],
                if (pronounce.ukPhonetic != null &&
                    pronounce.ukPhonetic!.isNotEmpty &&
                    pronounce.usPhonetic != null &&
                    pronounce.usPhonetic!.isNotEmpty)
                  const SizedBox(width: 10),
                if (pronounce.usPhonetic != null && pronounce.usPhonetic!.isNotEmpty) ...[
                  Text('美 ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                  Text(
                    '[${pronounce.usPhonetic!}]',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w300),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPronounceButton({required String text, IconData icon = Icons.volume_up_outlined, double size = 18}) {
    return GestureDetector(
      onTap: () => widget.onSpeak?.call(),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: size),
      ),
    );
  }

  Widget _buildSaveButton() {
    if (widget.onSaveWord == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final isSaved = widget.isSaved;
    final isSaving = widget.saving;

    return GestureDetector(
      onTap: isSaving ? null : () => widget.onSaveWord?.call(),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSaved ? cs.primary.withValues(alpha: 0.15) : cs.surface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSaved ? cs.primary : cs.outlineVariant),
        ),
        child: isSaving
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
            : Icon(isSaved ? Icons.star_rounded : Icons.star_border_rounded, size: 22, color: isSaved ? cs.primary : cs.onSurfaceVariant),
      ),
    );
  }

  // ─── Section: 语境释义 ─────────────────────────────────

  Widget _buildSentenceTranslation() {
    if (widget.data.sentenceTranslation == null &&
        widget.data.translation == null &&
        widget.data.wordMeaningInContext == null &&
        widget.data.contextSentence == null) {
      return const SizedBox.shrink();
    }
    return _buildSectionContainer(
      title: WordDetailSection.sentenceTranslation.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.data.contextSentence != null) ...[_buildRichContextSentence(), const SizedBox(height: 6)],
          if (widget.data.wordMeaningInContext != null) ...[
            Text(widget.data.wordMeaningInContext!, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, height: 1.5)),
            const SizedBox(height: 4),
          ],
          if (widget.data.sentenceTranslation != null || widget.data.translation != null)
            Text(
              widget.data.sentenceTranslation ?? widget.data.translation!,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4),
            ),
        ],
      ),
    );
  }

  Widget _buildRichContextSentence() {
    final sentence = widget.data.contextSentence!;
    final word = widget.data.word.toLowerCase();
    final index = sentence.toLowerCase().indexOf(word);
    if (index == -1) {
      return Text(sentence, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 14, height: 1.5),
        children: [
          TextSpan(text: sentence.substring(0, index)),
          TextSpan(
            text: sentence.substring(index, index + word.length),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          TextSpan(text: sentence.substring(index + word.length)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          d.partOfSpeech!,
                          style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.chineseMeaning, style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.5)),
                          if (d.englishMeaning != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(d.englishMeaning!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
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
                                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontStyle: FontStyle.italic),
                                    ),
                                    Text(ex.chinese, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 11)),
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
                Text('• ', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                Expanded(
                  child: Text(m, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.5)),
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
              style: TextStyle(color: cs.primary, fontSize: 13, fontWeight: FontWeight.w500),
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
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 2),
                      Text(ex.chinese, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 12)),
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
    final color = diff == DifficultyLevel.unknown ? cs.outline : Color(diff.colorValue);
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
                Icon(Icons.school_outlined, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  widget.data.difficulty.label,
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
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

    final effectiveForms = Map.fromEntries(forms.entries.where((e) => e.value != null && e.value!.isNotEmpty));

    if (effectiveForms.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Table(
            columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: effectiveForms.entries.map((e) {
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                    child: Text(e.key, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        e.value!,
                        style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w500),
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
                child: Text('同义', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: morph.synonyms.map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF4CAF50).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(s, style: const TextStyle(color: Color(0xFF81C784), fontSize: 12)),
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
              child: Text('反义', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: morph.antonyms.map((a) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFFF5252).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(a, style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 12)),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: items),
    );
  }

  // ─── Section: 记忆技巧 ─────────────────────────────────

  Widget _buildMnemonic() {
    if (widget.data.mnemonic == null || widget.data.mnemonic!.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return _buildSectionContainer(
      title: WordDetailSection.mnemonic.label,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.data.mnemonic!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.5)),
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
      case WordDetailSection.sentenceTranslation:
        return (data.sentenceTranslation != null && data.sentenceTranslation!.trim().isNotEmpty) ||
            (data.translation != null && data.translation!.trim().isNotEmpty) ||
            (data.wordMeaningInContext != null && data.wordMeaningInContext!.trim().isNotEmpty) ||
            (data.contextSentence != null && data.contextSentence!.trim().isNotEmpty);
      case WordDetailSection.definitions:
        return data.definitions.isNotEmpty;
      case WordDetailSection.englishMeaning:
        return data.definitions.any((d) => d.englishMeaning != null && d.englishMeaning!.trim().isNotEmpty);
      case WordDetailSection.partOfSpeech:
        return data.definitions.any((d) => d.partOfSpeech != null && d.partOfSpeech!.trim().isNotEmpty);
      case WordDetailSection.examples:
        return data.standaloneExamples.isNotEmpty || data.definitions.any((d) => d.examples.isNotEmpty);
      case WordDetailSection.difficulty:
        return true;
      case WordDetailSection.morphology:
        return data.morphology != null;
      case WordDetailSection.mnemonic:
        return data.mnemonic != null && data.mnemonic!.trim().isNotEmpty;
    }
  }

  // ─── 底部栏 ─────────────────────────────────

  Widget _buildBottomBar() {
    return const SizedBox.shrink();
  }

  // ─── 通用 Section 容器 ─────────────────────────────────

  Widget _buildSectionContainer({required String title, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
