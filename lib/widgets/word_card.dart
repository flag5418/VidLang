import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/providers/display_config_provider.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/dictionary_service.dart';
import 'package:vidlang/services/ios_native_features.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/utils/dialog_utils.dart';
import 'package:vidlang/widgets/recharge_dialog.dart';
import 'package:vidlang/widgets/word_detail_panel.dart';

/// WordBook → WordDetail 映射扩展
extension WordBookWordCardMapper on WordBook {
  WordDetail toWordDetail() {
    final defs = WordBookService.parseDefinitions(definitionsJson);
    return WordDetail(
      word: word,
      pronounce: PronounceInfo(
        ukPhonetic: phoneticUk,
        usPhonetic: phoneticUs,
      ),
      definitions: defs.map((d) => WordDefinition(
        partOfSpeech: d.partOfSpeech,
        chineseMeaning: d.meaning,
      )).toList(),
      contextSentence: contextSentence,
      difficulty: DifficultyLevelX.fromString(null),
      success: true,
      source: 'native',
    );
  }
}

/// 单词查词弹窗 — 分段加载模式
///
/// 用法：
/// ```dart
/// WordCard.show(
///   context,
///   word: 'example',
///   contextSentence: 'This is an example sentence.',
///   isPaidMode: ref.read(subscriptionProvider).isPremium,
///   onSpeak: () => doSomething(),
///   onSaveWord: (word, contextSentence, sourceType, sourceCode, sourceTitle) async { ... },
///   sourceType: 'video',
///   sourceCode: 'xxx',
///   sourceTitle: 'xxx',
/// );
/// ```
class WordCard extends ConsumerStatefulWidget {
  final String word;
  final String? contextSentence;
  final bool isPaidMode;
  final VoidCallback? onSpeak;

  /// 收藏回调
  final Future<bool> Function({
    required String word,
    String? contextSentence,
    required String sourceType,
    required String sourceCode,
    String? sourceTitle,
  })? onSaveWord;

  final String sourceType;
  final String sourceCode;
  final String? sourceTitle;
  final String? segmentCode;

  const WordCard._internal({
    required this.word,
    this.contextSentence,
    this.isPaidMode = false,
    this.onSpeak,
    this.onSaveWord,
    this.sourceType = 'video',
    this.sourceCode = '',
    this.sourceTitle,
    this.segmentCode,
  });

  /// 以 Dialog 方式展示 WordCard
  ///
  /// 注：showDialog 在新版 Flutter 中使用了 Windowing API，
  /// Android 不支持，因此改用 DialogUtils。
  static Future<void> show(
    BuildContext context, {
    required String word,
    String? contextSentence,
    bool isPaidMode = false,
    VoidCallback? onSpeak,
    Future<bool> Function({
      required String word,
      String? contextSentence,
      required String sourceType,
      required String sourceCode,
      String? sourceTitle,
    })? onSaveWord,
    String sourceType = 'video',
    String sourceCode = '',
    String? sourceTitle,
    String? segmentCode,
  }) {
    return DialogUtils.show<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (ctx) => WordCard._internal(
        word: word,
        contextSentence: contextSentence,
        isPaidMode: isPaidMode,
        onSpeak: onSpeak,
        onSaveWord: onSaveWord,
        sourceType: sourceType,
        sourceCode: sourceCode,
        sourceTitle: sourceTitle,
        segmentCode: segmentCode,
      ),
    );
  }

  @override
  ConsumerState<WordCard> createState() => _WordCardState();
}

enum _LoadState { loading, loaded, error }

class _WordCardState extends ConsumerState<WordCard> {
  WordDetail? _detail;
  _LoadState _state = _LoadState.loading;

  bool _saving = false;
  bool _saved = false;
  bool _rechargeShown = false;

  @override
  void initState() {
    super.initState();
    // 立即 TTS 发音
    TtsService().speakWord(widget.word);
    _fetchDefinition();
  }

  Future<void> _fetchDefinition() async {
    try {
      WordDetail detail;

      if (widget.isPaidMode) {
        // 付费用户走 AI
        detail = await AiService.getDefinition(
          word: widget.word,
          contextSentence: widget.contextSentence,
        );
      } else {
        // 免费用户：先用本地词典 placeholder，实际可接入本地词典
        detail = await _localFallback(widget.word);
      }

      if (!mounted) return;

      // 余额不足时弹出充值弹窗
      if (detail.isInsufficientBalance && !_rechargeShown) {
        _rechargeShown = true;
        RechargeDialog.show(
          context,
          requiredCny: detail.costCny ?? 0.01,
          balanceCny: detail.balanceAfter ?? 0,
          featureName: 'AI释义',
        );
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _detail = detail;
        _state = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detail = WordDetail.error(widget.word, '查询失败: $e');
        _state = _LoadState.error;
      });
    }
  }

  /// 本地词典兆底查询
  Future<WordDetail> _localFallback(String word) async {
    try {
      // 并行查询本地词典 + 系统翻译
      final results = await Future.wait([
        DictionaryService().lookup(word),
        IosNativeFeatures.translate(text: word),
      ]);
  
      final dictEntry = results[0] as DictEntry?;
      final translationResult = results[1] as TranslationResult;
  
      // 解析释义
      final definitions = <WordDefinition>[];
      if (dictEntry != null && dictEntry.translation != null && dictEntry.translation!.isNotEmpty) {
        for (final line in dictEntry.translation!.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final match = RegExp(r'^([a-z]+\.)\s*(.+)$').firstMatch(trimmed);
          if (match != null) {
            definitions.add(WordDefinition(
              partOfSpeech: match.group(1),
              chineseMeaning: match.group(2)!,
            ));
          } else {
            definitions.add(WordDefinition(chineseMeaning: trimmed));
          }
        }
      }
  
      // 系统翻译作为补充
      String? translation;
      if (translationResult.success && translationResult.translatedText.isNotEmpty && translationResult.translatedText != word) {
        translation = translationResult.translatedText;
      }
  
      if (definitions.isNotEmpty || translation != null) {
        // 如果没有解析出 definitions，用翻译填充
        if (definitions.isEmpty && translation != null) {
          definitions.add(WordDefinition(chineseMeaning: translation));
        }
  
        return WordDetail(
          word: word,
          pronounce: PronounceInfo(
            ukPhonetic: dictEntry?.phonetic,
          ),
          definitions: definitions,
          contextSentence: widget.contextSentence,
          success: true,
          source: 'local',
        );
      }
    } catch (_) {}
  
    // 最终兆底
    return WordDetail(
      word: word,
      definitions: [
        WordDefinition(
          chineseMeaning: '暂无本地释义，请升级付费版使用 AI 释义',
        ),
      ],
      success: true,
      source: 'local',
    );
  }

  Future<void> _handleSave() async {
    if (_saving || _saved || widget.onSaveWord == null) return;
    setState(() => _saving = true);
    try {
      final ok = await widget.onSaveWord!(
        word: widget.word,
        contextSentence: widget.contextSentence,
        sourceType: widget.sourceType,
        sourceCode: widget.sourceCode,
        sourceTitle: widget.sourceTitle,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (ok) _saved = true;
      });
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已收藏「${widget.word}」'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(displayConfigProvider).config;

    // loading 状态时使用占位 WordDetail
    if (_state == _LoadState.loading) {
      return WordDetailPanel(
        data: WordDetail(
          word: widget.word,
          pronounce: PronounceInfo(),
          definitions: [],
          standaloneExamples: [],
          success: true,
          source: 'loading',
        ),
        config: config,
        onSpeak: () => TtsService().speakWord(widget.word),
        onClose: () => Navigator.of(context).pop(),
        isLoading: true,
        onSaveWord: widget.onSaveWord != null && WordBookService.isSingleWord(widget.word)
            ? _handleSave
            : null,
        isSaved: _saved,
        saving: _saving,
      );
    }

    if (_detail == null) {
      return const SizedBox.shrink();
    }

    return WordDetailPanel(
      data: _detail!,
      config: config,
      onSpeak: widget.onSpeak ?? () => TtsService().speakWord(widget.word),
      onClose: () => Navigator.of(context).pop(),
      onSaveWord: widget.onSaveWord != null && WordBookService.isSingleWord(widget.word)
          ? _handleSave
          : null,
      isSaved: _saved,
      saving: _saving,
    );
  }
}
