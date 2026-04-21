import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/session/session_cubit.dart';
import '../../widgets/auth_shell.dart';
import 'forgot_password_request_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String? _localError;
  bool _biometricAvailable = false;
  bool _biometricCredentialCached = false;
  bool _submittingBiometric = false;

  @override
  void initState() {
    super.initState();
    unawaited(_hydrateFromStorage());
  }

  Future<void> _hydrateFromStorage() async {
    final session = context.read<SessionCubit>();
    try {
      final phone = await session.lastPhone();
      if (phone != null && mounted && _phoneCtrl.text.isEmpty) {
        final digits = phone.replaceFirst(RegExp(r'^\+234'), '');
        _phoneCtrl.text = digits;
      }
    } catch (_) {}
    try {
      final available = await session.biometricAvailable();
      final cached = await session.hasBiometricLoginCredential();
      if (!mounted) return;
      setState(() {
        _biometricAvailable = available;
        _biometricCredentialCached = cached;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String? _validatePhone(String? v) {
    final s = (v ?? '').trim();
    if (s.length != 10) return 'Enter a 10-digit phone number';
    if (!RegExp(r'^[0-9]{10}$').hasMatch(s)) return 'Digits only';
    return null;
  }

  String? _validatePassword(String? v) {
    if ((v ?? '').isEmpty) return 'Enter your password';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _localError = null);
    if (!_formKey.currentState!.validate()) return;
    final phone = '+234${_phoneCtrl.text.trim()}';
    final session = context.read<SessionCubit>();
    try {
      await session.login(phone: phone, password: _passwordCtrl.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _localError = _friendly(e));
    }
  }

  Future<void> _submitBiometric() async {
    if (_submittingBiometric) return;
    setState(() {
      _localError = null;
      _submittingBiometric = true;
    });
    final session = context.read<SessionCubit>();
    try {
      await session.loginWithBiometric();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancelled')) {
        setState(() {});
        return;
      }
      setState(() => _localError = _friendly(e));
    } finally {
      if (mounted) setState(() => _submittingBiometric = false);
    }
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.toLowerCase().contains('invalid')) {
      return 'Phone number or password is incorrect.';
    }
    return 'Could not sign in. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    return AuthShell(
      showAppBar: false,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "New here?",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          TextButton(
            onPressed: () => unawaited(Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const SignupScreen(),
              ),
            )),
            child: const Text('Create account'),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 24),
        const AuthBrand(),
        const SizedBox(height: 32),
        const AuthHero(
          title: 'Welcome back',
          subtitle: 'Sign in to continue to your account.',
        ),
        const SizedBox(height: 28),
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
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: _validatePassword,
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => unawaited(Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const ForgotPasswordRequestScreen(),
                    ),
                  )),
                  child: const Text('Forgot password?'),
                ),
              ),
            ],
          ),
        ),
        if (_localError != null) ...[
          AuthInlineMessage(message: _localError!),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
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
                : const Text('Sign in'),
          ),
        ),
        if (_biometricAvailable && _biometricCredentialCached) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                session.loading || _submittingBiometric ? null : _submitBiometric,
            icon: _submittingBiometric
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fingerprint),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Sign in with biometric'),
            ),
          ),
        ],
      ],
    );
  }
}
