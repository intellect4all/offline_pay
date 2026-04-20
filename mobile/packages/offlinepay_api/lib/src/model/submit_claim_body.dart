//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:offlinepay_api/src/model/ceiling_token_input.dart';
import 'package:built_collection/built_collection.dart';
import 'package:offlinepay_api/src/model/payment_request_input.dart';
import 'package:offlinepay_api/src/model/payment_token_input.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'submit_claim_body.g.dart';

/// SubmitClaimBody
///
/// Properties:
/// * [clientBatchId] 
/// * [tokens] 
/// * [ceilings] 
/// * [requests] - Receiver-signed PaymentRequests each token counter-signs. Match by session_nonce — every token must have exactly one request. 
@BuiltValue()
abstract class SubmitClaimBody implements Built<SubmitClaimBody, SubmitClaimBodyBuilder> {
  @BuiltValueField(wireName: r'client_batch_id')
  String get clientBatchId;

  @BuiltValueField(wireName: r'tokens')
  BuiltList<PaymentTokenInput> get tokens;

  @BuiltValueField(wireName: r'ceilings')
  BuiltList<CeilingTokenInput> get ceilings;

  /// Receiver-signed PaymentRequests each token counter-signs. Match by session_nonce — every token must have exactly one request. 
  @BuiltValueField(wireName: r'requests')
  BuiltList<PaymentRequestInput> get requests;

  SubmitClaimBody._();

  factory SubmitClaimBody([void updates(SubmitClaimBodyBuilder b)]) = _$SubmitClaimBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SubmitClaimBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SubmitClaimBody> get serializer => _$SubmitClaimBodySerializer();
}

class _$SubmitClaimBodySerializer implements PrimitiveSerializer<SubmitClaimBody> {
  @override
  final Iterable<Type> types = const [SubmitClaimBody, _$SubmitClaimBody];

  @override
  final String wireName = r'SubmitClaimBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SubmitClaimBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'client_batch_id';
    yield serializers.serialize(
      object.clientBatchId,
      specifiedType: const FullType(String),
    );
    yield r'tokens';
    yield serializers.serialize(
      object.tokens,
      specifiedType: const FullType(BuiltList, [FullType(PaymentTokenInput)]),
    );
    yield r'ceilings';
    yield serializers.serialize(
      object.ceilings,
      specifiedType: const FullType(BuiltList, [FullType(CeilingTokenInput)]),
    );
    yield r'requests';
    yield serializers.serialize(
      object.requests,
      specifiedType: const FullType(BuiltList, [FullType(PaymentRequestInput)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SubmitClaimBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SubmitClaimBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'client_batch_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.clientBatchId = valueDes;
          break;
        case r'tokens':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(PaymentTokenInput)]),
          ) as BuiltList<PaymentTokenInput>;
          result.tokens.replace(valueDes);
          break;
        case r'ceilings':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(CeilingTokenInput)]),
          ) as BuiltList<CeilingTokenInput>;
          result.ceilings.replace(valueDes);
          break;
        case r'requests':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(PaymentRequestInput)]),
          ) as BuiltList<PaymentRequestInput>;
          result.requests.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SubmitClaimBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SubmitClaimBodyBuilder();
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

