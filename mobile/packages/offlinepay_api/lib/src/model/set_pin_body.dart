//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'set_pin_body.g.dart';

/// SetPinBody
///
/// Properties:
/// * [pin] - 4- or 6-digit transaction PIN.
@BuiltValue()
abstract class SetPinBody implements Built<SetPinBody, SetPinBodyBuilder> {
  /// 4- or 6-digit transaction PIN.
  @BuiltValueField(wireName: r'pin')
  String get pin;

  SetPinBody._();

  factory SetPinBody([void updates(SetPinBodyBuilder b)]) = _$SetPinBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SetPinBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SetPinBody> get serializer => _$SetPinBodySerializer();
}

class _$SetPinBodySerializer implements PrimitiveSerializer<SetPinBody> {
  @override
  final Iterable<Type> types = const [SetPinBody, _$SetPinBody];

  @override
  final String wireName = r'SetPinBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SetPinBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'pin';
    yield serializers.serialize(
      object.pin,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SetPinBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SetPinBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'pin':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.pin = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SetPinBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SetPinBodyBuilder();
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

