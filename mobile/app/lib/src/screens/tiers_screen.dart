import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/cubits/session/session_cubit.dart';
import '../repositories/kyc_repository.dart';
import '../util/money.dart';
import 'kyc_submit_screen.dart';

class TiersScreen extends StatelessWidget {
  const TiersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.select<SessionCubit, String?>(
      (c) => c.state.profile?.kycTier,
    );
    final currentTier = profile ?? _Tier.tier1.id;
    final current = _Tier.byId(currentTier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction limits'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _CurrentTierBanner(tier: current),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Text(
              'ALL TIERS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          for (final tier in _Tier.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TierCard(
                tier: tier,
                isCurrent: tier.id == current.id,
                isUnlocked: tier.rank <= current.rank,
                onUpgrade: tier.rank > current.rank && tier.requiredIdType != null
                    ? () => _openSubmit(context, tier.requiredIdType!)
                    : null,
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Limits apply to online transfers. Offline payments draw '
              'from your offline wallet up to the amount you already '
              'funded.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSubmit(BuildContext context, KycIdType idType) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KycSubmitScreen(initialIdType: idType),
      ),
    );
  }
}

class _Tier {
  final String id;
  final int rank;
  final String title;
  final String summary;
  final int singleKobo;
  final int dailyKobo;
  final String requiresLabel;
  final KycIdType? requiredIdType;

  const _Tier({
    required this.id,
    required this.rank,
    required this.title,
    required this.summary,
    required this.singleKobo,
    required this.dailyKobo,
    required this.requiresLabel,
    required this.requiredIdType,
  });

  static const _Tier tier1 = _Tier(
    id: 'TIER_1',
    rank: 1,
    title: 'Tier 1',
    summary: 'Default for every new account.',
    singleKobo: 1000000,
    dailyKobo: 3000000,
    requiresLabel: 'Phone, name, email',
    requiredIdType: null,
  );

  static const _Tier tier2 = _Tier(
    id: 'TIER_2',
    rank: 2,
    title: 'Tier 2',
    summary: 'Higher limits for verified identities.',
    singleKobo: 5000000,
    dailyKobo: 30000000,
    requiresLabel: 'NIN',
    requiredIdType: KycIdType.nin,
  );

  static const _Tier tier3 = _Tier(
    id: 'TIER_3',
    rank: 3,
    title: 'Tier 3',
    summary: 'Unlimited transfers.',
    singleKobo: -1,
    dailyKobo: -1,
    requiresLabel: 'BVN',
    requiredIdType: KycIdType.bvn,
  );

  static const _Tier tier0 = _Tier(
    id: 'TIER_0',
    rank: 0,
    title: 'Tier 0',
    summary: 'Legacy accounts without a profile. Cannot send.',
    singleKobo: 0,
    dailyKobo: 0,
    requiresLabel: '—',
    requiredIdType: null,
  );

  static const List<_Tier> all = [tier1, tier2, tier3];

  static _Tier byId(String id) {
    switch (id) {
      case 'TIER_0':
        return tier0;
      case 'TIER_2':
        return tier2;
      case 'TIER_3':
        return tier3;
      case 'TIER_1':
      default:
        return tier1;
    }
  }
}

String _formatLimit(int kobo) {
  if (kobo < 0) return 'Unlimited';
  if (kobo == 0) return 'Blocked';
  return formatNaira(kobo);
}

class _CurrentTierBanner extends StatelessWidget {
  final _Tier tier;
  const _CurrentTierBanner({required this.tier});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR TIER',
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.8),
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tier.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            tier.summary,
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LimitChip(
                label: 'Per transfer',
                value: _formatLimit(tier.singleKobo),
                foreground: scheme.onPrimary,
              ),
              _LimitChip(
                label: 'Daily',
                value: _formatLimit(tier.dailyKobo),
                foreground: scheme.onPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimitChip extends StatelessWidget {
  final String label;
  final String value;
  final Color foreground;
  const _LimitChip({
    required this.label,
    required this.value,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final _Tier tier;
  final bool isCurrent;
  final bool isUnlocked;
  final VoidCallback? onUpgrade;
  const _TierCard({
    required this.tier,
    required this.isCurrent,
    required this.isUnlocked,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = isCurrent
        ? Border.all(color: scheme.primary, width: 2)
        : Border.all(color: scheme.outlineVariant);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusBadge(isCurrent: isCurrent, isUnlocked: isUnlocked),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tier.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                'Requires ${tier.requiresLabel}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tier.summary,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LimitRow(
                  label: 'Per transfer',
                  value: _formatLimit(tier.singleKobo),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LimitRow(
                  label: 'Daily',
                  value: _formatLimit(tier.dailyKobo),
                ),
              ),
            ],
          ),
          if (onUpgrade != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.shield_outlined, size: 18),
                onPressed: onUpgrade,
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Upgrade with ${tier.requiresLabel}'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isCurrent;
  final bool isUnlocked;
  const _StatusBadge({required this.isCurrent, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg, icon) = isCurrent
        ? ('Current', scheme.primary, scheme.onPrimary, Icons.check)
        : isUnlocked
            ? (
                'Unlocked',
                scheme.secondaryContainer,
                scheme.onSecondaryContainer,
                Icons.check_circle,
              )
            : (
                'Locked',
                scheme.surfaceContainerHighest,
                scheme.onSurfaceVariant,
                Icons.lock_outline,
              );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  final String label;
  final String value;
  const _LimitRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
