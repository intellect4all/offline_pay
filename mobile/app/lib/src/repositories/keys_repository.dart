import 'dart:convert' show base64;
import 'dart:typed_data';

import 'package:built_collection/built_collection.dart';
import 'package:offlinepay_api/offlinepay_api.dart' as gen;


class RealmKeySnapshot {
  final int version;
  final Uint8List key;
  final DateTime activeFrom;
  final DateTime? retiredAt;

  const RealmKeySnapshot({
    required this.version,
    required this.key,
    required this.activeFrom,
    required this.retiredAt,
  });
}

class BankPublicKeySnapshot {
  final String keyId;
  final String publicKeyB64;
  final DateTime activeFrom;
  final DateTime? retiredAt;

  const BankPublicKeySnapshot({
    required this.keyId,
    required this.publicKeyB64,
    required this.activeFrom,
    required this.retiredAt,
  });
}

class SealedBoxPubkeySnapshot {
  final Uint8List publicKey;
  final String keyId;
  final DateTime activeFrom;

  const SealedBoxPubkeySnapshot({
    required this.publicKey,
    required this.keyId,
    required this.activeFrom,
  });
}

class KeysRepository {
  final gen.OfflinepayApi _api;

  KeysRepository({required gen.OfflinepayApi api}) : _api = api;

  gen.DefaultApi get _default => _api.getDefaultApi();

  Map<String, dynamic> _authHeaders(String accessToken) => <String, dynamic>{
        'Authorization': 'Bearer $accessToken',
      };

  Future<List<RealmKeySnapshot>> getActiveRealmKeys({
    required String deviceId,
    required String accessToken,
  }) async {
    final resp = await _default.getV1KeysRealmActive(
      deviceId: deviceId,
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) return const [];
    return data.keys
        .map((k) => RealmKeySnapshot(
              version: k.version,
              key: Uint8List.fromList(base64.decode(k.key)),
              activeFrom: k.activeFrom,
              retiredAt: k.retiredAt,
            ))
        .toList(growable: false);
  }

  Future<List<BankPublicKeySnapshot>> getBankPublicKeys({
    required String accessToken,
    List<String> keyIds = const [],
  }) async {
    final body = gen.BankPublicKeysBody((b) {
      if (keyIds.isNotEmpty) b.keyIds = ListBuilder<String>(keyIds);
    });
    final resp = await _default.postV1KeysBankPublicKeys(
      bankPublicKeysBody: body,
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) return const [];
    return data.keys
        .map((k) => BankPublicKeySnapshot(
              keyId: k.keyId,
              publicKeyB64: k.publicKey,
              activeFrom: k.activeFrom,
              retiredAt: k.retiredAt,
            ))
        .toList(growable: false);
  }

  Future<SealedBoxPubkeySnapshot> getSealedBoxPubkey(String accessToken) async {
    final resp = await _default.getV1KeysSealedBoxPubkey(
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('keys: getSealedBoxPubkey returned empty body');
    }
    return SealedBoxPubkeySnapshot(
      publicKey: Uint8List.fromList(base64.decode(data.publicKey)),
      keyId: data.keyId,
      activeFrom: data.activeFrom,
    );
  }
}
