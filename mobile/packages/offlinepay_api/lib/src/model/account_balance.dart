//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'account_balance.g.dart';

/// AccountBalance
///
/// Properties:
/// * [kind] 
/// * [balanceKobo] 
/// * [currency] 
/// * [updatedAt] 
@BuiltValue()
abstract class AccountBalance implements Built<AccountBalance, AccountBalanceBuilder> {
  @BuiltValueField(wireName: r'kind')
  AccountBalanceKindEnum get kind;
  // enum kindEnum {  ACCOUNT_KIND_UNSPECIFIED,  ACCOUNT_KIND_MAIN,  ACCOUNT_KIND_OFFLINE,  ACCOUNT_KIND_LIEN_HOLDING,  ACCOUNT_KIND_RECEIVING_PENDING,  };

  @BuiltValueField(wireName: r'balance_kobo')
  int get balanceKobo;

  @BuiltValueField(wireName: r'currency')
  String get currency;

  @BuiltValueField(wireName: r'updated_at')
  DateTime get updatedAt;

  AccountBalance._();

  factory AccountBalance([void updates(AccountBalanceBuilder b)]) = _$AccountBalance;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AccountBalanceBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AccountBalance> get serializer => _$AccountBalanceSerializer();
}

class _$AccountBalanceSerializer implements PrimitiveSerializer<AccountBalance> {
  @override
  final Iterable<Type> types = const [AccountBalance, _$AccountBalance];

  @override
  final String wireName = r'AccountBalance';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AccountBalance object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(AccountBalanceKindEnum),
    );
    yield r'balance_kobo';
    yield serializers.serialize(
      object.balanceKobo,
      specifiedType: const FullType(int),
    );
    yield r'currency';
    yield serializers.serialize(
      object.currency,
      specifiedType: const FullType(String),
    );
    yield r'updated_at';
    yield serializers.serialize(
      object.updatedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    AccountBalance object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AccountBalanceBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AccountBalanceKindEnum),
          ) as AccountBalanceKindEnum;
          result.kind = valueDes;
          break;
        case r'balance_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.balanceKobo = valueDes;
          break;
        case r'currency':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.currency = valueDes;
          break;
        case r'updated_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.updatedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AccountBalance deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AccountBalanceBuilder();
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

class AccountBalanceKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'ACCOUNT_KIND_UNSPECIFIED')
  static const AccountBalanceKindEnum ACCOUNT_KIND_UNSPECIFIED = _$accountBalanceKindEnum_ACCOUNT_KIND_UNSPECIFIED;
  @BuiltValueEnumConst(wireName: r'ACCOUNT_KIND_MAIN')
  static const AccountBalanceKindEnum ACCOUNT_KIND_MAIN = _$accountBalanceKindEnum_ACCOUNT_KIND_MAIN;
  @BuiltValueEnumConst(wireName: r'ACCOUNT_KIND_OFFLINE')
  static const AccountBalanceKindEnum ACCOUNT_KIND_OFFLINE = _$accountBalanceKindEnum_ACCOUNT_KIND_OFFLINE;
  @BuiltValueEnumConst(wireName: r'ACCOUNT_KIND_LIEN_HOLDING')
  static const AccountBalanceKindEnum ACCOUNT_KIND_LIEN_HOLDING = _$accountBalanceKindEnum_ACCOUNT_KIND_LIEN_HOLDING;
  @BuiltValueEnumConst(wireName: r'ACCOUNT_KIND_RECEIVING_PENDING')
  static const AccountBalanceKindEnum ACCOUNT_KIND_RECEIVING_PENDING = _$accountBalanceKindEnum_ACCOUNT_KIND_RECEIVING_PENDING;

  static Serializer<AccountBalanceKindEnum> get serializer => _$accountBalanceKindEnumSerializer;

  const AccountBalanceKindEnum._(String name): super(name);

  static BuiltSet<AccountBalanceKindEnum> get values => _$accountBalanceKindEnumValues;
  static AccountBalanceKindEnum valueOf(String name) => _$accountBalanceKindEnumValueOf(name);
}

