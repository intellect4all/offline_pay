//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'top_up_body.g.dart';

/// TopUpBody
///
/// Properties:
/// * [amountKobo] - Amount to credit in kobo (1-10000000, i.e. max 100k naira).
@BuiltValue()
abstract class TopUpBody implements Built<TopUpBody, TopUpBodyBuilder> {
  /// Amount to credit in kobo (1-10000000, i.e. max 100k naira).
  @BuiltValueField(wireName: r'amount_kobo')
  int get amountKobo;

  TopUpBody._();

  factory TopUpBody([void updates(TopUpBodyBuilder b)]) = _$TopUpBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TopUpBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TopUpBody> get serializer => _$TopUpBodySerializer();
}

class _$TopUpBodySerializer implements PrimitiveSerializer<TopUpBody> {
  @override
  final Iterable<Type> types = const [TopUpBody, _$TopUpBody];

  @override
  final String wireName = r'TopUpBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TopUpBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'amount_kobo';
    yield serializers.serialize(
      object.amountKobo,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    TopUpBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TopUpBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.amountKobo = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TopUpBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TopUpBodyBuilder();
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

