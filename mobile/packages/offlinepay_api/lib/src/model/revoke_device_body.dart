//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_device_body.g.dart';

/// RevokeDeviceBody
///
/// Properties:
/// * [reason] 
@BuiltValue()
abstract class RevokeDeviceBody implements Built<RevokeDeviceBody, RevokeDeviceBodyBuilder> {
  @BuiltValueField(wireName: r'reason')
  String get reason;

  RevokeDeviceBody._();

  factory RevokeDeviceBody([void updates(RevokeDeviceBodyBuilder b)]) = _$RevokeDeviceBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeDeviceBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeDeviceBody> get serializer => _$RevokeDeviceBodySerializer();
}

class _$RevokeDeviceBodySerializer implements PrimitiveSerializer<RevokeDeviceBody> {
  @override
  final Iterable<Type> types = const [RevokeDeviceBody, _$RevokeDeviceBody];

  @override
  final String wireName = r'RevokeDeviceBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeDeviceBody object, {
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
    RevokeDeviceBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RevokeDeviceBodyBuilder result,
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
  RevokeDeviceBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeDeviceBodyBuilder();
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

