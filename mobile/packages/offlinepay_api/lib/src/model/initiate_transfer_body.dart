//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'initiate_transfer_body.g.dart';

/// InitiateTransferBody
///
/// Properties:
/// * [receiverAccountNumber] 
/// * [amountKobo] 
/// * [reference] 
/// * [pin] - 4- or 6-digit transaction PIN. Never logged.
@BuiltValue()
abstract class InitiateTransferBody implements Built<InitiateTransferBody, InitiateTransferBodyBuilder> {
  @BuiltValueField(wireName: r'receiver_account_number')
  String get receiverAccountNumber;

  @BuiltValueField(wireName: r'amount_kobo')
  int get amountKobo;

  @BuiltValueField(wireName: r'reference')
  String get reference;

  /// 4- or 6-digit transaction PIN. Never logged.
  @BuiltValueField(wireName: r'pin')
  String get pin;

  InitiateTransferBody._();

  factory InitiateTransferBody([void updates(InitiateTransferBodyBuilder b)]) = _$InitiateTransferBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(InitiateTransferBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<InitiateTransferBody> get serializer => _$InitiateTransferBodySerializer();
}

class _$InitiateTransferBodySerializer implements PrimitiveSerializer<InitiateTransferBody> {
  @override
  final Iterable<Type> types = const [InitiateTransferBody, _$InitiateTransferBody];

  @override
  final String wireName = r'InitiateTransferBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    InitiateTransferBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'receiver_account_number';
    yield serializers.serialize(
      object.receiverAccountNumber,
      specifiedType: const FullType(String),
    );
    yield r'amount_kobo';
    yield serializers.serialize(
      object.amountKobo,
      specifiedType: const FullType(int),
    );
    yield r'reference';
    yield serializers.serialize(
      object.reference,
      specifiedType: const FullType(String),
    );
    yield r'pin';
    yield serializers.serialize(
      object.pin,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    InitiateTransferBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required InitiateTransferBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'receiver_account_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.receiverAccountNumber = valueDes;
          break;
        case r'amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.amountKobo = valueDes;
          break;
        case r'reference':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.reference = valueDes;
          break;
        case r'pin':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.pin = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  InitiateTransferBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = InitiateTransferBodyBuilder();
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

