import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:test/test.dart';

Uint8List _nonce() => Uint8List.fromList(List<int>.filled(sessionNonceSize, 0xAA));
Uint8List _hash() => Uint8List.fromList(List<int>.filled(32, 0xCC));

void main() {
  test('seal → chunk → reassemble → open → verify', () async {
    final bank = await generateEd25519KeyPair();
    final payer = await generateEd25519KeyPair();

    final ceilingPayload = CeilingTokenPayload(
      payerId: 'user_alice',
      ceilingAmount: 1000000,
      issuedAt: DateTime.utc(2026, 4, 13, 9),
      expiresAt: DateTime.utc(2026, 4, 14, 9),
      sequenceStart: 0,
      payerPublicKey: Uint8List.fromList(payer.publicKey.bytes),
      bankKeyId: 'bank_key_1',
    );
    final bankSig = await signCeiling(bank.keyPair, ceilingPayload);

    final paymentPayload = PaymentPayload(
      payerId: 'user_alice',
      payeeId: 'user_bob',
      amount: 250000,
      sequenceNumber: 1,
      remainingCeiling: 750000,
      timestamp: DateTime.utc(2026, 4, 13, 10),
      ceilingTokenId: 'ct_1',
      sessionNonce: _nonce(),
      requestHash: _hash(),
    );
    final paySig = await signPayment(payer.keyPair, paymentPayload);

    final envelope = GossipEnvelope(
      paymentToken:
          PaymentToken(payload: paymentPayload, payerSignature: paySig),
      ceiling: EnvelopeCeiling(
        id: 'ct_1',
        payload: ceilingPayload,
        bankSignature: bankSig,
      ),
      blobs: const [],
    );

    final realmKey = Uint8List.fromList(List<int>.generate(32, (i) => i));
    const keyVersion = 1;

    final sealed = await sealEnvelopeToWire(
      envelope: envelope,
      realmKey: realmKey,
      keyVersion: keyVersion,
    );
    final frames = chunkEnvelopeFrames(sealed.wireBytes);
    expect(frames.length, greaterThanOrEqualTo(3));

    final r = Reassembler();
    for (final f in frames.reversed) {
      r.accept(decodeFrame(f));
    }
    expect(r.complete(), isTrue);
    final wire = reassembleEnvelopeWire(r)!;
    expect(wire, equals(sealed.wireBytes));

    final opened = await openEnvelopeFromWire(wire, (v) {
      return v == keyVersion ? realmKey : null;
    });
    expect(opened.keyVersion, keyVersion);
    expect(opened.envelope.paymentToken.payload.amount, 250000);
    expect(opened.envelope.ceiling, isNotNull);

    final okPay = await verifyPayment(
      opened.envelope.ceiling!.payload.payerPublicKey,
      opened.envelope.paymentToken.payload,
      opened.envelope.paymentToken.payerSignature,
    );
    expect(okPay, isTrue);
    final okBank = await verifyCeiling(
      bank.publicKey.bytes,
      opened.envelope.ceiling!.payload,
      opened.envelope.ceiling!.bankSignature,
    );
    expect(okBank, isTrue);
  });

  test('unknown key version throws UnknownKeyVersionError', () async {
    final bank = await generateEd25519KeyPair();
    final payer = await generateEd25519KeyPair();
    final pay = PaymentPayload(
      payerId: 'u1',
      payeeId: 'u2',
      amount: 100,
      sequenceNumber: 1,
      remainingCeiling: 0,
      timestamp: DateTime.utc(2026, 4, 13),
      ceilingTokenId: 'ct',
      sessionNonce: _nonce(),
      requestHash: _hash(),
    );
    final sig = await signPayment(payer.keyPair, pay);
    final env = GossipEnvelope(
      paymentToken: PaymentToken(payload: pay, payerSignature: sig),
      blobs: const [],
    );
    final realmKey = Uint8List(32);
    final sealed = await sealEnvelopeToWire(
      envelope: env,
      realmKey: realmKey,
      keyVersion: 7,
    );
    expect(
      () => openEnvelopeFromWire(sealed.wireBytes, (_) => null),
      throwsA(isA<UnknownKeyVersionError>()),
    );
    expect(bank.publicKey.bytes.length, 32);
  });

  test('tampered ciphertext fails to open', () async {
    final payer = await generateEd25519KeyPair();
    final pay = PaymentPayload(
      payerId: 'u1',
      payeeId: 'u2',
      amount: 100,
      sequenceNumber: 1,
      remainingCeiling: 0,
      timestamp: DateTime.utc(2026, 4, 13),
      ceilingTokenId: 'ct',
      sessionNonce: _nonce(),
      requestHash: _hash(),
    );
    final sig = await signPayment(payer.keyPair, pay);
    final env = GossipEnvelope(
      paymentToken: PaymentToken(payload: pay, payerSignature: sig),
      blobs: const [],
    );
    final realmKey = Uint8List(32);
    final sealed = await sealEnvelopeToWire(
      envelope: env,
      realmKey: realmKey,
      keyVersion: 1,
    );
    final tampered = Uint8List.fromList(sealed.wireBytes);
    tampered[tampered.length - 1] ^= 0xff;
    expect(
      () => openEnvelopeFromWire(tampered, (_) => realmKey),
      throwsA(anything),
    );
  });
}
