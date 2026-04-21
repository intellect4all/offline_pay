import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlinepay_app/src/services/local_queue.dart';
import 'package:sqflite/sqflite.dart' show DatabaseException;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LocalQueue ghost-reap + recovery', () {
    late LocalQueue queue;

    setUp(() async {
      queue = await LocalQueue.open(overridePath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await queue.close();
    });

    test('applyRecoveryInitiated expires SENT/QUEUED rows and flips status',
        () async {
      final now = DateTime.now().toUtc();
      final ceilingId = 'ceil-recov-1';
      await queue.recordCeiling(_ceiling(ceilingId, now, 500000));
      await queue.enqueueSent(_txn(
        id: 'tx-queued',
        ceilingId: ceilingId,
        amountKobo: 50000,
        sequenceNumber: 1,
        state: TxnState.queued,
      ));
      await queue.enqueueSent(_txn(
        id: 'tx-submitted',
        ceilingId: ceilingId,
        amountKobo: 30000,
        sequenceNumber: 2,
        state: TxnState.submitted,
      ));
      await queue.enqueueSent(_txn(
        id: 'tx-partial',
        ceilingId: ceilingId,
        amountKobo: 10000,
        sequenceNumber: 3,
        state: TxnState.partiallySettled,
        settledAmountKobo: 10000,
      ));

      final releaseAfter = now.add(const Duration(hours: 72, minutes: 30));
      final reaped = await queue.applyRecoveryInitiated(
        ceilingId: ceilingId,
        releaseAfter: releaseAfter,
      );

      expect(reaped, 1);

      final rows = await queue.listAll();
      final byId = {for (final r in rows) r.id: r};
      expect(byId['tx-queued']!.state, TxnState.expired);
      expect(byId['tx-queued']!.rejectionReason, isNotNull);
      expect(byId['tx-queued']!.rejectionReason!,
          contains('ceiling recovery initiated'));
      expect(byId['tx-submitted']!.state, TxnState.submitted);
      expect(byId['tx-partial']!.state, TxnState.partiallySettled);

      final rec = await queue.currentOrRecoveringCeiling();
      expect(rec, isNotNull);
      expect(rec!.id, ceilingId);
      expect(rec.status, CeilingStatus.recoveryPending);
      expect(rec.releaseAfter, releaseAfter);
    });

    test('sumSent excludes expired + rejected; keeps settled + in-flight',
        () async {
      final now = DateTime.now().toUtc();
      final ceilingId = 'ceil-sum-1';
      await queue.recordCeiling(_ceiling(ceilingId, now, 1000000));
      await queue.enqueueSent(_txn(
        id: 'a',
        ceilingId: ceilingId,
        amountKobo: 10000,
        sequenceNumber: 1,
        state: TxnState.submitted,
      ));
      await queue.enqueueSent(_txn(
        id: 'b',
        ceilingId: ceilingId,
        amountKobo: 20000,
        sequenceNumber: 2,
        state: TxnState.pending,
      ));
      await queue.enqueueSent(_txn(
        id: 'c',
        ceilingId: ceilingId,
        amountKobo: 30000,
        sequenceNumber: 3,
        state: TxnState.settled,
        settledAmountKobo: 30000,
      ));
      await queue.enqueueSent(_txn(
        id: 'd-ghost',
        ceilingId: ceilingId,
        amountKobo: 40000,
        sequenceNumber: 4,
        state: TxnState.expired,
      ));
      await queue.enqueueSent(_txn(
        id: 'e-rejected',
        ceilingId: ceilingId,
        amountKobo: 50000,
        sequenceNumber: 5,
        state: TxnState.rejected,
      ));

      final sum = await queue.sumSent(ceilingId);
      expect(sum, 60000);
    });

    test('nextSequenceNumber ignores state — expired rows still burn slots',
        () async {
      final now = DateTime.now().toUtc();
      final ceilingId = 'ceil-seq-1';
      await queue.recordCeiling(_ceiling(ceilingId, now, 1000000));
      await queue.enqueueSent(_txn(
        id: 'seq1-ghost',
        ceilingId: ceilingId,
        amountKobo: 10000,
        sequenceNumber: 1,
        state: TxnState.expired,
      ));
      await queue.enqueueSent(_txn(
        id: 'seq2-settled',
        ceilingId: ceilingId,
        amountKobo: 20000,
        sequenceNumber: 2,
        state: TxnState.settled,
      ));

      final next = await queue.nextSequenceNumber(ceilingId, 0);
      expect(next, 3);
    });

    test(
        'currentOrRecoveringCeiling returns newest non-terminal, prefers '
        'live issue order', () async {
      final now = DateTime.now().toUtc();
      await queue.recordCeiling(
        _ceiling('old', now.subtract(const Duration(days: 1)), 100000),
      );
      await queue.markCeilingStatus('old', CeilingStatus.revoked);

      await queue.recordCeiling(_ceiling('newer', now, 500000));
      await queue.applyRecoveryInitiated(
        ceilingId: 'newer',
        releaseAfter: now.add(const Duration(hours: 72)),
      );

      final rec = await queue.currentOrRecoveringCeiling();
      expect(rec, isNotNull);
      expect(rec!.id, 'newer');
      expect(rec.status, CeilingStatus.recoveryPending);
    });

    test('currentOrRecoveringCeiling returns null when nothing is live',
        () async {
      final now = DateTime.now().toUtc();
      await queue.recordCeiling(_ceiling('only', now, 100000));
      await queue.markCeilingStatus('only', CeilingStatus.revoked);
      final rec = await queue.currentOrRecoveringCeiling();
      expect(rec, isNull);
    });
  });

  group('LocalQueue.enqueueReceived replay semantics', () {
    late LocalQueue queue;

    setUp(() async {
      queue = await LocalQueue.open(overridePath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await queue.close();
    });

    test('accepts same (payer, seq) across different ceilings', () async {
      await queue.enqueueReceived(_recv(
        id: 'rcv-A-1',
        ceilingId: 'ceil-A',
        sequenceNumber: 1,
        amountKobo: 100000,
      ));

      await queue.enqueueReceived(_recv(
        id: 'rcv-B-1',
        ceilingId: 'ceil-B',
        sequenceNumber: 1,
        amountKobo: 600000,
      ));

      final rows = await queue.listAll();
      final ids = rows.map((r) => r.id).toSet();
      expect(ids, containsAll(<String>{'rcv-A-1', 'rcv-B-1'}));
    });

    test(
        'raises DatabaseException on a true same-ceiling (payer, seq) '
        'replay instead of silently ignoring it', () async {
      await queue.enqueueReceived(_recv(
        id: 'rcv-first',
        ceilingId: 'ceil-X',
        sequenceNumber: 7,
        amountKobo: 250000,
      ));

      await expectLater(
        queue.enqueueReceived(_recv(
          id: 'rcv-replay',
          ceilingId: 'ceil-X',
          sequenceNumber: 7,
          amountKobo: 250000,
        )),
        throwsA(isA<DatabaseException>()),
      );

      final rows = await queue.listAll();
      expect(rows.where((r) => r.id == 'rcv-first'), hasLength(1));
      expect(rows.where((r) => r.id == 'rcv-replay'), isEmpty);
    });
  });
}

CeilingRecord _ceiling(String id, DateTime issuedAt, int ceilingKobo) =>
    CeilingRecord(
      id: id,
      ceilingKobo: ceilingKobo,
      sequenceStart: 0,
      issuedAt: issuedAt,
      expiresAt: issuedAt.add(const Duration(hours: 24)),
      bankKeyId: 'bank-1',
      payerPublicKey: Uint8List(32),
      bankSignature: Uint8List(64),
      ceilingTokenBlob: '',
      status: CeilingStatus.active,
      createdAt: issuedAt,
      updatedAt: issuedAt,
    );

LocalTxn _txn({
  required String id,
  required String ceilingId,
  required int amountKobo,
  required int sequenceNumber,
  required TxnState state,
  int? settledAmountKobo,
}) =>
    LocalTxn(
      id: id,
      direction: TxnDirection.sent,
      payerId: 'alice',
      payeeId: 'bob',
      amountKobo: amountKobo,
      settledAmountKobo: settledAmountKobo,
      sequenceNumber: sequenceNumber,
      ceilingTokenId: ceilingId,
      state: state,
      createdAt: DateTime.now().toUtc(),
      submittedAt: state == TxnState.queued ? null : DateTime.now().toUtc(),
      settledAt: null,
      rejectionReason: null,
      paymentTokenBlob: '',
      ceilingTokenBlob: '',
      requestBlob: '',
    );

LocalTxn _recv({
  required String id,
  required String ceilingId,
  required int sequenceNumber,
  required int amountKobo,
}) =>
    LocalTxn(
      id: id,
      direction: TxnDirection.received,
      payerId: 'payer-1',
      payeeId: 'merchant-1',
      amountKobo: amountKobo,
      sequenceNumber: sequenceNumber,
      ceilingTokenId: ceilingId,
      state: TxnState.queued,
      createdAt: DateTime.now().toUtc(),
      submittedAt: null,
      settledAt: null,
      rejectionReason: null,
      paymentTokenBlob: '',
      ceilingTokenBlob: '',
      requestBlob: '',
    );
