import 'package:flutter/material.dart';

/// 英文划词组件 — 参考 deepenglish_pad 的 subtitles_widget.dart
/// 使用 Listener(onPointerDown/Move/Up) 实现低层级划词，不与其他手势冲突
class SelectableEnglishLine extends StatefulWidget {
  final String text;
  final double fontSize;
  final void Function(List<String> selectedWords)? onSelectionChanged;
  final void Function()? onStartSelection;
  final Color fontColor;
  final Color selectedBgColor;

  const SelectableEnglishLine({
    super.key,
    required this.text,
    required this.fontSize,
    this.onSelectionChanged,
    this.onStartSelection,
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
  bool _isCheckd = false;
  List<String> _checkKeys = [];
  String? _subtitleItemModel;
  int? _dragStartGlobalIdx;
  final GlobalKey _wrapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateWordPositions());
  }

  @override
  void didUpdateWidget(covariant SelectableEnglishLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      //_cachedWords = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateWordPositions());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();
    final words = _splitWords(widget.text);

    return Listener(
      onPointerMove: (event) {
        if (!_isCheckd) return;
        final targetRenderBox = _wrapKey.currentContext?.findRenderObject() as RenderBox?;
        if (targetRenderBox == null) return;
        final localPos = targetRenderBox.globalToLocal(event.position);

        for (int s = 0; s < words.length; s++) {
          final w = words[s];
          if (localPos.dx >= w.x && localPos.dx <= w.x + w.width &&
              localPos.dy >= w.y && localPos.dy <= w.y + w.height) {
            if (_subtitleItemModel == null) {
              _subtitleItemModel = w.word;
              _dragStartGlobalIdx = w.index;
              _checkKeys = [w.word];
            } else if (_dragStartGlobalIdx != null) {
              final start = _dragStartGlobalIdx! < w.index ? _dragStartGlobalIdx! : w.index;
              final end = _dragStartGlobalIdx! < w.index ? w.index : _dragStartGlobalIdx!;
              final newKeys = words.sublist(start, end + 1).map((e) => e.word).toList();
              if (_checkKeys.join('') != newKeys.join('')) {
                setState(() => _checkKeys = newKeys);
              }
            }
            break;
          }
        }
      },
      onPointerDown: (event) {
        Future.delayed(const Duration(milliseconds: 50), () {
          setState(() {
            _isCheckd = true;
            _subtitleItemModel = null;
            _dragStartGlobalIdx = null;
            _checkKeys = [];
          });
        });
      },
      onPointerUp: (event) {
        if (_isCheckd && _checkKeys.isNotEmpty) {
          widget.onSelectionChanged?.call(_checkKeys);
        }
        setState(() {
          _isCheckd = false;
          _checkKeys = [];
          _subtitleItemModel = null;
          _dragStartGlobalIdx = null;
        });
      },
      child: Stack(
        children: [
          CustomPaint(
            painter: _SelectionBgPainter(
              words: words,
              selectedWords: _checkKeys,
              backgroundColor: widget.selectedBgColor,
            ),
          ),
          Wrap(
            key: _wrapKey,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: words.map((w) {
              final isSel = _checkKeys.contains(w.word);
              return Container(
                key: w.containerKey,
                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 0),
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                child: Text(
                  w.word,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    fontWeight: FontWeight.bold,
                    color: isSel ? Colors.black : widget.fontColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<EnglishWord> _splitWords(String text) {
    final raw = text.split(RegExp(r'(\s+)'));
    return List.generate(raw.length, (i) => EnglishWord(word: raw[i], index: i));
  }

  void _updateWordPositions() {
    final wrapRenderBox = _wrapKey.currentContext?.findRenderObject() as RenderBox?;
    if (wrapRenderBox == null) return;
    final words = _splitWords(widget.text);
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

    //_cachedWords = words;
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
    final paint = Paint()..style = PaintingStyle.fill..color = backgroundColor;

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
        final left = first.x;
        final top = seg.map((w) => w.y).reduce((a, b) => a < b ? a : b);
        final bottom = seg.map((w) => w.y + w.height).reduce((a, b) => a > b ? a : b);
        const inset = 2;
        final right = last.x + last.width;
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
