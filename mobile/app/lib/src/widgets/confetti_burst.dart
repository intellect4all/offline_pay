import 'dart:math' as math;

import 'package:flutter/material.dart';

class ConfettiBurst extends StatefulWidget {
  final Object? trigger;
  final int particleCount;
  final Duration duration;

  const ConfettiBurst({
    super.key,
    required this.trigger,
    this.particleCount = 48,
    this.duration = const Duration(milliseconds: 1600),
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  List<_Particle> _particles = const [];
  Object? _lastTrigger;

  bool _fired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fired && widget.trigger != null) {
      _fired = true;
      _fire();
    }
  }

  @override
  void didUpdateWidget(covariant ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.trigger != _lastTrigger && widget.trigger != null) {
      _fire();
    }
  }

  void _fire() {
    _lastTrigger = widget.trigger;
    final rng = math.Random(widget.trigger.hashCode);
    final scheme = Theme.of(context).colorScheme;
    final palette = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      Colors.amber.shade400,
      Colors.pink.shade300,
    ];
    _particles = List<_Particle>.generate(widget.particleCount, (_) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 1.1;
      final speed = 340 + rng.nextDouble() * 260;
      return _Particle(
        angle: angle,
        speed: speed,
        color: palette[rng.nextInt(palette.length)],
        spin: (rng.nextDouble() - 0.5) * 8,
        size: 6 + rng.nextDouble() * 6,
        drift: (rng.nextDouble() - 0.5) * 60,
      );
    });
    _c
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          if (_c.isDismissed) return const SizedBox.shrink();
          return CustomPaint(
            painter: _ConfettiPainter(
              t: _c.value,
              particles: _particles,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final Color color;
  final double spin;
  final double size;
  final double drift;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.spin,
    required this.size,
    required this.drift,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<_Particle> particles;
  _ConfettiPainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.4);
    const gravity = 900.0;
    const seconds = 1.2;
    final elapsed = t * seconds;
    for (final p in particles) {
      final dx = origin.dx + math.cos(p.angle) * p.speed * elapsed + p.drift * elapsed;
      final dy = origin.dy +
          math.sin(p.angle) * p.speed * elapsed +
          0.5 * gravity * elapsed * elapsed;
      if (dy > size.height + 20) continue;
      final opacity = (1 - t).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.spin * elapsed);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size,
        height: p.size * 0.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.t != t || old.particles != particles;
}
