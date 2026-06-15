import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/utils/dialog_utils.dart';

class WordBookReviewPage extends StatefulWidget {
  final List<WordBook> words;

  const WordBookReviewPage({super.key, required this.words});

  @override
  State<WordBookReviewPage> createState() => _WordBookReviewPageState();
}

class _WordBookReviewPageState extends State<WordBookReviewPage>
    with SingleTickerProviderStateMixin {
  late List<WordBook> _remaining;
  int _currentIndex = 0;
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
    DialogUtils.show(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text('复习完成',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: cs.onSurface)),
          content: Text('已复习 $total 词',
              style: TextStyle(fontSize: 16.sp, color: cs.onSurfaceVariant)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text('返回'),
            ),
          ],
        );
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
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: cs.onSurfaceVariant),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 16.h),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _buildCard(cs),
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: OutlinedButton(
                        onPressed: _isFlipped ? _markUnrecognized : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('不认识', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                            Text('留在生词本',
                                style: TextStyle(fontSize: 11.sp, color: cs.error.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: FilledButton(
                        onPressed: _isFlipped ? _markRecognized : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('认识', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                            Text('移入已掌握',
                                style: TextStyle(fontSize: 11.sp, color: cs.onPrimary.withValues(alpha: 0.7))),
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
        width: 311.w,
        constraints: BoxConstraints(minHeight: 360.h),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20.r),
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
                fontSize: 28.sp,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            if ((_currentWord.phoneticUk ?? _currentWord.phoneticUs)?.isNotEmpty ?? false)
              Text(
                '/${_currentWord.phoneticUk ?? _currentWord.phoneticUs}/',
                style: TextStyle(fontSize: 16.sp, color: cs.onSurfaceVariant),
              ),
            SizedBox(height: 16.h),
            Icon(Icons.volume_up_rounded, size: 32.sp, color: cs.primary),
            SizedBox(height: 24.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                '点击显示释义',
                style: TextStyle(fontSize: 14.sp, color: cs.primary, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBack(ColorScheme cs) {
    final definitions = WordBookService.parseDefinitions(_currentWord.definitionsJson);
    final morphology = WordBookService.parseMorphology(_currentWord.morphologyJson);

    return Container(
      width: 311.w,
      constraints: BoxConstraints(minHeight: 360.h),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                _currentWord.word,
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: cs.onSurface),
              ),
            ),
            if ((_currentWord.phoneticUk ?? _currentWord.phoneticUs)?.isNotEmpty ?? false) ...[
              SizedBox(height: 4.h),
              Center(
                child: Text(
                  '/${_currentWord.phoneticUk ?? _currentWord.phoneticUs}/',
                  style: TextStyle(fontSize: 14.sp, color: cs.onSurfaceVariant),
                ),
              ),
            ],
            if (definitions.isNotEmpty) ...[
              SizedBox(height: 16.h),
              ...definitions.map((d) => Padding(
                    padding: EdgeInsets.only(bottom: 6.h),
                    child: Text(
                      '${d.partOfSpeech != null ? '${d.partOfSpeech}. ' : ''}${d.meaning}',
                      style: TextStyle(fontSize: 14.sp, color: cs.onSurface),
                    ),
                  )),
            ],
            if (definitions.any((d) => d.example != null && d.example!.isNotEmpty)) ...[
              SizedBox(height: 12.h),
              Text('例句',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.primary)),
              SizedBox(height: 4.h),
              ...definitions
                  .where((d) => d.example != null && d.example!.isNotEmpty)
                  .map((d) => Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Text('• ${d.example}',
                            style: TextStyle(fontSize: 13.sp, color: cs.onSurface)),
                      )),
            ],
            if (morphology.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Text('词形变化',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.primary)),
              SizedBox(height: 4.h),
              ...morphology.entries.map((e) => Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text('${e.key}: ${e.value}',
                        style: TextStyle(fontSize: 13.sp, color: cs.onSurface)),
                  )),
            ],
            if ((_currentWord.mnemonic ?? '').isNotEmpty) ...[
              SizedBox(height: 12.h),
              Text('助记',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: cs.primary)),
              SizedBox(height: 4.h),
              Text(_currentWord.mnemonic!,
                  style: TextStyle(fontSize: 13.sp, color: cs.onSurface)),
            ],
          ],
        ),
      ),
    );
  }
}
