import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/models/article_paragraph.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/models/article_translation.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/unified_translation_service.dart';
import 'package:vidlang/services/translation_init_service.dart';
import 'package:vidlang/services/translation_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/services/learning_stats_service.dart';
import 'package:vidlang/theme/app_icons.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/widgets/article/selectable_paragraph_text.dart';
import 'package:vidlang/widgets/shadow_reader/shadow_reader_component.dart';
import 'package:vidlang/widgets/word_card.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/widgets/app_dialogs.dart';

/// 标记记录类
class MarkRecord {
  final String id;
  final String text;
  final Color color;
  final DateTime createdAt;
  final int paragraphIndex;
  final int startIndex;
  final int endIndex;

  MarkRecord({
    required this.id,
    required this.text,
    required this.color,
    required this.createdAt,
    required this.paragraphIndex,
    required this.startIndex,
    required this.endIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'color': color.toARGB32(),
      'createdAt': createdAt.toIso8601String(),
      'paragraphIndex': paragraphIndex,
      'startIndex': startIndex,
      'endIndex': endIndex,
    };
  }

  factory MarkRecord.fromJson(Map<String, dynamic> json) {
    return MarkRecord(
      id: json['id'],
      text: json['text'],
      color: Color(json['color']),
      createdAt: DateTime.parse(json['createdAt']),
      paragraphIndex: json['paragraphIndex'] ?? -1,
      startIndex: json['startIndex'] ?? -1,
      endIndex: json['endIndex'] ?? -1,
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
  List<ArticleParagraph> _paragraphs = [];
  List<ArticleSentence> _sentences = [];
  bool _isLoading = true;
  double _fontSize = 16.0;
  int _totalWords = 0; // 文章总字数

  // 阅读计时器
  int _readingSeconds = 0; // 阅读秒数
  Timer? _readingTimer; // 阅读计时器

  // 段落激活
  int? _activeParagraphIndex;
  bool _isScrollingToTarget = false;

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
    Color(0xFFCE93D8),
  ];

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
  bool get _isPaidMode {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      return container.read(subscriptionProvider).mode ==
          SubscriptionMode.premium;
    } catch (_) {
      return false;
    }
  }

  // 单词释义加载状态
  bool _loadingWord = false;
  String? _loadingWordText;

  // 划词工具栏
  String? _selectionText;
  int? _selectionStartIndex;
  int? _selectionEndIndex;
  Offset? _toolbarOffset;
  final SelectableParagraphTextController _selectionController =
      SelectableParagraphTextController();

  // TTS
  bool _isSpeaking = false;
  bool _isSpeakingSelection = false;
  int _ttsCurrentWordIndex = -1;
  List<String> _ttsWords = [];
  ap.AudioPlayer? _audioPlayer;
  StreamSubscription? _audioPositionSub;
  StreamSubscription? _audioDurationSub;

  // 按段落/句子组织的单词索引
  int _currentSpeakingParagraphIndex = -1;
  int _ttsGeneration = 0; // TTS 生成计数器，用于防止过期回调覆盖新状态

  // 全文朗读
  bool _isReadingAll = false;
  int _readingAllParagraphIndex = 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer = ap.AudioPlayer();
    _initFontSize();
    _initTts();
    _loadMarkRecords().then((_) => _loadArticle());
    // 启动阅读计时器
    _startReadingTimer();
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
    _isSpeaking = false;
    _isSpeakingSelection = false;
    _ttsCurrentWordIndex = -1;
    _ttsWords = [];
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
    // 结束学习会话记录
    LearningStatsService.instance.endSession();
    TtsService().stop();
    _readingTimer?.cancel(); // 取消阅读计时器
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
    setState(
      () => _fontSize = prefs.getDouble('article_reader_font_size') ?? 16.0,
    );
  }

  Future<void> _initTts() async {
    // TTS 统一由 TtsService 管理，无需在此初始化 flutter_tts
    // 文章阅读器的单词高亮由 _startWordHighlightTimer 模拟
  }

  /// 启动阅读计时器
  void _startReadingTimer() {
    _readingSeconds = 0;
    _readingTimer?.cancel();
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _readingSeconds++);
      }
    });
  }

  /// 格式化阅读时间
  String _formatReadingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '$minutes分${secs.toString().padLeft(2, '0')}秒';
    }
    return '$secs秒';
  }

  Future<void> _loadArticle() async {
    final article = await BaseEntityExtension.findByCode<Article>(
      widget.articleCode,
      () => Article(),
    );
    if (article == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // ArticleChapter 已移除，不再查询章节
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
    if (sentences.length > 1 &&
        uniqueParaIndices.length == 1 &&
        paragraphs.isEmpty) {
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
      // _chapters 已移除
      if (_sentences.isEmpty) _sentences = sentences;
      if (_paragraphs.isEmpty) _paragraphs = paragraphs;
      _readSentenceIndex = article.lastSentenceIndex;
      _isLoading = false;
      // 计算总字数
      _totalWords = _sentences.fold(0, (sum, s) => sum + s.content.length);
    });

    // 开始学习会话记录
    LearningStatsService.instance.beginSession(
      resourceCode: widget.articleCode,
      resourceType: 'article',
      folderCode: article.folderCode,
    );

    // 根据 lastSentenceIndex 找到当前段落并滚动
    final currentSentence = _sentences
        .where((s) => s.sentenceIndex == _readSentenceIndex)
        .firstOrNull;
    if (currentSentence != null) {
      final currentParaIdx = currentSentence.paragraphIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _activeParagraphIndex = currentParaIdx;
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
      paraIndices = _sentences.map((s) => s.paragraphIndex).toSet().toList()
        ..sort();
    }
    debugPrint('═══ 文章段落调试 ═══');
    debugPrint('文章: ${article.title}');
    debugPrint('ArticleParagraph 记录数: ${_paragraphs.length}');
    debugPrint(
      '从句子推导的段落数: ${_sentences.map((s) => s.paragraphIndex).toSet().length}',
    );
    debugPrint('段落索引列表: $paraIndices');
    debugPrint('总句子数: ${_sentences.length}');
    for (final pIdx in paraIndices) {
      final sents = _sentences.where((s) => s.paragraphIndex == pIdx).toList();
      final preview = sents.map((s) => s.content).join(' ');
      final short = preview.length > 80
          ? '${preview.substring(0, 80)}...'
          : preview;
      debugPrint('  段落[$pIdx]: ${sents.length}句 → $short');
    }
    debugPrint('═══════════════════');

    _loadTranslation();

    // 检查并初始化翻译
    if (_sentences.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndInitializeTranslation();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(_onScroll);
    });
  }

  /// 修复旧数据：从文章原文重新解析段落边界，更新句子和段落记录
  Future<(List<ArticleSentence>, List<ArticleParagraph>)?>
  _fixArticleParagraphs(
    Article article,
    List<ArticleSentence> sentences,
  ) async {
    if (article.contentMarkdown.isEmpty) return null;

    // 统一换行符
    final normalized = article.contentMarkdown
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
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
      final paraSentences = sentences
          .where((s) => s.paragraphIndex == i)
          .toList();
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
    if (!_scrollController.hasClients ||
        _sentences.isEmpty ||
        _isSelecting ||
        _isScrollingToTarget) {
      return;
    }
    final viewportHeight = _scrollController.position.viewportDimension;
    final viewportCenter = _scrollController.offset + viewportHeight * 0.3;

    int? bestParaIdx;
    double bestDistance = double.infinity;

    for (final entry in _paragraphKeys.entries) {
      final key = entry.value;
      if (key.currentContext == null) continue;
      final box = key.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final offset = box.localToGlobal(
        Offset.zero,
        ancestor: context.findRenderObject(),
      );
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
      if (firstSentence != null &&
          firstSentence.sentenceIndex != _readSentenceIndex) {
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
        articleCode: widget.articleCode,
        article: _article!,
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

  /// 检查并初始化文章翻译
  Future<void> _checkAndInitializeTranslation() async {
    if (_article == null || _sentences.isEmpty) return;

    final mode = _isPaidMode ? SubscriptionMode.premium : SubscriptionMode.free;

    final needCount = TranslationInitService.countNeedTranslate(
      _sentences,
      mode,
    );
    if (needCount == 0) return;

    // 显示加载提示
    if (!mounted) return;
    TDToast.showText(
      '正在进行翻译初始化...',
      context: context,
      duration: const Duration(seconds: 2),
    );

    // 执行翻译
    try {
      await TranslationInitService.translateArticleSentences(
        sentences: _sentences,
        articleCode: widget.articleCode,
        title: _article!.title,
        mode: mode,
        onProgress: (current, total) {},
      );

      if (mounted) {
        setState(() {}); // 刷新 UI 显示翻译
      }
    } catch (e) {
      debugPrint('Article translation init failed: $e');
      if (mounted) {
        TDToast.showText(
          '翻译失败: $e',
          context: context,
          duration: const Duration(seconds: 3),
        );
      }
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
          ({
            required String word,
            String? contextSentence,
            required String sourceType,
            required String sourceCode,
            String? sourceTitle,
          }) async {
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
  // 使用统一的 TtsService（内部走 UnifiedTtsService，支持持久化缓存）

  /// 统一日志输出（release 模式也可见）
  void _articleTtsLog(String msg) {
    // ignore: avoid_print
    print(msg);
  }

  Future<void> _speakText(String text) async {
    _articleTtsLog('🎙️ [SpeakText] 开始播放文本 | 长度=${text.length}');
    _articleTtsLog(
      '🎙️ [SpeakText] 当前状态: _isSpeaking=$_isSpeaking, _isReadingAll=$_isReadingAll',
    );

    // 只停止引擎，保留朗读状态（如 _isReadingAll）
    _stopEngine();
    final int gen = ++_ttsGeneration;
    _articleTtsLog('🎙️ [SpeakText] 生成器: $gen');

    final mode = _isPaidMode ? SubscriptionMode.premium : SubscriptionMode.free;
    _articleTtsLog(
      '🎙️ [SpeakText] mode=$mode | text="${text.length > 50 ? '${text.substring(0, 50)}...' : text}"',
    );

    // 准备单词列表用于高亮（在播放前准备好）
    final wordRegex = RegExp(r'\b\w+\b');
    final wordMatches = wordRegex.allMatches(text).toList();
    _ttsWords = wordMatches.map((m) => m.group(0)!).toList();
    _articleTtsLog('🎙️ [SpeakText] 单词数量: ${_ttsWords.length}');

    setState(() {
      _isSpeaking = true;
      _isSpeakingSelection = false;
      _ttsCurrentWordIndex = _ttsWords.isNotEmpty ? 0 : -1;
      _articleTtsLog(
        '🎙️ [SpeakText] 设置 _isSpeaking=true, _ttsCurrentWordIndex=$_ttsCurrentWordIndex',
      );
    });

    try {
      _articleTtsLog('🎙️ [SpeakText] 开始调用 TtsService().speakClarity');
      await TtsService().speakClarity(
        text: text,
        mode: mode,
        onProgress: (fraction) {
          if (gen != _ttsGeneration || !mounted) return;
          _onTtsProgress(fraction);
        },
        onEvent: (event) {
          if (gen != _ttsGeneration) return; // 过期事件忽略
          _articleTtsLog(
            '🎙️ [SpeakText] TTS事件: ${event.type} | ${event.message ?? ""}',
          );
          if (event.type == TtsEventType.playing && mounted) {
            _articleTtsLog('🎙️ [SpeakText] 开始播放');
          }
        },
        onComplete: () {
          if (gen != _ttsGeneration) {
            _articleTtsLog(
              '🎙️ [SpeakText] 过期回调忽略 (gen=$gen != $_ttsGeneration)',
            );
            return;
          }
          _articleTtsLog('🎙️ [SpeakText] TTS引擎播放完成');
          TtsService().stop();
          setState(() {
            _isSpeaking = false;
            _ttsCurrentWordIndex = -1;
            _ttsWords = [];
            _currentSpeakingParagraphIndex = -1;
          });
          if (_isReadingAll) {
            _articleTtsLog('🎙️ [SpeakText] 继续朗读下一段');
            _readAllNext();
          }
        },
      );
      _articleTtsLog('🎙️ [SpeakText] speakClarity 返回');
    } catch (e) {
      _articleTtsLog('🎙️ [SpeakText] 异常: $e');
      _stopEngine();
      setState(() {
        _isSpeaking = false;
        _ttsCurrentWordIndex = -1;
        _ttsWords = [];
        _currentSpeakingParagraphIndex = -1;
      });
      if (mounted) {
        await TtsService().speakClarity(
          text: text,
          mode: mode,
          onComplete: () {
            if (gen != _ttsGeneration) return;
            _articleTtsLog('🎙️ [SpeakText] 重试播放完成');
            TtsService().stop();
            setState(() {
              _isSpeaking = false;
              _ttsCurrentWordIndex = -1;
              _ttsWords = [];
              _currentSpeakingParagraphIndex = -1;
            });
            if (_isReadingAll) _readAllNext();
          },
        );
      }
    }
  }

  /// 根据音频播放进度更新高亮单词索引
  void _onTtsProgress(double fraction) {
    if (_ttsWords.isEmpty) return;
    final index = (fraction * _ttsWords.length).floor().clamp(
      0,
      _ttsWords.length - 1,
    );
    if (index != _ttsCurrentWordIndex) {
      _ttsCurrentWordIndex = index;
      setState(() {});
    }
  }

  /// 只停止 TTS 引擎，保留朗读状态（_isReadingAll/_isSpeaking 等）
  void _stopEngine() {
    _articleTtsLog('🛑 [StopEngine] 停止引擎');
    TtsService().stop();
    _audioPositionSub?.cancel();
    _audioDurationSub?.cancel();
    _audioPlayer?.stop();
  }

  /// 返回按钮处理 - 确保停止所有播放后关闭页面
  void _onBackPressed() {
    _articleTtsLog('🔙 [BackPressed] 用户点击返回按钮');
    _stopSpeaking();
    _saveReadingPosition();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// 完全停止播放 - 停止引擎 + 重置所有朗读状态
  void _stopSpeaking() {
    _articleTtsLog('🛑 [StopSpeaking] 完全停止播放');
    _stopEngine();
    _isReadingAll = false;
    setState(() {
      _isSpeaking = false;
      _isSpeakingSelection = false;
      _ttsCurrentWordIndex = -1;
      _ttsWords = [];
      _currentSpeakingParagraphIndex = -1;
    });
    _articleTtsLog('✅ [StopSpeaking] 完全停止完成');
  }

  // ── 全文朗读 ──

  void _startReadAll() {
    _articleTtsLog('📚 [StartReadAll] 开始全文朗读');
    if (_sentences.isEmpty) return;
    final sortedParas = _getParagraphIndices();
    if (sortedParas.isEmpty) return;
    _isReadingAll = true;
    _readingAllParagraphIndex = sortedParas.first;
    setState(() {
      _activeParagraphIndex = sortedParas.first;
      _readSentenceIndex = _sentences.first.sentenceIndex;
      _ttsCurrentWordIndex = 0; // 从第一个单词开始
      _currentSpeakingParagraphIndex = sortedParas.first;
    });
    _articleTtsLog(
      '📚 [StartReadAll] 设置 _activeParagraphIndex=${sortedParas.first}, _currentSpeakingParagraphIndex=${sortedParas.first}',
    );
    // 滚动到第一段并居中显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToParagraph(sortedParas.first, alignment: 0.35);
    });
    _speakCurrentParagraph();
  }

  void _stopReadingAll() {
    _isReadingAll = false;
    _stopSpeaking();
  }

  void _readAllNext() {
    _articleTtsLog(
      '➡️ [ReadAllNext] 当前 _isReadingAll=$_isReadingAll, _readingAllParagraphIndex=$_readingAllParagraphIndex',
    );
    if (!_isReadingAll) return;
    final sortedParas = _getParagraphIndices();
    final currentIdx = sortedParas.indexOf(_readingAllParagraphIndex);
    if (currentIdx < 0 || currentIdx >= sortedParas.length - 1) {
      _articleTtsLog('➡️ [ReadAllNext] 到达最后一段，停止全文朗读');
      _isReadingAll = false;
      if (mounted) setState(() {});
      return;
    }
    _readingAllParagraphIndex = sortedParas[currentIdx + 1];
    _articleTtsLog('➡️ [ReadAllNext] 切换到段落 $_readingAllParagraphIndex');
    _isScrollingToTarget = true;
    setState(() {
      _activeParagraphIndex = _readingAllParagraphIndex;
      _currentSpeakingParagraphIndex = _readingAllParagraphIndex;
    });
    _scrollToParagraph(_readingAllParagraphIndex);
    Future.delayed(const Duration(milliseconds: 500), () {
      _isScrollingToTarget = false;
    });
    _speakCurrentParagraph();
  }

  void _speakCurrentParagraph() {
    _articleTtsLog(
      '🗣️ [SpeakCurrentParagraph] 朗读段落 $_readingAllParagraphIndex',
    );
    final sentences = _sentences
        .where((s) => s.paragraphIndex == _readingAllParagraphIndex)
        .toList();
    if (sentences.isEmpty) {
      _articleTtsLog(
        '🗣️ [SpeakCurrentParagraph] 段落 $_readingAllParagraphIndex 没有句子',
      );
      _readAllNext();
      return;
    }
    final text = sentences.map((s) => s.content).join(' ');
    _articleTtsLog(
      '🗣️ [SpeakCurrentParagraph] 文本长度: ${text.length}, 句子数: ${sentences.length}',
    );
    _speakText(text);
  }

  void _scrollToParagraph(int paragraphIndex, {double alignment = 0.3}) {
    final key = _paragraphKeys[paragraphIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: alignment,
      );
    }
  }

  List<int> _getParagraphIndices() {
    // 优先使用 ArticleParagraph 模型，否则从句子 paragraphIndex 推导
    if (_paragraphs.isNotEmpty) {
      return _paragraphs.map((p) => p.paragraphIndex).toList()..sort();
    }
    final indices = _sentences.map((s) => s.paragraphIndex).toSet().toList()
      ..sort();
    return indices;
  }

  List<ArticleSentence> _sentencesForParagraph(int paragraphIndex) {
    return _sentences.where((s) => s.paragraphIndex == paragraphIndex).toList();
  }

  // ── 段落朗读 ──

  void _speakParagraph(int paragraphIndex) {
    _articleTtsLog('📖 [SpeakParagraph] 开始朗读段落 $paragraphIndex');
    _articleTtsLog(
      '📖 [SpeakParagraph] 当前状态: _isReadingAll=$_isReadingAll, _isSpeaking=$_isSpeaking',
    );

    // 如果正在进行整体朗读，先停止
    if (_isReadingAll) {
      _articleTtsLog('📖 [SpeakParagraph] 停止整体朗读');
      _isReadingAll = false;
    }

    final sentences = _sentencesForParagraph(paragraphIndex);
    if (sentences.isEmpty) {
      _articleTtsLog('📖 [SpeakParagraph] 段落 $paragraphIndex 没有句子');
      return;
    }
    final firstSentence = sentences.first;
    _isScrollingToTarget = true;
    setState(() {
      _activeParagraphIndex = paragraphIndex;
      _readSentenceIndex = firstSentence.sentenceIndex;
      _currentSpeakingParagraphIndex = paragraphIndex;
    });
    _articleTtsLog(
      '📖 [SpeakParagraph] 设置 _activeParagraphIndex=$paragraphIndex, _currentSpeakingParagraphIndex=$paragraphIndex',
    );
    _scrollToParagraph(paragraphIndex);
    Future.delayed(const Duration(milliseconds: 500), () {
      _isScrollingToTarget = false;
    });
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
    final para = _paragraphs
        .where((p) => p.paragraphIndex == paragraphIndex)
        .firstOrNull;
    if (para != null && (para.translation ?? '').trim().isNotEmpty) {
      return para.translation!;
    }
    // 回退到句子译文拼接
    final sentences = _sentencesForParagraph(paragraphIndex);
    final translations = sentences
        .map((s) => s.contentTranslate ?? '')
        .where((t) => t.trim().isNotEmpty)
        .toList();
    if (translations.isEmpty) return _loadingTranslation ? '' : '';
    return translations.join('');
  }

  // ── 段落点击 ──

  void _onParagraphTap(int paragraphIndex) {
    if (_selectionText != null) {
      _hideSelectionToolbar();
      return;
    }
    _isScrollingToTarget = true;
    setState(() {
      if (_activeParagraphIndex == paragraphIndex) {
        _activeParagraphIndex = null;
      } else {
        _activeParagraphIndex = paragraphIndex;
        _selectionText = null;
        _toolbarOffset = null;
      }
    });
    // 滚动到屏幕中央
    _scrollToParagraph(paragraphIndex, alignment: 0.35);
    // 更新阅读位置
    final firstSentence = _sentencesForParagraph(paragraphIndex).firstOrNull;
    if (firstSentence != null) _readSentenceIndex = firstSentence.sentenceIndex;
    // 等待滚动动画结束后恢复滚动监听
    Future.delayed(const Duration(milliseconds: 500), () {
      _isScrollingToTarget = false;
    });
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
      _loadingWord = false;
      _loadingWordText = null;
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
    } else if (action == 'define') {
      _showWordTranslation(text);
      // 释义 toast 显示后延迟取消高亮
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _clearSelection();
      });
    } else if (action == 'translate') {
      _openWordCard(text, contextSentence: contextSentence);
      // 翻译弹窗关闭后取消高亮（弹窗关闭时 WordCard.dispose 会触发）
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _clearSelection();
      });
    } else if (action == 'mark') {
      _showMarkColorDialog(text);
      _clearSelection();
    } else if (action == 'shadow') {
      _startShadowReader(text, contextSentence);
    }
  }

  /// 检查字符串是否包含中文字符
  bool _containsChinese(String text) {
    return RegExp('[\u4e00-\u9fff]').hasMatch(text);
  }

  Future<void> _showWordTranslation(String text) async {
    if (!mounted) return;
    setState(() {
      _loadingWord = true;
      _loadingWordText = text;
    });
    try {
      final mode = _isPaidMode
          ? SubscriptionMode.premium
          : SubscriptionMode.free;
      final detail = await UnifiedTranslationService.instance.translate(
        text: text,
        mode: mode,
        sourceType: 'article',
        sourceCode: widget.articleCode,
      );
      if (!mounted) return;

      final translation =
          detail.translation ??
          detail.definitions.firstOrNull?.chineseMeaning ??
          '';
      String popoverText;
      if (translation.isNotEmpty && _containsChinese(translation)) {
        popoverText = translation;
      } else {
        popoverText = '未找到「$text」的中文释义';
      }

      if (!mounted) return;
      // 使用 Dialog 显示释义
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '释义',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, _, _) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  popoverText,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(ctx).colorScheme.onSurface,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
    } catch (e) {
      debugPrint('释义查询失败: $e');
      if (mounted) {
        TDToast.showText('释义查询失败', context: context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingWord = false;
          _loadingWordText = null;
        });
      }
    }
  }

  // ── 跟读 ──

  void _startShadowReader(String text, String contextSentence) {
    // 创建临时的 Subtitles 对象用于跟读组件（只跟读选中的单词或短语）
    final shadowSub = Subtitles(
      videoCode: widget.articleCode,
      content: text.trim(), // 仅跟读选中的文本
      contentTranslate: '',
      startPosition: 0,
      endPosition: 0,
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
            scope: 'sentence', // 可以保持 sentence 作用域，底层评测 API 会根据内容自动判断
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
    SharedPreferences.getInstance().then(
      (p) => p.setDouble('article_reader_font_size', v),
    );
  }

  Widget _buildFontSizePopup(ColorScheme cs) {
    return Positioned(
      right: Adaptive.w(context, 16),
      bottom: Adaptive.h(context, 180),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
        color: cs.surface,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A+ (大字号标记,顶部)
              Text(
                'A',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 22),
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
              // 竖直滑条
              SizedBox(
                height: Adaptive.h(context, 160),
                width: Adaptive.w(context, 40),
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
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
              // A- (小字号标记,底部)
              Text(
                'A',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 14),
                  color: cs.onSurfaceVariant,
                ),
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
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBackPressed();
        },
        child: Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(AppIcons.arrowBack, size: Adaptive.icon(context, 24)),
              onPressed: _onBackPressed,
            ),
            title: Text(
              _article!.title,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 18),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: Icon(
                  AppIcons.formatListBulleted,
                  size: Adaptive.icon(context, 22),
                  color: _showArticleList ? cs.primary : cs.onSurfaceVariant,
                ),
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
                Positioned(
                  left: _toolbarOffset!.dx,
                  top: _toolbarOffset!.dy,
                  child: _buildSelectionToolbar(cs),
                ),

              // 单词释义加载提示
              if (_loadingWord)
                Positioned(
                  left:
                      _toolbarOffset?.dx ??
                      MediaQuery.of(context).size.width / 2 - 60,
                  top:
                      (_toolbarOffset?.dy ??
                          MediaQuery.of(context).size.height / 2) -
                      50,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在查询「${_loadingWordText ?? ''}」...',
                          style: TextStyle(color: cs.onSurface, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

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

              // 段落导航按钮（右侧）
              if (_activeParagraphIndex != null)
                Positioned(
                  right: Adaptive.w(context, 8),
                  top: MediaQuery.of(context).size.height * 0.4,
                  child: _buildParagraphNavButtons(cs),
                ),

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
                  child: Container(
                    width: Adaptive.w(context, 320),
                    color: cs.surface,
                    child: _buildArticleListSidebar(cs),
                  ),
                ),
              ],
            ],
          ),
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
      padding: EdgeInsets.symmetric(
        horizontal: Adaptive.w(context, AppSpacing.md),
        vertical: Adaptive.h(context, AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paraIdx in paraIndices) _buildParagraphBlock(paraIdx, cs),
          SizedBox(height: Adaptive.h(context, 120)), // 底部空间，避免被 FAB 遮挡
        ],
      ),
    );
  }

  Widget _buildParagraphBlock(int paragraphIndex, ColorScheme cs) {
    final sentences = _sentencesForParagraph(paragraphIndex);
    if (sentences.isEmpty) return const SizedBox.shrink();

    final fullText = sentences.map((s) => s.content).join(' ');
    final isActive = paragraphIndex == _activeParagraphIndex;
    final isSpeakingPara =
        _isSpeaking && _currentSpeakingParagraphIndex == paragraphIndex;

    _paragraphKeys.putIfAbsent(paragraphIndex, () => GlobalKey());
    final key = _paragraphKeys[paragraphIndex]!;

    return KeyedSubtree(
      key: key,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isActive ? null : () => _onParagraphTap(paragraphIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: EdgeInsets.only(bottom: Adaptive.h(context, 24)),
          decoration: BoxDecoration(
            color: isActive
                ? cs.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(Adaptive.r(context, 16)),
            border: isActive
                ? Border.all(
                    color: cs.primary.withValues(alpha: 0.3),
                    width: 1.0,
                  )
                : Border.all(color: Colors.transparent, width: 1.0),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.fromLTRB(
            Adaptive.w(context, 16),
            Adaptive.h(context, 16),
            Adaptive.w(context, 16),
            Adaptive.h(context, 16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildParagraphText(fullText, paragraphIndex, cs, isSpeakingPara),

              if (_showTranslation)
                Builder(
                  builder: (_) {
                    final translation = _getParagraphTranslation(
                      paragraphIndex,
                    );
                    if (translation.isEmpty && !_loadingTranslation) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: EdgeInsets.only(top: Adaptive.h(context, 8)),
                      child: _loadingTranslation
                          ? Padding(
                              padding: EdgeInsets.all(Adaptive.h(context, 4)),
                              child: SizedBox(
                                width: Adaptive.h(context, 16),
                                height: Adaptive.h(context, 16),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Text(
                              translation,
                              style: TextStyle(
                                fontSize: Adaptive.sp(context, (_fontSize - 2)),
                                color: cs.onSurface.withValues(alpha: 0.7),
                                height: 1.6,
                              ),
                            ),
                    );
                  },
                ),

              if (isActive) ...[
                Padding(
                  padding: EdgeInsets.only(top: Adaptive.h(context, 8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSpeaking)
                        _paraBtn(AppIcons.stopCircle, '停止', _stopSpeaking, cs)
                      else
                        _paraBtn(
                          AppIcons.volumeUp,
                          '朗读',
                          () => _speakParagraph(paragraphIndex),
                          cs,
                        ),
                      SizedBox(width: Adaptive.w(context, 16)),
                      _paraBtn(
                        _showTranslation
                            ? AppIcons.translate
                            : AppIcons.translate,
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
  Widget _buildParagraphText(
    String fullText,
    int paragraphIndex,
    ColorScheme cs,
    bool isSpeakingPara,
  ) {
    if (_activeParagraphIndex == paragraphIndex) {
      final isTtsHighlight =
          !_isSpeakingSelection &&
          _currentSpeakingParagraphIndex == paragraphIndex &&
          _isSpeaking;
      final ttsWordIdx = isTtsHighlight ? _ttsCurrentWordIndex : -1;

      if (isTtsHighlight && _ttsCurrentWordIndex >= 0) {
        _articleTtsLog(
          '🔍 [Highlight] 段落 $paragraphIndex 高亮 | _ttsCurrentWordIndex=$_ttsCurrentWordIndex, 单词数=${_ttsWords.length}',
        );
      }

      final marksForPara = _markRecords
          .where((m) => m.paragraphIndex == paragraphIndex)
          .toList();

      return SelectableParagraphText(
        controller: _selectionController,
        text: fullText,
        fontSize: _fontSize,
        textColor: cs.onSurface,
        colorScheme: cs,
        isSpeaking: isTtsHighlight,
        ttsCurrentWordIndex: ttsWordIdx,
        marks: marksForPara,
        onTap: () => _onParagraphTap(paragraphIndex),
        onStartSelection: () => setState(() => _isSelecting = true),
        onSelectionDone: (selectedWords, position, startIdx, endIdx) {
          final selectedText = selectedWords.join(' ');
          _isSelecting = false;
          // 估算工具栏实际宽度（5个按钮 + padding）
          // 每个按钮约 50w，Row padding 12w，Container padding 6w×2，总计约 280w
          const toolbarWidth = 280.0;
          const toolbarHeight = 80.0;
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;

          _articleTtsLog(
            '🎙️ [Selection] 划词位置: dx=${position.dx}, dy=${position.dy} | 屏幕: ${screenWidth}x$screenHeight',
          );

          setState(() {
            _selectionText = selectedText;
            _selectionStartIndex = startIdx;
            _selectionEndIndex = endIdx;
            // 水平方向：确保工具栏不超出屏幕右边界
            final clampedDx = position.dx.clamp(
              Adaptive.w(context, 20),
              screenWidth - toolbarWidth,
            );
            // 垂直方向：工具栏在选中位置上方（dy - 60），确保不超出屏幕下边界
            final clampedDy = (position.dy - toolbarHeight).clamp(
              Adaptive.h(context, 40),
              screenHeight - toolbarHeight,
            );
            _toolbarOffset = Offset(clampedDx, clampedDy);
            _articleTtsLog('🎙️ [Selection] 调整后: dx=$clampedDx, dy=$clampedDy');
          });
        },
      );
    }
    return Text(
      fullText,
      style: TextStyle(
        fontSize: Adaptive.sp(context, _fontSize),
        color: cs.onSurface,
        height: 1.8,
      ),
    );
  }

  Widget _paraBtn(
    IconData icon,
    String label,
    VoidCallback onTap,
    ColorScheme cs,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Adaptive.r(context, 20)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Adaptive.w(context, 14),
          vertical: Adaptive.h(context, 8),
        ),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Adaptive.r(context, 20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Adaptive.sp(context, 16), color: cs.primary),
            SizedBox(width: Adaptive.w(context, 6)),
            Text(
              label,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 12),
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
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
          padding: EdgeInsets.symmetric(
            horizontal: Adaptive.w(context, 6),
            vertical: Adaptive.h(context, 6),
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(Adaptive.r(context, 16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tbBtn(
                AppIcons.volumeUp,
                '朗读',
                () => _onToolbarAction('speak'),
                cs,
              ),
              _tbBtn(
                AppIcons.lightbulbOutline,
                '释义',
                () => _onToolbarAction('define'),
                cs,
              ),
              _tbBtn(
                AppIcons.colorLens,
                '标注',
                () => _onToolbarAction('mark'),
                cs,
              ),
              _tbBtn(
                AppIcons.translate,
                '翻译',
                () => _onToolbarAction('translate'),
                cs,
              ),
              _tbBtn(
                AppIcons.micRounded,
                '跟读',
                () => _onToolbarAction('shadow'),
                cs,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tbBtn(
    IconData icon,
    String label,
    VoidCallback onTap,
    ColorScheme cs,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Adaptive.w(context, 12),
          vertical: Adaptive.h(context, 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Adaptive.sp(context, 20), color: cs.primary),
            SizedBox(height: Adaptive.h(context, 4)),
            Text(
              label,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 11),
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 底部栏 ──

  Widget _buildBottomBar(ColorScheme cs) {
    final totalSentences = _sentences.length;
    final progress = totalSentences > 0
        ? (_readSentenceIndex + 1) / totalSentences
        : 0.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Adaptive.w(context, 24),
        vertical: Adaptive.h(context, 12),
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(Adaptive.r(context, 4)),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: Adaptive.h(context, 4),
                backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            SizedBox(height: Adaptive.h(context, 12)),
            // 操作按钮和信息
            Row(
              children: [
                // 播放按钮
                IconButton(
                  icon: Icon(
                    _isReadingAll
                        ? AppIcons.stopCircle
                        : AppIcons.playCircleFill,
                    color: _isReadingAll ? cs.error : cs.primary,
                    size: Adaptive.sp(context, 36),
                  ),
                  onPressed: _isReadingAll ? _stopReadingAll : _startReadAll,
                  tooltip: _isReadingAll ? '停止朗读' : '全文朗读',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                SizedBox(width: Adaptive.w(context, 16)),
                // 文章字数和阅读时间
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_totalWords 字',
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 13),
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: Adaptive.h(context, 2)),
                      Text(
                        '阅读 ${_formatReadingTime(_readingSeconds)}',
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 11),
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                // 书签按钮 + 角标（Stack 叠加）
                SizedBox(
                  width: Adaptive.w(context, 36),
                  height: Adaptive.w(context, 36),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // 书签图标
                      IconButton(
                        icon: Icon(
                          AppIcons.bookmarkFill,
                          color: _showMarkManagerPopup
                              ? cs.primary
                              : cs.onSurfaceVariant,
                          size: Adaptive.sp(context, 24),
                        ),
                        onPressed: () => setState(() {
                          _showMarkManagerPopup = !_showMarkManagerPopup;
                          _showFontSizePopup = false;
                          _showArticleList = false;
                        }),
                        tooltip: '标记管理',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      // 角标：右上角偏移
                      Positioned(
                        top: -Adaptive.h(context, 2),
                        right: -Adaptive.w(context, 2),
                        child: _buildMarkBadge(cs),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    AppIcons.textFields,
                    color: _showFontSizePopup
                        ? cs.primary
                        : cs.onSurfaceVariant,
                    size: Adaptive.sp(context, 24),
                  ),
                  onPressed: () => setState(() {
                    _showFontSizePopup = !_showFontSizePopup;
                    _showArticleList = false;
                    _showMarkManagerPopup = false;
                  }),
                  tooltip: '字体大小',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 书签角标 ──

  /// 在书签图标右上角显示数量角标
  /// 无书签时返回 SizedBox.shrink（Stack 内不占位）
  Widget _buildMarkBadge(ColorScheme cs) {
    if (_markRecords.isEmpty) return const SizedBox.shrink();

    final count = _markRecords.length;
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: BoxConstraints(
        minWidth: Adaptive.w(context, 16),
        minHeight: Adaptive.w(context, 16),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: Adaptive.w(context, 4),
        vertical: Adaptive.w(context, 1),
      ),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(Adaptive.r(context, 8)),
        border: Border.all(color: cs.surface, width: 1.5),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: count > 9
                ? Adaptive.sp(context, 9)
                : Adaptive.sp(context, 10),
            color: cs.onPrimary,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  // ── 段落导航按钮 ──

  Widget _buildParagraphNavButtons(ColorScheme cs) {
    final paraIndices = _getParagraphIndices();
    if (paraIndices.isEmpty) return const SizedBox.shrink();

    final currentIndex = paraIndices.indexOf(_activeParagraphIndex!);
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex < paraIndices.length - 1;

    // 使用中性颜色，在浅色/深色模式下都清晰可见
    final buttonBgColor = cs.surfaceContainerHighest;
    final activeButtonBgColor = cs.surfaceContainerHigh;
    final iconColor = cs.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上一段
        GestureDetector(
          onTap: hasPrev
              ? () {
                  final prevIndex = paraIndices[currentIndex - 1];
                  _onParagraphTap(prevIndex);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: Adaptive.w(context, 36),
            height: Adaptive.w(context, 36),
            decoration: BoxDecoration(
              color: hasPrev ? activeButtonBgColor : buttonBgColor,
              borderRadius: BorderRadius.circular(Adaptive.r(context, 18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              AppIcons.keyboardArrowUp,
              color: hasPrev ? iconColor : iconColor.withValues(alpha: 0.3),
              size: Adaptive.sp(context, 24),
            ),
          ),
        ),
        SizedBox(height: Adaptive.h(context, 8)),
        // 当前段落指示
        Container(
          width: Adaptive.w(context, 40),
          padding: EdgeInsets.symmetric(vertical: Adaptive.h(context, 4)),
          decoration: BoxDecoration(
            color: activeButtonBgColor,
            borderRadius: BorderRadius.circular(Adaptive.r(context, 8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${currentIndex + 1}/${paraIndices.length}',
              style: TextStyle(
                fontSize: Adaptive.sp(context, 10),
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: Adaptive.h(context, 8)),
        // 下一段
        GestureDetector(
          onTap: hasNext
              ? () {
                  final nextIndex = paraIndices[currentIndex + 1];
                  _onParagraphTap(nextIndex);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: Adaptive.w(context, 36),
            height: Adaptive.w(context, 36),
            decoration: BoxDecoration(
              color: hasNext ? activeButtonBgColor : buttonBgColor,
              borderRadius: BorderRadius.circular(Adaptive.r(context, 18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              AppIcons.keyboardArrowDown,
              color: hasNext ? iconColor : iconColor.withValues(alpha: 0.3),
              size: Adaptive.sp(context, 24),
            ),
          ),
        ),
      ],
    );
  }

  // ── 侧边栏 ──

  Widget _buildArticleListSidebar(ColorScheme cs) {
    return Column(
      children: [
        // 标题
        Container(
          padding: EdgeInsets.all(Adaptive.w(context, 16)),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.article,
                color: cs.onSurface,
                size: Adaptive.sp(context, 20),
              ),
              SizedBox(width: Adaptive.w(context, 8)),
              Text(
                '文章列表',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 16),
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(width: Adaptive.w(context, 8)),
              Text(
                '(${_folderArticles.length}篇)',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 12),
                  color: cs.onSurfaceVariant,
                ),
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
                      Icon(
                        AppIcons.article,
                        size: Adaptive.sp(context, 48),
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      SizedBox(height: Adaptive.h(context, 12)),
                      Text(
                        '暂无文章',
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 14),
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(Adaptive.w(context, 12)),
                  itemCount: _folderArticles.length,
                  itemBuilder: (_, i) {
                    final a = _folderArticles[i];
                    final isCurrent = a.code == _article?.code;
                    final progressPercent = (a.progress * 100).round().clamp(
                      0,
                      100,
                    );
                    final estimatedMinutes = (a.wordCount / 200).ceil().clamp(
                      1,
                      999,
                    );
                    return Padding(
                      padding: EdgeInsets.only(bottom: Adaptive.h(context, 12)),
                      child: Material(
                        borderRadius: BorderRadius.circular(
                          Adaptive.r(context, 12),
                        ),
                        color: isCurrent
                            ? cs.primaryContainer.withValues(alpha: 0.2)
                            : cs.surfaceContainerHighest,
                        child: InkWell(
                          onTap: isCurrent
                              ? null
                              : () {
                                  final code = a.code;
                                  if (code != null &&
                                      code != widget.articleCode) {
                                    setState(() => _showArticleList = false);
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ArticleReaderPage(
                                          articleCode: code,
                                        ),
                                      ),
                                    );
                                  }
                                },
                          borderRadius: BorderRadius.circular(
                            Adaptive.r(context, 12),
                          ),
                          child: Container(
                            padding: EdgeInsets.all(Adaptive.w(context, 14)),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                Adaptive.r(context, 12),
                              ),
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
                                          fontSize: Adaptive.sp(context, 14),
                                          fontWeight: isCurrent
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: cs.onSurface,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: Adaptive.w(context, 8),
                                          vertical: Adaptive.h(context, 4),
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.primary,
                                          borderRadius: BorderRadius.circular(
                                            Adaptive.r(context, 6),
                                          ),
                                        ),
                                        child: Text(
                                          '当前',
                                          style: TextStyle(
                                            fontSize: Adaptive.sp(context, 12),
                                            color: cs.onPrimary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: Adaptive.h(context, 10)),
                                Wrap(
                                  spacing: Adaptive.w(context, 8),
                                  runSpacing: Adaptive.h(context, 6),
                                  children: [
                                    _statChip(
                                      AppIcons.layers,
                                      '${a.totalParagraphs}段',
                                      cs,
                                    ),
                                    _statChip(
                                      AppIcons.shortText,
                                      '${a.totalSentences}句',
                                      cs,
                                    ),
                                    _statChip(
                                      AppIcons.menuBook,
                                      '${a.wordCount}词',
                                      cs,
                                    ),
                                    _statChip(
                                      AppIcons.accessTime,
                                      '约$estimatedMinutes分钟',
                                      cs,
                                    ),
                                  ],
                                ),
                                SizedBox(height: Adaptive.h(context, 10)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          Adaptive.r(context, 4),
                                        ),
                                        child: LinearProgressIndicator(
                                          value: a.progress.clamp(0.0, 1.0),
                                          minHeight: Adaptive.h(context, 6),
                                          backgroundColor: cs.outline
                                              .withValues(alpha: 0.2),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                isCurrent
                                                    ? cs.primary
                                                    : cs.outline,
                                              ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: Adaptive.w(context, 10)),
                                    Text(
                                      '$progressPercent%',
                                      style: TextStyle(
                                        fontSize: Adaptive.sp(context, 12),
                                        fontWeight: FontWeight.w500,
                                        color: isCurrent
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
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
      padding: EdgeInsets.symmetric(
        horizontal: Adaptive.w(context, 8),
        vertical: Adaptive.h(context, 4),
      ),
      decoration: BoxDecoration(
        color: cs.onSurfaceVariant.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Adaptive.r(context, 6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: Adaptive.sp(context, 12),
            color: cs.onSurfaceVariant,
          ),
          SizedBox(width: Adaptive.w(context, 4)),
          Text(
            label,
            style: TextStyle(
              fontSize: Adaptive.sp(context, 12),
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── 标记词颜色选择 ──

  void _showMarkColorDialog(String selectedText) {
    if (_activeParagraphIndex == null ||
        _selectionStartIndex == null ||
        _selectionEndIndex == null) {
      return;
    }

    final trimmedText = selectedText.trim();
    final pIdx = _activeParagraphIndex!;
    final sIdx = _selectionStartIndex!;
    final eIdx = _selectionEndIndex!;

    showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          padding: EdgeInsets.fromLTRB(
            Adaptive.w(context, 24),
            Adaptive.h(context, 16),
            Adaptive.w(context, 24),
            MediaQuery.of(ctx).padding.bottom + Adaptive.h(context, 24),
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(Adaptive.r(context, 24)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: Adaptive.w(context, 40),
                  height: Adaptive.h(context, 4),
                  margin: EdgeInsets.only(bottom: Adaptive.h(context, 24)),
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(Adaptive.r(context, 2)),
                  ),
                ),
              ),
              Text(
                '标注',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 18),
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: Adaptive.h(context, 8)),
              Text(
                trimmedText,
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 15),
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: Adaptive.h(context, 24)),
              Text(
                '选择颜色',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 14),
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: Adaptive.h(context, 16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_markerColors.length, (i) {
                  final isCurrent = _markRecords.any(
                    (r) =>
                        r.paragraphIndex == pIdx &&
                        r.startIndex == sIdx &&
                        r.endIndex == eIdx &&
                        r.color == _markerColors[i],
                  );
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, i),
                    child: Container(
                      width: Adaptive.w(context, 44),
                      height: Adaptive.w(context, 44),
                      decoration: BoxDecoration(
                        color: _markerColors[i],
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _markerColors[i].withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: isCurrent
                            ? Border.all(color: cs.onSurface, width: 2.5)
                            : Border.all(color: Colors.white, width: 2),
                      ),
                      child: isCurrent
                          ? Icon(
                              AppIcons.check,
                              color: Colors.white,
                              size: Adaptive.sp(context, 22),
                            )
                          : null,
                    ),
                  );
                }),
              ),
              SizedBox(height: Adaptive.h(context, 32)),
              if (_markRecords.any(
                (r) =>
                    r.paragraphIndex == pIdx &&
                    r.startIndex == sIdx &&
                    r.endIndex == eIdx,
              ))
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _markRecords.removeWhere(
                          (r) =>
                              r.paragraphIndex == pIdx &&
                              r.startIndex == sIdx &&
                              r.endIndex == eIdx,
                        );
                      });
                      _saveMarkRecords();
                    },
                    icon: Icon(
                      AppIcons.delete,
                      color: cs.error,
                      size: Adaptive.sp(context, 20),
                    ),
                    label: Text(
                      '删除标注',
                      style: TextStyle(
                        color: cs.error,
                        fontSize: Adaptive.sp(context, 16),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: Adaptive.h(context, 14),
                      ),
                      backgroundColor: cs.error.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          Adaptive.r(context, 16),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ).then((colorIdx) {
      if (colorIdx != null && mounted) {
        setState(() {
          // 先移除已有的相同位置的标记
          _markRecords.removeWhere(
            (r) =>
                r.paragraphIndex == pIdx &&
                r.startIndex == sIdx &&
                r.endIndex == eIdx,
          );
          // 添加新标记
          _markRecords.add(
            MarkRecord(
              id: const Uuid().v4(),
              text: trimmedText,
              color: _markerColors[colorIdx],
              createdAt: DateTime.now(),
              paragraphIndex: pIdx,
              startIndex: sIdx,
              endIndex: eIdx,
            ),
          );
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
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(Adaptive.r(context, 20)),
                ),
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
                    margin: EdgeInsets.only(
                      top: Adaptive.h(context, 12),
                      bottom: Adaptive.h(context, 8),
                    ),
                    width: Adaptive.w(context, 32),
                    height: Adaptive.h(context, 4),
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        Adaptive.r(context, 2),
                      ),
                    ),
                  ),
                  // 标题栏
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Adaptive.w(context, 20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: Adaptive.w(context, 32),
                              height: Adaptive.w(context, 32),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  Adaptive.r(context, 8),
                                ),
                              ),
                              child: Icon(
                                AppIcons.bookmarkBorder,
                                size: Adaptive.sp(context, 18),
                                color: cs.primary,
                              ),
                            ),
                            SizedBox(width: Adaptive.w(context, 10)),
                            Text(
                              '标记管理',
                              style: TextStyle(
                                fontSize: Adaptive.sp(context, 17),
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
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
                              final confirmed = await AppConfirmDialog.show(
                                context,
                                title: '确认',
                                content: '确定要清空所有标记吗？',
                                confirmText: '确定',
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
                  Divider(
                    height: Adaptive.h(context, 1),
                    color: cs.outline.withValues(alpha: 0.1),
                  ),
                  // 内容区域
                  if (_markRecords.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: Adaptive.w(context, 64),
                              height: Adaptive.w(context, 64),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(
                                  alpha: 0.5,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                AppIcons.bookmarkBorder,
                                size: Adaptive.sp(context, 32),
                                color: cs.outline.withValues(alpha: 0.4),
                              ),
                            ),
                            SizedBox(height: Adaptive.h(context, 16)),
                            Text(
                              '暂无标记',
                              style: TextStyle(
                                fontSize: Adaptive.sp(context, 15),
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: Adaptive.h(context, 4)),
                            Text(
                              '划词并标注开始学习吧',
                              style: TextStyle(
                                fontSize: Adaptive.sp(context, 13),
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(
                          horizontal: Adaptive.w(context, 16),
                          vertical: Adaptive.h(context, 8),
                        ),
                        separatorBuilder: (_, _) => Divider(
                          height: Adaptive.h(context, 1),
                          color: cs.outline.withValues(alpha: 0.08),
                        ),
                        itemCount: _markRecords.length,
                        itemBuilder: (_, index) {
                          final record = _markRecords[index];
                          return TDCell(
                            titleWidget: Row(
                              children: [
                                Container(
                                  width: Adaptive.w(context, 10),
                                  height: Adaptive.w(context, 10),
                                  decoration: BoxDecoration(
                                    color: record.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cs.surface,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                SizedBox(width: Adaptive.w(context, 12)),
                                Expanded(
                                  child: Text(
                                    record.text,
                                    style: TextStyle(
                                      fontSize: Adaptive.sp(context, 14),
                                      color: cs.onSurface,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            rightIconWidget: IconButton(
                              icon: Icon(
                                AppIcons.close,
                                size: Adaptive.sp(context, 18),
                                color: cs.error,
                              ),
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
