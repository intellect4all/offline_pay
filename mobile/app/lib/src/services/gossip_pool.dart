import 'dart:typed_data';

import 'package:offlinepay_core/offlinepay_core.dart' show GossipBlob;
import 'package:sqflite/sqflite.dart';

// Protocol caps (see CLAUDE.md, gossip section).
const int gossipMaxCarry = 500;
const int gossipMaxHops = 3;

class GossipPool {
  final Database _db;
  final int maxCarry;
  final int maxHops;
  final DateTime Function() _now;

  GossipPool({
    required Database db,
    this.maxCarry = gossipMaxCarry,
    this.maxHops = gossipMaxHops,
    DateTime Function()? clock,
  })  : _db = db,
        _now = clock ?? (() => DateTime.now().toUtc());

  Future<void> ingest(
    GossipBlob blob, {
    required String selfUserId,
    String? originUserId,
    String? payerId,
    int? sequenceNumber,
  }) async {
    final nowMs = _now().millisecondsSinceEpoch;
    await _db.insert(
      'gossip_blobs',
      {
        'transaction_hash': blob.transactionHash,
        'encrypted_blob': blob.encryptedBlob,
        'bank_signature': blob.bankSignature,
        'ceiling_token_hash': blob.ceilingTokenHash,
        'hop_count': blob.hopCount,
        'blob_size': blob.blobSize,
        'origin_user_id': originUserId,
        'first_seen_at': nowMs,
        'uploaded_at': null,
        'payer_id': payerId,
        'sequence_number': sequenceNumber,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await _evictIfNeeded(selfUserId);
  }

  Future<void> _evictIfNeeded(String selfUserId) async {
    final row = await _db.rawQuery('SELECT COUNT(*) AS c FROM gossip_blobs');
    final count = ((row.first['c'] ?? 0) as num).toInt();
    if (count <= maxCarry) return;
    final overflow = count - maxCarry;
    final victims = await _db.rawQuery(
      '''
      SELECT transaction_hash FROM gossip_blobs
      WHERE origin_user_id IS NULL OR origin_user_id != ?
      ORDER BY (uploaded_at IS NOT NULL) DESC, first_seen_at ASC
      LIMIT ?
      ''',
      [selfUserId, overflow],
    );
    for (final v in victims) {
      await _db.delete(
        'gossip_blobs',
        where: 'transaction_hash = ?',
        whereArgs: [v['transaction_hash']],
      );
    }
  }

  Future<int> pruneByPayerSeq(
    List<({String payerId, int sequenceNumber})> coords,
  ) async {
    if (coords.isEmpty) return 0;
    var deleted = 0;
    final batch = _db.batch();
    for (final c in coords) {
      batch.delete(
        'gossip_blobs',
        where: 'payer_id = ? AND sequence_number = ?',
        whereArgs: [c.payerId, c.sequenceNumber],
      );
    }
    final results = await batch.commit();
    for (final r in results) {
      if (r is int) deleted += r;
    }
    return deleted;
  }

  Future<List<GossipBlob>> draw({
    required int n,
    required String selfUserId,
  }) async {
    if (n <= 0) return const [];
    final rows = await _db.rawQuery(
      '''
      SELECT g.* FROM gossip_blobs g
      WHERE g.hop_count < ?
        AND g.uploaded_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM transactions t
          WHERE g.payer_id IS NOT NULL
            AND g.sequence_number IS NOT NULL
            AND t.payer_id = g.payer_id
            AND t.sequence_number = g.sequence_number
            AND t.state IN ('settled','partiallySettled','rejected','expired')
        )
      ORDER BY (g.origin_user_id = ?) DESC, g.first_seen_at ASC
      LIMIT ?
      ''',
      [maxHops, selfUserId, n],
    );
    final out = <GossipBlob>[];
    for (final r in rows) {
      final newHop = ((r['hop_count'] ?? 0) as num).toInt() + 1;
      final hash = r['transaction_hash'] as Uint8List;
      await _db.update(
        'gossip_blobs',
        {'hop_count': newHop},
        where: 'transaction_hash = ?',
        whereArgs: [hash],
      );
      out.add(_rowToBlob(r, hopOverride: newHop));
    }
    await _db.delete(
      'gossip_blobs',
      where: 'hop_count >= ? AND uploaded_at IS NOT NULL',
      whereArgs: [maxHops],
    );
    return out;
  }

  Future<List<GossipBlob>> pendingForUpload({int limit = 200}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT * FROM gossip_blobs
      WHERE uploaded_at IS NULL
      ORDER BY first_seen_at ASC
      LIMIT ?
      ''',
      [limit],
    );
    return rows.map((r) => _rowToBlob(r)).toList(growable: false);
  }

  Future<void> markUploaded(List<Uint8List> transactionHashes) async {
    if (transactionHashes.isEmpty) return;
    final uploadedAt = _now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final h in transactionHashes) {
      batch.update(
        'gossip_blobs',
        {'uploaded_at': uploadedAt},
        where: 'transaction_hash = ?',
        whereArgs: [h],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, int>> stats() async {
    final total = await _scalarInt('SELECT COUNT(*) FROM gossip_blobs');
    final pending = await _scalarInt(
        'SELECT COUNT(*) FROM gossip_blobs WHERE uploaded_at IS NULL');
    final uploaded = await _scalarInt(
        'SELECT COUNT(*) FROM gossip_blobs WHERE uploaded_at IS NOT NULL');
    final maxHop = await _scalarInt(
        'SELECT COALESCE(MAX(hop_count), 0) FROM gossip_blobs');
    return {
      'total': total,
      'carryPending': pending,
      'uploaded': uploaded,
      'maxHop': maxHop,
      'maxCarry': maxCarry,
    };
  }

  Future<int> _scalarInt(String sql) async {
    final rows = await _db.rawQuery(sql);
    if (rows.isEmpty) return 0;
    final v = rows.first.values.first;
    return ((v ?? 0) as num).toInt();
  }

  GossipBlob _rowToBlob(Map<String, Object?> r, {int? hopOverride}) {
    return GossipBlob(
      transactionHash: _asBytes(r['transaction_hash']),
      encryptedBlob: _asBytes(r['encrypted_blob']),
      bankSignature: _asBytes(r['bank_signature']),
      ceilingTokenHash: _asBytes(r['ceiling_token_hash']),
      hopCount: hopOverride ?? ((r['hop_count'] ?? 0) as num).toInt(),
      blobSize: ((r['blob_size'] ?? 0) as num).toInt(),
    );
  }

  static Uint8List _asBytes(Object? v) {
    if (v is Uint8List) return v;
    if (v is List<int>) return Uint8List.fromList(v);
    return Uint8List(0);
  }
}
