import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/providers/display_config_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/unified_translation_service.dart';
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
      pronounce: PronounceInfo(ukPhonetic: phoneticUk, usPhonetic: phoneticUs),
      definitions: defs
          .map(
            (d) => WordDefinition(
              partOfSpeech: d.partOfSpeech,
              chineseMeaning: d.meaning,
            ),
          )
          .toList(),
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
  })?
  onSaveWord;

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
    })?
    onSaveWord,
    String sourceType = 'video',
    String sourceCode = '',
    String? sourceTitle,
    String? segmentCode,
  }) {
    return DialogUtils.show<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black45,
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
  late final bool _isSingleWord;

  @override
  void initState() {
    super.initState();
    _isSingleWord = WordBookService.isSingleWord(widget.word);
    if (widget.onSpeak != null) {
      widget.onSpeak!.call();
    } else {
      final mode = widget.isPaidMode
          ? SubscriptionMode.premium
          : SubscriptionMode.free;
      if (_isSingleWord) {
        TtsService().speakWord(widget.word, mode: mode);
      } else {
        TtsService().speakSubtitle(widget.word, mode: mode);
      }
    }
    _loadSavedState();
    _fetchDefinition();
  }

  @override
  void dispose() {
    // 弹窗关闭时停止 TTS 朗读
    TtsService().stop();
    super.dispose();
  }

  Future<void> _loadSavedState() async {
    try {
      final saved = _isSingleWord
          ? await WordBookService.isWordSaved(
              word: widget.word,
              sourceType: widget.sourceType,
              sourceCode: widget.sourceCode,
            )
          : await WordBookService.isSentenceSaved(
              text: widget.word,
              sourceType: widget.sourceType,
              sourceCode: widget.sourceCode,
            );
      if (!mounted) return;
      setState(() => _saved = saved);
    } catch (_) {}
  }

  Future<void> _fetchDefinition() async {
    try {
      WordDetail detail;
      final isPremium = widget.isPaidMode;

      if (_isSingleWord) {
        detail = await UnifiedTranslationService.instance.translate(
          text: widget.word,
          mode: isPremium ? SubscriptionMode.premium : SubscriptionMode.free,
          contextSentence: widget.contextSentence,
          sourceType: widget.sourceType,
          sourceCode: widget.sourceCode,
        );
      } else {
        detail = await UnifiedTranslationService.instance.translate(
          text: widget.word,
          mode: isPremium ? SubscriptionMode.premium : SubscriptionMode.free,
          contextSentence: widget.contextSentence,
          sourceType: widget.sourceType,
          sourceCode: widget.sourceCode,
        );
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

  Future<void> _handleToggleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_saved) {
        final ok = _isSingleWord
            ? await WordBookService.unsaveWord(
                word: widget.word,
                sourceType: widget.sourceType,
                sourceCode: widget.sourceCode,
              )
            : await WordBookService.unsaveSentence(
                text: widget.word,
                sourceType: widget.sourceType,
                sourceCode: widget.sourceCode,
              );
        if (!mounted) return;
        setState(() {
          _saving = false;
          if (ok) _saved = false;
        });
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已取消收藏'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      bool ok;
      if (_isSingleWord) {
        if (widget.onSaveWord == null) {
          ok = false;
        } else {
          ok = await widget.onSaveWord!(
            word: widget.word,
            contextSentence: widget.contextSentence,
            sourceType: widget.sourceType,
            sourceCode: widget.sourceCode,
            sourceTitle: widget.sourceTitle,
          );
        }
      } else {
        final wb = await WordBookService.saveSentence(
          text: widget.word,
          translation: _detail?.sentenceTranslation ?? _detail?.translation,
          sourceType: widget.sourceType,
          sourceCode: widget.sourceCode,
          sourceTitle: widget.sourceTitle,
          segmentCode: widget.segmentCode,
        );
        ok = wb != null;
      }

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
        onSpeak:
            widget.onSpeak ??
            () => (_isSingleWord
                ? TtsService().speakWord(widget.word)
                : TtsService().speakSubtitle(widget.word)),
        onClose: () => Navigator.of(context).pop(),
        isLoading: true,
        isSaved: _saved,
        saving: _saving,
        onSaveWord: _isSingleWord
            ? (widget.onSaveWord != null ? _handleToggleSave : null)
            : _handleToggleSave,
      );
    }

    if (_detail == null) return const SizedBox.shrink();

    return WordDetailPanel(
      data: _detail!,
      config: config,
      onSpeak:
          widget.onSpeak ??
          () => (_isSingleWord
              ? TtsService().speakWord(widget.word)
              : TtsService().speakSubtitle(widget.word)),
      onClose: () => Navigator.of(context).pop(),
      isSaved: _saved,
      saving: _saving,
      onSaveWord: _isSingleWord
          ? (widget.onSaveWord != null ? _handleToggleSave : null)
          : _handleToggleSave,
    );
  }
}
