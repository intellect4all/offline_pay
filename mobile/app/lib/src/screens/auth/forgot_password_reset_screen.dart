import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/session/session_cubit.dart';
import '../../widgets/auth_shell.dart';
import '../../widgets/pin_dots_field.dart';

class ForgotPasswordResetScreen extends StatefulWidget {
  final String email;
  const ForgotPasswordResetScreen({super.key, required this.email});

  @override
  State<ForgotPasswordResetScreen> createState() =>
      _ForgotPasswordResetScreenState();
}

class _ForgotPasswordResetScreenState extends State<ForgotPasswordResetScreen> {
  final _passwordCtrl = TextEditingController();
  Key _codeKey = UniqueKey();
  String _code = '';
  bool _busy = false;
  bool _obscure = true;
  String? _localError;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _validCode() => _code.length >= 4;
  bool _validPassword() => _passwordCtrl.text.length >= 8;
  bool get _canSubmit => _validCode() && _validPassword() && !_busy;

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!_validCode()) {
      setState(() => _localError = 'Enter the code from your email');
      return;
    }
    if (!_validPassword()) {
      setState(() => _localError = 'Password must be at least 8 characters');
      return;
    }
    setState(() => _busy = true);
    final session = context.read<SessionCubit>();
    try {
      await session.resetPassword(
        email: widget.email,
        code: _code,
        newPassword: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Password reset. Sign in with your new password.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _localError = 'Invalid or expired code. Try again.';
        _code = '';
        _codeKey = UniqueKey();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      appBarTitle: 'Reset password',
      children: [
        AuthHero(
          icon: Icons.key_outlined,
          title: 'Check your email',
          subtitle:
              'Enter the code we sent to ${widget.email} and choose a new password.',
        ),
        const SizedBox(height: 28),
        Text(
          'Verification code',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 10),
        PinDotsField(
          key: _codeKey,
          length: 6,
          enabled: !_busy,
          onChanged: (v) => setState(() {
            _code = v;
            _localError = null;
          }),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'New password',
            helperText: 'At least 8 characters',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_localError != null) ...[
          const SizedBox(height: 16),
          AuthInlineMessage(message: _localError!),
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
                : const Text('Reset password'),
          ),
        ),
      ],
    );
  }
}
