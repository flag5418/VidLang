import 'package:flutter/material.dart';

OverlayEntry? showAnchoredPopup({
  required BuildContext context,
  required GlobalKey anchorKey,
  required Widget child,
  bool dismissOnOutsideTap = true,
  void Function()? onDismiss,
}) {
  final overlay = Overlay.of(context);
  final renderBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null || !renderBox.attached) return null;

  final anchorPos = renderBox.localToGlobal(Offset.zero);
  final anchorSize = renderBox.size;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) {
      final screenHeight = MediaQuery.of(context).size.height;
      final popupBottom = screenHeight - anchorPos.dy + 8;
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismissOnOutsideTap
                  ? () {
                      onDismiss?.call();
                      entry.remove();
                    }
                  : null,
            ),
          ),
          Positioned(bottom: popupBottom, right: MediaQuery.of(context).size.width - anchorPos.dx - anchorSize.width, child: child),
        ],
      );
    },
  );

  overlay.insert(entry);
  return entry;
}
