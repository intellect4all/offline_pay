import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const int realmKeySize = 32;
const int aesGcmNonceSize = 12;
const int aesGcmTagSize = 16;

final _algo = AesGcm.with256bits();

Future<Uint8List> seal(
  List<int> key,
  List<int> nonce,
  List<int> plaintext, {
  List<int> associatedData = const [],
}) async {
  _checkKey(key);
  _checkNonce(nonce);
  final secretKey = SecretKey(key);
  final box = await _algo.encrypt(
    plaintext,
    secretKey: secretKey,
    nonce: nonce,
    aad: associatedData,
  );
  final out = Uint8List(box.cipherText.length + box.mac.bytes.length);
  out.setAll(0, box.cipherText);
  out.setAll(box.cipherText.length, box.mac.bytes);
  return out;
}

Future<Uint8List> open(
  List<int> key,
  List<int> nonce,
  List<int> ciphertext, {
  List<int> associatedData = const [],
}) async {
  _checkKey(key);
  _checkNonce(nonce);
  if (ciphertext.length < aesGcmTagSize) {
    throw ArgumentError('aes-gcm: ciphertext too short');
  }
  final split = ciphertext.length - aesGcmTagSize;
  final ct = ciphertext.sublist(0, split);
  final tag = ciphertext.sublist(split);
  final box = SecretBox(ct, nonce: nonce, mac: Mac(tag));
  final pt = await _algo.decrypt(
    box,
    secretKey: SecretKey(key),
    aad: associatedData,
  );
  return Uint8List.fromList(pt);
}

Uint8List deriveFrameNonce(List<int> base, int frameIndex) {
  if (base.length != aesGcmNonceSize) {
    throw ArgumentError('aes-gcm: nonce must be 12 bytes');
  }
  if (frameIndex < 0 || frameIndex > 0xFFFFFFFF) {
    throw ArgumentError('aes-gcm: frame index out of range');
  }
  final out = Uint8List(aesGcmNonceSize);
  out.setRange(0, aesGcmNonceSize, base);
  final bd = ByteData.sublistView(out);
  bd.setUint32(aesGcmNonceSize - 4, frameIndex, Endian.big);
  return out;
}

void _checkKey(List<int> k) {
  if (k.length != realmKeySize) {
    throw ArgumentError('aes-gcm: key must be 32 bytes');
  }
}

void _checkNonce(List<int> n) {
  if (n.length != aesGcmNonceSize) {
    throw ArgumentError('aes-gcm: nonce must be 12 bytes');
  }
}
