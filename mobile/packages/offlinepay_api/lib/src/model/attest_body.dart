//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attest_body.g.dart';

/// AttestBody
///
/// Properties:
/// * [attestationBlob] 
/// * [nonce] 
@BuiltValue()
abstract class AttestBody implements Built<AttestBody, AttestBodyBuilder> {
  @BuiltValueField(wireName: r'attestation_blob')
  String get attestationBlob;

  @BuiltValueField(wireName: r'nonce')
  String get nonce;

  AttestBody._();

  factory AttestBody([void updates(AttestBodyBuilder b)]) = _$AttestBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttestBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttestBody> get serializer => _$AttestBodySerializer();
}

class _$AttestBodySerializer implements PrimitiveSerializer<AttestBody> {
  @override
  final Iterable<Type> types = const [AttestBody, _$AttestBody];

  @override
  final String wireName = r'AttestBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttestBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'attestation_blob';
    yield serializers.serialize(
      object.attestationBlob,
      specifiedType: const FullType(String),
    );
    yield r'nonce';
    yield serializers.serialize(
      object.nonce,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttestBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AttestBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'attestation_blob':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.attestationBlob = valueDes;
          break;
        case r'nonce':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.nonce = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttestBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttestBodyBuilder();
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

