//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'register_device_body.g.dart';

/// RegisterDeviceBody
///
/// Properties:
/// * [devicePublicKey] 
/// * [platform] 
/// * [attestationBlob] 
/// * [appVersion] 
/// * [attestationNonce] 
@BuiltValue()
abstract class RegisterDeviceBody implements Built<RegisterDeviceBody, RegisterDeviceBodyBuilder> {
  @BuiltValueField(wireName: r'device_public_key')
  String get devicePublicKey;

  @BuiltValueField(wireName: r'platform')
  String get platform;

  @BuiltValueField(wireName: r'attestation_blob')
  String get attestationBlob;

  @BuiltValueField(wireName: r'app_version')
  String get appVersion;

  @BuiltValueField(wireName: r'attestation_nonce')
  String get attestationNonce;

  RegisterDeviceBody._();

  factory RegisterDeviceBody([void updates(RegisterDeviceBodyBuilder b)]) = _$RegisterDeviceBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RegisterDeviceBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RegisterDeviceBody> get serializer => _$RegisterDeviceBodySerializer();
}

class _$RegisterDeviceBodySerializer implements PrimitiveSerializer<RegisterDeviceBody> {
  @override
  final Iterable<Type> types = const [RegisterDeviceBody, _$RegisterDeviceBody];

  @override
  final String wireName = r'RegisterDeviceBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RegisterDeviceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'device_public_key';
    yield serializers.serialize(
      object.devicePublicKey,
      specifiedType: const FullType(String),
    );
    yield r'platform';
    yield serializers.serialize(
      object.platform,
      specifiedType: const FullType(String),
    );
    yield r'attestation_blob';
    yield serializers.serialize(
      object.attestationBlob,
      specifiedType: const FullType(String),
    );
    yield r'app_version';
    yield serializers.serialize(
      object.appVersion,
      specifiedType: const FullType(String),
    );
    yield r'attestation_nonce';
    yield serializers.serialize(
      object.attestationNonce,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RegisterDeviceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RegisterDeviceBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'device_public_key':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.devicePublicKey = valueDes;
          break;
        case r'platform':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.platform = valueDes;
          break;
        case r'attestation_blob':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.attestationBlob = valueDes;
          break;
        case r'app_version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.appVersion = valueDes;
          break;
        case r'attestation_nonce':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.attestationNonce = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RegisterDeviceBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RegisterDeviceBodyBuilder();
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

