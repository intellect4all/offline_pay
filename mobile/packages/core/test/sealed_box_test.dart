import 'dart:convert';
import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:test/test.dart';

void main() {
  test('round trip in Dart', () async {
    final recip = await generateSealedBoxKeyPair();
    final msg = utf8.encode('secret transaction blob');
    final ct = await sealAnonymous(recip.publicKey, msg);
    expect(ct.length, equals(msg.length + sealedBoxOverhead));
    final pt = await openAnonymous(recip.publicKey, recip.keyPair, ct);
    expect(pt, equals(msg));
  });

  test('fresh ephemeral keypair per seal', () async {
    final recip = await generateSealedBoxKeyPair();
    final msg = utf8.encode('same');
    final a = await sealAnonymous(recip.publicKey, msg);
    final b = await sealAnonymous(recip.publicKey, msg);
    expect(a, isNot(equals(b)));
  });

  test('tamper fails', () async {
    final recip = await generateSealedBoxKeyPair();
    final ct = await sealAnonymous(recip.publicKey, utf8.encode('hi'));
    ct[ct.length - 1] ^= 0xff;
    expect(
      () => openAnonymous(recip.publicKey, recip.keyPair, ct),
      throwsA(isA<Object>()),
    );
  });

  test('wrong recipient fails', () async {
    final a = await generateSealedBoxKeyPair();
    final b = await generateSealedBoxKeyPair();
    final ct = await sealAnonymous(a.publicKey, utf8.encode('hi'));
    expect(
      () => openAnonymous(b.publicKey, b.keyPair, ct),
      throwsA(isA<Object>()),
    );
  });

  test('short ciphertext rejected', () async {
    final recip = await generateSealedBoxKeyPair();
    expect(
      () => openAnonymous(recip.publicKey, recip.keyPair, Uint8List.fromList(utf8.encode('too short'))),
      throwsA(isA<Object>()),
    );
  });
}
