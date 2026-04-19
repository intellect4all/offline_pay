import 'dart:convert' show base64;
import 'dart:typed_data';

import '../canonical.dart' show CanonicalBytes, canonicalize;
import '../tokens.dart'
    show
        CeilingTokenPayload,
        DisplayCard,
        GossipBlob,
        PaymentPayload,
        PaymentToken;

class EnvelopeCeiling {
  final String id;
  final CeilingTokenPayload payload;
  final Uint8List bankSignature;

  EnvelopeCeiling({
    required this.id,
    required this.payload,
    required this.bankSignature,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'payload': payload.toJson(),
        'bank_signature': CanonicalBytes(bankSignature),
      };

  factory EnvelopeCeiling.fromJson(Map<String, Object?> m) {
    final p = Map<String, Object?>.from(m['payload']! as Map);
    return EnvelopeCeiling(
      id: m['id']! as String,
      payload: CeilingTokenPayload.fromJson(p),
      bankSignature:
          Uint8List.fromList(base64.decode(m['bank_signature']! as String)),
    );
  }
}

class GossipEnvelope {
  final PaymentToken paymentToken;
  final EnvelopeCeiling? ceiling;
  final List<GossipBlob> blobs;

  final DisplayCard? payerDisplayCard;

  GossipEnvelope({
    required this.paymentToken,
    this.ceiling,
    required this.blobs,
    this.payerDisplayCard,
  });

  Map<String, Object?> toJson() => {
        'payment_token': paymentToken.toJson(),
        if (ceiling != null) 'ceiling': ceiling!.toJson(),
        'blobs': blobs.map((b) => b.toJson()).toList(growable: false),
        if (payerDisplayCard != null)
          'payer_display_card': payerDisplayCard!.toJson(),
      };

  Uint8List canonicalBytes() => canonicalize(toJson());

  factory GossipEnvelope.fromJson(Map<String, Object?> m) {
    final pt = Map<String, Object?>.from(m['payment_token']! as Map);
    final sigStr = pt['payer_signature'] as String;
    final payload = PaymentPayload.fromJson(pt);
    final token = PaymentToken(
      payload: payload,
      payerSignature: Uint8List.fromList(base64.decode(sigStr)),
    );
    EnvelopeCeiling? ceiling;
    if (m['ceiling'] != null) {
      ceiling = EnvelopeCeiling.fromJson(
          Map<String, Object?>.from(m['ceiling']! as Map));
    }
    final blobsRaw = m['blobs'] as List? ?? const [];
    final blobs = <GossipBlob>[];
    for (final b in blobsRaw) {
      blobs.add(GossipBlob.fromJson(Map<String, Object?>.from(b as Map)));
    }
    DisplayCard? payerCard;
    final cardRaw = m['payer_display_card'];
    if (cardRaw is Map) {
      try {
        payerCard = DisplayCard.fromJson(Map<String, Object?>.from(cardRaw));
      } catch (_) {
      }
    }
    return GossipEnvelope(
      paymentToken: token,
      ceiling: ceiling,
      blobs: blobs,
      payerDisplayCard: payerCard,
    );
  }
}
