//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'forgot_password_request_body.g.dart';

/// ForgotPasswordRequestBody
///
/// Properties:
/// * [email] 
@BuiltValue()
abstract class ForgotPasswordRequestBody implements Built<ForgotPasswordRequestBody, ForgotPasswordRequestBodyBuilder> {
  @BuiltValueField(wireName: r'email')
  String get email;

  ForgotPasswordRequestBody._();

  factory ForgotPasswordRequestBody([void updates(ForgotPasswordRequestBodyBuilder b)]) = _$ForgotPasswordRequestBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ForgotPasswordRequestBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ForgotPasswordRequestBody> get serializer => _$ForgotPasswordRequestBodySerializer();
}

class _$ForgotPasswordRequestBodySerializer implements PrimitiveSerializer<ForgotPasswordRequestBody> {
  @override
  final Iterable<Type> types = const [ForgotPasswordRequestBody, _$ForgotPasswordRequestBody];

  @override
  final String wireName = r'ForgotPasswordRequestBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ForgotPasswordRequestBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'email';
    yield serializers.serialize(
      object.email,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ForgotPasswordRequestBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ForgotPasswordRequestBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'email':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.email = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ForgotPasswordRequestBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ForgotPasswordRequestBodyBuilder();
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

