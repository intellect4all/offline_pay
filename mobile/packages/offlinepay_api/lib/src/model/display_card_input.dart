//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'display_card_input.g.dart';

/// Server-issued identity credential. The receiver embeds this in every PaymentRequest they publish; the payer verifies the server signature against the cached bank public key to confirm display_name really belongs to user_id. 
///
/// Properties:
/// * [userId] 
/// * [displayName] 
/// * [accountNumber] 
/// * [issuedAt] 
/// * [bankKeyId] 
/// * [serverSignature] 
@BuiltValue()
abstract class DisplayCardInput implements Built<DisplayCardInput, DisplayCardInputBuilder> {
  @BuiltValueField(wireName: r'user_id')
  String get userId;

  @BuiltValueField(wireName: r'display_name')
  String get displayName;

  @BuiltValueField(wireName: r'account_number')
  String get accountNumber;

  @BuiltValueField(wireName: r'issued_at')
  DateTime get issuedAt;

  @BuiltValueField(wireName: r'bank_key_id')
  String get bankKeyId;

  @BuiltValueField(wireName: r'server_signature')
  String get serverSignature;

  DisplayCardInput._();

  factory DisplayCardInput([void updates(DisplayCardInputBuilder b)]) = _$DisplayCardInput;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DisplayCardInputBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DisplayCardInput> get serializer => _$DisplayCardInputSerializer();
}

class _$DisplayCardInputSerializer implements PrimitiveSerializer<DisplayCardInput> {
  @override
  final Iterable<Type> types = const [DisplayCardInput, _$DisplayCardInput];

  @override
  final String wireName = r'DisplayCardInput';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DisplayCardInput object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'user_id';
    yield serializers.serialize(
      object.userId,
      specifiedType: const FullType(String),
    );
    yield r'display_name';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'account_number';
    yield serializers.serialize(
      object.accountNumber,
      specifiedType: const FullType(String),
    );
    yield r'issued_at';
    yield serializers.serialize(
      object.issuedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'bank_key_id';
    yield serializers.serialize(
      object.bankKeyId,
      specifiedType: const FullType(String),
    );
    yield r'server_signature';
    yield serializers.serialize(
      object.serverSignature,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DisplayCardInput object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DisplayCardInputBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'user_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.userId = valueDes;
          break;
        case r'display_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.displayName = valueDes;
          break;
        case r'account_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.accountNumber = valueDes;
          break;
        case r'issued_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.issuedAt = valueDes;
          break;
        case r'bank_key_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.bankKeyId = valueDes;
          break;
        case r'server_signature':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.serverSignature = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DisplayCardInput deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DisplayCardInputBuilder();
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

