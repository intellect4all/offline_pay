//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:offlinepay_api/src/model/account_balance.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_balances_response.g.dart';

/// GetBalancesResponse
///
/// Properties:
/// * [balances] 
/// * [asOf] 
@BuiltValue()
abstract class GetBalancesResponse implements Built<GetBalancesResponse, GetBalancesResponseBuilder> {
  @BuiltValueField(wireName: r'balances')
  BuiltList<AccountBalance> get balances;

  @BuiltValueField(wireName: r'as_of')
  DateTime get asOf;

  GetBalancesResponse._();

  factory GetBalancesResponse([void updates(GetBalancesResponseBuilder b)]) = _$GetBalancesResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetBalancesResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetBalancesResponse> get serializer => _$GetBalancesResponseSerializer();
}

class _$GetBalancesResponseSerializer implements PrimitiveSerializer<GetBalancesResponse> {
  @override
  final Iterable<Type> types = const [GetBalancesResponse, _$GetBalancesResponse];

  @override
  final String wireName = r'GetBalancesResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetBalancesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'balances';
    yield serializers.serialize(
      object.balances,
      specifiedType: const FullType(BuiltList, [FullType(AccountBalance)]),
    );
    yield r'as_of';
    yield serializers.serialize(
      object.asOf,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetBalancesResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GetBalancesResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'balances':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(AccountBalance)]),
          ) as BuiltList<AccountBalance>;
          result.balances.replace(valueDes);
          break;
        case r'as_of':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.asOf = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GetBalancesResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetBalancesResponseBuilder();
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

