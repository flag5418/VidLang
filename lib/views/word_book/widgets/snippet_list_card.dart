import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

class SnippetListCard extends StatelessWidget {
  final WordBook snippet;
  final List<WordTag> tags;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onTagTap;

  const SnippetListCard({
    super.key,
    required this.snippet,
    required this.tags,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onTagTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sourceText = snippet.sourceText ?? snippet.word;
    final sourceTitle = snippet.sourceTitle ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Adaptive.r(16)),
        child: Container(
          padding: EdgeInsets.all(Adaptive.r(14)),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Adaptive.r(16)),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode)
                Padding(
                  padding: EdgeInsets.only(right: Adaptive.w(10), top: Adaptive.h(2)),
                  child: Icon(
                    selected ? AppIcons.checkCircle : AppIcons.radioButtonUnchecked,
                    size: Adaptive.sp(20),
                    color: selected ? colorScheme.primary : colorScheme.outline,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            sourceText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: Adaptive.sp(14),
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                        SizedBox(width: Adaptive.w(8)),
                        GestureDetector(
                          onTap: () => TtsService().speakSubtitle(sourceText),
                          child: Icon(
                            AppIcons.volumeUp,
                            size: Adaptive.sp(20),
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (sourceTitle.isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(6)),
                      Row(
                        children: [
                          Text(
                            _sourceLabel(snippet.sourceType),
                            style: TextStyle(fontSize: Adaptive.sp(13)),
                          ),
                          SizedBox(width: Adaptive.w(6)),
                          Expanded(
                            child: Text(
                              sourceTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: Adaptive.sp(12),
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(width: Adaptive.w(8)),
                          Text(
                            '复习${snippet.reviewCount}',
                            style: TextStyle(
                              fontSize: Adaptive.sp(13),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      SizedBox(height: Adaptive.h(8)),
                      Wrap(
                        spacing: Adaptive.w(6),
                        runSpacing: Adaptive.h(6),
                        children: tags.map((tag) {
                          return InkWell(
                            onTap: onTagTap,
                            borderRadius: BorderRadius.circular(Adaptive.r(999)),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: Adaptive.w(8), vertical: Adaptive.h(4)),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(Adaptive.r(999)),
                              ),
                              child: Text(
                                tag.name,
                                style: TextStyle(
                                  fontSize: Adaptive.sp(13),
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
}
