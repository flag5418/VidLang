import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vidlang/models/word_book_query_models.dart';

class WordBookNavPanel extends StatelessWidget {
  final String selectedStatus;
  final String? selectedTagCode;
  final List<WordBookNavItem> learningItems;
  final List<WordBookNavItem> masteredItems;
  final ValueChanged<WordBookNavItem> onSelect;

  const WordBookNavPanel({
    super.key,
    required this.selectedStatus,
    required this.selectedTagCode,
    required this.learningItems,
    required this.masteredItems,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            context,
            title: '生词',
            items: learningItems,
          ),
          SizedBox(height: 16.h),
          _buildSection(
            context,
            title: '已掌握',
            items: masteredItems,
          ),
        ],
      ),
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
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 8.h),
        ...items.map((item) {
          final selected = item.status == selectedStatus && item.tagCode == selectedTagCode;
          return Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: InkWell(
              onTap: () => onSelect(item),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary.withValues(alpha: 0.14) : colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${item.count}',
                      style: TextStyle(
                        fontSize: 12.sp,
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
