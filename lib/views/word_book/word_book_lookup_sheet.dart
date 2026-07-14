import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/models/word_detail.dart';
import 'package:vidlang/providers/subscription_provider.dart';
import 'package:vidlang/services/unified_translation_service.dart';
import 'package:vidlang/services/word_book_service.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

class WordBookLookupSheet extends ConsumerStatefulWidget {
  final String word;

  const WordBookLookupSheet({
    super.key,
    required this.word,
  });

  @override
  ConsumerState<WordBookLookupSheet> createState() => _WordBookLookupSheetState();
}

class _WordBookLookupSheetState extends ConsumerState<WordBookLookupSheet> {
  bool _loading = false;
  String? _error;
  WordDetail? _result;
  bool _alreadySaved = false;

  /// 内部自主判定付费模式
  bool get _isPaidMode => ref.read(subscriptionProvider).mode == SubscriptionMode.premium;

  @override
  void initState() {
    super.initState();
    _checkSaved();
    if (_isPaidMode) {
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mode = _isPaidMode ? SubscriptionMode.premium : SubscriptionMode.free;
      final result = await UnifiedTranslationService.instance.translate(
        text: widget.word,
        mode: mode,
      );
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
    final colorScheme = context.colors;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(Adaptive.r(context, 20))),
          ),
          child: Column(
            children: [
              SizedBox(height: Adaptive.h(context, 8)),
              Container(
                width: Adaptive.w(context, 36),
                height: Adaptive.h(context, 4),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(Adaptive.r(context, 2)),
                ),
              ),
              SizedBox(height: Adaptive.h(context, 8)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 20)),
                child: Row(
                  children: [
                    Text(
                      '查词结果',
                      style: TextStyle(fontSize: Adaptive.sp(context, 17), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                    ),
                    const Spacer(),
                    if (_alreadySaved)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 10), vertical: Adaptive.h(context, 4)),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Adaptive.r(context, 999)),
                        ),
                        child: Text(
                          '已收藏',
                          style: TextStyle(fontSize: Adaptive.sp(context, 12), color: colorScheme.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: Adaptive.h(context, 8)),
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
    final colorScheme = context.colors;

    if (!_isPaidMode) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(Adaptive.r(context, 40)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.cloudOff, size: Adaptive.sp(context, 48), color: colorScheme.onSurfaceVariant),
              SizedBox(height: Adaptive.h(context, 16)),
              Text(
                '离线词典暂未集成',
                style: TextStyle(fontSize: Adaptive.sp(context, 16), fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              SizedBox(height: Adaptive.h(context, 8)),
              Text(
                '请切换到收费模式使用 AI 查词',
                style: TextStyle(fontSize: Adaptive.sp(context, 14), color: colorScheme.onSurfaceVariant),
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
          padding: EdgeInsets.all(Adaptive.r(context, 40)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.error, size: Adaptive.sp(context, 48), color: colorScheme.error),
              SizedBox(height: Adaptive.h(context, 16)),
              Text('查询失败', style: TextStyle(fontSize: Adaptive.sp(context, 14), color: colorScheme.error)),
              SizedBox(height: Adaptive.h(context, 12)),
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
      padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 20)),
      children: [
        // Word
        Text(
          data.word,
          style: TextStyle(fontSize: Adaptive.sp(context, 28), fontWeight: FontWeight.w700, color: colorScheme.onSurface),
        ),
        SizedBox(height: Adaptive.h(context, 8)),
        // Phonetic
        if (data.pronounce.ukPhonetic != null)
          Row(
            children: [
              Text(
                '/${data.pronounce.ukPhonetic}/',
                style: TextStyle(fontSize: Adaptive.sp(context, 15), color: colorScheme.onSurfaceVariant),
              ),
              SizedBox(width: Adaptive.w(context, 12)),
              Icon(AppIcons.volumeUp, size: Adaptive.sp(context, 20), color: colorScheme.primary),
            ],
          ),
        if (data.definitions.isNotEmpty) ...[
          SizedBox(height: Adaptive.h(context, 20)),
          _buildDivider(colorScheme),
          SizedBox(height: Adaptive.h(context, 12)),
          Text('释义', style: TextStyle(fontSize: Adaptive.sp(context, 12), fontWeight: FontWeight.w600, color: colorScheme.tertiary)),
          SizedBox(height: Adaptive.h(context, 6)),
          ...data.definitions.map((d) {
            final pos = d.partOfSpeech;
            return Padding(
              padding: EdgeInsets.only(bottom: Adaptive.h(context, 4)),
              child: Text(
                '${pos != null ? '$pos. ' : ''}${d.chineseMeaning}',
                style: TextStyle(fontSize: Adaptive.sp(context, 14), color: colorScheme.onSurface),
              ),
            );
          }),
          // Examples from definitions
          ...data.definitions.where((d) => d.examples.isNotEmpty).expand((d) => d.examples.map((ex) {
            return Padding(
              padding: EdgeInsets.only(top: Adaptive.h(context, 2), left: Adaptive.w(context, 8), bottom: Adaptive.h(context, 2)),
              child: Text(
                ex.english,
                style: TextStyle(fontSize: Adaptive.sp(context, 13), color: colorScheme.onSurfaceVariant),
              ),
            );
          })),
        ],
        // Examples list
        if (data.standaloneExamples.isNotEmpty) ...[
          SizedBox(height: Adaptive.h(context, 16)),
          _buildDivider(colorScheme),
          SizedBox(height: Adaptive.h(context, 12)),
          Text('例句', style: TextStyle(fontSize: Adaptive.sp(context, 12), fontWeight: FontWeight.w600, color: colorScheme.tertiary)),
          SizedBox(height: Adaptive.h(context, 6)),
          ...data.standaloneExamples.map((ex) {
            return Padding(
              padding: EdgeInsets.only(bottom: Adaptive.h(context, 4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ex.english,
                    style: TextStyle(fontSize: Adaptive.sp(context, 13), color: colorScheme.onSurface),
                  ),
                  if (ex.chinese.isNotEmpty)
                    Text(
                      ex.chinese,
                      style: TextStyle(fontSize: Adaptive.sp(context, 12), color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            );
          }),
        ],
        if (morphology.isNotEmpty) ...[
          SizedBox(height: Adaptive.h(context, 16)),
          _buildDivider(colorScheme),
          SizedBox(height: Adaptive.h(context, 12)),
          Text('词形变化', style: TextStyle(fontSize: Adaptive.sp(context, 12), fontWeight: FontWeight.w600, color: colorScheme.tertiary)),
          SizedBox(height: Adaptive.h(context, 6)),
          ...morphology.entries.map((e) {
            return Padding(
              padding: EdgeInsets.only(bottom: Adaptive.h(context, 2)),
              child: Text(
                '${_morphologyLabel(e.key)}: ${e.value}',
                style: TextStyle(fontSize: Adaptive.sp(context, 13), color: colorScheme.onSurface),
              ),
            );
          }),
        ],
        SizedBox(height: Adaptive.h(context, 24)),
      ],
    );
  }

  Widget _buildDivider(AppColorsData cs) {
    return Divider(height: Adaptive.h(context, 1), color: cs.outlineVariant.withValues(alpha: 0.4));
  }

  Widget _buildBottomBar(BuildContext context) {
    final colorScheme = context.colors;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(Adaptive.w(context, 20), Adaptive.h(context, 8), Adaptive.w(context, 20), Adaptive.h(context, 12)),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
        ),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Adaptive.r(context, 20))),
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
