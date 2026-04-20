//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'bank_public_key.g.dart';

/// BankPublicKey
///
/// Properties:
/// * [keyId] 
/// * [publicKey] 
/// * [activeFrom] 
/// * [retiredAt] 
@BuiltValue()
abstract class BankPublicKey implements Built<BankPublicKey, BankPublicKeyBuilder> {
  @BuiltValueField(wireName: r'key_id')
  String get keyId;

  @BuiltValueField(wireName: r'public_key')
  String get publicKey;

  @BuiltValueField(wireName: r'active_from')
  DateTime get activeFrom;

  @BuiltValueField(wireName: r'retired_at')
  DateTime? get retiredAt;

  BankPublicKey._();

  factory BankPublicKey([void updates(BankPublicKeyBuilder b)]) = _$BankPublicKey;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BankPublicKeyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<BankPublicKey> get serializer => _$BankPublicKeySerializer();
}

class _$BankPublicKeySerializer implements PrimitiveSerializer<BankPublicKey> {
  @override
  final Iterable<Type> types = const [BankPublicKey, _$BankPublicKey];

  @override
  final String wireName = r'BankPublicKey';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    BankPublicKey object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'key_id';
    yield serializers.serialize(
      object.keyId,
      specifiedType: const FullType(String),
    );
    yield r'public_key';
    yield serializers.serialize(
      object.publicKey,
      specifiedType: const FullType(String),
    );
    yield r'active_from';
    yield serializers.serialize(
      object.activeFrom,
      specifiedType: const FullType(DateTime),
    );
    if (object.retiredAt != null) {
      yield r'retired_at';
      yield serializers.serialize(
        object.retiredAt,
        specifiedType: const FullType(DateTime),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    BankPublicKey object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required BankPublicKeyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'key_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.keyId = valueDes;
          break;
        case r'public_key':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.publicKey = valueDes;
          break;
        case r'active_from':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.activeFrom = valueDes;
          break;
        case r'retired_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.retiredAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  BankPublicKey deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BankPublicKeyBuilder();
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

