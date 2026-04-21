// Handles the device attestation + realm/bank/sealed-box key pull after
// a successful user login. Idempotent; safe to re-invoke.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:built_collection/built_collection.dart';
import 'package:dio/dio.dart';
import 'package:offlinepay_api/offlinepay_api.dart';

import 'keystore.dart';
import 'sync.dart' show TokenProvider;

const _kAppVersionFallback = '0.1.0-dev';

class DeviceRegistrar {
  final Keystore keystore;
  final DefaultApi api;
  final TokenProvider tokenProvider;

  DeviceRegistrar({
    required this.keystore,
    required this.api,
    required this.tokenProvider,
  });

  Future<bool> isRegistered() async {
    final deviceId = await keystore.deviceId();
    final jwt = await keystore.deviceJwt();
    if (deviceId == null || deviceId.isEmpty) return false;
    if (jwt == null || jwt.isEmpty) return false;
    final exp = _jwtExp(jwt);
    if (exp == null) return true;
    return exp.isAfter(DateTime.now().toUtc());
  }

  Future<void> ensureRegistered({
    required String userId,
    bool force = false,
  }) async {
    if (force) {
      await keystore.clear();
    } else if (await isRegistered()) {
      return;
    }

    final token = tokenProvider();
    if (token == null || token.isEmpty) {
      throw StateError('device-registrar: no access token available');
    }

    Uint8List? pubkey = await keystore.publicKey();
    pubkey ??= await keystore.generateKeyPair();

    final chal = await api.postV1DevicesAttestationChallenge(
      headers: _bearer(token),
    );
    final nonce = chal.data?.nonce;
    if (nonce == null || nonce.isEmpty) {
      throw StateError('device-registrar: empty attestation nonce');
    }

    final body = RegisterDeviceBody((b) => b
      ..devicePublicKey = base64.encode(pubkey!)
      ..platform = _platform()
      ..attestationBlob = _buildDevAttestationBlob(
        platform: _platform(),
        devicePubkey: pubkey,
        nonceBase64: nonce,
      )
      ..appVersion = _kAppVersionFallback
      ..attestationNonce = nonce);
    final regResp = await api.postV1Devices(
      registerDeviceBody: body,
      headers: _bearer(token),
    );
    final reg = regResp.data;
    if (reg == null) {
      throw StateError('device-registrar: empty register response');
    }

    await keystore.setDeviceId(reg.deviceId);
    await keystore.setDeviceJwt(reg.deviceJwt);
    await keystore.setUserId(userId);

    await _fetchRealmKey(reg.realmKeyVersion, reg.deviceId, token);

    try {
      final bankResp = await api.postV1KeysBankPublicKeys(
        bankPublicKeysBody: BankPublicKeysBody((b) => b),
      );
      final BuiltList<BankPublicKey> keys =
          bankResp.data?.keys ?? BuiltList<BankPublicKey>();
      await keystore.saveBankKeys(
        keys
            .map<Map<String, dynamic>>((k) => <String, dynamic>{
                  'key_id': k.keyId,
                  'public_key': k.publicKey,
                  'active_from': k.activeFrom.toUtc().toIso8601String(),
                })
            .toList(growable: false),
      );
    } catch (e, st) {
      developer.log(
        'device-registrar: bank-public-keys fetch failed',
        error: e,
        stackTrace: st,
        name: 'device_registrar',
      );
    }

    try {
      final sbResp = await api.getV1KeysSealedBoxPubkey();
      final pub = sbResp.data?.publicKey;
      if (pub != null && pub.isNotEmpty) {
        await keystore
            .saveSealedBoxPubkey(Uint8List.fromList(base64.decode(pub)));
      }
    } catch (e, st) {
      developer.log(
        'device-registrar: sealed-box pubkey fetch failed',
        error: e,
        stackTrace: st,
        name: 'device_registrar',
      );
    }
  }

  Future<void> refreshRealmKeyIfNeeded() async {
    final deviceId = await keystore.deviceId();
    if (deviceId == null) return;
    final token = tokenProvider();
    if (token == null || token.isEmpty) return;
    final current = await keystore.realmKey();
    final currentVersion = current?.$1 ?? 0;

    final resp = await api.getV1KeysRealmActive(
      deviceId: deviceId,
      limit: 1,
      headers: _bearer(token),
    );
    final newest = resp.data?.keys;
    if (newest == null || newest.isEmpty) return;
    final head = newest.first;
    if (head.version > currentVersion) {
      await _fetchRealmKey(head.version, deviceId, token);
    }
  }

  Future<void> clear() => keystore.clear();

  Future<void> _fetchRealmKey(
      int version, String deviceId, String token) async {
    final resp = await api.getV1KeysRealmVersion(
      version: version,
      deviceId: deviceId,
      headers: _bearer(token),
    );
    final rk = resp.data;
    if (rk == null) {
      throw StateError('device-registrar: empty realm key response');
    }
    final keyBytes = Uint8List.fromList(base64.decode(rk.key));
    await keystore.setRealmKey(rk.version, keyBytes);
  }

  Map<String, dynamic> _bearer(String token) =>
      <String, dynamic>{'Authorization': 'Bearer $token'};

  static String _buildDevAttestationBlob({
    required String platform,
    required Uint8List devicePubkey,
    required String nonceBase64,
  }) {
    final blob = <String, dynamic>{
      'platform': platform,
      'device_public_key': base64.encode(devicePubkey),
      'nonce': nonceBase64,
    };
    return base64.encode(utf8.encode(jsonEncode(blob)));
  }

  static String _platform() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return 'desktop';
  }

  static DateTime? _jwtExp(String jwt) {
    final parts = jwt.split('.');
    if (parts.length < 2) return null;
    try {
      final payload = parts[1];
      final padded = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4,
        '=',
      );
      final decoded = utf8.decode(base64Url.decode(padded));
      final claims = jsonDecode(decoded);
      if (claims is! Map) return null;
      final exp = claims['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          exp * 1000,
          isUtc: true,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

int? dioStatusCode(Object err) {
  if (err is DioException) return err.response?.statusCode;
  return null;
}
