import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/utils/adaptive.dart';
import 'package:vidlang/views/word_book/camera_translate_page.dart';

class CollectionHeaderWidget extends StatefulWidget {
  final bool isKnowledgeBase;
  final int totalWords;
  final int todayReviewed;
  final TextEditingController searchController;
  final ValueChanged<int> onTabChanged;

  const CollectionHeaderWidget({
    super.key,
    required this.isKnowledgeBase,
    required this.totalWords,
    required this.todayReviewed,
    required this.searchController,
    required this.onTabChanged,
  });

  @override
  State<CollectionHeaderWidget> createState() => _CollectionHeaderWidgetState();
}

class _CollectionHeaderWidgetState extends State<CollectionHeaderWidget> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.isKnowledgeBase ? '知识库' : '生词本',
              style: TextStyle(
                fontSize: Adaptive.sp(22),
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(width: Adaptive.w(8)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Adaptive.w(8),
                vertical: Adaptive.h(3),
              ),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Adaptive.r(999)),
              ),
              child: Text(
                '${widget.totalWords}${widget.isKnowledgeBase ? '句' : '词'}',
                style: TextStyle(
                  fontSize: Adaptive.sp(13),
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '今日 ${widget.todayReviewed}/${widget.totalWords}',
              style: TextStyle(
                fontSize: Adaptive.sp(12),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: Adaptive.h(12)),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Adaptive.r(10)),
          ),
          padding: EdgeInsets.all(Adaptive.r(3)),
          child: Row(
            children: [
              _buildTabChip('单词', AppIcons.spellcheck, 0, colorScheme),
              SizedBox(width: Adaptive.w(3)),
              _buildTabChip('知识库', AppIcons.libraryBooks, 1, colorScheme),
            ],
          ),
        ),
        SizedBox(height: Adaptive.h(12)),
        TextField(
          controller: widget.searchController,
          focusNode: _focusNode,
          onSubmitted: (_) => _handleSearchSubmit(),
          style: TextStyle(fontSize: Adaptive.sp(16), color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: widget.isKnowledgeBase ? '搜索句子或备注' : '搜索单词或上下文',
            hintStyle: TextStyle(fontSize: Adaptive.sp(15), color: colorScheme.onSurfaceVariant),
            prefixIcon: Icon(AppIcons.search, size: Adaptive.icon(22), color: colorScheme.onSurfaceVariant),
            suffixIcon: widget.searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () => widget.searchController.clear(),
                    icon: const Icon(AppIcons.close),
                  )
                : (Platform.isIOS && !widget.isKnowledgeBase
                    ? IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CameraTranslatePage()),
                        ),
                        icon: const Icon(AppIcons.cameraAlt),
                      )
                    : null),
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            contentPadding: EdgeInsets.symmetric(
              horizontal: Adaptive.w(14),
              vertical: Adaptive.h(14),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Adaptive.r(14)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabChip(
    String label,
    IconData icon,
    int tabIndex,
    AppColorsData cs,
  ) {
    final selected = tabIndex == (widget.isKnowledgeBase ? 1 : 0);
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onTabChanged(tabIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: Adaptive.h(8)),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(Adaptive.r(8)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: Adaptive.sp(16),
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              SizedBox(width: Adaptive.w(4)),
              Text(
                label,
                style: TextStyle(
                  fontSize: Adaptive.sp(13),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSearchSubmit() {}
}
