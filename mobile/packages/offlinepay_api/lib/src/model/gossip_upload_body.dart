//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:offlinepay_api/src/model/gossip_blob_input.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'gossip_upload_body.g.dart';

/// GossipUploadBody
///
/// Properties:
/// * [blobs] 
@BuiltValue()
abstract class GossipUploadBody implements Built<GossipUploadBody, GossipUploadBodyBuilder> {
  @BuiltValueField(wireName: r'blobs')
  BuiltList<GossipBlobInput> get blobs;

  GossipUploadBody._();

  factory GossipUploadBody([void updates(GossipUploadBodyBuilder b)]) = _$GossipUploadBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GossipUploadBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GossipUploadBody> get serializer => _$GossipUploadBodySerializer();
}

class _$GossipUploadBodySerializer implements PrimitiveSerializer<GossipUploadBody> {
  @override
  final Iterable<Type> types = const [GossipUploadBody, _$GossipUploadBody];

  @override
  final String wireName = r'GossipUploadBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GossipUploadBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'blobs';
    yield serializers.serialize(
      object.blobs,
      specifiedType: const FullType(BuiltList, [FullType(GossipBlobInput)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GossipUploadBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GossipUploadBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'blobs':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(GossipBlobInput)]),
          ) as BuiltList<GossipBlobInput>;
          result.blobs.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GossipUploadBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GossipUploadBodyBuilder();
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

