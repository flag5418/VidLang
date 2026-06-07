import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vidlang/utils/english_segmenter.dart';

/// 英文划词组件 — 参考 deepenglish_pad 的 subtitles_widget.dart
/// 使用 Listener(onPointerDown/Move/Up) 实现低层级划词，不与其他手势冲突
/// 支持：
/// - 单词粘连文本的自动分词
/// - 点击选词（短按）
/// - 滑动选词（按住拖动选择多个单词）
class SelectableEnglishLine extends StatefulWidget {
  final String text;
  final double fontSize;
  final void Function(List<String> selectedWords)? onSelectionChanged;
  final void Function()? onStartSelection;
  final void Function(String word)? onTapWord;
  final Color fontColor;
  final Color selectedBgColor;

  const SelectableEnglishLine({
    super.key,
    required this.text,
    required this.fontSize,
    this.onSelectionChanged,
    this.onStartSelection,
    this.onTapWord,
    this.fontColor = Colors.white,
    this.selectedBgColor = const Color(0xFFFF8C00),
  });

  @override
  State<SelectableEnglishLine> createState() => SelectableEnglishLineState();
}

class EnglishWord {
  final String word;
  final int index;
  final GlobalKey containerKey;
  double x, y, width, height;
  int wordRow;

  EnglishWord({required this.word, required this.index})
      : containerKey = GlobalKey(),
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        wordRow = 0;
}

class SelectableEnglishLineState extends State<SelectableEnglishLine> {
  bool _isPressing = false;
  bool _isDragging = false;
  List<String> _selectedWords = [];
  int? _dragStartIdx;
  final GlobalKey _wrapKey = GlobalKey();
  Timer? _pressTimer;
  List<EnglishWord>? _cachedWords;

  @override
  void initState() {
    super.initState();
    _cachedWords = _buildWords();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateWordPositions());
  }

  @override
  void didUpdateWidget(covariant SelectableEnglishLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _cachedWords = _buildWords();
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateWordPositions());
    }
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  /// 构建单词列表：优先使用 EnglishSegmenter 进行智能分词
  List<EnglishWord> _buildWords() {
    final tokens = EnglishSegmenter.segment(widget.text);
    return List.generate(tokens.length, (i) => EnglishWord(word: tokens[i], index: i));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    final words = _cachedWords ?? _buildWords();

    return Listener(
      onPointerDown: (event) {
        widget.onStartSelection?.call();
        _pressTimer?.cancel();
        // 短延迟后进入选择模式（区分点击和拖动）
        _pressTimer = Timer(const Duration(milliseconds: 80), () {
          if (!mounted) return;
          setState(() {
            _isPressing = true;
            _isDragging = false;
            _selectedWords = [];
            _dragStartIdx = null;
          });
          _trySelectWordAtPosition(event.position, words);
        });
      },
      onPointerMove: (event) {
        if (!_isPressing) {
          // 还没进入选择模式，但如果移动了说明是拖动，立即进入
          _pressTimer?.cancel();
          if (!mounted) return;
          setState(() {
            _isPressing = true;
            _isDragging = false;
            _selectedWords = [];
            _dragStartIdx = null;
          });
          _trySelectWordAtPosition(event.position, words);
          return;
        }

        _isDragging = true;
        final targetRenderBox = _wrapKey.currentContext?.findRenderObject() as RenderBox?;
        if (targetRenderBox == null) return;
        final localPos = targetRenderBox.globalToLocal(event.position);

        for (int s = 0; s < words.length; s++) {
          final w = words[s];
          if (localPos.dx >= w.x - 4 && localPos.dx <= w.x + w.width + 4 &&
              localPos.dy >= w.y - 2 && localPos.dy <= w.y + w.height + 2) {
            if (_dragStartIdx == null) {
              _dragStartIdx = w.index;
              _selectedWords = [w.word];
            } else {
              final start = _dragStartIdx! < w.index ? _dragStartIdx! : w.index;
              final end = _dragStartIdx! < w.index ? w.index : _dragStartIdx!;
              final newKeys = words.sublist(start, end + 1).map((e) => e.word).toList();
              if (_selectedWords.join(' ') != newKeys.join(' ')) {
                _selectedWords = newKeys;
              }
            }
            setState(() {});
            break;
          }
        }
      },
      onPointerUp: (event) {
        _pressTimer?.cancel();

        if (_isPressing && _selectedWords.isNotEmpty) {
          // 选择结束，通知选中单词
          widget.onSelectionChanged?.call(_selectedWords);
        } else if (!_isDragging && _selectedWords.isEmpty) {
          // 短按：点击单个单词
          _handleTap(event.position, words);
        }

        setState(() {
          _isPressing = false;
          _isDragging = false;
          _selectedWords = [];
          _dragStartIdx = null;
        });
      },
      onPointerCancel: (event) {
        _pressTimer?.cancel();
        setState(() {
          _isPressing = false;
          _isDragging = false;
          _selectedWords = [];
          _dragStartIdx = null;
        });
      },
      child: Stack(
        children: [
          // 选词高亮背景
          CustomPaint(
            painter: _SelectionBgPainter(
              words: words,
              selectedWords: _selectedWords,
              backgroundColor: widget.selectedBgColor,
            ),
          ),
          // 单词行
          Wrap(
            key: _wrapKey,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: words.map((w) {
              final isSel = _selectedWords.contains(w.word);
              return Container(
                key: w.containerKey,
                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
                child: Text(
                  w.word,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.bold,
                    color: isSel ? Colors.black : widget.fontColor,
                    height: 1.3,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 尝试选中指针位置下的单词
  void _trySelectWordAtPosition(Offset globalPos, List<EnglishWord> words) {
    final targetRenderBox = _wrapKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetRenderBox == null) return;
    final localPos = targetRenderBox.globalToLocal(globalPos);

    for (final w in words) {
      if (localPos.dx >= w.x - 4 && localPos.dx <= w.x + w.width + 4 &&
          localPos.dy >= w.y - 2 && localPos.dy <= w.y + w.height + 2) {
        _dragStartIdx = w.index;
        _selectedWords = [w.word];
        setState(() {});
        break;
      }
    }
  }

  /// 处理单击单词
  void _handleTap(Offset globalPos, List<EnglishWord> words) {
    final targetRenderBox = _wrapKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetRenderBox == null) return;
    final localPos = targetRenderBox.globalToLocal(globalPos);

    for (final w in words) {
      if (localPos.dx >= w.x - 4 && localPos.dx <= w.x + w.width + 4 &&
          localPos.dy >= w.y - 2 && localPos.dy <= w.y + w.height + 2) {
        // 点击单词回调
        widget.onTapWord?.call(w.word);
        // 同时触发选词弹窗（单个单词）
        widget.onSelectionChanged?.call([w.word]);
        break;
      }
    }
  }

  void _updateWordPositions() {
    if (!mounted) return;
    final wrapRenderBox = _wrapKey.currentContext?.findRenderObject() as RenderBox?;
    if (wrapRenderBox == null) return;
    final words = _cachedWords ?? _buildWords();
    final wrapOffset = wrapRenderBox.localToGlobal(Offset.zero);

    for (int i = 0; i < words.length; i++) {
      final ctx = words[i].containerKey.currentContext;
      if (ctx == null) continue;
      final renderBox = ctx.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      final localOffset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      words[i].x = localOffset.dx - wrapOffset.dx;
      words[i].y = localOffset.dy - wrapOffset.dy;
      words[i].width = size.width;
      words[i].height = size.height;
    }

    if (words.isNotEmpty) {
      words[0].wordRow = 0;
      for (int i = 1; i < words.length; i++) {
        words[i].wordRow = (words[i].y - words[i - 1].y).abs() > 2 ? words[i - 1].wordRow + 1 : words[i - 1].wordRow;
      }
    }
  }
}

class _SelectionBgPainter extends CustomPainter {
  final List<EnglishWord> words;
  final List<String> selectedWords;
  final Color backgroundColor;

  _SelectionBgPainter({
    required this.words,
    required this.selectedWords,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (words.isEmpty || selectedWords.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = backgroundColor;

    final selected = words.where((w) => selectedWords.contains(w.word)).toList();
    if (selected.isEmpty) return;

    final Map<int, List<EnglishWord>> byRow = {};
    for (final word in selected) {
      byRow.putIfAbsent(word.wordRow, () => []).add(word);
    }

    byRow.forEach((_, rowWords) {
      rowWords.sort((a, b) => a.index.compareTo(b.index));
      List<EnglishWord> seg = [];
      int? prevIdx;

      void drawSeg(List<EnglishWord> seg) {
        if (seg.isEmpty) return;
        final first = seg.first;
        final last = seg.last;
        final left = first.x - 2;
        final top = seg.map((w) => w.y).reduce((a, b) => a < b ? a : b);
        final bottom = seg.map((w) => w.y + w.height).reduce((a, b) => a > b ? a : b);
        const inset = 2;
        final right = last.x + last.width + 2;
        final rrect = RRect.fromLTRBR(left, top + inset, right, bottom - inset, const Radius.circular(6));
        canvas.drawRRect(rrect, paint);
      }

      for (final w in rowWords) {
        if (seg.isEmpty || (prevIdx != null && w.index == prevIdx + 1)) {
          seg.add(w);
        } else {
          drawSeg(seg);
          seg = [w];
        }
        prevIdx = w.index;
      }
      if (seg.isNotEmpty) drawSeg(seg);
    });
  }

  @override
  bool shouldRepaint(covariant _SelectionBgPainter oldDelegate) {
    return oldDelegate.selectedWords != selectedWords;
  }
}
