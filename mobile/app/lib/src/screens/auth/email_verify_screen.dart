import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/session/session_cubit.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/pin_dots_field.dart';

class EmailVerifyScreen extends StatefulWidget {
  const EmailVerifyScreen({super.key});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  Key _fieldKey = UniqueKey();
  String _code = '';
  bool _busy = false;
  String? _error;
  String? _info;

  bool get _canSubmit => _code.length >= 4 && !_busy;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final session = context.read<SessionCubit>();
    try {
      await session.confirmEmailVerify(_code);
      if (!mounted) return;
      unawaited(Navigator.of(context).maybePop());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Invalid or expired code. Try again.';
        _code = '';
        _fieldKey = UniqueKey();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final session = context.read<SessionCubit>();
    try {
      await session.requestEmailVerify();
      if (!mounted) return;
      setState(() => _info = 'Code sent. Check your email.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not resend. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<SessionCubit>().state.profile?.phone;
    return AuthShell(
      appBarTitle: 'Verify email',
      appBarActions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Skip'),
        ),
      ],
      footer: TextButton.icon(
        onPressed: _busy ? null : _resend,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Resend code'),
      ),
      children: [
        AuthHero(
          icon: Icons.mark_email_read_outlined,
          title: 'Check your email',
          subtitle: email == null
              ? 'Enter the 6-digit code we just sent you.'
              : 'Enter the 6-digit code we sent to the email on your account.',
        ),
        const SizedBox(height: 28),
        PinDotsField(
          key: _fieldKey,
          length: 6,
          enabled: !_busy,
          onChanged: (v) => setState(() {
            _code = v;
            _error = null;
          }),
          onSubmit: _submit,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          AuthInlineMessage(message: _error!),
        ],
        if (_info != null) ...[
          const SizedBox(height: 16),
          AuthInlineMessage(message: _info!, isError: false),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Verify'),
          ),
        ),
      ],
    );
  }
}
