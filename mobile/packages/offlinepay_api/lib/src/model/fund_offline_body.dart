//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'fund_offline_body.g.dart';

/// FundOfflineBody
///
/// Properties:
/// * [amountKobo] 
/// * [ttlSeconds] 
/// * [payerPublicKey] 
@BuiltValue()
abstract class FundOfflineBody implements Built<FundOfflineBody, FundOfflineBodyBuilder> {
  @BuiltValueField(wireName: r'amount_kobo')
  int get amountKobo;

  @BuiltValueField(wireName: r'ttl_seconds')
  int get ttlSeconds;

  @BuiltValueField(wireName: r'payer_public_key')
  String get payerPublicKey;

  FundOfflineBody._();

  factory FundOfflineBody([void updates(FundOfflineBodyBuilder b)]) = _$FundOfflineBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FundOfflineBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FundOfflineBody> get serializer => _$FundOfflineBodySerializer();
}

class _$FundOfflineBodySerializer implements PrimitiveSerializer<FundOfflineBody> {
  @override
  final Iterable<Type> types = const [FundOfflineBody, _$FundOfflineBody];

  @override
  final String wireName = r'FundOfflineBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FundOfflineBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'amount_kobo';
    yield serializers.serialize(
      object.amountKobo,
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
    FundOfflineBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FundOfflineBodyBuilder result,
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
  FundOfflineBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FundOfflineBodyBuilder();
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

