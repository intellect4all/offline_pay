//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'realm_key.g.dart';

/// RealmKey
///
/// Properties:
/// * [version] 
/// * [key] 
/// * [activeFrom] 
/// * [retiredAt] 
@BuiltValue()
abstract class RealmKey implements Built<RealmKey, RealmKeyBuilder> {
  @BuiltValueField(wireName: r'version')
  int get version;

  @BuiltValueField(wireName: r'key')
  String get key;

  @BuiltValueField(wireName: r'active_from')
  DateTime get activeFrom;

  @BuiltValueField(wireName: r'retired_at')
  DateTime? get retiredAt;

  RealmKey._();

  factory RealmKey([void updates(RealmKeyBuilder b)]) = _$RealmKey;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RealmKeyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RealmKey> get serializer => _$RealmKeySerializer();
}

class _$RealmKeySerializer implements PrimitiveSerializer<RealmKey> {
  @override
  final Iterable<Type> types = const [RealmKey, _$RealmKey];

  @override
  final String wireName = r'RealmKey';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RealmKey object, {
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
    RealmKey object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RealmKeyBuilder result,
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
  RealmKey deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RealmKeyBuilder();
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

