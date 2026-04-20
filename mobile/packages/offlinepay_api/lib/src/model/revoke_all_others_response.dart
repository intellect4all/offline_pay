//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'revoke_all_others_response.g.dart';

/// RevokeAllOthersResponse
///
/// Properties:
/// * [revoked] 
@BuiltValue()
abstract class RevokeAllOthersResponse implements Built<RevokeAllOthersResponse, RevokeAllOthersResponseBuilder> {
  @BuiltValueField(wireName: r'revoked')
  int get revoked;

  RevokeAllOthersResponse._();

  factory RevokeAllOthersResponse([void updates(RevokeAllOthersResponseBuilder b)]) = _$RevokeAllOthersResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RevokeAllOthersResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RevokeAllOthersResponse> get serializer => _$RevokeAllOthersResponseSerializer();
}

class _$RevokeAllOthersResponseSerializer implements PrimitiveSerializer<RevokeAllOthersResponse> {
  @override
  final Iterable<Type> types = const [RevokeAllOthersResponse, _$RevokeAllOthersResponse];

  @override
  final String wireName = r'RevokeAllOthersResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RevokeAllOthersResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'revoked';
    yield serializers.serialize(
      object.revoked,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RevokeAllOthersResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RevokeAllOthersResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'revoked':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.revoked = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RevokeAllOthersResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RevokeAllOthersResponseBuilder();
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

