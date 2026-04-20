//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'push_token_body.g.dart';

/// PushTokenBody
///
/// Properties:
/// * [fcmToken] 
/// * [platform] 
@BuiltValue()
abstract class PushTokenBody implements Built<PushTokenBody, PushTokenBodyBuilder> {
  @BuiltValueField(wireName: r'fcm_token')
  String get fcmToken;

  @BuiltValueField(wireName: r'platform')
  PushTokenBodyPlatformEnum get platform;
  // enum platformEnum {  android,  ios,  };

  PushTokenBody._();

  factory PushTokenBody([void updates(PushTokenBodyBuilder b)]) = _$PushTokenBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PushTokenBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PushTokenBody> get serializer => _$PushTokenBodySerializer();
}

class _$PushTokenBodySerializer implements PrimitiveSerializer<PushTokenBody> {
  @override
  final Iterable<Type> types = const [PushTokenBody, _$PushTokenBody];

  @override
  final String wireName = r'PushTokenBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PushTokenBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'fcm_token';
    yield serializers.serialize(
      object.fcmToken,
      specifiedType: const FullType(String),
    );
    yield r'platform';
    yield serializers.serialize(
      object.platform,
      specifiedType: const FullType(PushTokenBodyPlatformEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    PushTokenBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PushTokenBodyBuilder result,
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
        case r'platform':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(PushTokenBodyPlatformEnum),
          ) as PushTokenBodyPlatformEnum;
          result.platform = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PushTokenBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PushTokenBodyBuilder();
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

class PushTokenBodyPlatformEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'android')
  static const PushTokenBodyPlatformEnum android = _$pushTokenBodyPlatformEnum_android;
  @BuiltValueEnumConst(wireName: r'ios')
  static const PushTokenBodyPlatformEnum ios = _$pushTokenBodyPlatformEnum_ios;

  static Serializer<PushTokenBodyPlatformEnum> get serializer => _$pushTokenBodyPlatformEnumSerializer;

  const PushTokenBodyPlatformEnum._(String name): super(name);

  static BuiltSet<PushTokenBodyPlatformEnum> get values => _$pushTokenBodyPlatformEnumValues;
  static PushTokenBodyPlatformEnum valueOf(String name) => _$pushTokenBodyPlatformEnumValueOf(name);
}

