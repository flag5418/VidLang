import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_chapter.dart';
import 'package:vidlang/models/article_paragraph.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/models/article_translation.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/translation_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/utils/dialog_utils.dart';
import 'package:vidlang/widgets/article/selectable_paragraph_text.dart';
import 'package:vidlang/widgets/shadow_reader/shadow_reader_component.dart';
import 'package:vidlang/widgets/word_card.dart';

/// 标记记录类
class MarkRecord {
  final String id;
  final String text;
  final Color color;
  final DateTime createdAt;

  MarkRecord({
    required this.id,
    required this.text,
    required this.color,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'color': color.value,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MarkRecord.fromJson(Map<String, dynamic> json) {
    return MarkRecord(
      id: json['id'],
      text: json['text'],
      color: Color(json['color']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

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
  int _activeParagraphPosition = -1;

  // 划词选择状态
  bool _isSelecting = false; // 划词进行中（禁用滚动）

  // 阅读位置（句子索引）
  int _readSentenceIndex = 0;

  // 同文件夹文章列表
  List<Article> _folderArticles = [];
  bool _showArticleList = false;

  // 字体大小弹窗
  bool _showFontSizePopup = false;
  
  // 标记管理弹窗
  bool _showMarkManagerPopup = false;

  // Scroll
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _paragraphKeys = {};

  // 标记记录列表
  final List<MarkRecord> _markRecords = [];
  static const List<Color> _markerColors = [
    Color(0xFFE57373),
    Color(0xFFFFB74D),
    Color(0xFFFFF176),
    Color(0xFF81C784),
    Color(0xFF64B5F6),
    Color(0xFFCE93D8)
  ];

  // 标记记录相关方法
  Map<String, Color> get _markedWords {
    final map = <String, Color>{};
    for (final record in _markRecords) {
      final words = record.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      for (final word in words) {
        map[word] = record.color;
      }
    }
    return map;
  }

  Future<void> _loadMarkRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'mark_records_${widget.articleCode}';
      final data = prefs.getString(key);
      if (data != null) {
        final List<dynamic> list = json.decode(data);
        setState(() {
          _markRecords.clear();
          _markRecords.addAll(list.map((e) => MarkRecord.fromJson(e)));
        });
      }
    } catch (e) {
      debugPrint('加载标记记录失败: $e');
    }
  }

  Future<void> _saveMarkRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'mark_records_${widget.articleCode}';
      final data = json.encode(_markRecords.map((e) => e.toJson()).toList());
      await prefs.setString(key, data);
    } catch (e) {
      debugPrint('保存标记记录失败: $e');
    }
  }

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
  List<int> _ttsWordOffsets = [];
  Timer? _ttsTimer;
  bool _ttsProgressHandlerFired = false;
  ap.AudioPlayer? _audioPlayer;
  StreamSubscription? _audioPositionSub;
  StreamSubscription? _audioDurationSub;
  int? _audioTotalDurationMs;

  // 全文朗读
  bool _isReadingAll = false;
  int _readingAllParagraphIndex = 0;

  // 划词朗读
  bool _isSpeakingSelection = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = ap.AudioPlayer();
    _initFontSize();
    _initTts();
    _loadMarkRecords().then((_) => _loadArticle());
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
    _isSpeakingSelection = false;
    _ttsCurrentWordIndex = -1;
    _ttsWords = [];
    _ttsWordOffsets = [];
    _translation = null;
    _showTranslation = false;
    _loadingTranslation = false;
    _markRecords.clear();
    _paragraphKeys.clear();
    _isSelecting = false;
    _showArticleList = false;
    _showFontSizePopup = false;
    _showMarkManagerPopup = false;
    _scrollController.removeListener(_onScroll);
    _stopReadingAll();
    setState(() {
      _article = null;
      _chapters = [];
      _paragraphs = [];
      _sentences = [];
      _isLoading = true;
      _readSentenceIndex = 0;
      _activeParagraphIndex = null;
      _selectionText = null;
      _toolbarOffset = null;
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
        // 使用字符偏移量而不是 indexOf，避免重复词跳到第一个
        int idx = -1;
        for (int i = 0; i < _ttsWordOffsets.length; i++) {
          if (_ttsWordOffsets[i] <= start && (i == _ttsWordOffsets.length - 1 || _ttsWordOffsets[i + 1] > start)) {
            idx = i;
            break;
          }
        }
        if (idx < 0) idx = _ttsWordOffsets.length - 1;
        if (mounted) setState(() => _ttsCurrentWordIndex = idx);
      });
      _flutterTts!.setCompletionHandler(() {
        _ttsTimer?.cancel();
        _ttsTimer = null;
        if (mounted) {
          _finishSpeaking();
          if (_isReadingAll) _readAllNext();
        }
      });
      _ttsAvailable = true;
    } catch (_) {
      _ttsAvailable = false;
    }
  }

  Future<void> _loadArticle() async {
    final article = await BaseEntityExtension.findByCode<Article>(widget.articleCode, () => Article());
    if (article == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final chapters = await DatabaseService.findByCondition<ArticleChapter>(
      () => ArticleChapter(),
      where: 'article_code = ? AND is_deleted = 0',
      whereArgs: [widget.articleCode],
      orderBy: 'chapter_index ASC',
    );
    final sentences = await DatabaseService.findByCondition<ArticleSentence>(
      () => ArticleSentence(),
      where: 'article_code = ? AND is_deleted = 0',
      whereArgs: [widget.articleCode],
      orderBy: 'sentence_index ASC',
    );
    final paragraphs = await DatabaseService.findByCondition<ArticleParagraph>(
      () => ArticleParagraph(),
      where: 'article_code = ? AND is_deleted = 0',
      whereArgs: [widget.articleCode],
      orderBy: 'paragraph_index ASC',
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

    // 根据 lastSentenceIndex 找到当前段落并滚动
    final currentSentence = _sentences.where((s) => s.sentenceIndex == _readSentenceIndex).firstOrNull;
    if (currentSentence != null) {
      final currentParaIdx = currentSentence.paragraphIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _activeParagraphIndex = currentParaIdx;
          final paraIndices = _getParagraphIndices();
          _activeParagraphPosition = paraIndices.indexOf(currentParaIdx);
        });
        final paraIndices = _getParagraphIndices();
        final pos = paraIndices.indexOf(currentParaIdx);
        if (pos >= 0) {
          _scrollToParagraph(currentParaIdx);
        }
      });
    }

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
  Future<(List<ArticleSentence>, List<ArticleParagraph>)?> _fixArticleParagraphs(Article article, List<ArticleSentence> sentences) async {
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
      while (currentParaIdx < paragraphTexts.length && !paragraphTexts[currentParaIdx].contains(content)) {
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
        final paraIndices = _getParagraphIndices();
        _activeParagraphPosition = paraIndices.indexOf(bestParaIdx);
        setState(() {});
      }
    }
  }

  Future<void> _loadTranslation() async {
    if (_article == null) return;
    setState(() => _loadingTranslation = true);
    try {
      final t = await TranslationService.translateArticle(
        articleCode: widget.articleCode,
        article: _article!,
        chapters: _chapters,
        paragraphs: _paragraphs,
        sentences: _sentences,
      );
      if (mounted && t != null) {
        setState(() {
          _translation = t;
          _loadingTranslation = false;
        });
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
    try {
      await _article!.save();
    } catch (_) {}
  }

  void _openWordCard(String text, {String? contextSentence}) {
    WordCard.show(
      context,
      word: text,
      contextSentence: contextSentence,
      isPaidMode: _isPaidMode,
      sourceType: 'article',
      sourceCode: widget.articleCode,
      sourceTitle: _article?.title,
      onSaveWord:
          ({required String word, String? contextSentence, required String sourceType, required String sourceCode, String? sourceTitle}) async {
            final wb = await WordBookService.saveWord(
              word: word,
              contextSentence: contextSentence,
              sourceType: sourceType,
              sourceCode: sourceCode,
              sourceTitle: sourceTitle,
            );
            return wb != null;
          },
    );
  }

  // ── TTS ──

  Future<void> _speakText(String text) async {
    if (_isPaidMode) {
      await _speakWithAiTts(text);
    } else {
      await _speakWithNativeTts(text);
    }
  }

  Future<void> _speakWithAiTts(String text) async {
    setState(() {
      _isSpeaking = true;
      _isSpeakingSelection = false;
      _ttsCurrentWordIndex = -1;
    });

    try {
      final result = await AiService.getTtsAudio(text: text, sourceType: 'article', sourceCode: widget.articleCode);

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
      final wordRegex = RegExp(r'\b\w+\b');
      final wordMatches = wordRegex.allMatches(text).toList();
      _ttsWords = wordMatches.map((m) => m.group(0)!).toList();
      _ttsWordOffsets = wordMatches.map((m) => m.start).toList();
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

      // 监听播放位置，同步单词高亮（仅向前递增，避免进度跳跃）
      _audioPositionSub = _audioPlayer?.onPositionChanged.listen((position) {
        if (!mounted || _ttsWords.isEmpty || _audioTotalDurationMs == null || _audioTotalDurationMs == 0) return;
        final progress = position.inMilliseconds / _audioTotalDurationMs!;
        final wordIdx = (progress * _ttsWords.length).floor().clamp(0, _ttsWords.length - 1);
        if (wordIdx > _ttsCurrentWordIndex) {
          setState(() => _ttsCurrentWordIndex = wordIdx);
        }
      });

      await _audioPlayer?.play(ap.DeviceFileSource(file.path));

      _audioPlayer?.onPlayerComplete.first.then((_) {
        _audioPositionSub?.cancel();
        _audioDurationSub?.cancel();
        _finishSpeaking();
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
    _ttsWordOffsets = [];
    _ttsProgressHandlerFired = false;

    final wordRegex = RegExp(r'\b\w+\b');
    final wordMatches = wordRegex.allMatches(text).toList();
    _ttsWords = wordMatches.map((m) => m.group(0)!).toList();
    _ttsWordOffsets = wordMatches.map((m) => m.start).toList();

    if (_ttsWords.isEmpty) {
      try {
        await _flutterTts!.speak(text);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('朗读失败: $e')));
      }
      return;
    }

    _ttsCurrentWordIndex = 0;
    setState(() => _isSpeaking = true);

    _ttsTimer = Timer(const Duration(seconds: 1), () {
      if (_ttsProgressHandlerFired || !mounted) return;
      _ttsTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_ttsCurrentWordIndex >= _ttsWords.length - 1) {
          timer.cancel();
          _ttsTimer = null;
          _finishSpeaking();
          return;
        }
        setState(() => _ttsCurrentWordIndex++);
      });
    });

    try {
      await _flutterTts!.speak(text);
    } catch (e) {
      _ttsTimer?.cancel();
      _ttsTimer = null;
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
    _finishSpeaking();
  }

  void _finishSpeaking() {
    final wasSelection = _isSpeakingSelection;
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isSpeakingSelection = false;
        _ttsCurrentWordIndex = -1;
        _ttsWords = [];
        _ttsWordOffsets = [];
      });
      if (wasSelection) _clearSelection();
    }
  }

  // ── 全文朗读 ──

  void _startReadAll() {
    if (_sentences.isEmpty) return;
    final sortedParas = _getParagraphIndices();
    if (sortedParas.isEmpty) return;
    final startPara = _activeParagraphIndex ?? sortedParas.first;
    _isReadingAll = true;
    _readingAllParagraphIndex = startPara;
    final startPos = sortedParas.indexOf(startPara);
    setState(() {
      _activeParagraphIndex = startPara;
      _activeParagraphPosition = startPos >= 0 ? startPos : 0;
    });
    _speakCurrentParagraph();
  }

  void _stopReadingAll() {
    _isReadingAll = false;
    _stopSpeaking();
  }

  void _readAllNext() {
    if (!_isReadingAll) return;
    final sortedParas = _getParagraphIndices();
    final currentIdx = sortedParas.indexOf(_readingAllParagraphIndex);
    if (currentIdx < 0 || currentIdx >= sortedParas.length - 1) {
      _isReadingAll = false;
      if (mounted) setState(() {});
      return;
    }
    _readingAllParagraphIndex = sortedParas[currentIdx + 1];
    setState(() {
      _activeParagraphIndex = _readingAllParagraphIndex;
      _activeParagraphPosition = currentIdx + 1;
    });
    _scrollToParagraph(_readingAllParagraphIndex);
    _speakCurrentParagraph();
  }

  void _speakCurrentParagraph() {
    final sentences = _sentences.where((s) => s.paragraphIndex == _readingAllParagraphIndex).toList();
    if (sentences.isEmpty) {
      _readAllNext();
      return;
    }
    _speakText(sentences.map((s) => s.content).join(' '));
  }

  void _scrollToParagraph(int paragraphIndex) {
    final key = _paragraphKeys[paragraphIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _scrollToParagraphByPosition(int position) {
    final paraIndices = _getParagraphIndices();
    if (position < 0 || position >= paraIndices.length) return;
    final paraIndex = paraIndices[position];
    _scrollToParagraph(paraIndex);
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
    setState(() {
      _activeParagraphIndex = paragraphIndex;
      final paraIndices = _getParagraphIndices();
      _activeParagraphPosition = paraIndices.indexOf(paragraphIndex);
    });
    _scrollToParagraph(paragraphIndex);
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
    // 优先使用段落译文
    final para = _paragraphs.where((p) => p.paragraphIndex == paragraphIndex).firstOrNull;
    if (para != null && (para.translation ?? '').trim().isNotEmpty) {
      return para.translation!;
    }
    // 回退到句子译文拼接
    final sentences = _sentencesForParagraph(paragraphIndex);
    final translations = sentences.map((s) => s.contentTranslate ?? '').where((t) => t.trim().isNotEmpty).toList();
    if (translations.isEmpty) return _loadingTranslation ? '' : '';
    return translations.join('');
  }

  // ── 段落点击 ──

  void _onParagraphTap(int paragraphIndex) {
    if (_selectionText != null) {
      _hideSelectionToolbar();
      return;
    }
    setState(() {
      if (_activeParagraphIndex == paragraphIndex) {
        _activeParagraphIndex = null;
        _activeParagraphPosition = -1;
      } else {
        _activeParagraphIndex = paragraphIndex;
        _selectionText = null;
        _toolbarOffset = null;
        final paraIndices = _getParagraphIndices();
        _activeParagraphPosition = paraIndices.indexOf(paragraphIndex);
      }
    });
    // 更新阅读位置
    final firstSentence = _sentencesForParagraph(paragraphIndex).firstOrNull;
    if (firstSentence != null) _readSentenceIndex = firstSentence.sentenceIndex;
  }

  void _hideSelectionToolbar() {
    _selectionController.clearSelection();
    setState(() {
      _selectionText = null;
      _toolbarOffset = null;
      _showFontSizePopup = false;
    });
  }

  void _hideToolbarOnly() {
    setState(() {
      _toolbarOffset = null;
      _showFontSizePopup = false;
    });
  }

  void _clearSelection() {
    _selectionController.clearSelection();
    setState(() {
      _selectionText = null;
      _toolbarOffset = null;
    });
  }

  void _onToolbarAction(String action) {
    final text = _selectionText;
    if (text == null) return;
    final ctxSentences = _sentencesForParagraph(_activeParagraphIndex ?? 0);
    final contextSentence = ctxSentences.map((s) => s.content).join(' ');
    _hideToolbarOnly();
    if (action == 'speak') {
      _isSpeakingSelection = true;
      _speakText(text);
    } else if (action == 'define' || action == 'translate') {
      _openWordCard(text, contextSentence: contextSentence);
      _clearSelection();
    } else if (action == 'mark') {
      _showMarkColorDialog(text);
      _clearSelection();
    } else if (action == 'shadow') {
      _startShadowReader(text, contextSentence);
    }
  }

  // ── 跟读 ──

  void _startShadowReader(String text, String contextSentence) {
    // 在上下文中查找匹配的句子
    final matchingSentence = _sentences.where((s) => contextSentence.contains(s.content) || s.content.contains(text)).toList();
    
    if (matchingSentence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未找到匹配的句子')),
      );
      return;
    }

    final subtitle = matchingSentence.first;
    
    // 创建临时的 Subtitles 对象用于跟读组件
    final shadowSub = Subtitles(
      videoCode: widget.articleCode,
      content: subtitle.content,
      contentTranslate: subtitle.contentTranslate,
      startPosition: subtitle.startPositionMs,
      endPosition: subtitle.endPositionMs,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ShadowReaderComponent.show(
          context,
          config: ShadowReaderConfig(
            subtitle: shadowSub,
            resourceType: 'article',
            resourceCode: widget.articleCode,
            resourceTitle: _article?.title ?? '',
            language: 'en',
            scope: 'sentence',
            speakSubtitle: (t) => _speakText(t),
            isMusic: false,
          ),
        );
      }
    });
  }

  // ── 字体大小 ──

  void _onFontSizeChanged(double v) {
    setState(() => _fontSize = v);
    SharedPreferences.getInstance().then((p) => p.setDouble('article_reader_font_size', v));
  }

  Widget _buildFontSizePopup(ColorScheme cs) {
    return Positioned(
      right: 16.w,
      bottom: 180.h,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12.r),
        color: cs.surface,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A+ (大字号标记,顶部)
              Text(
                'A',
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant),
              ),
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
                    child: Slider(value: _fontSize, min: 10, max: 36, divisions: 26, onChanged: _onFontSizeChanged),
                  ),
                ),
              ),
              // A- (小字号标记,底部)
              Text(
                'A',
                style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
         );
        }

  // ── 主界面 ──

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(backgroundColor: cs.surface, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_article == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(backgroundColor: cs.surface, elevation: 0),
        body: Center(
          child: Text('文章不存在', style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_showFontSizePopup) {
          setState(() => _showFontSizePopup = false);
        } else if (_showMarkManagerPopup) {
          setState(() => _showMarkManagerPopup = false);
        } else if (_selectionText != null && _toolbarOffset != null) {
          _hideToolbarOnly();
        } else if (_selectionText != null) {
          _clearSelection();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.surface,
          elevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          title: Text(
            _article!.title,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.format_list_bulleted_rounded, color: _showArticleList ? cs.primary : cs.onSurfaceVariant),
              onPressed: () => setState(() {
                _showArticleList = !_showArticleList;
                _showFontSizePopup = false;
              }),
              tooltip: '文章列表',
            ),
            // IconButton(icon: const Icon(Icons.list), onPressed: _showOutlineSheet, tooltip: '目录'),
          ],
        ),
        body: Stack(
          children: [
            // 主内容
            Column(
              children: [
                Expanded(child: _buildContent(cs)),
                _buildBottomBar(cs),
              ],
            ),

            // 划词工具栏
            if (_selectionText != null && _toolbarOffset != null)
              Positioned(left: _toolbarOffset!.dx, top: _toolbarOffset!.dy, child: _buildSelectionToolbar(cs)),

             // 字体大小弹窗
           if (_showFontSizePopup) ...[
             GestureDetector(
               onTap: () => setState(() => _showFontSizePopup = false),
               child: Container(color: Colors.transparent),
             ),
             _buildFontSizePopup(cs),
           ],
           
           // 标记管理弹窗
           if (_showMarkManagerPopup) ...[
             GestureDetector(
               onTap: () => setState(() => _showMarkManagerPopup = false),
               child: Container(color: Colors.transparent),
             ),
             _buildMarkManagerPopup(cs),
           ],

              // 文章列表侧边栏
            if (_showArticleList) ...[
              // 半透明遮罩
              GestureDetector(
                onTap: () => setState(() => _showArticleList = false),
                child: Container(color: Colors.black26),
              ),
              // 侧边栏面板
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: Container(width: 320.w, color: cs.surface, child: _buildArticleListSidebar(cs)),
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
      return Center(
        child: Text('暂无内容', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      physics: _isSelecting ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paraIdx in paraIndices) _buildParagraphBlock(paraIdx, cs),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildParagraphText(fullText, paragraphIndex, cs, isSpeakingPara),

              if (_showTranslation)
                Builder(
                  builder: (_) {
                    final translation = _getParagraphTranslation(paragraphIndex);
                    if (translation.isEmpty && !_loadingTranslation) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: _loadingTranslation
                          ? Padding(
                              padding: EdgeInsets.all(4.h),
                              child: SizedBox(width: 16.h, height: 16.h, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : Text(
                              translation,
                              style: TextStyle(fontSize: (_fontSize - 2).sp, color: cs.onSurface.withValues(alpha: 0.7), height: 1.6),
                            ),
                    );
                  },
                ),

              if (isActive) ...[
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSpeaking)
                        _paraBtn(Icons.stop_circle_outlined, '停止', _stopSpeaking, cs)
                      else
                        _paraBtn(Icons.volume_up_outlined, '朗读', () => _speakParagraph(paragraphIndex), cs),
                      SizedBox(width: 16.w),
                      _paraBtn(
                        _showTranslation ? Icons.translate : Icons.translate_outlined,
                        _showTranslation ? '隐藏翻译' : '翻译',
                        _toggleParagraphTranslation,
                        cs,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 段落文本渲染：激活时用 SelectableParagraphText 支持划词，非激活时用普通 Text
  Widget _buildParagraphText(String fullText, int paragraphIndex, ColorScheme cs, bool isSpeakingPara) {
    if (_activeParagraphIndex == paragraphIndex) {
      final isTtsHighlight = !_isSpeakingSelection && (isSpeakingPara || (_isSpeaking && !_isReadingAll));
      final ttsWordIdx = isTtsHighlight ? _ttsCurrentWordIndex : -1;
      return SelectableParagraphText(
        controller: _selectionController,
        text: fullText,
        fontSize: _fontSize,
        textColor: cs.onSurface,
        colorScheme: cs,
        isSpeaking: isTtsHighlight,
        ttsCurrentWordIndex: ttsWordIdx,
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
    return Text(
      fullText,
      style: TextStyle(fontSize: _fontSize.sp, color: cs.onSurface, height: 1.8),
    );
  }

  Widget _paraBtn(IconData icon, String label, VoidCallback onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: cs.onSurfaceVariant),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ── 划词工具栏 ──

  Widget _buildSelectionToolbar(ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tbBtn(Icons.volume_up_outlined, '朗读', () => _onToolbarAction('speak'), cs),
              SizedBox(width: 4.w),
              _tbBtn(Icons.menu_book_outlined, '释义', () => _onToolbarAction('define'), cs),
              SizedBox(width: 4.w),
              _tbBtn(Icons.color_lens_outlined, '标注', () => _onToolbarAction('mark'), cs),
              SizedBox(width: 4.w),
              _tbBtn(Icons.translate_outlined, '翻译', () => _onToolbarAction('translate'), cs),
              SizedBox(width: 4.w),
              _tbBtn(Icons.mic_rounded, '跟读', () => _onToolbarAction('shadow'), cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tbBtn(IconData icon, String label, VoidCallback onTap, ColorScheme cs) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18.sp, color: cs.primary),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ── 底部栏 ──

  Widget _buildBottomBar(ColorScheme cs) {
    final totalSentences = _sentences.length;
    final progress = totalSentences > 0 ? (_readSentenceIndex + 1) / totalSentences : 0.0;
    final percent = (progress * 100).round().clamp(0, 100);
    final paraIndices = _getParagraphIndices();
    final totalParas = paraIndices.length;
    const pageSize = 7;
    final totalPages = (totalParas / pageSize).ceil().clamp(1, 999);
    final currentPage = (_activeParagraphPosition ~/ pageSize).clamp(0, totalPages - 1);
    final pageStart = currentPage * pageSize;
    final pageEnd = (pageStart + pageSize).clamp(0, totalParas);
    final pageParas = paraIndices.sublist(pageStart, pageEnd);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 段落导航
            if (totalParas > 0) ...[
              SizedBox(
                height: 36.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  itemCount: pageParas.length,
                  itemBuilder: (_, i) {
                    final paraIdx = pageParas[i];
                    final pos = pageStart + i;
                    final isActive = pos == _activeParagraphPosition;
                    final isRead = pos < _activeParagraphPosition;
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.w),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _activeParagraphPosition = pos);
                          _scrollToParagraph(paraIdx);
                        },
                        child: Container(
                          width: 26.w,
                          height: 26.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? cs.primary : isRead ? cs.primary.withValues(alpha: 0.15) : Colors.transparent,
                            border: Border.all(
                              color: isActive ? cs.primary : isRead ? cs.primary.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${paraIdx + 1}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: isActive ? cs.onPrimary : isRead ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.5),
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (totalParas > pageSize) ...[
                SizedBox(height: 6.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, size: 18.sp, color: cs.onSurfaceVariant),
                      onPressed: currentPage > 0
                          ? () {
                              final newPos = (_activeParagraphPosition ~/ pageSize - 1) * pageSize;
                              setState(() => _activeParagraphPosition = newPos);
                              _scrollToParagraphByPosition(newPos);
                            }
                          : null,
                    ),
                    Text(
                      '${currentPage + 1}/$totalPages',
                      style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, size: 18.sp, color: cs.onSurfaceVariant),
                      onPressed: currentPage < totalPages - 1
                          ? () {
                              final newPos = (_activeParagraphPosition ~/ pageSize + 1) * pageSize;
                              setState(() => _activeParagraphPosition = newPos);
                              _scrollToParagraphByPosition(newPos);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
              SizedBox(height: 8.h),
            ],
            // 进度条 + 操作按钮
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isReadingAll ? Icons.stop_circle_rounded : Icons.auto_stories_outlined,
                    color: _isReadingAll ? cs.error : cs.onSurfaceVariant,
                    size: 20.sp,
                  ),
                  onPressed: _isReadingAll ? _stopReadingAll : _startReadAll,
                  tooltip: _isReadingAll ? '停止朗读' : '全文朗读',
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2.r),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 3.h,
                          backgroundColor: cs.outline.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '第 ${_activeParagraphPosition + 1} 段 / 共 $totalParas 段',
                            style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(fontSize: 13.sp, color: cs.primary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.bookmark_border, color: _showMarkManagerPopup ? cs.primary : cs.onSurfaceVariant, size: 20.sp),
                  onPressed: () => setState(() {
                    _showMarkManagerPopup = !_showMarkManagerPopup;
                    _showFontSizePopup = false;
                    _showArticleList = false;
                  }),
                  tooltip: '标记管理',
                ),
                if (_markRecords.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(right: 4.w),
                    child: Text(
                      '(${_markRecords.length})',
                      style: TextStyle(fontSize: 12.sp, color: cs.primary),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.text_fields, color: _showFontSizePopup ? cs.primary : cs.onSurfaceVariant, size: 20.sp),
                  onPressed: () => setState(() {
                    _showFontSizePopup = !_showFontSizePopup;
                    _showArticleList = false;
                    _showMarkManagerPopup = false;
                  }),
                  tooltip: '字体大小',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 侧边栏 ──

  Widget _buildArticleListSidebar(ColorScheme cs) {
    return Column(
      children: [
        // 标题
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: [
              Icon(Icons.article_outlined, color: cs.onSurface, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                '文章列表',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              SizedBox(width: 8.w),
              Text(
                '(${_folderArticles.length}篇)',
                style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        // 文章卡片列表
        Expanded(
          child: _folderArticles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_outlined, size: 48.sp, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      SizedBox(height: 12.h),
                      Text('暂无文章', style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(12.w),
                  itemCount: _folderArticles.length,
                  itemBuilder: (_, i) {
                    final a = _folderArticles[i];
                    final isCurrent = a.code == _article?.code;
                    final progressPercent = (a.progress * 100).round().clamp(0, 100);
                    final estimatedMinutes = (a.wordCount / 200).ceil().clamp(1, 999);
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Material(
                        borderRadius: BorderRadius.circular(12.r),
                        color: isCurrent ? cs.primaryContainer.withValues(alpha: 0.2) : cs.surfaceContainerHighest,
                        child: InkWell(
                          onTap: isCurrent
                              ? null
                              : () {
                                  final code = a.code;
                                  if (code != null && code != widget.articleCode) {
                                    setState(() => _showArticleList = false);
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => ArticleReaderPage(articleCode: code)),
                                    );
                                  }
                                },
                          borderRadius: BorderRadius.circular(12.r),
                          child: Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.r),
                              border: isCurrent
                                  ? Border.all(color: cs.primary, width: 2)
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.title,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                                          color: cs.onSurface,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: cs.primary,
                                          borderRadius: BorderRadius.circular(6.r),
                                        ),
                                        child: Text(
                                          '当前',
                                          style: TextStyle(fontSize: 12.sp, color: cs.onPrimary),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                Wrap(
                                  spacing: 8.w,
                                  runSpacing: 6.h,
                                  children: [
                                    _statChip(Icons.layers, '${a.totalParagraphs}段', cs),
                                    _statChip(Icons.short_text, '${a.totalSentences}句', cs),
                                    _statChip(Icons.menu_book, '${a.wordCount}词', cs),
                                    _statChip(Icons.access_time, '约${estimatedMinutes}分钟', cs),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4.r),
                                        child: LinearProgressIndicator(
                                          value: a.progress.clamp(0.0, 1.0),
                                          minHeight: 6.h,
                                          backgroundColor: cs.outline.withValues(alpha: 0.2),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            isCurrent ? cs.primary : cs.outline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Text(
                                      '$progressPercent%',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, ColorScheme cs) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: cs.onSurfaceVariant),
          SizedBox(width: 4.w),
          Text(label, style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ── 标记词颜色选择 ──

  void _showMarkColorDialog(String selectedText) {
    final trimmedText = selectedText.trim();
    DialogUtils.show<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('标注「$trimmedText」'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Text('选择标记颜色', style: TextStyle(fontSize: 12.sp, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ),
            Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: List.generate(_markerColors.length, (i) {
                final isCurrent = _markRecords.any((r) => r.text.toLowerCase() == trimmedText.toLowerCase() && r.color == _markerColors[i]);
                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, i),
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: _markerColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: isCurrent ? Theme.of(ctx).colorScheme.primary : Colors.black26, width: isCurrent ? 3 : 1),
                    ),
                    child: isCurrent ? Icon(Icons.check, color: Colors.black, size: 18) : null,
                  ),
                );
              }),
            ),
          ],
        ),
        actions: [
          if (_markRecords.any((r) => r.text.toLowerCase() == trimmedText.toLowerCase()))
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _markRecords.removeWhere((r) => r.text.toLowerCase() == trimmedText.toLowerCase());
                });
                _saveMarkRecords();
              },
              child: Text('删除标记', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    ).then((colorIdx) {
      if (colorIdx != null && mounted) {
        setState(() {
          // 先移除已有的相同文本标记
          _markRecords.removeWhere((r) => r.text.toLowerCase() == trimmedText.toLowerCase());
          // 添加新标记
          _markRecords.add(MarkRecord(
            id: const Uuid().v4(),
            text: trimmedText,
            color: _markerColors[colorIdx],
            createdAt: DateTime.now(),
          ));
        });
        _saveMarkRecords();
      }
    });
  }

  // ── 标记管理弹窗 (TDesign风格底部抽屉) ──
  Widget _buildMarkManagerPopup(ColorScheme cs) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () => setState(() => _showMarkManagerPopup = false),
        child: Material(
          color: Colors.black.withValues(alpha: 0.4),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部横条
                  Container(
                    margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                    width: 32.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  // 标题栏
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32.w,
                              height: 32.w,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Icon(Icons.bookmark_border, size: 18.sp, color: cs.primary),
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              '标记管理',
                              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
                            ),
                          ],
                        ),
                        if (_markRecords.isNotEmpty)
                          TDButton(
                            text: '清空',
                            type: TDButtonType.text,
                            theme: TDButtonTheme.danger,
                            size: TDButtonSize.small,
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('确认'),
                                  content: const Text('确定要清空所有标记吗？'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                setState(() => _markRecords.clear());
                                await _saveMarkRecords();
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1.h, color: cs.outline.withValues(alpha: 0.1)),
                  // 内容区域
                  if (_markRecords.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64.w,
                              height: 64.w,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.bookmark_border, size: 32.sp, color: cs.outline.withValues(alpha: 0.4)),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              '暂无标记',
                              style: TextStyle(fontSize: 15.sp, color: cs.onSurfaceVariant),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '划词并标注开始学习吧',
                              style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        separatorBuilder: (_, __) => Divider(height: 1.h, color: cs.outline.withValues(alpha: 0.08)),
                        itemCount: _markRecords.length,
                        itemBuilder: (_, index) {
                          final record = _markRecords[index];
                          return TDCell(
                            titleWidget: Row(
                              children: [
                                Container(
                                  width: 10.w,
                                  height: 10.w,
                                  decoration: BoxDecoration(
                                    color: record.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: cs.surface, width: 1.5),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Text(
                                    record.text,
                                    style: TextStyle(fontSize: 14.sp, color: cs.onSurface),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            rightIconWidget: IconButton(
                              icon: Icon(Icons.close, size: 18.sp, color: cs.error),
                              onPressed: () async {
                                setState(() => _markRecords.removeAt(index));
                                await _saveMarkRecords();
                              },
                            ),
                            onClick: (_) {},
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
