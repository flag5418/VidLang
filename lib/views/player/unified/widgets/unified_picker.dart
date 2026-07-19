import 'package:flutter/material.dart';
import 'package:vidlang/theme/app_colors.dart';
import 'package:vidlang/utils/adaptive.dart' as adaptive;

/// 浮动弹出选择器（用于播放器控制栏）
///
/// 三种面板类型：
/// 1. **字号面板**：竖向滑块 + A-/A+ 标记
/// 2. **倍速面板**：竖向列表选择
/// 3. **循环模式面板**：竖向列表选择
///
/// 定位方式：通过按钮的 RenderBox 精确计算相对于按钮底部的位置。
/// 关闭方式：选中项后自动关闭 + 点击面板外部关闭。

// ═══════════════════════════════════════════════════════════
// 公共 API
// ═══════════════════════════════════════════════════════════

/// 字号面板回调：选中值 + 关闭
typedef FontSizeChanged = void Function(double value);

/// 倍速面板回调：选中值 + 关闭
typedef SpeedChanged = void Function(double value);

/// 循环模式面板回调：选中值 + 关闭
typedef LoopModeChanged = void Function(String value);

/// 显示字号面板
OverlayEntry showFontSizePanel(
  BuildContext context, {
  required double fontSize,
  required FontSizeChanged onChanged,
  required GlobalKey targetKey,
}) {
  final overlayState = Overlay.of(context);
  late final OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (ctx) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => overlayEntry.remove(),
          ),
        ),
        _FontSizeFloatingPanel(
          fontSize: fontSize,
          onChanged: onChanged,
          targetKey: targetKey,
          onDismiss: () => overlayEntry.remove(),
        ),
      ],
    ),
  );
  overlayState.insert(overlayEntry);
  return overlayEntry;
}

/// 显示倍速面板
OverlayEntry showSpeedPanel(
  BuildContext context, {
  required double currentSpeed,
  required List<double> speeds,
  required SpeedChanged onSelected,
  required GlobalKey targetKey,
}) {
  final overlayState = Overlay.of(context);
  late final OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (ctx) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => overlayEntry.remove(),
          ),
        ),
        _SpeedFloatingPanel(
          currentSpeed: currentSpeed,
          speeds: speeds,
          onSelected: onSelected,
          targetKey: targetKey,
          onDismiss: () => overlayEntry.remove(),
        ),
      ],
    ),
  );
  overlayState.insert(overlayEntry);
  return overlayEntry;
}

/// 显示循环模式面板
OverlayEntry showLoopPanel(
  BuildContext context, {
  required String currentMode,
  required List<Map<String, dynamic>> modes,
  required LoopModeChanged onSelected,
  required GlobalKey targetKey,
}) {
  final overlayState = Overlay.of(context);
  late final OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (ctx) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => overlayEntry.remove(),
          ),
        ),
        _LoopFloatingPanel(
          currentMode: currentMode,
          modes: modes,
          onSelected: onSelected,
          targetKey: targetKey,
          onDismiss: () => overlayEntry.remove(),
        ),
      ],
    ),
  );
  overlayState.insert(overlayEntry);
  return overlayEntry;
}

// ═══════════════════════════════════════════════════════════
// 字号面板：竖向滑块 + A-/A+
// ═══════════════════════════════════════════════════════════

class _FontSizeFloatingPanel extends StatefulWidget {
  final double fontSize;
  final FontSizeChanged onChanged;
  final GlobalKey targetKey;
  final VoidCallback onDismiss;

  const _FontSizeFloatingPanel({
    required this.fontSize,
    required this.onChanged,
    required this.targetKey,
    required this.onDismiss,
  });

  @override
  State<_FontSizeFloatingPanel> createState() => _FontSizeFloatingPanelState();
}

class _FontSizeFloatingPanelState extends State<_FontSizeFloatingPanel> {
  late double _currentSize;

  @override
  void initState() {
    super.initState();
    _currentSize = widget.fontSize;
  }

  @override
  void didUpdateWidget(covariant _FontSizeFloatingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize) {
      setState(() => _currentSize = widget.fontSize);
    }
  }

  Offset _calculatePosition() {
    final renderBox = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset(0, 0);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final panelWidth = adaptive.Adaptive.w(48);
    final panelHeight = adaptive.Adaptive.h(200);
    final safePadding = MediaQuery.of(context).padding;
    return Offset(
      position.dx + (renderBox.size.width - panelWidth) / 2,
      position.dy - panelHeight - safePadding.top,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = _calculatePosition();
    final panelWidth = adaptive.Adaptive.w(48);
    final panelHeight = adaptive.Adaptive.h(200);
    final safePadding = MediaQuery.of(context).padding;

    return Positioned(
      left: pos.dx,
      top: pos.dy + safePadding.bottom,
      child: _PanelWrapper(
        onDismiss: widget.onDismiss,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          color: const Color(0xFF1A1A1A),
          child: Container(
            width: panelWidth,
            height: panelHeight,
            padding: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'A',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(20),
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFB0B0B0),
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(6)),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: const Color(0xFF3A3A3C),
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        value: _currentSize.clamp(10.0, 36.0),
                        min: 10,
                        max: 36,
                        divisions: 26,
                        onChanged: (v) {
                          setState(() => _currentSize = v);
                          widget.onChanged(v);
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(6)),
                Text(
                  'A',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(12),
                    color: const Color(0xFFB0B0B0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 倍速面板：竖向列表选择
// ═══════════════════════════════════════════════════════════

class _SpeedFloatingPanel extends StatefulWidget {
  final double currentSpeed;
  final List<double> speeds;
  final SpeedChanged onSelected;
  final GlobalKey targetKey;
  final VoidCallback onDismiss;

  const _SpeedFloatingPanel({
    required this.currentSpeed,
    required this.speeds,
    required this.onSelected,
    required this.targetKey,
    required this.onDismiss,
  });

  @override
  State<_SpeedFloatingPanel> createState() => _SpeedFloatingPanelState();
}

class _SpeedFloatingPanelState extends State<_SpeedFloatingPanel> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.speeds.indexOf(widget.currentSpeed);
    if (_selectedIndex < 0) _selectedIndex = widget.speeds.length ~/ 2;
  }

  @override
  void didUpdateWidget(covariant _SpeedFloatingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSpeed != widget.currentSpeed) {
      final idx = widget.speeds.indexOf(widget.currentSpeed);
      if (idx >= 0) setState(() => _selectedIndex = idx);
    }
  }

  void _selectItem(int index) {
    setState(() => _selectedIndex = index);
    widget.onSelected(widget.speeds[index]);
    widget.onDismiss();
  }

  Offset _calculatePosition() {
    final renderBox = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset(0, 0);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final panelWidth = adaptive.Adaptive.w(90);
    final panelHeight = widget.speeds.length * adaptive.Adaptive.h(40) + adaptive.Adaptive.h(36);
    final safePadding = MediaQuery.of(context).padding;
    return Offset(
      position.dx + (renderBox.size.width - panelWidth) / 2,
      position.dy - panelHeight - safePadding.top,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = _calculatePosition();
    final panelWidth = adaptive.Adaptive.w(90);
    final panelHeight = widget.speeds.length * adaptive.Adaptive.h(40) + adaptive.Adaptive.h(36);
    final safePadding = MediaQuery.of(context).padding;

    return Positioned(
      left: pos.dx,
      top: pos.dy + safePadding.bottom,
      child: _PanelWrapper(
        onDismiss: widget.onDismiss,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          color: const Color(0xFF1A1A1A),
          child: Container(
            width: panelWidth,
            height: panelHeight,
            padding: EdgeInsets.symmetric(
              vertical: adaptive.Adaptive.h(6),
              horizontal: adaptive.Adaptive.w(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '倍速',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(12),
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(4)),
                ...widget.speeds.asMap().entries.map((entry) {
                  final index = entry.key;
                  final speed = entry.value;
                  final isSelected = index == _selectedIndex;
                  // 1.0x 不显示 "(正常)"
                  final label = speed == 1.0 ? '1.0x' : '${speed.toStringAsFixed(2)}x';

                  return GestureDetector(
                    onTap: () => _selectItem(index),
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(2)),
                      padding: EdgeInsets.symmetric(
                        horizontal: adaptive.Adaptive.w(8),
                        vertical: adaptive.Adaptive.h(6),
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(12),
                          color: isSelected ? AppColors.primary : const Color(0xFFCCCCCC),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 循环模式面板：竖向列表选择
// ═══════════════════════════════════════════════════════════

class _LoopFloatingPanel extends StatefulWidget {
  final String currentMode;
  final List<Map<String, dynamic>> modes;
  final LoopModeChanged onSelected;
  final GlobalKey targetKey;
  final VoidCallback onDismiss;

  const _LoopFloatingPanel({
    required this.currentMode,
    required this.modes,
    required this.onSelected,
    required this.targetKey,
    required this.onDismiss,
  });

  @override
  State<_LoopFloatingPanel> createState() => _LoopFloatingPanelState();
}

class _LoopFloatingPanelState extends State<_LoopFloatingPanel> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.modes.indexWhere((m) => m['value'] == widget.currentMode);
    if (_selectedIndex < 0) _selectedIndex = 0;
  }

  @override
  void didUpdateWidget(covariant _LoopFloatingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMode != widget.currentMode) {
      final idx = widget.modes.indexWhere((m) => m['value'] == widget.currentMode);
      if (idx >= 0) setState(() => _selectedIndex = idx);
    }
  }

  void _selectItem(int index) {
    setState(() => _selectedIndex = index);
    widget.onSelected(widget.modes[index]['value'] as String);
    widget.onDismiss();
  }

  Offset _calculatePosition() {
    final renderBox = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset(0, 0);
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final panelWidth = adaptive.Adaptive.w(100);
    final panelHeight = widget.modes.length * adaptive.Adaptive.h(40) + adaptive.Adaptive.h(36);
    final safePadding = MediaQuery.of(context).padding;
    return Offset(
      position.dx + (renderBox.size.width - panelWidth) / 2,
      position.dy - panelHeight - safePadding.top,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = _calculatePosition();
    final panelWidth = adaptive.Adaptive.w(100);
    final panelHeight = widget.modes.length * adaptive.Adaptive.h(40) + adaptive.Adaptive.h(36);
    final safePadding = MediaQuery.of(context).padding;

    return Positioned(
      left: pos.dx,
      top: pos.dy + safePadding.bottom,
      child: _PanelWrapper(
        onDismiss: widget.onDismiss,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(adaptive.Adaptive.r(12)),
          color: const Color(0xFF1A1A1A),
          child: Container(
            width: panelWidth,
            height: panelHeight,
            padding: EdgeInsets.symmetric(
              vertical: adaptive.Adaptive.h(6),
              horizontal: adaptive.Adaptive.w(6),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '循环',
                  style: TextStyle(
                    fontSize: adaptive.Adaptive.sp(12),
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: adaptive.Adaptive.h(4)),
                ...widget.modes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final mode = entry.value;
                  final isSelected = index == _selectedIndex;
                  final label = mode['label'] as String;

                  return GestureDetector(
                    onTap: () => _selectItem(index),
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: adaptive.Adaptive.h(2)),
                      padding: EdgeInsets.symmetric(
                        horizontal: adaptive.Adaptive.w(8),
                        vertical: adaptive.Adaptive.h(6),
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(adaptive.Adaptive.r(6)),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: adaptive.Adaptive.sp(12),
                          color: isSelected ? AppColors.primary : const Color(0xFFCCCCCC),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 面板包装器：提供"点击外部关闭"功能
// ═══════════════════════════════════════════════════════════

/// 在面板周围包裹一层透明触控区域，点击面板外部即可关闭。
///
/// 原理：用 Listener 捕获整个屏幕的 tap，
/// 如果点击位置不在面板区域内，则触发 onDismiss。
class _PanelWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const _PanelWrapper({
    required this.child,
    required this.onDismiss,
  });

  @override
  State<_PanelWrapper> createState() => _PanelWrapperState();
}

class _PanelWrapperState extends State<_PanelWrapper> {
  final GlobalKey _panelKey = GlobalKey();

  void _onPointerDown(PointerDownEvent event) {
    final panelBox = _panelKey.currentContext?.findRenderObject() as RenderBox?;
    if (panelBox != null) {
      final panelRect = panelBox.localToGlobal(Offset.zero) & panelBox.size;
      if (!panelRect.contains(event.position)) {
        widget.onDismiss();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      child: Container(
        key: _panelKey,
        child: widget.child,
      ),
    );
  }
}
