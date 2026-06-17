import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_chapter.dart';
import 'package:vidlang/models/article_paragraph.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/models/article_translation.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/translation_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/widgets/article/selectable_paragraph_text.dart';
import 'package:vidlang/widgets/word_card.dart';

/// 文章阅读器页面
class ArticleReaderPage extends StatefulWidget {
  final String articleCode;
  const ArticleReaderPage({super.key, required this.articleCode});
  @override
  State<ArticleReaderPage> createState() => _ArticleReaderPageState();
}

class _ArticleReaderPageState extends State<ArticleReaderPage> {
  Article? _article;
  List<ArticleChapter> _chapters = [];
  List<ArticleParagraph> _paragraphs = [];
  List<ArticleSentence> _sentences = [];
  bool _isLoading = true;
  double _fontSize = 16.0;

  // 段落激活
  int? _activeParagraphIndex;

  // 划词选择状态
  bool _isSelecting = false; // 划词进行中（禁用滚动）

  // 阅读位置（句子索引）
  int _readSentenceIndex = 0;

  // 同文件夹文章列表
  List<Article> _folderArticles = [];
  bool _showArticleList = false;

  // 字体大小弹窗
  bool _showFontSizePopup = false;

  // Scroll
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _paragraphKeys = {};

  // 单词标记
  final Map<String, Color> _markedWords = {};
  static const _markerColors = [
    Color(0xFFE57373), Color(0xFFFFB74D), Color(0xFFFFF176),
    Color(0xFF81C784), Color(0xFF64B5F6), Color(0xFFCE93D8),
  ];

  // 翻译
  ArticleTranslation? _translation;
  bool _showTranslation = false;
  bool _loadingTranslation = false;
  bool get _isPaidMode => AppConfig.currentUser?.authProvider == 'supabase';

  // 划词工具栏
  String? _selectionText;
  Offset? _toolbarOffset;
  final SelectableParagraphTextController _selectionController = SelectableParagraphTextController();

  // TTS
  FlutterTts? _flutterTts;
  bool _ttsAvailable = false;
  bool _isSpeaking = false;
  int _ttsCurrentWordIndex = -1;
  List<String> _ttsWords = [];
  Timer? _ttsTimer;
  bool _ttsProgressHandlerFired = false;
  ap.AudioPlayer? _audioPlayer;
  StreamSubscription? _audioPositionSub;
  StreamSubscription? _audioDurationSub;
  int? _audioTotalDurationMs;

  // 全文朗读
  bool _isReadingAll = false;
  int _readingAllParagraphIndex = 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer = ap.AudioPlayer();
    _initFontSize();
    _initTts();
    _loadArticle();
  }

  @override
  void didUpdateWidget(covariant ArticleReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleCode != widget.articleCode) {
      _resetForNewArticle();
      _loadArticle();
    }
  }

  void _resetForNewArticle() {
    _ttsTimer?.cancel();
    _isSpeaking = false;
    _ttsCurrentWordIndex = -1;
    _ttsWords = [];
    _translation = null;
    _showTranslation = false;
    _loadingTranslation = false;
    _markedWords.clear();
    _paragraphKeys.clear();
    _isSelecting = false;
    _showArticleList = false;
    _showFontSizePopup = false;
    _scrollController.removeListener(_onScroll);
    _stopReadingAll();
    setState(() {
      _article = null; _chapters = []; _paragraphs = []; _sentences = [];
      _isLoading = true; _readSentenceIndex = 0; _activeParagraphIndex = null;
      _selectionText = null; _toolbarOffset = null;
      _folderArticles = [];
    });
  }

  @override
  void dispose() {
    _saveReadingPosition();
    _flutterTts?.stop();
    _ttsTimer?.cancel();
    _audioPositionSub?.cancel();
    _audioDurationSub?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _fontSize = prefs.getDouble('article_reader_font_size') ?? 16.0);
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    try {
      await _flutterTts!.setLanguage('en-US');
      await _flutterTts!.setSpeechRate(0.5);
      await _flutterTts!.setPitch(1.0);
      _flutterTts!.setProgressHandler((String text, int start, int end, String word) {
        _ttsProgressHandlerFired = true;
        _ttsTimer?.cancel();
        _ttsTimer = null;
        final idx = _ttsWords.indexOf(word);
        if (idx >= 0 && mounted) setState(() => _ttsCurrentWordIndex = idx);
      });
      _flutterTts!.setCompletionHandler(() {
        _ttsTimer?.cancel();
        _ttsTimer = null;
        if (mounted) {
          setState(() { _isSpeaking = false; _ttsCurrentWordIndex = -1; _ttsWords = []; });
          if (_isReadingAll) _readAllNext();
        }
      });
      _ttsAvailable = true;
    } catch (_) { _ttsAvailable = false; }
  }

  Future<void> _loadArticle() async {
    final article = await BaseEntityExtension.findByCode<Article>(widget.articleCode, () => Article());
    if (article == null) { if (mounted) Navigator.pop(context); return; }

    final chapters = await DatabaseService.findByCondition<ArticleChapter>(
      () => ArticleChapter(), where: 'article_code = ? AND is_deleted = 0',
      whereArgs: [widget.articleCode], orderBy: 'chapter_index ASC',
    );
    final sentences = await DatabaseService.findByCondition<ArticleSentence>(
      () => ArticleSentence(), where: 'article_code = ? AND is_deleted = 0',
      whereArgs: [widget.articleCode], orderBy: 'sentence_index ASC',
    );
    final paragraphs = await DatabaseService.findByCondition<ArticleParagraph>(
      () => ArticleParagraph(), where: 'article_code = ? AND is_deleted = 0',
      whereArgs: [widget.articleCode], orderBy: 'paragraph_index ASC',
    );

    // 检测是否需要修复段落（旧数据所有句子 paragraphIndex=0）
    final uniqueParaIndices = sentences.map((s) => s.paragraphIndex).toSet();
    if (sentences.length > 1 && uniqueParaIndices.length == 1 && paragraphs.isEmpty) {
      print('⚠️ 检测到旧数据，所有句子在同一段落，尝试修复...');
      final fixed = await _fixArticleParagraphs(article, sentences);
      if (fixed != null) {
        setState(() {
          _sentences = fixed.$1;
          _paragraphs = fixed.$2;
        });
      }
    }

    setState(() {
      _article = article;
      _chapters = chapters;
      if (_sentences.isEmpty) _sentences = sentences;
      if (_paragraphs.isEmpty) _paragraphs = paragraphs;
      _readSentenceIndex = article.lastSentenceIndex;
      _isLoading = false;
    });

    // 加载同文件夹文章列表（用于侧边栏）
    final folderArticles = await DatabaseService.findByCondition<Article>(
      () => Article(),
      where: 'folder_code = ? AND is_deleted = 0',
      whereArgs: [article.folderCode],
      orderBy: 'order_index ASC, created_at ASC',
    );
    if (mounted) {
      setState(() => _folderArticles = folderArticles);
    }

    // ── 段落调试信息 ──
    final List<int> paraIndices;
    if (_paragraphs.isNotEmpty) {
      paraIndices = _paragraphs.map((p) => p.paragraphIndex).toList()..sort();
    } else {
      paraIndices = _sentences.map((s) => s.paragraphIndex).toSet().toList()..sort();
    }
    print('═══ 文章段落调试 ═══');
    print('文章: ${article.title}');
    print('ArticleParagraph 记录数: ${_paragraphs.length}');
    print('从句子推导的段落数: ${_sentences.map((s) => s.paragraphIndex).toSet().length}');
    print('段落索引列表: $paraIndices');
    print('总句子数: ${_sentences.length}');
    for (final pIdx in paraIndices) {
      final sents = _sentences.where((s) => s.paragraphIndex == pIdx).toList();
      final preview = sents.map((s) => s.content).join(' ');
      final short = preview.length > 80 ? '${preview.substring(0, 80)}...' : preview;
      print('  段落[$pIdx]: ${sents.length}句 → $short');
    }
    print('═══════════════════');

    _loadTranslation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(_onScroll);
    });
  }

  /// 修复旧数据：从文章原文重新解析段落边界，更新句子和段落记录
  Future<(List<ArticleSentence>, List<ArticleParagraph>)?> _fixArticleParagraphs(
      Article article, List<ArticleSentence> sentences) async {
    if (article.contentMarkdown.isEmpty) return null;

    // 统一换行符
    final normalized = article.contentMarkdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    // 提取段落文本（按空行分隔）
    final paragraphTexts = <String>[];
    final currentLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        if (currentLines.isNotEmpty) {
          paragraphTexts.add(currentLines.join(' '));
          currentLines.clear();
        }
      } else {
        currentLines.add(trimmed);
      }
    }
    if (currentLines.isNotEmpty) {
      paragraphTexts.add(currentLines.join(' '));
    }

    if (paragraphTexts.length <= 1) return null; // 只有一段，无法修复

    print('  修复: 从原文解析到 ${paragraphTexts.length} 个段落');

    // 为每个句子分配段落索引
    int currentParaIdx = 0;
    for (final sentence in sentences) {
      final content = sentence.content.trim();
      // 在当前段落中查找句子内容
      while (currentParaIdx < paragraphTexts.length &&
          !paragraphTexts[currentParaIdx].contains(content)) {
        currentParaIdx++;
      }
      if (currentParaIdx >= paragraphTexts.length) {
        currentParaIdx = paragraphTexts.length - 1;
      }
      sentence.paragraphIndex = currentParaIdx;
    }

    // 创建 ArticleParagraph 记录
    final paragraphs = <ArticleParagraph>[];
    for (int i = 0; i < paragraphTexts.length; i++) {
      final paraSentences = sentences.where((s) => s.paragraphIndex == i).toList();
      if (paraSentences.isEmpty) continue;
      paragraphs.add(
        ArticleParagraph(
          articleCode: article.code!,
          paragraphIndex: i,
          contentMarkdown: paragraphTexts[i],
          contentPlain: paragraphTexts[i],
          startSentenceIdx: paraSentences.first.sentenceIndex,
          endSentenceIdx: paraSentences.last.sentenceIndex,
        )..code = const Uuid().v4().replaceAll('-', ''),
      );
    }

    // 更新数据库
    for (final s in sentences) {
      await DatabaseService.update(s);
    }
    for (final p in paragraphs) {
      await DatabaseService.insert(p);
    }
    // 更新文章段落数
    article.totalParagraphs = paragraphs.length;
    await DatabaseService.update(article);

    print('  修复完成: ${paragraphs.length} 段落');
    return (sentences, paragraphs);
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _sentences.isEmpty || _isSelecting) return;
    final viewportHeight = _scrollController.position.viewportDimension;
    final viewportCenter = _scrollController.offset + viewportHeight * 0.3;

    int? bestParaIdx;
    double bestDistance = double.infinity;

    for (final entry in _paragraphKeys.entries) {
      final key = entry.value;
      if (key.currentContext == null) continue;
      final box = key.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final offset = box.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
      final center = offset.dy + box.size.height / 2;
      final distance = (center - viewportCenter).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestParaIdx = entry.key;
      }
    }

    // 更新阅读位置和激活段落
    if (bestParaIdx != null) {
      final firstSentence = _sentencesForParagraph(bestParaIdx).firstOrNull;
      if (firstSentence != null && firstSentence.sentenceIndex != _readSentenceIndex) {
        _readSentenceIndex = firstSentence.sentenceIndex;
      }
      if (_activeParagraphIndex != bestParaIdx) {
        _activeParagraphIndex = bestParaIdx;
        setState(() {});
      }
    }
  }

  Future<void> _loadTranslation() async {
    if (_article == null) return;
    setState(() => _loadingTranslation = true);
    try {
      final t = await TranslationService.translateArticle(
        articleCode: widget.articleCode, article: _article!,
        chapters: _chapters, paragraphs: _paragraphs, sentences: _sentences,
      );
      if (mounted && t != null) {
        setState(() { _translation = t; _loadingTranslation = false; });
      } else if (mounted) {
        setState(() => _loadingTranslation = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTranslation = false);
    }
  }

  Future<void> _saveReadingPosition() async {
    if (_article == null) return;
    _article!.lastSentenceIndex = _readSentenceIndex;
    _article!.lastStudyDate = DateTime.now();
    _article!.studyCount = (_article!.studyCount) + 1;
    if (_sentences.isNotEmpty) {
      _article!.progress = (_readSentenceIndex + 1) / _sentences.length;
    }
    try { await _article!.save(); } catch (_) {}
  }

  void _openWordCard(String text, {String? contextSentence}) {
    WordCard.show(context, word: text, contextSentence: contextSentence,
      isPaidMode: _isPaidMode, sourceType: 'article', sourceCode: widget.articleCode,
      sourceTitle: _article?.title,
      onSaveWord: ({required String word, String? contextSentence, required String sourceType, required String sourceCode, String? sourceTitle}) async {
        final wb = await WordBookService.saveWord(
          word: word, contextSentence: contextSentence,
          sourceType: sourceType, sourceCode: sourceCode, sourceTitle: sourceTitle,
        );
        return wb != null;
      },
    );
  }

  // ── TTS ──

  Future<void> _speakText(String text) async {
    if (_isPaidMode) { await _speakWithAiTts(text); }
    else { await _speakWithNativeTts(text); }
  }

  Future<void> _speakWithAiTts(String text) async {
    setState(() { _isSpeaking = true; _ttsCurrentWordIndex = -1; });

    try {
      final result = await AiService.getTtsAudio(
        text: text,
        sourceType: 'article',
        sourceCode: widget.articleCode,
      );

      if (result == null || !mounted) {
        print('⚠️ AI TTS 返回 null，回退到系统 TTS');
        setState(() => _isSpeaking = false);
        if (mounted) await _speakWithNativeTts(text);
        return;
      }

      final audioBase64 = result['audioBase64'] as String?;
      if (audioBase64 == null || audioBase64.isEmpty) {
        print('⚠️ AI TTS 返回空音频，回退到系统 TTS');
        setState(() => _isSpeaking = false);
        if (mounted) await _speakWithNativeTts(text);
        return;
      }

      final tmpDir = Directory.systemTemp;
      final file = File('${tmpDir.path}/tts_article_premium.mp3');
      await file.writeAsBytes(base64.decode(audioBase64));

      // 准备单词列表用于高亮
      final wordRegex = RegExp(r'(\b\w+\b|[^\w]+|\s+)');
      _ttsWords = wordRegex.allMatches(text)
          .map((m) => m.group(0)!)
          .where((t) => t.trim().isNotEmpty && RegExp(r'\w').hasMatch(t))
          .toList();
      _ttsCurrentWordIndex = _ttsWords.isNotEmpty ? 0 : -1;
      if (mounted) setState(() {});

      await _audioPlayer?.stop();
      _audioPositionSub?.cancel();
      _audioDurationSub?.cancel();
      _audioTotalDurationMs = null;

      // 监听音频总时长
      _audioDurationSub = _audioPlayer?.onDurationChanged.listen((d) {
        _audioTotalDurationMs = d.inMilliseconds;
      });

      // 监听播放位置，同步单词高亮
      _audioPositionSub = _audioPlayer?.onPositionChanged.listen((position) {
        if (!mounted || _ttsWords.isEmpty || _audioTotalDurationMs == null || _audioTotalDurationMs == 0) return;
        final progress = position.inMilliseconds / _audioTotalDurationMs!;
        final wordIdx = (progress * _ttsWords.length).floor().clamp(0, _ttsWords.length - 1);
        if (wordIdx != _ttsCurrentWordIndex) {
          setState(() => _ttsCurrentWordIndex = wordIdx);
        }
      });

      await _audioPlayer?.play(ap.DeviceFileSource(file.path));

      _audioPlayer?.onPlayerComplete.first.then((_) {
        _audioPositionSub?.cancel();
        _audioDurationSub?.cancel();
        if (!mounted) return;
        setState(() { _isSpeaking = false; _ttsCurrentWordIndex = -1; _ttsWords = []; });
        if (_isReadingAll) _readAllNext();
      });
    } catch (e) {
      print('⚠️ AI TTS 异常: $e');
      _audioPositionSub?.cancel();
      _audioDurationSub?.cancel();
      if (mounted) {
        setState(() => _isSpeaking = false);
        await _speakWithNativeTts(text);
      }
    }
  }

  Future<void> _speakWithNativeTts(String text) async {
    if (!_ttsAvailable || _flutterTts == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TTS 不可用')));
      return;
    }
    await _flutterTts!.stop();
    _ttsTimer?.cancel();
    _isSpeaking = false;
    _ttsCurrentWordIndex = -1;
    _ttsWords = [];
    _ttsProgressHandlerFired = false;

    final wordRegex = RegExp(r'(\b\w+\b|[^\w]+|\s+)');
    _ttsWords = wordRegex.allMatches(text).map((m) => m.group(0)!).where((t) => t.trim().isNotEmpty && RegExp(r'\w').hasMatch(t)).toList();

    if (_ttsWords.isEmpty) {
      try { await _flutterTts!.speak(text); } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('朗读失败: $e')));
      }
      return;
    }

    _ttsCurrentWordIndex = 0;
    setState(() => _isSpeaking = true);

    _ttsTimer = Timer(const Duration(seconds: 1), () {
      if (_ttsProgressHandlerFired || !mounted) return;
      _ttsTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
        if (!mounted) { timer.cancel(); return; }
        if (_ttsCurrentWordIndex >= _ttsWords.length - 1) {
          timer.cancel(); _ttsTimer = null;
          if (mounted) {
            setState(() { _isSpeaking = false; _ttsCurrentWordIndex = -1; _ttsWords = []; });
            if (_isReadingAll) _readAllNext();
          }
          return;
        }
        setState(() => _ttsCurrentWordIndex++);
      });
    });

    try { await _flutterTts!.speak(text); } catch (e) {
      _ttsTimer?.cancel(); _ttsTimer = null;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('朗读失败: $e')));
    }
  }

  void _stopSpeaking() {
    _ttsTimer?.cancel();
    _flutterTts?.stop();
    _audioPositionSub?.cancel();
    _audioDurationSub?.cancel();
    _audioPlayer?.stop();
    _isReadingAll = false;
    if (mounted) setState(() { _isSpeaking = false; _ttsCurrentWordIndex = -1; _ttsWords = []; });
  }

  // ── 全文朗读 ──

  void _startReadAll() {
    if (_sentences.isEmpty) return;
    final sortedParas = _getParagraphIndices();
    if (sortedParas.isEmpty) return;
    final startPara = _activeParagraphIndex ?? sortedParas.first;
    _isReadingAll = true;
    _readingAllParagraphIndex = startPara;
    _speakCurrentParagraph();
  }

  void _stopReadingAll() { _isReadingAll = false; _stopSpeaking(); }

  void _readAllNext() {
    if (!_isReadingAll) return;
    final sortedParas = _getParagraphIndices();
    final currentIdx = sortedParas.indexOf(_readingAllParagraphIndex);
    if (currentIdx < 0 || currentIdx >= sortedParas.length - 1) {
      _isReadingAll = false; if (mounted) setState(() {}); return;
    }
    _readingAllParagraphIndex = sortedParas[currentIdx + 1];
    setState(() { _activeParagraphIndex = _readingAllParagraphIndex; });
    _scrollToParagraph(_readingAllParagraphIndex);
    _speakCurrentParagraph();
  }

  void _speakCurrentParagraph() {
    final sentences = _sentences.where((s) => s.paragraphIndex == _readingAllParagraphIndex).toList();
    if (sentences.isEmpty) { _readAllNext(); return; }
    _speakText(sentences.map((s) => s.content).join(' '));
  }

  void _scrollToParagraph(int paragraphIndex) {
    final key = _paragraphKeys[paragraphIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  List<int> _getParagraphIndices() {
    // 优先使用 ArticleParagraph 模型，否则从句子 paragraphIndex 推导
    if (_paragraphs.isNotEmpty) {
      return _paragraphs.map((p) => p.paragraphIndex).toList()..sort();
    }
    final indices = _sentences.map((s) => s.paragraphIndex).toSet().toList()..sort();
    return indices;
  }

  List<ArticleSentence> _sentencesForParagraph(int paragraphIndex) {
    return _sentences.where((s) => s.paragraphIndex == paragraphIndex).toList();
  }

  // ── 段落朗读 ──

  void _speakParagraph(int paragraphIndex) {
    final sentences = _sentencesForParagraph(paragraphIndex);
    if (sentences.isEmpty) return;
    _speakText(sentences.map((s) => s.content).join(' '));
  }

  // ── 翻译 ──

  void _toggleParagraphTranslation() {
    setState(() => _showTranslation = !_showTranslation);
    // 如果需要翻译且尚未加载，触发加载
    if (_showTranslation && _translation == null && !_loadingTranslation) {
      _loadTranslation();
    }
  }

  String _getParagraphTranslation(int paragraphIndex) {
    final sentences = _sentencesForParagraph(paragraphIndex);
    final translations = sentences.map((s) => s.contentTranslate ?? '').where((t) => t.trim().isNotEmpty).toList();
    return translations.join('');
  }

  // ── 段落点击 ──

  void _onParagraphTap(int paragraphIndex) {
    if (_selectionText != null) { _hideSelectionToolbar(); return; }
    setState(() {
      if (_activeParagraphIndex == paragraphIndex) {
        _activeParagraphIndex = null;
      } else {
        _activeParagraphIndex = paragraphIndex;
        _selectionText = null; _toolbarOffset = null;
      }
    });
    // 更新阅读位置
    final firstSentence = _sentencesForParagraph(paragraphIndex).firstOrNull;
    if (firstSentence != null) _readSentenceIndex = firstSentence.sentenceIndex;
  }

  void _hideSelectionToolbar() {
    _selectionController.clearSelection();
    setState(() { _selectionText = null; _toolbarOffset = null; _showFontSizePopup = false; });
  }

  void _onToolbarAction(String action) {
    final text = _selectionText;
    if (text == null) return;
    final ctxSentences = _sentencesForParagraph(_activeParagraphIndex ?? 0);
    final contextSentence = ctxSentences.map((s) => s.content).join(' ');
    _hideSelectionToolbar();
    if (action == 'speak') {
      _speakText(text);
    } else if (action == 'define' || action == 'translate') {
      _openWordCard(text, contextSentence: contextSentence);
    } else if (action == 'mark') {
      _showMarkColorDialog(text);
    }
  }

  // ── 字体大小 ──

  void _onFontSizeChanged(double v) {
    setState(() => _fontSize = v);
    SharedPreferences.getInstance().then((p) => p.setDouble('article_reader_font_size', v));
  }

  Widget _buildFontSizePopup(ColorScheme cs) {
    return Positioned(
      right: 16.w, bottom: 130.h,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12.r),
        color: cs.surface,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A+ (大字号标记，顶部)
              Text('A', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
              // 竖直滑条
              SizedBox(
                height: 160.h,
                width: 40.w,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    ),
                    child: Slider(
                      value: _fontSize,
                      min: 10,
                      max: 36,
                      divisions: 26,
                      onChanged: _onFontSizeChanged,
                    ),
                  ),
                ),
              ),
              // A- (小字号标记，底部)
              Text('A', style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  // ── 目录/列表 ──

  void _showOutlineSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.3,
          expand: false,
          builder: (_, controller) {
            return Column(children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.2)))),
                child: Center(child: Container(width: 36.w, height: 4.h, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2.r)))),
              ),
              Padding(padding: EdgeInsets.all(AppSpacing.md.w), child: Text('目录', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: cs.onSurface))),
              Expanded(
                child: _chapters.isEmpty
                    ? ListView(children: [Padding(padding: EdgeInsets.all(AppSpacing.lg.w), child: Text('暂无章节', style: TextStyle(color: cs.onSurfaceVariant)))])
                    : ListView.builder(
                        controller: controller,
                        itemCount: _chapters.length,
                        itemBuilder: (_, index) {
                          final ch = _chapters[index];
                          final preview = ch.plainText.length > 60 ? '${ch.plainText.substring(0, 60)}...' : ch.plainText;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cs.primaryContainer, child: Text('${index + 1}', style: TextStyle(fontSize: 12.sp, color: cs.onPrimaryContainer)),
                            ),
                            title: Text(ch.title.isNotEmpty ? ch.title : '段落 ${index + 1}', style: TextStyle(fontSize: 14.sp)),
                            subtitle: Text(preview, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                            onTap: () {
                              Navigator.pop(ctx);
                              _scrollToChapter(index);
                            },
                          );
                        },
                      ),
              ),
            ]);
          },
        );
      },
    );
  }

  void _scrollToChapter(int chapterIndex) {
    if (chapterIndex >= _chapters.length) return;
    final ch = _chapters[chapterIndex];
    // 找到该章节的第一个句子所在的段落
    final sentence = _sentences.where((s) => s.sentenceIndex >= ch.startSentenceIndex && s.sentenceIndex <= ch.endSentenceIndex).firstOrNull;
    if (sentence != null) {
      _scrollToParagraph(sentence.paragraphIndex);
      setState(() { _activeParagraphIndex = sentence.paragraphIndex; });
    }
  }

  // ── 主界面 ──

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(backgroundColor: cs.surface, appBar: AppBar(backgroundColor: cs.surface, elevation: 0), body: const Center(child: CircularProgressIndicator()));
    }
    if (_article == null) {
      return Scaffold(backgroundColor: cs.surface, appBar: AppBar(backgroundColor: cs.surface, elevation: 0), body: Center(child: Text('文章不存在', style: TextStyle(color: cs.onSurfaceVariant))));
    }

    return GestureDetector(
      onTap: () {
        if (_selectionText != null) _hideSelectionToolbar();
        if (_showFontSizePopup) setState(() => _showFontSizePopup = false);
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface, elevation: 0,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
              IconButton(
                icon: Icon(Icons.menu_open, size: 22.sp, color: _showArticleList ? cs.primary : cs.onSurface),
                onPressed: () => setState(() {
                  _showArticleList = !_showArticleList;
                  _showFontSizePopup = false;
                }),
                tooltip: '文章列表',
              ),
            ],
          ),
          title: Text(_article!.title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(icon: const Icon(Icons.list), onPressed: _showOutlineSheet, tooltip: '目录'),
          ],
        ),
        body: Stack(
          children: [
            // 主内容
            Column(children: [
              Expanded(child: _buildContent(cs)),
              _buildBottomBar(cs),
            ]),

            // 划词工具栏
            if (_selectionText != null && _toolbarOffset != null)
              Positioned(left: _toolbarOffset!.dx, top: _toolbarOffset!.dy, child: _buildSelectionToolbar(cs)),

            // 字体大小弹窗
            if (_showFontSizePopup) _buildFontSizePopup(cs),

            // 文章列表侧边栏
            if (_showArticleList) ...[
              // 半透明遮罩
              GestureDetector(
                onTap: () => setState(() => _showArticleList = false),
                child: Container(color: Colors.black26),
              ),
              // 侧边栏面板
              Positioned(
                top: 0, left: 0, bottom: 0,
                child: Container(
                  width: 320.w,
                  color: cs.surface,
                  child: _buildArticleListSidebar(cs),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    final paraIndices = _getParagraphIndices();
    if (paraIndices.isEmpty) {
      return Center(child: Text('暂无内容', style: TextStyle(color: cs.onSurfaceVariant)));
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: _isSelecting ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paraIdx in paraIndices)
            _buildParagraphBlock(paraIdx, cs),
          SizedBox(height: 120.h), // 底部空间，避免被 FAB 遮挡
        ],
      ),
    );
  }

  Widget _buildParagraphBlock(int paragraphIndex, ColorScheme cs) {
    final sentences = _sentencesForParagraph(paragraphIndex);
    if (sentences.isEmpty) return const SizedBox.shrink();

    final fullText = sentences.map((s) => s.content).join(' ');
    final isActive = paragraphIndex == _activeParagraphIndex;
    final isSpeakingPara = _isSpeaking && _isReadingAll && _readingAllParagraphIndex == paragraphIndex;

    _paragraphKeys.putIfAbsent(paragraphIndex, () => GlobalKey());
    final key = _paragraphKeys[paragraphIndex]!;

    return KeyedSubtree(
      key: key,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isActive ? null : () => _onParagraphTap(paragraphIndex),
        child: Container(
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: isActive ? cs.primaryContainer.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
            border: isActive ? Border.all(color: cs.primary.withValues(alpha: 0.4), width: 1.5) : null,
          ),
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 8.h),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildParagraphText(fullText, paragraphIndex, cs, isSpeakingPara),

            if (isActive && _showTranslation)
              Builder(builder: (_) {
                final translation = _getParagraphTranslation(paragraphIndex);
                if (translation.isEmpty && !_loadingTranslation) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: _loadingTranslation
                      ? Padding(padding: EdgeInsets.all(4.h), child: SizedBox(width: 16.h, height: 16.h, child: CircularProgressIndicator(strokeWidth: 2)))
                      : Text(translation, style: TextStyle(fontSize: (_fontSize - 2).sp, color: cs.onSurface.withValues(alpha: 0.7), height: 1.6)),
                );
              }),

            if (isActive) ...[
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_isSpeaking)
                    _paraBtn(Icons.stop_circle_outlined, '停止', _stopSpeaking, cs)
                  else
                    _paraBtn(Icons.volume_up_outlined, '朗读', () => _speakParagraph(paragraphIndex), cs),
                  SizedBox(width: 16.w),
                  _paraBtn(
                    _showTranslation ? Icons.translate : Icons.translate_outlined,
                    _showTranslation ? '隐藏翻译' : '翻译',
                    _toggleParagraphTranslation, cs,
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

/// 段落文本渲染：激活时用 SelectableParagraphText 支持划词，非激活时用普通 Text
  Widget _buildParagraphText(String fullText, int paragraphIndex, ColorScheme cs, bool isSpeakingPara) {
    if (_activeParagraphIndex == paragraphIndex) {
      return SelectableParagraphText(
        controller: _selectionController,
        text: fullText,
        fontSize: _fontSize,
        textColor: cs.onSurface,
        colorScheme: cs,
        isSpeaking: isSpeakingPara || (_isSpeaking && !_isReadingAll),
        ttsCurrentWordIndex: isSpeakingPara || (_isSpeaking && !_isReadingAll) ? _ttsCurrentWordIndex : -1,
        markedWords: _markedWords,
        onTap: () => _onParagraphTap(paragraphIndex),
        onStartSelection: () => setState(() => _isSelecting = true),
        onSelectionDone: (selectedWords, position) {
          final selectedText = selectedWords.join(' ');
          _isSelecting = false;
          setState(() {
            _selectionText = selectedText;
            _toolbarOffset = Offset(
              position.dx.clamp(20.w, MediaQuery.of(context).size.width - 220.w),
              (position.dy - 60.h).clamp(40.h, MediaQuery.of(context).size.height - 100.h),
            );
          });
        },
      );
    }
    return Text(fullText, style: TextStyle(fontSize: _fontSize.sp, color: cs.onSurface, height: 1.8));
  }

  Widget _paraBtn(IconData icon, String label, VoidCallback onTap, ColorScheme cs) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16.sp, color: cs.onSurfaceVariant), SizedBox(width: 4.w),
          Text(label, style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }

  // ── 划词工具栏 ──

  Widget _buildSelectionToolbar(ColorScheme cs) {
    return Material(color: Colors.transparent, child: GestureDetector(
      onTap: () {},
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: cs.surface, borderRadius: BorderRadius.circular(12.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _tbBtn(Icons.volume_up_outlined, '朗读', () => _onToolbarAction('speak'), cs),
          SizedBox(width: 4.w),
          _tbBtn(Icons.menu_book_outlined, '释义', () => _onToolbarAction('define'), cs),
          SizedBox(width: 4.w),
          _tbBtn(Icons.color_lens_outlined, '标注', () => _onToolbarAction('mark'), cs),
          SizedBox(width: 4.w),
          _tbBtn(Icons.translate_outlined, '翻译', () => _onToolbarAction('translate'), cs),
        ]),
      ),
    ));
  }

  Widget _tbBtn(IconData icon, String label, VoidCallback onTap, ColorScheme cs) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8.r),
      child: Padding(padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18.sp, color: cs.primary),
          SizedBox(height: 2.h),
          Text(label, style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }

  // ── 底部栏 ──

  Widget _buildBottomBar(ColorScheme cs) {
    final totalSentences = _sentences.length;
    final progress = totalSentences > 0 ? (_readSentenceIndex + 1) / totalSentences : 0.0;
    final percent = (progress * 100).round().clamp(0, 100);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
      decoration: BoxDecoration(color: cs.surface, border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.15)))),
      child: SafeArea(
        child: Row(
          children: [
            // 全文朗读按钮
            IconButton(
              icon: Icon(
                _isReadingAll ? Icons.stop_circle_rounded : Icons.auto_stories_outlined,
                color: _isReadingAll ? cs.error : cs.onSurfaceVariant, size: 22.sp,
              ),
              onPressed: _isReadingAll ? _stopReadingAll : _startReadAll,
              tooltip: _isReadingAll ? '停止朗读' : '全文朗读',
            ),
            // 进度条
            Expanded(child: ClipRRect(
              borderRadius: BorderRadius.circular(2.r),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0), minHeight: 4.h,
                backgroundColor: cs.outline.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            )),
            SizedBox(width: 8.w),
            Text('$percent%', style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
            SizedBox(width: 4.w),
            // 字体大小按钮
            IconButton(
              icon: Icon(Icons.text_fields, color: _showFontSizePopup ? cs.primary : cs.onSurfaceVariant, size: 20.sp),
              onPressed: () => setState(() {
                _showFontSizePopup = !_showFontSizePopup;
                _showArticleList = false;
              }),
              tooltip: '字体大小',
            ),
          ],
        ),
      ),
    );
  }

  // ── 文章列表侧边栏 ──

  Widget _buildArticleListSidebar(ColorScheme cs) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: [
              Text('文章列表', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const Spacer(),
              Text('共 ${_folderArticles.length} 篇', style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Expanded(
          child: _folderArticles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined, size: 48.sp, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      SizedBox(height: 8.h),
                      Text('暂无其他文章', style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: _folderArticles.length,
                  itemBuilder: (_, i) {
                    final a = _folderArticles[i];
                    final isCurrent = a.code == _article?.code;
                    final progressPercent = (a.progress * 100).round();
                    return ListTile(
                      selected: isCurrent,
                      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.3),
                      leading: CircleAvatar(
                        radius: 20.r,
                        backgroundColor: isCurrent ? cs.primary : cs.primaryContainer,
                        child: Text('${i + 1}', style: TextStyle(fontSize: 14.sp, color: isCurrent ? cs.onPrimary : cs.onPrimaryContainer)),
                      ),
                      title: Text(a.title, style: TextStyle(fontSize: 14.sp, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal, color: cs.onSurface),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2.r),
                              child: LinearProgressIndicator(
                                value: a.progress.clamp(0.0, 1.0), minHeight: 3.h,
                                backgroundColor: cs.outline.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(isCurrent ? cs.primary : cs.outline),
                              ),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text('$progressPercent%', style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
                        ],
                      ),
                      onTap: isCurrent ? null : () {
                        final code = a.code;
                        if (code != null && code != widget.articleCode) {
                          setState(() => _showArticleList = false);
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ArticleReaderPage(articleCode: code)));
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── 标记词颜色选择 ──

  void _showMarkColorDialog(String word) {
    final lower = word.toLowerCase();
    showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('标注「$word」'),
        content: Wrap(spacing: 12.w, runSpacing: 12.h,
          children: List.generate(_markerColors.length, (i) {
            final isCurrent = _markedWords[lower] == _markerColors[i];
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, i),
              child: Container(width: 40.w, height: 40.w,
                decoration: BoxDecoration(
                  color: _markerColors[i], shape: BoxShape.circle,
                  border: Border.all(color: isCurrent ? cs_primary(ctx) : Colors.black26, width: isCurrent ? 3 : 1),
                ),
                child: isCurrent ? Icon(Icons.check, color: Colors.black, size: 18) : null,
              ),
            );
          }),
        ),
        actions: [
          if (_markedWords.containsKey(lower))
            TextButton(onPressed: () {
              Navigator.pop(ctx);
              setState(() => _markedWords.remove(lower));
            }, child: Text('删除标记', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    ).then((colorIdx) {
      if (colorIdx != null && mounted) setState(() => _markedWords[lower] = _markerColors[colorIdx]);
    });
  }

  Color cs_primary(BuildContext ctx) => Theme.of(ctx).colorScheme.primary;
}
