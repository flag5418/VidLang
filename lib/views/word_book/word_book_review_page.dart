import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/widgets/app_dialogs.dart';

class WordBookReviewPage extends StatefulWidget {
  final List<WordBook> words;

  const WordBookReviewPage({super.key, required this.words});

  @override
  State<WordBookReviewPage> createState() => _WordBookReviewPageState();
}

class _WordBookReviewPageState extends State<WordBookReviewPage>
    with SingleTickerProviderStateMixin {
  late List<WordBook> _remaining;
  final int _currentIndex = 0;
  bool _isFlipped = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  WordBook get _currentWord => _remaining[_currentIndex];

  @override
  void initState() {
    super.initState();
    _remaining = List.of(widget.words);
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _markRecognized() async {
    await WordBookService.updateMastery(
      wordBookCode: _currentWord.code!,
      recognized: true,
    );
    // Update local state
    _currentWord.masteryLevel = 'mastered';
    _currentWord.masteredAt = DateTime.now();
    _nextWord();
  }

  void _markUnrecognized() {
    _nextWord();
  }

  void _nextWord() {
    setState(() {
      _remaining.removeAt(_currentIndex);
      if (_remaining.isEmpty) {
        _showComplete();
        return;
      }
      _isFlipped = false;
      _flipController.value = 0;
      // _currentIndex stays 0 since we just removed it
    });
  }

  void _showComplete() {
    final total = widget.words.length;
    AppConfirmDialog.show(
      context,
      title: '复习完成',
      content: '已复习 $total 词',
      confirmText: '返回',
      onConfirm: () {
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: Text(
          '复习中 · 剩余 ${_remaining.length} 词',
          style: TextStyle(
            fontSize: Adaptive.sp(context, 16),
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
          padding: EdgeInsets.fromLTRB(
            Adaptive.w(context, 24),
            Adaptive.h(context, 16),
            Adaptive.w(context, 24),
            Adaptive.h(context, 16),
          ),
          child: Column(
            children: [
              Expanded(child: Center(child: _buildCard(cs))),
              SizedBox(height: Adaptive.h(context, 24)),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: Adaptive.h(context, 48),
                      child: OutlinedButton(
                        onPressed: _isFlipped ? _markUnrecognized : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Adaptive.r(context, 24),
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '不认识',
                              style: TextStyle(
                                fontSize: Adaptive.sp(context, 14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '留在生词本',
                              style: TextStyle(
                                fontSize: Adaptive.sp(context, 13),
                                color: cs.error.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: Adaptive.w(context, 16)),
                  Expanded(
                    child: SizedBox(
                      height: Adaptive.h(context, 48),
                      child: FilledButton(
                        onPressed: _isFlipped ? _markRecognized : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              Adaptive.r(context, 24),
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '认识',
                              style: TextStyle(
                                fontSize: Adaptive.sp(context, 14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '移入已掌握',
                              style: TextStyle(
                                fontSize: Adaptive.sp(context, 13),
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

  Widget _buildCard(ColorScheme cs) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * 3.1415926;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: angle < 1.5708
              ? _buildFront(cs)
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(3.1415926),
                  child: _buildBack(cs),
                ),
        );
      },
    );
  }

  Widget _buildFront(ColorScheme cs) {
    return GestureDetector(
      onTap: _flip,
      child: Container(
        width: Adaptive.w(context, 311),
        constraints: BoxConstraints(minHeight: Adaptive.h(context, 360)),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(Adaptive.r(context, 20)),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _currentWord.word,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: Adaptive.sp(context, 28),
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: Adaptive.h(context, 8)),
            if ((_currentWord.phoneticUk ?? _currentWord.phoneticUs)
                    ?.isNotEmpty ??
                false)
              Text(
                '/${_currentWord.phoneticUk ?? _currentWord.phoneticUs}/',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 16),
                  color: cs.onSurfaceVariant,
                ),
              ),
            SizedBox(height: Adaptive.h(context, 16)),
            Icon(
              AppIcons.volumeUp,
              size: Adaptive.sp(context, 32),
              color: cs.primary,
            ),
            SizedBox(height: Adaptive.h(context, 24)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Adaptive.w(context, 24),
                vertical: Adaptive.h(context, 12),
              ),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(Adaptive.r(context, 12)),
              ),
              child: Text(
                '点击显示释义',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 14),
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBack(ColorScheme cs) {
    final definitions = WordBookService.parseDefinitions(
      _currentWord.definitionsJson,
    );
    final morphology = WordBookService.parseMorphology(
      _currentWord.morphologyJson,
    );

    return Container(
      width: Adaptive.w(context, 311),
      constraints: BoxConstraints(minHeight: Adaptive.h(context, 360)),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Adaptive.r(context, 20)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(Adaptive.r(context, 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                _currentWord.word,
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 22),
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            if ((_currentWord.phoneticUk ?? _currentWord.phoneticUs)
                    ?.isNotEmpty ??
                false) ...[
              SizedBox(height: Adaptive.h(context, 4)),
              Center(
                child: Text(
                  '/${_currentWord.phoneticUk ?? _currentWord.phoneticUs}/',
                  style: TextStyle(
                    fontSize: Adaptive.sp(context, 14),
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (definitions.isNotEmpty) ...[
              SizedBox(height: Adaptive.h(context, 16)),
              ...definitions.map(
                (d) => Padding(
                  padding: EdgeInsets.only(bottom: Adaptive.h(context, 6)),
                  child: Text(
                    '${d.partOfSpeech != null ? '${d.partOfSpeech}. ' : ''}${d.meaning}',
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 14),
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ],
            if (definitions.any(
              (d) => d.example != null && d.example!.isNotEmpty,
            )) ...[
              SizedBox(height: Adaptive.h(context, 12)),
              Text(
                '例句',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 13),
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              SizedBox(height: Adaptive.h(context, 4)),
              ...definitions
                  .where((d) => d.example != null && d.example!.isNotEmpty)
                  .map(
                    (d) => Padding(
                      padding: EdgeInsets.only(bottom: Adaptive.h(context, 4)),
                      child: Text(
                        '• ${d.example}',
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 13),
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
            ],
            if (morphology.isNotEmpty) ...[
              SizedBox(height: Adaptive.h(context, 12)),
              Text(
                '词形变化',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 13),
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              SizedBox(height: Adaptive.h(context, 4)),
              ...morphology.entries.map(
                (e) => Padding(
                  padding: EdgeInsets.only(bottom: Adaptive.h(context, 4)),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: TextStyle(
                      fontSize: Adaptive.sp(context, 13),
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ],
            if ((_currentWord.mnemonic ?? '').isNotEmpty) ...[
              SizedBox(height: Adaptive.h(context, 12)),
              Text(
                '助记',
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 13),
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              SizedBox(height: Adaptive.h(context, 4)),
              Text(
                _currentWord.mnemonic!,
                style: TextStyle(
                  fontSize: Adaptive.sp(context, 13),
                  color: cs.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
