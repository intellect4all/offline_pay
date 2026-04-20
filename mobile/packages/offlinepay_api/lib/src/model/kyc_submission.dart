//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'kyc_submission.g.dart';

/// KYCSubmission
///
/// Properties:
/// * [id] 
/// * [userId] 
/// * [idType] 
/// * [idNumber] 
/// * [status] 
/// * [rejectionReason] 
/// * [tierGranted] 
/// * [submittedBy] 
/// * [submittedAt] 
/// * [verifiedAt] 
@BuiltValue()
abstract class KYCSubmission implements Built<KYCSubmission, KYCSubmissionBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'user_id')
  String get userId;

  @BuiltValueField(wireName: r'id_type')
  String get idType;

  @BuiltValueField(wireName: r'id_number')
  String get idNumber;

  @BuiltValueField(wireName: r'status')
  KYCSubmissionStatusEnum get status;
  // enum statusEnum {  VERIFIED,  REJECTED,  };

  @BuiltValueField(wireName: r'rejection_reason')
  String? get rejectionReason;

  @BuiltValueField(wireName: r'tier_granted')
  String? get tierGranted;

  @BuiltValueField(wireName: r'submitted_by')
  String? get submittedBy;

  @BuiltValueField(wireName: r'submitted_at')
  DateTime get submittedAt;

  @BuiltValueField(wireName: r'verified_at')
  DateTime? get verifiedAt;

  KYCSubmission._();

  factory KYCSubmission([void updates(KYCSubmissionBuilder b)]) = _$KYCSubmission;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(KYCSubmissionBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<KYCSubmission> get serializer => _$KYCSubmissionSerializer();
}

class _$KYCSubmissionSerializer implements PrimitiveSerializer<KYCSubmission> {
  @override
  final Iterable<Type> types = const [KYCSubmission, _$KYCSubmission];

  @override
  final String wireName = r'KYCSubmission';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    KYCSubmission object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'user_id';
    yield serializers.serialize(
      object.userId,
      specifiedType: const FullType(String),
    );
    yield r'id_type';
    yield serializers.serialize(
      object.idType,
      specifiedType: const FullType(String),
    );
    yield r'id_number';
    yield serializers.serialize(
      object.idNumber,
      specifiedType: const FullType(String),
    );
    yield r'status';
    yield serializers.serialize(
      object.status,
      specifiedType: const FullType(KYCSubmissionStatusEnum),
    );
    if (object.rejectionReason != null) {
      yield r'rejection_reason';
      yield serializers.serialize(
        object.rejectionReason,
        specifiedType: const FullType(String),
      );
    }
    if (object.tierGranted != null) {
      yield r'tier_granted';
      yield serializers.serialize(
        object.tierGranted,
        specifiedType: const FullType(String),
      );
    }
    if (object.submittedBy != null) {
      yield r'submitted_by';
      yield serializers.serialize(
        object.submittedBy,
        specifiedType: const FullType(String),
      );
    }
    yield r'submitted_at';
    yield serializers.serialize(
      object.submittedAt,
      specifiedType: const FullType(DateTime),
    );
    if (object.verifiedAt != null) {
      yield r'verified_at';
      yield serializers.serialize(
        object.verifiedAt,
        specifiedType: const FullType(DateTime),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    KYCSubmission object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required KYCSubmissionBuilder result,
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
        case r'user_id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.userId = valueDes;
          break;
        case r'id_type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.idType = valueDes;
          break;
        case r'id_number':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.idNumber = valueDes;
          break;
        case r'status':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(KYCSubmissionStatusEnum),
          ) as KYCSubmissionStatusEnum;
          result.status = valueDes;
          break;
        case r'rejection_reason':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.rejectionReason = valueDes;
          break;
        case r'tier_granted':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.tierGranted = valueDes;
          break;
        case r'submitted_by':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.submittedBy = valueDes;
          break;
        case r'submitted_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.submittedAt = valueDes;
          break;
        case r'verified_at':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.verifiedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  KYCSubmission deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = KYCSubmissionBuilder();
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

class KYCSubmissionStatusEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'VERIFIED')
  static const KYCSubmissionStatusEnum VERIFIED = _$kYCSubmissionStatusEnum_VERIFIED;
  @BuiltValueEnumConst(wireName: r'REJECTED')
  static const KYCSubmissionStatusEnum REJECTED = _$kYCSubmissionStatusEnum_REJECTED;

  static Serializer<KYCSubmissionStatusEnum> get serializer => _$kYCSubmissionStatusEnumSerializer;

  const KYCSubmissionStatusEnum._(String name): super(name);

  static BuiltSet<KYCSubmissionStatusEnum> get values => _$kYCSubmissionStatusEnumValues;
  static KYCSubmissionStatusEnum valueOf(String name) => _$kYCSubmissionStatusEnumValueOf(name);
}

