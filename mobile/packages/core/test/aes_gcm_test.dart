import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:test/test.dart';

void main() {
  test('round trip', () async {
    final key = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      key[i] = i;
    }
    final nonce = Uint8List.fromList(List<int>.generate(12, (i) => 100 + i));
    final pt = utf8.encode('hello world');
    final ad = utf8.encode('v1');
    final ct = await seal(key, nonce, pt, associatedData: ad);
    final got = await open(key, nonce, ct, associatedData: ad);
    expect(got, equals(pt));
  });

  test('tamper fails', () async {
    final key = Uint8List(32);
    final nonce = Uint8List(12);
    final ct = await seal(key, nonce, utf8.encode('data'));
    ct[0] ^= 0xff;
    expect(() => open(key, nonce, ct), throwsA(isA<Object>()));
  });

  test('frame nonce derivation is deterministic and unique', () {
    final base = Uint8List.fromList(List<int>.generate(12, (i) => i));
    final n0 = deriveFrameNonce(base, 0);
    final n1 = deriveFrameNonce(base, 1);
    expect(n0, isNot(equals(n1)));
    expect(deriveFrameNonce(base, 0), equals(n0));
    expect(n1.sublist(8), equals([0, 0, 0, 1]));
  });

  test('cross-language: Dart decrypts Go-sealed ciphertext', () async {
    final fix = jsonDecode(File('test/fixtures/crosslang.json').readAsStringSync())
        as Map<String, Object?>;
    final g = fix['aes_gcm']! as Map<String, Object?>;
    final key = base64.decode(g['key_b64']! as String);
    final nonce = base64.decode(g['nonce_b64']! as String);
    final ct = base64.decode(g['ciphertext_b64']! as String);
    final aad = base64.decode(g['aad_b64']! as String);
    final expected = base64.decode(g['plaintext_b64']! as String);
    final pt = await open(key, nonce, ct, associatedData: aad);
    expect(pt, equals(expected));
  });
}
