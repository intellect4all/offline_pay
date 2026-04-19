import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';
import 'package:test/test.dart';

void main() {
  test('SELECT AID command is recognised and OK-replied', () {
    final cmd = buildSelectAidCommand();
    expect(isSelectAidCommand(cmd), isTrue);
    expect(buildSelectOkResponse(), orderedEquals([0x90, 0x00]));

    final bad = Uint8List.fromList(cmd);
    bad[5] ^= 0xff;
    expect(isSelectAidCommand(bad), isFalse);
  });

  test('GET_CHUNK round-trip: command → response → parse', () {
    final wire = Uint8List.fromList(
        List<int>.generate(600, (i) => (i * 17) & 0xff));
    final responses = stageChunkResponses(wire);
    expect(responses.length, 3);

    final re = NfcReassembler();
    var total = 0;
    for (var i = 0;; i++) {
      final cmd = buildGetChunkCommand(i);
      final idx = tryParseGetChunkCommand(cmd);
      expect(idx, i);
      final rsp = responses[idx!];
      final parsed = parseGetChunkResponse(rsp);
      if (total == 0) total = parsed.total;
      re.accept(NfcChunkApdu(
        chunkIndex: idx,
        totalChunks: parsed.total,
        data: parsed.data,
      ));
      if (i + 1 >= total) break;
    }
    expect(re.complete, isTrue);
    expect(re.assemble(), equals(wire));
  });

  test('non-OK status code is reported', () {
    final bad = Uint8List.fromList([0x03, 0x01, 0x02, 0x6A, 0x82]);
    expect(() => parseGetChunkResponse(bad),
        throwsA(isA<NfcApduException>()));
  });

  test('tryParseGetChunkCommand returns null on SELECT and other APDUs', () {
    expect(tryParseGetChunkCommand(buildSelectAidCommand()), isNull);
    expect(
      tryParseGetChunkCommand(
          Uint8List.fromList([0x80, 0xBB, 0x00, 0x00, 0x00])),
      isNull,
    );
  });

  test('stageChunkResponses rejects oversized payloads', () {
    final wire = Uint8List(300);
    expect(
      () => stageChunkResponses(wire, chunkSize: 1),
      throwsA(isA<NfcApduException>()),
    );
  });
}
