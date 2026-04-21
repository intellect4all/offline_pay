// Cold-start auth without the network. The BFF mints an Ed25519 device
// session token on online login; on subsequent cold starts we verify it
// locally and gate the offline wallet behind a PIN / biometric.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kPinHash = 'offlinepay.unlock.pin_hash';
const _kPinSalt = 'offlinepay.unlock.pin_salt';
const _kPinFailures = 'offlinepay.unlock.pin_failures';
const _kPinLockoutAt = 'offlinepay.unlock.pin_lockout_until';
const _kDsToken = 'offlinepay.unlock.ds_token';
const _kDsKeyId = 'offlinepay.unlock.ds_key_id';
const _kDsPubKey = 'offlinepay.unlock.ds_pubkey';
const _kDsExpiresAt = 'offlinepay.unlock.ds_expires_at';
const _kDsScope = 'offlinepay.unlock.ds_scope';
const _kDsAudience = 'offlinepay.unlock.ds_audience';
const _kDsPendingMint = 'offlinepay.unlock.ds_pending_mint';

enum OfflineGateState {
  needsOnlineLogin,
  locked,
  unlocked,
  expired,
}

class PinVerifyResult {
  final bool ok;
  final String? reason;
  final Duration? lockedFor;
  const PinVerifyResult.ok() : ok = true, reason = null, lockedFor = null;
  const PinVerifyResult.bad(this.reason) : ok = false, lockedFor = null;
  const PinVerifyResult.lockedOut(this.lockedFor)
      : ok = false,
        reason = 'Too many failed attempts. Try again later.';
}

class CachedDeviceSession {
  final String token;
  final String keyId;
  final Uint8List serverPublicKey;
  final DateTime expiresAt;
  final String scope;

  const CachedDeviceSession({
    required this.token,
    required this.keyId,
    required this.serverPublicKey,
    required this.expiresAt,
    required this.scope,
  });
}

class OfflineAuthService {
  final FlutterSecureStorage _s;

  final int argonMemoryKib;
  final int argonIterations;
  final int argonParallelism;
  final int argonHashLen;

  final int maxFailures;
  final Duration lockoutWindow;

  final String expectedAudience;
  final Duration clockSkew;

  // Argon2id defaults target ~150ms on a low-end Android (OWASP mobile).
  OfflineAuthService({
    FlutterSecureStorage? storage,
    this.argonMemoryKib = 19000,
    this.argonIterations = 2,
    this.argonParallelism = 1,
    this.argonHashLen = 32,
    this.maxFailures = 5,
    this.lockoutWindow = const Duration(minutes: 5),
    this.expectedAudience = 'offlinepay-user',
    this.clockSkew = const Duration(minutes: 30),
  }) : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  Future<bool> hasPin() async {
    final h = await _s.read(key: _kPinHash);
    return h != null && h.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    _validatePinShape(pin);
    final salt = _randBytes(16);
    final digest = await _argonHash(pin, salt);
    await _s.write(key: _kPinSalt, value: base64.encode(salt));
    await _s.write(key: _kPinHash, value: base64.encode(digest));
    await _s.delete(key: _kPinFailures);
    await _s.delete(key: _kPinLockoutAt);
  }

  Future<PinVerifyResult> verifyPin(String pin) async {
    if (!_validShape(pin)) return const PinVerifyResult.bad('Enter 4 or 6 digits');
    final lockedUntil = await _readLockoutUntil();
    if (lockedUntil != null && DateTime.now().toUtc().isBefore(lockedUntil)) {
      return PinVerifyResult.lockedOut(lockedUntil.difference(DateTime.now().toUtc()));
    }
    final saltB64 = await _s.read(key: _kPinSalt);
    final hashB64 = await _s.read(key: _kPinHash);
    if (saltB64 == null || hashB64 == null) {
      return const PinVerifyResult.bad('No PIN set on this device');
    }
    final salt = base64.decode(saltB64);
    final expected = base64.decode(hashB64);
    final got = await _argonHash(pin, salt);
    final ok = _ctEqual(got, expected);
    if (ok) {
      await _s.delete(key: _kPinFailures);
      await _s.delete(key: _kPinLockoutAt);
      return const PinVerifyResult.ok();
    }
    final fails = (await _readInt(_kPinFailures)) + 1;
    await _s.write(key: _kPinFailures, value: '$fails');
    if (fails >= maxFailures) {
      final until = DateTime.now().toUtc().add(lockoutWindow);
      await _s.write(key: _kPinLockoutAt, value: until.toIso8601String());
      return PinVerifyResult.lockedOut(lockoutWindow);
    }
    final remaining = maxFailures - fails;
    return PinVerifyResult.bad('Incorrect PIN ($remaining attempt${remaining == 1 ? '' : 's'} left)');
  }

  Future<void> clearPin() async {
    await _s.delete(key: _kPinHash);
    await _s.delete(key: _kPinSalt);
    await _s.delete(key: _kPinFailures);
    await _s.delete(key: _kPinLockoutAt);
  }

  Future<void> cacheDeviceSession({
    required String token,
    required String keyId,
    required Uint8List serverPublicKey,
    required DateTime expiresAt,
    required String scope,
    String? audience,
  }) async {
    await _s.write(key: _kDsToken, value: token);
    await _s.write(key: _kDsKeyId, value: keyId);
    await _s.write(key: _kDsPubKey, value: base64.encode(serverPublicKey));
    await _s.write(key: _kDsExpiresAt, value: expiresAt.toUtc().toIso8601String());
    await _s.write(key: _kDsScope, value: scope);
    if (audience != null && audience.isNotEmpty) {
      await _s.write(key: _kDsAudience, value: audience);
    }
  }

  Future<CachedDeviceSession?> readCachedSession() async {
    final token = await _s.read(key: _kDsToken);
    final keyId = await _s.read(key: _kDsKeyId);
    final pubB64 = await _s.read(key: _kDsPubKey);
    final expIso = await _s.read(key: _kDsExpiresAt);
    final scope = await _s.read(key: _kDsScope);
    if (token == null || keyId == null || pubB64 == null || expIso == null) {
      return null;
    }
    try {
      return CachedDeviceSession(
        token: token,
        keyId: keyId,
        serverPublicKey: Uint8List.fromList(base64.decode(pubB64)),
        expiresAt: DateTime.parse(expIso),
        scope: scope ?? 'offline_pay',
      );
    } catch (e, st) {
      developer.log(
        'offline_auth: cached session is malformed',
        error: e,
        stackTrace: st,
        name: 'offline_auth',
      );
      return null;
    }
  }

  Future<void> clearDeviceSession() async {
    await _s.delete(key: _kDsToken);
    await _s.delete(key: _kDsKeyId);
    await _s.delete(key: _kDsPubKey);
    await _s.delete(key: _kDsExpiresAt);
    await _s.delete(key: _kDsScope);
    await _s.delete(key: _kDsAudience);
    await _s.delete(key: _kDsPendingMint);
  }

  Future<void> markDeviceSessionMintPending() =>
      _s.write(key: _kDsPendingMint, value: '1');

  Future<void> clearDeviceSessionMintPending() =>
      _s.delete(key: _kDsPendingMint);

  Future<bool> isDeviceSessionMintPending() async {
    final v = await _s.read(key: _kDsPendingMint);
    return v != null && v.isNotEmpty;
  }

  Future<OfflineGateState> evaluateGate({required String? expectedDeviceId}) async {
    final cached = await readCachedSession();
    if (cached == null) return OfflineGateState.needsOnlineLogin;
    final audience = await _s.read(key: _kDsAudience) ?? expectedAudience;
    final ok = await _verifyToken(
      token: cached.token,
      pub: cached.serverPublicKey,
      audience: audience,
      expectedDeviceId: expectedDeviceId,
    );
    if (!ok) return OfflineGateState.expired;
    return OfflineGateState.locked;
  }

  Future<bool> hasUsableSession() async {
    final s = await readCachedSession();
    if (s == null) return false;
    return DateTime.now().toUtc().isBefore(s.expiresAt.toUtc().add(clockSkew));
  }

  Future<Uint8List> _argonHash(String pin, List<int> salt) async {
    final algo = Argon2id(
      memory: argonMemoryKib,
      iterations: argonIterations,
      parallelism: argonParallelism,
      hashLength: argonHashLen,
    );
    final secret = SecretKey(utf8.encode(pin));
    final out = await algo.deriveKey(secretKey: secret, nonce: salt);
    return Uint8List.fromList(await out.extractBytes());
  }

  Future<DateTime?> _readLockoutUntil() async {
    final raw = await _s.read(key: _kPinLockoutAt);
    if (raw == null) return null;
    try {
      return DateTime.parse(raw).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<int> _readInt(String key) async {
    final raw = await _s.read(key: key);
    if (raw == null) return 0;
    return int.tryParse(raw) ?? 0;
  }

  void _validatePinShape(String pin) {
    if (!_validShape(pin)) {
      throw ArgumentError('PIN must be 4 or 6 digits');
    }
  }

  bool _validShape(String pin) {
    final n = pin.length;
    if (n != 4 && n != 6) return false;
    for (final c in pin.codeUnits) {
      if (c < 0x30 || c > 0x39) return false;
    }
    return true;
  }

  static Uint8List _randBytes(int n) {
    final r = SecretKeyData.random(length: n);
    return Uint8List.fromList(r.bytes);
  }

  static bool _ctEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  Future<bool> _verifyToken({
    required String token,
    required Uint8List pub,
    required String audience,
    required String? expectedDeviceId,
  }) async {
    final parts = token.split('.');
    if (parts.length != 3) return false;
    Uint8List headerJson;
    Uint8List claimsJson;
    Uint8List signature;
    try {
      headerJson = _b64urlDecode(parts[0]);
      claimsJson = _b64urlDecode(parts[1]);
      signature = _b64urlDecode(parts[2]);
    } catch (_) {
      return false;
    }
    Object? header;
    Object? claims;
    try {
      header = jsonDecode(utf8.decode(headerJson));
      claims = jsonDecode(utf8.decode(claimsJson));
    } catch (e, st) {
      developer.log(
        'offline_auth: token JSON decode failed',
        error: e,
        stackTrace: st,
        name: 'offline_auth',
      );
      return false;
    }
    if (header is! Map || claims is! Map) return false;
    if (header['alg'] != 'EdDSA') return false;

    final scope = claims['scope'];
    if (scope != 'offline_pay') return false;
    final aud = claims['aud'];
    if (aud is String && audience.isNotEmpty && aud != audience) return false;
    if (expectedDeviceId != null) {
      final did = claims['did'];
      if (did is String && did != expectedDeviceId) return false;
    }
    final exp = claims['exp'];
    if (exp is num) {
      final expAt = DateTime.fromMillisecondsSinceEpoch(
        (exp.toInt()) * 1000,
        isUtc: true,
      );
      if (DateTime.now().toUtc().isAfter(expAt.add(clockSkew))) return false;
    }

    final signingInput = utf8.encode('${parts[0]}.${parts[1]}');
    final algo = Ed25519();
    return algo.verify(
      signingInput,
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(pub, type: KeyPairType.ed25519),
      ),
    );
  }

  static Uint8List _b64urlDecode(String s) {
    final pad = (4 - s.length % 4) % 4;
    return Uint8List.fromList(base64Url.decode(s + ('=' * pad)));
  }
}
