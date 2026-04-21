import 'dart:convert' show utf8;

import 'package:cryptography/cryptography.dart' show Sha256;

import '../repositories/settlement_repository.dart';
import 'local_queue.dart';
import 'sync.dart' show TokenProvider;

class DrainReport {
  final int attempted;
  final int settled;
  final int partial;
  final int rejected;
  final int deferred;
  final String? errorReason;

  const DrainReport({
    required this.attempted,
    required this.settled,
    required this.partial,
    required this.rejected,
    required this.deferred,
    required this.errorReason,
  });

  const DrainReport.empty()
      : attempted = 0,
        settled = 0,
        partial = 0,
        rejected = 0,
        deferred = 0,
        errorReason = null;

  @override
  String toString() {
    if (errorReason != null) {
      return 'DrainReport(error="$errorReason", deferred=$deferred)';
    }
    return 'DrainReport(attempted=$attempted, settled=$settled, '
        'partial=$partial, rejected=$rejected, deferred=$deferred)';
  }
}

typedef CountryProvider = String? Function();

class ClaimSubmitter {
  final LocalQueue queue;
  final SettlementRepository settlement;
  final TokenProvider tokenProvider;
  final CountryProvider? countryProvider;
  final int batchSize;

  ClaimSubmitter({
    required this.queue,
    required this.settlement,
    required this.tokenProvider,
    this.countryProvider,
    this.batchSize = 50,
  });

  Future<DrainReport> drainOnce() async {
    final token = tokenProvider();
    if (token == null) {
      return const DrainReport.empty();
    }

    final queued = await queue.listPending();
    if (queued.isEmpty) return const DrainReport.empty();

    final rows =
        queued.length <= batchSize ? queued : queued.sublist(0, batchSize);

    final tokens = <PaymentTokenWire>[];
    final seenCeilings = <String, CeilingTokenWire>{};
    final seenRequests = <String, PaymentRequestWire>{};
    final hydrated = <LocalTxn>[];
    var rejectedDuringHydrate = 0;
    var skippedEmptyBlob = 0;
    for (final r in rows) {
      if (r.paymentTokenBlob.isEmpty ||
          r.ceilingTokenBlob.isEmpty ||
          r.requestBlob.isEmpty) {
        skippedEmptyBlob++;
        continue;
      }
      try {
        final pt = PaymentTokenWire.fromBlob(r.paymentTokenBlob);
        final ct = CeilingTokenWire.fromBlob(r.ceilingTokenBlob);
        final pr = PaymentRequestWire.fromBlob(r.requestBlob);
        tokens.add(pt);
        seenCeilings[ct.id] = ct;
        seenRequests[pr.sessionNonceB64] = pr;
        hydrated.add(r);
      } catch (e) {
        await queue.markStateUpdate(
          r.id,
          state: TxnState.rejected,
          reason: 'blob_hydrate: $e',
        );
        rejectedDuringHydrate++;
      }
    }

    if (hydrated.isEmpty) {
      return DrainReport(
        attempted: rows.length,
        settled: 0,
        partial: 0,
        rejected: rejectedDuringHydrate,
        deferred: skippedEmptyBlob,
        errorReason: null,
      );
    }

    final batchId = await _deriveBatchId(hydrated.map((r) => r.id));

    final ClaimReceipt receipt;
    try {
      receipt = await settlement.submitClaim(
        clientBatchId: batchId,
        tokens: tokens,
        ceilings: seenCeilings.values.toList(growable: false),
        requests: seenRequests.values.toList(growable: false),
        accessToken: token,
        submitterCountry: countryProvider?.call(),
      );
    } catch (e) {
      return DrainReport(
        attempted: hydrated.length,
        settled: 0,
        partial: 0,
        rejected: rejectedDuringHydrate,
        deferred: hydrated.length + skippedEmptyBlob,
        errorReason: e.toString(),
      );
    }

    // Positional match: the server returns one result per submitted
    // token in the same order. Row id is a local hash; server id is a
    // fresh ULID, so key-based lookup wouldn't work here.
    var settled = 0, partial = 0, rejected = rejectedDuringHydrate;
    var deferred = 0;
    final now = DateTime.now().toUtc();
    final resultsCount = receipt.results.length;
    for (var i = 0; i < hydrated.length; i++) {
      final row = hydrated[i];
      final res = i < resultsCount ? receipt.results[i] : null;
      if (res == null) {
        await queue.markStateUpdate(row.id, state: TxnState.pending);
        deferred++;
        continue;
      }
      final serverId = res.transactionId;
      final status = claimTxStatusFromWire(res.status);
      switch (status) {
        case ClaimTxStatus.settled:
          await queue.markStateUpdate(
            row.id,
            state: TxnState.settled,
            settledAt: now,
            settledAmountKobo: res.settledAmountKobo,
            serverTransactionId: serverId,
          );
          settled++;
          break;
        case ClaimTxStatus.partiallySettled:
          await queue.markStateUpdate(
            row.id,
            state: TxnState.partiallySettled,
            settledAt: now,
            settledAmountKobo: res.settledAmountKobo,
            reason: res.reason ?? 'ceiling_exhausted',
            serverTransactionId: serverId,
          );
          partial++;
          break;
        case ClaimTxStatus.rejected:
        case ClaimTxStatus.expired:
          await queue.markStateUpdate(
            row.id,
            state: TxnState.rejected,
            reason: res.reason ?? 'rejected',
            serverTransactionId: serverId,
          );
          rejected++;
          break;
        case ClaimTxStatus.pending:
        case ClaimTxStatus.unknown:
          await queue.markStateUpdate(
            row.id,
            state: TxnState.pending,
            serverTransactionId: serverId,
          );
          deferred++;
          break;
      }
    }

    return DrainReport(
      attempted: rows.length,
      settled: settled,
      partial: partial,
      rejected: rejected,
      deferred: deferred + skippedEmptyBlob,
      errorReason: null,
    );
  }

  Future<String> _deriveBatchId(Iterable<String> txIds) async {
    final sorted = txIds.toList()..sort();
    final joined = sorted.join('|');
    final hash = await Sha256().hash(utf8.encode(joined));
    final sb = StringBuffer();
    for (final b in hash.bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
