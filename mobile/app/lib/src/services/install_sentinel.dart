import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstallSentinel {
  static const _kMarker = 'install_sentinel.initialized_v1';

  static Future<void> ensure() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kMarker) == true) return;

    developer.log(
      'first launch after install — purging secure storage',
      name: 'install_sentinel',
    );
    try {
      await const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      ).deleteAll();
    } catch (e, st) {
      developer.log(
        'install_sentinel: deleteAll failed',
        error: e,
        stackTrace: st,
        name: 'install_sentinel',
      );
    }
    await prefs.setBool(_kMarker, true);
  }
}
