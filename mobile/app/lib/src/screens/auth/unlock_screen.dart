import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/cubits/session/session_cubit.dart';
import '../../services/offline_auth.dart';
import '../../util/haptics.dart';
import '../../widgets/pin_dots_field.dart';

class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  Key _fieldKey = UniqueKey();
  String _pin = '';
  String? _error;
  bool _submitting = false;
  bool _biometricChecked = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBiometric());
  }

  Future<void> _initBiometric() async {
    final cubit = context.read<SessionCubit>();
    final available = await cubit.biometric.isAvailable();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricChecked = true;
    });
    if (available) {
      unawaited(_tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    final cubit = context.read<SessionCubit>();
    final ok = await cubit.unlockWithBiometric();
    if (!mounted) return;
    if (ok) {
      Haptics.success();
    }
  }

  void _onPinChanged(String v) {
    setState(() {
      _pin = v;
      _error = null;
    });
  }

  Future<void> _onPinComplete() async {
    if (_pin.length != 4 && _pin.length != 6) return;
    setState(() => _submitting = true);
    try {
      final res = await context.read<SessionCubit>().unlockWithPin(_pin);
      if (!mounted) return;
      if (res.ok) {
        Haptics.success();
        return;
      }
      Haptics.error();
      setState(() {
        _error = res.reason ?? 'Incorrect PIN';
        _pin = '';
        _fieldKey = UniqueKey();
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signOutAndUseLogin() async {
    final cubit = context.read<SessionCubit>();
    await cubit.logout();
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cached = context.select<SessionCubit, CachedDeviceSession?>(
      (c) => c.state.deviceSession,
    );
    final hint = cached == null
        ? null
        : 'Offline session valid until ${_friendlyExpiry(cached.expiresAt)}';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.lock_outline,
                      size: 32, color: scheme.primary),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Unlock offline pay',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your PIN to use the offline wallet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 32),
              PinDotsField(
                key: _fieldKey,
                length: 6,
                enabled: !_submitting,
                onChanged: _onPinChanged,
                onSubmit: _onPinComplete,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
              ],
              if (hint != null) ...[
                const SizedBox(height: 18),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              const Spacer(),
              if (_biometricChecked && _biometricAvailable)
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _tryBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Use biometrics'),
                  ),
                ),
              TextButton(
                onPressed: _submitting ? null : _signOutAndUseLogin,
                child: const Text('Use password instead'),
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

  String _friendlyExpiry(DateTime utc) {
    final local = utc.toLocal();
    final diff = local.difference(DateTime.now());
    if (diff.isNegative) return 'expired';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return 'in ${diff.inDays}d';
  }
}
