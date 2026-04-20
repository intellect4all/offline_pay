//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sealed_box_pubkey_response.g.dart';

/// SealedBoxPubkeyResponse
///
/// Properties:
/// * [publicKey] 
/// * [keyId] 
/// * [activeFrom] 
@BuiltValue()
abstract class SealedBoxPubkeyResponse implements Built<SealedBoxPubkeyResponse, SealedBoxPubkeyResponseBuilder> {
  @BuiltValueField(wireName: r'public_key')
  String get publicKey;

  @BuiltValueField(wireName: r'key_id')
  String get keyId;

  @BuiltValueField(wireName: r'active_from')
  DateTime get activeFrom;

  SealedBoxPubkeyResponse._();

  factory SealedBoxPubkeyResponse([void updates(SealedBoxPubkeyResponseBuilder b)]) = _$SealedBoxPubkeyResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SealedBoxPubkeyResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SealedBoxPubkeyResponse> get serializer => _$SealedBoxPubkeyResponseSerializer();
}

class _$SealedBoxPubkeyResponseSerializer implements PrimitiveSerializer<SealedBoxPubkeyResponse> {
  @override
  final Iterable<Type> types = const [SealedBoxPubkeyResponse, _$SealedBoxPubkeyResponse];

  @override
  final String wireName = r'SealedBoxPubkeyResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SealedBoxPubkeyResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'public_key';
    yield serializers.serialize(
      object.publicKey,
      specifiedType: const FullType(String),
    );
    yield r'key_id';
    yield serializers.serialize(
      object.keyId,
      specifiedType: const FullType(String),
    );
    yield r'active_from';
    yield serializers.serialize(
      object.activeFrom,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    SealedBoxPubkeyResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SealedBoxPubkeyResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'public_key':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.publicKey = valueDes;
          break;
        case r'key_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.keyId = valueDes;
          break;
        case r'active_from':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.activeFrom = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SealedBoxPubkeyResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SealedBoxPubkeyResponseBuilder();
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

