import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/word_book_service.dart';

class WordBookDetailSheet extends StatelessWidget {
  final WordBook word;
  final List<WordTag> tags;
  final VoidCallback onRecognized;
  final VoidCallback onUnrecognized;
  final VoidCallback? onDelete;

  const WordBookDetailSheet({
    super.key,
    required this.word,
    required this.tags,
    required this.onRecognized,
    required this.onUnrecognized,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final definitions = WordBookService.parseDefinitions(word.definitionsJson);
    final accuracy = word.reviewCount == 0 ? 0 : (word.correctCount * 100 ~/ word.reviewCount);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      word.word,
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              if ((word.phoneticUk ?? word.phoneticUs)?.isNotEmpty ?? false)
                Text(
                  '/${word.phoneticUk ?? word.phoneticUs}/',
                  style: TextStyle(fontSize: 15.sp, color: colorScheme.onSurfaceVariant),
                ),
              SizedBox(height: 16.h),
              if (definitions.isNotEmpty) ...[
                _buildSectionTitle(context, '释义'),
                ...definitions.map(
                  (definition) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Text(
                      '${definition.partOfSpeech != null ? '${definition.partOfSpeech}. ' : ''}${definition.meaning}',
                      style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurface),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
              ],
              if (word.contextSentence?.isNotEmpty ?? false) ...[
                _buildSectionTitle(context, '来源上下文'),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Text(
                    word.contextSentence!,
                    style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurface),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
              if ((word.sourceTitle ?? '').isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Text(
                    '来源：${word.sourceTitle}',
                    style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              if (tags.isNotEmpty) ...[
                _buildSectionTitle(context, '标签'),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: tags
                      .map(
                        (tag) => Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                          child: Text(
                            tag.name,
                            style: TextStyle(fontSize: 12.sp, color: colorScheme.primary),
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 12.h),
              ],
              _buildSectionTitle(context, '学习记录'),
              Text(
                '复习 ${word.reviewCount} 次 · 正确率 $accuracy%',
                style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onUnrecognized,
                      child: const Text('不认识'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: FilledButton(
                      onPressed: onRecognized,
                      child: const Text('认识'),
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
