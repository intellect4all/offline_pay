import 'dart:convert' show base64;
import 'dart:typed_data';

import 'package:built_collection/built_collection.dart';
import 'package:dio/dio.dart';
import 'package:offlinepay_api/offlinepay_api.dart' as gen;

import 'claim_wire.dart';

export 'claim_wire.dart'
    show
        ClaimReceipt,
        ClaimRejected,
        ClaimResult,
        ClaimTxStatus,
        claimTxStatusFromWire,
        CeilingTokenWire,
        DisplayCardWire,
        PaymentRequestWire,
        PaymentTokenWire;

class SyncedTxn {
  final String transactionId;
  final String payerId;
  final String payeeId;
  final int amountKobo;
  final int settledAmountKobo;
  final int sequenceNumber;
  final String ceilingTokenId;

  final String status;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? settledAt;

  const SyncedTxn({
    required this.transactionId,
    required this.payerId,
    required this.payeeId,
    required this.amountKobo,
    required this.settledAmountKobo,
    required this.sequenceNumber,
    required this.ceilingTokenId,
    required this.status,
    required this.rejectionReason,
    required this.submittedAt,
    required this.settledAt,
  });

  factory SyncedTxn.fromGen(gen.SyncedTransaction t) => SyncedTxn(
        transactionId: t.transactionId,
        payerId: t.payerId,
        payeeId: t.payeeId,
        amountKobo: t.amountKobo,
        settledAmountKobo: t.settledAmountKobo,
        sequenceNumber: t.sequenceNumber,
        ceilingTokenId: t.ceilingTokenId,
        status: t.status.name,
        rejectionReason: t.rejectionReason,
        submittedAt: t.submittedAt,
        settledAt: t.settledAt,
      );
}

class SyncResult {
  final List<SyncedTxn> payerSide;
  final List<SyncedTxn> receiverSide;
  final DateTime syncedAt;
  final int finalizedCount;

  const SyncResult({
    required this.payerSide,
    required this.receiverSide,
    required this.syncedAt,
    required this.finalizedCount,
  });
}

class SettlementRepository {
  final gen.OfflinepayApi _api;

  SettlementRepository({required gen.OfflinepayApi api}) : _api = api;

  gen.DefaultApi get _default => _api.getDefaultApi();

  Map<String, dynamic> _authHeaders(String accessToken) => <String, dynamic>{
        'Authorization': 'Bearer $accessToken',
      };

  Future<SyncResult> syncUser({
    DateTime? since,
    List<String> disputed = const [],
    bool finalize = false,
    required String accessToken,
  }) async {
    final body = gen.SyncBody((b) {
      if (since != null) b.since = since.toUtc();
      if (disputed.isNotEmpty) {
        b.disputedTransactionIds = ListBuilder<String>(disputed);
      }
      b.finalize = finalize;
    });
    final resp = await _default.postV1SettlementSync(
      syncBody: body,
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('settlement: syncUser returned empty body');
    }
    return SyncResult(
      payerSide: data.payerSide.map(SyncedTxn.fromGen).toList(growable: false),
      receiverSide:
          data.receiverSide.map(SyncedTxn.fromGen).toList(growable: false),
      syncedAt: data.syncedAt,
      finalizedCount: data.finalizedCount,
    );
  }

  Future<ClaimReceipt> submitClaim({
    required String clientBatchId,
    required List<PaymentTokenWire> tokens,
    required List<CeilingTokenWire> ceilings,
    required List<PaymentRequestWire> requests,
    required String accessToken,
    String? submitterCountry,
  }) async {
    final body = gen.SubmitClaimBody((b) {
      b.clientBatchId = clientBatchId;
      b.tokens = ListBuilder<gen.PaymentTokenInput>(
        tokens.map((t) => t.toGen()),
      );
      b.ceilings = ListBuilder<gen.CeilingTokenInput>(
        ceilings.map((c) => c.toGen()),
      );
      b.requests = ListBuilder<gen.PaymentRequestInput>(
        requests.map((r) => r.toGen()),
      );
    });
    final headers = _authHeaders(accessToken);
    final country = submitterCountry?.trim().toUpperCase();
    if (country != null && country.isNotEmpty) {
      headers['X-Submitter-Country'] = country;
    }
    try {
      final resp = await _default.postV1SettlementClaims(
        submitClaimBody: body,
        headers: headers,
      );
      final data = resp.data;
      if (data == null) {
        throw const ClaimRejected(
          'empty_body',
          'submitClaim: server returned empty body',
          null,
        );
      }
      return ClaimReceipt.fromGen(data);
    } on DioException catch (e) {
      throw ClaimRejected(
        'http_${e.response?.statusCode ?? 0}',
        e.message ?? e.toString(),
        e.response?.statusCode,
      );
    }
  }

  Future<GossipUploadResult> uploadGossip({
    required List<GossipBlobWire> blobs,
    required String accessToken,
  }) async {
    if (blobs.isEmpty) {
      return const GossipUploadResult(accepted: 0, duplicates: 0, invalid: 0);
    }
    final body = gen.GossipUploadBody((b) {
      b.blobs = ListBuilder<gen.GossipBlobInput>(
        blobs.map((w) => w.toGen()),
      );
    });
    final resp = await _default.postV1SettlementGossip(
      gossipUploadBody: body,
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('settlement: uploadGossip returned empty body');
    }
    return GossipUploadResult(
      accepted: data.accepted,
      duplicates: data.duplicates,
      invalid: data.invalid,
    );
  }
}

class GossipBlobWire {
  final String transactionHashB64;
  final String encryptedBlobB64;
  final String bankSignatureB64;
  final String ceilingTokenHashB64;
  final int hopCount;
  final int blobSize;

  const GossipBlobWire({
    required this.transactionHashB64,
    required this.encryptedBlobB64,
    required this.bankSignatureB64,
    required this.ceilingTokenHashB64,
    required this.hopCount,
    required this.blobSize,
  });

  factory GossipBlobWire.fromBytes({
    required Uint8List transactionHash,
    required Uint8List encryptedBlob,
    required Uint8List bankSignature,
    required Uint8List ceilingTokenHash,
    required int hopCount,
    required int blobSize,
  }) =>
      GossipBlobWire(
        transactionHashB64: base64.encode(transactionHash),
        encryptedBlobB64: base64.encode(encryptedBlob),
        bankSignatureB64: base64.encode(bankSignature),
        ceilingTokenHashB64: base64.encode(ceilingTokenHash),
        hopCount: hopCount,
        blobSize: blobSize,
      );

  gen.GossipBlobInput toGen() => gen.GossipBlobInput((b) => b
    ..transactionHash = transactionHashB64
    ..encryptedBlob = encryptedBlobB64
    ..bankSignature = bankSignatureB64
    ..ceilingTokenHash = ceilingTokenHashB64
    ..hopCount = hopCount
    ..blobSize = blobSize);
}

class GossipUploadResult {
  final int accepted;
  final int duplicates;
  final int invalid;

  const GossipUploadResult({
    required this.accepted,
    required this.duplicates,
    required this.invalid,
  });
}
