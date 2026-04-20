// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ceiling_token_input.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const CeilingTokenInputStatusEnum
    _$ceilingTokenInputStatusEnum_CEILING_STATUS_UNSPECIFIED =
    const CeilingTokenInputStatusEnum._('CEILING_STATUS_UNSPECIFIED');
const CeilingTokenInputStatusEnum
    _$ceilingTokenInputStatusEnum_CEILING_STATUS_ACTIVE =
    const CeilingTokenInputStatusEnum._('CEILING_STATUS_ACTIVE');
const CeilingTokenInputStatusEnum
    _$ceilingTokenInputStatusEnum_CEILING_STATUS_EXPIRED =
    const CeilingTokenInputStatusEnum._('CEILING_STATUS_EXPIRED');
const CeilingTokenInputStatusEnum
    _$ceilingTokenInputStatusEnum_CEILING_STATUS_EXHAUSTED =
    const CeilingTokenInputStatusEnum._('CEILING_STATUS_EXHAUSTED');
const CeilingTokenInputStatusEnum
    _$ceilingTokenInputStatusEnum_CEILING_STATUS_REVOKED =
    const CeilingTokenInputStatusEnum._('CEILING_STATUS_REVOKED');

CeilingTokenInputStatusEnum _$ceilingTokenInputStatusEnumValueOf(String name) {
  switch (name) {
    case 'CEILING_STATUS_UNSPECIFIED':
      return _$ceilingTokenInputStatusEnum_CEILING_STATUS_UNSPECIFIED;
    case 'CEILING_STATUS_ACTIVE':
      return _$ceilingTokenInputStatusEnum_CEILING_STATUS_ACTIVE;
    case 'CEILING_STATUS_EXPIRED':
      return _$ceilingTokenInputStatusEnum_CEILING_STATUS_EXPIRED;
    case 'CEILING_STATUS_EXHAUSTED':
      return _$ceilingTokenInputStatusEnum_CEILING_STATUS_EXHAUSTED;
    case 'CEILING_STATUS_REVOKED':
      return _$ceilingTokenInputStatusEnum_CEILING_STATUS_REVOKED;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<CeilingTokenInputStatusEnum>
    _$ceilingTokenInputStatusEnumValues =
    BuiltSet<CeilingTokenInputStatusEnum>(const <CeilingTokenInputStatusEnum>[
  _$ceilingTokenInputStatusEnum_CEILING_STATUS_UNSPECIFIED,
  _$ceilingTokenInputStatusEnum_CEILING_STATUS_ACTIVE,
  _$ceilingTokenInputStatusEnum_CEILING_STATUS_EXPIRED,
  _$ceilingTokenInputStatusEnum_CEILING_STATUS_EXHAUSTED,
  _$ceilingTokenInputStatusEnum_CEILING_STATUS_REVOKED,
]);

Serializer<CeilingTokenInputStatusEnum>
    _$ceilingTokenInputStatusEnumSerializer =
    _$CeilingTokenInputStatusEnumSerializer();

class _$CeilingTokenInputStatusEnumSerializer
    implements PrimitiveSerializer<CeilingTokenInputStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'CEILING_STATUS_UNSPECIFIED': 'CEILING_STATUS_UNSPECIFIED',
    'CEILING_STATUS_ACTIVE': 'CEILING_STATUS_ACTIVE',
    'CEILING_STATUS_EXPIRED': 'CEILING_STATUS_EXPIRED',
    'CEILING_STATUS_EXHAUSTED': 'CEILING_STATUS_EXHAUSTED',
    'CEILING_STATUS_REVOKED': 'CEILING_STATUS_REVOKED',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'CEILING_STATUS_UNSPECIFIED': 'CEILING_STATUS_UNSPECIFIED',
    'CEILING_STATUS_ACTIVE': 'CEILING_STATUS_ACTIVE',
    'CEILING_STATUS_EXPIRED': 'CEILING_STATUS_EXPIRED',
    'CEILING_STATUS_EXHAUSTED': 'CEILING_STATUS_EXHAUSTED',
    'CEILING_STATUS_REVOKED': 'CEILING_STATUS_REVOKED',
  };

  @override
  final Iterable<Type> types = const <Type>[CeilingTokenInputStatusEnum];
  @override
  final String wireName = 'CeilingTokenInputStatusEnum';

  @override
  Object serialize(Serializers serializers, CeilingTokenInputStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  CeilingTokenInputStatusEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      CeilingTokenInputStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$CeilingTokenInput extends CeilingTokenInput {
  @override
  final String id;
  @override
  final String payerId;
  @override
  final int ceilingAmountKobo;
  @override
  final DateTime issuedAt;
  @override
  final DateTime expiresAt;
  @override
  final int sequenceStart;
  @override
  final String payerPublicKey;
  @override
  final String bankKeyId;
  @override
  final String bankSignature;
  @override
  final CeilingTokenInputStatusEnum status;

  factory _$CeilingTokenInput(
          [void Function(CeilingTokenInputBuilder)? updates]) =>
      (CeilingTokenInputBuilder()..update(updates))._build();

  _$CeilingTokenInput._(
      {required this.id,
      required this.payerId,
      required this.ceilingAmountKobo,
      required this.issuedAt,
      required this.expiresAt,
      required this.sequenceStart,
      required this.payerPublicKey,
      required this.bankKeyId,
      required this.bankSignature,
      required this.status})
      : super._();
  @override
  CeilingTokenInput rebuild(void Function(CeilingTokenInputBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  CeilingTokenInputBuilder toBuilder() =>
      CeilingTokenInputBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CeilingTokenInput &&
        id == other.id &&
        payerId == other.payerId &&
        ceilingAmountKobo == other.ceilingAmountKobo &&
        issuedAt == other.issuedAt &&
        expiresAt == other.expiresAt &&
        sequenceStart == other.sequenceStart &&
        payerPublicKey == other.payerPublicKey &&
        bankKeyId == other.bankKeyId &&
        bankSignature == other.bankSignature &&
        status == other.status;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, payerId.hashCode);
    _$hash = $jc(_$hash, ceilingAmountKobo.hashCode);
    _$hash = $jc(_$hash, issuedAt.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, sequenceStart.hashCode);
    _$hash = $jc(_$hash, payerPublicKey.hashCode);
    _$hash = $jc(_$hash, bankKeyId.hashCode);
    _$hash = $jc(_$hash, bankSignature.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CeilingTokenInput')
          ..add('id', id)
          ..add('payerId', payerId)
          ..add('ceilingAmountKobo', ceilingAmountKobo)
          ..add('issuedAt', issuedAt)
          ..add('expiresAt', expiresAt)
          ..add('sequenceStart', sequenceStart)
          ..add('payerPublicKey', payerPublicKey)
          ..add('bankKeyId', bankKeyId)
          ..add('bankSignature', bankSignature)
          ..add('status', status))
        .toString();
  }
}

class CeilingTokenInputBuilder
    implements Builder<CeilingTokenInput, CeilingTokenInputBuilder> {
  _$CeilingTokenInput? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _payerId;
  String? get payerId => _$this._payerId;
  set payerId(String? payerId) => _$this._payerId = payerId;

  int? _ceilingAmountKobo;
  int? get ceilingAmountKobo => _$this._ceilingAmountKobo;
  set ceilingAmountKobo(int? ceilingAmountKobo) =>
      _$this._ceilingAmountKobo = ceilingAmountKobo;

  DateTime? _issuedAt;
  DateTime? get issuedAt => _$this._issuedAt;
  set issuedAt(DateTime? issuedAt) => _$this._issuedAt = issuedAt;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  int? _sequenceStart;
  int? get sequenceStart => _$this._sequenceStart;
  set sequenceStart(int? sequenceStart) =>
      _$this._sequenceStart = sequenceStart;

  String? _payerPublicKey;
  String? get payerPublicKey => _$this._payerPublicKey;
  set payerPublicKey(String? payerPublicKey) =>
      _$this._payerPublicKey = payerPublicKey;

  String? _bankKeyId;
  String? get bankKeyId => _$this._bankKeyId;
  set bankKeyId(String? bankKeyId) => _$this._bankKeyId = bankKeyId;

  String? _bankSignature;
  String? get bankSignature => _$this._bankSignature;
  set bankSignature(String? bankSignature) =>
      _$this._bankSignature = bankSignature;

  CeilingTokenInputStatusEnum? _status;
  CeilingTokenInputStatusEnum? get status => _$this._status;
  set status(CeilingTokenInputStatusEnum? status) => _$this._status = status;

  CeilingTokenInputBuilder() {
    CeilingTokenInput._defaults(this);
  }

  CeilingTokenInputBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _payerId = $v.payerId;
      _ceilingAmountKobo = $v.ceilingAmountKobo;
      _issuedAt = $v.issuedAt;
      _expiresAt = $v.expiresAt;
      _sequenceStart = $v.sequenceStart;
      _payerPublicKey = $v.payerPublicKey;
      _bankKeyId = $v.bankKeyId;
      _bankSignature = $v.bankSignature;
      _status = $v.status;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CeilingTokenInput other) {
    _$v = other as _$CeilingTokenInput;
  }

  @override
  void update(void Function(CeilingTokenInputBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CeilingTokenInput build() => _build();

  _$CeilingTokenInput _build() {
    final _$result = _$v ??
        _$CeilingTokenInput._(
          id: BuiltValueNullFieldError.checkNotNull(
              id, r'CeilingTokenInput', 'id'),
          payerId: BuiltValueNullFieldError.checkNotNull(
              payerId, r'CeilingTokenInput', 'payerId'),
          ceilingAmountKobo: BuiltValueNullFieldError.checkNotNull(
              ceilingAmountKobo, r'CeilingTokenInput', 'ceilingAmountKobo'),
          issuedAt: BuiltValueNullFieldError.checkNotNull(
              issuedAt, r'CeilingTokenInput', 'issuedAt'),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt, r'CeilingTokenInput', 'expiresAt'),
          sequenceStart: BuiltValueNullFieldError.checkNotNull(
              sequenceStart, r'CeilingTokenInput', 'sequenceStart'),
          payerPublicKey: BuiltValueNullFieldError.checkNotNull(
              payerPublicKey, r'CeilingTokenInput', 'payerPublicKey'),
          bankKeyId: BuiltValueNullFieldError.checkNotNull(
              bankKeyId, r'CeilingTokenInput', 'bankKeyId'),
          bankSignature: BuiltValueNullFieldError.checkNotNull(
              bankSignature, r'CeilingTokenInput', 'bankSignature'),
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'CeilingTokenInput', 'status'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
