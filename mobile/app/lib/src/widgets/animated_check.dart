import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedCheck extends StatefulWidget {
  final double size;
  final Color? circleColor;
  final Color? checkColor;
  final Duration duration;

  const AnimatedCheck({
    super.key,
    this.size = 96,
    this.circleColor,
    this.checkColor,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final circle = widget.circleColor ?? scheme.primary;
    final check = widget.checkColor ?? scheme.onPrimary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _CheckPainter(
            progress: _controller.value,
            circle: circle,
            check: check,
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color circle;
  final Color check;
  _CheckPainter({
    required this.progress,
    required this.circle,
    required this.check,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final t1 = math.min(1.0, progress / 0.5);
    final eased = _overshoot(t1);
    final radius = (size.width / 2) * eased;
    if (radius > 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = circle,
      );
    }

    final t2 = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
    if (t2 <= 0) return;

    final w = size.width;
    final h = size.height;
    final p1 = Offset(w * 0.28, h * 0.52);
    final p2 = Offset(w * 0.45, h * 0.68);
    final p3 = Offset(w * 0.74, h * 0.38);
    final seg1 = (p2 - p1).distance;
    final seg2 = (p3 - p2).distance;
    final total = seg1 + seg2;
    final drawn = total * Curves.easeOut.transform(t2);

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= seg1) {
      final k = drawn / seg1;
      final cur = Offset.lerp(p1, p2, k)!;
      path.lineTo(cur.dx, cur.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final k = ((drawn - seg1) / seg2).clamp(0.0, 1.0);
      final cur = Offset.lerp(p2, p3, k)!;
      path.lineTo(cur.dx, cur.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = check
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  double _overshoot(double t) {
    if (t < 0.7) return Curves.easeOutBack.transform(t / 0.7);
    final extra = (t - 0.7) / 0.3;
    return 1.05 - 0.05 * extra;
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress || old.circle != circle || old.check != check;
}
