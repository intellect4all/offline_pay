//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'device_session_response.g.dart';

/// DeviceSessionResponse
///
/// Properties:
/// * [token] - Compact base64url-encoded `header.claims.signature` blob signed with Ed25519. The device verifies it locally against `server_public_key`. 
/// * [serverPublicKey] - 32-byte Ed25519 public key the device should cache.
/// * [keyId] - Identifier of the signing key (for rotation).
/// * [issuedAt] 
/// * [expiresAt] 
/// * [scope] 
@BuiltValue()
abstract class DeviceSessionResponse implements Built<DeviceSessionResponse, DeviceSessionResponseBuilder> {
  /// Compact base64url-encoded `header.claims.signature` blob signed with Ed25519. The device verifies it locally against `server_public_key`. 
  @BuiltValueField(wireName: r'token')
  String get token;

  /// 32-byte Ed25519 public key the device should cache.
  @BuiltValueField(wireName: r'server_public_key')
  String get serverPublicKey;

  /// Identifier of the signing key (for rotation).
  @BuiltValueField(wireName: r'key_id')
  String get keyId;

  @BuiltValueField(wireName: r'issued_at')
  DateTime get issuedAt;

  @BuiltValueField(wireName: r'expires_at')
  DateTime get expiresAt;

  @BuiltValueField(wireName: r'scope')
  DeviceSessionResponseScopeEnum get scope;
  // enum scopeEnum {  offline_pay,  };

  DeviceSessionResponse._();

  factory DeviceSessionResponse([void updates(DeviceSessionResponseBuilder b)]) = _$DeviceSessionResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeviceSessionResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeviceSessionResponse> get serializer => _$DeviceSessionResponseSerializer();
}

class _$DeviceSessionResponseSerializer implements PrimitiveSerializer<DeviceSessionResponse> {
  @override
  final Iterable<Type> types = const [DeviceSessionResponse, _$DeviceSessionResponse];

  @override
  final String wireName = r'DeviceSessionResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeviceSessionResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'token';
    yield serializers.serialize(
      object.token,
      specifiedType: const FullType(String),
    );
    yield r'server_public_key';
    yield serializers.serialize(
      object.serverPublicKey,
      specifiedType: const FullType(String),
    );
    yield r'key_id';
    yield serializers.serialize(
      object.keyId,
      specifiedType: const FullType(String),
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
    yield r'scope';
    yield serializers.serialize(
      object.scope,
      specifiedType: const FullType(DeviceSessionResponseScopeEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeviceSessionResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeviceSessionResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.token = valueDes;
          break;
        case r'server_public_key':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.serverPublicKey = valueDes;
          break;
        case r'key_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.keyId = valueDes;
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
        case r'scope':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DeviceSessionResponseScopeEnum),
          ) as DeviceSessionResponseScopeEnum;
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
  DeviceSessionResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeviceSessionResponseBuilder();
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

class DeviceSessionResponseScopeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'offline_pay')
  static const DeviceSessionResponseScopeEnum offlinePay = _$deviceSessionResponseScopeEnum_offlinePay;

  static Serializer<DeviceSessionResponseScopeEnum> get serializer => _$deviceSessionResponseScopeEnumSerializer;

  const DeviceSessionResponseScopeEnum._(String name): super(name);

  static BuiltSet<DeviceSessionResponseScopeEnum> get values => _$deviceSessionResponseScopeEnumValues;
  static DeviceSessionResponseScopeEnum valueOf(String name) => _$deviceSessionResponseScopeEnumValueOf(name);
}

