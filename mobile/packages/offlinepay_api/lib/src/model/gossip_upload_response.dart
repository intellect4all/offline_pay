//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'gossip_upload_response.g.dart';

/// GossipUploadResponse
///
/// Properties:
/// * [accepted] 
/// * [duplicates] 
/// * [invalid] 
@BuiltValue()
abstract class GossipUploadResponse implements Built<GossipUploadResponse, GossipUploadResponseBuilder> {
  @BuiltValueField(wireName: r'accepted')
  int get accepted;

  @BuiltValueField(wireName: r'duplicates')
  int get duplicates;

  @BuiltValueField(wireName: r'invalid')
  int get invalid;

  GossipUploadResponse._();

  factory GossipUploadResponse([void updates(GossipUploadResponseBuilder b)]) = _$GossipUploadResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GossipUploadResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GossipUploadResponse> get serializer => _$GossipUploadResponseSerializer();
}

class _$GossipUploadResponseSerializer implements PrimitiveSerializer<GossipUploadResponse> {
  @override
  final Iterable<Type> types = const [GossipUploadResponse, _$GossipUploadResponse];

  @override
  final String wireName = r'GossipUploadResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GossipUploadResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'accepted';
    yield serializers.serialize(
      object.accepted,
      specifiedType: const FullType(int),
    );
    yield r'duplicates';
    yield serializers.serialize(
      object.duplicates,
      specifiedType: const FullType(int),
    );
    yield r'invalid';
    yield serializers.serialize(
      object.invalid,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GossipUploadResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GossipUploadResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'accepted':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.accepted = valueDes;
          break;
        case r'duplicates':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.duplicates = valueDes;
          break;
        case r'invalid':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.invalid = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GossipUploadResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GossipUploadResponseBuilder();
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

