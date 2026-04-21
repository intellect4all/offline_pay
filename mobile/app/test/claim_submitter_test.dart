import 'dart:convert' show base64, jsonEncode, utf8;

import 'package:flutter_test/flutter_test.dart';
import 'package:offlinepay_app/src/repositories/settlement_repository.dart';
import 'package:offlinepay_app/src/services/claim_submitter.dart';
import 'package:offlinepay_app/src/services/local_queue.dart';

void main() {
  group('ClaimSubmitter', () {
    test('empty queue → attempted=0', () async {
      final queue = _FakeQueue();
      final repo = _FakeSettlement();
      final s = ClaimSubmitter(
        queue: queue,
        settlement: repo,
        tokenProvider: () => 'bearer-xyz',
      );
      final report = await s.drainOnce();
      expect(report.attempted, 0);
      expect(report.settled, 0);
      expect(report.errorReason, isNull);
      expect(repo.callCount, 0);
    });

    test('all rows SETTLED → queue flips to SETTLED', () async {
      final queue = _FakeQueue();
      for (var i = 1; i <= 3; i++) {
        queue.insert(_txn(i));
      }
      final repo = _FakeSettlement()
        ..receipt = _receiptOf([
          _result('tx-1', 'TRANSACTION_STATUS_SETTLED'),
          _result('tx-2', 'TRANSACTION_STATUS_SETTLED'),
          _result('tx-3', 'TRANSACTION_STATUS_SETTLED'),
        ]);

      final s = ClaimSubmitter(
        queue: queue,
        settlement: repo,
        tokenProvider: () => 'bearer-xyz',
      );
      final report = await s.drainOnce();

      expect(report.attempted, 3);
      expect(report.settled, 3);
      expect(report.rejected, 0);
      expect(report.deferred, 0);
      expect(queue.rows['tx-1']!.state, TxnState.settled);
      expect(queue.rows['tx-2']!.state, TxnState.settled);
      expect(queue.rows['tx-3']!.state, TxnState.settled);
      expect(repo.lastCeilingCount, 1);
      expect(repo.callCount, 1);
      expect(repo.lastBatchId, isNotEmpty);
    });

    test('1 of 3 REJECTED → partial outcome, others SETTLED', () async {
      final queue = _FakeQueue();
      for (var i = 1; i <= 3; i++) {
        queue.insert(_txn(i));
      }
      final repo = _FakeSettlement()
        ..receipt = _receiptOf([
          _result('tx-1', 'TRANSACTION_STATUS_SETTLED'),
          _result('tx-2', 'TRANSACTION_STATUS_REJECTED', reason: 'bad_sig'),
          _result('tx-3', 'TRANSACTION_STATUS_SETTLED'),
        ]);

      final s = ClaimSubmitter(
        queue: queue,
        settlement: repo,
        tokenProvider: () => 'bearer-xyz',
      );
      final report = await s.drainOnce();

      expect(report.attempted, 3);
      expect(report.settled, 2);
      expect(report.rejected, 1);
      expect(queue.rows['tx-1']!.state, TxnState.settled);
      expect(queue.rows['tx-2']!.state, TxnState.rejected);
      expect(queue.rows['tx-2']!.rejectionReason, 'bad_sig');
      expect(queue.rows['tx-3']!.state, TxnState.settled);
    });

    test('repository throws → rows remain QUEUED', () async {
      final queue = _FakeQueue();
      queue.insert(_txn(1));
      queue.insert(_txn(2));
      final repo = _FakeSettlement()
        ..error = const ClaimRejected('http_503', 'gateway down', 503);

      final s = ClaimSubmitter(
        queue: queue,
        settlement: repo,
        tokenProvider: () => 'bearer-xyz',
      );
      final report = await s.drainOnce();

      expect(report.deferred, 2);
      expect(report.settled, 0);
      expect(report.errorReason, isNotNull);
      expect(queue.rows['tx-1']!.state, TxnState.queued);
      expect(queue.rows['tx-2']!.state, TxnState.queued);
    });

    test('null token provider → no-op', () async {
      final queue = _FakeQueue();
      queue.insert(_txn(1));
      final repo = _FakeSettlement();
      final s = ClaimSubmitter(
        queue: queue,
        settlement: repo,
        tokenProvider: () => null,
      );
      final report = await s.drainOnce();
      expect(report.attempted, 0);
      expect(repo.callCount, 0);
      expect(queue.rows['tx-1']!.state, TxnState.queued);
    });

    test('PARTIALLY_SETTLED → row flips to partiallySettled with server amount',
        () async {
      final queue = _FakeQueue();
      queue.insert(_txn(1));
      final repo = _FakeSettlement()
        ..receipt = _receiptOf([
          const ClaimResult(
            transactionId: 'tx-1',
            sequenceNumber: 1,
            submittedAmountKobo: 100,
            settledAmountKobo: 40,
            status: 'TRANSACTION_STATUS_PARTIALLY_SETTLED',
            reason: 'ceiling_exhausted',
          ),
        ]);
      final s = ClaimSubmitter(
        queue: queue,
        settlement: repo,
        tokenProvider: () => 'tok',
      );
      final report = await s.drainOnce();
      expect(report.partial, 1);
      expect(report.settled, 0);
      final row = queue.rows['tx-1']!;
      expect(row.state, TxnState.partiallySettled);
      expect(row.settledAmountKobo, 40);
      expect(row.amountKobo, 100);
      expect(row.rejectionReason, 'ceiling_exhausted');
    });

    test('PENDING result → row flips to pending (not resubmitted next drain)',
        () async {
      final queue = _FakeQueue();
      queue.insert(_txn(1));
      final repo = _FakeSettlement()
        ..receipt = _receiptOf([
          _result('tx-1', 'TRANSACTION_STATUS_PENDING'),
        ]);
      final s = ClaimSubmitter(
        queue: queue,
        settlement: repo,
        tokenProvider: () => 'tok',
      );
      final r1 = await s.drainOnce();
      expect(r1.deferred, 1);
      expect(queue.rows['tx-1']!.state, TxnState.pending);
      final r2 = await s.drainOnce();
      expect(r2.attempted, 0);
    });

    test('countryProvider value forwarded to settlement.submitClaim',
        () async {
      final queue = _FakeQueue();
      queue.insert(_txn(1));
      final repo = _FakeSettlement()
        ..receipt = _receiptOf([
          _result('tx-1', 'TRANSACTION_STATUS_SETTLED'),
        ]);
      final s = ClaimSubmitter(
        queue: queue,
        settlement: repo,
        tokenProvider: () => 'tok',
        countryProvider: () => 'NG',
      );
      await s.drainOnce();
      expect(repo.lastSubmitterCountry, 'NG');
    });

    test('SENT rows drain alongside RECEIVED rows', () async {
      final queue = _FakeQueue()
        ..insert(_txn(1, direction: TxnDirection.sent))
        ..insert(_txn(2, direction: TxnDirection.received))
        ..insert(_txn(3, direction: TxnDirection.sent));
      final repo = _FakeSettlement()
        ..receipt = _receiptOf([
          _result('tx-1', 'TRANSACTION_STATUS_SETTLED'),
          _result('tx-2', 'TRANSACTION_STATUS_SETTLED'),
          _result('tx-3', 'TRANSACTION_STATUS_SETTLED'),
        ]);

      final s = ClaimSubmitter(
        queue: queue,
        settlement: repo,
        tokenProvider: () => 'bearer-xyz',
      );
      final report = await s.drainOnce();

      expect(report.attempted, 3);
      expect(report.settled, 3);
      expect(queue.rows['tx-1']!.state, TxnState.settled);
      expect(queue.rows['tx-2']!.state, TxnState.settled);
      expect(queue.rows['tx-3']!.state, TxnState.settled);
    });

    test('null countryProvider → submitterCountry=null', () async {
      final queue = _FakeQueue();
      queue.insert(_txn(1));
      final repo = _FakeSettlement()
        ..receipt = _receiptOf([
          _result('tx-1', 'TRANSACTION_STATUS_SETTLED'),
        ]);
      final s = ClaimSubmitter(
        queue: queue,
        settlement: repo,
        tokenProvider: () => 'tok',
      );
      await s.drainOnce();
      expect(repo.lastSubmitterCountry, isNull);
    });
  });
}

LocalTxn _txn(int i, {TxnDirection direction = TxnDirection.received}) {
  return LocalTxn(
    id: 'tx-$i',
    direction: direction,
    payerId: 'payer-A',
    payeeId: 'payee-B',
    amountKobo: 100 * i,
    sequenceNumber: i,
    ceilingTokenId: 'ceil-1',
    state: TxnState.queued,
    createdAt: DateTime.utc(2026, 4, 14, 12, i),
    submittedAt: null,
    settledAt: null,
    rejectionReason: null,
    paymentTokenBlob: _paymentBlob(i),
    ceilingTokenBlob: _ceilingBlob(),
    requestBlob: _requestBlob(i),
  );
}

String _paymentBlob(int seq) {
  final m = <String, Object?>{
    'payer_id': 'payer-A',
    'payee_id': 'payee-B',
    'amount': 100 * seq,
    'sequence_number': seq,
    'remaining_ceiling': 10000,
    'timestamp': '2026-04-14T12:00:00Z',
    'ceiling_token_id': 'ceil-1',
    'payer_signature': base64.encode(List<int>.filled(64, 0x11)),
    'session_nonce': base64.encode(_nonceFor(seq)),
    'request_hash': base64.encode(List<int>.filled(32, 0x44)),
  };
  return base64.encode(utf8.encode(jsonEncode(m)));
}

List<int> _nonceFor(int seq) {
  final b = List<int>.filled(16, 0);
  b[0] = seq & 0xff;
  b[1] = (seq >> 8) & 0xff;
  return b;
}

String _requestBlob(int seq) {
  final card = <String, Object?>{
    'user_id': 'payee-B',
    'display_name': 'Payee B',
    'account_number': '8000000002',
    'issued_at': '2026-04-14T08:00:00Z',
    'bank_key_id': 'bank-key-1',
    'server_signature': base64.encode(List<int>.filled(64, 0x55)),
  };
  final m = <String, Object?>{
    'receiver_id': 'payee-B',
    'receiver_display_card': card,
    'amount': 100 * seq,
    'session_nonce': base64.encode(_nonceFor(seq)),
    'issued_at': '2026-04-14T11:59:00Z',
    'expires_at': '2026-04-14T12:59:00Z',
    'receiver_device_pubkey': base64.encode(List<int>.filled(32, 0x66)),
    'receiver_signature': base64.encode(List<int>.filled(64, 0x77)),
  };
  return base64.encode(utf8.encode(jsonEncode(m)));
}

String _ceilingBlob() {
  final m = <String, Object?>{
    'id': 'ceil-1',
    'payload': <String, Object?>{
      'payer_id': 'payer-A',
      'ceiling_amount': 50000,
      'issued_at': '2026-04-14T09:00:00Z',
      'expires_at': '2026-04-14T21:00:00Z',
      'sequence_start': 0,
      'public_key': base64.encode(List<int>.filled(32, 0x22)),
      'bank_key_id': 'bank-key-1',
    },
    'bank_signature': base64.encode(List<int>.filled(64, 0x33)),
  };
  return base64.encode(utf8.encode(jsonEncode(m)));
}

ClaimResult _result(String id, String status, {String? reason}) => ClaimResult(
      transactionId: id,
      sequenceNumber: int.parse(id.split('-').last),
      submittedAmountKobo: 100,
      settledAmountKobo: status == 'TRANSACTION_STATUS_SETTLED' ? 100 : 0,
      status: status,
      reason: reason,
    );

ClaimReceipt _receiptOf(List<ClaimResult> results) => ClaimReceipt(
      batchId: 'server-batch-1',
      receiverUserId: 'payee-B',
      totalSubmitted: results.length,
      totalSettled:
          results.where((r) => r.status == 'TRANSACTION_STATUS_SETTLED').length,
      totalPartial: 0,
      totalRejected: results
          .where((r) => r.status == 'TRANSACTION_STATUS_REJECTED')
          .length,
      totalAmountKobo: 0,
      status: 'SETTLEMENT_BATCH_STATUS_COMPLETED',
      submittedAt: DateTime.utc(2026, 4, 14, 13),
      processedAt: DateTime.utc(2026, 4, 14, 13, 0, 1),
      results: results,
    );

class _FakeQueue implements LocalQueue {
  final Map<String, LocalTxn> rows = {};

  void insert(LocalTxn t) => rows[t.id] = t;

  @override
  Future<List<LocalTxn>> listPending({TxnDirection? direction}) async {
    return rows.values
        .where((r) => r.state == TxnState.queued)
        .where((r) => direction == null || r.direction == direction)
        .toList();
  }

  @override
  Future<void> markStateUpdate(
    String id, {
    required TxnState state,
    DateTime? settledAt,
    int? settledAmountKobo,
    String? reason,
    String? serverTransactionId,
  }) async {
    final cur = rows[id];
    if (cur == null) return;
    rows[id] = LocalTxn(
      id: cur.id,
      direction: cur.direction,
      payerId: cur.payerId,
      payeeId: cur.payeeId,
      amountKobo: cur.amountKobo,
      settledAmountKobo: settledAmountKobo ?? cur.settledAmountKobo,
      sequenceNumber: cur.sequenceNumber,
      ceilingTokenId: cur.ceilingTokenId,
      state: state,
      createdAt: cur.createdAt,
      submittedAt: cur.submittedAt,
      settledAt: settledAt ?? cur.settledAt,
      rejectionReason: reason ?? cur.rejectionReason,
      paymentTokenBlob: cur.paymentTokenBlob,
      ceilingTokenBlob: cur.ceilingTokenBlob,
      requestBlob: cur.requestBlob,
      serverTransactionId: serverTransactionId ?? cur.serverTransactionId,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettlement implements SettlementRepository {
  ClaimReceipt? receipt;
  Object? error;
  int callCount = 0;
  int lastCeilingCount = 0;
  String? lastBatchId;
  String? lastSubmitterCountry;

  int lastRequestCount = 0;

  @override
  Future<ClaimReceipt> submitClaim({
    required String clientBatchId,
    required List<PaymentTokenWire> tokens,
    required List<CeilingTokenWire> ceilings,
    required List<PaymentRequestWire> requests,
    required String accessToken,
    String? submitterCountry,
  }) async {
    callCount++;
    lastCeilingCount = ceilings.length;
    lastRequestCount = requests.length;
    lastBatchId = clientBatchId;
    lastSubmitterCountry = submitterCountry;
    if (error != null) throw error!;
    return receipt!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
