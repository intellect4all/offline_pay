//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:offlinepay_api/src/model/synced_transaction.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'sync_response.g.dart';

/// SyncResponse
///
/// Properties:
/// * [payerSide] 
/// * [receiverSide] 
/// * [syncedAt] 
/// * [finalizedCount] 
/// * [finalizePending] - True when the caller set `finalize=true` and the server enqueued a settlement-finalize event. The ledger move runs asynchronously in the worker; clients should surface an \"in progress\" hint and wait for the `offline_payment_settled` push or the next sync cycle. 
@BuiltValue()
abstract class SyncResponse implements Built<SyncResponse, SyncResponseBuilder> {
  @BuiltValueField(wireName: r'payer_side')
  BuiltList<SyncedTransaction> get payerSide;

  @BuiltValueField(wireName: r'receiver_side')
  BuiltList<SyncedTransaction> get receiverSide;

  @BuiltValueField(wireName: r'synced_at')
  DateTime get syncedAt;

  @BuiltValueField(wireName: r'finalized_count')
  int get finalizedCount;

  /// True when the caller set `finalize=true` and the server enqueued a settlement-finalize event. The ledger move runs asynchronously in the worker; clients should surface an \"in progress\" hint and wait for the `offline_payment_settled` push or the next sync cycle. 
  @BuiltValueField(wireName: r'finalize_pending')
  bool? get finalizePending;

  SyncResponse._();

  factory SyncResponse([void updates(SyncResponseBuilder b)]) = _$SyncResponse;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncResponse> get serializer => _$SyncResponseSerializer();
}

class _$SyncResponseSerializer implements PrimitiveSerializer<SyncResponse> {
  @override
  final Iterable<Type> types = const [SyncResponse, _$SyncResponse];

  @override
  final String wireName = r'SyncResponse';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'payer_side';
    yield serializers.serialize(
      object.payerSide,
      specifiedType: const FullType(BuiltList, [FullType(SyncedTransaction)]),
    );
    yield r'receiver_side';
    yield serializers.serialize(
      object.receiverSide,
      specifiedType: const FullType(BuiltList, [FullType(SyncedTransaction)]),
    );
    yield r'synced_at';
    yield serializers.serialize(
      object.syncedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'finalized_count';
    yield serializers.serialize(
      object.finalizedCount,
      specifiedType: const FullType(int),
    );
    if (object.finalizePending != null) {
      yield r'finalize_pending';
      yield serializers.serialize(
        object.finalizePending,
        specifiedType: const FullType(bool),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncResponse object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SyncResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'payer_side':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(SyncedTransaction)]),
          ) as BuiltList<SyncedTransaction>;
          result.payerSide.replace(valueDes);
          break;
        case r'receiver_side':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(SyncedTransaction)]),
          ) as BuiltList<SyncedTransaction>;
          result.receiverSide.replace(valueDes);
          break;
        case r'synced_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.syncedAt = valueDes;
          break;
        case r'finalized_count':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.finalizedCount = valueDes;
          break;
        case r'finalize_pending':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.finalizePending = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncResponse deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncResponseBuilder();
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

