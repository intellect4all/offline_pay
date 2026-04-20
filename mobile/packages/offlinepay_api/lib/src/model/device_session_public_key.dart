//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_session_public_key.g.dart';

/// DeviceSessionPublicKey
///
/// Properties:
/// * [keyId] 
/// * [publicKey] 
/// * [activeFrom] 
/// * [retiredAt] 
@BuiltValue()
abstract class DeviceSessionPublicKey implements Built<DeviceSessionPublicKey, DeviceSessionPublicKeyBuilder> {
  @BuiltValueField(wireName: r'key_id')
  String get keyId;

  @BuiltValueField(wireName: r'public_key')
  String get publicKey;

  @BuiltValueField(wireName: r'active_from')
  DateTime get activeFrom;

  @BuiltValueField(wireName: r'retired_at')
  DateTime? get retiredAt;

  DeviceSessionPublicKey._();

  factory DeviceSessionPublicKey([void updates(DeviceSessionPublicKeyBuilder b)]) = _$DeviceSessionPublicKey;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceSessionPublicKeyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceSessionPublicKey> get serializer => _$DeviceSessionPublicKeySerializer();
}

class _$DeviceSessionPublicKeySerializer implements PrimitiveSerializer<DeviceSessionPublicKey> {
  @override
  final Iterable<Type> types = const [DeviceSessionPublicKey, _$DeviceSessionPublicKey];

  @override
  final String wireName = r'DeviceSessionPublicKey';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceSessionPublicKey object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'key_id';
    yield serializers.serialize(
      object.keyId,
      specifiedType: const FullType(String),
    );
    yield r'public_key';
    yield serializers.serialize(
      object.publicKey,
      specifiedType: const FullType(String),
    );
    yield r'active_from';
    yield serializers.serialize(
      object.activeFrom,
      specifiedType: const FullType(DateTime),
    );
    if (object.retiredAt != null) {
      yield r'retired_at';
      yield serializers.serialize(
        object.retiredAt,
        specifiedType: const FullType(DateTime),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceSessionPublicKey object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeviceSessionPublicKeyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'key_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.keyId = valueDes;
          break;
        case r'public_key':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.publicKey = valueDes;
          break;
        case r'active_from':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.activeFrom = valueDes;
          break;
        case r'retired_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.retiredAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeviceSessionPublicKey deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceSessionPublicKeyBuilder();
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

