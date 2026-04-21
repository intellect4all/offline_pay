import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offlinepay_app/src/repositories/settlement_repository.dart';
import 'package:offlinepay_app/src/services/gossip_pool.dart';
import 'package:offlinepay_app/src/services/gossip_uploader.dart';
import 'package:offlinepay_app/src/services/local_queue.dart';
import 'package:offlinepay_core/offlinepay_core.dart' show GossipBlob;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('GossipUploader', () {
    late LocalQueue queue;
    late GossipPool pool;

    setUp(() async {
      queue = await LocalQueue.open(overridePath: inMemoryDatabasePath);
      pool = GossipPool(db: queue.db);
    });

    tearDown(() async {
      await queue.close();
    });

    test('empty pool → zero report', () async {
      final repo = _FakeSettlement();
      final u = GossipUploader(
        pool: pool,
        settlement: repo,
        tokenProvider: () => 'tok',
      );
      final report = await u.uploadOnce();
      expect(report.submitted, 0);
      expect(report.accepted, 0);
      expect(repo.callCount, 0);
    });

    test('pool of 5 → uploads batch, marks all uploaded', () async {
      for (var i = 1; i <= 5; i++) {
        await pool.ingest(_blob(i), selfUserId: 'me');
      }
      final repo = _FakeSettlement()
        ..result =
            const GossipUploadResult(accepted: 4, duplicates: 1, invalid: 0);
      final u = GossipUploader(
        pool: pool,
        settlement: repo,
        tokenProvider: () => 'tok',
      );
      final report = await u.uploadOnce();
      expect(report.submitted, 5);
      expect(report.accepted, 4);
      expect(report.duplicates, 1);
      expect(report.errorReason, isNull);
      expect(repo.callCount, 1);
      expect(repo.lastBlobCount, 5);

      final stats = await pool.stats();
      expect(stats['carryPending'], 0);
      expect(stats['uploaded'], 5);

      final r2 = await u.uploadOnce();
      expect(r2.submitted, 0);
      expect(repo.callCount, 1);
    });

    test('repo throws → rows remain carry-pending', () async {
      for (var i = 1; i <= 3; i++) {
        await pool.ingest(_blob(i), selfUserId: 'me');
      }
      final repo = _FakeSettlement()..error = StateError('network down');
      final u = GossipUploader(
        pool: pool,
        settlement: repo,
        tokenProvider: () => 'tok',
      );
      final report = await u.uploadOnce();
      expect(report.submitted, 3);
      expect(report.accepted, 0);
      expect(report.errorReason, isNotNull);
      final stats = await pool.stats();
      expect(stats['carryPending'], 3);
      expect(stats['uploaded'], 0);
    });

    test('null token provider → no-op', () async {
      await pool.ingest(_blob(1), selfUserId: 'me');
      final repo = _FakeSettlement();
      final u = GossipUploader(
        pool: pool,
        settlement: repo,
        tokenProvider: () => null,
      );
      final report = await u.uploadOnce();
      expect(report.submitted, 0);
      expect(repo.callCount, 0);
      final stats = await pool.stats();
      expect(stats['carryPending'], 1);
    });
  });
}

GossipBlob _blob(int id) {
  return GossipBlob(
    transactionHash: Uint8List.fromList([id, ...List<int>.filled(31, 0xAA)]),
    encryptedBlob: Uint8List.fromList(List<int>.filled(200, 0xBB)),
    bankSignature: Uint8List.fromList(List<int>.filled(64, 0xCC)),
    ceilingTokenHash: Uint8List.fromList(List<int>.filled(32, 0xDD)),
    hopCount: 0,
    blobSize: 200,
  );
}

class _FakeSettlement implements SettlementRepository {
  GossipUploadResult? result;
  Object? error;
  int callCount = 0;
  int lastBlobCount = 0;

  @override
  Future<GossipUploadResult> uploadGossip({
    required List<GossipBlobWire> blobs,
    required String accessToken,
  }) async {
    callCount++;
    lastBlobCount = blobs.length;
    if (error != null) throw error!;
    return result ??
        GossipUploadResult(
          accepted: blobs.length,
          duplicates: 0,
          invalid: 0,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
