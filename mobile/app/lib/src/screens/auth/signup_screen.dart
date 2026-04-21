import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/session/session_cubit.dart';
import '../../widgets/auth_shell.dart';
import 'email_verify_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _obscure = true;
  String? _localError;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.length != 10) return 'Enter a 10-digit phone number';
    if (!RegExp(r'^[0-9]{10}$').hasMatch(s)) return 'Digits only';
    return null;
  }

  String? _validatePassword(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateRequired(String? v, String label) {
    if ((v ?? '').trim().isEmpty) return '$label is required';
    return null;
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
    final session = context.read<SessionCubit>();
    try {
      await session.signup(
        phone: '+234${_phoneCtrl.text.trim()}',
        password: _passwordCtrl.text,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      unawaited(Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(builder: (_) => const EmailVerifyScreen()),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _localError = _friendly(e));
    }
  }

  String _friendly(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('already') || msg.contains('409')) {
      return 'An account already exists for that phone or email.';
    }
    if (msg.contains('400')) {
      return 'Some details look off. Please review and try again.';
    }
    return 'Could not create account. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    return AuthShell(
      appBarTitle: 'Create account',
      footer: Text(
        'By creating an account you agree to the Terms of Service and '
        'Privacy Policy.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
      children: [
        const SizedBox(height: 8),
        const AuthHero(
          title: 'Let’s set you up',
          subtitle: 'Takes under a minute. We only ask what we need.',
          compact: true,
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _phoneCtrl,
                autofocus: true,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixText: '+234 ',
                  border: OutlineInputBorder(),
                  hintText: '8108678294',
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Password',
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
                validator: _validatePassword,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _validateRequired(v, 'First name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _validateRequired(v, 'Last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: "We'll send a verification code here",
                  border: OutlineInputBorder(),
                ),
                validator: _validateEmail,
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_localError != null) ...[
          const SizedBox(height: 16),
          AuthInlineMessage(message: _localError!),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: session.loading ? null : _submit,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: session.loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create account'),
          ),
        ),
      ],
    );
  }
}
