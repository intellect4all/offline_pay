import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Sha256;

import '../canonical.dart' show canonicalize;
import '../sealed_box.dart' show sealAnonymous;
import '../tokens.dart' show GossipBlob;
import 'payload.dart';

Future<List<GossipBlob>> sealGossipBlobs(
  List<GossipInnerPayload> plaintexts,
  List<int> serverPublicKey,
) async {
  final out = <GossipBlob>[];
  for (final p in plaintexts) {
    final canon = p.canonicalBytes();
    final ct = await sealAnonymous(serverPublicKey, canon);
    final txHash = (await Sha256().hash(canon)).bytes;
    final ceilingCanon = canonicalize(p.ceiling.payload.toJson());
    final ctHash = (await Sha256().hash(ceilingCanon)).bytes;
    out.add(GossipBlob(
      transactionHash: Uint8List.fromList(txHash),
      encryptedBlob: ct,
      bankSignature: p.ceiling.bankSignature,
      ceilingTokenHash: Uint8List.fromList(ctHash),
      hopCount: 0,
      blobSize: ct.length,
    ));
  }
  return out;
}
