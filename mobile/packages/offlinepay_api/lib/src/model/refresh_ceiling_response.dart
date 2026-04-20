//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:offlinepay_api/src/model/ceiling_token.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'refresh_ceiling_response.g.dart';

/// RefreshCeilingResponse
///
/// Properties:
/// * [ceiling] 
/// * [lienId] 
@BuiltValue()
abstract class RefreshCeilingResponse implements Built<RefreshCeilingResponse, RefreshCeilingResponseBuilder> {
  @BuiltValueField(wireName: r'ceiling')
  CeilingToken get ceiling;

  @BuiltValueField(wireName: r'lien_id')
  String get lienId;

  RefreshCeilingResponse._();

  factory RefreshCeilingResponse([void updates(RefreshCeilingResponseBuilder b)]) = _$RefreshCeilingResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RefreshCeilingResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RefreshCeilingResponse> get serializer => _$RefreshCeilingResponseSerializer();
}

class _$RefreshCeilingResponseSerializer implements PrimitiveSerializer<RefreshCeilingResponse> {
  @override
  final Iterable<Type> types = const [RefreshCeilingResponse, _$RefreshCeilingResponse];

  @override
  final String wireName = r'RefreshCeilingResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RefreshCeilingResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'ceiling';
    yield serializers.serialize(
      object.ceiling,
      specifiedType: const FullType(CeilingToken),
    );
    yield r'lien_id';
    yield serializers.serialize(
      object.lienId,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RefreshCeilingResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RefreshCeilingResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'ceiling':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(CeilingToken),
          ) as CeilingToken;
          result.ceiling.replace(valueDes);
          break;
        case r'lien_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.lienId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RefreshCeilingResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RefreshCeilingResponseBuilder();
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

