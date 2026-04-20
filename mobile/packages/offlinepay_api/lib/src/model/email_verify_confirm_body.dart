//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'email_verify_confirm_body.g.dart';

/// EmailVerifyConfirmBody
///
/// Properties:
/// * [code] 
@BuiltValue()
abstract class EmailVerifyConfirmBody implements Built<EmailVerifyConfirmBody, EmailVerifyConfirmBodyBuilder> {
  @BuiltValueField(wireName: r'code')
  String get code;

  EmailVerifyConfirmBody._();

  factory EmailVerifyConfirmBody([void updates(EmailVerifyConfirmBodyBuilder b)]) = _$EmailVerifyConfirmBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(EmailVerifyConfirmBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<EmailVerifyConfirmBody> get serializer => _$EmailVerifyConfirmBodySerializer();
}

class _$EmailVerifyConfirmBodySerializer implements PrimitiveSerializer<EmailVerifyConfirmBody> {
  @override
  final Iterable<Type> types = const [EmailVerifyConfirmBody, _$EmailVerifyConfirmBody];

  @override
  final String wireName = r'EmailVerifyConfirmBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    EmailVerifyConfirmBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'code';
    yield serializers.serialize(
      object.code,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    EmailVerifyConfirmBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required EmailVerifyConfirmBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'code':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.code = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  EmailVerifyConfirmBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EmailVerifyConfirmBodyBuilder();
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

