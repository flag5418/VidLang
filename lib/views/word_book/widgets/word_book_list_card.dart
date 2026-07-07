import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

class WordBookListCard extends StatelessWidget {
  final WordBook word;
  final List<WordTag> tags;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onTagTap;

  const WordBookListCard({
    super.key,
    required this.word,
    required this.tags,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final meaning = WordBookService.firstMeaning(word.definitionsJson) ?? '暂无释义';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Adaptive.r(context, 16)),
        child: Container(
          padding: EdgeInsets.all(Adaptive.r(context, 14)),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Adaptive.r(context, 16)),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode)
                Padding(
                  padding: EdgeInsets.only(right: Adaptive.w(context, 10), top: Adaptive.h(context, 2)),
                  child: Icon(
                    selected ? AppIcons.checkCircle : AppIcons.radioButtonUnchecked,
                    size: Adaptive.sp(context, 20),
                    color: selected ? colorScheme.primary : colorScheme.outline,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            word.word,
                            style: TextStyle(
                              fontSize: Adaptive.sp(context, 16),
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          _sourceLabel(word.sourceType),
                          style: TextStyle(fontSize: Adaptive.sp(context, 15)),
                        ),
                        SizedBox(width: Adaptive.w(context, 8)),
                        Text(
                          '复习${word.reviewCount}',
                          style: TextStyle(
                            fontSize: Adaptive.sp(context, 12),
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if ((word.phoneticUk ?? word.phoneticUs)?.isNotEmpty ?? false) ...[
                      SizedBox(height: Adaptive.h(context, 4)),
                      Text(
                        '/${word.phoneticUk ?? word.phoneticUs}/',
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 12),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(height: Adaptive.h(context, 6)),
                    Text(
                      meaning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Adaptive.sp(context, 13),
                        color: colorScheme.onSurface,
                      ),
                    ),
                    // ── 来源上下文 ──
                    if (word.contextSentence != null && word.contextSentence!.isNotEmpty) ...[                      SizedBox(height: Adaptive.h(context, 6)),
                      Text(
                        word.contextSentence!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Adaptive.sp(context, 12),
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    // ── 来源信息 ──
                    if (word.sourceTitle != null && word.sourceTitle!.isNotEmpty) ...[                      SizedBox(height: Adaptive.h(context, 4)),
                      Row(
                        children: [
                          Icon(
                            _sourceIcon(word.sourceType),
                            size: Adaptive.sp(context, 14),
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          SizedBox(width: Adaptive.w(context, 4)),
                          Expanded(
                            child: Text(
                              word.sourceTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: Adaptive.sp(context, 13),
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(context, 8)),
                      Wrap(
                        spacing: Adaptive.w(context, 6),
                        runSpacing: Adaptive.h(context, 6),
                        children: tags.map((tag) {
                          return InkWell(
                            onTap: onTagTap,
                            borderRadius: BorderRadius.circular(Adaptive.r(context, 999)),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 8), vertical: Adaptive.h(context, 4)),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(Adaptive.r(context, 999)),
                              ),
                              child: Text(
                                tag.name,
                                style: TextStyle(
                                  fontSize: Adaptive.sp(context, 13),
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel(String type) {
    switch (type) {
      case 'video':
        return '视频';
      case 'article':
        return '文章';
      case 'music':
        return '音频';
      default:
        return '资源';
    }
  }

  IconData _sourceIcon(String type) {
    switch (type) {
      case 'video':
        return AppIcons.movie;
      case 'article':
        return AppIcons.article;
      case 'music':
        return AppIcons.musicNote;
      default:
        return AppIcons.book;
    }
  }
}
