//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'resolved_account.g.dart';

/// ResolvedAccount
///
/// Properties:
/// * [accountNumber] 
/// * [maskedName] 
@BuiltValue()
abstract class ResolvedAccount implements Built<ResolvedAccount, ResolvedAccountBuilder> {
  @BuiltValueField(wireName: r'account_number')
  String get accountNumber;

  @BuiltValueField(wireName: r'masked_name')
  String get maskedName;

  ResolvedAccount._();

  factory ResolvedAccount([void updates(ResolvedAccountBuilder b)]) = _$ResolvedAccount;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ResolvedAccountBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ResolvedAccount> get serializer => _$ResolvedAccountSerializer();
}

class _$ResolvedAccountSerializer implements PrimitiveSerializer<ResolvedAccount> {
  @override
  final Iterable<Type> types = const [ResolvedAccount, _$ResolvedAccount];

  @override
  final String wireName = r'ResolvedAccount';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ResolvedAccount object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'account_number';
    yield serializers.serialize(
      object.accountNumber,
      specifiedType: const FullType(String),
    );
    yield r'masked_name';
    yield serializers.serialize(
      object.maskedName,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ResolvedAccount object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ResolvedAccountBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'account_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.accountNumber = valueDes;
          break;
        case r'masked_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.maskedName = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ResolvedAccount deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ResolvedAccountBuilder();
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

