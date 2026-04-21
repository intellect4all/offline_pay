import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../presentation/cubits/kyc/kyc_cubit.dart';
import '../presentation/cubits/session/session_cubit.dart';
import '../repositories/kyc_repository.dart';
import '../util/time_format.dart';

class KycSubmitScreen extends StatefulWidget {
  final KycIdType initialIdType;
  const KycSubmitScreen({super.key, this.initialIdType = KycIdType.nin});

  @override
  State<KycSubmitScreen> createState() => _KycSubmitScreenState();
}

int _tierRank(String tier) {
  switch (tier) {
    case 'TIER_3':
      return 3;
    case 'TIER_2':
      return 2;
    case 'TIER_1':
      return 1;
    case 'TIER_0':
    default:
      return 0;
  }
}

class _KycSubmitScreenState extends State<KycSubmitScreen> {
  late KycIdType _idType;
  final _controller = TextEditingController();
  bool _successHandled = false;

  @override
  void initState() {
    super.initState();
    _idType = widget.initialIdType;
    final cubit = context.read<KycCubit>();
    cubit.clearResult();
    cubit.clearError();
    cubit.loadSubmissions();
    if (kDebugMode) {
      cubit.loadHint();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.length != 11 || int.tryParse(raw) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter 11 digits — no spaces or dashes.'),
        ),
      );
      return;
    }
    final cubit = context.read<KycCubit>();
    final result = await cubit.submit(idType: _idType, idNumber: raw);
    if (!mounted) return;
    if (result != null && result.verified) {
      _controller.clear();
      await _showSuccessAndPop(result);
    }
  }

  Future<void> _showSuccessAndPop(KycSubmission result) async {
    if (_successHandled) return;
    _successHandled = true;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (sheetCtx) => _SuccessSheet(result: result),
    );
    if (!mounted) return;
    context.read<KycCubit>().clearResult();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final currentTier = context.select<SessionCubit, String>(
      (c) => c.state.profile?.kycTier ?? 'TIER_1',
    );
    final targetRank = _tierRank(_idType.targetTier);
    final currentRank = _tierRank(currentTier);
    final alreadyCovered = currentRank >= targetRank;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade KYC'),
        centerTitle: false,
      ),
      body: BlocBuilder<KycCubit, KycUiState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _TargetTierCard(idType: _idType),
              const SizedBox(height: 20),
              _IdTypePicker(
                selected: _idType,
                onChanged: (v) => setState(() => _idType = v),
              ),
              const SizedBox(height: 16),
              if (alreadyCovered)
                _AlreadyCoveredBanner(
                  currentTier: currentTier,
                  idType: _idType,
                )
              else ...[
                _NumberField(
                  controller: _controller,
                  idType: _idType,
                ),
                if (kDebugMode && state.hint.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _HintRow(idType: _idType, hint: state.hint),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  _InlineAlert(
                    icon: Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    text: state.error!,
                  ),
                ],
                if (state.lastResult != null &&
                    !state.lastResult!.verified) ...[
                  const SizedBox(height: 12),
                  _ResultCard(result: state.lastResult!),
                ],
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: alreadyCovered
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Back to tiers'),
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    : FilledButton.icon(
                        icon: state.submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.shield_outlined),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            state.submitting
                                ? 'Submitting…'
                                : 'Submit ${_idType.label}',
                          ),
                        ),
                        onPressed: state.submitting ? null : _submit,
                      ),
              ),
              const SizedBox(height: 28),
              if (state.submissions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
                  child: Text(
                    'HISTORY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                for (final row in state.submissions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _HistoryTile(row: row),
                  ),
              ] else if (state.loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TargetTierCard extends StatelessWidget {
  final KycIdType idType;
  const _TargetTierCard({required this.idType});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final targetTier = idType.targetTier.replaceAll('TIER_', 'Tier ');
    final blurb = idType == KycIdType.nin
        ? 'A verified NIN unlocks ₦50,000 per transfer and ₦300,000 daily.'
        : 'A verified BVN unlocks unlimited transfers.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.onSecondaryContainer.withValues(alpha: 0.12),
            child: Icon(
              Icons.trending_up,
              color: scheme.onSecondaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrading to $targetTier',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  blurb,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdTypePicker extends StatelessWidget {
  final KycIdType selected;
  final ValueChanged<KycIdType> onChanged;
  const _IdTypePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<KycIdType>(
      segments: const [
        ButtonSegment(
          value: KycIdType.nin,
          label: Text('NIN'),
          icon: Icon(Icons.badge_outlined),
        ),
        ButtonSegment(
          value: KycIdType.bvn,
          label: Text('BVN'),
          icon: Icon(Icons.account_balance_outlined),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final KycIdType idType;
  const _NumberField({required this.controller, required this.idType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 11,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: '11-digit ${idType.label}',
        hintText: '• • • • • • • • • • •',
        prefixIcon: Icon(
          idType == KycIdType.bvn
              ? Icons.account_balance_outlined
              : Icons.badge_outlined,
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  final KycIdType idType;
  final Map<String, String> hint;
  const _HintRow({required this.idType, required this.hint});

  @override
  Widget build(BuildContext context) {
    final expected = hint[idType.wire] ?? hint[idType.label] ?? '';
    if (expected.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(
          Icons.build_outlined,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Dev hint: expected ${idType.label} is $expected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
          ),
        ),
      ],
    );
  }
}

class _InlineAlert extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InlineAlert({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final KycSubmission result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (result.verified) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.verified, color: scheme.onPrimaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verified — tier upgraded to ${result.tierGranted ?? result.idType.targetTier}',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your new limits apply immediately.',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return _InlineAlert(
      icon: Icons.cancel_outlined,
      color: scheme.error,
      text: result.rejectionReason ?? 'Submission rejected.',
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final KycSubmission row;
  const _HistoryTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verified = row.verified;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: verified
                ? scheme.primaryContainer
                : scheme.errorContainer,
            child: Icon(
              verified ? Icons.check : Icons.close,
              size: 16,
              color: verified
                  ? scheme.onPrimaryContainer
                  : scheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.idType.label} — ${verified ? (row.tierGranted ?? 'Verified') : 'Rejected'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  shortRelative(row.submittedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (!verified && row.rejectionReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    row.rejectionReason!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlreadyCoveredBanner extends StatelessWidget {
  final String currentTier;
  final KycIdType idType;
  const _AlreadyCoveredBanner({
    required this.currentTier,
    required this.idType,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final niceTier = currentTier.replaceAll('TIER_', 'Tier ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: scheme.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're already on $niceTier",
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your ${idType.label} is on file — nothing more to '
                  'submit at this level.',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  final KycSubmission result;
  const _SuccessSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final newTier = (result.tierGranted ?? result.idType.targetTier)
        .replaceAll('TIER_', 'Tier ');
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified,
                color: scheme.onPrimaryContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "You're now on $newTier",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${result.idType.label} is verified. The new '
              'transaction limits apply immediately.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
