//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'transfer.g.dart';

/// Transfer
///
/// Properties:
/// * [id] 
/// * [senderUserId] 
/// * [receiverUserId] 
/// * [senderDisplayName] - Best-effort \"First Last\" rendering of the sender pulled from the users table at read time. Nullable so the API stays forward- compatible if the join ever falls back (e.g. deleted user row). 
/// * [receiverDisplayName] - Best-effort \"First Last\" rendering of the receiver. Mirror of `sender_display_name`. 
/// * [receiverAccountNumber] 
/// * [amountKobo] 
/// * [status] 
/// * [reference] 
/// * [failureReason] 
/// * [createdAt] 
/// * [settledAt] 
@BuiltValue()
abstract class Transfer implements Built<Transfer, TransferBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'sender_user_id')
  String get senderUserId;

  @BuiltValueField(wireName: r'receiver_user_id')
  String get receiverUserId;

  /// Best-effort \"First Last\" rendering of the sender pulled from the users table at read time. Nullable so the API stays forward- compatible if the join ever falls back (e.g. deleted user row). 
  @BuiltValueField(wireName: r'sender_display_name')
  String? get senderDisplayName;

  /// Best-effort \"First Last\" rendering of the receiver. Mirror of `sender_display_name`. 
  @BuiltValueField(wireName: r'receiver_display_name')
  String? get receiverDisplayName;

  @BuiltValueField(wireName: r'receiver_account_number')
  String get receiverAccountNumber;

  @BuiltValueField(wireName: r'amount_kobo')
  int get amountKobo;

  @BuiltValueField(wireName: r'status')
  TransferStatusEnum get status;
  // enum statusEnum {  ACCEPTED,  PROCESSING,  SETTLED,  FAILED,  };

  @BuiltValueField(wireName: r'reference')
  String get reference;

  @BuiltValueField(wireName: r'failure_reason')
  String? get failureReason;

  @BuiltValueField(wireName: r'created_at')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'settled_at')
  DateTime? get settledAt;

  Transfer._();

  factory Transfer([void updates(TransferBuilder b)]) = _$Transfer;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TransferBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Transfer> get serializer => _$TransferSerializer();
}

class _$TransferSerializer implements PrimitiveSerializer<Transfer> {
  @override
  final Iterable<Type> types = const [Transfer, _$Transfer];

  @override
  final String wireName = r'Transfer';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Transfer object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'sender_user_id';
    yield serializers.serialize(
      object.senderUserId,
      specifiedType: const FullType(String),
    );
    yield r'receiver_user_id';
    yield serializers.serialize(
      object.receiverUserId,
      specifiedType: const FullType(String),
    );
    if (object.senderDisplayName != null) {
      yield r'sender_display_name';
      yield serializers.serialize(
        object.senderDisplayName,
        specifiedType: const FullType(String),
      );
    }
    if (object.receiverDisplayName != null) {
      yield r'receiver_display_name';
      yield serializers.serialize(
        object.receiverDisplayName,
        specifiedType: const FullType(String),
      );
    }
    yield r'receiver_account_number';
    yield serializers.serialize(
      object.receiverAccountNumber,
      specifiedType: const FullType(String),
    );
    yield r'amount_kobo';
    yield serializers.serialize(
      object.amountKobo,
      specifiedType: const FullType(int),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(TransferStatusEnum),
    );
    yield r'reference';
    yield serializers.serialize(
      object.reference,
      specifiedType: const FullType(String),
    );
    if (object.failureReason != null) {
      yield r'failure_reason';
      yield serializers.serialize(
        object.failureReason,
        specifiedType: const FullType(String),
      );
    }
    yield r'created_at';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
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
    Transfer object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TransferBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'sender_user_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.senderUserId = valueDes;
          break;
        case r'receiver_user_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.receiverUserId = valueDes;
          break;
        case r'sender_display_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.senderDisplayName = valueDes;
          break;
        case r'receiver_display_name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.receiverDisplayName = valueDes;
          break;
        case r'receiver_account_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.receiverAccountNumber = valueDes;
          break;
        case r'amount_kobo':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.amountKobo = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(TransferStatusEnum),
          ) as TransferStatusEnum;
          result.status = valueDes;
          break;
        case r'reference':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.reference = valueDes;
          break;
        case r'failure_reason':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.failureReason = valueDes;
          break;
        case r'created_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createdAt = valueDes;
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
  Transfer deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TransferBuilder();
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

class TransferStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'ACCEPTED')
  static const TransferStatusEnum ACCEPTED = _$transferStatusEnum_ACCEPTED;
  @BuiltValueEnumConst(wireName: r'PROCESSING')
  static const TransferStatusEnum PROCESSING = _$transferStatusEnum_PROCESSING;
  @BuiltValueEnumConst(wireName: r'SETTLED')
  static const TransferStatusEnum SETTLED = _$transferStatusEnum_SETTLED;
  @BuiltValueEnumConst(wireName: r'FAILED')
  static const TransferStatusEnum FAILED = _$transferStatusEnum_FAILED;

  static Serializer<TransferStatusEnum> get serializer => _$transferStatusEnumSerializer;

  const TransferStatusEnum._(String name): super(name);

  static BuiltSet<TransferStatusEnum> get values => _$transferStatusEnumValues;
  static TransferStatusEnum valueOf(String name) => _$transferStatusEnumValueOf(name);
}

