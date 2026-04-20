//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'rotate_device_body.g.dart';

/// RotateDeviceBody
///
/// Properties:
/// * [oldDeviceId] 
/// * [newDevicePublicKey] 
/// * [platform] 
/// * [attestationBlob] 
/// * [appVersion] 
@BuiltValue()
abstract class RotateDeviceBody implements Built<RotateDeviceBody, RotateDeviceBodyBuilder> {
  @BuiltValueField(wireName: r'old_device_id')
  String get oldDeviceId;

  @BuiltValueField(wireName: r'new_device_public_key')
  String get newDevicePublicKey;

  @BuiltValueField(wireName: r'platform')
  String get platform;

  @BuiltValueField(wireName: r'attestation_blob')
  String get attestationBlob;

  @BuiltValueField(wireName: r'app_version')
  String get appVersion;

  RotateDeviceBody._();

  factory RotateDeviceBody([void updates(RotateDeviceBodyBuilder b)]) = _$RotateDeviceBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RotateDeviceBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RotateDeviceBody> get serializer => _$RotateDeviceBodySerializer();
}

class _$RotateDeviceBodySerializer implements PrimitiveSerializer<RotateDeviceBody> {
  @override
  final Iterable<Type> types = const [RotateDeviceBody, _$RotateDeviceBody];

  @override
  final String wireName = r'RotateDeviceBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RotateDeviceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'old_device_id';
    yield serializers.serialize(
      object.oldDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'new_device_public_key';
    yield serializers.serialize(
      object.newDevicePublicKey,
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
  }

  @override
  Object serialize(
    Serializers serializers,
    RotateDeviceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RotateDeviceBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'old_device_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.oldDeviceId = valueDes;
          break;
        case r'new_device_public_key':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.newDevicePublicKey = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RotateDeviceBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RotateDeviceBodyBuilder();
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

