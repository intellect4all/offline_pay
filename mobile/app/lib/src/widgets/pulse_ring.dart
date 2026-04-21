import 'package:flutter/material.dart';

class PulseRing extends StatefulWidget {
  final double size;
  final Widget child;
  final Color? color;
  final double maxRadiusFactor;
  final Duration duration;

  const PulseRing({
    super.key,
    required this.size,
    required this.child,
    this.color,
    this.maxRadiusFactor = 1.8,
    this.duration = const Duration(milliseconds: 1600),
  });

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final t = _controller.value;
        final tLag = (t + 0.5) % 1.0;
        return SizedBox(
          width: widget.size * widget.maxRadiusFactor,
          height: widget.size * widget.maxRadiusFactor,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _ring(t, color),
              _ring(tLag, color),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }

  Widget _ring(double t, Color color) {
    final scale = 1 + (widget.maxRadiusFactor - 1) * t;
    final opacity = (1 - t).clamp(0.0, 1.0) * 0.4;
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
            ),
          ),
        ),
      ),
    );
  }
}
