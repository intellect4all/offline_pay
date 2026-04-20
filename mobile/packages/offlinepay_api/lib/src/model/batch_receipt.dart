//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:offlinepay_api/src/model/settlement_result.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'batch_receipt.g.dart';

/// BatchReceipt
///
/// Properties:
/// * [batchId] 
/// * [receiverUserId] 
/// * [totalSubmitted] 
/// * [totalSettled] 
/// * [totalPartial] 
/// * [totalRejected] 
/// * [totalAmountKobo] 
/// * [status] 
/// * [submittedAt] 
/// * [processedAt] 
/// * [results] 
@BuiltValue()
abstract class BatchReceipt implements Built<BatchReceipt, BatchReceiptBuilder> {
  @BuiltValueField(wireName: r'batch_id')
  String get batchId;

  @BuiltValueField(wireName: r'receiver_user_id')
  String get receiverUserId;

  @BuiltValueField(wireName: r'total_submitted')
  int get totalSubmitted;

  @BuiltValueField(wireName: r'total_settled')
  int get totalSettled;

  @BuiltValueField(wireName: r'total_partial')
  int get totalPartial;

  @BuiltValueField(wireName: r'total_rejected')
  int get totalRejected;

  @BuiltValueField(wireName: r'total_amount_kobo')
  int get totalAmountKobo;

  @BuiltValueField(wireName: r'status')
  BatchReceiptStatusEnum get status;
  // enum statusEnum {  SETTLEMENT_BATCH_STATUS_UNSPECIFIED,  SETTLEMENT_BATCH_STATUS_RECEIVED,  SETTLEMENT_BATCH_STATUS_PROCESSING,  SETTLEMENT_BATCH_STATUS_COMPLETED,  SETTLEMENT_BATCH_STATUS_FAILED,  };

  @BuiltValueField(wireName: r'submitted_at')
  DateTime get submittedAt;

  @BuiltValueField(wireName: r'processed_at')
  DateTime? get processedAt;

  @BuiltValueField(wireName: r'results')
  BuiltList<SettlementResult> get results;

  BatchReceipt._();

  factory BatchReceipt([void updates(BatchReceiptBuilder b)]) = _$BatchReceipt;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(BatchReceiptBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<BatchReceipt> get serializer => _$BatchReceiptSerializer();
}

class _$BatchReceiptSerializer implements PrimitiveSerializer<BatchReceipt> {
  @override
  final Iterable<Type> types = const [BatchReceipt, _$BatchReceipt];

  @override
  final String wireName = r'BatchReceipt';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    BatchReceipt object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'batch_id';
    yield serializers.serialize(
      object.batchId,
      specifiedType: const FullType(String),
    );
    yield r'receiver_user_id';
    yield serializers.serialize(
      object.receiverUserId,
      specifiedType: const FullType(String),
    );
    yield r'total_submitted';
    yield serializers.serialize(
      object.totalSubmitted,
      specifiedType: const FullType(int),
    );
    yield r'total_settled';
    yield serializers.serialize(
      object.totalSettled,
      specifiedType: const FullType(int),
    );
    yield r'total_partial';
    yield serializers.serialize(
      object.totalPartial,
      specifiedType: const FullType(int),
    );
    yield r'total_rejected';
    yield serializers.serialize(
      object.totalRejected,
      specifiedType: const FullType(int),
    );
    yield r'total_amount_kobo';
    yield serializers.serialize(
      object.totalAmountKobo,
      specifiedType: const FullType(int),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(BatchReceiptStatusEnum),
    );
    yield r'submitted_at';
    yield serializers.serialize(
      object.submittedAt,
      specifiedType: const FullType(DateTime),
    );
    if (object.processedAt != null) {
      yield r'processed_at';
      yield serializers.serialize(
        object.processedAt,
        specifiedType: const FullType(DateTime),
      );
    }
    yield r'results';
    yield serializers.serialize(
      object.results,
      specifiedType: const FullType(BuiltList, [FullType(SettlementResult)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    BatchReceipt object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required BatchReceiptBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'batch_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.batchId = valueDes;
          break;
        case r'receiver_user_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.receiverUserId = valueDes;
          break;
        case r'total_submitted':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalSubmitted = valueDes;
          break;
        case r'total_settled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalSettled = valueDes;
          break;
        case r'total_partial':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalPartial = valueDes;
          break;
        case r'total_rejected':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalRejected = valueDes;
          break;
        case r'total_amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.totalAmountKobo = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BatchReceiptStatusEnum),
          ) as BatchReceiptStatusEnum;
          result.status = valueDes;
          break;
        case r'submitted_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.submittedAt = valueDes;
          break;
        case r'processed_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.processedAt = valueDes;
          break;
        case r'results':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(SettlementResult)]),
          ) as BuiltList<SettlementResult>;
          result.results.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  BatchReceipt deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = BatchReceiptBuilder();
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

class BatchReceiptStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'SETTLEMENT_BATCH_STATUS_UNSPECIFIED')
  static const BatchReceiptStatusEnum SETTLEMENT_BATCH_STATUS_UNSPECIFIED = _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_UNSPECIFIED;
  @BuiltValueEnumConst(wireName: r'SETTLEMENT_BATCH_STATUS_RECEIVED')
  static const BatchReceiptStatusEnum SETTLEMENT_BATCH_STATUS_RECEIVED = _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_RECEIVED;
  @BuiltValueEnumConst(wireName: r'SETTLEMENT_BATCH_STATUS_PROCESSING')
  static const BatchReceiptStatusEnum SETTLEMENT_BATCH_STATUS_PROCESSING = _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_PROCESSING;
  @BuiltValueEnumConst(wireName: r'SETTLEMENT_BATCH_STATUS_COMPLETED')
  static const BatchReceiptStatusEnum SETTLEMENT_BATCH_STATUS_COMPLETED = _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_COMPLETED;
  @BuiltValueEnumConst(wireName: r'SETTLEMENT_BATCH_STATUS_FAILED')
  static const BatchReceiptStatusEnum SETTLEMENT_BATCH_STATUS_FAILED = _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_FAILED;

  static Serializer<BatchReceiptStatusEnum> get serializer => _$batchReceiptStatusEnumSerializer;

  const BatchReceiptStatusEnum._(String name): super(name);

  static BuiltSet<BatchReceiptStatusEnum> get values => _$batchReceiptStatusEnumValues;
  static BatchReceiptStatusEnum valueOf(String name) => _$batchReceiptStatusEnumValueOf(name);
}

