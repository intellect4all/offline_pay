//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:offlinepay_api/src/model/bank_public_key.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'bank_public_keys_response.g.dart';

/// BankPublicKeysResponse
///
/// Properties:
/// * [keys] 
@BuiltValue()
abstract class BankPublicKeysResponse implements Built<BankPublicKeysResponse, BankPublicKeysResponseBuilder> {
  @BuiltValueField(wireName: r'keys')
  BuiltList<BankPublicKey> get keys;

  BankPublicKeysResponse._();

  factory BankPublicKeysResponse([void updates(BankPublicKeysResponseBuilder b)]) = _$BankPublicKeysResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BankPublicKeysResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<BankPublicKeysResponse> get serializer => _$BankPublicKeysResponseSerializer();
}

class _$BankPublicKeysResponseSerializer implements PrimitiveSerializer<BankPublicKeysResponse> {
  @override
  final Iterable<Type> types = const [BankPublicKeysResponse, _$BankPublicKeysResponse];

  @override
  final String wireName = r'BankPublicKeysResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    BankPublicKeysResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'keys';
    yield serializers.serialize(
      object.keys,
      specifiedType: const FullType(BuiltList, [FullType(BankPublicKey)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    BankPublicKeysResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required BankPublicKeysResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'keys':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(BankPublicKey)]),
          ) as BuiltList<BankPublicKey>;
          result.keys.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  BankPublicKeysResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BankPublicKeysResponseBuilder();
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

