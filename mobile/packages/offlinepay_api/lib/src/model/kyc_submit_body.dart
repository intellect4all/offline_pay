//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'kyc_submit_body.g.dart';

/// KYCSubmitBody
///
/// Properties:
/// * [idType] 
/// * [idNumber] 
@BuiltValue()
abstract class KYCSubmitBody implements Built<KYCSubmitBody, KYCSubmitBodyBuilder> {
  @BuiltValueField(wireName: r'id_type')
  KYCSubmitBodyIdTypeEnum get idType;
  // enum idTypeEnum {  NIN,  BVN,  };

  @BuiltValueField(wireName: r'id_number')
  String get idNumber;

  KYCSubmitBody._();

  factory KYCSubmitBody([void updates(KYCSubmitBodyBuilder b)]) = _$KYCSubmitBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(KYCSubmitBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<KYCSubmitBody> get serializer => _$KYCSubmitBodySerializer();
}

class _$KYCSubmitBodySerializer implements PrimitiveSerializer<KYCSubmitBody> {
  @override
  final Iterable<Type> types = const [KYCSubmitBody, _$KYCSubmitBody];

  @override
  final String wireName = r'KYCSubmitBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    KYCSubmitBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id_type';
    yield serializers.serialize(
      object.idType,
      specifiedType: const FullType(KYCSubmitBodyIdTypeEnum),
    );
    yield r'id_number';
    yield serializers.serialize(
      object.idNumber,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    KYCSubmitBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required KYCSubmitBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id_type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(KYCSubmitBodyIdTypeEnum),
          ) as KYCSubmitBodyIdTypeEnum;
          result.idType = valueDes;
          break;
        case r'id_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.idNumber = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  KYCSubmitBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = KYCSubmitBodyBuilder();
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

class KYCSubmitBodyIdTypeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'NIN')
  static const KYCSubmitBodyIdTypeEnum NIN = _$kYCSubmitBodyIdTypeEnum_NIN;
  @BuiltValueEnumConst(wireName: r'BVN')
  static const KYCSubmitBodyIdTypeEnum BVN = _$kYCSubmitBodyIdTypeEnum_BVN;

  static Serializer<KYCSubmitBodyIdTypeEnum> get serializer => _$kYCSubmitBodyIdTypeEnumSerializer;

  const KYCSubmitBodyIdTypeEnum._(String name): super(name);

  static BuiltSet<KYCSubmitBodyIdTypeEnum> get values => _$kYCSubmitBodyIdTypeEnumValues;
  static KYCSubmitBodyIdTypeEnum valueOf(String name) => _$kYCSubmitBodyIdTypeEnumValueOf(name);
}

