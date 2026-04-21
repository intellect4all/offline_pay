import 'package:flutter/material.dart';

class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius radius;

  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = const BorderRadius.all(Radius.circular(8)),
  });

  const Skeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = const BorderRadius.all(Radius.circular(999));

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.06),
      base,
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return ClipRRect(
          borderRadius: widget.radius,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _ShimmerPainter(
                t: _c.value,
                base: base,
                highlight: highlight,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double t;
  final Color base;
  final Color highlight;
  _ShimmerPainter({
    required this.t,
    required this.base,
    required this.highlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);
    final bandWidth = size.width * 0.45;
    final shift = (t * (size.width + bandWidth)) - bandWidth;
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [base, highlight, base],
      stops: const [0, 0.5, 1],
    ).createShader(
      Rect.fromLTWH(shift, 0, bandWidth, size.height),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.srcOver,
    );
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) =>
      old.t != t || old.base != base || old.highlight != highlight;
}
