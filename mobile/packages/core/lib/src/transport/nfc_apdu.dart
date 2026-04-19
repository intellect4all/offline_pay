import 'dart:typed_data';

const int nfcCla = 0x80;
const int nfcInsGetChunk = 0xA0;
const int nfcChunkPayloadSize = 240;
const int nfcMaxChunks = 255;

const List<int> offlinePayAid = [0xF0, 0x4F, 0x46, 0x4C, 0x50, 0x41, 0x59, 0x01];

const List<int> swOk = [0x90, 0x00];
const List<int> swWrongLength = [0x67, 0x00];
const List<int> swInsNotSupported = [0x6D, 0x00];
const List<int> swClaNotSupported = [0x6E, 0x00];

class NfcApduException implements Exception {
  final String message;
  NfcApduException(this.message);
  @override
  String toString() => 'NfcApduException: $message';
}

List<Uint8List> chunkSealedWireToApdus(
  Uint8List sealedWireBytes, {
  int chunkSize = nfcChunkPayloadSize,
}) {
  if (chunkSize <= 0 || chunkSize > 255) {
    throw NfcApduException('chunk size must be 1..255');
  }
  if (sealedWireBytes.isEmpty) {
    throw NfcApduException('empty sealed wire');
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
    final data = sealedWireBytes.sublist(start, end);
    out.add(_buildApdu(i, total, data));
  }
  return out;
}

Uint8List _buildApdu(int idx, int total, Uint8List data) {
  final apdu = Uint8List(5 + data.length + 1);
  apdu[0] = nfcCla;
  apdu[1] = nfcInsGetChunk;
  apdu[2] = idx & 0xFF;
  apdu[3] = total & 0xFF;
  apdu[4] = data.length & 0xFF;
  apdu.setRange(5, 5 + data.length, data);
  apdu[5 + data.length] = 0x00;
  return apdu;
}

class NfcChunkApdu {
  final int chunkIndex;
  final int totalChunks;
  final Uint8List data;
  NfcChunkApdu({
    required this.chunkIndex,
    required this.totalChunks,
    required this.data,
  });
}

NfcChunkApdu parseChunkApdu(Uint8List apdu) {
  if (apdu.length < 5) throw NfcApduException('apdu too short');
  if (apdu[0] != nfcCla) throw NfcApduException('bad CLA');
  if (apdu[1] != nfcInsGetChunk) throw NfcApduException('bad INS');
  final idx = apdu[2];
  final total = apdu[3];
  if (total == 0) throw NfcApduException('total chunks is zero');
  final lc = apdu[4];
  if (apdu.length < 5 + lc) throw NfcApduException('truncated data');
  if (idx >= total) {
    throw NfcApduException('chunk index $idx >= total $total');
  }
  final data = Uint8List.fromList(apdu.sublist(5, 5 + lc));
  return NfcChunkApdu(chunkIndex: idx, totalChunks: total, data: data);
}

class NfcReassembler {
  final Map<int, Uint8List> _chunks = {};
  int _total = 0;

  int get total => _total;
  int get received => _chunks.length;

  bool get complete => _total > 0 && _chunks.length == _total;

  void accept(NfcChunkApdu chunk) {
    if (_total == 0) {
      _total = chunk.totalChunks;
    } else if (chunk.totalChunks != _total) {
      throw NfcApduException(
          'total mismatch: expected $_total got ${chunk.totalChunks}');
    }
    _chunks[chunk.chunkIndex] = chunk.data;
  }

  Uint8List assemble() {
    if (!complete) throw NfcApduException('missing chunks');
    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < _total; i++) {
      final c = _chunks[i];
      if (c == null) throw NfcApduException('missing chunk $i');
      builder.add(c);
    }
    return builder.toBytes();
  }

  void reset() {
    _chunks.clear();
    _total = 0;
  }
}
