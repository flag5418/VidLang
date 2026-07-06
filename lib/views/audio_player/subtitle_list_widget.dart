import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vidlang/models/subtitles.dart';
import 'package:vidlang/theme/theme.dart';
import 'package:vidlang/widgets/selectable_english_line.dart';

/// 全屏字幕列表组件
///
/// - 显示所有字幕行，当前播放行高亮 + 放大
/// - 自动滚动到当前行（用户手动滚动时暂停自动跟踪）
/// - 点击行 → 跳转播放
/// - 长按划词 → 弹出 WordCard
class SubtitleListView extends StatefulWidget {
  final List<Subtitles> subtitles;
  final int? currentIndex;
  final bool subtitleVisible;
  final bool translateVisible;
  final bool pronunciationVisible;
  final double fontSize;
  final void Function(int index)? onTapSubtitle;
  final void Function(List<String> words, Subtitles subtitle)? onWordSelected;

  const SubtitleListView({
    super.key,
    required this.subtitles,
    this.currentIndex,
    this.subtitleVisible = true,
    this.translateVisible = true,
    this.pronunciationVisible = true,
    this.fontSize = 20.0,
    this.onTapSubtitle,
    this.onWordSelected,
  });

  @override
  State<SubtitleListView> createState() => SubtitleListViewState();
}

class SubtitleListViewState extends State<SubtitleListView> {
  final ScrollController _scrollController = ScrollController();
  bool _userScrolling = false;
  int? _lastAutoScrolledIndex;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_userScrolling) return;
    // User is scrolling — we'll re-enable auto-scroll when they stop
  }

  /// Scroll to the current subtitle index
  void scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    if (index == _lastAutoScrolledIndex && !_userScrolling) return;
    _lastAutoScrolledIndex = index;
    _userScrolling = false;

    // Estimate item height and scroll
    final itemExtent = _estimateItemHeight(index);
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (index * itemExtent) - (viewportHeight / 2) + (itemExtent / 2);
    final maxScroll = _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      targetOffset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  double _estimateItemHeight(int index) {
    // Rough estimate: each subtitle item ~80-120px depending on content
    final sub = widget.subtitles[index];
    int lines = 1; // original text
    if (widget.pronunciationVisible && sub.pronunciation != null && sub.pronunciation!.isNotEmpty) lines++;
    if (widget.translateVisible && sub.contentTranslate != null && sub.contentTranslate!.isNotEmpty) lines++;
    return 30.0 + lines * 28.0 + 24.0; // padding + lines + spacing
  }

  @override
  void didUpdateWidget(covariant SubtitleListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex && widget.currentIndex != null) {
      if (!_userScrolling) {
        // Delay to ensure layout is complete
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) scrollToIndex(widget.currentIndex!);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subtitles.isEmpty) {
      return const SizedBox.shrink();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification && notification.dragDetails != null) {
          _userScrolling = true;
        }
        if (notification is ScrollEndNotification) {
          // Re-enable auto-scroll after user stops scrolling (with delay)
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _userScrolling = false;
          });
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        itemCount: widget.subtitles.length,
        itemBuilder: (context, index) {
          final sub = widget.subtitles[index];
          final isCurrent = index == widget.currentIndex;
          return _SubtitleItem(
            subtitle: sub,
            isCurrent: isCurrent,
            subtitleVisible: widget.subtitleVisible,
            translateVisible: widget.translateVisible,
            pronunciationVisible: widget.pronunciationVisible,
            fontSize: widget.fontSize,
            onTap: () => widget.onTapSubtitle?.call(index),
            onWordSelected: (words) => widget.onWordSelected?.call(words, sub),
          );
        },
      ),
    );
  }
}

class _SubtitleItem extends StatelessWidget {
  final Subtitles subtitle;
  final bool isCurrent;
  final bool subtitleVisible;
  final bool translateVisible;
  final bool pronunciationVisible;
  final double fontSize;
  final VoidCallback? onTap;
  final void Function(List<String> words)? onWordSelected;

  const _SubtitleItem({
    required this.subtitle,
    required this.isCurrent,
    required this.subtitleVisible,
    required this.translateVisible,
    required this.pronunciationVisible,
    required this.fontSize,
    this.onTap,
    this.onWordSelected,
  });

  @override
  Widget build(BuildContext context) {
    final activeFontSize = isCurrent ? fontSize : fontSize - 2;
    final textColor = isCurrent ? AppColors.onSurface : AppColors.onSurface.withValues(alpha: 0.35);
    final pronColor = isCurrent
        ? AppColors.primary.withValues(alpha: 0.9)
        : AppColors.primary.withValues(alpha: 0.3);
    final translateColor = isCurrent
        ? AppColors.onSurface.withValues(alpha: 0.75)
        : AppColors.onSurface.withValues(alpha: 0.25);

    final pronMap = _parsePronunciationMap(subtitle.pronunciationMapJson);
    final hasAlignedPron = pronMap != null && pronMap.isNotEmpty && pronunciationVisible;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: isCurrent ? 8 : 6),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: isCurrent ? 10 : 6),
        decoration: isCurrent
            ? BoxDecoration(
                color: AppColors.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Original text
            if (subtitleVisible && subtitle.content.isNotEmpty)
              onWordSelected != null && isCurrent
                  ? SelectableEnglishLine(
                      text: subtitle.content,
                      fontSize: activeFontSize,
                      fontColor: textColor,
                      selectedBgColor: AppColors.primary.withValues(alpha: 0.7),
                      onStartSelection: () {},
                      onSelectionChanged: onWordSelected!,
                    )
                  : AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        color: textColor,
                        fontSize: activeFontSize,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                        height: 1.4,
                      ),
                      child: Text(
                        subtitle.content,
                        textAlign: TextAlign.center,
                      ),
                    ),

            // Pronunciation (aligned or plain)
            if (pronunciationVisible && hasAlignedPron && subtitleVisible)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _AlignedPronRow(
                  content: subtitle.content,
                  pronMap: pronMap,
                  fontSize: activeFontSize - 4,
                  color: pronColor,
                ),
              )
            else if (pronunciationVisible && subtitle.pronunciation != null && subtitle.pronunciation!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle.pronunciation!,
                  style: TextStyle(
                    color: pronColor,
                    fontSize: activeFontSize - 4,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.5,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Translation
            if (translateVisible && subtitle.contentTranslate != null && subtitle.contentTranslate!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle.contentTranslate!,
                  style: TextStyle(
                    color: translateColor,
                    fontSize: activeFontSize - 4,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static List<_PronEntry>? _parsePronunciationMap(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final list = jsonDecode(json) as List;
      return list.map((e) => _PronEntry(
        word: e['word'] as String? ?? '',
        zh: e['zh'] as String? ?? '',
      )).toList();
    } catch (_) {
      return null;
    }
  }
}

class _AlignedPronRow extends StatelessWidget {
  final String content;
  final List<_PronEntry> pronMap;
  final double fontSize;
  final Color color;

  const _AlignedPronRow({
    required this.content,
    required this.pronMap,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final lookup = <String, String>{};
    for (final entry in pronMap) {
      lookup[entry.word.toLowerCase()] = entry.zh;
    }

    final tokens = content.split(RegExp(r'(\s+)'));
    final spans = <InlineSpan>[];

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      final clean = token.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      final zh = lookup[clean] ?? '';

      if (zh.isNotEmpty) {
        spans.add(TextSpan(
          text: zh,
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w400),
        ));
      } else if (clean.isNotEmpty) {
        spans.add(TextSpan(
          text: ' ' * (token.length > 1 ? token.length : 1),
          style: TextStyle(fontSize: fontSize, color: context.colors.background.withValues(alpha: 0)),
        ));
      }

      if (i < tokens.length - 1) {
        spans.add(TextSpan(
          text: ' ',
          style: TextStyle(fontSize: fontSize, color: context.colors.background.withValues(alpha: 0)),
        ));
      }
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }
}

class _PronEntry {
  final String word;
  final String zh;
  const _PronEntry({required this.word, required this.zh});
}
