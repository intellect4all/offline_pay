import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

enum TxnDirection { sent, received }

enum CeilingStatus {
  active,
  superseded,
  revoked,
  expired,
  exhausted,
  recoveryPending,
}

String ceilingStatusLabel(CeilingStatus s) {
  switch (s) {
    case CeilingStatus.active:
      return 'ACTIVE';
    case CeilingStatus.superseded:
      return 'SUPERSEDED';
    case CeilingStatus.revoked:
      return 'REVOKED';
    case CeilingStatus.expired:
      return 'EXPIRED';
    case CeilingStatus.exhausted:
      return 'EXHAUSTED';
    case CeilingStatus.recoveryPending:
      return 'RECOVERY_PENDING';
  }
}

class CeilingRecord {
  final String id;
  final int ceilingKobo;
  final int sequenceStart;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String bankKeyId;
  final Uint8List payerPublicKey;
  final Uint8List bankSignature;
  final String ceilingTokenBlob;
  final CeilingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? releaseAfter;

  const CeilingRecord({
    required this.id,
    required this.ceilingKobo,
    required this.sequenceStart,
    required this.issuedAt,
    required this.expiresAt,
    required this.bankKeyId,
    required this.payerPublicKey,
    required this.bankSignature,
    required this.ceilingTokenBlob,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.releaseAfter,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'ceiling_kobo': ceilingKobo,
        'sequence_start': sequenceStart,
        'issued_at': issuedAt.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'bank_key_id': bankKeyId,
        'payer_public_key': payerPublicKey,
        'bank_signature': bankSignature,
        'ceiling_token_blob': ceilingTokenBlob,
        'status': status.name,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'release_after': releaseAfter?.toUtc().toIso8601String(),
      };

  static CeilingRecord fromRow(Map<String, Object?> r) => CeilingRecord(
        id: r['id']! as String,
        ceilingKobo: (r['ceiling_kobo']! as num).toInt(),
        sequenceStart: (r['sequence_start']! as num).toInt(),
        issuedAt: DateTime.parse(r['issued_at']! as String).toUtc(),
        expiresAt: DateTime.parse(r['expires_at']! as String).toUtc(),
        bankKeyId: r['bank_key_id']! as String,
        payerPublicKey:
            Uint8List.fromList(r['payer_public_key']! as List<int>),
        bankSignature:
            Uint8List.fromList(r['bank_signature']! as List<int>),
        ceilingTokenBlob: r['ceiling_token_blob']! as String,
        status: CeilingStatus.values.byName(r['status']! as String),
        createdAt: DateTime.parse(r['created_at']! as String).toUtc(),
        updatedAt: DateTime.parse(r['updated_at']! as String).toUtc(),
        releaseAfter: r['release_after'] == null
            ? null
            : DateTime.parse(r['release_after']! as String).toUtc(),
      );
}

enum TxnState {
  queued,
  submitted,
  pending,
  settled,
  partiallySettled,
  rejected,
  expired,
}

String txnStateLabel(TxnState s) {
  switch (s) {
    case TxnState.queued:
      return 'QUEUED';
    case TxnState.submitted:
      return 'SUBMITTED';
    case TxnState.pending:
      return 'PENDING';
    case TxnState.settled:
      return 'SETTLED';
    case TxnState.partiallySettled:
      return 'PARTIALLY_SETTLED';
    case TxnState.rejected:
      return 'REJECTED';
    case TxnState.expired:
      return 'EXPIRED';
  }
}

class LocalTxn {
  final String id;
  final TxnDirection direction;
  final String payerId;
  final String payeeId;

  final String? counterDisplayName;

  final int amountKobo;
  final int? settledAmountKobo;
  final int sequenceNumber;
  final String ceilingTokenId;
  final TxnState state;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final DateTime? settledAt;
  final String? rejectionReason;

  final String paymentTokenBlob;
  final String ceilingTokenBlob;
  final String requestBlob;
  final String? serverTransactionId;

  const LocalTxn({
    required this.id,
    required this.direction,
    required this.payerId,
    required this.payeeId,
    required this.amountKobo,
    this.settledAmountKobo,
    required this.sequenceNumber,
    required this.ceilingTokenId,
    required this.state,
    required this.createdAt,
    required this.submittedAt,
    required this.settledAt,
    required this.rejectionReason,
    required this.paymentTokenBlob,
    required this.ceilingTokenBlob,
    this.requestBlob = '',
    this.serverTransactionId,
    this.counterDisplayName,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'direction': direction.name,
        'payer_id': payerId,
        'payee_id': payeeId,
        'amount_kobo': amountKobo,
        'settled_amount_kobo': settledAmountKobo,
        'sequence_number': sequenceNumber,
        'ceiling_token_id': ceilingTokenId,
        'state': state.name,
        'created_at': createdAt.toUtc().toIso8601String(),
        'submitted_at': submittedAt?.toUtc().toIso8601String(),
        'settled_at': settledAt?.toUtc().toIso8601String(),
        'rejection_reason': rejectionReason,
        'payment_token_blob': paymentTokenBlob,
        'ceiling_token_blob': ceilingTokenBlob,
        'request_blob': requestBlob,
        'server_txn_id': serverTransactionId,
        'counter_display_name': counterDisplayName,
      };

  static LocalTxn fromRow(Map<String, Object?> r) {
    return LocalTxn(
      id: r['id']! as String,
      direction: TxnDirection.values.byName(r['direction']! as String),
      payerId: r['payer_id']! as String,
      payeeId: r['payee_id']! as String,
      amountKobo: (r['amount_kobo']! as num).toInt(),
      settledAmountKobo: r['settled_amount_kobo'] == null
          ? null
          : (r['settled_amount_kobo']! as num).toInt(),
      sequenceNumber: (r['sequence_number']! as num).toInt(),
      ceilingTokenId: r['ceiling_token_id']! as String,
      state: TxnState.values.byName(r['state']! as String),
      createdAt: DateTime.parse(r['created_at']! as String).toUtc(),
      submittedAt: r['submitted_at'] == null
          ? null
          : DateTime.parse(r['submitted_at']! as String).toUtc(),
      settledAt: r['settled_at'] == null
          ? null
          : DateTime.parse(r['settled_at']! as String).toUtc(),
      rejectionReason: r['rejection_reason'] as String?,
      paymentTokenBlob: r['payment_token_blob']! as String,
      ceilingTokenBlob: r['ceiling_token_blob']! as String,
      requestBlob: (r['request_blob'] as String?) ?? '',
      serverTransactionId: r['server_txn_id'] as String?,
      counterDisplayName: r['counter_display_name'] as String?,
    );
  }
}

class LocalQueue {
  final Database _db;
  LocalQueue._(this._db);

  Database get db => _db;

  static Future<LocalQueue> open({String? overridePath}) async {
    final dir = overridePath ??
        p.join(
            (await getApplicationDocumentsDirectory()).path, 'offlinepay.db');
    final db = await openDatabase(
      dir,
      version: 11,
      onConfigure: (db) async {
        // rawQuery, not execute: journal_mode returns a row on Android.
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.rawQuery('PRAGMA foreign_keys=ON');
      },
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            direction TEXT NOT NULL,
            payer_id TEXT NOT NULL,
            payee_id TEXT NOT NULL,
            amount_kobo INTEGER NOT NULL,
            settled_amount_kobo INTEGER,
            sequence_number INTEGER NOT NULL,
            ceiling_token_id TEXT NOT NULL,
            state TEXT NOT NULL,
            created_at TEXT NOT NULL,
            submitted_at TEXT,
            settled_at TEXT,
            rejection_reason TEXT,
            payment_token_blob TEXT NOT NULL,
            ceiling_token_blob TEXT NOT NULL,
            request_blob TEXT NOT NULL DEFAULT '',
            server_txn_id TEXT,
            counter_display_name TEXT
          );
        ''');
        await db.execute('CREATE INDEX tx_state ON transactions(state);');
        await db.execute(
            'CREATE INDEX tx_direction_created ON transactions(direction, created_at DESC);');
        // Seq is monotonic per ceiling; re-funding resets it, so the
        // uniqueness scope must include ceiling_token_id.
        await db.execute(
            'CREATE UNIQUE INDEX tx_payer_ceiling_seq '
            'ON transactions(payer_id, ceiling_token_id, sequence_number);');
        await db.execute(
            'CREATE INDEX tx_server_txn_id ON transactions(server_txn_id);');
        await _createSubmissionAttempts(db);
        await _createGossipBlobs(db);
        await _createCeilings(db);
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await _createSubmissionAttempts(db);
        }
        if (oldV < 3) {
          await _createGossipBlobs(db);
        }
        if (oldV < 4) {
          await db.execute(
              'ALTER TABLE transactions ADD COLUMN settled_amount_kobo INTEGER;');
        }
        if (oldV < 5) {
          await _createCeilings(db);
        }
        if (oldV < 6) {
          await db.execute(
              "ALTER TABLE transactions ADD COLUMN request_blob TEXT NOT NULL DEFAULT '';");
        }
        if (oldV < 7) {
          await db.execute(
              'ALTER TABLE transactions ADD COLUMN server_txn_id TEXT;');
          await db.execute(
              'CREATE INDEX tx_server_txn_id ON transactions(server_txn_id);');
        }
        if (oldV < 8) {
          await db.execute(
              'ALTER TABLE ceilings ADD COLUMN release_after TEXT;');
        }
        if (oldV < 9) {
          await db.execute('DROP INDEX IF EXISTS tx_payer_seq;');
          await db.execute(
              'CREATE UNIQUE INDEX tx_payer_ceiling_seq '
              'ON transactions(payer_id, ceiling_token_id, sequence_number);');
        }
        if (oldV < 10) {
          await db.execute(
              'ALTER TABLE transactions ADD COLUMN counter_display_name TEXT;');
        }
        if (oldV < 11) {
          await db.execute(
              'ALTER TABLE gossip_blobs ADD COLUMN payer_id TEXT;');
          await db.execute(
              'ALTER TABLE gossip_blobs ADD COLUMN sequence_number INTEGER;');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS gb_payer_seq '
              'ON gossip_blobs(payer_id, sequence_number);');
        }
      },
    );
    return LocalQueue._(db);
  }

  static Future<void> _createCeilings(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ceilings (
        id TEXT PRIMARY KEY,
        ceiling_kobo INTEGER NOT NULL,
        sequence_start INTEGER NOT NULL,
        issued_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        bank_key_id TEXT NOT NULL,
        payer_public_key BLOB NOT NULL,
        bank_signature BLOB NOT NULL,
        ceiling_token_blob TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        release_after TEXT
      );
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS ceilings_status_issued '
        'ON ceilings(status, issued_at DESC);');
  }

  static Future<void> _createSubmissionAttempts(Database db) async {
    await db.execute('''
      CREATE TABLE submission_attempts (
        txn_id TEXT PRIMARY KEY
          REFERENCES transactions(id) ON DELETE CASCADE,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        first_attempt_at TEXT NOT NULL,
        last_attempt_at TEXT NOT NULL,
        last_error TEXT
      );
    ''');
    await db.execute(
        'CREATE INDEX sa_status_last ON submission_attempts(status, last_attempt_at);');
  }

  static Future<void> _createGossipBlobs(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gossip_blobs (
        transaction_hash BLOB PRIMARY KEY,
        encrypted_blob BLOB NOT NULL,
        bank_signature BLOB NOT NULL,
        ceiling_token_hash BLOB NOT NULL,
        hop_count INTEGER NOT NULL,
        blob_size INTEGER NOT NULL,
        origin_user_id TEXT,
        first_seen_at INTEGER NOT NULL,
        uploaded_at INTEGER,
        payer_id TEXT,
        sequence_number INTEGER
      );
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS gb_pending ON gossip_blobs(uploaded_at, first_seen_at);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS gb_hop ON gossip_blobs(hop_count);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS gb_payer_seq ON gossip_blobs(payer_id, sequence_number);');
  }

  Future<void> close() => _db.close();

  Future<void> enqueueSent(LocalTxn t) async {
    assert(t.direction == TxnDirection.sent);
    await _db.insert('transactions', t.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> enqueueReceived(LocalTxn t) async {
    assert(t.direction == TxnDirection.received);
    await _db.insert('transactions', t.toRow(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<LocalTxn>> listPending({TxnDirection? direction}) async {
    final where = StringBuffer('state = ?');
    final args = <Object?>[TxnState.queued.name];
    if (direction != null) {
      where.write(' AND direction = ?');
      args.add(direction.name);
    }
    final rows = await _db.query('transactions',
        where: where.toString(), whereArgs: args, orderBy: 'created_at ASC');
    return rows.map(LocalTxn.fromRow).toList();
  }

  Future<void> markSubmitted(String id, DateTime at) async {
    await _db.update(
      'transactions',
      {
        'state': TxnState.submitted.name,
        'submitted_at': at.toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markStateUpdate(
    String id, {
    required TxnState state,
    DateTime? settledAt,
    int? settledAmountKobo,
    String? reason,
    String? serverTransactionId,
  }) async {
    final patch = <String, Object?>{'state': state.name};
    if (settledAt != null) {
      patch['settled_at'] = settledAt.toUtc().toIso8601String();
    }
    if (settledAmountKobo != null) {
      patch['settled_amount_kobo'] = settledAmountKobo;
    }
    if (reason != null) patch['rejection_reason'] = reason;
    if (serverTransactionId != null && serverTransactionId.isNotEmpty) {
      patch['server_txn_id'] = serverTransactionId;
    }
    await _db.update('transactions', patch, where: 'id = ?', whereArgs: [id]);
  }

  Future<LocalTxn?> findByServerTransactionId(String serverTxnId) async {
    final rows = await _db.query(
      'transactions',
      where: 'server_txn_id = ?',
      whereArgs: [serverTxnId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LocalTxn.fromRow(rows.first);
  }

  Future<List<LocalTxn>> listAll({int limit = 500}) async {
    final rows = await _db.query('transactions',
        orderBy: 'created_at DESC', limit: limit);
    return rows.map(LocalTxn.fromRow).toList();
  }

  Future<int> nextSequenceNumber(
      String ceilingTokenId, int sequenceStart) async {
    // Counts every row, including terminal ones — reusing a retired seq
    // would collide with a belated claim the server could accept.
    final rows = await _db.rawQuery(
      'SELECT MAX(sequence_number) AS m FROM transactions WHERE ceiling_token_id = ? AND direction = ?',
      [ceilingTokenId, TxnDirection.sent.name],
    );
    final m = rows.isEmpty ? null : rows.first['m'];
    if (m == null) return sequenceStart + 1;
    return (m as int) + 1;
  }

  Future<int> sumSent(String ceilingTokenId) async {
    final rows = await _db.rawQuery(
      "SELECT COALESCE(SUM(amount_kobo),0) AS s "
      "FROM transactions "
      "WHERE ceiling_token_id = ? AND direction = ? "
      "AND state NOT IN ('expired','rejected')",
      [ceilingTokenId, TxnDirection.sent.name],
    );
    return ((rows.first['s'] ?? 0) as num).toInt();
  }

  Future<int?> lastSequenceFromPayer(
    String payerId,
    String ceilingTokenId,
  ) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(sequence_number) AS m FROM transactions '
      'WHERE payer_id = ? AND ceiling_token_id = ?',
      [payerId, ceilingTokenId],
    );
    if (rows.isEmpty) return null;
    final m = rows.first['m'];
    if (m == null) return null;
    return (m as num).toInt();
  }

  Future<int> countByState(TxnState state) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE state = ?',
      [state.name],
    );
    return ((rows.first['c'] ?? 0) as num).toInt();
  }

  Future<void> recordCeiling(CeilingRecord record) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction((txn) async {
      await txn.update(
        'ceilings',
        {'status': CeilingStatus.superseded.name, 'updated_at': now},
        where: 'status = ?',
        whereArgs: [CeilingStatus.active.name],
      );
      await txn.insert(
        'ceilings',
        record.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<CeilingRecord?> currentActiveCeiling() async {
    final rows = await _db.query(
      'ceilings',
      where: 'status = ?',
      whereArgs: [CeilingStatus.active.name],
      orderBy: 'issued_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CeilingRecord.fromRow(rows.first);
  }

  Future<List<CeilingRecord>> listCeilings({int limit = 200}) async {
    final rows = await _db.query(
      'ceilings',
      orderBy: 'issued_at DESC',
      limit: limit,
    );
    return rows.map(CeilingRecord.fromRow).toList(growable: false);
  }

  Future<void> markCeilingStatus(String id, CeilingStatus status) async {
    await _db.update(
      'ceilings',
      {
        'status': status.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<CeilingRecord?> currentOrRecoveringCeiling() async {
    final rows = await _db.query(
      'ceilings',
      where: 'status IN (?, ?)',
      whereArgs: [
        CeilingStatus.active.name,
        CeilingStatus.recoveryPending.name,
      ],
      orderBy: 'issued_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CeilingRecord.fromRow(rows.first);
  }

  Future<int> applyRecoveryInitiated({
    required String ceilingId,
    required DateTime releaseAfter,
    String ghostReason = 'ceiling recovery initiated; payment token unclaimable',
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return _db.transaction<int>((txn) async {
      await txn.update(
        'ceilings',
        {
          'status': CeilingStatus.recoveryPending.name,
          'release_after': releaseAfter.toUtc().toIso8601String(),
          'updated_at': nowIso,
        },
        where: 'id = ?',
        whereArgs: [ceilingId],
      );
      return txn.update(
        'transactions',
        {
          'state': TxnState.expired.name,
          'rejection_reason': ghostReason,
        },
        where: 'ceiling_token_id = ? AND direction = ? AND state = ?',
        whereArgs: [
          ceilingId,
          TxnDirection.sent.name,
          TxnState.queued.name,
        ],
      );
    });
  }

  Future<void> recordAttempt(
    String txnId, {
    required SubmissionStatus status,
    String? error,
    DateTime? at,
  }) async {
    final now = (at ?? DateTime.now().toUtc()).toIso8601String();
    await _db.rawInsert('''
      INSERT INTO submission_attempts (
        txn_id, status, attempts, first_attempt_at, last_attempt_at, last_error
      ) VALUES (?, ?, 1, ?, ?, ?)
      ON CONFLICT(txn_id) DO UPDATE SET
        status = excluded.status,
        attempts = submission_attempts.attempts + 1,
        last_attempt_at = excluded.last_attempt_at,
        last_error = excluded.last_error
    ''', [txnId, status.name, now, now, error]);
  }

  Future<SubmissionAttempt?> getAttempt(String txnId) async {
    final rows = await _db.query('submission_attempts',
        where: 'txn_id = ?', whereArgs: [txnId], limit: 1);
    if (rows.isEmpty) return null;
    return SubmissionAttempt._fromRow(rows.first);
  }

  Future<int> purgeStaleSubmitting(
      {Duration staleAfter = const Duration(minutes: 30)}) async {
    final cutoff =
        DateTime.now().toUtc().subtract(staleAfter).toIso8601String();
    return _db.delete(
      'submission_attempts',
      where: 'status = ? AND last_attempt_at < ?',
      whereArgs: [SubmissionStatus.submitting.name, cutoff],
    );
  }

  static String encodeJsonBlob(Map<String, Object?> m) =>
      base64.encode(utf8.encode(jsonEncode(m)));

  static Map<String, Object?> decodeJsonBlob(String b) =>
      jsonDecode(utf8.decode(base64.decode(b))) as Map<String, Object?>;
}

enum SubmissionStatus { submitting, submitted, failed }

class SubmissionAttempt {
  final String txnId;
  final SubmissionStatus status;
  final int attempts;
  final DateTime firstAttemptAt;
  final DateTime lastAttemptAt;
  final String? lastError;

  const SubmissionAttempt({
    required this.txnId,
    required this.status,
    required this.attempts,
    required this.firstAttemptAt,
    required this.lastAttemptAt,
    required this.lastError,
  });

  static SubmissionAttempt _fromRow(Map<String, Object?> r) {
    return SubmissionAttempt(
      txnId: r['txn_id']! as String,
      status: SubmissionStatus.values.byName(r['status']! as String),
      attempts: (r['attempts']! as num).toInt(),
      firstAttemptAt: DateTime.parse(r['first_attempt_at']! as String).toUtc(),
      lastAttemptAt: DateTime.parse(r['last_attempt_at']! as String).toUtc(),
      lastError: r['last_error'] as String?,
    );
  }
}
