//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_realm_key_response.g.dart';

/// GetRealmKeyResponse
///
/// Properties:
/// * [version] 
/// * [key] 
/// * [activeFrom] 
/// * [expiresAt] 
@BuiltValue()
abstract class GetRealmKeyResponse implements Built<GetRealmKeyResponse, GetRealmKeyResponseBuilder> {
  @BuiltValueField(wireName: r'version')
  int get version;

  @BuiltValueField(wireName: r'key')
  String get key;

  @BuiltValueField(wireName: r'active_from')
  DateTime get activeFrom;

  @BuiltValueField(wireName: r'expires_at')
  DateTime get expiresAt;

  GetRealmKeyResponse._();

  factory GetRealmKeyResponse([void updates(GetRealmKeyResponseBuilder b)]) = _$GetRealmKeyResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetRealmKeyResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetRealmKeyResponse> get serializer => _$GetRealmKeyResponseSerializer();
}

class _$GetRealmKeyResponseSerializer implements PrimitiveSerializer<GetRealmKeyResponse> {
  @override
  final Iterable<Type> types = const [GetRealmKeyResponse, _$GetRealmKeyResponse];

  @override
  final String wireName = r'GetRealmKeyResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetRealmKeyResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
    yield r'key';
    yield serializers.serialize(
      object.key,
      specifiedType: const FullType(String),
    );
    yield r'active_from';
    yield serializers.serialize(
      object.activeFrom,
      specifiedType: const FullType(DateTime),
    );
    yield r'expires_at';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetRealmKeyResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GetRealmKeyResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.version = valueDes;
          break;
        case r'key':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.key = valueDes;
          break;
        case r'active_from':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.activeFrom = valueDes;
          break;
        case r'expires_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.expiresAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GetRealmKeyResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetRealmKeyResponseBuilder();
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

