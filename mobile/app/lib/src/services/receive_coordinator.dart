import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';

import '../presentation/cubits/app/app_state.dart' show ActiveRequest;
import 'keystore.dart';

const Duration defaultRequestTtl = Duration(minutes: 5);

class ReceiveCoordinator {
  final Keystore keystore;
  final DateTime Function() _now;

  ReceiveCoordinator({
    required this.keystore,
    DateTime Function()? clock,
  }) : _now = clock ?? (() => DateTime.now().toUtc());

  Future<ActiveRequest> issue({
    required String receiverUserId,
    required DisplayCard displayCard,
    required int amountKobo,
    required Uint8List realmKey,
    required int realmKeyVersion,
    Duration ttl = defaultRequestTtl,
    Random? random,
  }) async {
    if (displayCard.payload.userId != receiverUserId) {
      throw ArgumentError(
        'display card user_id (${displayCard.payload.userId}) does not match '
        'receiver_user_id ($receiverUserId)',
      );
    }
    final rnd = random ?? Random.secure();
    final nonce = Uint8List(sessionNonceSize);
    for (var i = 0; i < sessionNonceSize; i++) {
      nonce[i] = rnd.nextInt(256);
    }
    final kp = await keystore.loadKeyPair();
    final devicePub = Uint8List.fromList((await kp.extractPublicKey()).bytes);

    final now = _now();
    final payload = PaymentRequestPayload(
      receiverId: receiverUserId,
      receiverDisplayCard: displayCard,
      amount: amountKobo,
      sessionNonce: nonce,
      issuedAt: now,
      expiresAt: now.add(ttl),
      receiverDevicePubkey: devicePub,
    );
    final sig = await signRequest(kp, payload);
    final request = PaymentRequest(payload: payload, receiverSignature: sig);

    final sealed = await sealRequestToWire(
      request: request,
      realmKey: realmKey,
      keyVersion: realmKeyVersion,
      random: rnd,
    );
    final frames = chunkRequestFrames(sealed.wireBytes, chunkSize: 256);

    return ActiveRequest(
      request: request,
      qrFrames: frames,
      issuedAt: payload.issuedAt,
      expiresAt: payload.expiresAt,
    );
  }
}
