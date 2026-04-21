import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/send_money/send_money_cubit.dart';

class SendMoneyAccountStep extends StatefulWidget {
  const SendMoneyAccountStep({super.key});

  @override
  State<SendMoneyAccountStep> createState() => _SendMoneyAccountStepState();
}

class _SendMoneyAccountStepState extends State<SendMoneyAccountStep> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    final s = (v ?? '').trim();
    if (s.length != 10) return 'Enter a 10-digit account number';
    if (!RegExp(r'^[0-9]{10}$').hasMatch(s)) return 'Digits only';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context
        .read<SendMoneyCubit>()
        .resolveAccount(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendMoneyCubit>().state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Who are you paying?',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter the recipient's 10-digit offline_pay account number.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                      decoration: const InputDecoration(
                        labelText: 'Account number',
                        border: OutlineInputBorder(),
                        hintText: '0123456789',
                      ),
                      validator: _validate,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          state.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: state.loading ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: state.loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
