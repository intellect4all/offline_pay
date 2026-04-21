// Drains queued claims, uploads gossip, reconciles against the server,
// and rotates realm/bank/sealed-box keys. Fires on connectivity-up and
// on a 30-second tick.

import 'dart:async';
import 'dart:typed_data';

import '../repositories/keys_repository.dart';
import '../repositories/settlement_repository.dart';
import 'claim_submitter.dart';
import 'connectivity.dart';
import 'gossip_pool.dart';
import 'gossip_uploader.dart';
import 'keystore.dart';
import 'local_queue.dart';

typedef TokenProvider = String? Function();

typedef RealmKeyInstaller = void Function(
  int version,
  Uint8List key, {
  bool activate,
});

typedef DeviceSessionRetrier = Future<void> Function();

class SyncService {
  final LocalQueue queue;
  final Keystore keystore;
  final ConnectivityService connectivity;
  final SettlementRepository settlement;
  final KeysRepository keys;
  final ClaimSubmitter claimSubmitter;
  final GossipUploader? gossipUploader;
  final GossipPool? gossipPool;
  final TokenProvider tokenProvider;

  RealmKeyInstaller? realmInstaller;
  DeviceSessionRetrier? deviceSessionRetrier;

  StreamSubscription<bool>? _sub;
  Timer? _periodic;
  final _events = StreamController<SyncEvent>.broadcast();

  static const Duration periodicInterval = Duration(seconds: 30);

  SyncService({
    required this.queue,
    required this.keystore,
    required this.connectivity,
    required this.settlement,
    required this.keys,
    required this.claimSubmitter,
    required this.tokenProvider,
    this.gossipUploader,
    this.gossipPool,
  });

  Stream<SyncEvent> get events => _events.stream;

  void start({Duration? interval}) {
    _sub = connectivity.stream.listen((online) {
      if (online) unawaited(runOnce());
    });
    _periodic?.cancel();
    _periodic = Timer.periodic(interval ?? periodicInterval, (_) {
      if (connectivity.online && tokenProvider() != null) {
        unawaited(runOnce());
      }
    });
    if (connectivity.online) unawaited(runOnce());
  }

  Future<void> dispose() async {
    _periodic?.cancel();
    await _sub?.cancel();
    await _events.close();
  }

  bool _inflight = false;
  Future<void> runOnce() async {
    if (_inflight) return;
    _inflight = true;
    try {
      _events.add(const SyncEvent.started());
      if (connectivity.online && tokenProvider() != null) {
        await _drainClaims();
        await _drainGossip();
        await _refreshKeys();
        await _retryDeviceSession();
      }
      await _reconcile();
      _events.add(const SyncEvent.completed());
    } catch (e) {
      _events.add(SyncEvent.failed(e.toString()));
    } finally {
      _inflight = false;
    }
  }

  Future<void> _drainClaims() async {
    try {
      final report = await claimSubmitter.drainOnce();
      if (report.attempted > 0) {
        _events.add(SyncEvent._('drained', report.toString()));
      }
    } catch (e) {
      _events.add(SyncEvent.failed('drain: $e'));
    }
  }

  Future<void> _retryDeviceSession() async {
    final retry = deviceSessionRetrier;
    if (retry == null) return;
    try {
      await retry();
    } catch (e) {
      _events.add(SyncEvent.failed('device_session_retry: $e'));
    }
  }

  Future<void> _drainGossip() async {
    final uploader = gossipUploader;
    if (uploader == null) return;
    try {
      final report = await uploader.uploadOnce();
      if (report.submitted > 0) {
        _events.add(SyncEvent._('gossip_uploaded', report.toString()));
      }
    } catch (e) {
      _events.add(SyncEvent.failed('gossip: $e'));
    }
  }

  Future<void> _reconcile() async {
    final userId = await keystore.userId();
    if (userId == null) return;
    final token = tokenProvider();
    if (token == null) {
      _events.add(const SyncEvent.skipped('no session token'));
      return;
    }
    try {
      final res = await settlement.syncUser(
        finalize: true,
        accessToken: token,
      );
      if (res.finalizedCount > 0) {
        _events.add(SyncEvent._('finalized', '${res.finalizedCount}'));
      }
      await _diffLocalAgainstServer(res);
    } catch (e) {
      _events.add(SyncEvent.failed('sync: $e'));
    }
  }

  Future<void> _diffLocalAgainstServer(SyncResult res) async {
    final all = await queue.listAll();
    final byServerId = <String, LocalTxn>{};
    final byCeilingSeq = <String, LocalTxn>{};
    String ceilingSeqKey(String ceilingTokenId, int seq) =>
        '$ceilingTokenId#$seq';
    for (final r in all) {
      final sid = r.serverTransactionId;
      if (sid != null && sid.isNotEmpty) {
        byServerId[sid] = r;
      }
      byCeilingSeq[ceilingSeqKey(r.ceilingTokenId, r.sequenceNumber)] = r;
    }
    var serverOnly = 0;
    var stateMismatch = 0;
    var amountMismatch = 0;
    var applied = 0;
    final sample = <String>[];
    final terminalCoords = <({String payerId, int sequenceNumber})>[];

    void noteSample(String s) {
      if (sample.length < 3) sample.add(s);
    }

    Future<void> reconcile(SyncedTxn s) async {
      var l = byServerId[s.transactionId];
      l ??= byCeilingSeq[ceilingSeqKey(s.ceilingTokenId, s.sequenceNumber)];
      if (l == null) {
        serverOnly++;
        noteSample('server_only:${s.transactionId}');
        return;
      }
      final expected = _localStateForWire(s.status);
      if (expected == null) return;

      final needsServerIdBackfill = (l.serverTransactionId == null ||
              l.serverTransactionId!.isEmpty) &&
          s.transactionId.isNotEmpty;

      final shouldUpdate = l.state != expected ||
          (s.settledAmountKobo > 0 &&
              l.settledAmountKobo != s.settledAmountKobo) ||
          needsServerIdBackfill;
      if (shouldUpdate) {
        final settledAt = s.settledAt ?? DateTime.now().toUtc();
        final reason = s.rejectionReason;
        await queue.markStateUpdate(
          l.id,
          state: expected,
          settledAt: _isSettledState(expected) ? settledAt : null,
          settledAmountKobo: s.settledAmountKobo > 0 ? s.settledAmountKobo : null,
          reason: (reason != null && reason.isNotEmpty) ? reason : null,
          serverTransactionId: needsServerIdBackfill ? s.transactionId : null,
        );
        applied++;
        if (_isTerminalState(expected) && l.state != expected) {
          terminalCoords.add((
            payerId: l.payerId,
            sequenceNumber: l.sequenceNumber,
          ));
        }
        if (l.state != expected) {
          stateMismatch++;
          noteSample(
              'state:${s.transactionId} local=${l.state.name} server=${s.status}');
        }
        if (s.settledAmountKobo > 0 &&
            l.settledAmountKobo != s.settledAmountKobo) {
          amountMismatch++;
          noteSample(
              'amount:${s.transactionId} local=${l.settledAmountKobo} server=${s.settledAmountKobo}');
        }
      }
    }

    for (final t in res.payerSide) {
      await reconcile(t);
    }
    for (final t in res.receiverSide) {
      await reconcile(t);
    }

    final pool = gossipPool;
    if (pool != null && terminalCoords.isNotEmpty) {
      try {
        final pruned = await pool.pruneByPayerSeq(terminalCoords);
        if (pruned > 0) {
          _events.add(SyncEvent._('gossip_pruned', '$pruned'));
        }
      } catch (e) {
        _events.add(SyncEvent.failed('gossip_prune: $e'));
      }
    }

    if (applied + serverOnly == 0) return;
    _events.add(SyncEvent._(
      'reconcile_diff',
      'applied=$applied server_only=$serverOnly '
          'state_mismatch=$stateMismatch amount_mismatch=$amountMismatch '
          'sample=${sample.join(",")}',
    ));
  }

  bool _isTerminalState(TxnState s) =>
      s == TxnState.settled ||
      s == TxnState.partiallySettled ||
      s == TxnState.rejected ||
      s == TxnState.expired;

  bool _isSettledState(TxnState s) =>
      s == TxnState.settled || s == TxnState.partiallySettled;

  TxnState? _localStateForWire(String wire) {
    switch (wire) {
      case 'TRANSACTION_STATUS_SETTLED':
        return TxnState.settled;
      case 'TRANSACTION_STATUS_PARTIALLY_SETTLED':
        return TxnState.partiallySettled;
      case 'TRANSACTION_STATUS_REJECTED':
        return TxnState.rejected;
      case 'TRANSACTION_STATUS_EXPIRED':
        return TxnState.expired;
      case 'TRANSACTION_STATUS_PENDING':
        return TxnState.pending;
      case 'TRANSACTION_STATUS_SUBMITTED':
        return TxnState.submitted;
      default:
        return null;
    }
  }

  Future<void> _refreshKeys() async {
    final token = tokenProvider();
    if (token == null) return;
    final deviceId = await keystore.deviceId();
    if (deviceId == null) return;
    try {
      final bundle = await keys.getActiveRealmKeys(
        deviceId: deviceId,
        accessToken: token,
      );
      if (bundle.isNotEmpty) {
        final active = bundle
            .where((k) => k.retiredAt == null)
            .fold<RealmKeySnapshot?>(null, (latest, k) {
          if (latest == null || k.version > latest.version) return k;
          return latest;
        });
        final installer = realmInstaller;
        for (final k in bundle) {
          if (installer != null) {
            installer(k.version, k.key, activate: k.version == active?.version);
          }
        }
        if (active != null) {
          await keystore.setRealmKey(active.version, active.key);
        }
        _events.add(SyncEvent._('realm_keys', 'n=${bundle.length}'));
      }
    } catch (e) {
      _events.add(SyncEvent.failed('realm_keys: $e'));
    }
    try {
      final bank = await keys.getBankPublicKeys(accessToken: token);
      if (bank.isNotEmpty) {
        await keystore.saveBankKeys(bank
            .map((k) => <String, dynamic>{
                  'key_id': k.keyId,
                  'public_key': k.publicKeyB64,
                  'active_from': k.activeFrom.toIso8601String(),
                  if (k.retiredAt != null)
                    'retired_at': k.retiredAt!.toIso8601String(),
                })
            .toList(growable: false));
        _events.add(SyncEvent._('bank_keys', 'n=${bank.length}'));
      }
    } catch (e) {
      _events.add(SyncEvent.failed('bank_keys: $e'));
    }
    try {
      final sealed = await keys.getSealedBoxPubkey(token);
      await keystore.saveSealedBoxPubkey(sealed.publicKey);
    } catch (e) {
      _events.add(SyncEvent.failed('sealed_box: $e'));
    }
  }
}

class SyncEvent {
  final String kind;
  final String? detail;
  const SyncEvent._(this.kind, this.detail);
  const SyncEvent.started() : this._('started', null);
  const SyncEvent.completed() : this._('completed', null);
  const SyncEvent.skipped(String reason) : this._('skipped', reason);
  const SyncEvent.failed(String err) : this._('failed', err);

  @override
  String toString() =>
      detail == null ? 'SyncEvent($kind)' : 'SyncEvent($kind: $detail)';
}
