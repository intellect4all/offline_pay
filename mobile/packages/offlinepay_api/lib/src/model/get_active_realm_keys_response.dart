//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:offlinepay_api/src/model/realm_key.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_active_realm_keys_response.g.dart';

/// GetActiveRealmKeysResponse
///
/// Properties:
/// * [keys] 
@BuiltValue()
abstract class GetActiveRealmKeysResponse implements Built<GetActiveRealmKeysResponse, GetActiveRealmKeysResponseBuilder> {
  @BuiltValueField(wireName: r'keys')
  BuiltList<RealmKey> get keys;

  GetActiveRealmKeysResponse._();

  factory GetActiveRealmKeysResponse([void updates(GetActiveRealmKeysResponseBuilder b)]) = _$GetActiveRealmKeysResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetActiveRealmKeysResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetActiveRealmKeysResponse> get serializer => _$GetActiveRealmKeysResponseSerializer();
}

class _$GetActiveRealmKeysResponseSerializer implements PrimitiveSerializer<GetActiveRealmKeysResponse> {
  @override
  final Iterable<Type> types = const [GetActiveRealmKeysResponse, _$GetActiveRealmKeysResponse];

  @override
  final String wireName = r'GetActiveRealmKeysResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetActiveRealmKeysResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'keys';
    yield serializers.serialize(
      object.keys,
      specifiedType: const FullType(BuiltList, [FullType(RealmKey)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetActiveRealmKeysResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GetActiveRealmKeysResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'keys':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(RealmKey)]),
          ) as BuiltList<RealmKey>;
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
  GetActiveRealmKeysResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetActiveRealmKeysResponseBuilder();
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

