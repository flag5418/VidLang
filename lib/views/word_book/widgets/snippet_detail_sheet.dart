import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/tts_service.dart';
import 'package:vidlang/theme/theme.dart';

class SnippetDetailSheet extends StatefulWidget {
  final WordBook snippet;
  final List<WordTag> tags;
  final VoidCallback onRecognized;
  final VoidCallback onUnrecognized;
  final VoidCallback? onDelete;
  final void Function(String note)? onNoteChanged;
  final VoidCallback? onEditTags;

  const SnippetDetailSheet({
    super.key,
    required this.snippet,
    required this.tags,
    required this.onRecognized,
    required this.onUnrecognized,
    this.onDelete,
    this.onNoteChanged,
    this.onEditTags,
  });

  @override
  State<SnippetDetailSheet> createState() => _SnippetDetailSheetState();
}

class _SnippetDetailSheetState extends State<SnippetDetailSheet> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.snippet.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final snippet = widget.snippet;

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
                      '句子详情',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final text = (snippet.sourceText ?? '').isNotEmpty
                          ? snippet.sourceText!
                          : snippet.word;
                      TtsService().speakSubtitle(text);
                    },
                    icon: const Icon(Icons.volume_up_outlined),
                    tooltip: '朗读',
                  ),
                  if (widget.onDelete != null)
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              SizedBox(height: 12.h),
              // 句子原文
              if ((snippet.sourceText ?? '').isNotEmpty) ...[
                _buildSectionTitle(context, '原文'),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Text(
                    snippet.sourceText!,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
              // 翻译
              if ((snippet.sourceTranslation ?? '').isNotEmpty) ...[
                _buildSectionTitle(context, '翻译'),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Text(
                    snippet.sourceTranslation!,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
              ],
              // 来源
              if ((snippet.sourceTitle ?? '').isNotEmpty) ...[
                _buildSectionTitle(context, '来源'),
                Text(
                  snippet.sourceTitle!,
                  style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
                ),
                SizedBox(height: 8.h),
              ],
              // 收藏时间
              if (snippet.createdAt != null) ...[
                Text(
                  '收藏于 ${snippet.createdAt!.year}-${snippet.createdAt!.month.toString().padLeft(2, '0')}-${snippet.createdAt!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12.sp, color: colorScheme.outline),
                ),
                SizedBox(height: 8.h),
              ],
              _buildDivider(context),
              // 标签
              _buildSectionTitle(context, '标签'),
              if (widget.tags.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: widget.tags
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
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onEditTags,
                  child: const Text('编辑标签'),
                ),
              ),
              SizedBox(height: 12.h),
              _buildDivider(context),
              // 备注
              _buildSectionTitle(context, '备注'),
              TextField(
                controller: _noteController,
                maxLines: 3,
                onChanged: (value) => widget.onNoteChanged?.call(value),
                decoration: InputDecoration(
                  hintText: '添加备注...',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 18.h),
              // 学习统计
              _buildDivider(context),
              _buildSectionTitle(context, '学习记录'),
              Text(
                '复习 ${snippet.reviewCount} 次'
                '${snippet.reviewCount > 0 ? ' · 正确率 ${snippet.correctCount * 100 ~/ snippet.reviewCount}%' : ''}',
                style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: 18.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onUnrecognized,
                      child: const Text('不认识'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onRecognized,
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

  Widget _buildDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
    );
  }
}
