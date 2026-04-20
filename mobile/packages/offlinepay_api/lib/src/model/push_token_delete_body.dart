//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'push_token_delete_body.g.dart';

/// PushTokenDeleteBody
///
/// Properties:
/// * [fcmToken] 
@BuiltValue()
abstract class PushTokenDeleteBody implements Built<PushTokenDeleteBody, PushTokenDeleteBodyBuilder> {
  @BuiltValueField(wireName: r'fcm_token')
  String get fcmToken;

  PushTokenDeleteBody._();

  factory PushTokenDeleteBody([void updates(PushTokenDeleteBodyBuilder b)]) = _$PushTokenDeleteBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PushTokenDeleteBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PushTokenDeleteBody> get serializer => _$PushTokenDeleteBodySerializer();
}

class _$PushTokenDeleteBodySerializer implements PrimitiveSerializer<PushTokenDeleteBody> {
  @override
  final Iterable<Type> types = const [PushTokenDeleteBody, _$PushTokenDeleteBody];

  @override
  final String wireName = r'PushTokenDeleteBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PushTokenDeleteBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'fcm_token';
    yield serializers.serialize(
      object.fcmToken,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PushTokenDeleteBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PushTokenDeleteBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'fcm_token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.fcmToken = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PushTokenDeleteBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PushTokenDeleteBodyBuilder();
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

