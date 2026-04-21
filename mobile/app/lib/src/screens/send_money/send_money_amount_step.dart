import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/app/app_cubit.dart';
import '../../presentation/cubits/send_money/send_money_cubit.dart';
import '../../util/money.dart';
import '_send_money_widgets.dart';

const _quickAmountsKobo = <int>[100000, 500000, 100000000, 500000000];

class SendMoneyAmountStep extends StatefulWidget {
  const SendMoneyAmountStep({super.key});

  @override
  State<SendMoneyAmountStep> createState() => _SendMoneyAmountStepState();
}

class _SendMoneyAmountStepState extends State<SendMoneyAmountStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _kobo => parseNairaToKobo(_controller.text.trim());

  String? _error(int availableKobo) {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return null;
    final k = parseNairaToKobo(raw);
    if (k == null) return 'Invalid amount';
    if (k <= 0) return 'Amount must be positive';
    if (k > availableKobo) {
      return 'Insufficient balance — available ${formatNaira(availableKobo)}';
    }
    return null;
  }

  void _continue(int availableKobo) {
    final kobo = _kobo;
    if (kobo == null || kobo <= 0) return;
    if (kobo > availableKobo) return;
    context.read<SendMoneyCubit>().setAmount(kobo);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendMoneyCubit>().state;
    final availableKobo = context.watch<AppCubit>().state.mainBalanceKobo;
    final recipient = state.recipient;
    final kobo = _kobo;
    final error = _error(availableKobo);
    return LayoutBuilder(
      builder: (_, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (recipient != null)
                    SendMoneyRecipientBanner(
                      maskedName: recipient.maskedName,
                      accountNumber: recipient.accountNumber,
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'How much?',
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Available ${formatNaira(availableKobo)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  _AmountField(
                    controller: _controller,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final k in _quickAmountsKobo)
                        ActionChip(
                          label: Text(formatNaira(k)),
                          onPressed: () {
                            _controller.text = _koboToEditField(k);
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: (kobo != null &&
                            kobo > 0 &&
                            kobo <= availableKobo)
                        ? () => _continue(availableKobo)
                        : null,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Review'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _koboToEditField(int kobo) {
    final whole = kobo ~/ 100;
    final fraction = kobo % 100;
    if (fraction == 0) return '$whole';
    return '$whole.${fraction.toString().padLeft(2, '0')}';
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _AmountField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '₦',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: onChanged,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            decoration: const InputDecoration(
              hintText: '0.00',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
