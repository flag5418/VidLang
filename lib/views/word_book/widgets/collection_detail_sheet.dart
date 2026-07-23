import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/services/word_book/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

class CollectionDetailSheet extends StatelessWidget {
  final WordBook word;
  final VoidCallback onClose;

  const CollectionDetailSheet({super.key, required this.word, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final definitions = WordBookService.parseDefinitions(word.definitionsJson);
    final morphology = WordBookService.parseMorphology(word.morphologyJson);
    final accuracy = word.reviewCount == 0 ? 0 : (word.correctCount * 100 ~/ word.reviewCount);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxHeight: Adaptive.h(480)),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(Adaptive.r(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: Adaptive.w(20),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Adaptive.w(16), vertical: Adaptive.h(14)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '详情',
                      style: TextStyle(
                        fontSize: Adaptive.sp(12),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: Adaptive.w(24),
                      height: Adaptive.h(24),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(Adaptive.r(12)),
                      ),
                      child: Icon(Icons.close_rounded, size: Adaptive.icon(12), color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(Adaptive.w(20)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            word.word,
                            style: TextStyle(fontSize: Adaptive.sp(24), fontWeight: FontWeight.w700, color: cs.onSurface),
                          ),
                        ),
                        SizedBox(width: Adaptive.w(8)),
                        GestureDetector(
                          onTap: () => TtsService().speakWord(word.word),
                          child: Icon(AppIcons.volumeUp, size: Adaptive.sp(18), color: cs.primary),
                        ),
                      ],
                    ),
                    if ((word.phoneticUk ?? word.phoneticUs)?.isNotEmpty ?? false)
                      Padding(
                        padding: EdgeInsets.only(top: Adaptive.h(4)),
                        child: Text(
                          '/${word.phoneticUk ?? word.phoneticUs}/',
                          style: TextStyle(fontSize: Adaptive.sp(15), color: cs.onSurfaceVariant),
                        ),
                      ),
                    if (definitions.isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(16)),
                      Text('释义', style: TextStyle(fontSize: Adaptive.sp(14), fontWeight: FontWeight.w700, color: cs.onSurface)),
                      ...definitions.map((d) => Padding(
                        padding: EdgeInsets.only(bottom: Adaptive.h(6)),
                        child: Text('${d.partOfSpeech != null ? '${d.partOfSpeech}. ' : ''}${d.meaning}', style: TextStyle(fontSize: Adaptive.sp(14), color: cs.onSurface)),
                      )),
                    ],
                    if (definitions.any((d) => d.example != null && d.example!.isNotEmpty)) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('例句', style: TextStyle(fontSize: Adaptive.sp(13), fontWeight: FontWeight.w600, color: cs.primary)),
                      ...definitions.where((d) => d.example != null && d.example!.isNotEmpty).map(
                        (d) => Padding(
                          padding: EdgeInsets.only(bottom: Adaptive.h(4)),
                          child: Text('• ${d.example}', style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurfaceVariant)),
                        ),
                      ),
                    ],
                    if (morphology.isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('词形变化', style: TextStyle(fontSize: Adaptive.sp(13), fontWeight: FontWeight.w600, color: cs.primary)),
                      ...morphology.entries.map((e) => Padding(
                        padding: EdgeInsets.only(bottom: Adaptive.h(4)),
                        child: Text('${_morphologyLabel(e.key)}: ${e.value}', style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurface)),
                      )),
                    ],
                    if (word.mnemonic?.isNotEmpty ?? false) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('助记', style: TextStyle(fontSize: Adaptive.sp(13), fontWeight: FontWeight.w600, color: cs.primary)),
                      Text(word.mnemonic!, style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurface)),
                    ],
                    if ((word.sourceTitle ?? '').isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('来源', style: TextStyle(fontSize: Adaptive.sp(14), fontWeight: FontWeight.w700, color: cs.onSurface)),
                      Container(
                        padding: EdgeInsets.all(Adaptive.w(12)),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(Adaptive.r(10)),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(_sourceIcon(word.sourceType), size: Adaptive.sp(16), color: cs.primary),
                            SizedBox(width: Adaptive.w(8)),
                            Expanded(
                              child: Text(
                                '${_sourceLabel(word.sourceType)} · ${word.sourceTitle}',
                                style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (word.contextSentence?.isNotEmpty ?? false) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('上下文', style: TextStyle(fontSize: Adaptive.sp(14), fontWeight: FontWeight.w700, color: cs.onSurface)),
                      Text(word.contextSentence!, style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
                    ],
                    if (word.reviewCount > 0) ...[
                      SizedBox(height: Adaptive.h(12)),
                      Text('学习记录', style: TextStyle(fontSize: Adaptive.sp(14), fontWeight: FontWeight.w700, color: cs.onSurface)),
                      Text('复习 ${word.reviewCount} 次 · 正确率 $accuracy%', style: TextStyle(fontSize: Adaptive.sp(13), color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ),
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

  String _sourceLabel(String type) {
    switch (type) {
      case 'video': return '视频';
      case 'article': return '文章';
      case 'music': return '音频';
      default: return '资源';
    }
  }

  IconData _sourceIcon(String type) {
    switch (type) {
      case 'video': return AppIcons.movie;
      case 'article': return AppIcons.article;
      case 'music': return AppIcons.musicNote;
      default: return AppIcons.book;
    }
  }
}
