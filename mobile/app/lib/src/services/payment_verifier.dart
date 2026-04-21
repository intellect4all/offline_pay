import 'dart:convert' show base64;
import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart';

import '../presentation/cubits/app/app_state.dart' show ActiveRequest;
import '../util/txn_id.dart';
import 'gossip_pool.dart';
import 'keystore.dart';
import 'local_queue.dart';

enum VerifyFailure {
  decrypt,
  reassemble,
  signature,
  sequence,
  expired,
  ceilingMissing,
  insufficient,
  selfPay,
  unknownKeyVersion,
  noActiveRequest,
  requestMismatch,
  amountMismatch,
}

class VerifyException implements Exception {
  final VerifyFailure reason;
  final String detail;
  const VerifyException(this.reason, this.detail);
  @override
  String toString() => 'VerifyException(${reason.name}): $detail';
}

class VerifiedPayment {
  final String transactionId;
  final String payerId;
  final String payeeId;
  final String ceilingTokenId;
  final int amountKobo;
  final int sequenceNumber;
  final DateTime timestamp;
  final Uint8List paymentTokenBytes;
  final Uint8List ceilingTokenBytes;

  const VerifiedPayment({
    required this.transactionId,
    required this.payerId,
    required this.payeeId,
    required this.ceilingTokenId,
    required this.amountKobo,
    required this.sequenceNumber,
    required this.timestamp,
    required this.paymentTokenBytes,
    required this.ceilingTokenBytes,
  });
}

typedef RealmKeyResolver = Uint8List? Function(int version);

typedef ActiveRequestLookup = ActiveRequest? Function(List<int> sessionNonce);

const Duration ceilingGracePeriod = Duration(minutes: 30);

class PaymentVerifier {
  final Keystore keystore;
  final LocalQueue queue;
  final RealmKeyResolver realmKeyResolver;
  final ActiveRequestLookup? activeRequestLookup;
  final GossipPool? gossipPool;
  final DateTime Function() _now;

  PaymentVerifier({
    required this.keystore,
    required this.queue,
    required this.realmKeyResolver,
    this.activeRequestLookup,
    this.gossipPool,
    DateTime Function()? clock,
  }) : _now = clock ?? (() => DateTime.now().toUtc());

  Future<VerifiedPayment> verifyAndEnqueue(
    List<Uint8List> frames, {
    required String selfUserId,
  }) async {
    final wire = _reassemble(frames);
    final opened = await _openEnvelope(wire);
    final env = opened.envelope;

    final ceiling = env.ceiling;
    if (ceiling == null) {
      throw const VerifyException(
        VerifyFailure.ceilingMissing,
        'envelope has no embedded ceiling token; cannot verify offline',
      );
    }

    final payload = env.paymentToken.payload;

    if (payload.payerId == selfUserId) {
      throw const VerifyException(
        VerifyFailure.selfPay,
        'cannot receive payment from self',
      );
    }

    await _verifyBankSignature(ceiling);

    final payerSigOk = await verifyPayment(
      ceiling.payload.payerPublicKey,
      payload,
      env.paymentToken.payerSignature,
    );
    if (!payerSigOk) {
      throw const VerifyException(
        VerifyFailure.signature,
        'payer signature invalid',
      );
    }

    final lastSeen = await queue.lastSequenceFromPayer(
      payload.payerId,
      payload.ceilingTokenId,
    );
    if (lastSeen != null && payload.sequenceNumber <= lastSeen) {
      throw VerifyException(
        VerifyFailure.sequence,
        'sequence ${payload.sequenceNumber} not greater than last seen '
        '$lastSeen for ceiling ${payload.ceilingTokenId}',
      );
    }

    if (payload.remainingCeiling < 0) {
      throw VerifyException(
        VerifyFailure.insufficient,
        'remaining_ceiling < 0 (${payload.remainingCeiling})',
      );
    }

    final now = _now();
    if (ceiling.payload.expiresAt.add(ceilingGracePeriod).isBefore(now)) {
      throw VerifyException(
        VerifyFailure.expired,
        'ceiling expired at ${ceiling.payload.expiresAt.toIso8601String()}',
      );
    }

    ActiveRequest? activeRequest;
    final lookup = activeRequestLookup;
    if (lookup != null) {
      activeRequest = lookup(payload.sessionNonce);
      if (activeRequest == null) {
        throw const VerifyException(
          VerifyFailure.noActiveRequest,
          'no active PaymentRequest matches this session_nonce — ask the payer to rescan the invoice',
        );
      }
      final prAmount = activeRequest.request.payload.amount;
      if (prAmount != unboundAmount && prAmount != payload.amount) {
        throw VerifyException(
          VerifyFailure.amountMismatch,
          'payer paid ${payload.amount} but invoice asked for $prAmount',
        );
      }
    }
    final requestBlob = activeRequest == null
        ? ''
        : base64.encode(canonicalize(activeRequest.request));

    final paymentBytes = canonicalize(env.paymentToken.toJson());
    final ceilingBytes = canonicalize(ceiling.toJson());
    final transactionId = await deriveTransactionId(paymentBytes);

    final payerDisplayName = env.payerDisplayCard?.payload.displayName;
    final txn = LocalTxn(
      id: transactionId,
      direction: TxnDirection.received,
      payerId: payload.payerId,
      payeeId: payload.payeeId,
      amountKobo: payload.amount,
      sequenceNumber: payload.sequenceNumber,
      ceilingTokenId: payload.ceilingTokenId,
      state: TxnState.queued,
      createdAt: _now(),
      submittedAt: null,
      settledAt: null,
      rejectionReason: null,
      paymentTokenBlob: base64.encode(paymentBytes),
      ceilingTokenBlob: base64.encode(ceilingBytes),
      requestBlob: requestBlob,
      counterDisplayName: payerDisplayName,
    );
    await queue.enqueueReceived(txn);

    final pool = gossipPool;
    if (pool != null && env.blobs.isNotEmpty) {
      for (final b in env.blobs) {
        try {
          await pool.ingest(b, selfUserId: selfUserId);
        } catch (_) {
        }
      }
    }

    return VerifiedPayment(
      transactionId: transactionId,
      payerId: payload.payerId,
      payeeId: payload.payeeId,
      ceilingTokenId: payload.ceilingTokenId,
      amountKobo: payload.amount,
      sequenceNumber: payload.sequenceNumber,
      timestamp: payload.timestamp,
      paymentTokenBytes: paymentBytes,
      ceilingTokenBytes: ceilingBytes,
    );
  }

  Uint8List _reassemble(List<Uint8List> frames) {
    final r = Reassembler();
    for (final raw in frames) {
      try {
        r.accept(decodeFrame(raw));
      } on QrFrameException catch (e) {
        throw VerifyException(VerifyFailure.reassemble, e.message);
      }
    }
    if (!r.complete()) {
      throw const VerifyException(
        VerifyFailure.reassemble,
        'frame set incomplete',
      );
    }
    try {
      final wire = reassembleEnvelopeWire(r);
      if (wire == null) {
        throw const VerifyException(
          VerifyFailure.reassemble,
          'reassembly returned null',
        );
      }
      return wire;
    } on QrFrameException catch (e) {
      throw VerifyException(VerifyFailure.reassemble, e.message);
    }
  }

  Future<OpenedEnvelope> _openEnvelope(Uint8List wire) async {
    try {
      return await openEnvelopeFromWire(wire, realmKeyResolver);
    } on UnknownKeyVersionError catch (e) {
      throw VerifyException(
        VerifyFailure.unknownKeyVersion,
        'unknown realm key version ${e.version}',
      );
    } catch (e) {
      throw VerifyException(VerifyFailure.decrypt, '$e');
    }
  }

  Future<void> _verifyBankSignature(EnvelopeCeiling ceiling) async {
    final bankKeys = await keystore.readBankKeys();
    final keyId = ceiling.payload.bankKeyId;
    Map<String, dynamic>? match;
    for (final k in bankKeys) {
      if (k['key_id'] == keyId) {
        match = k;
        break;
      }
    }
    if (match == null) {
      throw VerifyException(
        VerifyFailure.signature,
        'bank key $keyId not in cached keyring',
      );
    }
    final pubB64 = match['public_key'] as String?;
    if (pubB64 == null || pubB64.isEmpty) {
      throw const VerifyException(
        VerifyFailure.signature,
        'bank key entry missing public_key',
      );
    }
    final pub = base64.decode(pubB64);
    final ok = await verifyCeiling(pub, ceiling.payload, ceiling.bankSignature);
    if (!ok) {
      throw const VerifyException(
        VerifyFailure.signature,
        'bank signature invalid on ceiling token',
      );
    }
  }

}
