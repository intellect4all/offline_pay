//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'attestation_challenge_response.g.dart';

/// AttestationChallengeResponse
///
/// Properties:
/// * [nonce] 
/// * [expiresAt] 
@BuiltValue()
abstract class AttestationChallengeResponse implements Built<AttestationChallengeResponse, AttestationChallengeResponseBuilder> {
  @BuiltValueField(wireName: r'nonce')
  String get nonce;

  @BuiltValueField(wireName: r'expires_at')
  DateTime get expiresAt;

  AttestationChallengeResponse._();

  factory AttestationChallengeResponse([void updates(AttestationChallengeResponseBuilder b)]) = _$AttestationChallengeResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AttestationChallengeResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AttestationChallengeResponse> get serializer => _$AttestationChallengeResponseSerializer();
}

class _$AttestationChallengeResponseSerializer implements PrimitiveSerializer<AttestationChallengeResponse> {
  @override
  final Iterable<Type> types = const [AttestationChallengeResponse, _$AttestationChallengeResponse];

  @override
  final String wireName = r'AttestationChallengeResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AttestationChallengeResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'nonce';
    yield serializers.serialize(
      object.nonce,
      specifiedType: const FullType(String),
    );
    yield r'expires_at';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AttestationChallengeResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AttestationChallengeResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'nonce':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.nonce = valueDes;
          break;
        case r'expires_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.expiresAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AttestationChallengeResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AttestationChallengeResponseBuilder();
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

