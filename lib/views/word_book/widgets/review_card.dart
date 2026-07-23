import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 复习卡片（翻转动画）
/// 
/// 正面：单词 + 音标 + 发音按钮
/// 背面：释义 + 例句 + 词形变化 + 助记
class ReviewCard extends StatefulWidget {
  final WordBook word;
  final bool isFlipped;

  const ReviewCard({
    super.key,
    required this.word,
    required this.isFlipped,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isFlipped) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(ReviewCard old) {
    super.didUpdateWidget(old);
    if (widget.isFlipped != old.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (widget.isFlipped) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {});
  }

  void _speakWord() {
    TtsService().speakWord(widget.word.word);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _flip,
      child: SizedBox(
        width: Adaptive.w(311),
        height: Adaptive.h(360),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final currentAngle = _animation.value * pi;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(currentAngle),
              child: currentAngle < pi / 2
                  ? _buildFront(cs)
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _buildBack(cs),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFront(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Adaptive.r(20)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: Adaptive.w(16),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.word.word,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Adaptive.sp(28),
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: Adaptive.h(8)),
          if ((widget.word.phoneticUk ?? widget.word.phoneticUs)?.isNotEmpty ?? false)
            Text(
              '/${widget.word.phoneticUk ?? widget.word.phoneticUs}/',
              style: TextStyle(
                fontSize: Adaptive.sp(16),
                color: cs.onSurfaceVariant,
              ),
            ),
          SizedBox(height: Adaptive.h(16)),
          GestureDetector(
            onTap: _speakWord,
            child: Icon(
              AppIcons.volumeUp,
              size: Adaptive.sp(32),
              color: cs.primary,
            ),
          ),
          SizedBox(height: Adaptive.h(24)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Adaptive.w(24),
              vertical: Adaptive.h(12),
            ),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Adaptive.r(12)),
            ),
            child: Text(
              '点击显示释义',
              style: TextStyle(
                fontSize: Adaptive.sp(14),
                color: cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(ColorScheme cs) {
    final definitions = WordBookService.parseDefinitions(widget.word.definitionsJson);
    final morphology = WordBookService.parseMorphology(widget.word.morphologyJson);

    return Container(
      padding: EdgeInsets.all(Adaptive.r(20)),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(Adaptive.r(20)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: Adaptive.w(16),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                widget.word.word,
                style: TextStyle(
                  fontSize: Adaptive.sp(22),
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            if ((widget.word.phoneticUk ?? widget.word.phoneticUs)?.isNotEmpty ?? false) ...[
              SizedBox(height: Adaptive.h(4)),
              Center(
                child: Text(
                  '/${widget.word.phoneticUk ?? widget.word.phoneticUs}/',
                  style: TextStyle(
                    fontSize: Adaptive.sp(14),
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (definitions.isNotEmpty) ...[
              SizedBox(height: Adaptive.h(16)),
              ...definitions.map(
                (d) => Padding(
                  padding: EdgeInsets.only(bottom: Adaptive.h(6)),
                  child: Text(
                    '${d.partOfSpeech != null ? '${d.partOfSpeech}. ' : ''}${d.meaning}',
                    style: TextStyle(
                      fontSize: Adaptive.sp(14),
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ],
            if (definitions.any((d) => d.example != null && d.example!.isNotEmpty)) ...[
              SizedBox(height: Adaptive.h(12)),
              Text(
                '例句',
                style: TextStyle(
                  fontSize: Adaptive.sp(13),
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              SizedBox(height: Adaptive.h(4)),
              ...definitions
                  .where((d) => d.example != null && d.example!.isNotEmpty)
                  .map(
                    (d) => Padding(
                      padding: EdgeInsets.only(bottom: Adaptive.h(4)),
                      child: Text(
                        '• ${d.example}',
                        style: TextStyle(
                          fontSize: Adaptive.sp(13),
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ),
            ],
            if (morphology.isNotEmpty) ...[
              SizedBox(height: Adaptive.h(12)),
              Text(
                '词形变化',
                style: TextStyle(
                  fontSize: Adaptive.sp(13),
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              SizedBox(height: Adaptive.h(4)),
              ...morphology.entries.map(
                (e) => Padding(
                  padding: EdgeInsets.only(bottom: Adaptive.h(4)),
                  child: Text(
                    '${_morphologyLabel(e.key)}: ${e.value}',
                    style: TextStyle(
                      fontSize: Adaptive.sp(13),
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ],
            if ((widget.word.mnemonic ?? '').isNotEmpty) ...[
              SizedBox(height: Adaptive.h(12)),
              Text(
                '助记',
                style: TextStyle(
                  fontSize: Adaptive.sp(13),
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              SizedBox(height: Adaptive.h(4)),
              Text(
                widget.word.mnemonic!,
                style: TextStyle(
                  fontSize: Adaptive.sp(13),
                  color: cs.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _morphologyLabel(String key) {
    switch (key) {
      case 'comparative': return '比较级';
      case 'superlative': return '最高级';
      case 'plural': return '复数';
      case 'pastTense': case 'past_tense': return '过去式';
      case 'pastParticiple': case 'past_participle': return '过去分词';
      case 'presentParticiple': case 'present_participle': return '现在分词';
      case 'thirdPerson': case 'third_person': return '第三人称单数';
      default: return key;
    }
  }
}
