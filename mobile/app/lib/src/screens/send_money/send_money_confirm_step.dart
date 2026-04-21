import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/app/app_cubit.dart';
import '../../presentation/cubits/send_money/send_money_cubit.dart';
import '../../presentation/cubits/send_money/send_money_state.dart';
import '../../util/money.dart';
import '../../widgets/pin_dots_field.dart';
import '../set_pin_screen.dart';
import '_send_money_widgets.dart';

class SendMoneyConfirmStep extends StatefulWidget {
  const SendMoneyConfirmStep({super.key});

  @override
  State<SendMoneyConfirmStep> createState() => _SendMoneyConfirmStepState();
}

class _SendMoneyConfirmStepState extends State<SendMoneyConfirmStep> {
  String _pin = '';

  bool _validPin(String v) => v.length == 4 || v.length == 6;

  void _submit() {
    if (!_validPin(_pin)) return;
    final amount = context.read<SendMoneyCubit>().state.amountKobo ?? 0;
    final available = context.read<AppCubit>().state.mainBalanceKobo;
    if (amount > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance — available ${formatNaira(available)}',
          ),
        ),
      );
      return;
    }
    final ref = generateTransferReference();
    context.read<SendMoneyCubit>().submit(ref, _pin);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendMoneyCubit>().state;
    final available = context.watch<AppCubit>().state.mainBalanceKobo;
    final recipient = state.recipient;
    final amount = state.amountKobo ?? 0;
    final insufficient = amount > available;
    final locked = state.lastPinOutcome == SendMoneyPinOutcome.locked;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: ListView(
        children: [
          if (recipient != null)
            SendMoneyRecipientBanner(
              maskedName: recipient.maskedName,
              accountNumber: recipient.accountNumber,
            ),
          const SizedBox(height: 24),
          Text(
            'Amount',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            formatNaira(amount),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 32),
          Text(
            'Transaction PIN',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          PinDotsField(
            length: 6,
            enabled: !state.loading && !locked,
            onChanged: (v) => setState(() => _pin = v),
            onSubmit: () {
              if (_validPin(_pin)) _submit();
            },
          ),
          if (insufficient) ...[
            const SizedBox(height: 12),
            Text(
              'Insufficient balance — available ${formatNaira(available)}',
              style: TextStyle(color: scheme.error),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(
              state.error!,
              style: TextStyle(color: scheme.error),
            ),
          ],
          if (state.lastPinOutcome == SendMoneyPinOutcome.notSet) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.lock_outline),
              label: const Text('Set transaction PIN'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SetPinScreen(),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (state.loading ||
                    locked ||
                    insufficient ||
                    !_validPin(_pin))
                ? null
                : _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: state.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Pay ${formatNaira(amount)}'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: state.loading
                ? null
                : () => context.read<SendMoneyCubit>().reset(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
