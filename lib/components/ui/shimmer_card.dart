import 'package:flutter/material.dart';

/// 骨架屏组件——用于加载态。
///
/// 使用 AnimationController + 渐变扫光实现 shimmer 效果。
/// 品牌色淡光（#4ADE80 alpha 0.3）扫过灰色占位块。
/// 扫光动画 1.2s 循环，easeInOut。

class ShimmerCard extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerCard({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 14.0,
  });

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E5E5),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _ShimmerPainter(_animation.value),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double position;

  _ShimmerPainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = LinearGradient(
      begin: Alignment(position - 0.5, 0),
      end: Alignment(position + 0.5, 0),
      colors: const [
        Color(0x00E5E5E5),
        Color(0x4D4ADE80),
        Color(0x00E5E5E5),
      ],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) => oldDelegate.position != position;
}

/// 模拟视频卡片布局的骨架屏。
class ShimmerVideoCard extends StatelessWidget {
  const ShimmerVideoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const ShimmerCard(height: 100.0, borderRadius: 14.0),
        const SizedBox(height: 10.0),
        const ShimmerCard(height: 16.0, borderRadius: 4.0),
        const SizedBox(height: 6.0),
        ShimmerCard(
          height: 12.0,
          width: 120.0,
          borderRadius: 4.0,
        ),
      ],
    );
  }
}
