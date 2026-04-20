//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'ceiling_token_input.g.dart';

/// CeilingTokenInput
///
/// Properties:
/// * [id] 
/// * [payerId] 
/// * [ceilingAmountKobo] 
/// * [issuedAt] 
/// * [expiresAt] 
/// * [sequenceStart] 
/// * [payerPublicKey] 
/// * [bankKeyId] 
/// * [bankSignature] 
/// * [status] 
@BuiltValue()
abstract class CeilingTokenInput implements Built<CeilingTokenInput, CeilingTokenInputBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'payer_id')
  String get payerId;

  @BuiltValueField(wireName: r'ceiling_amount_kobo')
  int get ceilingAmountKobo;

  @BuiltValueField(wireName: r'issued_at')
  DateTime get issuedAt;

  @BuiltValueField(wireName: r'expires_at')
  DateTime get expiresAt;

  @BuiltValueField(wireName: r'sequence_start')
  int get sequenceStart;

  @BuiltValueField(wireName: r'payer_public_key')
  String get payerPublicKey;

  @BuiltValueField(wireName: r'bank_key_id')
  String get bankKeyId;

  @BuiltValueField(wireName: r'bank_signature')
  String get bankSignature;

  @BuiltValueField(wireName: r'status')
  CeilingTokenInputStatusEnum get status;
  // enum statusEnum {  CEILING_STATUS_UNSPECIFIED,  CEILING_STATUS_ACTIVE,  CEILING_STATUS_EXPIRED,  CEILING_STATUS_EXHAUSTED,  CEILING_STATUS_REVOKED,  };

  CeilingTokenInput._();

  factory CeilingTokenInput([void updates(CeilingTokenInputBuilder b)]) = _$CeilingTokenInput;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CeilingTokenInputBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CeilingTokenInput> get serializer => _$CeilingTokenInputSerializer();
}

class _$CeilingTokenInputSerializer implements PrimitiveSerializer<CeilingTokenInput> {
  @override
  final Iterable<Type> types = const [CeilingTokenInput, _$CeilingTokenInput];

  @override
  final String wireName = r'CeilingTokenInput';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CeilingTokenInput object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'payer_id';
    yield serializers.serialize(
      object.payerId,
      specifiedType: const FullType(String),
    );
    yield r'ceiling_amount_kobo';
    yield serializers.serialize(
      object.ceilingAmountKobo,
      specifiedType: const FullType(int),
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
    yield r'sequence_start';
    yield serializers.serialize(
      object.sequenceStart,
      specifiedType: const FullType(int),
    );
    yield r'payer_public_key';
    yield serializers.serialize(
      object.payerPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'bank_key_id';
    yield serializers.serialize(
      object.bankKeyId,
      specifiedType: const FullType(String),
    );
    yield r'bank_signature';
    yield serializers.serialize(
      object.bankSignature,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(CeilingTokenInputStatusEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CeilingTokenInput object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CeilingTokenInputBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'payer_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.payerId = valueDes;
          break;
        case r'ceiling_amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.ceilingAmountKobo = valueDes;
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
        case r'sequence_start':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.sequenceStart = valueDes;
          break;
        case r'payer_public_key':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.payerPublicKey = valueDes;
          break;
        case r'bank_key_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.bankKeyId = valueDes;
          break;
        case r'bank_signature':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.bankSignature = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(CeilingTokenInputStatusEnum),
          ) as CeilingTokenInputStatusEnum;
          result.status = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CeilingTokenInput deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CeilingTokenInputBuilder();
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

class CeilingTokenInputStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'CEILING_STATUS_UNSPECIFIED')
  static const CeilingTokenInputStatusEnum CEILING_STATUS_UNSPECIFIED = _$ceilingTokenInputStatusEnum_CEILING_STATUS_UNSPECIFIED;
  @BuiltValueEnumConst(wireName: r'CEILING_STATUS_ACTIVE')
  static const CeilingTokenInputStatusEnum CEILING_STATUS_ACTIVE = _$ceilingTokenInputStatusEnum_CEILING_STATUS_ACTIVE;
  @BuiltValueEnumConst(wireName: r'CEILING_STATUS_EXPIRED')
  static const CeilingTokenInputStatusEnum CEILING_STATUS_EXPIRED = _$ceilingTokenInputStatusEnum_CEILING_STATUS_EXPIRED;
  @BuiltValueEnumConst(wireName: r'CEILING_STATUS_EXHAUSTED')
  static const CeilingTokenInputStatusEnum CEILING_STATUS_EXHAUSTED = _$ceilingTokenInputStatusEnum_CEILING_STATUS_EXHAUSTED;
  @BuiltValueEnumConst(wireName: r'CEILING_STATUS_REVOKED')
  static const CeilingTokenInputStatusEnum CEILING_STATUS_REVOKED = _$ceilingTokenInputStatusEnum_CEILING_STATUS_REVOKED;

  static Serializer<CeilingTokenInputStatusEnum> get serializer => _$ceilingTokenInputStatusEnumSerializer;

  const CeilingTokenInputStatusEnum._(String name): super(name);

  static BuiltSet<CeilingTokenInputStatusEnum> get values => _$ceilingTokenInputStatusEnumValues;
  static CeilingTokenInputStatusEnum valueOf(String name) => _$ceilingTokenInputStatusEnumValueOf(name);
}

