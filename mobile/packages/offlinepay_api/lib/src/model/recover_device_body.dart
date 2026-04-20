//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'recover_device_body.g.dart';

/// RecoverDeviceBody
///
/// Properties:
/// * [userId] 
/// * [recoveryProof] 
/// * [newDevicePublicKey] 
/// * [platform] 
/// * [attestationBlob] 
/// * [appVersion] 
@BuiltValue()
abstract class RecoverDeviceBody implements Built<RecoverDeviceBody, RecoverDeviceBodyBuilder> {
  @BuiltValueField(wireName: r'user_id')
  String get userId;

  @BuiltValueField(wireName: r'recovery_proof')
  String get recoveryProof;

  @BuiltValueField(wireName: r'new_device_public_key')
  String get newDevicePublicKey;

  @BuiltValueField(wireName: r'platform')
  String get platform;

  @BuiltValueField(wireName: r'attestation_blob')
  String get attestationBlob;

  @BuiltValueField(wireName: r'app_version')
  String get appVersion;

  RecoverDeviceBody._();

  factory RecoverDeviceBody([void updates(RecoverDeviceBodyBuilder b)]) = _$RecoverDeviceBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RecoverDeviceBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RecoverDeviceBody> get serializer => _$RecoverDeviceBodySerializer();
}

class _$RecoverDeviceBodySerializer implements PrimitiveSerializer<RecoverDeviceBody> {
  @override
  final Iterable<Type> types = const [RecoverDeviceBody, _$RecoverDeviceBody];

  @override
  final String wireName = r'RecoverDeviceBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RecoverDeviceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'user_id';
    yield serializers.serialize(
      object.userId,
      specifiedType: const FullType(String),
    );
    yield r'recovery_proof';
    yield serializers.serialize(
      object.recoveryProof,
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
    RecoverDeviceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RecoverDeviceBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'user_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.userId = valueDes;
          break;
        case r'recovery_proof':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.recoveryProof = valueDes;
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
  RecoverDeviceBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RecoverDeviceBodyBuilder();
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

