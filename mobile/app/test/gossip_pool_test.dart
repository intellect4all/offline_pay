import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlinepay_app/src/services/gossip_pool.dart';
import 'package:offlinepay_app/src/services/local_queue.dart';
import 'package:offlinepay_core/offlinepay_core.dart' show GossipBlob;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('GossipPool', () {
    late LocalQueue queue;
    late GossipPool pool;

    setUp(() async {
      queue = await LocalQueue.open(overridePath: inMemoryDatabasePath);
      pool = GossipPool(db: queue.db, maxCarry: 5, maxHops: 3);
    });

    tearDown(() async {
      await queue.close();
    });

    test('ingest dedups by transaction_hash', () async {
      final b = _blob(id: 1);
      await pool.ingest(b, selfUserId: 'me');
      await pool.ingest(b, selfUserId: 'me');
      await pool.ingest(b, selfUserId: 'me');
      final stats = await pool.stats();
      expect(stats['total'], 1);
      expect(stats['carryPending'], 1);
    });

    test('draw increments hop_count and filters at maxHops', () async {
      final b = _blob(id: 2);
      await pool.ingest(b, selfUserId: 'me');

      var drawn = await pool.draw(n: 10, selfUserId: 'me');
      expect(drawn, hasLength(1));
      expect(drawn.first.hopCount, 1);

      drawn = await pool.draw(n: 10, selfUserId: 'me');
      expect(drawn, hasLength(1));
      expect(drawn.first.hopCount, 2);

      drawn = await pool.draw(n: 10, selfUserId: 'me');
      expect(drawn, hasLength(1));
      expect(drawn.first.hopCount, 3);

      drawn = await pool.draw(n: 10, selfUserId: 'me');
      expect(drawn, isEmpty);

      final stats = await pool.stats();
      expect(stats['maxHop'], 3);
    });

    test('FIFO eviction preserves self-origin blobs', () async {
      for (var i = 1; i <= 3; i++) {
        await pool.ingest(_blob(id: i, originUserId: 'me'),
            selfUserId: 'me', originUserId: 'me');
      }
      for (var i = 10; i <= 14; i++) {
        await pool.ingest(_blob(id: i),
            selfUserId: 'me');
      }

      final stats = await pool.stats();
      expect(stats['total'], 5);
      final drawn = await pool.draw(n: 5, selfUserId: 'me');
      expect(drawn, hasLength(5));
      final drawnIds = drawn.take(3).map((b) => b.transactionHash[0]).toSet();
      expect(drawnIds, {1, 2, 3});
    });

    test('pendingForUpload excludes already-uploaded rows', () async {
      await pool.ingest(_blob(id: 1), selfUserId: 'me');
      await pool.ingest(_blob(id: 2), selfUserId: 'me');
      await pool.ingest(_blob(id: 3), selfUserId: 'me');

      var pending = await pool.pendingForUpload();
      expect(pending, hasLength(3));

      await pool.markUploaded([pending[0].transactionHash]);
      pending = await pool.pendingForUpload();
      expect(pending, hasLength(2));
      expect(pending.map((p) => p.transactionHash[0]).toSet(), {2, 3});

      final stats = await pool.stats();
      expect(stats['uploaded'], 1);
      expect(stats['carryPending'], 2);
    });

    test('draw with n=0 returns empty', () async {
      await pool.ingest(_blob(id: 1), selfUserId: 'me');
      final drawn = await pool.draw(n: 0, selfUserId: 'me');
      expect(drawn, isEmpty);
    });

    test('ingest persists origin_user_id', () async {
      await pool.ingest(_blob(id: 42),
          selfUserId: 'me', originUserId: 'someone-else');
      final drawn = await pool.draw(n: 5, selfUserId: 'me');
      expect(drawn, hasLength(1));
      expect(drawn.first.transactionHash[0], 42);
    });

    test('draw skips uploaded blobs', () async {
      await pool.ingest(_blob(id: 1), selfUserId: 'me');
      await pool.ingest(_blob(id: 2), selfUserId: 'me');
      await pool.markUploaded([
        Uint8List.fromList([1, ...List<int>.filled(31, 0xAA)]),
      ]);
      final drawn = await pool.draw(n: 10, selfUserId: 'me');
      expect(drawn, hasLength(1));
      expect(drawn.first.transactionHash[0], 2);
    });

    test('draw skips own-origin blobs whose local txn is terminal', () async {
      const payerId = 'me';
      const seq = 42;
      await pool.ingest(
        _blob(id: 7),
        selfUserId: payerId,
        originUserId: payerId,
        payerId: payerId,
        sequenceNumber: seq,
      );
      await queue.enqueueSent(_settledTxn(payerId: payerId, seq: seq));
      final drawn = await pool.draw(n: 10, selfUserId: payerId);
      expect(drawn, isEmpty);
    });

    test('draw still returns own-origin blobs while txn is non-terminal',
        () async {
      const payerId = 'me';
      const seq = 99;
      await pool.ingest(
        _blob(id: 8),
        selfUserId: payerId,
        originUserId: payerId,
        payerId: payerId,
        sequenceNumber: seq,
      );
      await queue.enqueueSent(
        _settledTxn(payerId: payerId, seq: seq, state: TxnState.queued),
      );
      final drawn = await pool.draw(n: 10, selfUserId: payerId);
      expect(drawn, hasLength(1));
    });

    test('pruneByPayerSeq deletes matching blobs only', () async {
      await pool.ingest(
        _blob(id: 1),
        selfUserId: 'me',
        originUserId: 'me',
        payerId: 'me',
        sequenceNumber: 10,
      );
      await pool.ingest(
        _blob(id: 2),
        selfUserId: 'me',
        originUserId: 'me',
        payerId: 'me',
        sequenceNumber: 11,
      );
      await pool.ingest(_blob(id: 3), selfUserId: 'me');

      final pruned = await pool.pruneByPayerSeq([
        (payerId: 'me', sequenceNumber: 10),
      ]);
      expect(pruned, 1);
      final stats = await pool.stats();
      expect(stats['total'], 2);

      expect(await pool.pruneByPayerSeq([]), 0);
    });

    test('eviction prefers uploaded blobs as victims', () async {
      for (var i = 1; i <= 5; i++) {
        await pool.ingest(_blob(id: i), selfUserId: 'me');
      }
      await pool.markUploaded([
        Uint8List.fromList([1, ...List<int>.filled(31, 0xAA)]),
        Uint8List.fromList([2, ...List<int>.filled(31, 0xAA)]),
      ]);
      await pool.ingest(_blob(id: 6), selfUserId: 'me');
      final stats = await pool.stats();
      expect(stats['total'], 5);
      expect(stats['uploaded'], 1, reason: 'one of the two uploaded was evicted');
    });
  });
}

LocalTxn _settledTxn({
  required String payerId,
  required int seq,
  TxnState state = TxnState.settled,
}) {
  final now = DateTime.now().toUtc();
  return LocalTxn(
    id: 'tx-$payerId-$seq',
    direction: TxnDirection.sent,
    payerId: payerId,
    payeeId: 'payee-$seq',
    amountKobo: 1000,
    sequenceNumber: seq,
    ceilingTokenId: 'ceil-1',
    state: state,
    createdAt: now,
    submittedAt: state == TxnState.queued ? null : now,
    settledAt: state == TxnState.settled ? now : null,
    rejectionReason: null,
    paymentTokenBlob: '',
    ceilingTokenBlob: '',
  );
}

GossipBlob _blob({required int id, String? originUserId}) {
  return GossipBlob(
    transactionHash: Uint8List.fromList([id, ...List<int>.filled(31, 0xAA)]),
    encryptedBlob: Uint8List.fromList(List<int>.filled(200, 0xBB)),
    bankSignature: Uint8List.fromList(List<int>.filled(64, 0xCC)),
    ceilingTokenHash: Uint8List.fromList(List<int>.filled(32, 0xDD)),
    hopCount: 0,
    blobSize: 200,
  );
}
