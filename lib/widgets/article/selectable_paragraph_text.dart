import 'package:flutter/material.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/utils/adaptive.dart';

/// 段落内单词信息
class _ParagraphWord {
  final String text;
  final int index;
  final bool isWord;
  final GlobalKey key = GlobalKey();
  double x = 0;
  double y = 0;
  double width = 0;
  double height = 0;
  int row = 0;

  _ParagraphWord({
    required this.text,
    required this.index,
    required this.isWord,
  });
}

/// 可划词的段落文本控制器
/// 用于外部清除选区
class SelectableParagraphTextController {
  void Function()? _clearSelection;
  void clearSelection() => _clearSelection?.call();
}

/// 可划词的段落文本组件
///
/// 支持：
/// - PanDown/PanUpdate/PanEnd 划词选择
/// - Tap 点击（非划词模式下）
/// - TTS 高亮
/// - 标记词下划线
/// - 划词结束后选区保持高亮，直到外部调用 clearSelection
class SelectableParagraphText extends StatefulWidget {
  final String text;
  final double fontSize;
  final FontWeight? fontWeight;
  final Color textColor;
  final AppColorsData colorScheme;

  /// 控制器（用于外部清除选区）
  final SelectableParagraphTextController? controller;

  /// 点击（非划词模式）
  final VoidCallback? onTap;

  /// 划词结束回调 (selectedWords, toolbarPosition, startIndex, endIndex)
  final void Function(
    List<String> selectedWords,
    Offset position,
    int startIndex,
    int endIndex,
  )?
  onSelectionDone;

  /// 开始划词（父组件应禁用滚动）
  final VoidCallback? onStartSelection;

  /// TTS 朗读高亮
  final bool isSpeaking;
  final int ttsCurrentWordIndex;

  /// 标记词 (仅传入当前段落的标记)
  final List<dynamic> marks; // 使用 dynamic 避免循环引用，实际是 MarkRecord

  const SelectableParagraphText({
    super.key,
    required this.text,
    required this.fontSize,
    this.fontWeight,
    required this.textColor,
    required this.colorScheme,
    this.controller,
    this.onTap,
    this.onSelectionDone,
    this.onStartSelection,
    this.isSpeaking = false,
    this.ttsCurrentWordIndex = -1,
    this.marks = const [],
  });

  @override
  State<SelectableParagraphText> createState() =>
      _SelectableParagraphTextState();
}

class _SelectableParagraphTextState extends State<SelectableParagraphText> {
  List<_ParagraphWord>? _cachedWords;
  String? _lastText;
  final GlobalKey _wrapKey = GlobalKey();
  final List<int> _selectedIndices = [];

  @override
  void initState() {
    super.initState();
    widget.controller?._clearSelection = clearSelection;
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateWordPositions());
  }

  @override
  void didUpdateWidget(covariant SelectableParagraphText oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller?._clearSelection = clearSelection;
    if (oldWidget.text != widget.text) {
      _cachedWords = null;
      _lastText = null;
      _selectedIndices.clear();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _updateWordPositions(),
      );
    }
  }

  @override
  void dispose() {
    if (widget.controller?._clearSelection == clearSelection) {
      widget.controller?._clearSelection = null;
    }
    super.dispose();
  }

  /// 外部调用：清除选区
  void clearSelection() {
    if (_selectedIndices.isNotEmpty && mounted) {
      setState(() => _selectedIndices.clear());
    }
  }

  List<_ParagraphWord> _splitWords(String text) {
    if (_cachedWords != null && _cachedWords!.isNotEmpty && _lastText == text) {
      return _cachedWords!;
    }
    // 拆分单词、标点、空格
    final regex = RegExp(r'\b\w+\b|[^\w\s]|\s+');
    _cachedWords = regex.allMatches(text).toList().asMap().entries.map((e) {
      final match = e.value.group(0)!;
      return _ParagraphWord(
        text: match,
        index: e.key,
        isWord: RegExp(r'\w').hasMatch(match),
      );
    }).toList();
    _lastText = text;
    return _cachedWords!;
  }

  /// 渲染后计算每个单词相对 Wrap 的位置
  void _updateWordPositions([int retry = 0]) {
    final words = _splitWords(widget.text);
    int successCount = 0;
    int rowIndex = 0;

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final key = word.key;
      if (key.currentContext == null) continue;

      final RenderBox? renderBox =
          key.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      final RenderBox? wrapRenderBox =
          _wrapKey.currentContext?.findRenderObject() as RenderBox?;
      if (wrapRenderBox == null) continue;

      final globalPos = renderBox.localToGlobal(Offset.zero);
      final wrapGlobalPos = wrapRenderBox.localToGlobal(Offset.zero);
      final relative = globalPos - wrapGlobalPos;

      word.x = relative.dx;
      word.y = relative.dy;
      word.width = renderBox.size.width;
      word.height = renderBox.size.height;

      if (i > 0 && (word.y - words[i - 1].y).abs() > 1) {
        rowIndex += 1;
      }
      word.row = rowIndex;
      successCount++;
    }

    // 如果未获取到位置，稍后重试（最多3次）
    if (successCount == 0 && retry < 3) {
      Future.delayed(Duration(milliseconds: 100 * (retry + 1)), () {
        if (mounted) _updateWordPositions(retry + 1);
      });
    }
  }

  /// 命中测试：根据手势坐标返回命中的单词
  _ParagraphWord? _hitTestWord(Offset localPosition) {
    if (_cachedWords == null || _cachedWords!.isEmpty) return null;

    final RenderBox? gestureBox = context.findRenderObject() as RenderBox?;
    final RenderBox? wrapBox =
        _wrapKey.currentContext?.findRenderObject() as RenderBox?;
    if (gestureBox == null || wrapBox == null) return null;

    final globalPos = gestureBox.localToGlobal(localPosition);
    final wrapLocal = wrapBox.globalToLocal(globalPos);
    final dx = wrapLocal.dx;
    final dy = wrapLocal.dy;

    for (final word in _cachedWords!) {
      final left = word.x;
      final top = word.y;
      final right = word.x + word.width;
      final bottom = word.y + word.height;
      if (dx >= left && dx <= right && dy >= top && dy <= bottom) {
        return word;
      }
    }
    return null;
  }

  void _handlePanDown(DragDownDetails details) {
    widget.onStartSelection?.call();
    final word = _hitTestWord(details.localPosition);
    if (word == null) return;
    setState(() {
      _selectedIndices
        ..clear()
        ..add(word.index);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_cachedWords == null || _cachedWords!.isEmpty) return;
    if (_selectedIndices.isEmpty) return;

    final int startIndex = _selectedIndices.first;
    final _ParagraphWord? endWord = _hitTestWord(details.localPosition);
    if (endWord == null) return;

    final int endIndex = endWord.index;

    final newSelection = <int>[];
    if (endIndex >= startIndex) {
      for (int i = startIndex; i <= endIndex; i++) {
        newSelection.add(i);
      }
    } else {
      for (int i = startIndex; i >= endIndex; i--) {
        newSelection.add(i);
      }
    }

    setState(() {
      _selectedIndices
        ..clear()
        ..addAll(newSelection);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_selectedIndices.isNotEmpty && widget.onSelectionDone != null) {
      final words = _splitWords(widget.text);
      final sortedIndices = _selectedIndices.toList()..sort();
      final selectedWords = sortedIndices
          .map((idx) => words[idx].text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // 计算工具栏位置（最后一个选中词的上方）
      final lastIdx = sortedIndices.last;
      if (lastIdx < words.length) {
        final lastWord = words[lastIdx];
        final key = lastWord.key;
        if (key.currentContext != null) {
          final box = key.currentContext!.findRenderObject() as RenderBox?;
          if (box != null) {
            final pos = box.localToGlobal(Offset.zero);
            widget.onSelectionDone!(
              selectedWords,
              pos,
              sortedIndices.first,
              sortedIndices.last,
            );
          }
        }
      }
    }
    // 不清除选区，保持高亮直到外部调用 clearSelection
  }

  void _handleTap() {
    // 无论是否有选区，都调用 onTap，让父组件决定如何处理
    // 父组件会通过 controller 清除选区并隐藏工具栏
    widget.onTap?.call();
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    widget.onStartSelection?.call();
    final word = _hitTestWord(details.localPosition);
    if (word == null) return;
    setState(() {
      _selectedIndices
        ..clear()
        ..add(word.index);
    });

    if (widget.onSelectionDone != null) {
      final words = _splitWords(widget.text);
      final selectedWords = [words[word.index].text.trim()];

      final key = word.key;
      if (key.currentContext != null) {
        final box = key.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero);
          widget.onSelectionDone!(selectedWords, pos, word.index, word.index);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _splitWords(widget.text);
    int isWordIdx = 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: _handlePanDown,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onLongPressStart: _handleLongPressStart,
      onTap: _handleTap,
      child: Wrap(
        key: _wrapKey,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: words.asMap().entries.map((e) {
          final index = e.key;
          final word = e.value;
          final isSelected = _selectedIndices.contains(index);

          // TTS 当前词高亮
          int ttsIdx = -1;
          if (word.isWord) {
            ttsIdx = isWordIdx;
            isWordIdx++;
          }
          final isTtsHighlight =
              widget.isSpeaking &&
              ttsIdx == widget.ttsCurrentWordIndex &&
              word.isWord;

          // 标记词
          dynamic activeMark;
          for (final mark in widget.marks) {
            if (index >= mark.startIndex && index <= mark.endIndex) {
              activeMark = mark;
              break;
            }
          }
          final markColor = activeMark?.color;

          Color? bgColor;
          Color textColor = widget.textColor;
          TextDecoration? decoration;
          TextDecorationStyle decorationStyle = TextDecorationStyle.solid;
          Color? underlineColor;

          if (isTtsHighlight) {
            bgColor = widget.colorScheme.primary.withValues(alpha: 0.15);
            textColor = widget.colorScheme.primary;
            decoration = null; // TTS高亮不使用下划线
          } else if (isSelected) {
            bgColor = widget.colorScheme.primary.withValues(alpha: 0.12);
            textColor = widget.colorScheme.primary;
          } else if (markColor != null) {
            bgColor = markColor.withValues(alpha: 0.2);
            decoration = TextDecoration.underline;
            decorationStyle = TextDecorationStyle.dotted;
            underlineColor = markColor;
            decorationStyle = TextDecorationStyle.dotted;
          }

          return Container(
            key: word.key,
            padding: EdgeInsets.symmetric(horizontal: Adaptive.w(context, 2), vertical: Adaptive.h(context, 2)),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(Adaptive.r(context, 3)),
              border: isTtsHighlight
                  ? Border.all(
                      color: widget.colorScheme.primary.withValues(alpha: 0.4),
                      width: 1.0,
                    )
                  : null,
            ),
            child: Text(
              word.text,
              style: TextStyle(
                fontSize: Adaptive.sp(context, widget.fontSize),
                color: textColor,
                fontWeight: widget.fontWeight ?? FontWeight.w500,
                height: 1.6,
                decoration: decoration,
                decorationStyle: decorationStyle,
                decorationColor: underlineColor ?? markColor,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
