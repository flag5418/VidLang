import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/providers/display_config_provider.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

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

  /// 是否为短句翻译模式（仅显示翻译内容）
  final bool isSentenceMode;

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
    this.isSentenceMode = false,
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

  /// 检查文本是否为错误/无效内容（不显示给用户）
  bool _isErrorContent(String text) {
    if (text.isEmpty) return true;
    const errorPatterns = [
      '翻译失败',
      '翻译模型未就绪',
      '翻译模型加载失败',
      'Tokenization 失败',
      '本地翻译模型未就绪',
      '本地翻译失败',
      '查询失败',
      '未知',
      '失败',
      'Error',
      'error',
    ];
    for (final pattern in errorPatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
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
    // iOS 原生翻译返回错误信息时，也显示错误状态
    if (widget.data.source == 'ios_translate') {
      final translation = widget.data.translation ?? '';
      final error = widget.data.error ?? '';
      if (_isErrorContent(translation) || _isErrorContent(error)) {
        return _buildErrorState();
      }
    }
    return _buildContentLayout();
  }

  // ─── Loading 状态 ─────────────────────────────────

  Widget _buildLoadingState() {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width >= 600;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: isWide ? 520 : screenSize.width * 0.65,
        constraints: BoxConstraints(maxHeight: screenSize.height * 0.55),
        padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 28), vertical: Adaptive.h(context, 28)),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(Adaptive.r(context, 24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: Adaptive.sp(context, 13)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _buildHeader()),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Icon(Icons.close_rounded, size: 20, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              SizedBox(height: Adaptive.h(context, 24)),
              SizedBox(
                width: Adaptive.icon(context, 32),
                height: Adaptive.icon(context, 32),
                child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
              ),
              SizedBox(height: Adaptive.h(context, 16)),
              Text('正在查询「${widget.data.word}」...', style: TextStyle(fontSize: Adaptive.sp(context, 14), fontWeight: FontWeight.w500)),
              SizedBox(height: Adaptive.h(context, 6)),
              Text('正在连接 AI 翻译服务', style: TextStyle(fontSize: Adaptive.sp(context, 12), color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
              SizedBox(height: Adaptive.h(context, 16)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Error 状态 ─────────────────────────────────

  Widget _buildErrorState() {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width >= 600;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: isWide ? 420 : screenSize.width * 0.6,
        constraints: BoxConstraints(maxHeight: screenSize.height * 0.55),
        padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 24), vertical: Adaptive.h(context, 20)),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(Adaptive.r(context, 24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _buildHeader()),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Icon(Icons.close_rounded, size: 20, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            SizedBox(height: Adaptive.h(context, 16)),
            Icon(Icons.error_outline_rounded, size: 36, color: cs.error.withValues(alpha: 0.8)),
            SizedBox(height: Adaptive.h(context, 12)),
            Text(
              widget.data.error ?? '查询失败',
              style: TextStyle(color: cs.onSurface, fontSize: Adaptive.sp(context, 15), fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Adaptive.h(context, 6)),
            Text(
              '请检查网络连接后重试',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: Adaptive.sp(context, 13)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: Adaptive.h(context, 18)),
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
    final brightness = Theme.of(context).brightness;
    final screenSize = MediaQuery.of(context).size;
    final isLandscape =
        screenSize.width > screenSize.height && screenSize.width >= 600;
    final pad = isIPad(context);

    // 横竖屏尺寸参数 — iPad 下大幅放大
    final cardWidth = screenSize.width * (isLandscape ? (pad ? 0.78 : 0.65) : (pad ? 0.90 : 0.9));
    final maxHeight = screenSize.height * (isLandscape ? (pad ? 0.90 : 0.82) : (pad ? 0.80 : 0.65));
    final navWidth = isLandscape ? (pad ? 180.0 : 110.0) : (pad ? 150.0 : 96.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(maxWidth: pad ? 1000 : 700, maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(Adaptive.r(context, 24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.4 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.2 : 0.04),
              blurRadius: 6,
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
                    padding: EdgeInsets.fromLTRB(
                      Adaptive.w(context, 24),
                      Adaptive.h(context, 20),
                      Adaptive.w(context, 24),
                      Adaptive.h(context, 16),
                    ),
                    child: _buildHeader(),
                  ),
                  Container(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: brightness == Brightness.dark ? 0.3 : 0.15),
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
                          color: cs.outlineVariant.withValues(alpha: brightness == Brightness.dark ? 0.3 : 0.15),
                        ),
                        // 右侧可滚动内容
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              Adaptive.w(context, 20),
                              Adaptive.h(context, 16),
                              Adaptive.w(context, 20),
                              Adaptive.h(context, 24),
                            ),
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
          margin: EdgeInsets.only(bottom: Adaptive.h(context, 4), left: Adaptive.w(context, 8), right: Adaptive.w(context, 8)),
          padding: EdgeInsets.symmetric(
            horizontal: Adaptive.w(context, 8),
            vertical: Adaptive.h(context, isLandscape ? 10 : 8),
          ),
          decoration: BoxDecoration(
            color: isActive
                ? cs.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // 濯活指示条
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: isLandscape ? 18 : 16,
                decoration: BoxDecoration(
                  color: isActive ? cs.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: Adaptive.w(context, 8)),
              Expanded(
                child: Text(
                  s.label,
                  style: TextStyle(
                    color: isActive ? cs.primary : cs.onSurfaceVariant,
                    fontSize: isLandscape ? Adaptive.sp(context, 14) : Adaptive.sp(context, 13),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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
        Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.15)),
        GestureDetector(
          onTap: _enterSettings,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: Adaptive.w(context, 4),
              vertical: Adaptive.h(context, 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AppIcons.settings,
                  size: isLandscape ? Adaptive.icon(context, 14) : Adaptive.icon(context, 12),
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '显示设置',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: Adaptive.sp(context, 11),
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
                  fontSize: widget.data.word.length > 20 ? Adaptive.sp(context, 16) : Adaptive.sp(context, 20),
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
              icon: AppIcons.volumeUp,
              size: Adaptive.icon(context, 20),
            ),
            SizedBox(width: Adaptive.w(context, 8)),
            // 收藏按钮
            _buildSaveButton(),
          ],
        ),
        // 音标
        if (hasPhonetic)
          Padding(
            padding: EdgeInsets.only(top: Adaptive.h(context, 6)),
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
                      fontSize: Adaptive.sp(context, 11),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '/${pronounce.ukPhonetic!}/',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: Adaptive.sp(context, 12),
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
                      fontSize: Adaptive.sp(context, 11),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '/${pronounce.usPhonetic!}/',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: Adaptive.sp(context, 12),
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
    IconData icon = AppIcons.volumeUp,
    double size = 16,
  }) {
    return InkWell(
      onTap: () {
        if (text.isNotEmpty) {
          TtsService().speakClarity(text: text);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(Adaptive.w(context, 8)),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
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
        padding: EdgeInsets.all(Adaptive.w(context, 6)),
        decoration: BoxDecoration(
          color: isSaved
              ? cs.primaryContainer.withValues(alpha: 0.3)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Adaptive.r(context, 10)),
        ),
        child: isSaving
            ? SizedBox(
                width: Adaptive.icon(context, 20),
                height: Adaptive.icon(context, 20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            : Icon(
                isSaved
                    ? AppIcons.star
                    : AppIcons.starOutline,
                size: Adaptive.icon(context, 20),
                color: isSaved ? cs.primary : cs.onSurfaceVariant,
              ),
      ),
    );
  }

  // ─── Section: 中文释义 ─────────────────────────────────

  /// 检查字符串是否包含中文字符
  bool _containsChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  Widget _buildChineseMeaning() {
    final definitions = widget.data.definitions;
    final hasDefinitions = definitions.any((d) => d.chineseMeaning.trim().isNotEmpty);
    final rawTranslation = widget.data.translation?.trim() ?? '';
    final hasTranslation = rawTranslation.isNotEmpty && !_isErrorContent(rawTranslation);
    
    if (!hasDefinitions && !hasTranslation) return const SizedBox.shrink();
    
    final cs = Theme.of(context).colorScheme;
    final List<Widget> items = [];
    
    // 优先显示 definitions（结构化释义）
    for (final d in definitions) {
      var meaning = d.chineseMeaning.trim();
      if (meaning.isEmpty) continue;

      // 如果 chineseMeaning 没有中文字符（AI 返回了英文），尝试兜底
      if (!_containsChinese(meaning)) {
        // 优先使用 translation 作为兜底
        if (hasTranslation) {
          meaning = widget.data.translation!;
        } else if (d.englishMeaning != null && d.englishMeaning!.isNotEmpty) {
          // 标记为英文释义（灰色斜体显示）
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
                          fontSize: Adaptive.sp(context, 11),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      d.englishMeaning!,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: Adaptive.sp(context, 14),
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
          continue;
        }
      }

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
                      fontSize: Adaptive.sp(context, 11),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  meaning,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: Adaptive.sp(context, 15),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 如果没有 definitions 但有 translation，显示 translation 作为兜底
    if (items.isEmpty && hasTranslation) {
      items.add(
        Text(
          widget.data.translation!,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: Adaptive.sp(context, 15),
            height: 1.5,
          ),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

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
    if (widget.data.isSentenceMode) {
      return _buildSentenceTranslationForSentenceMode();
    }
    
    if (widget.data.contextSentence == null &&
        widget.data.sentenceTranslation == null &&
        widget.data.translation == null) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return _buildSectionContainer(
      title: WordDetailSection.sentenceTranslation.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 英文句子（高亮当前单词）
          if (widget.data.contextSentence != null) ...[
            _buildRichContextSentence(),
            const SizedBox(height: 8),
          ],
          // 中文翻译（高亮当前单词的中文释义）
          if (widget.data.sentenceTranslation != null ||
              widget.data.translation != null)
            _buildRichChineseTranslation(),
          // 语境中的词义
          if (widget.data.wordMeaningInContext != null &&
              widget.data.wordMeaningInContext!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '在此句中：${widget.data.wordMeaningInContext}',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                    fontSize: Adaptive.sp(context, 12),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 短句模式下的当前句释义（仅显示中文翻译）
  Widget _buildSentenceTranslationForSentenceMode() {
    final translation = widget.data.sentenceTranslation ?? widget.data.translation;
    if (translation == null || translation.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    
    final cs = Theme.of(context).colorScheme;
    return _buildSectionContainer(
      title: WordDetailSection.sentenceTranslation.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 中文翻译（高亮当前单词的中文释义）
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  translation,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: Adaptive.sp(context, 13),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 播放按钮
              _buildPronounceButton(text: translation, size: Adaptive.icon(context, 14)),
            ],
          ),
        ],
      ),
    );
  }

  /// 高亮英文句子中的单词
  /// 支持两种模式：
  /// 1. AI 已用【】包裹高亮 → 直接渲染高亮标记
  /// 2. 原始句子 → 自动查找并高亮目标单词
  Widget _buildRichContextSentence() {
    final sentence = widget.data.contextSentence!;
    final word = widget.data.word;
    final cs = Theme.of(context).colorScheme;

    // 检查是否已包含 AI 高亮标记【】
    if (sentence.contains('【') && sentence.contains('】')) {
      return _buildHighlightedText(sentence, highlightColor: const Color(0xFF1976D2));
    }

    // 降级：自动匹配并高亮
    final escapedWord = RegExp.escape(word);
    final regex = RegExp(escapedWord, caseSensitive: false);
    final match = regex.firstMatch(sentence);

    if (match == null) {
      return Text(
        sentence,
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: Adaptive.sp(context, 14),
          height: 1.5,
        ),
      );
    }

    final start = match.start;
    final end = match.end;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: Adaptive.sp(context, 14),
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

  /// 高亮中文翻译中的词义
  /// 支持两种模式：
  /// 1. AI 已用【】包裹高亮 → 直接渲染
  /// 2. 原始翻译 → 直接显示
  Widget _buildRichChineseTranslation() {
    final translation = widget.data.sentenceTranslation ?? widget.data.translation ?? '';
    final cs = Theme.of(context).colorScheme;

    // 检查是否包含 AI 高亮标记
    if (translation.contains('【') && translation.contains('】')) {
      return _buildHighlightedText(translation, highlightColor: const Color(0xFFE65100));
    }

    // 无高亮标记，直接显示
    return Text(
      translation,
      style: TextStyle(
        color: cs.onSurfaceVariant,
                    fontSize: Adaptive.sp(context, 13),
        height: 1.4,
      ),
    );
  }

  /// 渲染带【】高亮标记的文本
  Widget _buildHighlightedText(String text, {required Color highlightColor}) {
    final cs = Theme.of(context).colorScheme;
    // 按【】分割文本
    final parts = <InlineSpan>[];
    final regex = RegExp(r'【([^】]*)】');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // 高亮前的普通文本
      if (match.start > lastEnd) {
        parts.add(TextSpan(
          text: text.substring(lastEnd, match.start),
        ));
      }
      // 高亮文本
      parts.add(TextSpan(
        text: match.group(1) ?? '',
        style: TextStyle(
          color: highlightColor,
          fontWeight: FontWeight.bold,
          backgroundColor: highlightColor.withValues(alpha: 0.1),
        ),
      ));
      lastEnd = match.end;
    }
    // 剩余文本
    if (lastEnd < text.length) {
      parts.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: Adaptive.sp(context, 14),
          height: 1.5,
        ),
        children: parts,
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
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: Adaptive.sp(context, 14)),
                ),
                Expanded(
                  child: Text(
                    m,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: Adaptive.sp(context, 14),
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
                    fontSize: Adaptive.sp(context, 13),
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
    final cs = Theme.of(context).colorScheme;
    final targetWord = widget.data.word;
    
    // 收集所有例句：standalone_examples + definitions 中的 examples
    final List<WordExample> allExamples = [];
    
    // 1. standalone_examples（独立例句区块）
    allExamples.addAll(widget.data.standaloneExamples);
    
    // 2. definitions 中的 examples（每个词性下的例句）
    for (final d in widget.data.definitions) {
      allExamples.addAll(d.examples);
    }
    
    if (allExamples.isEmpty) return const SizedBox.shrink();
    
    // 去重：基于英文内容
    final seen = <String>{};
    final uniqueExamples = <WordExample>[];
    for (final ex in allExamples) {
      final key = ex.english.trim().toLowerCase();
      if (key.isNotEmpty && !seen.contains(key)) {
        seen.add(key);
        uniqueExamples.add(ex);
      }
    }

    return _buildSectionContainer(
      title: WordDetailSection.examples.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: uniqueExamples.map((ex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 英文例句：高亮目标单词
                      _buildExampleEnglish(ex.english, targetWord, cs),
                      const SizedBox(height: 2),
                      // 中文翻译
                      Text(
                        ex.chinese,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontSize: Adaptive.sp(context, 12),
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

  /// 渲染例句英文，自动高亮目标单词
  Widget _buildExampleEnglish(String english, String targetWord, ColorScheme cs) {
    // 检查是否已包含 AI 高亮标记【】
    if (english.contains('【') && english.contains('】')) {
      return _buildHighlightedText(english, highlightColor: const Color(0xFF1976D2));
    }

    // 自动匹配并高亮目标单词（忽略大小写、忽略标点后缀）
    final escapedWord = RegExp.escape(targetWord);
    final regex = RegExp(r'\b' + escapedWord + r'\b', caseSensitive: false);
    final match = regex.firstMatch(english);

    if (match == null) {
      return Text(
        english,
        style: TextStyle(
          color: cs.onSurfaceVariant,
                    fontSize: Adaptive.sp(context, 14),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final start = match.start;
    final end = match.end;
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: cs.onSurfaceVariant,
                    fontSize: Adaptive.sp(context, 14),
          fontStyle: FontStyle.italic,
        ),
        children: [
          TextSpan(text: english.substring(0, start)),
          TextSpan(
            text: english.substring(start, end),
            style: const TextStyle(
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          TextSpan(text: english.substring(end)),
        ],
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
                Icon(AppIcons.school, size: Adaptive.icon(context, 14), color: color),
                const SizedBox(width: 6),
                Text(
                  widget.data.difficulty.label,
                  style: TextStyle(
                    color: color,
                    fontSize: Adaptive.sp(context, 13),
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
                        fontSize: Adaptive.sp(context, 13),
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
                          fontSize: Adaptive.sp(context, 13),
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
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: Adaptive.sp(context, 13)),
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
                        style: TextStyle(
                          color: const Color(0xFF81C784),
                          fontSize: Adaptive.sp(context, 12),
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
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: Adaptive.sp(context, 13)),
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
                      style: TextStyle(
                        color: const Color(0xFFEF9A9A),
                        fontSize: Adaptive.sp(context, 12),
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
    if (widget.data.mnemonic == null || widget.data.mnemonic!.isEmpty) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return _buildSectionContainer(
      title: WordDetailSection.mnemonic.label,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.lightbulbOutline, size: Adaptive.icon(context, 16), color: cs.primary),
          SizedBox(width: Adaptive.w(context, 8)),
          Expanded(
            child: Text(
              widget.data.mnemonic!,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                    fontSize: Adaptive.sp(context, 14),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<WordDetailSection> _buildEffectiveSections() {
    if (widget.data.isSentenceMode) {
      return [WordDetailSection.sentenceTranslation];
    }
    
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
                    AppIcons.arrowBackIosNew,
                    size: Adaptive.icon(context, 18),
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 4),
                Text(
                  '显示设置',
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 15),
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
                  style: TextStyle(fontSize: Adaptive.sp(context, 12), color: cs.onSurfaceVariant),
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
                          AppIcons.dragHandle,
                          size: Adaptive.icon(context, 20),
                          color: cs.onSurfaceVariant,
                        ),
                        SizedBox(width: Adaptive.w(context, 8)),
                        Expanded(
                          child: Text(
                            section.label,
                            style: TextStyle(fontSize: Adaptive.sp(context, 14), color: cs.onSurface),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            AppIcons.arrowUpward,
                            size: Adaptive.icon(context, 18),
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
                            AppIcons.arrowDownward,
                            size: Adaptive.icon(context, 18),
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
                      fontSize: Adaptive.sp(context, 13),
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
                          SizedBox(width: Adaptive.w(context, 28)),
                          Expanded(
                            child: Text(
                              section.label,
                              style: TextStyle(
                                fontSize: Adaptive.sp(context, 14),
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _settingsToggle(section),
                            icon: Icon(AppIcons.add, size: Adaptive.icon(context, 12)),
                            label: Text(
                              '添加',
                                style: TextStyle(fontSize: Adaptive.sp(context, 12)),
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

  // ─── 通用 Section 容器（卡片式布局） ──────────────────────

  Widget _buildSectionContainer({
    required String title,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(Adaptive.r(context, 16)),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? cs.surfaceContainerLow
              : cs.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(Adaptive.r(context, 16)),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: brightness == Brightness.dark ? 0.15 : 0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 标题行
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    constraints: BoxConstraints(
                      minWidth: Adaptive.w(context, 4),
                    ),
                    height: Adaptive.h(context, 18),
                    width: Adaptive.w(context, 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(Adaptive.r(context, 3)),
                    ),
                  ),
                  SizedBox(width: Adaptive.w(context, 10)),
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: Adaptive.sp(context, 14),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            // 内容
            child,
          ],
        ),
      ),
    );
  }
}
