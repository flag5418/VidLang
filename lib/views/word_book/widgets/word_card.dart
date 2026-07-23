import 'dart:developer' as dev;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;
import 'package:vidlang/utils/app_globals.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/views/word_book/providers/display_config_provider.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/ai/ai_service.dart';
import 'package:vidlang/services/ai/unified_translation_service.dart';
import 'package:vidlang/services/tts/local_tts_service.dart';
import 'package:vidlang/services/tts/unified_tts_service.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/views/word_book/widgets/native_translation_guide_sheet.dart';
import 'package:vidlang/components/dialogs/recharge_dialog.dart';
import 'package:vidlang/views/word_book/widgets/free_translation_card.dart';
import 'package:vidlang/views/word_book/widgets/word_detail_panel.dart';

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
///   onSaveWord: (word, contextSentence, sourceType, sourceCode, sourceTitle) async { ... },
///   sourceType: 'video',
///   sourceCode: 'xxx',
///   sourceTitle: 'xxx',
/// );
/// ```
///
/// **分流规则（严格按 SubscriptionMode，无附加条件）**：
/// - 发音：premium → 云端 TTS | free → iOS 原生 TTS
/// - 释义：premium → AiService.getDefinition (云端 AI) | free → UnifiedTranslationService (iOS 原生翻译)
///
/// 组件内部自主读取 subscriptionProvider 判定，调用方无需传入任何模式参数。
class WordCard extends ConsumerStatefulWidget {
  final String word;
  final String? contextSentence;

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
    this.onSaveWord,
    this.sourceType = 'video',
    this.sourceCode = '',
    this.sourceTitle,
    this.segmentCode,
  });

  /// 以 Dialog 方式展示 WordCard
  static Future<void> show(
    BuildContext context, {
    required String word,
    String? contextSentence,
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
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black45,
      barrierLabel: 'WordCard',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => WordCard._internal(
        word: word,
        contextSentence: contextSentence,
        onSaveWord: onSaveWord,
        sourceType: sourceType,
        sourceCode: sourceCode,
        sourceTitle: sourceTitle,
        segmentCode: segmentCode,
      ),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
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

  /// 🔴 独立的音频播放器实例（不与 Player/TtsService 共用）
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  bool _isSpeaking = false;

  /// 内部自主判定付费模式，严格按 SubscriptionMode 分流
  bool get _isPaidMode =>
      ref.read(subscriptionProvider).mode == SubscriptionMode.premium;

  @override
  void initState() {
    super.initState();
    // 加载数据
    _loadSavedState();
    _fetchDefinition();

    // 延迟发音：使用独立播放器，不影响 Player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _speakWord();
    });
  }

  /// 🔴 独立发音方法：使用独立的 AudioPlayer，完全隔离 Player
  Future<void> _speakWord() async {
    if (_isSpeaking) _stopSpeaking(); // 同步停止

    final mode = _isPaidMode ? SubscriptionMode.premium : SubscriptionMode.free;
    _isSpeaking = true;

    try {
      if (mode == SubscriptionMode.premium) {
        // 付费模式：使用云端 TTS + 独立 AudioPlayer 播放
        await _speakWithCloudTts();
      } else {
        // 免费模式：使用 iOS 原生 TTS + 独立 AudioPlayer 播放
        await _speakWithLocalTts();
      }
    } catch (e) {
      dev.log('🔊 [WordCard] TTS 发音异常: $e', name: 'WordCard', error: e);
    } finally {
      _isSpeaking = false;
    }
  }

  /// 免费模式：iOS 原生 TTS
  Future<void> _speakWithLocalTts() async {
    final result = await UnifiedTtsService.instance.synthesize(
      text: widget.word,
      mode: SubscriptionMode.free,
      onWord: null,
    );

    if (!mounted || result.success != true) return;

    // 直接播放模式（iOS AVSpeechSynthesizer 已在 synthesize 中播放）
    if (result.audioPath.isEmpty || result.format == 'direct') {
      // 估算播放时长并等待
      final wordCount = widget.word.trim().isEmpty
          ? 1
          : widget.word.trim().split(RegExp(r'\s+')).length;
      final estimatedMs = (wordCount * 400).clamp(500, 30000);
      await Future.delayed(Duration(milliseconds: estimatedMs));
      return;
    }

    // 文件播放模式：使用独立 AudioPlayer
    final file = result.audioPath;
    if (file.isEmpty) return;

    await _audioPlayer.play(ap.DeviceFileSource(file));
    await _audioPlayer.onPlayerComplete.first;
  }

  /// 付费模式：云端 TTS（暂未实现，先用本地降级）
  Future<void> _speakWithCloudTts() async {
    // TODO: 集成 DashScope TTS 到独立实例
    // 目前降级为本地 TTS
    await _speakWithLocalTts();
  }

  /// 立即停止发音（同步，参考 Player 的 pause 模式）
  void _stopSpeaking() {
    try {
      // 1. 停止 AudioPlayer
      _audioPlayer.stop();
      // 2. 停止原生 TTS（iOS AVSpeechSynthesizer）
      LocalTtsService.instance.stop();
      // 3. 重置状态
      _isSpeaking = false;
    } catch (e) {
      dev.log('🔊 [WordCard] stopSpeaking 异常: $e', name: 'WordCard');
    }
  }

  @override
  void dispose() {
    // 🔴 同步释放资源（不能是 async！）
    _stopSpeaking();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSavedState() async {
    try {
      final isSingleWord = WordBookService.isSingleWord(widget.word);
      final saved = isSingleWord
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
      // 严格按 SubscriptionMode 分流，不区分单词/句子
      if (_isPaidMode) {
        // 付费模式 → 云端 AI 释义（带三级缓存）
        dev.log('📖 [WordCard] 开始查询 AI 释义: "${widget.word}"', name: 'WordCard');
        detail = await AiService.getDefinition(
          word: widget.word,
          contextSentence: widget.contextSentence,
          sourceType: widget.sourceType,
          sourceCode: widget.sourceCode,
          billing: {'mode': 'premium'},
        );
      } else {
        // 免费模式 → iOS 原生翻译
        dev.log(
          '📖 [WordCard] 开始查询 iOS 原生翻译: "${widget.word}"',
          name: 'WordCard',
        );
        detail = await UnifiedTranslationService.instance.translate(
          text: widget.word,
          mode: SubscriptionMode.free,
          contextSentence: widget.contextSentence,
          sourceType: widget.sourceType,
          sourceCode: widget.sourceCode,
        );
      }

      // if (!mounted) return;

      dev.log(
        '📖 [WordCard] 查询结果: success=${detail.success} word="${detail.word}" translation="${detail.translation ?? 'null'}" error="${detail.error ?? 'null'}" source="${detail.source}"',
        name: 'WordCard',
      );

      // 翻译失败时处理（无本地模型概念，统一按成功/失败处理）
      if (!detail.success) {
        // iOS 原生翻译可能需要下载语言包
        if (detail.languagePackRequired && mounted) {
          dev.log('📱 [WordCard] 需要下载语言包', name: 'WordCard');
          NativeTranslationGuideSheet.show(context);
        }
        // 不再区分 local/local_ai/native source，统一由 UI 展示错误信息
      }

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
    } catch (e, stackTrace) {
      dev.log(
        '💥 [WordCard] 查询异常: $e\n$stackTrace',
        name: 'WordCard',
        error: e,
      );
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
      final isSingleWord = WordBookService.isSingleWord(widget.word);
      if (_saved) {
        final ok = isSingleWord
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
          // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
          TDToast.showText('已取消收藏', context: context);
        }
        return;
      }

      bool ok;
      if (isSingleWord) {
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
        // ✅ TDesign 规范：使用 TDToast 替代 SnackBar
        TDToast.showSuccess('已收藏「${widget.word}」', context: context);
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(displayConfigProvider).config;
    final isSingleWord = WordBookService.isSingleWord(widget.word);

    // 统一发音回调：使用独立播放器
    Future<void> speakCallback() => _speakWord();

    // loading 状态
    if (_state == _LoadState.loading) {
      // 免费模式使用极简加载卡片
      if (!_isPaidMode) {
        return _buildFreeLoadingCard(context);
      }
      // 付费模式使用完整加载面板
      return WordDetailPanel(
        data: WordDetail(
          word: widget.word,
          pronounce: PronounceInfo(),
          definitions: [],
          standaloneExamples: [],
          success: true,
          source: 'loading',
          isSentenceMode: !isSingleWord,
        ),
        config: config,
        onSpeak: speakCallback,
        onClose: () => Navigator.of(context).pop(),
        isLoading: true,
        isSaved: _saved,
        saving: _saving,
        onSaveWord: isSingleWord
            ? (widget.onSaveWord != null ? _handleToggleSave : null)
            : _handleToggleSave,
        isSentenceMode: !isSingleWord,
      );
    }

    if (_detail == null) return const SizedBox.shrink();

    // 免费模式使用极简翻译卡片
    if (!_isPaidMode) {
      return _buildFreeTranslationCard(context);
    }

    // 付费模式使用完整详情面板
    return WordDetailPanel(
      data: _detail!,
      config: config,
      onSpeak: speakCallback,
      onClose: () => Navigator.of(context).pop(),
      isSaved: _saved,
      saving: _saving,
      onSaveWord: isSingleWord
          ? (widget.onSaveWord != null ? _handleToggleSave : null)
          : _handleToggleSave,
      isSentenceMode: !isSingleWord,
    );
  }

  Widget _buildFreeLoadingCard(BuildContext context) {
    final cs = context.colors;
    final brightness = Theme.of(context).brightness;
    final screenSize = MediaQuery.of(context).size;
    final isWide = AppGlobals.isTablet;
    final cardWidth = isWide ? 420.0 : screenSize.width * 0.88;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(maxHeight: screenSize.height * 0.7),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: brightness == Brightness.dark ? 0.4 : 0.08,
              ),
              blurRadius: adaptive.Adaptive.w(20),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: adaptive.Adaptive.w(16),
                vertical: adaptive.Adaptive.h(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '翻译',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: adaptive.Adaptive.sp(13),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      Icons.close_rounded,
                      size: adaptive.Adaptive.icon(18),
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: cs.outlineVariant.withValues(
                alpha: brightness == Brightness.dark ? 0.3 : 0.15,
              ),
            ),
            const Flexible(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeTranslationCard(BuildContext context) {
    Future<bool> buildSaveCallback({
      required String word,
      String? contextSentence,
      required String sourceType,
      required String sourceCode,
      String? sourceTitle,
    }) async {
      await _handleToggleSave();
      return true;
    }

    return FreeTranslationCard(
      word: widget.word,
      contextSentence: widget.contextSentence,
      translation: _detail!.translation,
      success: _detail!.success,
      error: _detail!.error,
      onSaveWord: widget.onSaveWord != null ? buildSaveCallback : null,
      sourceType: widget.sourceType,
      sourceCode: widget.sourceCode,
      sourceTitle: widget.sourceTitle,
      onClose: () => Navigator.of(context).pop(),
    );
  }
}
