//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'payment_token_input.g.dart';

/// PaymentTokenInput
///
/// Properties:
/// * [payerId] 
/// * [payeeId] 
/// * [amountKobo] 
/// * [sequenceNumber] 
/// * [remainingCeilingKobo] 
/// * [timestamp] 
/// * [ceilingTokenId] 
/// * [payerSignature] 
/// * [sessionNonce] - 16-byte nonce from the PaymentRequest; single-use per receiver.
/// * [requestHash] - sha256(canonical(PaymentRequest)) — server recomputes to detect tampering.
@BuiltValue()
abstract class PaymentTokenInput implements Built<PaymentTokenInput, PaymentTokenInputBuilder> {
  @BuiltValueField(wireName: r'payer_id')
  String get payerId;

  @BuiltValueField(wireName: r'payee_id')
  String get payeeId;

  @BuiltValueField(wireName: r'amount_kobo')
  int get amountKobo;

  @BuiltValueField(wireName: r'sequence_number')
  int get sequenceNumber;

  @BuiltValueField(wireName: r'remaining_ceiling_kobo')
  int get remainingCeilingKobo;

  @BuiltValueField(wireName: r'timestamp')
  DateTime get timestamp;

  @BuiltValueField(wireName: r'ceiling_token_id')
  String get ceilingTokenId;

  @BuiltValueField(wireName: r'payer_signature')
  String get payerSignature;

  /// 16-byte nonce from the PaymentRequest; single-use per receiver.
  @BuiltValueField(wireName: r'session_nonce')
  String get sessionNonce;

  /// sha256(canonical(PaymentRequest)) — server recomputes to detect tampering.
  @BuiltValueField(wireName: r'request_hash')
  String get requestHash;

  PaymentTokenInput._();

  factory PaymentTokenInput([void updates(PaymentTokenInputBuilder b)]) = _$PaymentTokenInput;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PaymentTokenInputBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PaymentTokenInput> get serializer => _$PaymentTokenInputSerializer();
}

class _$PaymentTokenInputSerializer implements PrimitiveSerializer<PaymentTokenInput> {
  @override
  final Iterable<Type> types = const [PaymentTokenInput, _$PaymentTokenInput];

  @override
  final String wireName = r'PaymentTokenInput';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PaymentTokenInput object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'payer_id';
    yield serializers.serialize(
      object.payerId,
      specifiedType: const FullType(String),
    );
    yield r'payee_id';
    yield serializers.serialize(
      object.payeeId,
      specifiedType: const FullType(String),
    );
    yield r'amount_kobo';
    yield serializers.serialize(
      object.amountKobo,
      specifiedType: const FullType(int),
    );
    yield r'sequence_number';
    yield serializers.serialize(
      object.sequenceNumber,
      specifiedType: const FullType(int),
    );
    yield r'remaining_ceiling_kobo';
    yield serializers.serialize(
      object.remainingCeilingKobo,
      specifiedType: const FullType(int),
    );
    yield r'timestamp';
    yield serializers.serialize(
      object.timestamp,
      specifiedType: const FullType(DateTime),
    );
    yield r'ceiling_token_id';
    yield serializers.serialize(
      object.ceilingTokenId,
      specifiedType: const FullType(String),
    );
    yield r'payer_signature';
    yield serializers.serialize(
      object.payerSignature,
      specifiedType: const FullType(String),
    );
    yield r'session_nonce';
    yield serializers.serialize(
      object.sessionNonce,
      specifiedType: const FullType(String),
    );
    yield r'request_hash';
    yield serializers.serialize(
      object.requestHash,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PaymentTokenInput object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PaymentTokenInputBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'payer_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.payerId = valueDes;
          break;
        case r'payee_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.payeeId = valueDes;
          break;
        case r'amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.amountKobo = valueDes;
          break;
        case r'sequence_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.sequenceNumber = valueDes;
          break;
        case r'remaining_ceiling_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.remainingCeilingKobo = valueDes;
          break;
        case r'timestamp':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.timestamp = valueDes;
          break;
        case r'ceiling_token_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.ceilingTokenId = valueDes;
          break;
        case r'payer_signature':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.payerSignature = valueDes;
          break;
        case r'session_nonce':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.sessionNonce = valueDes;
          break;
        case r'request_hash':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.requestHash = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PaymentTokenInput deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PaymentTokenInputBuilder();
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

