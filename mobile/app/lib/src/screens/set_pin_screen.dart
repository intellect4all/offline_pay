import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/service_locator.dart';
import '../presentation/cubits/session/session_cubit.dart';
import '../repositories/auth_repository.dart';
import '../services/offline_auth.dart';
import '../util/haptics.dart';
import '../widgets/animated_check.dart';
import '../widgets/pin_dots_field.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  Key _fieldKey = UniqueKey();
  String _enterPin = '';
  String _confirmPin = '';
  bool _confirming = false;
  bool _submitting = false;
  bool _success = false;
  String? _error;

  bool _validLen(String v) => v.length == 4 || v.length == 6;

  void _resetField() => _fieldKey = UniqueKey();

  void _onPinChanged(String v) {
    setState(() {
      if (_confirming) {
        _confirmPin = v;
      } else {
        _enterPin = v;
      }
      _error = null;
    });
  }

  void _onPinComplete() {
    if (!_confirming) {
      if (!_validLen(_enterPin)) {
        setState(() => _error = 'PIN must be 4 or 6 digits');
        return;
      }
      setState(() {
        _confirming = true;
        _confirmPin = '';
        _resetField();
      });
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (!_validLen(_confirmPin)) {
      setState(() => _error = 'Re-enter the full PIN');
      return;
    }
    if (_enterPin != _confirmPin) {
      setState(() {
        _error = "PINs don't match. Start over.";
        _confirming = false;
        _enterPin = '';
        _confirmPin = '';
        _resetField();
      });
      return;
    }
    final token = context.read<SessionCubit>().state.session?.accessToken;
    if (token == null) {
      setState(() => _error = 'Not signed in');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await sl<AuthRepository>().setPin(
            pin: _enterPin,
            accessToken: token,
          );
      try {
        await sl<OfflineAuthService>().setPin(_enterPin);
      } catch (_) {
      }
      if (!mounted) return;
      Haptics.success();
      setState(() => _success = true);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PinRejected catch (e) {
      if (!mounted) return;
      Haptics.error();
      setState(() {
        _error = e.message;
        _confirming = false;
        _enterPin = '';
        _confirmPin = '';
        _resetField();
      });
    } catch (_) {
      if (!mounted) return;
      Haptics.error();
      setState(() {
        _error = 'Could not save PIN';
        _resetField();
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_success) return _SuccessView();
    final heading = _confirming ? 'Confirm your PIN' : 'Choose a PIN';
    final subtitle = _confirming
        ? 'Enter the same PIN again to confirm.'
        : 'Pick a 4- or 6-digit PIN. You will enter it each time you send money.';
    final length = _confirming && _enterPin.length == 4 ? 4 : 6;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction PIN'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                heading,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 36),
              PinDotsField(
                key: _fieldKey,
                length: length,
                enabled: !_submitting,
                onChanged: _onPinChanged,
                onSubmit: _onPinComplete,
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
              ],
              const Spacer(),
              if (_confirming)
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                            _confirming = false;
                            _confirmPin = '';
                            _enterPin = '';
                            _error = null;
                            _resetField();
                          }),
                  child: const Text('Start over'),
                ),
              if (_submitting) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AnimatedCheck(size: 96),
              const SizedBox(height: 16),
              Text(
                'PIN saved',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
