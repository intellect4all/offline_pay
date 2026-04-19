import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:test/test.dart';

GossipBlob _blob(int seed, {int hop = 0, int size = 200}) {
  final tx = Uint8List(32);
  tx[0] = seed & 0xFF;
  tx[1] = (seed >> 8) & 0xFF;
  tx[2] = (seed >> 16) & 0xFF;
  tx[3] = (seed >> 24) & 0xFF;
  for (var i = 4; i < 32; i++) {
    tx[i] = ((seed * (i + 17)) ^ (seed >> (i & 7))) & 0xFF;
  }
  final enc = Uint8List(size);
  for (var i = 0; i < size; i++) {
    enc[i] = (seed + i) & 0xFF;
  }
  return GossipBlob(
    transactionHash: tx,
    encryptedBlob: enc,
    bankSignature: Uint8List.fromList([1, 2, 3, 4]),
    ceilingTokenHash: Uint8List.fromList([9, 9, 9, 9]),
    hopCount: hop,
    blobSize: size,
  );
}

void main() {
  group('CarryCache', () {
    test('500-cap eviction drops oldest non-own entries first', () {
      final c = CarryCache();
      for (var i = 0; i < 100; i++) {
        c.add(_blob(i), isOwnTxn: true);
      }
      for (var i = 100; i < 600; i++) {
        c.add(_blob(i), isOwnTxn: false);
      }
      expect(c.length, maxCarryCapacity);
      for (var i = 0; i < 100; i++) {
        expect(c.alreadySeen(_blob(i).transactionHash), isTrue,
            reason: 'own-txn $i should survive eviction');
      }
    });

    test('own-txns are never evicted under extreme pressure', () {
      final c = CarryCache(capacity: 10);
      for (var i = 0; i < 10; i++) {
        c.add(_blob(i), isOwnTxn: true);
      }
      for (var i = 10; i < 60; i++) {
        c.add(_blob(i), isOwnTxn: false);
      }
      for (var i = 0; i < 10; i++) {
        expect(c.alreadySeen(_blob(i).transactionHash), isTrue);
      }
    });

    test('incrementHops drops blobs at the hop limit', () {
      final c = CarryCache();
      c.add(_blob(1, hop: 0), isOwnTxn: false);
      c.add(_blob(2, hop: 1), isOwnTxn: false);
      c.add(_blob(3, hop: maxGossipHops), isOwnTxn: false);
      final out = c.incrementHops();
      expect(out.length, 2);
      expect(out.map((b) => b.hopCount).toList(), [1, 2]);
      expect(c.length, 2);
    });

    test('outgoingBundle respects byte budget', () {
      final c = CarryCache();
      for (var i = 0; i < 10; i++) {
        c.add(_blob(i, size: 100), isOwnTxn: false);
      }
      final bundle = c.outgoingBundle(350);
      expect(bundle.length, 3);
      final total = bundle.fold<int>(0, (a, b) => a + b.blobSize);
      expect(total, lessThanOrEqualTo(350));
    });

    test('outgoingBundle handles zero budget', () {
      final c = CarryCache();
      c.add(_blob(1), isOwnTxn: false);
      expect(c.outgoingBundle(0), isEmpty);
    });
  });
}
