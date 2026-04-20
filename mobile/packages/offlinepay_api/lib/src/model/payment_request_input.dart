//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:offlinepay_api/src/model/display_card_input.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'payment_request_input.g.dart';

/// Receiver-signed invoice the payer counter-signs before issuing a PaymentToken. amount_kobo=0 is the \"unbound\" sentinel (P2P fallback: the payer enters the amount themselves). 
///
/// Properties:
/// * [receiverId] 
/// * [receiverDisplayCard] 
/// * [amountKobo] - 0 means \"unbound\" — the payer picks the amount.
/// * [sessionNonce] - 16 random bytes; single-use per receiver.
/// * [issuedAt] 
/// * [expiresAt] 
/// * [receiverDevicePubkey] 
/// * [receiverSignature] 
@BuiltValue()
abstract class PaymentRequestInput implements Built<PaymentRequestInput, PaymentRequestInputBuilder> {
  @BuiltValueField(wireName: r'receiver_id')
  String get receiverId;

  @BuiltValueField(wireName: r'receiver_display_card')
  DisplayCardInput get receiverDisplayCard;

  /// 0 means \"unbound\" — the payer picks the amount.
  @BuiltValueField(wireName: r'amount_kobo')
  int get amountKobo;

  /// 16 random bytes; single-use per receiver.
  @BuiltValueField(wireName: r'session_nonce')
  String get sessionNonce;

  @BuiltValueField(wireName: r'issued_at')
  DateTime get issuedAt;

  @BuiltValueField(wireName: r'expires_at')
  DateTime get expiresAt;

  @BuiltValueField(wireName: r'receiver_device_pubkey')
  String get receiverDevicePubkey;

  @BuiltValueField(wireName: r'receiver_signature')
  String get receiverSignature;

  PaymentRequestInput._();

  factory PaymentRequestInput([void updates(PaymentRequestInputBuilder b)]) = _$PaymentRequestInput;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PaymentRequestInputBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PaymentRequestInput> get serializer => _$PaymentRequestInputSerializer();
}

class _$PaymentRequestInputSerializer implements PrimitiveSerializer<PaymentRequestInput> {
  @override
  final Iterable<Type> types = const [PaymentRequestInput, _$PaymentRequestInput];

  @override
  final String wireName = r'PaymentRequestInput';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PaymentRequestInput object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'receiver_id';
    yield serializers.serialize(
      object.receiverId,
      specifiedType: const FullType(String),
    );
    yield r'receiver_display_card';
    yield serializers.serialize(
      object.receiverDisplayCard,
      specifiedType: const FullType(DisplayCardInput),
    );
    yield r'amount_kobo';
    yield serializers.serialize(
      object.amountKobo,
      specifiedType: const FullType(int),
    );
    yield r'session_nonce';
    yield serializers.serialize(
      object.sessionNonce,
      specifiedType: const FullType(String),
    );
    yield r'issued_at';
    yield serializers.serialize(
      object.issuedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'expires_at';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'receiver_device_pubkey';
    yield serializers.serialize(
      object.receiverDevicePubkey,
      specifiedType: const FullType(String),
    );
    yield r'receiver_signature';
    yield serializers.serialize(
      object.receiverSignature,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PaymentRequestInput object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PaymentRequestInputBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'receiver_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.receiverId = valueDes;
          break;
        case r'receiver_display_card':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DisplayCardInput),
          ) as DisplayCardInput;
          result.receiverDisplayCard.replace(valueDes);
          break;
        case r'amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.amountKobo = valueDes;
          break;
        case r'session_nonce':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.sessionNonce = valueDes;
          break;
        case r'issued_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.issuedAt = valueDes;
          break;
        case r'expires_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.expiresAt = valueDes;
          break;
        case r'receiver_device_pubkey':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.receiverDevicePubkey = valueDes;
          break;
        case r'receiver_signature':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.receiverSignature = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PaymentRequestInput deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PaymentRequestInputBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}

