//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'logout_body.g.dart';

/// LogoutBody
///
/// Properties:
/// * [refreshToken] 
@BuiltValue()
abstract class LogoutBody implements Built<LogoutBody, LogoutBodyBuilder> {
  @BuiltValueField(wireName: r'refresh_token')
  String get refreshToken;

  LogoutBody._();

  factory LogoutBody([void updates(LogoutBodyBuilder b)]) = _$LogoutBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LogoutBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<LogoutBody> get serializer => _$LogoutBodySerializer();
}

class _$LogoutBodySerializer implements PrimitiveSerializer<LogoutBody> {
  @override
  final Iterable<Type> types = const [LogoutBody, _$LogoutBody];

  @override
  final String wireName = r'LogoutBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LogoutBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'refresh_token';
    yield serializers.serialize(
      object.refreshToken,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    LogoutBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required LogoutBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'refresh_token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.refreshToken = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  LogoutBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LogoutBodyBuilder();
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

