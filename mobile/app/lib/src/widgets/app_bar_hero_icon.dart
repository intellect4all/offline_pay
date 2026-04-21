import 'package:flutter/material.dart';

class AppBarHeroIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const AppBarHeroIcon({
    super.key,
    required this.icon,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: scheme.primary, size: size * 0.5),
    );
  }
}
