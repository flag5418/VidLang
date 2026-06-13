import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/word_book_service.dart';

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
                      children: [
                        Expanded(
                          child: Text(
                            word.word,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          _sourceLabel(word.sourceType),
                          style: TextStyle(fontSize: 15.sp),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '复习${word.reviewCount}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if ((word.phoneticUk ?? word.phoneticUs)?.isNotEmpty ?? false) ...[
                      SizedBox(height: 4.h),
                      Text(
                        '/${word.phoneticUk ?? word.phoneticUs}/',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    SizedBox(height: 6.h),
                    Text(
                      meaning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: colorScheme.onSurface,
                      ),
                    ),
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
                                  fontSize: 11.sp,
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
