//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:offlinepay_api/src/model/device_session_public_key.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_session_public_keys.g.dart';

/// DeviceSessionPublicKeys
///
/// Properties:
/// * [keys] 
@BuiltValue()
abstract class DeviceSessionPublicKeys implements Built<DeviceSessionPublicKeys, DeviceSessionPublicKeysBuilder> {
  @BuiltValueField(wireName: r'keys')
  BuiltList<DeviceSessionPublicKey> get keys;

  DeviceSessionPublicKeys._();

  factory DeviceSessionPublicKeys([void updates(DeviceSessionPublicKeysBuilder b)]) = _$DeviceSessionPublicKeys;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceSessionPublicKeysBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceSessionPublicKeys> get serializer => _$DeviceSessionPublicKeysSerializer();
}

class _$DeviceSessionPublicKeysSerializer implements PrimitiveSerializer<DeviceSessionPublicKeys> {
  @override
  final Iterable<Type> types = const [DeviceSessionPublicKeys, _$DeviceSessionPublicKeys];

  @override
  final String wireName = r'DeviceSessionPublicKeys';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceSessionPublicKeys object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'keys';
    yield serializers.serialize(
      object.keys,
      specifiedType: const FullType(BuiltList, [FullType(DeviceSessionPublicKey)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceSessionPublicKeys object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeviceSessionPublicKeysBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'keys':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(DeviceSessionPublicKey)]),
          ) as BuiltList<DeviceSessionPublicKey>;
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
  DeviceSessionPublicKeys deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceSessionPublicKeysBuilder();
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

