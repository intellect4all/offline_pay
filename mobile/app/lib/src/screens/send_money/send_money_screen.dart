import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/send_money/send_money_cubit.dart';
import '../../presentation/cubits/send_money/send_money_state.dart';
import '../../util/biometric.dart';
import '../../widgets/app_bar_hero_icon.dart';
import '_send_money_widgets.dart';
import 'send_money_account_step.dart';
import 'send_money_amount_step.dart';
import 'send_money_confirm_step.dart';
import 'send_money_result_step.dart';

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _BiometricGatePlaceholder extends StatelessWidget {
  const _BiometricGatePlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fingerprint, size: 72, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            'Waiting for biometric check\u2026',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  bool _gateOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<SendMoneyCubit>().reset();
      final ok = await Biometric.confirm(
        reason: 'Confirm it\u2019s you to send money',
      );
      if (!mounted) return;
      if (ok) {
        setState(() => _gateOpen = true);
      } else {
        unawaited(Navigator.of(context).maybePop());
      }
    });
  }

  static const _labels = ['Account', 'Amount', 'Confirm'];

  int _currentFromStep(SendMoneyStep step) {
    switch (step) {
      case SendMoneyStep.enterAccount:
        return 1;
      case SendMoneyStep.enterAmount:
        return 2;
      case SendMoneyStep.confirming:
      case SendMoneyStep.polling:
      case SendMoneyStep.done:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendMoneyCubit>().state;
    final Widget body;
    switch (state.step) {
      case SendMoneyStep.enterAccount:
        body = const SendMoneyAccountStep();
        break;
      case SendMoneyStep.enterAmount:
        body = const SendMoneyAmountStep();
        break;
      case SendMoneyStep.confirming:
        body = const SendMoneyConfirmStep();
        break;
      case SendMoneyStep.polling:
      case SendMoneyStep.done:
        body = const SendMoneyResultStep();
        break;
    }
    final terminal = state.step == SendMoneyStep.polling ||
        state.step == SendMoneyStep.done;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send money'),
        centerTitle: false,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: Hero(
                tag: 'hero-send-money',
                child: AppBarHeroIcon(icon: Icons.north_east),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: !_gateOpen
            ? const _BiometricGatePlaceholder()
            : Column(
                children: [
                  if (!terminal)
                    SendMoneySteps(
                      current: _currentFromStep(state.step),
                      total: _labels.length,
                      labels: _labels,
                    ),
                  Expanded(child: body),
                ],
              ),
      ),
    );
  }
}
