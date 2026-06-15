import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/services/ai_service.dart';
import 'package:vidlang/services/word_book_service.dart';

class WordBookLookupSheet extends StatefulWidget {
  final String word;
  final bool isPaidMode;

  const WordBookLookupSheet({
    super.key,
    required this.word,
    required this.isPaidMode,
  });

  @override
  State<WordBookLookupSheet> createState() => _WordBookLookupSheetState();
}

class _WordBookLookupSheetState extends State<WordBookLookupSheet> {
  bool _loading = false;
  String? _error;
  WordDetail? _result;
  bool _alreadySaved = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
    if (widget.isPaidMode) {
      _lookup();
    }
  }

  Future<void> _checkSaved() async {
    final existing = await WordBookService.queryWords(
      WordBookFilter(keyword: widget.word),
    );
    if (mounted) {
      setState(() => _alreadySaved = existing.any((wb) => wb.word == widget.word.toLowerCase()));
    }
  }

  Future<void> _lookup() async {
    if (!widget.isPaidMode) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await AiService.getDefinition(word: widget.word);
      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              SizedBox(height: 8.h),
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 8.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Text(
                      '查词结果',
                      style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    const Spacer(),
                    if (_alreadySaved)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          '已收藏',
                          style: TextStyle(fontSize: 12.sp, color: colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Expanded(
                child: _buildContent(context, scrollController),
              ),
              _buildBottomBar(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, ScrollController scrollController) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!widget.isPaidMode) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 48.sp, color: colorScheme.onSurfaceVariant),
              SizedBox(height: 16.h),
              Text(
                '离线词典暂未集成',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              SizedBox(height: 8.h),
              Text(
                '请切换到收费模式使用 AI 查词',
                style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48.sp, color: colorScheme.error),
              SizedBox(height: 16.h),
              Text('查询失败', style: TextStyle(fontSize: 14.sp, color: colorScheme.error)),
              SizedBox(height: 12.h),
              OutlinedButton(onPressed: _lookup, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    if (_result == null) {
      return const SizedBox.shrink();
    }

    final data = _result!;
    // AI result does not carry morphologyJson; use an empty map
    final morphology = <String, String>{};

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      children: [
        // Word
        Text(
          data.word,
          style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w700, color: colorScheme.onSurface),
        ),
        SizedBox(height: 8.h),
        // Phonetic
        if (data.pronounce.ukPhonetic != null)
          Row(
            children: [
              Text(
                '/${data.pronounce.ukPhonetic}/',
                style: TextStyle(fontSize: 15.sp, color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(width: 12.w),
              Icon(Icons.volume_up, size: 20.sp, color: colorScheme.primary),
            ],
          ),
        if (data.definitions.isNotEmpty) ...[
          SizedBox(height: 20.h),
          _buildDivider(colorScheme),
          SizedBox(height: 12.h),
          Text('释义', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colorScheme.tertiary)),
          SizedBox(height: 6.h),
          ...data.definitions.map((d) {
            final pos = d.partOfSpeech;
            return Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Text(
                '${pos != null ? '$pos. ' : ''}${d.chineseMeaning}',
                style: TextStyle(fontSize: 14.sp, color: colorScheme.onSurface),
              ),
            );
          }),
          // Examples from definitions
          ...data.definitions.where((d) => d.examples.isNotEmpty).expand((d) => d.examples.map((ex) {
            return Padding(
              padding: EdgeInsets.only(top: 2.h, left: 8.w, bottom: 2.h),
              child: Text(
                ex.english,
                style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurfaceVariant),
              ),
            );
          })),
        ],
        // Examples list
        if (data.standaloneExamples.isNotEmpty) ...[
          SizedBox(height: 16.h),
          _buildDivider(colorScheme),
          SizedBox(height: 12.h),
          Text('例句', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colorScheme.tertiary)),
          SizedBox(height: 6.h),
          ...data.standaloneExamples.map((ex) {
            return Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ex.english,
                    style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurface),
                  ),
                  if (ex.chinese.isNotEmpty)
                    Text(
                      ex.chinese,
                      style: TextStyle(fontSize: 12.sp, color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            );
          }),
        ],
        if (morphology.isNotEmpty) ...[
          SizedBox(height: 16.h),
          _buildDivider(colorScheme),
          SizedBox(height: 12.h),
          Text('词形变化', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colorScheme.tertiary)),
          SizedBox(height: 6.h),
          ...morphology.entries.map((e) {
            return Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Text(
                '${_morphologyLabel(e.key)}: ${e.value}',
                style: TextStyle(fontSize: 13.sp, color: colorScheme.onSurface),
              ),
            );
          }),
        ],
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildDivider(ColorScheme cs) {
    return Divider(height: 1.h, color: cs.outlineVariant.withValues(alpha: 0.4));
  }

  Widget _buildBottomBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
        ),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
            ),
            child: const Text('关闭'),
          ),
        ),
      ),
    );
  }

  String _morphologyLabel(String key) {
    const labels = {
      'comparative': '比较级',
      'superlative': '最高级',
      'plural': '复数',
      'past': '过去式',
      'past_participle': '过去分词',
      'present_participle': '现在分词',
      'third_person': '第三人称单数',
      'singular': '单数',
    };
    return labels[key] ?? key;
  }
}
