//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'deactivate_device_body.g.dart';

/// DeactivateDeviceBody
///
/// Properties:
/// * [reason] 
@BuiltValue()
abstract class DeactivateDeviceBody implements Built<DeactivateDeviceBody, DeactivateDeviceBodyBuilder> {
  @BuiltValueField(wireName: r'reason')
  String get reason;

  DeactivateDeviceBody._();

  factory DeactivateDeviceBody([void updates(DeactivateDeviceBodyBuilder b)]) = _$DeactivateDeviceBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DeactivateDeviceBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DeactivateDeviceBody> get serializer => _$DeactivateDeviceBodySerializer();
}

class _$DeactivateDeviceBodySerializer implements PrimitiveSerializer<DeactivateDeviceBody> {
  @override
  final Iterable<Type> types = const [DeactivateDeviceBody, _$DeactivateDeviceBody];

  @override
  final String wireName = r'DeactivateDeviceBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DeactivateDeviceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'reason';
    yield serializers.serialize(
      object.reason,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DeactivateDeviceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DeactivateDeviceBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'reason':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.reason = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DeactivateDeviceBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DeactivateDeviceBodyBuilder();
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

