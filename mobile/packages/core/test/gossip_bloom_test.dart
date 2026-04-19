import 'dart:typed_data';

import 'package:offlinepay_core/src/gossip/bloom.dart';
import 'package:test/test.dart';

Uint8List _key(int seed) {
  final b = Uint8List(32);
  b[0] = seed & 0xFF;
  b[1] = (seed >> 8) & 0xFF;
  b[2] = (seed >> 16) & 0xFF;
  b[3] = (seed >> 24) & 0xFF;
  for (var i = 4; i < 32; i++) {
    b[i] = ((seed * (i + 13)) ^ (seed >> (i & 7))) & 0xFF;
  }
  return b;
}

void main() {
  group('BloomFilter', () {
    test('contains returns true for inserted keys', () {
      final bf = BloomFilter();
      final k1 = _key(1);
      final k2 = _key(2);
      bf.add(k1);
      expect(bf.contains(k1), isTrue);
      expect(bf.contains(k2), isFalse);
    });

    test('false-positive rate is reasonable at 500 items', () {
      final bf = BloomFilter();
      for (var i = 0; i < 500; i++) {
        bf.add(_key(i));
      }
      var fp = 0;
      for (var i = 0; i < 10000; i++) {
        if (bf.contains(_key(1_000_000 + i))) fp++;
      }
      expect(fp, lessThan(500));
    });

    test('reset clears membership', () {
      final bf = BloomFilter();
      bf.add(_key(42));
      expect(bf.contains(_key(42)), isTrue);
      bf.reset();
      expect(bf.contains(_key(42)), isFalse);
      expect(bf.itemsAdded, 0);
    });
  });
}
