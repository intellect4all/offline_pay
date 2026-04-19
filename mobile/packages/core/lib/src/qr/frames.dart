import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

const int protocolVersion = 1;

const int kindHeader = 0;
const int kindPayload = 1;
const int kindTrailer = 2;

const int defaultChunkSize = 2048;

class QrFrameException implements Exception {
  final String message;
  QrFrameException(this.message);
  @override
  String toString() => 'QrFrameException: $message';
}

class Frame {
  final int kind;
  final int index;
  final int totalFrames;
  final int protocol;
  final String contentType;
  final Uint8List payload;

  Frame({
    required this.kind,
    required this.index,
    required this.totalFrames,
    required this.protocol,
    this.contentType = '',
    required this.payload,
  });
}

Uint8List _sha256(Uint8List data) {
  final d = SHA256Digest();
  d.update(data, 0, data.length);
  final out = Uint8List(32);
  d.doFinal(out, 0);
  return out;
}

List<Frame> chunk(Uint8List content, int chunkSize, String contentType) {
  if (chunkSize <= 0) chunkSize = defaultChunkSize;
  if (contentType.isEmpty) {
    throw QrFrameException('content_type required');
  }
  final hash = _sha256(content);

  final payloads = <Uint8List>[];
  for (var i = 0; i < content.length; i += chunkSize) {
    final end = (i + chunkSize < content.length) ? i + chunkSize : content.length;
    payloads.add(Uint8List.fromList(content.sublist(i, end)));
  }
  if (payloads.isEmpty) payloads.add(Uint8List(0));

  final total = payloads.length + 2;
  final frames = <Frame>[];
  frames.add(Frame(
    kind: kindHeader,
    index: 0,
    totalFrames: total,
    protocol: protocolVersion,
    contentType: contentType,
    payload: Uint8List.fromList(hash),
  ));
  for (var i = 0; i < payloads.length; i++) {
    frames.add(Frame(
      kind: kindPayload,
      index: i + 1,
      totalFrames: total,
      protocol: protocolVersion,
      payload: payloads[i],
    ));
  }
  frames.add(Frame(
    kind: kindTrailer,
    index: total - 1,
    totalFrames: total,
    protocol: protocolVersion,
    payload: Uint8List.fromList(hash),
  ));
  return frames;
}

Uint8List encodeFrame(Frame f) {
  final ct = Uint8List.fromList(utf8.encode(f.contentType));
  final totalLen = 1 + 2 + 4 + 4 + 2 + ct.length + 4 + f.payload.length;
  final out = Uint8List(totalLen);
  final bd = ByteData.sublistView(out);
  out[0] = f.kind;
  bd.setUint16(1, f.protocol, Endian.big);
  bd.setUint32(3, f.index, Endian.big);
  bd.setUint32(7, f.totalFrames, Endian.big);
  bd.setUint16(11, ct.length, Endian.big);
  out.setRange(13, 13 + ct.length, ct);
  final plOff = 13 + ct.length;
  bd.setUint32(plOff, f.payload.length, Endian.big);
  out.setRange(plOff + 4, plOff + 4 + f.payload.length, f.payload);
  return out;
}

Frame decodeFrame(Uint8List b) {
  if (b.length < 1 + 2 + 4 + 4 + 2 + 4) {
    throw QrFrameException('bad frame');
  }
  final bd = ByteData.sublistView(b);
  final kind = b[0];
  if (kind != kindHeader && kind != kindPayload && kind != kindTrailer) {
    throw QrFrameException('bad frame');
  }
  final protocol = bd.getUint16(1, Endian.big);
  final index = bd.getUint32(3, Endian.big);
  final total = bd.getUint32(7, Endian.big);
  final ctLen = bd.getUint16(11, Endian.big);
  if (13 + ctLen > b.length) throw QrFrameException('bad frame');
  final ct = utf8.decode(b.sublist(13, 13 + ctLen));
  final plOff = 13 + ctLen;
  if (plOff + 4 > b.length) throw QrFrameException('bad frame');
  final plLen = bd.getUint32(plOff, Endian.big);
  if (plOff + 4 + plLen != b.length) throw QrFrameException('bad frame');
  final payload = Uint8List.fromList(b.sublist(plOff + 4, plOff + 4 + plLen));
  return Frame(
    kind: kind,
    index: index,
    totalFrames: total,
    protocol: protocol,
    contentType: ct,
    payload: payload,
  );
}

class Reassembler {
  int _total = 0;
  String _contentType = '';
  Uint8List? _hash;
  Uint8List? _checksum;
  final _payloads = <int, Uint8List>{};
  bool _sawHeader = false;
  bool _sawTrailer = false;

  String get contentType => _contentType;

  void accept(Frame f) {
    if (f.protocol != protocolVersion) {
      throw QrFrameException('unsupported protocol ${f.protocol}');
    }
    switch (f.kind) {
      case kindHeader:
        _total = f.totalFrames;
        _contentType = f.contentType;
        _hash = Uint8List.fromList(f.payload);
        _sawHeader = true;
        return;
      case kindTrailer:
        if (_total != 0 && f.totalFrames != _total) {
          throw QrFrameException('trailer total mismatch');
        }
        _total = f.totalFrames;
        _checksum = Uint8List.fromList(f.payload);
        _sawTrailer = true;
        return;
      case kindPayload:
        if (f.index == 0) {
          throw QrFrameException('payload frame index 0 is reserved');
        }
        _payloads[f.index] = Uint8List.fromList(f.payload);
        return;
      default:
        throw QrFrameException('bad frame');
    }
  }

  bool complete() {
    if (!_sawHeader || !_sawTrailer || _total == 0) return false;
    final expected = _total - 2;
    if (_payloads.length != expected) return false;
    for (var i = 1; i <= expected; i++) {
      if (!_payloads.containsKey(i)) return false;
    }
    return true;
  }

  List<int> missing() {
    if (_total < 2) return const [];
    final expected = _total - 2;
    final out = <int>[];
    for (var i = 1; i <= expected; i++) {
      if (!_payloads.containsKey(i)) out.add(i);
    }
    return out;
  }

  ({Uint8List content, String contentType}) assemble() {
    if (!complete()) {
      throw QrFrameException('missing frames');
    }
    final expected = _total - 2;
    final builder = BytesBuilder(copy: false);
    for (var i = 1; i <= expected; i++) {
      builder.add(_payloads[i]!);
    }
    final content = builder.toBytes();
    final sum = _sha256(content);
    if (!_byteEquals(sum, _hash!)) {
      throw QrFrameException('checksum mismatch');
    }
    if (!_byteEquals(sum, _checksum!)) {
      throw QrFrameException('checksum mismatch');
    }
    return (content: content, contentType: _contentType);
  }
}

bool _byteEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
