import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:offlinepay_core/offlinepay_core.dart' show GossipBlob;

import '../repositories/settlement_repository.dart';
import 'gossip_pool.dart';
import 'sync.dart' show TokenProvider;

class GossipUploadReport {
  final int submitted;
  final int accepted;
  final int duplicates;
  final int invalid;
  final String? errorReason;

  const GossipUploadReport({
    required this.submitted,
    required this.accepted,
    required this.duplicates,
    required this.invalid,
    required this.errorReason,
  });

  const GossipUploadReport.empty()
      : submitted = 0,
        accepted = 0,
        duplicates = 0,
        invalid = 0,
        errorReason = null;

  @override
  String toString() {
    if (errorReason != null) {
      return 'GossipUploadReport(error="$errorReason", submitted=$submitted)';
    }
    return 'GossipUploadReport(submitted=$submitted, accepted=$accepted, '
        'duplicates=$duplicates, invalid=$invalid)';
  }
}

class GossipUploader {
  final GossipPool pool;
  final SettlementRepository settlement;
  final TokenProvider tokenProvider;
  final int batchSize;

  GossipUploader({
    required this.pool,
    required this.settlement,
    required this.tokenProvider,
    this.batchSize = 200,
  });

  Future<GossipUploadReport> uploadOnce() async {
    final token = tokenProvider();
    if (token == null) {
      debugPrint('gossip.upload: skipped — no access token');
      return const GossipUploadReport.empty();
    }

    final List<GossipBlob> pending =
        await pool.pendingForUpload(limit: batchSize);
    if (pending.isEmpty) return const GossipUploadReport.empty();

    debugPrint('gossip.upload: draining ${pending.length} blob(s)');

    final wire = pending
        .map((b) => GossipBlobWire.fromBytes(
              transactionHash: b.transactionHash,
              encryptedBlob: b.encryptedBlob,
              bankSignature: b.bankSignature,
              ceilingTokenHash: b.ceilingTokenHash,
              hopCount: b.hopCount,
              blobSize: b.blobSize,
            ))
        .toList(growable: false);

    final GossipUploadResult res;
    try {
      res = await settlement.uploadGossip(
        blobs: wire,
        accessToken: token,
      );
    } catch (e) {
      debugPrint('gossip.upload: network error: $e');
      return GossipUploadReport(
        submitted: pending.length,
        accepted: 0,
        duplicates: 0,
        invalid: 0,
        errorReason: e.toString(),
      );
    }

    debugPrint('gossip.upload: server response — accepted=${res.accepted} '
        'duplicates=${res.duplicates} invalid=${res.invalid}');

    final hashes = pending
        .map<Uint8List>((b) => b.transactionHash)
        .toList(growable: false);
    await pool.markUploaded(hashes);

    return GossipUploadReport(
      submitted: pending.length,
      accepted: res.accepted,
      duplicates: res.duplicates,
      invalid: res.invalid,
      errorReason: null,
    );
  }
}
