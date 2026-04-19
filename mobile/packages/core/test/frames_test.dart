import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:test/test.dart';

void main() {
  test('chunk → encode → decode → reassemble in reverse order', () {
    final rng = Random(1);
    final payload = Uint8List.fromList(List<int>.generate(7000, (_) => rng.nextInt(256)));
    final frames = chunk(payload, 1024, 'payment');
    final decoded = frames.map((f) => decodeFrame(encodeFrame(f))).toList();
    final r = Reassembler();
    for (var i = decoded.length - 1; i >= 0; i--) {
      r.accept(decoded[i]);
    }
    expect(r.complete(), isTrue);
    final res = r.assemble();
    expect(res.contentType, equals('payment'));
    expect(res.content, equals(payload));
  });

  test('out-of-order with duplicates', () {
    final rng = Random(2);
    final payload = Uint8List.fromList(List<int>.generate(5000, (_) => rng.nextInt(256)));
    final frames = chunk(payload, 500, 'payment');
    final shuffled = List<Frame>.from(frames)..shuffle(Random(3));
    final withDupes = [...shuffled, shuffled.first, shuffled.last];
    final r = Reassembler();
    for (final f in withDupes) {
      r.accept(f);
    }
    expect(r.assemble().content, equals(payload));
  });

  test('missing frame detected', () {
    final frames = chunk(Uint8List.fromList(utf8.encode('some bytes here longer than a chunk')), 10, 'payment');
    final r = Reassembler();
    for (var i = 0; i < frames.length; i++) {
      if (i == 3) continue;
      r.accept(frames[i]);
    }
    expect(r.complete(), isFalse);
    expect(() => r.assemble(), throwsA(isA<QrFrameException>()));
    expect(r.missing(), isNotEmpty);
  });

  test('checksum mismatch detected', () {
    final frames = chunk(Uint8List.fromList(utf8.encode('abcdefghij')), 4, 'payment');
    for (final f in frames) {
      if (f.kind == kindPayload) {
        f.payload[0] ^= 0xff;
        break;
      }
    }
    final r = Reassembler();
    for (final f in frames) {
      r.accept(f);
    }
    expect(() => r.assemble(), throwsA(isA<QrFrameException>()));
  });

  test('decode rejects garbage', () {
    expect(() => decodeFrame(Uint8List.fromList([0x99])), throwsA(isA<QrFrameException>()));
    expect(() => decodeFrame(Uint8List(0)), throwsA(isA<QrFrameException>()));
  });

  test('empty payload round trip', () {
    final frames = chunk(Uint8List(0), 100, 'payment');
    final r = Reassembler();
    for (final f in frames) {
      r.accept(f);
    }
    expect(r.assemble().content, isEmpty);
  });

  test('cross-language: Go-encoded frames decode and reassemble in Dart', () {
    final fix = jsonDecode(File('test/fixtures/crosslang.json').readAsStringSync())
        as Map<String, Object?>;
    final g = fix['frames']! as Map<String, Object?>;
    final expectedContent = base64.decode(g['content_b64']! as String);
    final goFrames = (g['frames']! as List).cast<Map<String, Object?>>();
    final r = Reassembler();
    for (final gf in goFrames) {
      final encoded = base64.decode(gf['encoded_b64']! as String);
      r.accept(decodeFrame(Uint8List.fromList(encoded)));
    }
    final res = r.assemble();
    expect(res.contentType, equals(g['content_type']));
    expect(res.content, equals(expectedContent));
  });
}
