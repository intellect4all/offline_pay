import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../repositories/auth_repository.dart';

class StoredSession {
  final String userId;
  final String accountNumber;
  final String refreshToken;
  final String? lastPhone;

  const StoredSession({
    required this.userId,
    required this.accountNumber,
    required this.refreshToken,
    this.lastPhone,
  });
}

class SessionStore {
  static const _kUserId = 'session.user_id';
  static const _kAccount = 'session.account_number';
  static const _kRefresh = 'session.refresh_token';
  static const _kLastPhone = 'session.last_phone';

  final FlutterSecureStorage _storage;

  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  Future<void> save(AuthSession s, {String? lastPhone}) async {
    await _storage.write(key: _kUserId, value: s.userId);
    await _storage.write(key: _kAccount, value: s.accountNumber);
    await _storage.write(key: _kRefresh, value: s.refreshToken);
    if (lastPhone != null) {
      await _storage.write(key: _kLastPhone, value: lastPhone);
    }
  }

  Future<StoredSession?> load() async {
    final userId = await _storage.read(key: _kUserId);
    final account = await _storage.read(key: _kAccount);
    final refresh = await _storage.read(key: _kRefresh);
    final lastPhone = await _storage.read(key: _kLastPhone);
    if (userId == null || account == null || refresh == null) return null;
    return StoredSession(
      userId: userId,
      accountNumber: account,
      refreshToken: refresh,
      lastPhone: lastPhone,
    );
  }

  Future<String?> lastPhone() => _storage.read(key: _kLastPhone);

  Future<void> rememberPhone(String phone) =>
      _storage.write(key: _kLastPhone, value: phone);

  Future<void> clear() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kAccount);
    await _storage.delete(key: _kRefresh);
  }
}
