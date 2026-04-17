import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:test/test.dart';

Uint8List _k(int seed) => Uint8List.fromList(List<int>.generate(32, (i) => i ^ seed));

void main() {
  group('RealmKeyring', () {
    test('seed sets active version', () {
      final kr = RealmKeyring.seed(1, _k(0x5a));
      expect(kr.activeVersion, 1);
      expect(kr.activeKey.length, 32);
    });

    test('newer version auto-activates', () {
      final kr = RealmKeyring.seed(1, _k(0x01));
      kr.add(2, _k(0x02));
      expect(kr.activeVersion, 2);
      expect(kr.keyFor(1), isNotNull);
      expect(kr.keyFor(2), isNotNull);
    });

    test('retired version stays decryptable', () {
      final kr = RealmKeyring.seed(1, _k(0x01));
      kr.add(2, _k(0x02));
      expect(kr.keyFor(1), isNotNull);
    });

    test('unknown version returns null for lookup callback', () {
      final kr = RealmKeyring.seed(1, _k(0x01));
      expect(kr.keyFor(9), isNull);
    });

    test('remove active version downgrades activeVersion', () {
      final kr = RealmKeyring.seed(1, _k(0x01));
      kr.add(2, _k(0x02));
      kr.remove(2);
      expect(kr.activeVersion, 1);
    });
  });
}
