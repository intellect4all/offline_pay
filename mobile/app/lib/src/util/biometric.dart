import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class Biometric {
  Biometric._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> confirm({
    String reason = 'Confirm to continue',
  }) async {
    try {
      if (!await isAvailable()) return true;
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException {
      return true;
    }
  }
}
