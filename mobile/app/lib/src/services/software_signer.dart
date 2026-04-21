import 'dart:convert' show base64;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'signer.dart';

class SoftwareSigner implements HardwareSigner {
  static const _kPriv = 'offlinepay.signer.ed25519.priv';
  static const _kPub = 'offlinepay.signer.ed25519.pub';

  final FlutterSecureStorage _s;
  SoftwareSigner([FlutterSecureStorage? s])
      : _s = s ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  @override
  Future<SignerKeyDescriptor?> publicKeyDescriptor() async {
    final b64 = await _s.read(key: _kPub);
    if (b64 == null) return null;
    return SignerKeyDescriptor(
      algorithm: SignerAlgorithm.ed25519,
      publicKey: Uint8List.fromList(base64.decode(b64)),
      hardwareBacked: false,
    );
  }

  @override
  Future<SignerKeyDescriptor> generateKeyPair() async {
    final kp = await Ed25519().newKeyPair();
    final priv = await kp.extractPrivateKeyBytes();
    final pub = await kp.extractPublicKey();
    await _s.write(key: _kPriv, value: base64.encode(priv));
    await _s.write(key: _kPub, value: base64.encode(pub.bytes));
    return SignerKeyDescriptor(
      algorithm: SignerAlgorithm.ed25519,
      publicKey: Uint8List.fromList(pub.bytes),
      hardwareBacked: false,
    );
  }

  @override
  Future<Uint8List> sign(Uint8List message) async {
    final b64 = await _s.read(key: _kPriv);
    if (b64 == null) {
      throw StateError('SoftwareSigner: no key provisioned');
    }
    final seed = base64.decode(b64).sublist(0, 32);
    final kp = await Ed25519().newKeyPairFromSeed(seed);
    final sig = await Ed25519().sign(message, keyPair: kp);
    return Uint8List.fromList(sig.bytes);
  }

  @override
  Future<void> wipe() async {
    await _s.delete(key: _kPriv);
    await _s.delete(key: _kPub);
  }
}
