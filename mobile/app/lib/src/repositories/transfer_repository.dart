import 'package:dio/dio.dart';
import 'package:offlinepay_api/offlinepay_api.dart' as gen;



class ResolvedAccount {
  final String accountNumber;
  final String maskedName;

  const ResolvedAccount({
    required this.accountNumber,
    required this.maskedName,
  });
}

enum TransferStatus {
  accepted,
  processing,
  settled,
  failed;

  static TransferStatus fromWire(String s) {
    switch (s.toUpperCase()) {
      case 'ACCEPTED':
        return TransferStatus.accepted;
      case 'SETTLED':
        return TransferStatus.settled;
      case 'FAILED':
        return TransferStatus.failed;
      case 'PROCESSING':
      default:
        return TransferStatus.processing;
    }
  }

  bool get isTerminal =>
      this == TransferStatus.settled || this == TransferStatus.failed;
}


class TransferResult {
  final String id;
  final String senderUserId;
  final String receiverUserId;
  final String? senderDisplayName;
  final String? receiverDisplayName;
  final TransferStatus status;
  final int amountKobo;
  final String receiverAccountNumber;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? settledAt;

  const TransferResult({
    required this.id,
    required this.senderUserId,
    required this.receiverUserId,
    required this.status,
    required this.amountKobo,
    required this.receiverAccountNumber,
    required this.failureReason,
    required this.createdAt,
    required this.settledAt,
    this.senderDisplayName,
    this.receiverDisplayName,
  });

  factory TransferResult.fromGen(gen.Transfer t) => TransferResult(
        id: t.id,
        senderUserId: t.senderUserId,
        receiverUserId: t.receiverUserId,
        senderDisplayName: t.senderDisplayName,
        receiverDisplayName: t.receiverDisplayName,
        status: TransferStatus.fromWire(t.status.name),
        amountKobo: t.amountKobo,
        receiverAccountNumber: t.receiverAccountNumber,
        failureReason: t.failureReason,
        createdAt: t.createdAt,
        settledAt: t.settledAt,
      );
}


class AccountNotFound implements Exception {
  final String accountNumber;
  const AccountNotFound(this.accountNumber);
  @override
  String toString() => 'AccountNotFound($accountNumber)';
}


class TransferRejected implements Exception {
  final String? code;
  final String message;
  final int? statusCode;
  const TransferRejected(this.code, this.message, [this.statusCode]);
  @override
  String toString() =>
      'TransferRejected(${code ?? 'unknown'}: $message, status=${statusCode ?? '?'})';

  bool get isPinNotSet => statusCode == 409 && code == 'pin_not_set';
  bool get isPinBad => statusCode == 401 && code == 'pin_bad';
  bool get isPinLocked => statusCode == 423 && code == 'pin_locked';

  bool get isKycTierBlocked =>
      statusCode == 402 && code == 'kyc_tier_blocked';
  bool get isExceedsSingleLimit =>
      statusCode == 402 && code == 'exceeds_single_limit';
  bool get isExceedsDailyLimit =>
      statusCode == 402 && code == 'exceeds_daily_limit';

  bool get isFraudBlocked =>
      statusCode == 403 && code == 'fraud_block';
}

class TransferRepository {
  final gen.OfflinepayApi _api;

  TransferRepository({required gen.OfflinepayApi api}) : _api = api;

  gen.DefaultApi get _default => _api.getDefaultApi();

  Map<String, dynamic> _authHeaders(String accessToken) => <String, dynamic>{
        'Authorization': 'Bearer $accessToken',
      };

  Future<ResolvedAccount> resolve(
    String accountNumber,
    String accessToken,
  ) async {
    try {
      final resp = await _default.getV1AccountsResolveAccountNumber(
        accountNumber: accountNumber,
        headers: _authHeaders(accessToken),
      );
      final data = resp.data;
      if (data == null) {
        throw StateError('transfers: resolve returned empty body');
      }
      return ResolvedAccount(
        accountNumber: data.accountNumber,
        maskedName: data.maskedName,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw AccountNotFound(accountNumber);
      }
      rethrow;
    }
  }

  Future<TransferResult> initiate({
    required String receiverAccountNumber,
    required int amountKobo,
    required String reference,
    required String pin,
    required String accessToken,
  }) async {
    try {
      final body = gen.InitiateTransferBody((b) => b
        ..receiverAccountNumber = receiverAccountNumber
        ..amountKobo = amountKobo
        ..reference = reference
        ..pin = pin);
      final resp = await _default.postV1Transfers(
        initiateTransferBody: body,
        headers: _authHeaders(accessToken),
      );
      final data = resp.data;
      if (data == null) {
        throw StateError('transfers: initiate returned empty body');
      }
      return TransferResult.fromGen(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null && status >= 200 && status < 300) rethrow;
      String? code;
      String message = e.message ?? 'transfer rejected';
      final respData = e.response?.data;
      if (respData is Map) {
        final c = respData['code'];
        final m = respData['message'];
        if (c is String) code = c;
        if (m is String) message = m;
      }
      throw TransferRejected(code, message, status);
    }
  }

  Future<TransferResult> get(String id, String accessToken) async {
    final resp = await _default.getV1TransfersID(
      id: id,
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('transfers: get returned empty body');
    }
    return TransferResult.fromGen(data);
  }

  Future<List<TransferResult>> list({
    required String accessToken,
    int limit = 50,
    int offset = 0,
  }) async {
    final resp = await _default.getV1Transfers(
      limit: limit,
      offset: offset,
      headers: _authHeaders(accessToken),
    );
    final data = resp.data;
    if (data == null) return const <TransferResult>[];
    return data.items.map(TransferResult.fromGen).toList(growable: false);
  }
}
