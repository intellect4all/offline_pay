import 'dart:convert' show base64, jsonDecode, utf8;

import 'package:offlinepay_api/offlinepay_api.dart' as gen;

class ClaimReceipt {
  final String batchId;
  final String receiverUserId;
  final int totalSubmitted;
  final int totalSettled;
  final int totalPartial;
  final int totalRejected;
  final int totalAmountKobo;
  final String status;
  final DateTime submittedAt;
  final DateTime? processedAt;
  final List<ClaimResult> results;

  const ClaimReceipt({
    required this.batchId,
    required this.receiverUserId,
    required this.totalSubmitted,
    required this.totalSettled,
    required this.totalPartial,
    required this.totalRejected,
    required this.totalAmountKobo,
    required this.status,
    required this.submittedAt,
    required this.processedAt,
    required this.results,
  });

  factory ClaimReceipt.fromGen(gen.BatchReceipt r) => ClaimReceipt(
        batchId: r.batchId,
        receiverUserId: r.receiverUserId,
        totalSubmitted: r.totalSubmitted,
        totalSettled: r.totalSettled,
        totalPartial: r.totalPartial,
        totalRejected: r.totalRejected,
        totalAmountKobo: r.totalAmountKobo,
        status: r.status.name,
        submittedAt: r.submittedAt,
        processedAt: r.processedAt,
        results: r.results.map(ClaimResult.fromGen).toList(growable: false),
      );
}

class ClaimResult {
  final String transactionId;
  final int sequenceNumber;
  final int submittedAmountKobo;
  final int settledAmountKobo;
  final String status;
  final String? reason;

  const ClaimResult({
    required this.transactionId,
    required this.sequenceNumber,
    required this.submittedAmountKobo,
    required this.settledAmountKobo,
    required this.status,
    required this.reason,
  });

  factory ClaimResult.fromGen(gen.SettlementResult r) => ClaimResult(
        transactionId: r.transactionId,
        sequenceNumber: r.sequenceNumber,
        submittedAmountKobo: r.submittedAmountKobo,
        settledAmountKobo: r.settledAmountKobo,
        status: r.status.name,
        reason: r.reason,
      );
}

enum ClaimTxStatus {
  pending,
  settled,
  partiallySettled,
  rejected,
  expired,
  unknown,
}

ClaimTxStatus claimTxStatusFromWire(String wire) {
  switch (wire) {
    case 'TRANSACTION_STATUS_SETTLED':
      return ClaimTxStatus.settled;
    case 'TRANSACTION_STATUS_PARTIALLY_SETTLED':
      return ClaimTxStatus.partiallySettled;
    case 'TRANSACTION_STATUS_REJECTED':
      return ClaimTxStatus.rejected;
    case 'TRANSACTION_STATUS_EXPIRED':
      return ClaimTxStatus.expired;
    case 'TRANSACTION_STATUS_PENDING':
    case 'TRANSACTION_STATUS_QUEUED':
    case 'TRANSACTION_STATUS_SUBMITTED':
      return ClaimTxStatus.pending;
    default:
      return ClaimTxStatus.unknown;
  }
}

class PaymentTokenWire {
  final String payerId;
  final String payeeId;
  final int amountKobo;
  final int sequenceNumber;
  final int remainingCeilingKobo;
  final DateTime timestamp;
  final String ceilingTokenId;
  final String payerSignatureB64;
  final String sessionNonceB64;
  final String requestHashB64;

  const PaymentTokenWire({
    required this.payerId,
    required this.payeeId,
    required this.amountKobo,
    required this.sequenceNumber,
    required this.remainingCeilingKobo,
    required this.timestamp,
    required this.ceilingTokenId,
    required this.payerSignatureB64,
    required this.sessionNonceB64,
    required this.requestHashB64,
  });

  factory PaymentTokenWire.fromBlob(String base64Blob) {
    final m = _decodeJsonMap(base64Blob, 'payment_token');
    return PaymentTokenWire(
      payerId: _requireString(m, 'payer_id', maxLen: 128),
      payeeId: _requireString(m, 'payee_id', maxLen: 128),
      amountKobo: _requireInt(m, 'amount'),
      sequenceNumber: _requireInt(m, 'sequence_number'),
      remainingCeilingKobo: _requireInt(m, 'remaining_ceiling'),
      timestamp: _requireIso8601(m, 'timestamp'),
      ceilingTokenId: _requireString(m, 'ceiling_token_id', maxLen: 128),
      payerSignatureB64: _requireString(m, 'payer_signature', maxLen: 256),
      sessionNonceB64: _requireString(m, 'session_nonce', maxLen: 64),
      requestHashB64: _requireString(m, 'request_hash', maxLen: 128),
    );
  }

  gen.PaymentTokenInput toGen() => gen.PaymentTokenInput((b) => b
    ..payerId = payerId
    ..payeeId = payeeId
    ..amountKobo = amountKobo
    ..sequenceNumber = sequenceNumber
    ..remainingCeilingKobo = remainingCeilingKobo
    ..timestamp = timestamp.toUtc()
    ..ceilingTokenId = ceilingTokenId
    ..payerSignature = payerSignatureB64
    ..sessionNonce = sessionNonceB64
    ..requestHash = requestHashB64);
}

class CeilingTokenWire {
  final String id;
  final String payerId;
  final int ceilingAmountKobo;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int sequenceStart;
  final String payerPublicKeyB64;
  final String bankKeyId;
  final String bankSignatureB64;

  const CeilingTokenWire({
    required this.id,
    required this.payerId,
    required this.ceilingAmountKobo,
    required this.issuedAt,
    required this.expiresAt,
    required this.sequenceStart,
    required this.payerPublicKeyB64,
    required this.bankKeyId,
    required this.bankSignatureB64,
  });

  factory CeilingTokenWire.fromBlob(String base64Blob) {
    final outer = _decodeJsonMap(base64Blob, 'ceiling_token');
    final payloadRaw = outer['payload'];
    if (payloadRaw is! Map) {
      throw const FormatException(
          'ceiling_token: missing or non-object payload field');
    }
    final payload = Map<String, Object?>.from(payloadRaw);
    return CeilingTokenWire(
      id: _requireString(outer, 'id', maxLen: 128),
      payerId: _requireString(payload, 'payer_id', maxLen: 128),
      ceilingAmountKobo: _requireInt(payload, 'ceiling_amount'),
      issuedAt: _requireIso8601(payload, 'issued_at'),
      expiresAt: _requireIso8601(payload, 'expires_at'),
      sequenceStart: _requireInt(payload, 'sequence_start'),
      payerPublicKeyB64: _requireString(payload, 'public_key', maxLen: 256),
      bankKeyId: _requireString(payload, 'bank_key_id', maxLen: 128),
      bankSignatureB64: _requireString(outer, 'bank_signature', maxLen: 256),
    );
  }

  gen.CeilingTokenInput toGen() => gen.CeilingTokenInput((b) => b
    ..id = id
    ..payerId = payerId
    ..ceilingAmountKobo = ceilingAmountKobo
    ..issuedAt = issuedAt.toUtc()
    ..expiresAt = expiresAt.toUtc()
    ..sequenceStart = sequenceStart
    ..payerPublicKey = payerPublicKeyB64
    ..bankKeyId = bankKeyId
    ..bankSignature = bankSignatureB64
    ..status = gen.CeilingTokenInputStatusEnum.CEILING_STATUS_ACTIVE);
}

class PaymentRequestWire {
  final String receiverId;
  final DisplayCardWire displayCard;
  final int amountKobo;
  final String sessionNonceB64;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String receiverDevicePubkeyB64;
  final String receiverSignatureB64;

  const PaymentRequestWire({
    required this.receiverId,
    required this.displayCard,
    required this.amountKobo,
    required this.sessionNonceB64,
    required this.issuedAt,
    required this.expiresAt,
    required this.receiverDevicePubkeyB64,
    required this.receiverSignatureB64,
  });

  factory PaymentRequestWire.fromBlob(String base64Blob) {
    final m = _decodeJsonMap(base64Blob, 'payment_request');
    final cardRaw = m['receiver_display_card'];
    if (cardRaw is! Map) {
      throw const FormatException(
        'payment_request: missing or non-object receiver_display_card',
      );
    }
    final cardMap = Map<String, Object?>.from(cardRaw);
    return PaymentRequestWire(
      receiverId: _requireString(m, 'receiver_id', maxLen: 128),
      displayCard: DisplayCardWire._fromMap(cardMap),
      amountKobo: _requireInt(m, 'amount'),
      sessionNonceB64: _requireString(m, 'session_nonce', maxLen: 64),
      issuedAt: _requireIso8601(m, 'issued_at'),
      expiresAt: _requireIso8601(m, 'expires_at'),
      receiverDevicePubkeyB64:
          _requireString(m, 'receiver_device_pubkey', maxLen: 256),
      receiverSignatureB64: _requireString(m, 'receiver_signature', maxLen: 256),
    );
  }

  gen.PaymentRequestInput toGen() => gen.PaymentRequestInput((b) => b
    ..receiverId = receiverId
    ..receiverDisplayCard = displayCard.toGen().toBuilder()
    ..amountKobo = amountKobo
    ..sessionNonce = sessionNonceB64
    ..issuedAt = issuedAt.toUtc()
    ..expiresAt = expiresAt.toUtc()
    ..receiverDevicePubkey = receiverDevicePubkeyB64
    ..receiverSignature = receiverSignatureB64);
}

class DisplayCardWire {
  final String userId;
  final String displayName;
  final String accountNumber;
  final DateTime issuedAt;
  final String bankKeyId;
  final String serverSignatureB64;

  const DisplayCardWire({
    required this.userId,
    required this.displayName,
    required this.accountNumber,
    required this.issuedAt,
    required this.bankKeyId,
    required this.serverSignatureB64,
  });

  factory DisplayCardWire._fromMap(Map<String, Object?> m) => DisplayCardWire(
        userId: _requireString(m, 'user_id', maxLen: 128),
        displayName: _requireString(m, 'display_name', maxLen: 128),
        accountNumber: _requireString(m, 'account_number', maxLen: 32),
        issuedAt: _requireIso8601(m, 'issued_at'),
        bankKeyId: _requireString(m, 'bank_key_id', maxLen: 128),
        serverSignatureB64:
            _requireString(m, 'server_signature', maxLen: 256),
      );

  gen.DisplayCardInput toGen() => gen.DisplayCardInput((b) => b
    ..userId = userId
    ..displayName = displayName
    ..accountNumber = accountNumber
    ..issuedAt = issuedAt.toUtc()
    ..bankKeyId = bankKeyId
    ..serverSignature = serverSignatureB64);
}

Map<String, Object?> _decodeJsonMap(String base64Blob, String context) {
  try {
    final raw = utf8.decode(base64.decode(base64Blob));
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('$context: top-level JSON is not an object');
    }
    return Map<String, Object?>.from(decoded);
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('$context: $e');
  }
}

String _requireString(
  Map<String, Object?> m,
  String key, {
  required int maxLen,
}) {
  final v = m[key];
  if (v is! String) {
    throw FormatException('field "$key" missing or not a string');
  }
  if (v.isEmpty) {
    throw FormatException('field "$key" is empty');
  }
  if (v.length > maxLen) {
    throw FormatException(
        'field "$key" exceeds max length ($maxLen): got ${v.length}');
  }
  return v;
}

int _requireInt(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! num) {
    throw FormatException('field "$key" missing or not a number');
  }
  if (v.isNaN || v.isInfinite) {
    throw FormatException('field "$key" is not a finite number');
  }
  return v.toInt();
}

DateTime _requireIso8601(Map<String, Object?> m, String key) {
  final raw = _requireString(m, key, maxLen: 64);
  try {
    return DateTime.parse(raw).toUtc();
  } catch (e) {
    throw FormatException('field "$key" is not a valid ISO-8601 timestamp');
  }
}

class ClaimRejected implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  const ClaimRejected(this.code, this.message, this.statusCode);
  @override
  String toString() => 'ClaimRejected($code, status=$statusCode): $message';
}
