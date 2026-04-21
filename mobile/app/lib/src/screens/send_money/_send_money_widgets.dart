import 'package:flutter/material.dart';

class SendMoneySteps extends StatelessWidget {
  final int current;
  final int total;
  final List<String> labels;
  const SendMoneySteps({
    super.key,
    required this.current,
    required this.total,
    required this.labels,
  }) : assert(labels.length == total);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < current ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: i < current
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          fontWeight:
                              i == current - 1 ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            if (i < total - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class SendMoneyRecipientBanner extends StatelessWidget {
  final String maskedName;
  final String accountNumber;
  const SendMoneyRecipientBanner({
    super.key,
    required this.maskedName,
    required this.accountNumber,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = _initials(maskedName);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              initials,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maskedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  accountNumber,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '·';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
