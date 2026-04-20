//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'synced_transaction.g.dart';

/// SyncedTransaction
///
/// Properties:
/// * [transactionId] 
/// * [payerId] 
/// * [payeeId] 
/// * [amountKobo] 
/// * [settledAmountKobo] 
/// * [sequenceNumber] 
/// * [ceilingTokenId] 
/// * [status] 
/// * [rejectionReason] 
/// * [submittedAt] 
/// * [settledAt] 
@BuiltValue()
abstract class SyncedTransaction implements Built<SyncedTransaction, SyncedTransactionBuilder> {
  @BuiltValueField(wireName: r'transaction_id')
  String get transactionId;

  @BuiltValueField(wireName: r'payer_id')
  String get payerId;

  @BuiltValueField(wireName: r'payee_id')
  String get payeeId;

  @BuiltValueField(wireName: r'amount_kobo')
  int get amountKobo;

  @BuiltValueField(wireName: r'settled_amount_kobo')
  int get settledAmountKobo;

  @BuiltValueField(wireName: r'sequence_number')
  int get sequenceNumber;

  @BuiltValueField(wireName: r'ceiling_token_id')
  String get ceilingTokenId;

  @BuiltValueField(wireName: r'status')
  SyncedTransactionStatusEnum get status;
  // enum statusEnum {  TRANSACTION_STATUS_UNSPECIFIED,  TRANSACTION_STATUS_QUEUED,  TRANSACTION_STATUS_SUBMITTED,  TRANSACTION_STATUS_PENDING,  TRANSACTION_STATUS_SETTLED,  TRANSACTION_STATUS_PARTIALLY_SETTLED,  TRANSACTION_STATUS_REJECTED,  TRANSACTION_STATUS_EXPIRED,  };

  @BuiltValueField(wireName: r'rejection_reason')
  String? get rejectionReason;

  @BuiltValueField(wireName: r'submitted_at')
  DateTime? get submittedAt;

  @BuiltValueField(wireName: r'settled_at')
  DateTime? get settledAt;

  SyncedTransaction._();

  factory SyncedTransaction([void updates(SyncedTransactionBuilder b)]) = _$SyncedTransaction;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SyncedTransactionBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SyncedTransaction> get serializer => _$SyncedTransactionSerializer();
}

class _$SyncedTransactionSerializer implements PrimitiveSerializer<SyncedTransaction> {
  @override
  final Iterable<Type> types = const [SyncedTransaction, _$SyncedTransaction];

  @override
  final String wireName = r'SyncedTransaction';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SyncedTransaction object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'transaction_id';
    yield serializers.serialize(
      object.transactionId,
      specifiedType: const FullType(String),
    );
    yield r'payer_id';
    yield serializers.serialize(
      object.payerId,
      specifiedType: const FullType(String),
    );
    yield r'payee_id';
    yield serializers.serialize(
      object.payeeId,
      specifiedType: const FullType(String),
    );
    yield r'amount_kobo';
    yield serializers.serialize(
      object.amountKobo,
      specifiedType: const FullType(int),
    );
    yield r'settled_amount_kobo';
    yield serializers.serialize(
      object.settledAmountKobo,
      specifiedType: const FullType(int),
    );
    yield r'sequence_number';
    yield serializers.serialize(
      object.sequenceNumber,
      specifiedType: const FullType(int),
    );
    yield r'ceiling_token_id';
    yield serializers.serialize(
      object.ceilingTokenId,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(SyncedTransactionStatusEnum),
    );
    if (object.rejectionReason != null) {
      yield r'rejection_reason';
      yield serializers.serialize(
        object.rejectionReason,
        specifiedType: const FullType(String),
      );
    }
    if (object.submittedAt != null) {
      yield r'submitted_at';
      yield serializers.serialize(
        object.submittedAt,
        specifiedType: const FullType(DateTime),
      );
    }
    if (object.settledAt != null) {
      yield r'settled_at';
      yield serializers.serialize(
        object.settledAt,
        specifiedType: const FullType(DateTime),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    SyncedTransaction object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SyncedTransactionBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'transaction_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.transactionId = valueDes;
          break;
        case r'payer_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.payerId = valueDes;
          break;
        case r'payee_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.payeeId = valueDes;
          break;
        case r'amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.amountKobo = valueDes;
          break;
        case r'settled_amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.settledAmountKobo = valueDes;
          break;
        case r'sequence_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.sequenceNumber = valueDes;
          break;
        case r'ceiling_token_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.ceilingTokenId = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(SyncedTransactionStatusEnum),
          ) as SyncedTransactionStatusEnum;
          result.status = valueDes;
          break;
        case r'rejection_reason':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.rejectionReason = valueDes;
          break;
        case r'submitted_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.submittedAt = valueDes;
          break;
        case r'settled_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.settledAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SyncedTransaction deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SyncedTransactionBuilder();
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

class SyncedTransactionStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_UNSPECIFIED')
  static const SyncedTransactionStatusEnum TRANSACTION_STATUS_UNSPECIFIED = _$syncedTransactionStatusEnum_TRANSACTION_STATUS_UNSPECIFIED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_QUEUED')
  static const SyncedTransactionStatusEnum TRANSACTION_STATUS_QUEUED = _$syncedTransactionStatusEnum_TRANSACTION_STATUS_QUEUED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_SUBMITTED')
  static const SyncedTransactionStatusEnum TRANSACTION_STATUS_SUBMITTED = _$syncedTransactionStatusEnum_TRANSACTION_STATUS_SUBMITTED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_PENDING')
  static const SyncedTransactionStatusEnum TRANSACTION_STATUS_PENDING = _$syncedTransactionStatusEnum_TRANSACTION_STATUS_PENDING;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_SETTLED')
  static const SyncedTransactionStatusEnum TRANSACTION_STATUS_SETTLED = _$syncedTransactionStatusEnum_TRANSACTION_STATUS_SETTLED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_PARTIALLY_SETTLED')
  static const SyncedTransactionStatusEnum TRANSACTION_STATUS_PARTIALLY_SETTLED = _$syncedTransactionStatusEnum_TRANSACTION_STATUS_PARTIALLY_SETTLED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_REJECTED')
  static const SyncedTransactionStatusEnum TRANSACTION_STATUS_REJECTED = _$syncedTransactionStatusEnum_TRANSACTION_STATUS_REJECTED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_EXPIRED')
  static const SyncedTransactionStatusEnum TRANSACTION_STATUS_EXPIRED = _$syncedTransactionStatusEnum_TRANSACTION_STATUS_EXPIRED;

  static Serializer<SyncedTransactionStatusEnum> get serializer => _$syncedTransactionStatusEnumSerializer;

  const SyncedTransactionStatusEnum._(String name): super(name);

  static BuiltSet<SyncedTransactionStatusEnum> get values => _$syncedTransactionStatusEnumValues;
  static SyncedTransactionStatusEnum valueOf(String name) => _$syncedTransactionStatusEnumValueOf(name);
}

