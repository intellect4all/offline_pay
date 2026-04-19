import 'dart:convert' show base64;
import 'dart:typed_data';

import '../canonical.dart' show CanonicalBytes, canonicalize;
import '../tokens.dart'
    show CeilingTokenPayload, PaymentPayload, PaymentRequest, PaymentToken;

class CeilingTokenWire {
  final String id;
  final CeilingTokenPayload payload;
  final Uint8List bankSignature;

  CeilingTokenWire({
    required this.id,
    required this.payload,
    required this.bankSignature,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'payload': payload.toJson(),
        'bank_signature': CanonicalBytes(bankSignature),
      };

  factory CeilingTokenWire.fromJson(Map<String, Object?> m) {
    return CeilingTokenWire(
      id: m['id']! as String,
      payload: CeilingTokenPayload.fromJson(
          Map<String, Object?>.from(m['payload']! as Map)),
      bankSignature:
          Uint8List.fromList(base64.decode(m['bank_signature']! as String)),
    );
  }
}

class GossipInnerPayload {
  final CeilingTokenWire ceiling;
  final PaymentToken payment;
  final PaymentRequest request;
  final String senderUserId;

  GossipInnerPayload({
    required this.ceiling,
    required this.payment,
    required this.request,
    required this.senderUserId,
  });

  Map<String, Object?> toJson() => {
        'ceiling': ceiling.toJson(),
        'payment': payment.toJson(),
        'request': request.toJson(),
        'sender_user_id': senderUserId,
      };

  Uint8List canonicalBytes() => canonicalize(toJson());

  factory GossipInnerPayload.fromJson(Map<String, Object?> m) {
    final paymentMap = Map<String, Object?>.from(m['payment']! as Map);
    final payload = PaymentPayload.fromJson(paymentMap);
    final sigStr = paymentMap['payer_signature'] as String;
    return GossipInnerPayload(
      ceiling: CeilingTokenWire.fromJson(
          Map<String, Object?>.from(m['ceiling']! as Map)),
      payment: PaymentToken(
        payload: payload,
        payerSignature: Uint8List.fromList(base64.decode(sigStr)),
      ),
      request: PaymentRequest.fromJson(
          Map<String, Object?>.from(m['request']! as Map)),
      senderUserId: m['sender_user_id']! as String,
    );
  }
}
