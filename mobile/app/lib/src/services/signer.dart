import 'dart:typed_data';

enum SignerAlgorithm {
  ed25519,
  ecdsaP256,
}

class SignerKeyDescriptor {
  final SignerAlgorithm algorithm;
  final Uint8List publicKey;
  final bool hardwareBacked;

  const SignerKeyDescriptor({
    required this.algorithm,
    required this.publicKey,
    required this.hardwareBacked,
  });
}

abstract class HardwareSigner {
  Future<SignerKeyDescriptor?> publicKeyDescriptor();

  Future<SignerKeyDescriptor> generateKeyPair();

  Future<Uint8List> sign(Uint8List message);

  Future<void> wipe();
}
