import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offlinepay_core/offlinepay_core.dart'
    show DisplayCard, PaymentChannel, RealmKeyring;

import '../../../repositories/auth_repository.dart';
import '../../../repositories/transfer_repository.dart';
import '../../../repositories/wallet_repository.dart';
import '../../../services/connectivity.dart';
import '../../../services/keystore.dart';
import '../../../services/local_queue.dart';
import '../../../services/sync.dart';
import 'app_state.dart';

typedef _TokenProvider = String? Function();

class AppCubit extends Cubit<AppUiState> {
  final LocalQueue queue;
  final Keystore keystore;
  final ConnectivityService connectivity;
  final SyncService sync;
  final WalletRepository walletRepo;
  final TransferRepository transferRepo;
  final AuthRepository authRepo;
  final _TokenProvider _tokenProvider;

  List<TransferResult> _remoteTransfers = const [];

  final RealmKeyring _realmKeyring = kDebugMode
      ? RealmKeyring.seed(
          1,
          Uint8List.fromList(List<int>.generate(32, (i) => i ^ 0x5a)),
        )
      : RealmKeyring();

  StreamSubscription<bool>? _connSub;
  StreamSubscription<void>? _syncSub;

  AppCubit({
    required this.queue,
    required this.keystore,
    required this.connectivity,
    required this.sync,
    required this.walletRepo,
    required this.transferRepo,
    required this.authRepo,
    required String? Function() tokenProvider,
  })  : _tokenProvider = tokenProvider,
        super(const AppUiState());

  RealmKeyring get realmKeyring => _realmKeyring;
  int get activeRealmKeyVersion => _realmKeyring.activeVersion;
  Uint8List get activeRealmKey => _realmKeyring.activeKey;
  Uint8List? realmKeyForVersion(int v) => _realmKeyring.keyFor(v);

  void setTab(int index) {
    if (index == state.currentTab) return;
    emit(state.copyWith(currentTab: index));
  }

  void setPreferredChannel(PaymentChannel c) {
    if (c == state.preferredChannel) return;
    emit(state.copyWith(preferredChannel: c));
  }

  void setUserId(String id) {
    emit(state.copyWith(userId: id));
  }

  void setDisplayCard(DisplayCard? card) {
    if (card == null) {
      emit(state.copyWith(clearDisplayCard: true));
      unawaited(keystore.clearDisplayCard());
      return;
    }
    emit(state.copyWith(displayCard: card));
    unawaited(keystore.saveDisplayCard(card));
  }

  void setActiveRequest(ActiveRequest req) {
    emit(state.copyWith(activeRequest: req));
  }

  void clearActiveRequest() {
    emit(state.copyWith(clearActiveRequest: true));
  }


  Future<void> refreshDisplayCard() async {
    final token = _tokenProvider();
    if (token == null) return;
    try {
      final card = await authRepo.displayCard(token);
      setDisplayCard(card);
    } catch (_) {}
  }

  ActiveRequest? matchActiveRequest(List<int> sessionNonce) {
    final active = state.activeRequest;
    if (active == null) return null;
    if (active.expiresAt.isBefore(DateTime.now().toUtc())) return null;
    final n = active.sessionNonce;
    if (n.length != sessionNonce.length) return null;
    for (var i = 0; i < n.length; i++) {
      if (n[i] != sessionNonce[i]) return null;
    }
    return active;
  }

  void clearActiveCeiling() {
    final current = state.activeCeiling;
    emit(state.copyWith(clearActiveCeiling: true, sentSum: 0));
    if (current != null) {
      unawaited(
        queue.markCeilingStatus(current.id, CeilingStatus.revoked),
      );
    }
  }

  Future<void> reconcileCeilingStatus() async {
    final rec = state.recoveringCeiling;
    if (rec == null) return;
    final token = _tokenProvider();
    if (token == null || !state.online) return;
    CurrentCeilingSnapshot snap;
    try {
      snap = await walletRepo.getCurrentCeiling(token);
    } catch (_) {
      return;
    }
    if (!snap.present) {
      await queue.markCeilingStatus(rec.id, CeilingStatus.revoked);
      emit(state.copyWith(clearRecoveringCeiling: true));
      unawaited(refreshRemote());
      return;
    }
    if (snap.ceilingId == rec.id && snap.isRecoveryPending) {
      final serverReleaseAfter = snap.releaseAfter ?? rec.releaseAfter;
      if (serverReleaseAfter != rec.releaseAfter) {
        emit(state.copyWith(
          recoveringCeiling: RecoveringCeiling(
            id: rec.id,
            quarantinedKobo: snap.remainingKobo ?? rec.quarantinedKobo,
            releaseAfter: serverReleaseAfter.toUtc(),
          ),
        ));
      }
      return;
    }
    if (snap.ceilingId != null && snap.ceilingId != rec.id) {
      await queue.markCeilingStatus(rec.id, CeilingStatus.revoked);
      emit(state.copyWith(clearRecoveringCeiling: true));
      unawaited(refreshRemote());
      return;
    }
    await queue.markCeilingStatus(rec.id, CeilingStatus.revoked);
    emit(state.copyWith(clearRecoveringCeiling: true));
    unawaited(refreshRemote());
  }

  Future<void> beginCeilingRecovery({
    required String ceilingId,
    required int quarantinedKobo,
    required DateTime releaseAfter,
  }) async {
    await queue.applyRecoveryInitiated(
      ceilingId: ceilingId,
      releaseAfter: releaseAfter,
    );
    emit(state.copyWith(
      clearActiveCeiling: true,
      sentSum: 0,
      recoveringCeiling: RecoveringCeiling(
        id: ceilingId,
        quarantinedKobo: quarantinedKobo,
        releaseAfter: releaseAfter.toUtc(),
      ),
    ));
  }

  void installRealmKey(int version, Uint8List key, {bool activate = false}) {
    _realmKeyring.add(version, key, activate: activate);
    emit(state.copyWith(realmKeyVersion: _realmKeyring.activeVersion));
  }

  Future<void> bootstrap() async {
    final uid = await keystore.userId();
    final record = await queue.currentOrRecoveringCeiling();
    ActiveCeiling? ceiling;
    RecoveringCeiling? recovering;
    if (record != null) {
      if (record.status == CeilingStatus.recoveryPending) {
        final ra = record.releaseAfter;
        if (ra != null) {
          recovering = RecoveringCeiling(
            id: record.id,
            quarantinedKobo: record.ceilingKobo,
            releaseAfter: ra.toUtc(),
          );
        }
      } else {
        ceiling = _ceilingFromRecord(record);
      }
    }

    final cachedCard = await keystore.readDisplayCard();
    emit(state.copyWith(
      userId: uid,
      online: connectivity.online,
      activeCeiling: ceiling,
      recoveringCeiling: recovering,
      displayCard: cachedCard,
    ));
    _connSub = connectivity.stream.listen((v) {
      final wasOnline = state.online;
      emit(state.copyWith(online: v));
      if (v && !wasOnline) {
        unawaited(refreshRemoteAndActivity());
      }
    });
    _syncSub = sync.events.listen((event) {
      refreshLocal();
      unawaited(reconcileCeilingStatus());
      if (_isTransactionImpactingEvent(event)) {
        unawaited(refreshRemoteAndActivity());
      }
    });
    unawaited(refreshDisplayCard());
    await refreshLocal();
    if (recovering != null) {
      unawaited(reconcileCeilingStatus());
    }
  }


  ActiveCeiling _ceilingFromRecord(CeilingRecord r) => ActiveCeiling(
        id: r.id,
        ceilingKobo: r.ceilingKobo,
        sequenceStart: r.sequenceStart,
        issuedAt: r.issuedAt,
        expiresAt: r.expiresAt,
        bankKeyId: r.bankKeyId,
        payerPublicKey: r.payerPublicKey,
        bankSignature: r.bankSignature,
        ceilingTokenBlob: r.ceilingTokenBlob,
      );

  Future<void> refreshLocal() async {
    final localRows = await queue.listAll();
    final c = state.activeCeiling;
    final sentSum = c == null ? 0 : await queue.sumSent(c.id);
    emit(state.copyWith(
      activity: _mergeActivity(localRows, _remoteTransfers),
      sentSum: sentSum,
    ));
  }

  Future<void> refreshTransfers() async {
    final token = _tokenProvider();
    if (!state.online || token == null) return;
    try {
      _remoteTransfers = await transferRepo.list(accessToken: token, limit: 100);
    } catch (_) {}
  }

  LocalTxn _transferToLocalTxn(TransferResult t, String? selfId) {
    final isSent = selfId != null && t.senderUserId == selfId;
    final st = switch (t.status) {
      TransferStatus.accepted => TxnState.submitted,
      TransferStatus.processing => TxnState.submitted,
      TransferStatus.settled => TxnState.settled,
      TransferStatus.failed => TxnState.rejected,
    };
    return LocalTxn(
      id: t.id,
      direction: isSent ? TxnDirection.sent : TxnDirection.received,
      payerId: t.senderUserId,
      payeeId: t.receiverUserId,
      amountKobo: t.amountKobo,
      settledAmountKobo: t.status == TransferStatus.settled ? t.amountKobo : null,
      sequenceNumber: 0,
      ceilingTokenId: '',
      state: st,
      createdAt: t.createdAt,
      submittedAt: t.createdAt,
      settledAt: t.settledAt,
      rejectionReason: t.failureReason,
      paymentTokenBlob: '',
      ceilingTokenBlob: '',
      counterDisplayName:
          isSent ? t.receiverDisplayName : t.senderDisplayName,
    );
  }

  List<LocalTxn> _mergeActivity(
    List<LocalTxn> local,
    List<TransferResult> remote,
  ) {
    if (remote.isEmpty) return local;
    final selfId = state.userId;
    final synthetic =
        remote.map((t) => _transferToLocalTxn(t, selfId)).toList();
    final seen = <String>{};
    final merged = <LocalTxn>[];
    for (final r in [...local, ...synthetic]) {
      if (seen.add(r.id)) merged.add(r);
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<void> refreshRemote() async {
    final token = _tokenProvider();
    if (!state.online || token == null) return;
    final balances = await walletRepo.getBalances(token);
    int main = 0, offline = 0, lien = 0, pending = 0;
    for (final b in balances) {
      switch (accountKindFromWire(b.kind)) {
        case 'main':
          main = b.balanceKobo;
          break;
        case 'offline':
          offline = b.balanceKobo;
          break;
        case 'lien':
          lien = b.balanceKobo;
          break;
        case 'receiving_pending':
          pending = b.balanceKobo;
          break;
      }
    }
    emit(state.copyWith(
      mainBalanceKobo: main,
      offlineBalanceKobo: offline,
      lienBalanceKobo: lien,
      receivingPendingKobo: pending,
      hasRemoteBalances: true,
    ));
  }

  Future<void> refreshRemoteAndActivity() async {
    if (state.refreshing) return;
    emit(state.copyWith(refreshing: true));
    try {
      try {
        await refreshRemote();
      } catch (_) {}
      await refreshTransfers();
      await refreshLocal();
    } finally {
      emit(state.copyWith(refreshing: false));
    }
  }

  bool _isTransactionImpactingEvent(SyncEvent e) {
    switch (e.kind) {
      case 'drained':
      case 'finalized':
      case 'reconcile_diff':
      case 'gossip_uploaded':
        return true;
      default:
        return false;
    }
  }

  Future<void> refreshAll() async {
    if (state.refreshing) return;
    emit(state.copyWith(refreshing: true));
    try {
      unawaited(sync.runOnce());
      try {
        await refreshRemote();
      } catch (_) {}
      await refreshTransfers();
      await refreshLocal();
    } finally {
      emit(state.copyWith(refreshing: false));
    }
  }

  void applyFundOffline({
    required ActiveCeiling ceiling,
    required int newMainBalanceKobo,
    required int newOfflineBalanceKobo,
    required int newLienBalanceKobo,
  }) {
    emit(state.copyWith(
      activeCeiling: ceiling,
      mainBalanceKobo: newMainBalanceKobo,
      offlineBalanceKobo: newOfflineBalanceKobo,
      lienBalanceKobo: newLienBalanceKobo,
      hasRemoteBalances: true,
    ));
    final now = DateTime.now().toUtc();
    unawaited(queue.recordCeiling(CeilingRecord(
      id: ceiling.id,
      ceilingKobo: ceiling.ceilingKobo,
      sequenceStart: ceiling.sequenceStart,
      issuedAt: ceiling.issuedAt,
      expiresAt: ceiling.expiresAt,
      bankKeyId: ceiling.bankKeyId,
      payerPublicKey: ceiling.payerPublicKey,
      bankSignature: ceiling.bankSignature,
      ceilingTokenBlob: ceiling.ceilingTokenBlob,
      status: CeilingStatus.active,
      createdAt: now,
      updatedAt: now,
    )));
  }

  void applyRemoteBalances({
    required int main,
    required int offline,
    required int lien,
    required int receivingPending,
  }) {
    emit(state.copyWith(
      mainBalanceKobo: main,
      offlineBalanceKobo: offline,
      lienBalanceKobo: lien,
      receivingPendingKobo: receivingPending,
      hasRemoteBalances: true,
    ));
  }

  @override
  Future<void> close() {
    unawaited(_connSub?.cancel());
    unawaited(_syncSub?.cancel());
    return super.close();
  }
}
