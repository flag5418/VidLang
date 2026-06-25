import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/services/dictionary_service.dart';
import 'package:vidlang/services/ios_native_features.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/widgets/selectable_english_line.dart';
import 'package:vidlang/widgets/word_card.dart';

class CameraTranslatePage extends ConsumerStatefulWidget {
  const CameraTranslatePage({super.key});

  @override
  ConsumerState<CameraTranslatePage> createState() => _CameraTranslatePageState();
}

class _CameraTranslatePageState extends ConsumerState<CameraTranslatePage> {
  bool _loading = true;
  String? _imagePath;
  String _recognizedText = '';
  List<_RecognizedWord> _words = [];
  Map<String, DictEntry?> _dictCache = {};
  String? _selectedWord;
  bool _translating = false;
  String? _fullTranslation;

  @override
  void initState() {
    super.initState();
    _takePhoto();
  }

  Future<void> _takePhoto() async {
    setState(() => _loading = true);
    try {
      final result = await IosNativeFeatures.extractTextFromCamera();
      if (!mounted) return;
      if (!result.success || result.text.trim().isEmpty) {
        setState(() => _loading = false);
        if (result.success && result.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未识别到文本'), duration: Duration(seconds: 2)),
          );
        }
        return;
      }
      _recognizedText = result.text.trim();
      _buildWordList();
      await _batchLookup();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照识别失败: $e'), duration: const Duration(seconds: 3)),
      );
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
      final entry = await DictionaryService().lookup(w);
      _dictCache[w] = entry;
    }
    if (mounted) setState(() {});
  }

  Future<void> _translateFullText() async {
    if (_translating || _recognizedText.isEmpty) return;
    setState(() => _translating = true);
    try {
      final result = await IosNativeFeatures.translate(
        text: _recognizedText,
        sourceLanguage: 'en',
        targetLanguage: 'zh-Hans',
      );
      if (mounted) {
        setState(() {
          _fullTranslation = result.success ? result.translatedText : null;
          _translating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _translating = false);
    }
  }

  void _onWordSelected(List<String> selectedWords) {
    if (selectedWords.isEmpty) return;
    final word = selectedWords.first.toLowerCase();
    setState(() => _selectedWord = word);
  }

  void _showWordDetail(String word) {
    final clean = word.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z']'), '');
    if (clean.isEmpty) return;
    final canSave = WordBookService.isSingleWord(clean);
    WordCard.show(
      context,
      word: clean,
      isPaidMode: false,
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(cs),
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text('拍照识别中...', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                    )
                  : _buildContent(cs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
          ),
          const SizedBox(width: 12),
          Text(
            '拍照翻译',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (_recognizedText.isNotEmpty) ...[
            IconButton(
              onPressed: _translateFullText,
              icon: _translating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.translate_rounded, color: Colors.white, size: 20),
              style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
              tooltip: '全文翻译',
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
              style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
              tooltip: '重新拍照',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_recognizedText.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text('未识别到英文文本', style: TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('重新拍照'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildRecognizedTextOverlay(cs),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_selectedWord != null) _buildWordQuickBar(cs),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRecognizedTextOverlay(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SelectableEnglishLine(
              text: _recognizedText,
              fontSize: 20,
              fontColor: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _fullTranslation!,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, height: 1.5),
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
                  final entry = _dictCache[w.word.toLowerCase()];
                  final trans = entry?.shortTranslation ?? '';
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
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
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
    );
  }

  Widget _buildWordQuickBar(ColorScheme cs) {
    final word = _selectedWord!;
    final entry = _dictCache[word];
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
                    Text(
                      word,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (entry?.phonetic != null && entry!.phonetic!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '/${entry!.phonetic}/',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                    ],
                  ],
                ),
                if (entry?.shortTranslation != null && entry!.shortTranslation!.isNotEmpty)
                  Text(
                    entry!.shortTranslation!,
                    style: TextStyle(color: cs.onSurface, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => TtsService().speakWord(word),
            icon: Icon(Icons.volume_up_rounded, color: cs.primary, size: 22),
            style: IconButton.styleFrom(backgroundColor: cs.primaryContainer.withValues(alpha: 0.3)),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _showWordDetail(word),
            icon: Icon(Icons.expand_more_rounded, color: cs.primary, size: 22),
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
