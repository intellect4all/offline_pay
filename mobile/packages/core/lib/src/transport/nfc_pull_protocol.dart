import 'dart:typed_data';

import 'nfc_apdu.dart';

const int _insSelect = 0xA4;
const int _selectP1 = 0x04;
const int _selectP2 = 0x00;

Uint8List buildSelectAidCommand() {
  final aid = offlinePayAid;
  final out = Uint8List(5 + aid.length + 1);
  out[0] = 0x00;
  out[1] = _insSelect;
  out[2] = _selectP1;
  out[3] = _selectP2;
  out[4] = aid.length;
  out.setRange(5, 5 + aid.length, aid);
  out[5 + aid.length] = 0x00;
  return out;
}

bool isSelectAidCommand(Uint8List cmd) {
  if (cmd.length < 5 + offlinePayAid.length) return false;
  if (cmd[0] != 0x00 || cmd[1] != _insSelect) return false;
  if (cmd[2] != _selectP1 || cmd[3] != _selectP2) return false;
  final lc = cmd[4];
  if (lc != offlinePayAid.length) return false;
  for (var i = 0; i < lc; i++) {
    if (cmd[5 + i] != offlinePayAid[i]) return false;
  }
  return true;
}

Uint8List buildSelectOkResponse() =>
    Uint8List.fromList([0x90, 0x00]);

Uint8List buildGetChunkCommand(int idx) {
  if (idx < 0 || idx > 255) {
    throw NfcApduException('chunk index out of range: $idx');
  }
  return Uint8List.fromList([nfcCla, nfcInsGetChunk, idx, 0x00, 0x00]);
}

int? tryParseGetChunkCommand(Uint8List cmd) {
  if (cmd.length < 5) return null;
  if (cmd[0] != nfcCla || cmd[1] != nfcInsGetChunk) return null;
  return cmd[2];
}

Uint8List buildGetChunkResponse({required int total, required Uint8List data}) {
  if (total < 1 || total > nfcMaxChunks) {
    throw NfcApduException('total chunks out of range: $total');
  }
  if (data.length > 252) {
    throw NfcApduException('chunk data too large for single APDU response');
  }
  final out = Uint8List(1 + data.length + 2);
  out[0] = total;
  out.setRange(1, 1 + data.length, data);
  out[out.length - 2] = 0x90;
  out[out.length - 1] = 0x00;
  return out;
}

class GetChunkResponse {
  final int total;
  final Uint8List data;
  GetChunkResponse({required this.total, required this.data});
}

GetChunkResponse parseGetChunkResponse(Uint8List rsp) {
  if (rsp.length < 3) throw NfcApduException('response too short');
  final sw1 = rsp[rsp.length - 2];
  final sw2 = rsp[rsp.length - 1];
  if (sw1 != 0x90 || sw2 != 0x00) {
    throw NfcApduException(
        'non-OK status: ${sw1.toRadixString(16)}${sw2.toRadixString(16)}');
  }
  final total = rsp[0];
  if (total < 1 || total > nfcMaxChunks) {
    throw NfcApduException('advertised total out of range: $total');
  }
  final data = Uint8List.fromList(rsp.sublist(1, rsp.length - 2));
  return GetChunkResponse(total: total, data: data);
}

List<Uint8List> stageChunkResponses(
  Uint8List sealedWireBytes, {
  int chunkSize = nfcChunkPayloadSize,
}) {
  if (sealedWireBytes.isEmpty) {
    throw NfcApduException('empty sealed wire');
  }
  if (chunkSize <= 0 || chunkSize > 240) {
    throw NfcApduException('chunk size out of range: $chunkSize');
  }
  final total = (sealedWireBytes.length + chunkSize - 1) ~/ chunkSize;
  if (total > nfcMaxChunks) {
    throw NfcApduException(
        'payload too large for NFC: $total chunks exceeds $nfcMaxChunks');
  }
  final out = <Uint8List>[];
  for (var i = 0; i < total; i++) {
    final start = i * chunkSize;
    final end = (start + chunkSize < sealedWireBytes.length)
        ? start + chunkSize
        : sealedWireBytes.length;
    final data = Uint8List.fromList(sealedWireBytes.sublist(start, end));
    out.add(buildGetChunkResponse(total: total, data: data));
  }
  return out;
}
