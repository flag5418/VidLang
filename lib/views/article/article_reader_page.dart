import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidlang/config.dart';
import 'package:vidlang/models/article.dart';
import 'package:vidlang/models/article_bookmark.dart';
import 'package:vidlang/models/article_chapter.dart';
import 'package:vidlang/models/article_paragraph.dart';
import 'package:vidlang/models/article_sentence.dart';
import 'package:vidlang/models/article_translation.dart';
import 'package:vidlang/models/base_entity.dart';
import 'package:vidlang/services/database_service.dart';
import 'package:vidlang/services/translation_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/app_spacing.dart';
import 'package:vidlang/utils/dialog_utils.dart';
import 'package:vidlang/widgets/word_card.dart';

/// 文章阅读器页面
///
/// 核心功能：
/// - 以章（Chapter）为组织单元，逐句渲染
/// - 当前句高亮 + 逐句 TTS 朗读 + 句子级书签
/// - 划词菜单（释义/朗读/收藏/标记/翻译入口）
/// - 单词标记：选中单词→选颜色→全文同词高亮→逐步掌握后手动清除
/// - 章目录抽屉 + 阅读统计面板
/// - 断点续读 + 阅读进度条
/// - 字体大小调节
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
  ArticleBookmark? _bookmark;
  bool _isLoading = true;
  double _fontSize = 16.0;
  int _currentChapterIndex = 0;
  bool _hasBookmark = false;

  // TTS
  FlutterTts? _flutterTts;
  bool _ttsAvailable = false;
  bool _isSpeaking = false;
  int _ttsCurrentWordIndex = -1;
  List<String> _ttsWords = [];
  int _ttsSentenceIndex = -1;
  Timer? _ttsTimer;
  bool _ttsProgressHandlerFired = false;

  // 侧边栏
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 阅读位置
  int _readSentenceIndex = 0;

  // Scroll tracking
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _sentenceKeys = {};

  // 单词标记：word_lowercase → Color
  final Map<String, Color> _markedWords = {};
  static const _markerColors = [
    Color(0xFFE57373), // 红
    Color(0xFFFFB74D), // 橙
    Color(0xFFFFF176), // 黄
    Color(0xFF81C784), // 绿
    Color(0xFF64B5F6), // 蓝
    Color(0xFFCE93D8), // 紫
  ];

  // 翻译
  ArticleTranslation? _translation;
  bool _showTranslation = false;
  bool _loadingTranslation = false;
  bool get _isPaidMode => AppConfig.currentUser?.authProvider == 'supabase';

  @override
  void initState() {
    super.initState();
    _initFontSize();
    _initTts();
    _loadArticle();
    _checkBookmark();
  }

  @override
  void didUpdateWidget(covariant ArticleReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleCode != widget.articleCode) {
      _resetForNewArticle();
      _loadArticle();
      _checkBookmark();
    }
  }

  void _resetForNewArticle() {
    _ttsTimer?.cancel();
    _isSpeaking = false;
    _ttsCurrentWordIndex = -1;
    _ttsSentenceIndex = -1;
    _ttsWords = [];
    _translation = null;
    _showTranslation = false;
    _loadingTranslation = false;
    _markedWords.clear();
    _sentenceKeys.clear();
    _scrollController.removeListener(_onScroll);
    setState(() {
      _article = null;
      _chapters = [];
      _paragraphs = [];
      _sentences = [];
      _bookmark = null;
      _isLoading = true;
      _currentChapterIndex = 0;
      _readSentenceIndex = 0;
      _hasBookmark = false;
    });
  }

  @override
  void dispose() {
    _saveReadingPosition();
    _flutterTts?.stop();
    _ttsTimer?.cancel();
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
        if (idx >= 0 && mounted) {
          setState(() => _ttsCurrentWordIndex = idx);
        }
      });

      _flutterTts!.setCompletionHandler(() {
        _ttsTimer?.cancel();
        _ttsTimer = null;
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _ttsCurrentWordIndex = -1;
            _ttsSentenceIndex = -1;
            _ttsWords = [];
          });
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

    setState(() {
      _article = article;
      _chapters = chapters;
      _paragraphs = paragraphs;
      _sentences = sentences;
      _currentChapterIndex = article.lastParagraphIndex;
      _readSentenceIndex = article.lastSentenceIndex;
      _isLoading = false;
    });

    // 异步加载翻译（不阻塞阅读）
    _loadTranslation();

    // Scroll-based read position tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.addListener(_onScroll);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _sentences.isEmpty) return;
    final viewportTop = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final viewportCenter = viewportTop + viewportHeight * 0.3;

    int bestIndex = _readSentenceIndex;
    double bestDistance = double.infinity;

    for (final sentence in _sentences) {
      final key = _sentenceKeys[sentence.sentenceIndex];
      if (key?.currentContext == null) continue;
      final box = key!.currentContext!.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final offset = box.localToGlobal(Offset.zero, ancestor: context.findRenderObject());
      final center = offset.dy + box.size.height / 2;
      final distance = (center - viewportCenter).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = sentence.sentenceIndex;
      }
    }

    if (bestIndex != _readSentenceIndex) {
      _readSentenceIndex = bestIndex;
      final chapter = _chapterForSentence(bestIndex);
      if (chapter != null && chapter.chapterIndex != _currentChapterIndex) {
        _currentChapterIndex = chapter.chapterIndex;
      }
    }
  }

  ArticleChapter? _chapterForSentence(int sentenceIndex) {
    for (final ch in _chapters) {
      if (sentenceIndex >= ch.startSentenceIndex && sentenceIndex <= ch.endSentenceIndex) {
        return ch;
      }
    }
    return null;
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

  Future<void> _checkBookmark() async {
    final bookmarks = await DatabaseService.findByCondition<ArticleBookmark>(
      () => ArticleBookmark(),
      where: 'article_code = ? AND is_deleted = 0',
      whereArgs: [widget.articleCode],
      orderBy: 'updated_at DESC',
      limit: 1,
    );

    if (bookmarks.isNotEmpty && mounted) {
      setState(() {
        _bookmark = bookmarks.first;
        _hasBookmark = true;
      });

      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('继续阅读'),
          content: Text('检测到上次阅读位置（第 ${_bookmark!.paragraphIndex + 1} 章），是否从上次位置继续？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('从头开始')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('继续阅读')),
          ],
        ),
      );

      if (result == true && _bookmark != null) {
        setState(() {
          _currentChapterIndex = _bookmark!.paragraphIndex;
          _readSentenceIndex = _bookmark!.sentenceIndex;
        });
      }
    }
  }

  Future<void> _saveReadingPosition() async {
    if (_article == null) return;

    // 更新 article 表
    _article!.lastParagraphIndex = _currentChapterIndex;
    _article!.lastSentenceIndex = _readSentenceIndex;
    _article!.lastStudyDate = DateTime.now();
    _article!.studyCount = (_article!.studyCount) + 1;

    if (_sentences.isNotEmpty) {
      _article!.progress = (_readSentenceIndex + 1) / _sentences.length;
    }

    try {
      await _article!.save();
    } catch (_) {}

    // 保存书签到 article_bookmark 表（upsert）
    try {
      if (_bookmark != null && !_bookmark!.isDeleted) {
        _bookmark!.paragraphIndex = _currentChapterIndex;
        _bookmark!.sentenceIndex = _readSentenceIndex;
        await _bookmark!.save();
      } else {
        final bookmark = ArticleBookmark(articleCode: widget.articleCode, paragraphIndex: _currentChapterIndex, sentenceIndex: _readSentenceIndex);
        await DatabaseService.insert(bookmark);
      }
    } catch (_) {}
  }

  Future<void> _addBookmark({String? note}) async {
    if (_bookmark != null && !_bookmark!.isDeleted) {
      _bookmark!.paragraphIndex = _currentChapterIndex;
      _bookmark!.sentenceIndex = _readSentenceIndex;
      _bookmark!.note = note ?? _bookmark!.note;
      await _bookmark!.save();
    } else {
      final bookmark = ArticleBookmark(
        articleCode: widget.articleCode,
        paragraphIndex: _currentChapterIndex,
        sentenceIndex: _readSentenceIndex,
        note: note,
      );
      await DatabaseService.insert(bookmark);
      _bookmark = bookmark;
    }
    setState(() => _hasBookmark = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('书签已保存')));
    }
  }

  Future<void> _removeBookmark() async {
    if (_bookmark != null) {
      await _bookmark!.softDelete();
      setState(() {
        _bookmark = null;
        _hasBookmark = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('书签已取消')));
      }
    }
  }

  void _jumpToChapter(int index) {
    setState(() => _currentChapterIndex = index);
    Navigator.of(context).pop(); // 关闭 endDrawer
  }

  void _jumpToBookmark() {
    if (_bookmark != null) {
      _jumpToChapter(_bookmark!.paragraphIndex);
    }
  }

  // ============================================================
  // 划词菜单 — 底部 Sheet 方式
  // ============================================================

  void _showSelectionSheet(String selectedText, {String? contextSentence, String? segmentCode}) {
    if (selectedText.trim().isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildSelectionToolbar(selectedText, contextSentence: contextSentence, segmentCode: segmentCode),
    );
  }

  Widget _buildSelectionToolbar(String text, {String? contextSentence, String? segmentCode}) {
    return Container(
      margin: EdgeInsets.all(AppSpacing.md.w),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(12.r)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 选中文本预览
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
              child: Text(
                text.length > 100 ? '${text.substring(0, 100)}...' : text,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.sp),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 操作按钮行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToolbarButton('释义', Icons.translate, () {
                  Navigator.pop(context);
                  _openWordCard(text, contextSentence: contextSentence, segmentCode: segmentCode);
                }),
                _buildToolbarButton('朗读', Icons.volume_up_outlined, () {
                  Navigator.pop(context);
                  _speakSelected(text);
                }),
                _buildToolbarButton('收藏', Icons.bookmark_add_outlined, () {
                  Navigator.pop(context);
                  _openWordCard(text, contextSentence: contextSentence, segmentCode: segmentCode);
                }),
                if (!text.contains(' '))
                  _buildToolbarButton('标记', Icons.format_paint, () {
                    Navigator.pop(context);
                    _showColorPicker(text);
                  }),
                _buildToolbarButton('翻译', Icons.g_translate, () {
                  Navigator.pop(context);
                  _openWordCard(text, contextSentence: contextSentence, segmentCode: segmentCode);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openWordCard(String text, {String? contextSentence, String? segmentCode}) {
    WordCard.show(
      context,
      word: text,
      contextSentence: contextSentence,
      isPaidMode: _isPaidMode,
      sourceType: 'article',
      sourceCode: widget.articleCode,
      sourceTitle: _article?.title,
      segmentCode: segmentCode,
      onSaveWord:
          ({required String word, String? contextSentence, required String sourceType, required String sourceCode, String? sourceTitle}) async {
            final wb = await WordBookService.saveWord(
              word: word,
              contextSentence: contextSentence,
              sourceType: sourceType,
              sourceCode: sourceCode,
              sourceTitle: sourceTitle,
              segmentCode: segmentCode,
            );
            return wb != null;
          },
    );
  }

  Widget _buildToolbarButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20.sp),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(color: Colors.white, fontSize: 11.sp),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _speakSelected(String text) async {
    if (!_ttsAvailable || _flutterTts == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TTS 不可用')));
      return;
    }

    await _flutterTts!.stop();
    _ttsTimer?.cancel();
    _isSpeaking = false;
    _ttsCurrentWordIndex = -1;
    _ttsSentenceIndex = -1;
    _ttsWords = [];
    _ttsProgressHandlerFired = false;

    final wordRegex = RegExp(r'(\b\w+\b|[^\w]+|\s+)');
    _ttsWords = wordRegex.allMatches(text).map((m) => m.group(0)!).where((t) => t.trim().isNotEmpty && RegExp(r'\w').hasMatch(t)).toList();

    for (int i = 0; i < _sentences.length; i++) {
      if (_sentences[i].content == text) {
        _ttsSentenceIndex = _sentences[i].sentenceIndex;
        break;
      }
    }

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

    // After 1s, if progress handler never fired, fall back to Timer
    _ttsTimer = Timer(const Duration(seconds: 1), () {
      if (_ttsProgressHandlerFired || !mounted) return;
      const msPerWord = 350;
      _ttsTimer = Timer.periodic(const Duration(milliseconds: msPerWord), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_ttsCurrentWordIndex >= _ttsWords.length - 1) {
          timer.cancel();
          _ttsTimer = null;
          if (mounted) {
            setState(() {
              _isSpeaking = false;
              _ttsCurrentWordIndex = -1;
              _ttsSentenceIndex = -1;
              _ttsWords = [];
            });
          }
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
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _ttsCurrentWordIndex = -1;
        _ttsSentenceIndex = -1;
        _ttsWords = [];
      });
    }
  }

  // ============================================================
  // 字体大小设置
  // ============================================================

  void _showFontSizeSheet() {
    double tempSize = _fontSize;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final colorScheme = Theme.of(ctx).colorScheme;
            return Container(
              padding: EdgeInsets.all(AppSpacing.lg.w),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '字体大小',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  SizedBox(height: AppSpacing.lg.h),

                  // 实时预览
                  Text(
                    'The quick brown fox jumps over the lazy dog.',
                    style: TextStyle(fontSize: tempSize.sp, color: colorScheme.onSurface),
                  ),
                  SizedBox(height: AppSpacing.lg.h),

                  // 滑块
                  Row(
                    children: [
                      Text('10', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      Expanded(
                        child: Slider(
                          value: tempSize,
                          min: 10,
                          max: 32,
                          divisions: 22,
                          activeColor: AppColors.primary,
                          onChanged: (v) => setSheetState(() => tempSize = v),
                        ),
                      ),
                      Text('32', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md.h),

                  // 按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheetState(() => tempSize = 16);
                          setState(() => _fontSize = 16);
                          SharedPreferences.getInstance().then((prefs) => prefs.setDouble('article_reader_font_size', 16));
                          Navigator.pop(ctx);
                        },
                        child: const Text('恢复默认'),
                      ),
                      SizedBox(width: AppSpacing.sm.w),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _fontSize = tempSize);
                          SharedPreferences.getInstance().then((prefs) => prefs.setDouble('article_reader_font_size', tempSize));
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('保存', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 侧边栏
  // ============================================================

  Widget _buildOutlineDrawer() {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Container(
              padding: EdgeInsets.all(AppSpacing.md.w),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Icon(Icons.list_alt, color: colorScheme.onSurface, size: 20.sp),
                  SizedBox(width: AppSpacing.sm.w),
                  Text(
                    '目录',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  const Spacer(),
                  if (_hasBookmark)
                    GestureDetector(
                      onTap: _jumpToBookmark,
                      child: Icon(Icons.bookmark, color: AppColors.primary, size: 20.sp),
                    ),
                ],
              ),
            ),

            // 列表
            Expanded(
              child: ListView.builder(
                itemCount: _chapters.length,
                itemBuilder: (context, index) {
                  final chapter = _chapters[index];
                  final isCurrent = index == _currentChapterIndex;
                  final firstSentence = chapter.plainText.length > 50 ? '${chapter.plainText.substring(0, 50)}...' : chapter.plainText;

                  return InkWell(
                    onTap: () => _jumpToChapter(index),
                    onLongPress: () => _showChapterActions(index),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.primary.withValues(alpha: 0.15) : null,
                        border: Border(bottom: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1))),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 序号
                          Container(
                            width: 28.w,
                            height: 28.w,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isCurrent ? AppColors.primary : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: isCurrent ? Colors.white : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  firstSentence,
                                  style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurface),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_hasBookmark && _bookmark != null && _bookmark!.paragraphIndex == index)
                                  Padding(
                                    padding: EdgeInsets.only(top: 2.h),
                                    child: Row(
                                      children: [
                                        Icon(Icons.bookmark, size: 10.sp, color: AppColors.primary),
                                        SizedBox(width: 2.w),
                                        Text(
                                          '书签',
                                          style: TextStyle(fontSize: 10.sp, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 阅读统计
            Container(
              padding: EdgeInsets.all(AppSpacing.md.w),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))),
              ),
              child: _buildReadingStats(colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  void _showChapterActions(int chapterIndex) {
    DialogUtils.show(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('第 ${chapterIndex + 1} 章'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _addBookmark(note: '第 ${chapterIndex + 1} 章');
            },
            child: const Row(children: [Icon(Icons.bookmark_add_outlined, size: 18), SizedBox(width: 8), Text('标记书签')]),
          ),
          if (_hasBookmark && _bookmark != null && _bookmark!.paragraphIndex == chapterIndex)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                _removeBookmark();
              },
              child: const Row(children: [Icon(Icons.bookmark_remove, size: 18), SizedBox(width: 8), Text('取消书签')]),
            ),
        ],
      ),
    );
  }

  Widget _buildReadingStats(ColorScheme colorScheme) {
    final totalWords = _article?.wordCount ?? 0;
    final totalSentences = _sentences.length;
    final readSentences = _readSentenceIndex + 1;
    final progressPercent = totalSentences > 0 ? (readSentences * 100 ~/ totalSentences) : 0;
    final estimatedMinutes = (totalWords / 200).ceil().clamp(1, 999);
    final keySentenceCount = _sentences.where((s) => s.isKeySentence).length;
    final markedWordCount = _markedWords.length;

    final stats = [
      _StatItem('总词数', '$totalWords'),
      _StatItem('总句数', '$totalSentences'),
      _StatItem('已读', '$progressPercent%'),
      _StatItem('预估', '$estimatedMinutes 分钟'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '阅读统计',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: AppSpacing.md.w,
          runSpacing: 8.h,
          children: stats.map((s) {
            return SizedBox(
              width: (MediaQuery.of(context).size.width * 0.75 - AppSpacing.md.w * 3) / 2,
              child: Row(
                children: [
                  Text(
                    s.label,
                    style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Text(
                    s.value,
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Text(
              '重点句',
              style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              '$keySentenceCount / $totalSentences',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ],
        ),
        if (markedWordCount > 0) ...[
          SizedBox(height: 4.h),
          Row(
            children: [
              Text(
                '标记词',
                style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                '$markedWordCount',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ),
        ],
        SizedBox(height: 8.h),
        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(2.r),
          child: LinearProgressIndicator(
            value: totalSentences > 0 ? (readSentences / totalSentences).clamp(0.0, 1.0) : 0,
            minHeight: 4.h,
            backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 主界面
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(backgroundColor: colorScheme.surface, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_article == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(backgroundColor: colorScheme.surface, elevation: 0),
        body: const Center(child: Text('文章不存在')),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(
          _article!.title,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 翻译开关
          _buildTranslateToggle(colorScheme),
          if (_hasBookmark)
            IconButton(
              icon: Icon(Icons.bookmark, color: AppColors.primary),
              onPressed: _jumpToBookmark,
              tooltip: '跳转书签',
            ),
          IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openEndDrawer(), tooltip: '目录'),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'font_size':
                  _showFontSizeSheet();
                  break;
                case 'add_bookmark':
                  _addBookmark();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'font_size', child: Text('字体大小')),
              const PopupMenuItem(value: 'add_bookmark', child: Text('添加书签')),
            ],
          ),
        ],
      ),
      endDrawer: _buildOutlineDrawer(),
      endDrawerEnableOpenDragGesture: true,
      body: Column(
        children: [
          // 正文区域
          Expanded(
            child: _chapters.isEmpty
                ? Center(
                    child: Text('暂无内容', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  )
                : _buildContent(colorScheme),
          ),

          // 底部进度条
          _buildBottomBar(colorScheme),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    final chapter = _chapters.isNotEmpty ? (_currentChapterIndex < _chapters.length ? _chapters[_currentChapterIndex] : _chapters.first) : null;

    if (chapter == null) {
      return Center(
        child: Text('暂无内容', style: TextStyle(color: colorScheme.onSurfaceVariant)),
      );
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.all(AppSpacing.md.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 章节导航
          _buildChapterNav(colorScheme),

          SizedBox(height: AppSpacing.lg.h),

          // 章节文本（逐句渲染，支持划词）
          ..._buildChapterSentences(chapter, colorScheme),

          // 翻译显示
          if (_showTranslation && _translation != null) _buildTranslationSection(chapter, colorScheme),

          SizedBox(height: AppSpacing.xxl.h),
        ],
      ),
    );
  }

  Widget _buildChapterNav(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _currentChapterIndex > 0 ? () => setState(() => _currentChapterIndex--) : null,
          icon: const Icon(Icons.arrow_back_ios),
          iconSize: 16.sp,
        ),
        Text(
          '第 ${_currentChapterIndex + 1} 章 / ${_chapters.length}',
          style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
        ),
        IconButton(
          onPressed: _currentChapterIndex < _chapters.length - 1 ? () => setState(() => _currentChapterIndex++) : null,
          icon: const Icon(Icons.arrow_forward_ios),
          iconSize: 16.sp,
        ),
      ],
    );
  }

  // ============================================================
  // 句子渲染
  // ============================================================

  List<Widget> _buildChapterSentences(ArticleChapter chapter, ColorScheme colorScheme) {
    final startIdx = chapter.startSentenceIndex;
    final endIdx = chapter.endSentenceIndex + 1;
    final chapterSentences = _sentences.where((s) => s.sentenceIndex >= startIdx && s.sentenceIndex < endIdx).toList();

    if (chapterSentences.isEmpty) {
      return [
        SelectableText(
          chapter.plainText,
          style: TextStyle(fontSize: _fontSize.sp, color: colorScheme.onSurface, height: 1.8),
        ),
      ];
    }

    final widgets = <Widget>[];

    // 章标题
    if (chapter.title.isNotEmpty) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Text(
            chapter.title,
            style: TextStyle(fontSize: (_fontSize + 4).sp, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
          ),
        ),
      );
    }

    final lastIdx = chapterSentences.length - 1;
    for (int i = 0; i < chapterSentences.length; i++) {
      final sentence = chapterSentences[i];
      final isCurrent = sentence.sentenceIndex == _readSentenceIndex;
      final isTtsSentence = _isSpeaking && _ttsSentenceIndex == sentence.sentenceIndex;
      final spans = _buildMarkedSpans(
        sentence.content,
        colorScheme,
        isCurrent,
        ttsWordIndex: isTtsSentence ? _ttsCurrentWordIndex : -1,
        ttsWords: isTtsSentence ? _ttsWords : const [],
      );
      _sentenceKeys.putIfAbsent(sentence.sentenceIndex, () => GlobalKey());
      widgets.add(
        KeyedSubtree(key: _sentenceKeys[sentence.sentenceIndex], child: _buildSentenceTile(sentence, spans, colorScheme, isCurrent, i == lastIdx)),
      );

      final next = i + 1 <= lastIdx ? chapterSentences[i + 1] : null;
      final isEndOfParagraph = next == null || next.paragraphIndex != sentence.paragraphIndex;
      if (isEndOfParagraph) {
        widgets.add(_buildParagraphFooter(sentence.paragraphIndex, colorScheme));
      }
    }
    return widgets;
  }

  Widget _buildParagraphFooter(int paragraphIndex, ColorScheme colorScheme) {
    final hasAnyTranslation = _sentences.any((s) => s.paragraphIndex == paragraphIndex && (s.contentTranslate ?? '').trim().isNotEmpty);

    return Padding(
      padding: EdgeInsets.fromLTRB(6.w, 0, 6.w, 10.h),
      child: Row(
        children: [
          const Spacer(),
          InkWell(
            onTap: () => _onParagraphTranslateTap(paragraphIndex),
            borderRadius: BorderRadius.circular(6.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate_outlined, size: 14.sp, color: AppColors.primary.withValues(alpha: 0.95)),
                  SizedBox(width: 4.w),
                  Text(
                    hasAnyTranslation ? '本段已翻译' : '翻译本段',
                    style: TextStyle(fontSize: 11.sp, color: AppColors.primary.withValues(alpha: 0.95)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onParagraphTranslateTap(int paragraphIndex) async {
    final needsTranslation = _sentences.any((s) => s.paragraphIndex == paragraphIndex && (s.contentTranslate ?? '').trim().isEmpty);

    if (needsTranslation && !_loadingTranslation) {
      await _loadTranslation();
    }
    if (!mounted) return;
    setState(() => _showTranslation = true);
  }

  Widget _buildSentenceTile(ArticleSentence sentence, List<TextSpan> spans, ColorScheme colorScheme, bool isCurrent, bool isLast) {
    final bool isTtsSpeakingThis = _isSpeaking && _ttsSentenceIndex == sentence.sentenceIndex;

    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.primary.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(6.r),
        border: isCurrent ? Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1) : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 4.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText.rich(
              TextSpan(
                style: TextStyle(fontSize: _fontSize.sp, color: colorScheme.onSurface, height: 1.8),
                children: spans,
              ),
              onSelectionChanged: (selection, cause) {
                if (selection.isValid && selection.isNormalized && selection.end > selection.start) {
                  final selText = sentence.content.substring(selection.start, selection.end);
                  final lower = selText.toLowerCase().trim();
                  if (!selText.contains(' ') && _markedWords.containsKey(lower)) {
                    _showMarkedWordActions(lower);
                  } else {
                    _showSelectionSheet(selText, contextSentence: sentence.content, segmentCode: sentence.sentenceIndex.toString());
                  }
                }
              },
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTtsSpeakingThis)
                  _buildSentenceActionBtn(Icons.stop_circle_outlined, '停止', _stopSpeaking)
                else
                  _buildSentenceActionBtn(Icons.volume_up_outlined, '朗读', () => _speakSelected(sentence.content)),
                SizedBox(width: 10.w),
                _buildSentenceActionBtn(
                  sentence.isKeySentence ? Icons.bookmark : Icons.bookmark_border,
                  sentence.isKeySentence ? '已标记' : '书签',
                  () => _toggleSentenceKey(sentence),
                ),
              ],
            ),
            if (!isLast)
              Padding(
                padding: EdgeInsets.only(top: 4.h),
                child: Divider(height: 1.h, color: colorScheme.outline.withValues(alpha: 0.08)),
              ),
            if (_showTranslation && sentence.contentTranslate != null && sentence.contentTranslate!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: Text(
                  sentence.contentTranslate!,
                  style: TextStyle(fontSize: (_fontSize - 2).sp, color: colorScheme.onSurface.withValues(alpha: 0.7), height: 1.6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 翻译开关
  // ============================================================

  Widget _buildTranslateToggle(ColorScheme colorScheme) {
    if (_loadingTranslation) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final hasTranslation = _translation != null;
    return IconButton(
      icon: Icon(
        _showTranslation ? Icons.translate : Icons.translate_outlined,
        color: _showTranslation ? AppColors.primary : colorScheme.onSurfaceVariant,
      ),
      onPressed: hasTranslation ? () => setState(() => _showTranslation = !_showTranslation) : () => _retryTranslation(),
      tooltip: hasTranslation ? (_showTranslation ? '隐藏翻译' : '显示翻译') : '重新翻译',
    );
  }

  void _retryTranslation() {
    setState(() {
      _translation = null;
      _showTranslation = false;
    });
    _loadTranslation();
  }

  // ============================================================
  // 翻译显示
  // ============================================================

  Widget _buildTranslationSection(ArticleChapter chapter, ColorScheme colorScheme) {
    final chapterIdx = chapter.chapterIndex.toString();
    final translated = _translation?.chapterTranslations[chapterIdx] ?? _translation?.fullTranslation;

    if (translated == null || translated.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.md.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.primary.withValues(alpha: 0.2)),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            '中文翻译',
            style: TextStyle(fontSize: 12.sp, color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: AppSpacing.sm.h),
          SelectableText(
            translated,
            style: TextStyle(fontSize: (_fontSize - 2).sp, color: colorScheme.onSurface.withValues(alpha: 0.85), height: 1.7),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceActionBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13.sp, color: AppColors.primary),
            SizedBox(width: 2.w),
            Text(
              label,
              style: TextStyle(fontSize: 11.sp, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 标记词文本 Span 构建
  // ============================================================

  List<TextSpan> _buildMarkedSpans(String text, ColorScheme colorScheme, bool isCurrent, {int ttsWordIndex = -1, List<String> ttsWords = const []}) {
    if (_markedWords.isEmpty && ttsWordIndex < 0) {
      return [TextSpan(text: text)];
    }
    final regex = RegExp(r'(\b\w+\b|[^\w]+|\s+)');
    final matches = regex.allMatches(text);
    final spans = <TextSpan>[];
    int wordMatchIdx = 0;
    for (final m in matches) {
      final token = m.group(0)!;
      final lower = token.toLowerCase();
      final markColor = _markedWords[lower] ?? _markedWords[token];

      // TTS 逐词高亮
      final bool isTtsWord =
          ttsWordIndex >= 0 &&
          ttsWords.isNotEmpty &&
          wordMatchIdx < ttsWords.length &&
          ttsWords[wordMatchIdx] == token &&
          wordMatchIdx == ttsWordIndex;
      if (token.trim().isNotEmpty && RegExp(r'\w').hasMatch(token)) {
        wordMatchIdx++;
      }

      if (isTtsWord) {
        spans.add(
          TextSpan(
            text: token,
            style: TextStyle(backgroundColor: AppColors.primary.withValues(alpha: 0.3), color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        );
      } else if (markColor != null) {
        spans.add(
          TextSpan(
            text: token,
            style: TextStyle(
              backgroundColor: markColor.withValues(alpha: 0.25),
              color: isCurrent ? colorScheme.onSurface : null,
              decoration: TextDecoration.underline,
              decorationColor: markColor,
              decorationThickness: 2,
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: token));
      }
    }
    return spans;
  }

  Future<void> _toggleSentenceKey(ArticleSentence sentence) async {
    sentence.isKeySentence = !sentence.isKeySentence;
    await sentence.save();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(sentence.isKeySentence ? '已标记重点句' : '已取消标记'), duration: const Duration(seconds: 1)));
    }
  }

  // ============================================================
  // 单词标记
  // ============================================================

  void _showColorPicker(String word) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('标记「$word」', style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择标记颜色：', style: TextStyle(fontSize: 13)),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: List.generate(_markerColors.length, (i) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx, i);
                  },
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: _markerColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26, width: 1),
                      boxShadow: [BoxShadow(color: _markerColors[i].withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消'))],
      ),
    ).then((colorIdx) {
      if (colorIdx != null && mounted) {
        _markWord(word, colorIdx as int);
      }
    });
  }

  void _markWord(String word, int colorIndex) {
    final lower = word.toLowerCase().trim();
    if (_markedWords.containsKey(lower)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('该单词已有标记，长按标记可更换颜色'), duration: Duration(seconds: 2)));
      return;
    }
    setState(() {
      _markedWords[lower] = _markerColors[colorIndex % _markerColors.length];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已标记单词，全文同步高亮'), duration: Duration(seconds: 2)));
    }
  }

  void _showMarkedWordActions(String word) {
    final color = _markedWords[word];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.md.w),
              child: Row(
                children: [
                  Container(
                    width: 16.w,
                    height: 16.w,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '「$word」',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('查词'),
              onTap: () {
                Navigator.pop(ctx);
                final currentList = _sentences.where((s) => s.sentenceIndex == _readSentenceIndex).toList();
                final current = currentList.isNotEmpty ? currentList.first : null;
                _openWordCard(word, contextSentence: current?.content, segmentCode: _readSentenceIndex.toString());
              },
            ),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: const Text('更换颜色'),
              onTap: () {
                Navigator.pop(ctx);
                _changeMarkColor(word);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除标记', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _markedWords.remove(word));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已移除「$word」的标记'), duration: const Duration(seconds: 2)));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _changeMarkColor(String word) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('更换「$word」的颜色'),
        content: Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: List.generate(_markerColors.length, (i) {
            final isCurrent = _markedWords[word] == _markerColors[i];
            return GestureDetector(
              onTap: () {
                Navigator.pop(ctx, i);
              },
              child: Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: _markerColors[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: isCurrent ? Colors.black : Colors.black26, width: isCurrent ? 2.5 : 1),
                  boxShadow: [BoxShadow(color: _markerColors[i].withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: isCurrent ? const Icon(Icons.check, color: Colors.black, size: 18) : null,
              ),
            );
          }),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消'))],
      ),
    ).then((colorIdx) {
      if (colorIdx != null && mounted) {
        setState(() {
          _markedWords[word] = _markerColors[colorIdx as int];
        });
      }
    });
  }

  Widget _buildBottomBar(ColorScheme colorScheme) {
    final totalSentences = _sentences.length;
    final progress = totalSentences > 0 ? (_readSentenceIndex + 1) / totalSentences : 0.0;
    final estimatedMinutes = (_article!.wordCount / 200).ceil().clamp(1, 999);
    final readWords = ((_readSentenceIndex + 1) / totalSentences * _article!.wordCount).round().clamp(0, _article!.wordCount);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2.r),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 3.h,
                backgroundColor: colorScheme.outline.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '预估 $estimatedMinutes 分钟 · 已读 $readWords / ${_article!.wordCount} 词',
              style: TextStyle(fontSize: 11.sp, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);
}
