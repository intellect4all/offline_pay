//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_session_request.g.dart';

/// DeviceSessionRequest
///
/// Properties:
/// * [deviceId] - Caller's registered device identifier (returned by `POST /v1/devices`). Must be active and owned by the authenticated user, otherwise the server returns 403. 
/// * [scope] - Capability scope this token grants on-device. Defaults to `offline_pay`. Reserved for future tiers; unknown scopes 400. 
@BuiltValue()
abstract class DeviceSessionRequest implements Built<DeviceSessionRequest, DeviceSessionRequestBuilder> {
  /// Caller's registered device identifier (returned by `POST /v1/devices`). Must be active and owned by the authenticated user, otherwise the server returns 403. 
  @BuiltValueField(wireName: r'device_id')
  String get deviceId;

  /// Capability scope this token grants on-device. Defaults to `offline_pay`. Reserved for future tiers; unknown scopes 400. 
  @BuiltValueField(wireName: r'scope')
  DeviceSessionRequestScopeEnum? get scope;
  // enum scopeEnum {  offline_pay,  };

  DeviceSessionRequest._();

  factory DeviceSessionRequest([void updates(DeviceSessionRequestBuilder b)]) = _$DeviceSessionRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceSessionRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceSessionRequest> get serializer => _$DeviceSessionRequestSerializer();
}

class _$DeviceSessionRequestSerializer implements PrimitiveSerializer<DeviceSessionRequest> {
  @override
  final Iterable<Type> types = const [DeviceSessionRequest, _$DeviceSessionRequest];

  @override
  final String wireName = r'DeviceSessionRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceSessionRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'device_id';
    yield serializers.serialize(
      object.deviceId,
      specifiedType: const FullType(String),
    );
    if (object.scope != null) {
      yield r'scope';
      yield serializers.serialize(
        object.scope,
        specifiedType: const FullType(DeviceSessionRequestScopeEnum),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceSessionRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeviceSessionRequestBuilder result,
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
        case r'scope':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DeviceSessionRequestScopeEnum),
          ) as DeviceSessionRequestScopeEnum;
          result.scope = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeviceSessionRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceSessionRequestBuilder();
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

class DeviceSessionRequestScopeEnum extends EnumClass {

  /// Capability scope this token grants on-device. Defaults to `offline_pay`. Reserved for future tiers; unknown scopes 400. 
  @BuiltValueEnumConst(wireName: r'offline_pay')
  static const DeviceSessionRequestScopeEnum offlinePay = _$deviceSessionRequestScopeEnum_offlinePay;

  static Serializer<DeviceSessionRequestScopeEnum> get serializer => _$deviceSessionRequestScopeEnumSerializer;

  const DeviceSessionRequestScopeEnum._(String name): super(name);

  static BuiltSet<DeviceSessionRequestScopeEnum> get values => _$deviceSessionRequestScopeEnumValues;
  static DeviceSessionRequestScopeEnum valueOf(String name) => _$deviceSessionRequestScopeEnumValueOf(name);
}

