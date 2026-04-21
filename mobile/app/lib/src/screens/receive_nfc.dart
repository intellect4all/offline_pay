import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';

import '../presentation/cubits/app/app_cubit.dart';
import '../services/local_queue.dart';
import '../services/payment_verifier.dart';

class NfcReceiveResult {
  final VerifiedPayment? success;
  final String? error;
  const NfcReceiveResult.success(VerifiedPayment v)
      : success = v,
        error = null;
  const NfcReceiveResult.failure(String msg)
      : success = null,
        error = msg;
}

Future<NfcReceiveResult> handleNfcSealedWire(
  AppCubit cubit,
  Uint8List wire,
) async {
  try {
    final opened = await openEnvelopeFromWire(
      wire,
      cubit.realmKeyForVersion,
    );
    final env = opened.envelope;
    final payload = env.paymentToken.payload;
    if (payload.payerId == cubit.state.userId) {
      return const NfcReceiveResult.failure('Self-pay rejected.');
    }
    var verified = false;
    if (env.ceiling != null) {
      verified = await verifyPayment(
        env.ceiling!.payload.payerPublicKey,
        payload,
        env.paymentToken.payerSignature,
      );
    }
    final rawJson = <String, Object?>{
      ...payload.toJson(),
      'payer_signature': base64.encode(env.paymentToken.payerSignature),
    };
    final txn = LocalTxn(
      id: '${payload.ceilingTokenId}:${payload.sequenceNumber}',
      direction: TxnDirection.received,
      payerId: payload.payerId,
      payeeId: cubit.state.userId ?? payload.payeeId,
      amountKobo: payload.amount,
      sequenceNumber: payload.sequenceNumber,
      ceilingTokenId: payload.ceilingTokenId,
      state: TxnState.queued,
      createdAt: DateTime.now().toUtc(),
      submittedAt: null,
      settledAt: null,
      rejectionReason: null,
      paymentTokenBlob: LocalQueue.encodeJsonBlob(rawJson),
      ceilingTokenBlob: '',
      counterDisplayName: env.payerDisplayCard?.payload.displayName,
    );
    await cubit.queue.enqueueReceived(txn);
    await cubit.refreshLocal();
    final verifiedPayment = VerifiedPayment(
      transactionId: txn.id,
      payerId: payload.payerId,
      payeeId: txn.payeeId,
      ceilingTokenId: payload.ceilingTokenId,
      amountKobo: payload.amount,
      sequenceNumber: payload.sequenceNumber,
      timestamp: payload.timestamp,
      paymentTokenBytes: canonicalize(env.paymentToken.toJson()),
      ceilingTokenBytes: env.ceiling != null
          ? canonicalize(env.ceiling!.toJson())
          : Uint8List(0),
    );
    if (!verified) {
      return NfcReceiveResult.success(verifiedPayment);
    }
    return NfcReceiveResult.success(verifiedPayment);
  } on UnknownKeyVersionError catch (e) {
    return NfcReceiveResult.failure(
      'Update required — unknown key version ${e.version}.',
    );
  } catch (e) {
    return NfcReceiveResult.failure('Reassembly/decrypt failed: $e');
  }
}
