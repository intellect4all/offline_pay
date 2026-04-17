import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' hide Poly1305;
import 'package:pointycastle/digests/blake2b.dart';
import 'package:pointycastle/macs/poly1305.dart';
import 'package:pointycastle/api.dart' show KeyParameter;

const int sealedBoxPubKeySize = 32;
const int sealedBoxPrivKeySize = 32;
const int _poly1305TagSize = 16;
const int sealedBoxOverhead = 32 + _poly1305TagSize;

class SealedBoxKeyPair {
  final SimpleKeyPair keyPair;
  final Uint8List publicKey;
  SealedBoxKeyPair({required this.keyPair, required this.publicKey});
}

Future<SealedBoxKeyPair> generateSealedBoxKeyPair() async {
  final algo = X25519();
  final kp = await algo.newKeyPair();
  final pub = await kp.extractPublicKey();
  return SealedBoxKeyPair(
    keyPair: kp,
    publicKey: Uint8List.fromList(pub.bytes),
  );
}

Future<Uint8List> sealAnonymous(List<int> recipientPub, List<int> plaintext) async {
  if (recipientPub.length != sealedBoxPubKeySize) {
    throw ArgumentError('sealed-box: recipient pubkey must be 32 bytes');
  }
  final algo = X25519();
  final ephKp = await algo.newKeyPair();
  final ephPub = (await ephKp.extractPublicKey()).bytes;

  final shared = await algo.sharedSecretKey(
    keyPair: ephKp,
    remotePublicKey: SimplePublicKey(recipientPub, type: KeyPairType.x25519),
  );
  final sharedBytes = Uint8List.fromList(await shared.extractBytes());

  final nonce24 = _sealedBoxNonce(ephPub, recipientPub);
  final beforenmKey = _hsalsa20(sharedBytes, _sigma, _zero16);
  final subkey = _hsalsa20(beforenmKey, _sigma, nonce24.sublist(0, 16));
  final ct = _secretBoxSeal(subkey, Uint8List.fromList(nonce24.sublist(16, 24)), Uint8List.fromList(plaintext));

  final out = Uint8List(32 + ct.length);
  out.setRange(0, 32, ephPub);
  out.setRange(32, out.length, ct);
  return out;
}

Future<Uint8List> openAnonymous(
  List<int> recipientPub,
  SimpleKeyPair recipientKeyPair,
  List<int> ciphertext,
) async {
  if (ciphertext.length < sealedBoxOverhead) {
    throw ArgumentError('sealed-box: ciphertext too short');
  }
  final ctBytes = Uint8List.fromList(ciphertext);
  final ephPub = ctBytes.sublist(0, 32);
  final body = ctBytes.sublist(32);

  final algo = X25519();
  final shared = await algo.sharedSecretKey(
    keyPair: recipientKeyPair,
    remotePublicKey: SimplePublicKey(ephPub, type: KeyPairType.x25519),
  );
  final sharedBytes = Uint8List.fromList(await shared.extractBytes());

  final nonce24 = _sealedBoxNonce(ephPub, recipientPub);
  final beforenmKey = _hsalsa20(sharedBytes, _sigma, _zero16);
  final subkey = _hsalsa20(beforenmKey, _sigma, nonce24.sublist(0, 16));
  return _secretBoxOpen(subkey, Uint8List.fromList(nonce24.sublist(16, 24)), body);
}

Uint8List _sealedBoxNonce(List<int> ephPub, List<int> recipientPub) {
  final h = Blake2bDigest(digestSize: 24);
  h.update(Uint8List.fromList(ephPub), 0, 32);
  h.update(Uint8List.fromList(recipientPub), 0, 32);
  final out = Uint8List(24);
  h.doFinal(out, 0);
  return out;
}

final Uint8List _sigma = Uint8List.fromList('expand 32-byte k'.codeUnits);
final Uint8List _zero16 = Uint8List(16);

Uint8List _secretBoxSeal(Uint8List key, Uint8List nonce8, Uint8List plaintext) {
  final keystreamLen = 32 + plaintext.length;
  final keystream = _salsa20Keystream(key, nonce8, keystreamLen);
  final polyKey = keystream.sublist(0, 32);
  final ct = Uint8List(plaintext.length);
  for (var i = 0; i < plaintext.length; i++) {
    ct[i] = plaintext[i] ^ keystream[32 + i];
  }
  final tag = _poly1305(polyKey, ct);
  final out = Uint8List(_poly1305TagSize + plaintext.length);
  out.setRange(0, _poly1305TagSize, tag);
  out.setRange(_poly1305TagSize, out.length, ct);
  return out;
}

Uint8List _secretBoxOpen(Uint8List key, Uint8List nonce8, Uint8List body) {
  if (body.length < _poly1305TagSize) {
    throw ArgumentError('sealed-box: body too short');
  }
  final tag = body.sublist(0, _poly1305TagSize);
  final ct = body.sublist(_poly1305TagSize);
  final keystream = _salsa20Keystream(key, nonce8, 32 + ct.length);
  final polyKey = keystream.sublist(0, 32);
  final expectedTag = _poly1305(polyKey, ct);
  if (!_constantTimeEquals(tag, expectedTag)) {
    throw StateError('sealed-box: authentication failed');
  }
  final pt = Uint8List(ct.length);
  for (var i = 0; i < ct.length; i++) {
    pt[i] = ct[i] ^ keystream[32 + i];
  }
  return pt;
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

Uint8List _poly1305(Uint8List key, Uint8List data) {
  final poly = Poly1305();
  poly.init(KeyParameter(key));
  poly.update(data, 0, data.length);
  final out = Uint8List(16);
  poly.doFinal(out, 0);
  return out;
}

int _rotl(int x, int n) {
  x &= 0xFFFFFFFF;
  return ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF;
}

void _salsaCore(List<int> out, List<int> input, {required int rounds, required bool finalAdd}) {
  final x = List<int>.filled(16, 0);
  for (var i = 0; i < 16; i++) {
    x[i] = input[i];
  }
  for (var i = 0; i < rounds; i += 2) {
    x[4] ^= _rotl((x[0] + x[12]) & 0xFFFFFFFF, 7);
    x[8] ^= _rotl((x[4] + x[0]) & 0xFFFFFFFF, 9);
    x[12] ^= _rotl((x[8] + x[4]) & 0xFFFFFFFF, 13);
    x[0] ^= _rotl((x[12] + x[8]) & 0xFFFFFFFF, 18);
    x[9] ^= _rotl((x[5] + x[1]) & 0xFFFFFFFF, 7);
    x[13] ^= _rotl((x[9] + x[5]) & 0xFFFFFFFF, 9);
    x[1] ^= _rotl((x[13] + x[9]) & 0xFFFFFFFF, 13);
    x[5] ^= _rotl((x[1] + x[13]) & 0xFFFFFFFF, 18);
    x[14] ^= _rotl((x[10] + x[6]) & 0xFFFFFFFF, 7);
    x[2] ^= _rotl((x[14] + x[10]) & 0xFFFFFFFF, 9);
    x[6] ^= _rotl((x[2] + x[14]) & 0xFFFFFFFF, 13);
    x[10] ^= _rotl((x[6] + x[2]) & 0xFFFFFFFF, 18);
    x[3] ^= _rotl((x[15] + x[11]) & 0xFFFFFFFF, 7);
    x[7] ^= _rotl((x[3] + x[15]) & 0xFFFFFFFF, 9);
    x[11] ^= _rotl((x[7] + x[3]) & 0xFFFFFFFF, 13);
    x[15] ^= _rotl((x[11] + x[7]) & 0xFFFFFFFF, 18);

    x[1] ^= _rotl((x[0] + x[3]) & 0xFFFFFFFF, 7);
    x[2] ^= _rotl((x[1] + x[0]) & 0xFFFFFFFF, 9);
    x[3] ^= _rotl((x[2] + x[1]) & 0xFFFFFFFF, 13);
    x[0] ^= _rotl((x[3] + x[2]) & 0xFFFFFFFF, 18);
    x[6] ^= _rotl((x[5] + x[4]) & 0xFFFFFFFF, 7);
    x[7] ^= _rotl((x[6] + x[5]) & 0xFFFFFFFF, 9);
    x[4] ^= _rotl((x[7] + x[6]) & 0xFFFFFFFF, 13);
    x[5] ^= _rotl((x[4] + x[7]) & 0xFFFFFFFF, 18);
    x[11] ^= _rotl((x[10] + x[9]) & 0xFFFFFFFF, 7);
    x[8] ^= _rotl((x[11] + x[10]) & 0xFFFFFFFF, 9);
    x[9] ^= _rotl((x[8] + x[11]) & 0xFFFFFFFF, 13);
    x[10] ^= _rotl((x[9] + x[8]) & 0xFFFFFFFF, 18);
    x[12] ^= _rotl((x[15] + x[14]) & 0xFFFFFFFF, 7);
    x[13] ^= _rotl((x[12] + x[15]) & 0xFFFFFFFF, 9);
    x[14] ^= _rotl((x[13] + x[12]) & 0xFFFFFFFF, 13);
    x[15] ^= _rotl((x[14] + x[13]) & 0xFFFFFFFF, 18);
  }
  for (var i = 0; i < 16; i++) {
    out[i] = finalAdd ? (x[i] + input[i]) & 0xFFFFFFFF : x[i];
  }
}

int _u32le(List<int> b, int o) =>
    b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | ((b[o + 3] & 0xFF) << 24);

void _putU32le(Uint8List b, int o, int v) {
  b[o] = v & 0xFF;
  b[o + 1] = (v >> 8) & 0xFF;
  b[o + 2] = (v >> 16) & 0xFF;
  b[o + 3] = (v >> 24) & 0xFF;
}

Uint8List _hsalsa20(Uint8List key, Uint8List constant, Uint8List input16) {
  final state = List<int>.filled(16, 0);
  state[0] = _u32le(constant, 0);
  state[1] = _u32le(key, 0);
  state[2] = _u32le(key, 4);
  state[3] = _u32le(key, 8);
  state[4] = _u32le(key, 12);
  state[5] = _u32le(constant, 4);
  state[6] = _u32le(input16, 0);
  state[7] = _u32le(input16, 4);
  state[8] = _u32le(input16, 8);
  state[9] = _u32le(input16, 12);
  state[10] = _u32le(constant, 8);
  state[11] = _u32le(key, 16);
  state[12] = _u32le(key, 20);
  state[13] = _u32le(key, 24);
  state[14] = _u32le(key, 28);
  state[15] = _u32le(constant, 12);

  final out = List<int>.filled(16, 0);
  _salsaCore(out, state, rounds: 20, finalAdd: false);

  final sub = Uint8List(32);
  _putU32le(sub, 0, out[0]);
  _putU32le(sub, 4, out[5]);
  _putU32le(sub, 8, out[10]);
  _putU32le(sub, 12, out[15]);
  _putU32le(sub, 16, out[6]);
  _putU32le(sub, 20, out[7]);
  _putU32le(sub, 24, out[8]);
  _putU32le(sub, 28, out[9]);
  return sub;
}

Uint8List _salsa20Keystream(Uint8List key, Uint8List nonce8, int length) {
  final out = Uint8List(length);
  final state = List<int>.filled(16, 0);
  state[0] = _u32le(_sigma, 0);
  state[1] = _u32le(key, 0);
  state[2] = _u32le(key, 4);
  state[3] = _u32le(key, 8);
  state[4] = _u32le(key, 12);
  state[5] = _u32le(_sigma, 4);
  state[6] = _u32le(nonce8, 0);
  state[7] = _u32le(nonce8, 4);
  state[8] = 0;
  state[9] = 0;
  state[10] = _u32le(_sigma, 8);
  state[11] = _u32le(key, 16);
  state[12] = _u32le(key, 20);
  state[13] = _u32le(key, 24);
  state[14] = _u32le(key, 28);
  state[15] = _u32le(_sigma, 12);

  final block = List<int>.filled(16, 0);
  final blockBytes = Uint8List(64);
  var off = 0;
  while (off < length) {
    _salsaCore(block, state, rounds: 20, finalAdd: true);
    for (var i = 0; i < 16; i++) {
      final w = block[i];
      blockBytes[i * 4] = w & 0xFF;
      blockBytes[i * 4 + 1] = (w >> 8) & 0xFF;
      blockBytes[i * 4 + 2] = (w >> 16) & 0xFF;
      blockBytes[i * 4 + 3] = (w >> 24) & 0xFF;
    }
    final take = (length - off) < 64 ? (length - off) : 64;
    out.setRange(off, off + take, blockBytes);
    off += take;
    state[8] = (state[8] + 1) & 0xFFFFFFFF;
    if (state[8] == 0) state[9] = (state[9] + 1) & 0xFFFFFFFF;
  }
  return out;
}
