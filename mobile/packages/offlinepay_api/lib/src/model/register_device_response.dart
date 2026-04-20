//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'register_device_response.g.dart';

/// RegisterDeviceResponse
///
/// Properties:
/// * [deviceId] 
/// * [deviceJwt] 
/// * [registeredAt] 
/// * [realmKeyVersion] 
@BuiltValue()
abstract class RegisterDeviceResponse implements Built<RegisterDeviceResponse, RegisterDeviceResponseBuilder> {
  @BuiltValueField(wireName: r'device_id')
  String get deviceId;

  @BuiltValueField(wireName: r'device_jwt')
  String get deviceJwt;

  @BuiltValueField(wireName: r'registered_at')
  DateTime get registeredAt;

  @BuiltValueField(wireName: r'realm_key_version')
  int get realmKeyVersion;

  RegisterDeviceResponse._();

  factory RegisterDeviceResponse([void updates(RegisterDeviceResponseBuilder b)]) = _$RegisterDeviceResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RegisterDeviceResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RegisterDeviceResponse> get serializer => _$RegisterDeviceResponseSerializer();
}

class _$RegisterDeviceResponseSerializer implements PrimitiveSerializer<RegisterDeviceResponse> {
  @override
  final Iterable<Type> types = const [RegisterDeviceResponse, _$RegisterDeviceResponse];

  @override
  final String wireName = r'RegisterDeviceResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RegisterDeviceResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'device_id';
    yield serializers.serialize(
      object.deviceId,
      specifiedType: const FullType(String),
    );
    yield r'device_jwt';
    yield serializers.serialize(
      object.deviceJwt,
      specifiedType: const FullType(String),
    );
    yield r'registered_at';
    yield serializers.serialize(
      object.registeredAt,
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
    RegisterDeviceResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RegisterDeviceResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'device_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.deviceId = valueDes;
          break;
        case r'device_jwt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.deviceJwt = valueDes;
          break;
        case r'registered_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.registeredAt = valueDes;
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
  RegisterDeviceResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RegisterDeviceResponseBuilder();
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

