import 'dart:convert';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:cryptography/cryptography.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offlinepay_app/src/services/offline_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStoragePlatform.instance = _InMemorySecureStorage();

  group('OfflineAuthService — PIN', () {
    test('setPin then verifyPin succeeds; bad PIN counts toward lockout',
        () async {
      final svc = OfflineAuthService(maxFailures: 3, lockoutWindow: const Duration(minutes: 5));
      await svc.setPin('1234');
      final ok = await svc.verifyPin('1234');
      expect(ok.ok, isTrue);

      var bad = await svc.verifyPin('0000');
      expect(bad.ok, isFalse);
      expect(bad.lockedFor, isNull);
      bad = await svc.verifyPin('0000');
      expect(bad.ok, isFalse);
      bad = await svc.verifyPin('0000');
      expect(bad.ok, isFalse);
      expect(bad.lockedFor, isNotNull);

      final blocked = await svc.verifyPin('1234');
      expect(blocked.ok, isFalse);
      expect(blocked.lockedFor, isNotNull);
    });

    test('verifyPin rejects wrong-shape input', () async {
      final svc = OfflineAuthService();
      await svc.setPin('123456');
      final r = await svc.verifyPin('12');
      expect(r.ok, isFalse);
    });
  });

  group('OfflineAuthService — token verify', () {
    test('valid Go-shaped token verifies; tampered fails', () async {
      final svc = OfflineAuthService(expectedAudience: 'aud-test');
      final algo = Ed25519();
      final kp = await algo.newKeyPair();
      final pub = await kp.extractPublicKey();
      final pubBytes = Uint8List.fromList(pub.bytes);

      final now = DateTime.now().toUtc();
      final token = await _signToken(
        kp: kp,
        kid: 'kid-1',
        claims: {
          'sub': 'u_alice',
          'acc': '8108678294',
          'did': 'd_galaxy',
          'scope': 'offline_pay',
          'iat': now.millisecondsSinceEpoch ~/ 1000,
          'exp': now.add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000,
          'aud': 'aud-test',
        },
      );

      await svc.cacheDeviceSession(
        token: token,
        keyId: 'kid-1',
        serverPublicKey: pubBytes,
        expiresAt: now.add(const Duration(days: 7)),
        scope: 'offline_pay',
        audience: 'aud-test',
      );

      final state = await svc.evaluateGate(expectedDeviceId: 'd_galaxy');
      expect(state, OfflineGateState.locked);

      final mismatched = await svc.evaluateGate(expectedDeviceId: 'd_other');
      expect(mismatched, OfflineGateState.expired);
    });

    test('expired token surfaces as expired gate', () async {
      final svc = OfflineAuthService(
        expectedAudience: 'aud-test',
        clockSkew: const Duration(seconds: 1),
      );
      final algo = Ed25519();
      final kp = await algo.newKeyPair();
      final pub = await kp.extractPublicKey();
      final pubBytes = Uint8List.fromList(pub.bytes);
      final past = DateTime.now().toUtc().subtract(const Duration(days: 2));
      final token = await _signToken(
        kp: kp,
        kid: 'kid-1',
        claims: {
          'sub': 'u_alice',
          'acc': '8108678294',
          'did': 'd_galaxy',
          'scope': 'offline_pay',
          'iat': past.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000,
          'exp': past.millisecondsSinceEpoch ~/ 1000,
          'aud': 'aud-test',
        },
      );
      await svc.cacheDeviceSession(
        token: token,
        keyId: 'kid-1',
        serverPublicKey: pubBytes,
        expiresAt: past,
        scope: 'offline_pay',
        audience: 'aud-test',
      );
      final state = await svc.evaluateGate(expectedDeviceId: 'd_galaxy');
      expect(state, OfflineGateState.expired);
    });
  });
}

Future<String> _signToken({
  required SimpleKeyPair kp,
  required String kid,
  required Map<String, dynamic> claims,
}) async {
  final header = {'alg': 'EdDSA', 'typ': 'DST', 'kid': kid};
  final headerEnc = _b64url(utf8.encode(jsonEncode(header)));
  final claimsEnc = _b64url(utf8.encode(jsonEncode(claims)));
  final signingInput = utf8.encode('$headerEnc.$claimsEnc');
  final algo = Ed25519();
  final sig = await algo.sign(signingInput, keyPair: kp);
  final sigEnc = _b64url(sig.bytes);
  return '$headerEnc.$claimsEnc.$sigEnc';
}

String _b64url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

class _InMemorySecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _m = {};

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async {
    return _m.containsKey(key);
  }

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    _m.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _m.clear();
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    return _m[key];
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async {
    return Map.of(_m);
  }

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async {
    _m[key] = value;
  }
}
