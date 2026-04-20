//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'move_to_main_response.g.dart';

/// MoveToMainResponse
///
/// Properties:
/// * [releasedKobo] 
/// * [newMainBalanceKobo] 
@BuiltValue()
abstract class MoveToMainResponse implements Built<MoveToMainResponse, MoveToMainResponseBuilder> {
  @BuiltValueField(wireName: r'released_kobo')
  int get releasedKobo;

  @BuiltValueField(wireName: r'new_main_balance_kobo')
  int get newMainBalanceKobo;

  MoveToMainResponse._();

  factory MoveToMainResponse([void updates(MoveToMainResponseBuilder b)]) = _$MoveToMainResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(MoveToMainResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<MoveToMainResponse> get serializer => _$MoveToMainResponseSerializer();
}

class _$MoveToMainResponseSerializer implements PrimitiveSerializer<MoveToMainResponse> {
  @override
  final Iterable<Type> types = const [MoveToMainResponse, _$MoveToMainResponse];

  @override
  final String wireName = r'MoveToMainResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    MoveToMainResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'released_kobo';
    yield serializers.serialize(
      object.releasedKobo,
      specifiedType: const FullType(int),
    );
    yield r'new_main_balance_kobo';
    yield serializers.serialize(
      object.newMainBalanceKobo,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    MoveToMainResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required MoveToMainResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'released_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.releasedKobo = valueDes;
          break;
        case r'new_main_balance_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.newMainBalanceKobo = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  MoveToMainResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MoveToMainResponseBuilder();
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

