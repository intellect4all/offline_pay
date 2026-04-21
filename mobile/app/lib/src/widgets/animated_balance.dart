import 'package:flutter/material.dart';

import '../util/money.dart';

class AnimatedBalance extends StatelessWidget {
  final int amountKobo;
  final TextStyle? style;
  final Duration duration;

  const AnimatedBalance({
    super.key,
    required this.amountKobo,
    this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: Curves.easeOutCubic,
      tween: Tween<double>(end: amountKobo.toDouble()),
      builder: (_, value, __) => Text(
        formatNaira(value.round()),
        style: style,
      ),
    );
  }
}
