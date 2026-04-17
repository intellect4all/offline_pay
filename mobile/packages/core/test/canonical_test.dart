import 'dart:convert';
import 'dart:typed_data';

import 'package:offlinepay_core/src/canonical.dart';
import 'package:test/test.dart';

void main() {
  test('sorts object keys lexicographically', () {
    final got = canonicalize({'b': 2, 'a': 1, 'c': 3});
    expect(utf8.decode(got), equals('{"a":1,"b":2,"c":3}'));
  });

  test('sorts nested object keys', () {
    final got = canonicalize({
      'm': {'z': 1, 'a': 2},
      'k': 3,
    });
    expect(utf8.decode(got), equals('{"k":3,"m":{"a":2,"z":1}}'));
  });

  test('deterministic across runs', () {
    final value = {
      'id': 'user_1',
      'when': DateTime.utc(2026, 4, 13, 12, 0, 0),
      'amount': 50000,
      'bytes': Uint8List.fromList([0x01, 0x02, 0x03]),
    };
    final a = canonicalize(value);
    for (var i = 0; i < 50; i++) {
      final b = canonicalize(value);
      expect(b, equals(a));
    }
  });

  test('byte arrays as standard base64', () {
    final got = canonicalize({
      'k': const CanonicalBytes([0xff, 0x00, 0x7f]),
    });
    expect(utf8.decode(got), equals('{"k":"/wB/"}'));
  });

  test('RFC3339Nano formatting trims trailing zeros', () {
    expect(
      formatRfc3339Nano(DateTime.utc(2026, 4, 13, 12, 0, 0)),
      equals('2026-04-13T12:00:00Z'),
    );
    expect(
      formatRfc3339Nano(DateTime.utc(2026, 4, 13, 12, 0, 0, 500)),
      equals('2026-04-13T12:00:00.5Z'),
    );
  });
}
