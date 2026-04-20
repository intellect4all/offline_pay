//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'gossip_blob_input.g.dart';

/// GossipBlobInput
///
/// Properties:
/// * [transactionHash] 
/// * [encryptedBlob] 
/// * [bankSignature] 
/// * [ceilingTokenHash] 
/// * [hopCount] 
/// * [blobSize] 
@BuiltValue()
abstract class GossipBlobInput implements Built<GossipBlobInput, GossipBlobInputBuilder> {
  @BuiltValueField(wireName: r'transaction_hash')
  String get transactionHash;

  @BuiltValueField(wireName: r'encrypted_blob')
  String get encryptedBlob;

  @BuiltValueField(wireName: r'bank_signature')
  String get bankSignature;

  @BuiltValueField(wireName: r'ceiling_token_hash')
  String get ceilingTokenHash;

  @BuiltValueField(wireName: r'hop_count')
  int get hopCount;

  @BuiltValueField(wireName: r'blob_size')
  int get blobSize;

  GossipBlobInput._();

  factory GossipBlobInput([void updates(GossipBlobInputBuilder b)]) = _$GossipBlobInput;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GossipBlobInputBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GossipBlobInput> get serializer => _$GossipBlobInputSerializer();
}

class _$GossipBlobInputSerializer implements PrimitiveSerializer<GossipBlobInput> {
  @override
  final Iterable<Type> types = const [GossipBlobInput, _$GossipBlobInput];

  @override
  final String wireName = r'GossipBlobInput';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GossipBlobInput object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'transaction_hash';
    yield serializers.serialize(
      object.transactionHash,
      specifiedType: const FullType(String),
    );
    yield r'encrypted_blob';
    yield serializers.serialize(
      object.encryptedBlob,
      specifiedType: const FullType(String),
    );
    yield r'bank_signature';
    yield serializers.serialize(
      object.bankSignature,
      specifiedType: const FullType(String),
    );
    yield r'ceiling_token_hash';
    yield serializers.serialize(
      object.ceilingTokenHash,
      specifiedType: const FullType(String),
    );
    yield r'hop_count';
    yield serializers.serialize(
      object.hopCount,
      specifiedType: const FullType(int),
    );
    yield r'blob_size';
    yield serializers.serialize(
      object.blobSize,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GossipBlobInput object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GossipBlobInputBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'transaction_hash':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.transactionHash = valueDes;
          break;
        case r'encrypted_blob':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.encryptedBlob = valueDes;
          break;
        case r'bank_signature':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.bankSignature = valueDes;
          break;
        case r'ceiling_token_hash':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.ceilingTokenHash = valueDes;
          break;
        case r'hop_count':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.hopCount = valueDes;
          break;
        case r'blob_size':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.blobSize = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GossipBlobInput deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GossipBlobInputBuilder();
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

