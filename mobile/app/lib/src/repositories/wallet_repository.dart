import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:offlinepay_api/offlinepay_api.dart' as gen;
import 'package:offlinepay_core/offlinepay_core.dart'
    show CeilingTokenPayload, EnvelopeCeiling, canonicalize;



class WalletBalance {
  final String kind;
  final int balanceKobo;
  final String currency;
  final DateTime updatedAt;

  const WalletBalance({
    required this.kind,
    required this.balanceKobo,
    required this.currency,
    required this.updatedAt,
  });
}


class CeilingSnapshot {
  final String id;
  final String payerId;
  final int ceilingAmountKobo;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int sequenceStart;
  final Uint8List payerPublicKey;
  final String bankKeyId;
  final Uint8List bankSignature;
  final String status;

  final String ceilingTokenBlob;

  const CeilingSnapshot({
    required this.id,
    required this.payerId,
    required this.ceilingAmountKobo,
    required this.issuedAt,
    required this.expiresAt,
    required this.sequenceStart,
    required this.payerPublicKey,
    required this.bankKeyId,
    required this.bankSignature,
    required this.status,
    required this.ceilingTokenBlob,
  });

  factory CeilingSnapshot.fromGen(gen.CeilingToken t) {
    final payerPublicKey = Uint8List.fromList(base64Decode(t.payerPublicKey));
    final bankSignature = Uint8List.fromList(base64Decode(t.bankSignature));
    final envelope = EnvelopeCeiling(
      id: t.id,
      payload: CeilingTokenPayload(
        payerId: t.payerId,
        ceilingAmount: t.ceilingAmountKobo,
        issuedAt: t.issuedAt,
        expiresAt: t.expiresAt,
        sequenceStart: t.sequenceStart,
        payerPublicKey: payerPublicKey,
        bankKeyId: t.bankKeyId,
      ),
      bankSignature: bankSignature,
    );
    final blob = base64.encode(canonicalize(envelope.toJson()));
    return CeilingSnapshot(
      id: t.id,
      payerId: t.payerId,
      ceilingAmountKobo: t.ceilingAmountKobo,
      issuedAt: t.issuedAt,
      expiresAt: t.expiresAt,
      sequenceStart: t.sequenceStart,
      payerPublicKey: payerPublicKey,
      bankKeyId: t.bankKeyId,
      bankSignature: bankSignature,
      status: t.status.name,
      ceilingTokenBlob: blob,
    );
  }
}

String accountKindFromWire(String wire) {
  switch (wire) {
    case 'ACCOUNT_KIND_MAIN':
      return 'main';
    case 'ACCOUNT_KIND_OFFLINE':
      return 'offline';
    case 'ACCOUNT_KIND_LIEN_HOLDING':
      return 'lien';
    case 'ACCOUNT_KIND_RECEIVING_PENDING':
      return 'receiving_pending';
    default:
      return '';
  }
}

class RecoverOfflineOutcome {
  final String ceilingId;
  final int quarantinedKobo;
  final DateTime releaseAfter;
  const RecoverOfflineOutcome({
    required this.ceilingId,
    required this.quarantinedKobo,
    required this.releaseAfter,
  });
}

class CurrentCeilingSnapshot {
  final bool present;
  final String? ceilingId;
  final String? status;
  final int? ceilingKobo;
  final int? settledKobo;
  final int? remainingKobo;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime? releaseAfter;

  const CurrentCeilingSnapshot({
    required this.present,
    this.ceilingId,
    this.status,
    this.ceilingKobo,
    this.settledKobo,
    this.remainingKobo,
    this.issuedAt,
    this.expiresAt,
    this.releaseAfter,
  });

  bool get isActive => present && status == 'ACTIVE';
  bool get isRecoveryPending => present && status == 'RECOVERY_PENDING';
}

class RecoverOfflineRejected implements Exception {
  final String? code;
  final String message;
  final int? statusCode;
  const RecoverOfflineRejected(this.code, this.message, [this.statusCode]);
  @override
  String toString() =>
      'RecoverOfflineRejected(${code ?? 'unknown'}: $message, status=${statusCode ?? '?'})';

  bool get isUnsettledClaims => code == 'unsettled_claims';
  bool get isNoActiveCeiling => code == 'no_active_ceiling';
}

class WalletRepository {
  final gen.OfflinepayApi _api;

  WalletRepository({required gen.OfflinepayApi api}) : _api = api;

  gen.DefaultApi get _default => _api.getDefaultApi();

  Map<String, dynamic> _authHeaders(String accessToken) => <String, dynamic>{
        'Authorization': 'Bearer $accessToken',
      };

  Future<List<WalletBalance>> getBalances(String accessToken) async {
    final resp = await _default.getV1WalletBalances(
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('wallet: getBalances returned empty body');
    }
    return data.balances
        .map((b) => WalletBalance(
              kind: b.kind.name,
              balanceKobo: b.balanceKobo,
              currency: b.currency,
              updatedAt: b.updatedAt,
            ))
        .toList(growable: false);
  }

  Future<CeilingSnapshot> fundOffline({
    required int amountKobo,
    required int ttlSeconds,
    required Uint8List payerPublicKey,
    required String accessToken,
  }) async {
    final body = gen.FundOfflineBody((b) => b
      ..amountKobo = amountKobo
      ..ttlSeconds = ttlSeconds
      ..payerPublicKey = base64Encode(payerPublicKey));
    final resp = await _default.postV1WalletFundOffline(
      fundOfflineBody: body,
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('wallet: fundOffline returned empty body');
    }
    return CeilingSnapshot.fromGen(data.ceiling);
  }

  Future<({int releasedKobo, int newMainBalanceKobo})> moveToMain(
    String accessToken,
  ) async {
    final resp = await _default.postV1WalletMoveToMain(
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('wallet: moveToMain returned empty body');
    }
    return (
      releasedKobo: data.releasedKobo,
      newMainBalanceKobo: data.newMainBalanceKobo,
    );
  }

  Future<int> topUp({
    required int amountKobo,
    required String accessToken,
  }) async {
    final body = gen.TopUpBody((b) => b..amountKobo = amountKobo);
    final resp = await _default.postV1WalletTopUp(
      topUpBody: body,
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('wallet: topUp returned empty body');
    }
    return data.newBalanceKobo;
  }

  Future<CurrentCeilingSnapshot> getCurrentCeiling(String accessToken) async {
    final resp = await _default.getV1WalletCeilingCurrent(
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('wallet: getCurrentCeiling returned empty body');
    }
    if (!data.present) {
      return const CurrentCeilingSnapshot(present: false);
    }
    return CurrentCeilingSnapshot(
      present: true,
      ceilingId: data.ceilingId,
      status: data.status,
      ceilingKobo: data.ceilingKobo,
      settledKobo: data.settledKobo,
      remainingKobo: data.remainingKobo,
      issuedAt: data.issuedAt?.toUtc(),
      expiresAt: data.expiresAt?.toUtc(),
      releaseAfter: data.releaseAfter?.toUtc(),
    );
  }

  Future<RecoverOfflineOutcome> recoverOfflineCeiling(String accessToken) async {
    try {
      final resp = await _default.postV1WalletRecoverOfflineCeiling(
        headers: _authHeaders(accessToken),
      );
      final data = resp.data;
      if (data == null) {
        throw StateError('wallet: recoverOfflineCeiling returned empty body');
      }
      return RecoverOfflineOutcome(
        ceilingId: data.ceilingId,
        quarantinedKobo: data.quarantinedKobo,
        releaseAfter: data.releaseAfter.toUtc(),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 200 && status < 300) rethrow;
      String? code;
      String message = e.message ?? 'recover offline ceiling failed';
      final respData = e.response?.data;
      if (respData is Map) {
        final c = respData['code'];
        final m = respData['message'];
        if (c is String) code = c;
        if (m is String) message = m;
      }
      throw RecoverOfflineRejected(code, message, status);
    }
  }

  Future<CeilingSnapshot> refreshCeiling({
    required int newAmountKobo,
    required int ttlSeconds,
    required Uint8List payerPublicKey,
    required String accessToken,
  }) async {
    final body = gen.RefreshCeilingBody((b) => b
      ..newAmountKobo = newAmountKobo
      ..ttlSeconds = ttlSeconds
      ..payerPublicKey = base64Encode(payerPublicKey));
    final resp = await _default.postV1WalletRefreshCeiling(
      refreshCeilingBody: body,
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('wallet: refreshCeiling returned empty body');
    }
    return CeilingSnapshot.fromGen(data.ceiling);
  }
}
