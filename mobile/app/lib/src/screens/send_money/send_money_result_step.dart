import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/send_money/send_money_cubit.dart';
import '../../presentation/cubits/send_money/send_money_state.dart';
import '../../repositories/transfer_repository.dart';
import '../../util/haptics.dart';
import '../../util/money.dart';
import '../../widgets/animated_check.dart';
import '../../widgets/confetti_burst.dart';

class SendMoneyResultStep extends StatefulWidget {
  const SendMoneyResultStep({super.key});

  @override
  State<SendMoneyResultStep> createState() => _SendMoneyResultStepState();
}

class _SendMoneyResultStepState extends State<SendMoneyResultStep> {
  bool _hapticsFired = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendMoneyCubit>().state;
    final scheme = Theme.of(context).colorScheme;
    final polling = state.step == SendMoneyStep.polling;
    final result = state.result;

    if (polling) {
      return _Centered(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Processing transfer…',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            result == null ? 'Submitting…' : 'Status: ${result.status.name}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      );
    }

    final failed = state.error != null ||
        (result != null && result.status == TransferStatus.failed);
    final succeeded =
        !failed && result != null && result.status == TransferStatus.settled;
    final pendingStill = !failed && !succeeded;

    if (!_hapticsFired) {
      if (succeeded) {
        _hapticsFired = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => Haptics.success());
      } else if (failed) {
        _hapticsFired = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => Haptics.error());
      }
    }

    final IconData icon;
    final Color bg;
    final Color fg;
    final String title;
    final String subtitle;

    if (failed) {
      icon = Icons.error_outline;
      bg = scheme.errorContainer;
      fg = scheme.error;
      title = 'Transfer failed';
      subtitle = state.error ?? result?.failureReason ?? 'Unknown error';
    } else if (succeeded) {
      icon = Icons.check_circle_outline;
      bg = scheme.primaryContainer;
      fg = scheme.primary;
      title = 'Transfer successful';
      subtitle = 'Sent ${formatNaira(result.amountKobo)} to '
          '${result.receiverAccountNumber}';
    } else {
      icon = Icons.schedule;
      bg = scheme.tertiaryContainer;
      fg = scheme.tertiary;
      title = 'Transfer pending';
      subtitle = 'Still processing. Check Activity for the final status.';
    }

    return Stack(
      children: [
        _Centered(
          children: [
            if (succeeded)
              const AnimatedCheck(size: 96)
            else
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 52, color: fg),
              ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  context.read<SendMoneyCubit>().reset();
                  Navigator.of(context).pop();
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Done'),
                ),
              ),
            ),
            if (pendingStill || failed) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.read<SendMoneyCubit>().reset(),
                child: const Text('Send another'),
              ),
            ],
          ],
        ),
        if (succeeded)
          Positioned.fill(
            child: ConfettiBurst(trigger: result.id),
          ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  final List<Widget> children;
  const _Centered({required this.children});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}
