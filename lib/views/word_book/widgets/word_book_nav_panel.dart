import 'package:flutter/material.dart';
import 'package:vidlang/models/word_book.dart';
import 'package:vidlang/models/word_book_query_models.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';

class WordBookNavPanel extends StatelessWidget {
  final String selectedStatus;
  final String? selectedTagCode;
  final List<WordBookNavItem> learningItems;
  final List<WordBookNavItem> masteredItems;
  final ValueChanged<WordBookNavItem> onSelect;
  final bool selectionMode;
  final Set<String> selectedWordCodes;
  final List<WordBook>? words;
  final void Function(Set<String> codes)? onSmartSelect;

  const WordBookNavPanel({
    super.key,
    required this.selectedStatus,
    required this.selectedTagCode,
    required this.learningItems,
    required this.masteredItems,
    required this.onSelect,
    this.selectionMode = false,
    this.selectedWordCodes = const {},
    this.words,
    this.onSmartSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(Adaptive.r(12)),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Adaptive.r(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            context,
            title: '生词',
            items: learningItems,
          ),
          if (selectionMode && words != null && words!.isNotEmpty)
            _buildSmartRecommendations(context),
          SizedBox(height: Adaptive.h(16)),
          _buildSection(
            context,
            title: '已掌握',
            items: masteredItems,
          ),
        ],
      ),
    );
  }

  Widget _buildSmartRecommendations(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final needsReview = words!.where((w) {
      if (w.nextReviewAt == null) return false;
      return w.nextReviewAt!.isBefore(now);
    }).toList();

    final neverTested = words!.where((w) => w.reviewCount == 0).toList();

    final highError = words!.where((w) {
      if (w.reviewCount == 0) return false;
      return (w.correctCount / w.reviewCount) < 0.5;
    }).toList();

    final smartItems = <_SmartRecommendItem>[
      _SmartRecommendItem(label: '需复习', count: needsReview.length, codes: needsReview.map((w) => w.code!).toSet()),
      _SmartRecommendItem(label: '从未测试', count: neverTested.length, codes: neverTested.map((w) => w.code!).toSet()),
      _SmartRecommendItem(label: '错误率高', count: highError.length, codes: highError.map((w) => w.code!).toSet()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: Adaptive.h(4)),
        ...smartItems.where((item) => item.count > 0).map((item) {
          final allSelected = item.codes.isNotEmpty && item.codes.every((c) => selectedWordCodes.contains(c));
          return Padding(
            padding: EdgeInsets.only(bottom: Adaptive.h(6)),
            child: InkWell(
              onTap: () => onSmartSelect?.call(item.codes),
              borderRadius: BorderRadius.circular(Adaptive.r(12)),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: Adaptive.w(10), vertical: Adaptive.h(10)),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(Adaptive.r(12)),
                ),
                child: Row(
                  children: [
                    Icon(
                      allSelected && item.codes.isNotEmpty
                          ? AppIcons.checkBox
                          : AppIcons.checkBoxOutlineBlank,
                      size: Adaptive.sp(18),
                      color: colorScheme.primary,
                    ),
                    SizedBox(width: Adaptive.w(8)),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Adaptive.sp(13),
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(width: Adaptive.w(8)),
                    Text(
                      '${item.count}',
                      style: TextStyle(
                        fontSize: Adaptive.sp(12),
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<WordBookNavItem> items,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: Adaptive.sp(14),
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: Adaptive.h(8)),
        ...items.map((item) {
          final selected = item.status == selectedStatus && item.tagCode == selectedTagCode;
          return Padding(
            padding: EdgeInsets.only(bottom: Adaptive.h(6)),
            child: InkWell(
              onTap: () => onSelect(item),
              borderRadius: BorderRadius.circular(Adaptive.r(12)),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: Adaptive.w(10), vertical: Adaptive.h(10)),
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary.withValues(alpha: 0.14) : colorScheme.surface,
                  borderRadius: BorderRadius.circular(Adaptive.r(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: Adaptive.sp(13),
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(width: Adaptive.w(8)),
                    Text(
                      '${item.count}',
                      style: TextStyle(
                        fontSize: Adaptive.sp(12),
                        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SmartRecommendItem {
  final String label;
  final int count;
  final Set<String> codes;

  _SmartRecommendItem({required this.label, required this.count, required this.codes});
}
