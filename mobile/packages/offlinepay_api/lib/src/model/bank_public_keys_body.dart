//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'bank_public_keys_body.g.dart';

/// BankPublicKeysBody
///
/// Properties:
/// * [keyIds] 
@BuiltValue()
abstract class BankPublicKeysBody implements Built<BankPublicKeysBody, BankPublicKeysBodyBuilder> {
  @BuiltValueField(wireName: r'key_ids')
  BuiltList<String>? get keyIds;

  BankPublicKeysBody._();

  factory BankPublicKeysBody([void updates(BankPublicKeysBodyBuilder b)]) = _$BankPublicKeysBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BankPublicKeysBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<BankPublicKeysBody> get serializer => _$BankPublicKeysBodySerializer();
}

class _$BankPublicKeysBodySerializer implements PrimitiveSerializer<BankPublicKeysBody> {
  @override
  final Iterable<Type> types = const [BankPublicKeysBody, _$BankPublicKeysBody];

  @override
  final String wireName = r'BankPublicKeysBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    BankPublicKeysBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.keyIds != null) {
      yield r'key_ids';
      yield serializers.serialize(
        object.keyIds,
        specifiedType: const FullType(BuiltList, [FullType(String)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    BankPublicKeysBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required BankPublicKeysBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'key_ids':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.keyIds.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  BankPublicKeysBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BankPublicKeysBodyBuilder();
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

