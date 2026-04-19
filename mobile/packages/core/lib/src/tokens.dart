import 'dart:convert' show base64;
import 'dart:typed_data';

import 'canonical.dart' show CanonicalBytes;

class CeilingTokenPayload {
  final String payerId;
  final int ceilingAmount;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int sequenceStart;
  final Uint8List payerPublicKey;
  final String bankKeyId;

  CeilingTokenPayload({
    required this.payerId,
    required this.ceilingAmount,
    required this.issuedAt,
    required this.expiresAt,
    required this.sequenceStart,
    required this.payerPublicKey,
    required this.bankKeyId,
  });

  Map<String, Object?> toJson() => {
        'payer_id': payerId,
        'ceiling_amount': ceilingAmount,
        'issued_at': issuedAt,
        'expires_at': expiresAt,
        'sequence_start': sequenceStart,
        'public_key': CanonicalBytes(payerPublicKey),
        'bank_key_id': bankKeyId,
      };

  factory CeilingTokenPayload.fromJson(Map<String, Object?> m) {
    return CeilingTokenPayload(
      payerId: m['payer_id']! as String,
      ceilingAmount: (m['ceiling_amount']! as num).toInt(),
      issuedAt: DateTime.parse(m['issued_at']! as String).toUtc(),
      expiresAt: DateTime.parse(m['expires_at']! as String).toUtc(),
      sequenceStart: (m['sequence_start']! as num).toInt(),
      payerPublicKey: Uint8List.fromList(base64.decode(m['public_key']! as String)),
      bankKeyId: m['bank_key_id']! as String,
    );
  }

  void validate() {
    if (payerId.isEmpty) throw ArgumentError('payer_id required');
    if (ceilingAmount <= 0) throw ArgumentError('ceiling_amount must be positive');
    if (!expiresAt.isAfter(issuedAt)) {
      throw ArgumentError('expires_at must be after issued_at');
    }
    if (sequenceStart < 0) throw ArgumentError('sequence_start must be non-negative');
    if (payerPublicKey.isEmpty) throw ArgumentError('public_key required');
    if (bankKeyId.isEmpty) throw ArgumentError('bank_key_id required');
  }
}

const int sessionNonceSize = 16;

class PaymentPayload {
  final String payerId;
  final String payeeId;
  final int amount;
  final int sequenceNumber;
  final int remainingCeiling;
  final DateTime timestamp;
  final String ceilingTokenId;
  final Uint8List sessionNonce;
  final Uint8List requestHash;

  PaymentPayload({
    required this.payerId,
    required this.payeeId,
    required this.amount,
    required this.sequenceNumber,
    required this.remainingCeiling,
    required this.timestamp,
    required this.ceilingTokenId,
    required this.sessionNonce,
    required this.requestHash,
  });

  Map<String, Object?> toJson() => {
        'payer_id': payerId,
        'payee_id': payeeId,
        'amount': amount,
        'sequence_number': sequenceNumber,
        'remaining_ceiling': remainingCeiling,
        'timestamp': timestamp,
        'ceiling_token_id': ceilingTokenId,
        'session_nonce': CanonicalBytes(sessionNonce),
        'request_hash': CanonicalBytes(requestHash),
      };

  factory PaymentPayload.fromJson(Map<String, Object?> m) {
    return PaymentPayload(
      payerId: m['payer_id']! as String,
      payeeId: m['payee_id']! as String,
      amount: (m['amount']! as num).toInt(),
      sequenceNumber: (m['sequence_number']! as num).toInt(),
      remainingCeiling: (m['remaining_ceiling']! as num).toInt(),
      timestamp: DateTime.parse(m['timestamp']! as String).toUtc(),
      ceilingTokenId: m['ceiling_token_id']! as String,
      sessionNonce: Uint8List.fromList(base64.decode(m['session_nonce']! as String)),
      requestHash: Uint8List.fromList(base64.decode(m['request_hash']! as String)),
    );
  }

  void validate() {
    if (payerId.isEmpty) throw ArgumentError('payer_id required');
    if (payeeId.isEmpty) throw ArgumentError('payee_id required');
    if (payerId == payeeId) throw ArgumentError('payer_id and payee_id must differ');
    if (amount <= 0) throw ArgumentError('amount must be positive');
    if (sequenceNumber <= 0) throw ArgumentError('sequence_number must be positive');
    if (remainingCeiling < 0) throw ArgumentError('remaining_ceiling must be non-negative');
    if (ceilingTokenId.isEmpty) throw ArgumentError('ceiling_token_id required');
    if (sessionNonce.length != sessionNonceSize) {
      throw ArgumentError('session_nonce must be $sessionNonceSize bytes');
    }
    if (requestHash.isEmpty) throw ArgumentError('request_hash required');
  }
}

class PaymentToken {
  final PaymentPayload payload;
  final Uint8List payerSignature;

  PaymentToken({required this.payload, required this.payerSignature});

  Map<String, Object?> toJson() => {
        ...payload.toJson(),
        'payer_signature': CanonicalBytes(payerSignature),
      };
}

class DisplayCardPayload {
  final String userId;
  final String displayName;
  final String accountNumber;
  final DateTime issuedAt;
  final String bankKeyId;

  DisplayCardPayload({
    required this.userId,
    required this.displayName,
    required this.accountNumber,
    required this.issuedAt,
    required this.bankKeyId,
  });

  Map<String, Object?> toJson() => {
        'user_id': userId,
        'display_name': displayName,
        'account_number': accountNumber,
        'issued_at': issuedAt,
        'bank_key_id': bankKeyId,
      };

  factory DisplayCardPayload.fromJson(Map<String, Object?> m) {
    return DisplayCardPayload(
      userId: m['user_id']! as String,
      displayName: m['display_name']! as String,
      accountNumber: m['account_number']! as String,
      issuedAt: DateTime.parse(m['issued_at']! as String).toUtc(),
      bankKeyId: m['bank_key_id']! as String,
    );
  }

  void validate() {
    if (userId.isEmpty) throw ArgumentError('user_id required');
    if (displayName.isEmpty) throw ArgumentError('display_name required');
    if (accountNumber.isEmpty) throw ArgumentError('account_number required');
    if (bankKeyId.isEmpty) throw ArgumentError('bank_key_id required');
  }
}

class DisplayCard {
  final DisplayCardPayload payload;
  final Uint8List serverSignature;

  DisplayCard({required this.payload, required this.serverSignature});

  Map<String, Object?> toJson() => {
        ...payload.toJson(),
        'server_signature': CanonicalBytes(serverSignature),
      };

  factory DisplayCard.fromJson(Map<String, Object?> m) {
    final sig = m['server_signature'];
    if (sig == null) {
      throw ArgumentError('display card missing server_signature');
    }
    final payload = DisplayCardPayload.fromJson(m);
    return DisplayCard(
      payload: payload,
      serverSignature: Uint8List.fromList(base64.decode(sig as String)),
    );
  }
}

const int unboundAmount = 0;

class PaymentRequestPayload {
  final String receiverId;
  final DisplayCard receiverDisplayCard;
  final int amount;
  final Uint8List sessionNonce;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final Uint8List receiverDevicePubkey;

  PaymentRequestPayload({
    required this.receiverId,
    required this.receiverDisplayCard,
    required this.amount,
    required this.sessionNonce,
    required this.issuedAt,
    required this.expiresAt,
    required this.receiverDevicePubkey,
  });

  Map<String, Object?> toJson() => {
        'receiver_id': receiverId,
        'receiver_display_card': receiverDisplayCard.toJson(),
        'amount': amount,
        'session_nonce': CanonicalBytes(sessionNonce),
        'issued_at': issuedAt,
        'expires_at': expiresAt,
        'receiver_device_pubkey': CanonicalBytes(receiverDevicePubkey),
      };

  factory PaymentRequestPayload.fromJson(Map<String, Object?> m) {
    return PaymentRequestPayload(
      receiverId: m['receiver_id']! as String,
      receiverDisplayCard:
          DisplayCard.fromJson((m['receiver_display_card']! as Map).cast<String, Object?>()),
      amount: (m['amount']! as num).toInt(),
      sessionNonce: Uint8List.fromList(base64.decode(m['session_nonce']! as String)),
      issuedAt: DateTime.parse(m['issued_at']! as String).toUtc(),
      expiresAt: DateTime.parse(m['expires_at']! as String).toUtc(),
      receiverDevicePubkey:
          Uint8List.fromList(base64.decode(m['receiver_device_pubkey']! as String)),
    );
  }

  bool get isUnbound => amount == unboundAmount;

  void validate() {
    if (receiverId.isEmpty) throw ArgumentError('receiver_id required');
    if (receiverDisplayCard.payload.userId != receiverId) {
      throw ArgumentError('display_card.user_id must match receiver_id');
    }
    if (amount < 0) throw ArgumentError('amount must be >= 0');
    if (sessionNonce.length != sessionNonceSize) {
      throw ArgumentError('session_nonce must be $sessionNonceSize bytes');
    }
    if (!expiresAt.isAfter(issuedAt)) {
      throw ArgumentError('expires_at must be after issued_at');
    }
    if (receiverDevicePubkey.isEmpty) {
      throw ArgumentError('receiver_device_pubkey required');
    }
    receiverDisplayCard.payload.validate();
  }
}

class PaymentRequest {
  final PaymentRequestPayload payload;
  final Uint8List receiverSignature;

  PaymentRequest({required this.payload, required this.receiverSignature});

  Map<String, Object?> toJson() => {
        ...payload.toJson(),
        'receiver_signature': CanonicalBytes(receiverSignature),
      };

  factory PaymentRequest.fromJson(Map<String, Object?> m) {
    final sig = m['receiver_signature'];
    if (sig == null) throw ArgumentError('missing receiver_signature');
    return PaymentRequest(
      payload: PaymentRequestPayload.fromJson(m),
      receiverSignature: Uint8List.fromList(base64.decode(sig as String)),
    );
  }
}

class GossipBlob {
  final Uint8List transactionHash;
  final Uint8List encryptedBlob;
  final Uint8List bankSignature;
  final Uint8List ceilingTokenHash;
  final int hopCount;
  final int blobSize;

  GossipBlob({
    required this.transactionHash,
    required this.encryptedBlob,
    required this.bankSignature,
    required this.ceilingTokenHash,
    required this.hopCount,
    required this.blobSize,
  });

  Map<String, Object?> toJson() => {
        'transaction_hash': CanonicalBytes(transactionHash),
        'encrypted_blob': CanonicalBytes(encryptedBlob),
        'bank_signature': CanonicalBytes(bankSignature),
        'ceiling_token_hash': CanonicalBytes(ceilingTokenHash),
        'hop_count': hopCount,
        'blob_size': blobSize,
      };

  factory GossipBlob.fromJson(Map<String, Object?> m) {
    return GossipBlob(
      transactionHash: Uint8List.fromList(base64.decode(m['transaction_hash']! as String)),
      encryptedBlob: Uint8List.fromList(base64.decode(m['encrypted_blob']! as String)),
      bankSignature: Uint8List.fromList(base64.decode(m['bank_signature']! as String)),
      ceilingTokenHash: Uint8List.fromList(base64.decode(m['ceiling_token_hash']! as String)),
      hopCount: (m['hop_count']! as num).toInt(),
      blobSize: (m['blob_size']! as num).toInt(),
    );
  }
}
