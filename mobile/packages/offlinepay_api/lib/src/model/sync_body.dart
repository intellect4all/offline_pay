//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_body.g.dart';

/// SyncBody
///
/// Properties:
/// * [since] 
/// * [disputedTransactionIds] 
/// * [finalize] 
@BuiltValue()
abstract class SyncBody implements Built<SyncBody, SyncBodyBuilder> {
  @BuiltValueField(wireName: r'since')
  DateTime? get since;

  @BuiltValueField(wireName: r'disputed_transaction_ids')
  BuiltList<String>? get disputedTransactionIds;

  @BuiltValueField(wireName: r'finalize')
  bool? get finalize;

  SyncBody._();

  factory SyncBody([void updates(SyncBodyBuilder b)]) = _$SyncBody;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncBodyBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncBody> get serializer => _$SyncBodySerializer();
}

class _$SyncBodySerializer implements PrimitiveSerializer<SyncBody> {
  @override
  final Iterable<Type> types = const [SyncBody, _$SyncBody];

  @override
  final String wireName = r'SyncBody';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncBody object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.since != null) {
      yield r'since';
      yield serializers.serialize(
        object.since,
        specifiedType: const FullType(DateTime),
      );
    }
    if (object.disputedTransactionIds != null) {
      yield r'disputed_transaction_ids';
      yield serializers.serialize(
        object.disputedTransactionIds,
        specifiedType: const FullType(BuiltList, [FullType(String)]),
      );
    }
    if (object.finalize != null) {
      yield r'finalize';
      yield serializers.serialize(
        object.finalize,
        specifiedType: const FullType(bool),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncBody object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SyncBodyBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'since':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.since = valueDes;
          break;
        case r'disputed_transaction_ids':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.disputedTransactionIds.replace(valueDes);
          break;
        case r'finalize':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.finalize = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncBody deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncBodyBuilder();
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

