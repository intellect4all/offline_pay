import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:test/test.dart';

Uint8List _nonce() => Uint8List.fromList(List<int>.filled(sessionNonceSize, 0xAA));
Uint8List _hash() => Uint8List.fromList(List<int>.filled(32, 0xCC));

void main() {
  test('sign + verify round trip in Dart', () async {
    final keys = await generateEd25519KeyPair();
    final payload = PaymentPayload(
      payerId: 'alice',
      payeeId: 'bob',
      amount: 1000,
      sequenceNumber: 1,
      remainingCeiling: 4000,
      timestamp: DateTime.utc(2026, 4, 13, 12, 0, 0),
      ceilingTokenId: 'ceil_1',
      sessionNonce: _nonce(),
      requestHash: _hash(),
    );
    final sig = await signPayment(keys.keyPair, payload);
    expect(sig.length, equals(64));
    final ok = await verifyPayment(keys.publicKey.bytes, payload, sig);
    expect(ok, isTrue);

    final tampered = PaymentPayload(
      payerId: payload.payerId,
      payeeId: payload.payeeId,
      amount: payload.amount + 1,
      sequenceNumber: payload.sequenceNumber,
      remainingCeiling: payload.remainingCeiling,
      timestamp: payload.timestamp,
      ceilingTokenId: payload.ceilingTokenId,
      sessionNonce: payload.sessionNonce,
      requestHash: payload.requestHash,
    );
    final tamperedOk = await verifyPayment(keys.publicKey.bytes, tampered, sig);
    expect(tamperedOk, isFalse);
  });

  test('cross-language fixture: Go signatures verify in Dart', () async {
    final fix = _loadFixture();

    final ceilingMap = fix['ceiling'] as Map<String, Object?>;
    final ceiling = CeilingTokenPayload.fromJson(ceilingMap['payload']! as Map<String, Object?>);
    final dartCanon = utf8.decode(canonicalize(ceiling));
    expect(dartCanon, equals(ceilingMap['canonical']));

    final bankPub = base64.decode(ceilingMap['bank_public_key_b64']! as String);
    final ceilingSig = base64.decode(ceilingMap['signature_b64']! as String);
    expect(
      await verifyCeiling(bankPub, ceiling, ceilingSig),
      isTrue,
      reason: 'Go-signed ceiling must verify in Dart',
    );

    final paymentMap = fix['payment'] as Map<String, Object?>;
    final payment = PaymentPayload.fromJson(paymentMap['payload']! as Map<String, Object?>);
    expect(utf8.decode(canonicalize(payment)), equals(paymentMap['canonical']));
    final payerPub = base64.decode(paymentMap['payer_public_key_b64']! as String);
    final paymentSig = base64.decode(paymentMap['signature_b64']! as String);
    expect(await verifyPayment(payerPub, payment, paymentSig), isTrue);
  });

  test('cross-language fixture: Dart-signed verifies against Go pubkey', () async {
    final fix = _loadFixture();
    final paymentMap = fix['payment'] as Map<String, Object?>;
    final payment = PaymentPayload.fromJson(paymentMap['payload']! as Map<String, Object?>);

    final privBytes = base64.decode(paymentMap['payer_private_key_b64']! as String);
    final seed = privBytes.sublist(0, 32);
    final kp = await Ed25519().newKeyPairFromSeed(seed);

    final sig = await signPayment(kp, payment);
    final expectedSig = base64.decode(paymentMap['signature_b64']! as String);
    expect(Uint8List.fromList(sig), equals(Uint8List.fromList(expectedSig)));
  });
}

Map<String, Object?> _loadFixture() {
  final raw = File('test/fixtures/crosslang.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, Object?>;
}
