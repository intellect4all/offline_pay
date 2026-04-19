import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:test/test.dart';

void main() {
  group('gossip fixture cross-lang', () {
    late Map<String, Object?> fix;
    setUpAll(() {
      fix = jsonDecode(File('test/fixtures/crosslang.json').readAsStringSync())
          as Map<String, Object?>;
    });

    test('Dart decrypts Go-sealed gossip inner payload', () async {
      final g = fix['gossip']! as Map<String, Object?>;
      final serverPub = base64.decode(g['server_public_key_b64']! as String);
      final serverPriv = base64.decode(g['server_private_key_b64']! as String);
      final ct = base64.decode(g['ciphertext_b64']! as String);
      final expectedCanon =
          Uint8List.fromList(utf8.encode(g['canonical_inner']! as String));

      final kp = await X25519().newKeyPairFromSeed(serverPriv);
      final pt = await openAnonymous(serverPub, kp, ct);
      expect(pt, equals(expectedCanon));
    });

    test('Dart-sealed gossip inner payload decrypts under Go layout', () async {
      final g = fix['gossip']! as Map<String, Object?>;
      final rawInner = g['inner'];
      final resolved = rawInner is String
          ? jsonDecode(rawInner) as Map<String, Object?>
          : Map<String, Object?>.from(rawInner as Map);
      final parsed = GossipInnerPayload.fromJson(resolved);
      final canon = parsed.canonicalBytes();
      final expectedCanon =
          Uint8List.fromList(utf8.encode(g['canonical_inner']! as String));
      expect(canon, equals(expectedCanon),
          reason: 'Dart canonical encoding must match Go byte-for-byte');

      final serverPub = base64.decode(g['server_public_key_b64']! as String);
      final serverPriv = base64.decode(g['server_private_key_b64']! as String);
      final kp = await X25519().newKeyPairFromSeed(serverPriv);
      final sealed = await sealAnonymous(serverPub, canon);
      final back = await openAnonymous(serverPub, kp, sealed);
      expect(back, equals(canon));
    });

    test('sealGossipBlobs hashes match Go-emitted hashes', () async {
      final g = fix['gossip']! as Map<String, Object?>;
      final expectedTxHash =
          base64.decode(g['transaction_hash_b64']! as String);
      final expectedCeilingHash =
          base64.decode(g['ceiling_token_hash_b64']! as String);
      final serverPub = base64.decode(g['server_public_key_b64']! as String);

      final rawInner = g['inner'];
      final resolved = rawInner is String
          ? jsonDecode(rawInner) as Map<String, Object?>
          : Map<String, Object?>.from(rawInner as Map);
      final parsed = GossipInnerPayload.fromJson(resolved);

      final blobs = await sealGossipBlobs([parsed], serverPub);
      expect(blobs, hasLength(1));
      final b = blobs.first;
      expect(b.transactionHash, equals(expectedTxHash));
      expect(b.ceilingTokenHash, equals(expectedCeilingHash));
      expect(b.hopCount, 0);
      expect(b.blobSize, b.encryptedBlob.length);
    });
  });
}
