import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/session/session_cubit.dart';
import '../../widgets/auth_shell.dart';
import 'forgot_password_reset_screen.dart';

class ForgotPasswordRequestScreen extends StatefulWidget {
  const ForgotPasswordRequestScreen({super.key});

  @override
  State<ForgotPasswordRequestScreen> createState() =>
      _ForgotPasswordRequestScreenState();
}

class _ForgotPasswordRequestScreenState
    extends State<ForgotPasswordRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _busy = false;
  String? _localError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
      return 'Enter a valid email';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final session = context.read<SessionCubit>();
    final email = _emailCtrl.text.trim();
    try {
      await session.requestForgotPassword(email);
      if (!mounted) return;
      unawaited(Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => ForgotPasswordResetScreen(email: email),
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _localError = 'Could not send code. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      appBarTitle: 'Forgot password',
      children: [
        const AuthHero(
          icon: Icons.lock_reset,
          title: 'Forgot your password?',
          subtitle:
              "Enter the email on your account and we'll send a code to reset it.",
        ),
        const SizedBox(height: 28),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            validator: _validateEmail,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        if (_localError != null) ...[
          const SizedBox(height: 16),
          AuthInlineMessage(message: _localError!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send code'),
          ),
        ),
      ],
    );
  }
}
