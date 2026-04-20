//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'refresh_ceiling_body.g.dart';

/// RefreshCeilingBody
///
/// Properties:
/// * [newAmountKobo] 
/// * [ttlSeconds] 
/// * [payerPublicKey] 
@BuiltValue()
abstract class RefreshCeilingBody implements Built<RefreshCeilingBody, RefreshCeilingBodyBuilder> {
  @BuiltValueField(wireName: r'new_amount_kobo')
  int get newAmountKobo;

  @BuiltValueField(wireName: r'ttl_seconds')
  int get ttlSeconds;

  @BuiltValueField(wireName: r'payer_public_key')
  String get payerPublicKey;

  RefreshCeilingBody._();

  factory RefreshCeilingBody([void updates(RefreshCeilingBodyBuilder b)]) = _$RefreshCeilingBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RefreshCeilingBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RefreshCeilingBody> get serializer => _$RefreshCeilingBodySerializer();
}

class _$RefreshCeilingBodySerializer implements PrimitiveSerializer<RefreshCeilingBody> {
  @override
  final Iterable<Type> types = const [RefreshCeilingBody, _$RefreshCeilingBody];

  @override
  final String wireName = r'RefreshCeilingBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RefreshCeilingBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'new_amount_kobo';
    yield serializers.serialize(
      object.newAmountKobo,
      specifiedType: const FullType(int),
    );
    yield r'ttl_seconds';
    yield serializers.serialize(
      object.ttlSeconds,
      specifiedType: const FullType(int),
    );
    yield r'payer_public_key';
    yield serializers.serialize(
      object.payerPublicKey,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RefreshCeilingBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RefreshCeilingBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'new_amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.newAmountKobo = valueDes;
          break;
        case r'ttl_seconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.ttlSeconds = valueDes;
          break;
        case r'payer_public_key':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.payerPublicKey = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RefreshCeilingBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RefreshCeilingBodyBuilder();
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

