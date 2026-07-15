import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_tag.dart';
import 'package:vidlang/services/tts/tts_service.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

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
        padding: EdgeInsets.fromLTRB(Adaptive.w(16), Adaptive.h(12), Adaptive.w(16), Adaptive.h(16)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: Adaptive.w(40),
                  height: Adaptive.h(4),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(Adaptive.r(999)),
                  ),
                ),
              ),
              SizedBox(height: Adaptive.h(16)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '句子详情',
                      style: TextStyle(
                        fontSize: Adaptive.sp(18),
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
                    icon: const Icon(AppIcons.volumeUp),
                    tooltip: '朗读',
                  ),
                  if (widget.onDelete != null)
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: const Icon(AppIcons.delete),
                    ),
                ],
              ),
              SizedBox(height: Adaptive.h(12)),
              // 句子原文
              if ((snippet.sourceText ?? '').isNotEmpty) ...[
                _buildSectionTitle(context, '原文'),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(Adaptive.r(12)),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(Adaptive.r(14)),
                  ),
                  child: Text(
                    snippet.sourceText!,
                    style: TextStyle(
                      fontSize: Adaptive.sp(16),
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: Adaptive.h(12)),
              ],
              // 翻译
              if ((snippet.sourceTranslation ?? '').isNotEmpty) ...[
                _buildSectionTitle(context, '翻译'),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(Adaptive.r(12)),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(Adaptive.r(14)),
                  ),
                  child: Text(
                    snippet.sourceTranslation!,
                    style: TextStyle(
                      fontSize: Adaptive.sp(14),
                      color: colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: Adaptive.h(12)),
              ],
              // 来源
              if ((snippet.sourceTitle ?? '').isNotEmpty) ...[
                _buildSectionTitle(context, '来源'),
                Text(
                  snippet.sourceTitle!,
                  style: TextStyle(fontSize: Adaptive.sp(13), color: colorScheme.onSurfaceVariant),
                ),
                SizedBox(height: Adaptive.h(8)),
              ],
              // 收藏时间
              if (snippet.createdAt != null) ...[
                Text(
                  '收藏于 ${snippet.createdAt!.year}-${snippet.createdAt!.month.toString().padLeft(2, '0')}-${snippet.createdAt!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: Adaptive.sp(12), color: colorScheme.outline),
                ),
                SizedBox(height: Adaptive.h(8)),
              ],
              _buildDivider(context),
              // 标签
              _buildSectionTitle(context, '标签'),
              if (widget.tags.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: Adaptive.h(8)),
                  child: Wrap(
                    spacing: Adaptive.w(8),
                    runSpacing: Adaptive.h(8),
                    children: widget.tags
                        .map(
                          (tag) => Container(
                            padding: EdgeInsets.symmetric(horizontal: Adaptive.w(10), vertical: Adaptive.h(5)),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(Adaptive.r(999)),
                            ),
                            child: Text(
                              tag.name,
                              style: TextStyle(fontSize: Adaptive.sp(12), color: colorScheme.primary),
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
              SizedBox(height: Adaptive.h(12)),
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
                    borderRadius: BorderRadius.circular(Adaptive.r(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: Adaptive.h(18)),
              // 学习统计
              _buildDivider(context),
              _buildSectionTitle(context, '学习记录'),
              Text(
                '复习 ${snippet.reviewCount} 次'
                '${snippet.reviewCount > 0 ? ' · 正确率 ${snippet.correctCount * 100 ~/ snippet.reviewCount}%' : ''}',
                style: TextStyle(fontSize: Adaptive.sp(13), color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: Adaptive.h(18)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onUnrecognized,
                      child: const Text('不认识'),
                    ),
                  ),
                  SizedBox(width: Adaptive.w(12)),
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
      padding: EdgeInsets.only(bottom: Adaptive.h(8)),
      child: Text(
        title,
        style: TextStyle(
          fontSize: Adaptive.sp(14),
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Adaptive.h(12)),
      child: Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
    );
  }
}
