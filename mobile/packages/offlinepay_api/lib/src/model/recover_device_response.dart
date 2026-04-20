//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'recover_device_response.g.dart';

/// RecoverDeviceResponse
///
/// Properties:
/// * [newDeviceId] 
/// * [recoveredAt] 
/// * [realmKeyVersion] 
@BuiltValue()
abstract class RecoverDeviceResponse implements Built<RecoverDeviceResponse, RecoverDeviceResponseBuilder> {
  @BuiltValueField(wireName: r'new_device_id')
  String get newDeviceId;

  @BuiltValueField(wireName: r'recovered_at')
  DateTime get recoveredAt;

  @BuiltValueField(wireName: r'realm_key_version')
  int get realmKeyVersion;

  RecoverDeviceResponse._();

  factory RecoverDeviceResponse([void updates(RecoverDeviceResponseBuilder b)]) = _$RecoverDeviceResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(RecoverDeviceResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<RecoverDeviceResponse> get serializer => _$RecoverDeviceResponseSerializer();
}

class _$RecoverDeviceResponseSerializer implements PrimitiveSerializer<RecoverDeviceResponse> {
  @override
  final Iterable<Type> types = const [RecoverDeviceResponse, _$RecoverDeviceResponse];

  @override
  final String wireName = r'RecoverDeviceResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    RecoverDeviceResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'new_device_id';
    yield serializers.serialize(
      object.newDeviceId,
      specifiedType: const FullType(String),
    );
    yield r'recovered_at';
    yield serializers.serialize(
      object.recoveredAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'realm_key_version';
    yield serializers.serialize(
      object.realmKeyVersion,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    RecoverDeviceResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required RecoverDeviceResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'new_device_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.newDeviceId = valueDes;
          break;
        case r'recovered_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.recoveredAt = valueDes;
          break;
        case r'realm_key_version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.realmKeyVersion = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  RecoverDeviceResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = RecoverDeviceResponseBuilder();
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

