import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/views/word_book/widgets/review_card.dart';
import 'package:vidlang/components/dialogs/app_dialogs.dart';

class WordBookReviewPage extends StatefulWidget {
  final List<WordBook> words;

  const WordBookReviewPage({super.key, required this.words});

  @override
  State<WordBookReviewPage> createState() => _WordBookReviewPageState();
}

class _WordBookReviewPageState extends State<WordBookReviewPage> {
  late List<WordBook> _remaining;
  bool _isFlipped = false;
  int _correctCount = 0;
  int _totalCount = 0;

  WordBook get _currentWord => _remaining.first;

  @override
  void initState() {
    super.initState();
    _remaining = List.of(widget.words);
    _totalCount = widget.words.length;
  }

  void _nextWord({required bool recognized}) async {
    if (recognized) _correctCount++;
    await WordBookService.updateMastery(
      wordBookCode: _currentWord.code!,
      recognized: recognized,
    );
    setState(() {
      _remaining.removeAt(0);
      _isFlipped = false;
    });
    if (_remaining.isEmpty) {
      _showComplete();
    }
  }

  void _showComplete() {
    AppConfirmDialog.show(
      context,
      title: '复习完成',
      content:
          '已复习 ${widget.words.length} 词，正确 $_correctCount 题，正确率 ${_totalCount > 0 ? (_correctCount * 100 / _totalCount).toStringAsFixed(1) : '0'}%',
      confirmText: '返回',
      onConfirm: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = _totalCount > 0 ? _remaining.length / _totalCount : 0.0;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text(
          '复习中 · 剩余 ${_remaining.length} 词',
          style: TextStyle(
            fontSize: Adaptive.sp(16),
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(AppIcons.close, color: cs.onSurfaceVariant),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Adaptive.w(24)),
          child: Column(
            children: [
              // 进度条
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(Adaptive.r(2)),
                backgroundColor: cs.outline.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
              SizedBox(height: Adaptive.h(16)),
              Expanded(
                child: Center(
                  child: ReviewCard(word: _currentWord, isFlipped: _isFlipped),
                ),
              ),
              SizedBox(height: Adaptive.h(24)),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: Adaptive.h(48),
                      child: OutlinedButton(
                        onPressed: _isFlipped
                            ? () => _nextWord(recognized: false)
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Adaptive.r(24)),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '不认识',
                              style: TextStyle(
                                fontSize: Adaptive.sp(14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '留在生词本',
                              style: TextStyle(
                                fontSize: Adaptive.sp(13),
                                color: cs.error.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: Adaptive.w(16)),
                  Expanded(
                    child: SizedBox(
                      height: Adaptive.h(48),
                      child: FilledButton(
                        onPressed: _isFlipped
                            ? () => _nextWord(recognized: true)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Adaptive.r(24)),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '认识',
                              style: TextStyle(
                                fontSize: Adaptive.sp(14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '移入已掌握',
                              style: TextStyle(
                                fontSize: Adaptive.sp(13),
                                color: cs.onPrimary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
