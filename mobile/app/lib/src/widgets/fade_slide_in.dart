import 'package:flutter/material.dart';

class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 380),
    this.delay = Duration.zero,
    this.offset = 12,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  double _t = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: _t),
      builder: (_, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * widget.offset),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
