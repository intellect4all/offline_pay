import 'dart:convert';
import 'dart:typed_data';

import 'package:offlinepay_api/offlinepay_api.dart' as gen;


class DeviceSessionResponse {
  final String token;
  final String keyId;
  final Uint8List serverPublicKey;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String scope;

  const DeviceSessionResponse({
    required this.token,
    required this.keyId,
    required this.serverPublicKey,
    required this.issuedAt,
    required this.expiresAt,
    required this.scope,
  });
}

class DeviceSessionPublicKey {
  final String keyId;
  final Uint8List publicKey;
  final DateTime activeFrom;
  final DateTime? retiredAt;

  const DeviceSessionPublicKey({
    required this.keyId,
    required this.publicKey,
    required this.activeFrom,
    this.retiredAt,
  });
}

class DeviceSessionRepository {
  final gen.OfflinepayApi _api;

  DeviceSessionRepository({required gen.OfflinepayApi api}) : _api = api;

  gen.DefaultApi get _default => _api.getDefaultApi();

  Map<String, dynamic> _authHeaders(String accessToken) => <String, dynamic>{
        'Authorization': 'Bearer $accessToken',
      };

  Future<DeviceSessionResponse> issue({
    required String accessToken,
    required String deviceId,
    String scope = 'offline_pay',
  }) async {
    final body = gen.DeviceSessionRequest((b) => b
      ..deviceId = deviceId
      ..scope = gen.DeviceSessionRequestScopeEnum.offlinePay);
    final _ = scope;
    final resp = await _default.postV1AuthDeviceSession(
      deviceSessionRequest: body,
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('device-session: empty response body');
    }
    return DeviceSessionResponse(
      token: data.token,
      keyId: data.keyId,
      serverPublicKey: Uint8List.fromList(base64.decode(data.serverPublicKey)),
      issuedAt: data.issuedAt.toUtc(),
      expiresAt: data.expiresAt.toUtc(),
      scope: data.scope.name,
    );
  }

  Future<List<DeviceSessionPublicKey>> publicKeys() async {
    final resp = await _default.getV1AuthDeviceSessionPublicKeys();
    final data = resp.data;
    if (data == null) return const [];
    return data.keys
        .map((k) => DeviceSessionPublicKey(
              keyId: k.keyId,
              publicKey: Uint8List.fromList(base64.decode(k.publicKey)),
              activeFrom: k.activeFrom.toUtc(),
              retiredAt: k.retiredAt?.toUtc(),
            ))
        .toList(growable: false);
  }
}
