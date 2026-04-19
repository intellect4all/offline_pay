import 'dart:convert' show jsonDecode, utf8;
import 'dart:math' show Random;
import 'dart:typed_data';

import 'aes_gcm.dart' show aesGcmNonceSize, open, seal;
import 'canonical.dart' show canonicalize;
import 'qr/frames.dart' show Reassembler, chunk, defaultChunkSize, encodeFrame;
import 'tokens.dart' show PaymentRequest;

const String requestContentType = 'application/offlinepay.request+v1';

class SealedRequest {
  final Uint8List wireBytes;
  final int plaintextLen;
  SealedRequest({required this.wireBytes, required this.plaintextLen});
}

Future<SealedRequest> sealRequestToWire({
  required PaymentRequest request,
  required List<int> realmKey,
  required int keyVersion,
  Random? random,
}) async {
  if (keyVersion < 0 || keyVersion > 255) {
    throw ArgumentError('key_version must fit in one byte');
  }
  final plaintext = canonicalize(request);
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
  return SealedRequest(wireBytes: out, plaintextLen: plaintext.length);
}

List<Uint8List> chunkRequestFrames(
  Uint8List wireBytes, {
  int chunkSize = defaultChunkSize,
  String contentType = requestContentType,
}) {
  final frames = chunk(wireBytes, chunkSize, contentType);
  return frames.map(encodeFrame).toList(growable: false);
}

class OpenedRequest {
  final PaymentRequest request;
  final int keyVersion;
  OpenedRequest({required this.request, required this.keyVersion});
}

class UnknownRequestKeyVersionError implements Exception {
  final int version;
  UnknownRequestKeyVersionError(this.version);
  @override
  String toString() => 'unknown realm key version: $version';
}

typedef RealmKeyLookup = Uint8List? Function(int version);

Future<OpenedRequest> openRequestFromWire(
  Uint8List wire,
  RealmKeyLookup keyForVersion,
) async {
  if (wire.length < 1 + aesGcmNonceSize) {
    throw ArgumentError('request wire: too short');
  }
  final keyVersion = wire[0];
  final key = keyForVersion(keyVersion);
  if (key == null) {
    throw UnknownRequestKeyVersionError(keyVersion);
  }
  final baseNonce = wire.sublist(1, 1 + aesGcmNonceSize);
  final ct = wire.sublist(1 + aesGcmNonceSize);
  final aad = Uint8List.fromList([keyVersion]);
  final plaintext = await open(key, baseNonce, ct, associatedData: aad);
  final jsonMap = jsonDecode(utf8.decode(plaintext));
  if (jsonMap is! Map) {
    throw FormatException(
      'request wire: expected JSON object, got ${jsonMap.runtimeType}',
    );
  }
  final request = PaymentRequest.fromJson(jsonMap.cast<String, Object?>());
  return OpenedRequest(request: request, keyVersion: keyVersion);
}

Uint8List? reassembleRequestWire(Reassembler r) {
  if (!r.complete()) return null;
  if (r.contentType != requestContentType) return null;
  return r.assemble().content;
}
