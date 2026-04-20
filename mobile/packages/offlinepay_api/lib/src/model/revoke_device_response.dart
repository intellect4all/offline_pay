//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_device_response.g.dart';

/// RevokeDeviceResponse
///
/// Properties:
/// * [revokedAt] 
@BuiltValue()
abstract class RevokeDeviceResponse implements Built<RevokeDeviceResponse, RevokeDeviceResponseBuilder> {
  @BuiltValueField(wireName: r'revoked_at')
  DateTime get revokedAt;

  RevokeDeviceResponse._();

  factory RevokeDeviceResponse([void updates(RevokeDeviceResponseBuilder b)]) = _$RevokeDeviceResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeDeviceResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeDeviceResponse> get serializer => _$RevokeDeviceResponseSerializer();
}

class _$RevokeDeviceResponseSerializer implements PrimitiveSerializer<RevokeDeviceResponse> {
  @override
  final Iterable<Type> types = const [RevokeDeviceResponse, _$RevokeDeviceResponse];

  @override
  final String wireName = r'RevokeDeviceResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeDeviceResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'revoked_at';
    yield serializers.serialize(
      object.revokedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RevokeDeviceResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RevokeDeviceResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'revoked_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.revokedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RevokeDeviceResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeDeviceResponseBuilder();
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

