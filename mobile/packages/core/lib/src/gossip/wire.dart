import 'dart:convert' show jsonDecode, utf8;
import 'dart:math' show Random;
import 'dart:typed_data';

import '../aes_gcm.dart' show aesGcmNonceSize, open, seal;
import '../qr/frames.dart'
    show Reassembler, chunk, defaultChunkSize, encodeFrame;
import 'envelope.dart' show GossipEnvelope;

const String envelopeContentType = 'application/offlinepay.envelope+v1';

class SealedEnvelope {
  final Uint8List wireBytes;
  final int plaintextLen;
  SealedEnvelope({required this.wireBytes, required this.plaintextLen});
}

Future<SealedEnvelope> sealEnvelopeToWire({
  required GossipEnvelope envelope,
  required List<int> realmKey,
  required int keyVersion,
  Random? random,
}) async {
  if (keyVersion < 0 || keyVersion > 255) {
    throw ArgumentError('key_version must fit in one byte');
  }
  final plaintext = envelope.canonicalBytes();
  final rnd = random ?? Random.secure();
  final baseNonce = Uint8List(aesGcmNonceSize);
  for (var i = 0; i < aesGcmNonceSize; i++) {
    baseNonce[i] = rnd.nextInt(256);
  }
  final aad = Uint8List.fromList([keyVersion]);
  final ct = await seal(realmKey, baseNonce, plaintext, associatedData: aad);
  final out = Uint8List(1 + aesGcmNonceSize + ct.length);
  out[0] = keyVersion;
  out.setRange(1, 1 + aesGcmNonceSize, baseNonce);
  out.setRange(1 + aesGcmNonceSize, out.length, ct);
  return SealedEnvelope(wireBytes: out, plaintextLen: plaintext.length);
}

List<Uint8List> chunkEnvelopeFrames(
  Uint8List wireBytes, {
  int chunkSize = defaultChunkSize,
  String contentType = envelopeContentType,
}) {
  final frames = chunk(wireBytes, chunkSize, contentType);
  return frames.map(encodeFrame).toList(growable: false);
}

class OpenedEnvelope {
  final GossipEnvelope envelope;
  final int keyVersion;
  OpenedEnvelope({required this.envelope, required this.keyVersion});
}

class UnknownKeyVersionError implements Exception {
  final int version;
  UnknownKeyVersionError(this.version);
  @override
  String toString() => 'unknown realm key version: $version';
}

Future<OpenedEnvelope> openEnvelopeFromWire(
  Uint8List wireBytes,
  List<int>? Function(int version) keyForVersion,
) async {
  if (wireBytes.length < 1 + aesGcmNonceSize) {
    throw ArgumentError('wire bytes too short');
  }
  final keyVersion = wireBytes[0];
  final key = keyForVersion(keyVersion);
  if (key == null) throw UnknownKeyVersionError(keyVersion);
  final baseNonce = wireBytes.sublist(1, 1 + aesGcmNonceSize);
  final ct = wireBytes.sublist(1 + aesGcmNonceSize);
  final aad = Uint8List.fromList([keyVersion]);
  final pt = await open(key, baseNonce, ct, associatedData: aad);
  final json = jsonDecode(utf8.decode(pt)) as Map<String, Object?>;
  return OpenedEnvelope(
    envelope: GossipEnvelope.fromJson(json),
    keyVersion: keyVersion,
  );
}

Uint8List? reassembleEnvelopeWire(Reassembler r) {
  if (!r.complete()) return null;
  return r.assemble().content;
}
