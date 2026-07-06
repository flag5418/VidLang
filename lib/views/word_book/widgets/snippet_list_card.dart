import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/theme/theme.dart';

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
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode)
                Padding(
                  padding: EdgeInsets.only(right: 10.w, top: 2.h),
                  child: Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20.sp,
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
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        GestureDetector(
                          onTap: () => TtsService().speakSubtitle(sourceText),
                          child: Icon(
                            Icons.volume_up_outlined,
                            size: 20.sp,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (sourceTitle.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Text(
                            _sourceLabel(snippet.sourceType),
                            style: TextStyle(fontSize: 13.sp),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              sourceTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '复习${snippet.reviewCount}',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 6.h,
                        children: tags.map((tag) {
                          return InkWell(
                            onTap: onTagTap,
                            borderRadius: BorderRadius.circular(999.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999.r),
                              ),
                              child: Text(
                                tag.name,
                                style: TextStyle(
                                  fontSize: 13.sp,
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
        return '🎬';
      case 'article':
        return '📄';
      case 'music':
        return '🎵';
      default:
        return '📖';
    }
  }
}
