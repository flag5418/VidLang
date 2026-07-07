import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/ios_native_features.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/unified_translation_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/widgets/selectable_english_line.dart';
import 'package:vidlang/widgets/word_card.dart';
import 'package:vidlang/theme/theme.dart';

class CameraTranslatePage extends ConsumerStatefulWidget {
  const CameraTranslatePage({super.key});

  @override
  ConsumerState<CameraTranslatePage> createState() => _CameraTranslatePageState();
}

class _CameraTranslatePageState extends ConsumerState<CameraTranslatePage> {
  bool _loading = true;
  String _recognizedText = '';
  List<_RecognizedWord> _words = [];
  final Map<String, String?> _dictCache = {};
  String? _selectedWord;
  String? _fullTranslation;

  @override
  void initState() {
    super.initState();
    _takePhoto();
  }

  Future<void> _takePhoto() async {
    setState(() => _loading = true);
    try {
      final result = await IosNativeFeatures.openCameraTranslatePage();
      if (!mounted) return;
      if (!result.success || result.text.trim().isEmpty) {
        if (result.success && result.text.trim().isEmpty) {
          Navigator.pop(context);
          return;
        }
        if (result.error == 'User cancelled') {
          Navigator.pop(context);
          return;
        }
        setState(() => _loading = false);
        return;
      }
      _recognizedText = result.text.trim();
      _buildWordList();
      await _batchLookup();
      await _autoTranslate();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _buildWordList() {
    final wordPattern = RegExp(r"([a-zA-Z']+)");
    final matches = wordPattern.allMatches(_recognizedText);
    _words = matches.map((m) {
      final word = m.group(0)!;
      return _RecognizedWord(word: word, start: m.start, end: m.end);
    }).toList();
  }

  Future<void> _batchLookup() async {
    final uniqueWords = _words.map((w) => w.word.toLowerCase()).toSet().toList();
    for (final w in uniqueWords) {
      if (_dictCache.containsKey(w)) continue;
      // 拍照翻译页面默认使用免费模式（本地翻译）
      final detail = await UnifiedTranslationService.instance.translate(
        text: w,
        mode: SubscriptionMode.free,
      );
      _dictCache[w] = detail.success ? detail.translation ?? '' : null;
    }
  }

  Future<void> _autoTranslate() async {
    if (_recognizedText.isEmpty) return;
    try {
      final result = await IosNativeFeatures.translate(
        text: _recognizedText,
        sourceLanguage: 'en',
        targetLanguage: 'zh-Hans',
      );
      if (result.success && mounted) {
        _fullTranslation = result.translatedText;
      }
    } catch (_) {}
  }

  void _onWordSelected(List<String> selectedWords) {
    if (selectedWords.isEmpty) return;
    final word = selectedWords.first.toLowerCase();
    setState(() => _selectedWord = word);
  }

  void _showWordDetail(String word) {
    final clean = word.toLowerCase().replaceAll(RegExp(r"[^a-zA-Z']"), '');
    if (clean.isEmpty) return;
    final canSave = WordBookService.isSingleWord(clean);
    bool isPaidMode = false;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      isPaidMode = container.read(subscriptionProvider).mode == SubscriptionMode.premium;
    } catch (_) {}
    WordCard.show(
      context,
      word: clean,
      isPaidMode: isPaidMode,
      onSpeak: () => TtsService().speakWord(clean),
      onSaveWord: canSave
          ? ({
              required String word,
              String? contextSentence,
              required String sourceType,
              required String sourceCode,
              String? sourceTitle,
            }) async {
              final result = await WordBookService.saveWord(
                word: word,
                sourceType: 'camera',
                sourceCode: '',
                contextSentence: contextSentence,
              );
              return result != null;
            }
          : null,
      sourceType: 'camera',
      sourceCode: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(cs),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.onSurface),
                      const SizedBox(height: 16),
                      Text('拍照识别中...', style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.54), fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(cs),
            Expanded(child: _buildContent(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs) {
    final col = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(AppIcons.arrowBackIosNew, color: col.textPrimary, size: 20),
            style: IconButton.styleFrom(backgroundColor: col.textPrimary.withValues(alpha: 0.1)),
          ),
          const SizedBox(width: 12),
          Text(
            '拍照翻译',
            style: TextStyle(color: col.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: _takePhoto,
            icon: Icon(AppIcons.cameraAlt, color: col.textPrimary, size: 20),
            style: IconButton.styleFrom(backgroundColor: col.textPrimary.withValues(alpha: 0.1)),
            tooltip: '重新拍照',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            decoration: BoxDecoration(
              color: AppColors.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SelectableEnglishLine(
                      text: _recognizedText,
                      fontSize: 20,
                      fontColor: AppColors.onSurface,
                      selectedBgColor: cs.primary.withValues(alpha: 0.7),
                      onSelectionChanged: (words) => _onWordSelected(words),
                      onTapWord: (word) => _showWordDetail(word),
                    ),
                    if (_fullTranslation != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.onSurface.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _fullTranslation!,
                          style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.8), fontSize: 16, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    if (_words.isNotEmpty && _fullTranslation == null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: _words.map((w) {
                          final trans = _dictCache[w.word.toLowerCase()] ?? '';
                          if (trans.isEmpty) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  w.word,
                                  style: TextStyle(color: cs.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  ' $trans',
                                  style: TextStyle(color: AppColors.onSurface.withValues(alpha: 0.7), fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_selectedWord != null) _buildWordQuickBar(cs),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildWordQuickBar(ColorScheme cs) {
    final word = _selectedWord!;
    final translation = _dictCache[word];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(word, style: TextStyle(color: cs.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (translation != null && translation.isNotEmpty)
                  Text(
                    translation,
                    style: TextStyle(color: cs.onSurface, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => TtsService().speakWord(word),
            icon: Icon(AppIcons.volumeUp, color: cs.primary, size: 22),
            style: IconButton.styleFrom(backgroundColor: cs.primaryContainer.withValues(alpha: 0.3)),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _showWordDetail(word),
            icon: Icon(AppIcons.expandMore, color: cs.primary, size: 22),
            style: IconButton.styleFrom(backgroundColor: cs.primaryContainer.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}

class _RecognizedWord {
  final String word;
  final int start;
  final int end;

  _RecognizedWord({required this.word, required this.start, required this.end});
}
