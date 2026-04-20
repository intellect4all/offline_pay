//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'rotate_device_response.g.dart';

/// RotateDeviceResponse
///
/// Properties:
/// * [newDeviceId] 
/// * [deviceJwt] 
/// * [rotatedAt] 
/// * [realmKeyVersion] 
@BuiltValue()
abstract class RotateDeviceResponse implements Built<RotateDeviceResponse, RotateDeviceResponseBuilder> {
  @BuiltValueField(wireName: r'new_device_id')
  String get newDeviceId;

  @BuiltValueField(wireName: r'device_jwt')
  String get deviceJwt;

  @BuiltValueField(wireName: r'rotated_at')
  DateTime get rotatedAt;

  @BuiltValueField(wireName: r'realm_key_version')
  int get realmKeyVersion;

  RotateDeviceResponse._();

  factory RotateDeviceResponse([void updates(RotateDeviceResponseBuilder b)]) = _$RotateDeviceResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RotateDeviceResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RotateDeviceResponse> get serializer => _$RotateDeviceResponseSerializer();
}

class _$RotateDeviceResponseSerializer implements PrimitiveSerializer<RotateDeviceResponse> {
  @override
  final Iterable<Type> types = const [RotateDeviceResponse, _$RotateDeviceResponse];

  @override
  final String wireName = r'RotateDeviceResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RotateDeviceResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'new_device_id';
    yield serializers.serialize(
      object.newDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'device_jwt';
    yield serializers.serialize(
      object.deviceJwt,
      specifiedType: const FullType(String),
    );
    yield r'rotated_at';
    yield serializers.serialize(
      object.rotatedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'realm_key_version';
    yield serializers.serialize(
      object.realmKeyVersion,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RotateDeviceResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RotateDeviceResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'new_device_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.newDeviceId = valueDes;
          break;
        case r'device_jwt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.deviceJwt = valueDes;
          break;
        case r'rotated_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.rotatedAt = valueDes;
          break;
        case r'realm_key_version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.realmKeyVersion = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RotateDeviceResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RotateDeviceResponseBuilder();
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

