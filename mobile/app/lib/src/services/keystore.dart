// MVP key store. flutter_secure_storage gets us Android Keystore + iOS
// Keychain at rest, but the private key still materialises in the Dart
// heap to sign. Production wants a native signer (StrongBox / Secure
// Enclave) behind a platform channel — see TODO.md A-05.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:offlinepay_core/offlinepay_core.dart';

const _kPrivKey = 'offlinepay.ed25519.priv';
const _kPubKey = 'offlinepay.ed25519.pub';
const _kUserId = 'offlinepay.user.id';
const _kDeviceId = 'offlinepay.device.id';
const _kDeviceJwt = 'offlinepay.device.jwt';
const _kRealmKey = 'offlinepay.realm.key';
const _kRealmKeyVersion = 'offlinepay.realm.key.version';
const _kBankKeys = 'offlinepay.bank.keys';
const _kSealedBoxPubkey = 'offlinepay.sealedbox.pubkey';
const _kDisplayCard = 'offlinepay.identity.display_card';
const _kBiometricCred = 'offlinepay.auth.biometric_credential';

class Keystore {
  final FlutterSecureStorage _s;
  Keystore([FlutterSecureStorage? s])
      : _s = s ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  Future<bool> hasKeyPair() async {
    final priv = await _s.read(key: _kPrivKey);
    return priv != null;
  }

  Future<Uint8List> generateKeyPair() async {
    final keys = await generateEd25519KeyPair();
    final priv = await keys.keyPair.extractPrivateKeyBytes();
    await _s.write(key: _kPrivKey, value: base64.encode(priv));
    await _s.write(key: _kPubKey, value: base64.encode(keys.publicKey.bytes));
    return Uint8List.fromList(keys.publicKey.bytes);
  }

  Future<Uint8List?> publicKey() async {
    final b64 = await _s.read(key: _kPubKey);
    if (b64 == null) return null;
    return Uint8List.fromList(base64.decode(b64));
  }

  Future<SimpleKeyPair> loadKeyPair() async {
    final privB64 = await _s.read(key: _kPrivKey);
    final pubB64 = await _s.read(key: _kPubKey);
    if (privB64 == null || pubB64 == null) {
      throw StateError('keystore: no keypair provisioned');
    }
    final priv = base64.decode(privB64);
    final algo = Ed25519();
    return algo.newKeyPairFromSeed(priv.sublist(0, 32));
  }

  Future<void> setUserId(String id) => _s.write(key: _kUserId, value: id);
  Future<String?> userId() => _s.read(key: _kUserId);

  Future<void> setDeviceId(String id) => _s.write(key: _kDeviceId, value: id);
  Future<String?> deviceId() => _s.read(key: _kDeviceId);

  Future<void> setDeviceJwt(String jwt) =>
      _s.write(key: _kDeviceJwt, value: jwt);
  Future<String?> deviceJwt() => _s.read(key: _kDeviceJwt);

  Future<void> setRealmKey(int version, Uint8List key) async {
    await _s.write(key: _kRealmKey, value: base64.encode(key));
    await _s.write(key: _kRealmKeyVersion, value: version.toString());
  }

  Future<(int, Uint8List)?> realmKey() async {
    final b64 = await _s.read(key: _kRealmKey);
    final v = await _s.read(key: _kRealmKeyVersion);
    if (b64 == null || v == null) return null;
    return (int.parse(v), Uint8List.fromList(base64.decode(b64)));
  }

  Future<void> saveBankKeys(List<Map<String, dynamic>> keys) async {
    await _s.write(key: _kBankKeys, value: jsonEncode(keys));
  }

  Future<List<Map<String, dynamic>>> readBankKeys() async {
    final raw = await _s.read(key: _kBankKeys);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map<Map<String, dynamic>>(
          (e) => e.map((k, v) => MapEntry(k.toString(), v)),
        )
        .toList(growable: false);
  }

  Future<void> saveSealedBoxPubkey(Uint8List pubkey) =>
      _s.write(key: _kSealedBoxPubkey, value: base64.encode(pubkey));

  Future<Uint8List?> readSealedBoxPubkey() async {
    final b64 = await _s.read(key: _kSealedBoxPubkey);
    if (b64 == null) return null;
    return Uint8List.fromList(base64.decode(b64));
  }

  // canonicalize, not jsonEncode — toJson() returns CanonicalBytes that
  // stdlib jsonEncode can't serialise.
  Future<void> saveDisplayCard(DisplayCard card) => _s.write(
        key: _kDisplayCard,
        value: utf8.decode(canonicalize(card.toJson())),
      );

  Future<DisplayCard?> readDisplayCard() async {
    final raw = await _s.read(key: _kDisplayCard);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return DisplayCard.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDisplayCard() => _s.delete(key: _kDisplayCard);

  Future<void> saveBiometricLoginCredential({
    required String phone,
    required String password,
  }) =>
      _s.write(
        key: _kBiometricCred,
        value: jsonEncode({'phone': phone, 'password': password}),
      );

  Future<({String phone, String password})?> readBiometricLoginCredential() async {
    final raw = await _s.read(key: _kBiometricCred);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final phone = decoded['phone'];
      final password = decoded['password'];
      if (phone is! String || password is! String) return null;
      return (phone: phone, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasBiometricLoginCredential() async {
    final raw = await _s.read(key: _kBiometricCred);
    return raw != null && raw.isNotEmpty;
  }

  Future<void> clearBiometricLoginCredential() =>
      _s.delete(key: _kBiometricCred);

  // Leaves the signing keypair and user id in place so re-registration
  // against the same account keeps the existing payer identity.
  Future<void> clear() async {
    await _s.delete(key: _kDeviceId);
    await _s.delete(key: _kDeviceJwt);
    await _s.delete(key: _kRealmKey);
    await _s.delete(key: _kRealmKeyVersion);
    await _s.delete(key: _kBankKeys);
    await _s.delete(key: _kSealedBoxPubkey);
    await _s.delete(key: _kDisplayCard);
    await _s.delete(key: _kBiometricCred);
  }

  Future<void> wipe() async {
    await _s.deleteAll();
  }
}
