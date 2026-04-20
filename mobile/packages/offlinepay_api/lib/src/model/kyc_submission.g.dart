// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kyc_submission.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const KYCSubmissionStatusEnum _$kYCSubmissionStatusEnum_VERIFIED =
    const KYCSubmissionStatusEnum._('VERIFIED');
const KYCSubmissionStatusEnum _$kYCSubmissionStatusEnum_REJECTED =
    const KYCSubmissionStatusEnum._('REJECTED');

KYCSubmissionStatusEnum _$kYCSubmissionStatusEnumValueOf(String name) {
  switch (name) {
    case 'VERIFIED':
      return _$kYCSubmissionStatusEnum_VERIFIED;
    case 'REJECTED':
      return _$kYCSubmissionStatusEnum_REJECTED;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<KYCSubmissionStatusEnum> _$kYCSubmissionStatusEnumValues =
    BuiltSet<KYCSubmissionStatusEnum>(const <KYCSubmissionStatusEnum>[
  _$kYCSubmissionStatusEnum_VERIFIED,
  _$kYCSubmissionStatusEnum_REJECTED,
]);

Serializer<KYCSubmissionStatusEnum> _$kYCSubmissionStatusEnumSerializer =
    _$KYCSubmissionStatusEnumSerializer();

class _$KYCSubmissionStatusEnumSerializer
    implements PrimitiveSerializer<KYCSubmissionStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'VERIFIED': 'VERIFIED',
    'REJECTED': 'REJECTED',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'VERIFIED': 'VERIFIED',
    'REJECTED': 'REJECTED',
  };

  @override
  final Iterable<Type> types = const <Type>[KYCSubmissionStatusEnum];
  @override
  final String wireName = 'KYCSubmissionStatusEnum';

  @override
  Object serialize(Serializers serializers, KYCSubmissionStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  KYCSubmissionStatusEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      KYCSubmissionStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$KYCSubmission extends KYCSubmission {
  @override
  final String id;
  @override
  final String userId;
  @override
  final String idType;
  @override
  final String idNumber;
  @override
  final KYCSubmissionStatusEnum status;
  @override
  final String? rejectionReason;
  @override
  final String? tierGranted;
  @override
  final String? submittedBy;
  @override
  final DateTime submittedAt;
  @override
  final DateTime? verifiedAt;

  factory _$KYCSubmission([void Function(KYCSubmissionBuilder)? updates]) =>
      (KYCSubmissionBuilder()..update(updates))._build();

  _$KYCSubmission._(
      {required this.id,
      required this.userId,
      required this.idType,
      required this.idNumber,
      required this.status,
      this.rejectionReason,
      this.tierGranted,
      this.submittedBy,
      required this.submittedAt,
      this.verifiedAt})
      : super._();
  @override
  KYCSubmission rebuild(void Function(KYCSubmissionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  KYCSubmissionBuilder toBuilder() => KYCSubmissionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is KYCSubmission &&
        id == other.id &&
        userId == other.userId &&
        idType == other.idType &&
        idNumber == other.idNumber &&
        status == other.status &&
        rejectionReason == other.rejectionReason &&
        tierGranted == other.tierGranted &&
        submittedBy == other.submittedBy &&
        submittedAt == other.submittedAt &&
        verifiedAt == other.verifiedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, idType.hashCode);
    _$hash = $jc(_$hash, idNumber.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, rejectionReason.hashCode);
    _$hash = $jc(_$hash, tierGranted.hashCode);
    _$hash = $jc(_$hash, submittedBy.hashCode);
    _$hash = $jc(_$hash, submittedAt.hashCode);
    _$hash = $jc(_$hash, verifiedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'KYCSubmission')
          ..add('id', id)
          ..add('userId', userId)
          ..add('idType', idType)
          ..add('idNumber', idNumber)
          ..add('status', status)
          ..add('rejectionReason', rejectionReason)
          ..add('tierGranted', tierGranted)
          ..add('submittedBy', submittedBy)
          ..add('submittedAt', submittedAt)
          ..add('verifiedAt', verifiedAt))
        .toString();
  }
}

class KYCSubmissionBuilder
    implements Builder<KYCSubmission, KYCSubmissionBuilder> {
  _$KYCSubmission? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  String? _idType;
  String? get idType => _$this._idType;
  set idType(String? idType) => _$this._idType = idType;

  String? _idNumber;
  String? get idNumber => _$this._idNumber;
  set idNumber(String? idNumber) => _$this._idNumber = idNumber;

  KYCSubmissionStatusEnum? _status;
  KYCSubmissionStatusEnum? get status => _$this._status;
  set status(KYCSubmissionStatusEnum? status) => _$this._status = status;

  String? _rejectionReason;
  String? get rejectionReason => _$this._rejectionReason;
  set rejectionReason(String? rejectionReason) =>
      _$this._rejectionReason = rejectionReason;

  String? _tierGranted;
  String? get tierGranted => _$this._tierGranted;
  set tierGranted(String? tierGranted) => _$this._tierGranted = tierGranted;

  String? _submittedBy;
  String? get submittedBy => _$this._submittedBy;
  set submittedBy(String? submittedBy) => _$this._submittedBy = submittedBy;

  DateTime? _submittedAt;
  DateTime? get submittedAt => _$this._submittedAt;
  set submittedAt(DateTime? submittedAt) => _$this._submittedAt = submittedAt;

  DateTime? _verifiedAt;
  DateTime? get verifiedAt => _$this._verifiedAt;
  set verifiedAt(DateTime? verifiedAt) => _$this._verifiedAt = verifiedAt;

  KYCSubmissionBuilder() {
    KYCSubmission._defaults(this);
  }

  KYCSubmissionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _userId = $v.userId;
      _idType = $v.idType;
      _idNumber = $v.idNumber;
      _status = $v.status;
      _rejectionReason = $v.rejectionReason;
      _tierGranted = $v.tierGranted;
      _submittedBy = $v.submittedBy;
      _submittedAt = $v.submittedAt;
      _verifiedAt = $v.verifiedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(KYCSubmission other) {
    _$v = other as _$KYCSubmission;
  }

  @override
  void update(void Function(KYCSubmissionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  KYCSubmission build() => _build();

  _$KYCSubmission _build() {
    final _$result = _$v ??
        _$KYCSubmission._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'KYCSubmission', 'id'),
          userId: BuiltValueNullFieldError.checkNotNull(
              userId, r'KYCSubmission', 'userId'),
          idType: BuiltValueNullFieldError.checkNotNull(
              idType, r'KYCSubmission', 'idType'),
          idNumber: BuiltValueNullFieldError.checkNotNull(
              idNumber, r'KYCSubmission', 'idNumber'),
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'KYCSubmission', 'status'),
          rejectionReason: rejectionReason,
          tierGranted: tierGranted,
          submittedBy: submittedBy,
          submittedAt: BuiltValueNullFieldError.checkNotNull(
              submittedAt, r'KYCSubmission', 'submittedAt'),
          verifiedAt: verifiedAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
