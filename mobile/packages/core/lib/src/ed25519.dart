import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'canonical.dart';
import 'tokens.dart';

class Ed25519Keys {
  final SimpleKeyPair keyPair;
  final SimplePublicKey publicKey;
  Ed25519Keys({required this.keyPair, required this.publicKey});
}

Future<Ed25519Keys> generateEd25519KeyPair() async {
  final algo = Ed25519();
  final kp = await algo.newKeyPair();
  final pub = await kp.extractPublicKey();
  return Ed25519Keys(keyPair: kp, publicKey: pub);
}

Future<Uint8List> _sign(SimpleKeyPair kp, Uint8List msg) async {
  final algo = Ed25519();
  final sig = await algo.sign(msg, keyPair: kp);
  return Uint8List.fromList(sig.bytes);
}

Future<bool> _verify(List<int> pub, Uint8List msg, List<int> sig) async {
  final algo = Ed25519();
  return algo.verify(
    msg,
    signature: Signature(sig, publicKey: SimplePublicKey(pub, type: KeyPairType.ed25519)),
  );
}

Future<Uint8List> signCeiling(SimpleKeyPair keyPair, CeilingTokenPayload payload) async {
  payload.validate();
  return _sign(keyPair, canonicalize(payload));
}

Future<bool> verifyCeiling(List<int> pub, CeilingTokenPayload payload, List<int> signature) async {
  try {
    payload.validate();
  } on ArgumentError {
    return false;
  }
  return _verify(pub, canonicalize(payload), signature);
}

Future<Uint8List> signPayment(SimpleKeyPair keyPair, PaymentPayload payload) async {
  payload.validate();
  return _sign(keyPair, canonicalize(payload));
}

Future<bool> verifyPayment(List<int> pub, PaymentPayload payload, List<int> signature) async {
  try {
    payload.validate();
  } on ArgumentError {
    return false;
  }
  return _verify(pub, canonicalize(payload), signature);
}

Future<Uint8List> signDisplayCard(SimpleKeyPair keyPair, DisplayCardPayload payload) async {
  payload.validate();
  return _sign(keyPair, canonicalize(payload));
}

Future<bool> verifyDisplayCard(
    List<int> pub, DisplayCardPayload payload, List<int> signature) async {
  try {
    payload.validate();
  } on ArgumentError {
    return false;
  }
  return _verify(pub, canonicalize(payload), signature);
}

Future<Uint8List> signRequest(SimpleKeyPair keyPair, PaymentRequestPayload payload) async {
  payload.validate();
  return _sign(keyPair, canonicalize(payload));
}

Future<bool> verifyRequest(
    List<int> pub, PaymentRequestPayload payload, List<int> signature) async {
  try {
    payload.validate();
  } on ArgumentError {
    return false;
  }
  return _verify(pub, canonicalize(payload), signature);
}

Future<Uint8List> hashRequest(PaymentRequest request) async {
  final msg = canonicalize(request);
  final digest = await Sha256().hash(msg);
  return Uint8List.fromList(digest.bytes);
}
