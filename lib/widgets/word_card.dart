import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/providers/display_config_provider.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/dictionary_service.dart';
import 'package:vidlang/services/ios_native_features.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/services/word_tag_service.dart';
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
      definitions: defs.map((d) => WordDefinition(partOfSpeech: d.partOfSpeech, chineseMeaning: d.meaning)).toList(),
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
      if (_isSingleWord) {
        TtsService().speakWord(widget.word);
      } else {
        TtsService().speakSubtitle(widget.word);
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
          ? await WordBookService.isWordSaved(word: widget.word, sourceType: widget.sourceType, sourceCode: widget.sourceCode)
          : await WordBookService.isSentenceSaved(text: widget.word, sourceType: widget.sourceType, sourceCode: widget.sourceCode);
      if (!mounted) return;
      setState(() => _saved = saved);
    } catch (_) {}
  }

  Future<void> _fetchDefinition() async {
    try {
      WordDetail detail;

      if (widget.isPaidMode) {
        if (_isSingleWord) {
          detail = await AiService.getDefinition(
            word: widget.word,
            contextSentence: widget.contextSentence,
            sourceType: widget.sourceType,
            sourceCode: widget.sourceCode,
          );
        } else {
          detail = await AiService.translateText(text: widget.word, sourceType: widget.sourceType, sourceCode: widget.sourceCode);
          detail = WordDetail(
            word: widget.word,
            pronounce: detail.pronounce,
            definitions: detail.definitions,
            standaloneExamples: detail.standaloneExamples,
            difficulty: detail.difficulty,
            morphology: detail.morphology,
            mnemonic: detail.mnemonic,
            contextSentence: widget.word,
            sentenceTranslation: detail.sentenceTranslation ?? detail.translation,
            wordMeaningInContext: detail.wordMeaningInContext,
            translation: detail.translation,
            success: detail.success,
            error: detail.error,
            costCny: detail.costCny,
            balanceAfter: detail.balanceAfter,
            source: detail.source,
          );
        }
      } else {
        detail = _isSingleWord ? await _localFallback(widget.word) : await _localSentenceFallback(widget.word);
      }

      if (!mounted) return;

      // 余额不足时弹出充值弹窗
      if (detail.isInsufficientBalance && !_rechargeShown) {
        _rechargeShown = true;
        RechargeDialog.show(context, requiredCny: detail.costCny ?? 0.01, balanceCny: detail.balanceAfter ?? 0, featureName: 'AI释义');
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
      final results = await Future.wait([DictionaryService().lookup(word), IosNativeFeatures.translate(text: word)]);

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
            definitions.add(WordDefinition(partOfSpeech: match.group(1), chineseMeaning: match.group(2)!));
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
          pronounce: PronounceInfo(ukPhonetic: dictEntry?.phonetic),
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
      definitions: [WordDefinition(chineseMeaning: '暂无本地释义，请升级付费版使用 AI 释义')],
      success: true,
      source: 'local',
    );
  }

  Future<WordDetail> _localSentenceFallback(String text) async {
    final translationResult = await IosNativeFeatures.translate(text: text);
    final translated = translationResult.success && translationResult.translatedText.isNotEmpty ? translationResult.translatedText : null;
    return WordDetail(word: text, contextSentence: text, sentenceTranslation: translated, success: true, source: 'local');
  }

  Future<void> _handleToggleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (_saved) {
        final ok = _isSingleWord
            ? await WordBookService.unsaveWord(word: widget.word, sourceType: widget.sourceType, sourceCode: widget.sourceCode)
            : await WordBookService.unsaveSentence(text: widget.word, sourceType: widget.sourceType, sourceCode: widget.sourceCode);
        if (!mounted) return;
        setState(() {
          _saving = false;
          if (ok) _saved = false;
        });
        if (ok) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已取消收藏'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已收藏「${widget.word}」'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 收藏成功后弹出标签设置弹窗（下拉菜单样式）
  Future<void> _showTagSettingDialog({String? wordBookCode, required String contentType}) async {
    await WordTagService.ensureBuiltInDifficultyTagsExist();
    if (!mounted) return;

    String? resolvedCode = wordBookCode;
    if (resolvedCode == null) {
      final rows = await WordBookService.queryWords(WordBookFilter(keyword: widget.word, contentType: contentType));
      final target = contentType == 'word'
          ? rows.where((w) => w.word == widget.word.trim().toLowerCase()).firstOrNull
          : rows.where((w) => w.sourceText == widget.word.trim()).firstOrNull;
      resolvedCode = target?.code;
    }

    if (resolvedCode == null || !mounted) return;
    final allTags = await WordTagService.listTags();
    final existingTags = await WordTagService.listTagsForWord(resolvedCode);
    if (!mounted) return;

    final defaultCode = await WordTagService.ensureDefaultTag();
    if (!mounted) return;

    final selectedCodes = existingTags.map((t) => t.code).whereType<String>().toSet();
    if (selectedCodes.isEmpty && contentType == 'word') {
      final difficulty = _detail?.difficulty ?? DifficultyLevel.unknown;
      if (difficulty != DifficultyLevel.unknown) {
        final match = allTags.where((t) => t.name == difficulty.label && t.code != null).firstOrNull;
        if (match?.code != null) {
          selectedCodes.add(match!.code!);
        }
      }
    }
    if (selectedCodes.isEmpty) {
      selectedCodes.add(defaultCode);
    }

    final newTagController = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    await DialogUtils.show<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final maxHeight = media.size.height * 0.68;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final selectedTagNames = allTags.where((tag) => tag.code != null && selectedCodes.contains(tag.code)).map((tag) => tag.name).toList();

            return AnimatedPadding(
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              duration: const Duration(milliseconds: 180),
              child: Center(
                child: Material(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16.r),
                  child: SizedBox(
                    width: 360.w,
                    height: maxHeight,
                    child: Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.label_outline_rounded, size: 20.sp, color: cs.primary),
                              SizedBox(width: 8.w),
                              Text(
                                '设置标签',
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
                              ),
                              const Spacer(),
                              IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close_rounded)),
                            ],
                          ),
                          if (selectedTagNames.isNotEmpty) ...[
                            SizedBox(height: 8.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 8.h,
                              children: selectedTagNames.map((name) {
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999.r)),
                                  child: Text(
                                    name,
                                    style: TextStyle(fontSize: 12.sp, color: cs.primary, fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          SizedBox(height: 12.h),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(vertical: 6.h),
                                itemCount: allTags.length,
                                itemBuilder: (_, index) {
                                  final tag = allTags[index];
                                  final tagCode = tag.code;
                                  final selected = tagCode != null && selectedCodes.contains(tagCode);
                                  return InkWell(
                                    onTap: tagCode == null
                                        ? null
                                        : () {
                                            setDialogState(() {
                                              if (selected) {
                                                selectedCodes.remove(tagCode);
                                              } else {
                                                selectedCodes.add(tagCode);
                                              }
                                            });
                                          },
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                      child: Row(
                                        children: [
                                          Icon(
                                            selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                            size: 20.sp,
                                            color: selected ? cs.primary : cs.onSurfaceVariant,
                                          ),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            child: Text(
                                              tag.name,
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                                color: selected ? cs.primary : cs.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: newTagController,
                                  style: TextStyle(fontSize: 14.sp, color: cs.onSurface),
                                  decoration: InputDecoration(
                                    hintText: '新标签名称',
                                    hintStyle: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                                    isDense: true,
                                    filled: true,
                                    fillColor: cs.surfaceContainerLow,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r), borderSide: BorderSide.none),
                                  ),
                                  onSubmitted: (_) => _addNewTag(newTagController, allTags, selectedCodes, setDialogState),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              SizedBox(
                                height: 40.h,
                                child: FilledButton.tonal(
                                  onPressed: () => _addNewTag(newTagController, allTags, selectedCodes, setDialogState),
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                  ),
                                  child: Text('添加', style: TextStyle(fontSize: 13.sp)),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          SizedBox(
                            width: double.infinity,
                            height: 44.h,
                            child: FilledButton(
                              onPressed: () async {
                                await WordTagService.replaceTags(resolvedCode!, selectedCodes.toList());
                                if (!mounted) return;
                                Navigator.of(ctx).pop();
                              },
                              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
                              child: Text(
                                '确定',
                                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    newTagController.dispose();
  }

  Future<void> _addNewTag(
    TextEditingController controller,
    List<WordTag> allTags,
    Set<String> selectedCodes,
    void Function(VoidCallback) setModalState,
  ) async {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    final tag = await WordTagService.createTag(name);
    if (tag != null && tag.code != null) {
      setModalState(() {
        allTags.add(tag);
        selectedCodes.add(tag.code!);
      });
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(displayConfigProvider).config;

    // loading 状态时使用占位 WordDetail
    if (_state == _LoadState.loading) {
      return WordDetailPanel(
        data: WordDetail(word: widget.word, pronounce: PronounceInfo(), definitions: [], standaloneExamples: [], success: true, source: 'loading'),
        config: config,
        onSpeak: widget.onSpeak ?? () => (_isSingleWord ? TtsService().speakWord(widget.word) : TtsService().speakSubtitle(widget.word)),
        onClose: () => Navigator.of(context).pop(),
        isLoading: true,
        isSaved: _saved,
        saving: _saving,
        onSaveWord: _isSingleWord ? (widget.onSaveWord != null ? _handleToggleSave : null) : _handleToggleSave,
      );
    }

    if (_detail == null) return const SizedBox.shrink();

    return WordDetailPanel(
      data: _detail!,
      config: config,
      onSpeak: widget.onSpeak ?? () => (_isSingleWord ? TtsService().speakWord(widget.word) : TtsService().speakSubtitle(widget.word)),
      onClose: () => Navigator.of(context).pop(),
      isSaved: _saved,
      saving: _saving,
      onSaveWord: _isSingleWord ? (widget.onSaveWord != null ? _handleToggleSave : null) : _handleToggleSave,
    );
  }
}
