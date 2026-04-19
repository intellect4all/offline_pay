import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:test/test.dart';

void main() {
  group('chunkSealedWireToApdus / parseChunkApdu / NfcReassembler', () {
    Uint8List sample(int n) =>
        Uint8List.fromList(List<int>.generate(n, (i) => (i * 31) & 0xFF));

    test('round-trips a multi-chunk payload byte-identically', () {
      final wire = sample(1000);
      final apdus = chunkSealedWireToApdus(wire);
      expect(apdus.length, 5);
      final r = NfcReassembler();
      for (final a in apdus) {
        r.accept(parseChunkApdu(a));
      }
      expect(r.complete, isTrue);
      expect(r.assemble(), equals(wire));
    });

    test('tolerates out-of-order arrival', () {
      final wire = sample(700);
      final apdus = chunkSealedWireToApdus(wire);
      final r = NfcReassembler();
      for (final a in apdus.reversed) {
        r.accept(parseChunkApdu(a));
      }
      expect(r.complete, isTrue);
      expect(r.assemble(), equals(wire));
    });

    test('duplicate chunks are idempotent', () {
      final wire = sample(500);
      final apdus = chunkSealedWireToApdus(wire);
      final r = NfcReassembler();
      r.accept(parseChunkApdu(apdus[0]));
      r.accept(parseChunkApdu(apdus[0]));
      r.accept(parseChunkApdu(apdus[1]));
      r.accept(parseChunkApdu(apdus[2]));
      expect(r.complete, isTrue);
      expect(r.assemble(), equals(wire));
    });

    test('missing chunk leaves reassembler incomplete', () {
      final wire = sample(700);
      final apdus = chunkSealedWireToApdus(wire);
      final r = NfcReassembler();
      r.accept(parseChunkApdu(apdus[0]));
      r.accept(parseChunkApdu(apdus[2]));
      expect(r.complete, isFalse);
      expect(() => r.assemble(), throwsA(isA<NfcApduException>()));
    });

    test('rejects mismatched total across chunks', () {
      final r = NfcReassembler();
      r.accept(NfcChunkApdu(
          chunkIndex: 0, totalChunks: 3, data: Uint8List(4)));
      expect(
        () => r.accept(NfcChunkApdu(
            chunkIndex: 1, totalChunks: 4, data: Uint8List(4))),
        throwsA(isA<NfcApduException>()),
      );
    });

    test('parseChunkApdu rejects bad CLA / INS / oversized index', () {
      expect(
        () => parseChunkApdu(Uint8List.fromList([0x00, 0xA0, 0, 1, 0])),
        throwsA(isA<NfcApduException>()),
      );
      expect(
        () => parseChunkApdu(Uint8List.fromList([0x80, 0x00, 0, 1, 0])),
        throwsA(isA<NfcApduException>()),
      );
      expect(
        () => parseChunkApdu(Uint8List.fromList([0x80, 0xA0, 5, 3, 0])),
        throwsA(isA<NfcApduException>()),
      );
    });

    test('rejects payload too large for u8 chunk count', () {
      final wire = sample(2570);
      expect(
        () => chunkSealedWireToApdus(wire, chunkSize: 10),
        throwsA(isA<NfcApduException>()),
      );
    });
  });

  test('NFC carrier yields byte-identical envelope vs QR carrier', () async {
    final payer = await generateEd25519KeyPair();
    final pay = PaymentPayload(
      payerId: 'u1',
      payeeId: 'u2',
      amount: 12345,
      sequenceNumber: 7,
      remainingCeiling: 50000,
      timestamp: DateTime.utc(2026, 4, 14),
      ceilingTokenId: 'ct_x',
      sessionNonce: Uint8List.fromList(List<int>.filled(sessionNonceSize, 0xAA)),
      requestHash: Uint8List.fromList(List<int>.filled(32, 0xCC)),
    );
    final sig = await signPayment(payer.keyPair, pay);
    final env = GossipEnvelope(
      paymentToken: PaymentToken(payload: pay, payerSignature: sig),
      blobs: const [],
    );
    final realmKey = Uint8List.fromList(List<int>.generate(32, (i) => i ^ 0x5a));
    final sealed = await sealEnvelopeToWire(
      envelope: env,
      realmKey: realmKey,
      keyVersion: 1,
    );

    final qrFrames = chunkEnvelopeFrames(sealed.wireBytes);
    final r = Reassembler();
    for (final f in qrFrames) {
      r.accept(decodeFrame(f));
    }
    final qrWire = reassembleEnvelopeWire(r)!;

    final apdus = chunkSealedWireToApdus(sealed.wireBytes);
    final nr = NfcReassembler();
    for (final a in apdus) {
      nr.accept(parseChunkApdu(a));
    }
    final nfcWire = nr.assemble();

    expect(nfcWire, equals(qrWire));
    final openedQr =
        await openEnvelopeFromWire(qrWire, (_) => realmKey);
    final openedNfc =
        await openEnvelopeFromWire(nfcWire, (_) => realmKey);
    expect(openedNfc.envelope.canonicalBytes(),
        equals(openedQr.envelope.canonicalBytes()));
  });
}
