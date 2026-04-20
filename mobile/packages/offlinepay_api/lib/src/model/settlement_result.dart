//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'settlement_result.g.dart';

/// SettlementResult
///
/// Properties:
/// * [transactionId] 
/// * [sequenceNumber] 
/// * [submittedAmountKobo] 
/// * [settledAmountKobo] 
/// * [status] 
/// * [reason] 
@BuiltValue()
abstract class SettlementResult implements Built<SettlementResult, SettlementResultBuilder> {
  @BuiltValueField(wireName: r'transaction_id')
  String get transactionId;

  @BuiltValueField(wireName: r'sequence_number')
  int get sequenceNumber;

  @BuiltValueField(wireName: r'submitted_amount_kobo')
  int get submittedAmountKobo;

  @BuiltValueField(wireName: r'settled_amount_kobo')
  int get settledAmountKobo;

  @BuiltValueField(wireName: r'status')
  SettlementResultStatusEnum get status;
  // enum statusEnum {  TRANSACTION_STATUS_UNSPECIFIED,  TRANSACTION_STATUS_QUEUED,  TRANSACTION_STATUS_SUBMITTED,  TRANSACTION_STATUS_PENDING,  TRANSACTION_STATUS_SETTLED,  TRANSACTION_STATUS_PARTIALLY_SETTLED,  TRANSACTION_STATUS_REJECTED,  TRANSACTION_STATUS_EXPIRED,  };

  @BuiltValueField(wireName: r'reason')
  String? get reason;

  SettlementResult._();

  factory SettlementResult([void updates(SettlementResultBuilder b)]) = _$SettlementResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(SettlementResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<SettlementResult> get serializer => _$SettlementResultSerializer();
}

class _$SettlementResultSerializer implements PrimitiveSerializer<SettlementResult> {
  @override
  final Iterable<Type> types = const [SettlementResult, _$SettlementResult];

  @override
  final String wireName = r'SettlementResult';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    SettlementResult object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'transaction_id';
    yield serializers.serialize(
      object.transactionId,
      specifiedType: const FullType(String),
    );
    yield r'sequence_number';
    yield serializers.serialize(
      object.sequenceNumber,
      specifiedType: const FullType(int),
    );
    yield r'submitted_amount_kobo';
    yield serializers.serialize(
      object.submittedAmountKobo,
      specifiedType: const FullType(int),
    );
    yield r'settled_amount_kobo';
    yield serializers.serialize(
      object.settledAmountKobo,
      specifiedType: const FullType(int),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(SettlementResultStatusEnum),
    );
    if (object.reason != null) {
      yield r'reason';
      yield serializers.serialize(
        object.reason,
        specifiedType: const FullType(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    SettlementResult object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required SettlementResultBuilder result,
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
        case r'sequence_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.sequenceNumber = valueDes;
          break;
        case r'submitted_amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.submittedAmountKobo = valueDes;
          break;
        case r'settled_amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.settledAmountKobo = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(SettlementResultStatusEnum),
          ) as SettlementResultStatusEnum;
          result.status = valueDes;
          break;
        case r'reason':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.reason = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  SettlementResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = SettlementResultBuilder();
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

class SettlementResultStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_UNSPECIFIED')
  static const SettlementResultStatusEnum TRANSACTION_STATUS_UNSPECIFIED = _$settlementResultStatusEnum_TRANSACTION_STATUS_UNSPECIFIED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_QUEUED')
  static const SettlementResultStatusEnum TRANSACTION_STATUS_QUEUED = _$settlementResultStatusEnum_TRANSACTION_STATUS_QUEUED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_SUBMITTED')
  static const SettlementResultStatusEnum TRANSACTION_STATUS_SUBMITTED = _$settlementResultStatusEnum_TRANSACTION_STATUS_SUBMITTED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_PENDING')
  static const SettlementResultStatusEnum TRANSACTION_STATUS_PENDING = _$settlementResultStatusEnum_TRANSACTION_STATUS_PENDING;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_SETTLED')
  static const SettlementResultStatusEnum TRANSACTION_STATUS_SETTLED = _$settlementResultStatusEnum_TRANSACTION_STATUS_SETTLED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_PARTIALLY_SETTLED')
  static const SettlementResultStatusEnum TRANSACTION_STATUS_PARTIALLY_SETTLED = _$settlementResultStatusEnum_TRANSACTION_STATUS_PARTIALLY_SETTLED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_REJECTED')
  static const SettlementResultStatusEnum TRANSACTION_STATUS_REJECTED = _$settlementResultStatusEnum_TRANSACTION_STATUS_REJECTED;
  @BuiltValueEnumConst(wireName: r'TRANSACTION_STATUS_EXPIRED')
  static const SettlementResultStatusEnum TRANSACTION_STATUS_EXPIRED = _$settlementResultStatusEnum_TRANSACTION_STATUS_EXPIRED;

  static Serializer<SettlementResultStatusEnum> get serializer => _$settlementResultStatusEnumSerializer;

  const SettlementResultStatusEnum._(String name): super(name);

  static BuiltSet<SettlementResultStatusEnum> get values => _$settlementResultStatusEnumValues;
  static SettlementResultStatusEnum valueOf(String name) => _$settlementResultStatusEnumValueOf(name);
}

