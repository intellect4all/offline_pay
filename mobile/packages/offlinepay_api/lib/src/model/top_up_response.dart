//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'top_up_response.g.dart';

/// TopUpResponse
///
/// Properties:
/// * [newBalanceKobo] - Updated main wallet balance in kobo.
@BuiltValue()
abstract class TopUpResponse implements Built<TopUpResponse, TopUpResponseBuilder> {
  /// Updated main wallet balance in kobo.
  @BuiltValueField(wireName: r'new_balance_kobo')
  int get newBalanceKobo;

  TopUpResponse._();

  factory TopUpResponse([void updates(TopUpResponseBuilder b)]) = _$TopUpResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TopUpResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TopUpResponse> get serializer => _$TopUpResponseSerializer();
}

class _$TopUpResponseSerializer implements PrimitiveSerializer<TopUpResponse> {
  @override
  final Iterable<Type> types = const [TopUpResponse, _$TopUpResponse];

  @override
  final String wireName = r'TopUpResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TopUpResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'new_balance_kobo';
    yield serializers.serialize(
      object.newBalanceKobo,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TopUpResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TopUpResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'new_balance_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.newBalanceKobo = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TopUpResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TopUpResponseBuilder();
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

