// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settlement_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SettlementResultStatusEnum
    _$settlementResultStatusEnum_TRANSACTION_STATUS_UNSPECIFIED =
    const SettlementResultStatusEnum._('TRANSACTION_STATUS_UNSPECIFIED');
const SettlementResultStatusEnum
    _$settlementResultStatusEnum_TRANSACTION_STATUS_QUEUED =
    const SettlementResultStatusEnum._('TRANSACTION_STATUS_QUEUED');
const SettlementResultStatusEnum
    _$settlementResultStatusEnum_TRANSACTION_STATUS_SUBMITTED =
    const SettlementResultStatusEnum._('TRANSACTION_STATUS_SUBMITTED');
const SettlementResultStatusEnum
    _$settlementResultStatusEnum_TRANSACTION_STATUS_PENDING =
    const SettlementResultStatusEnum._('TRANSACTION_STATUS_PENDING');
const SettlementResultStatusEnum
    _$settlementResultStatusEnum_TRANSACTION_STATUS_SETTLED =
    const SettlementResultStatusEnum._('TRANSACTION_STATUS_SETTLED');
const SettlementResultStatusEnum
    _$settlementResultStatusEnum_TRANSACTION_STATUS_PARTIALLY_SETTLED =
    const SettlementResultStatusEnum._('TRANSACTION_STATUS_PARTIALLY_SETTLED');
const SettlementResultStatusEnum
    _$settlementResultStatusEnum_TRANSACTION_STATUS_REJECTED =
    const SettlementResultStatusEnum._('TRANSACTION_STATUS_REJECTED');
const SettlementResultStatusEnum
    _$settlementResultStatusEnum_TRANSACTION_STATUS_EXPIRED =
    const SettlementResultStatusEnum._('TRANSACTION_STATUS_EXPIRED');

SettlementResultStatusEnum _$settlementResultStatusEnumValueOf(String name) {
  switch (name) {
    case 'TRANSACTION_STATUS_UNSPECIFIED':
      return _$settlementResultStatusEnum_TRANSACTION_STATUS_UNSPECIFIED;
    case 'TRANSACTION_STATUS_QUEUED':
      return _$settlementResultStatusEnum_TRANSACTION_STATUS_QUEUED;
    case 'TRANSACTION_STATUS_SUBMITTED':
      return _$settlementResultStatusEnum_TRANSACTION_STATUS_SUBMITTED;
    case 'TRANSACTION_STATUS_PENDING':
      return _$settlementResultStatusEnum_TRANSACTION_STATUS_PENDING;
    case 'TRANSACTION_STATUS_SETTLED':
      return _$settlementResultStatusEnum_TRANSACTION_STATUS_SETTLED;
    case 'TRANSACTION_STATUS_PARTIALLY_SETTLED':
      return _$settlementResultStatusEnum_TRANSACTION_STATUS_PARTIALLY_SETTLED;
    case 'TRANSACTION_STATUS_REJECTED':
      return _$settlementResultStatusEnum_TRANSACTION_STATUS_REJECTED;
    case 'TRANSACTION_STATUS_EXPIRED':
      return _$settlementResultStatusEnum_TRANSACTION_STATUS_EXPIRED;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SettlementResultStatusEnum> _$settlementResultStatusEnumValues =
    BuiltSet<SettlementResultStatusEnum>(const <SettlementResultStatusEnum>[
  _$settlementResultStatusEnum_TRANSACTION_STATUS_UNSPECIFIED,
  _$settlementResultStatusEnum_TRANSACTION_STATUS_QUEUED,
  _$settlementResultStatusEnum_TRANSACTION_STATUS_SUBMITTED,
  _$settlementResultStatusEnum_TRANSACTION_STATUS_PENDING,
  _$settlementResultStatusEnum_TRANSACTION_STATUS_SETTLED,
  _$settlementResultStatusEnum_TRANSACTION_STATUS_PARTIALLY_SETTLED,
  _$settlementResultStatusEnum_TRANSACTION_STATUS_REJECTED,
  _$settlementResultStatusEnum_TRANSACTION_STATUS_EXPIRED,
]);

Serializer<SettlementResultStatusEnum> _$settlementResultStatusEnumSerializer =
    _$SettlementResultStatusEnumSerializer();

class _$SettlementResultStatusEnumSerializer
    implements PrimitiveSerializer<SettlementResultStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'TRANSACTION_STATUS_UNSPECIFIED': 'TRANSACTION_STATUS_UNSPECIFIED',
    'TRANSACTION_STATUS_QUEUED': 'TRANSACTION_STATUS_QUEUED',
    'TRANSACTION_STATUS_SUBMITTED': 'TRANSACTION_STATUS_SUBMITTED',
    'TRANSACTION_STATUS_PENDING': 'TRANSACTION_STATUS_PENDING',
    'TRANSACTION_STATUS_SETTLED': 'TRANSACTION_STATUS_SETTLED',
    'TRANSACTION_STATUS_PARTIALLY_SETTLED':
        'TRANSACTION_STATUS_PARTIALLY_SETTLED',
    'TRANSACTION_STATUS_REJECTED': 'TRANSACTION_STATUS_REJECTED',
    'TRANSACTION_STATUS_EXPIRED': 'TRANSACTION_STATUS_EXPIRED',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'TRANSACTION_STATUS_UNSPECIFIED': 'TRANSACTION_STATUS_UNSPECIFIED',
    'TRANSACTION_STATUS_QUEUED': 'TRANSACTION_STATUS_QUEUED',
    'TRANSACTION_STATUS_SUBMITTED': 'TRANSACTION_STATUS_SUBMITTED',
    'TRANSACTION_STATUS_PENDING': 'TRANSACTION_STATUS_PENDING',
    'TRANSACTION_STATUS_SETTLED': 'TRANSACTION_STATUS_SETTLED',
    'TRANSACTION_STATUS_PARTIALLY_SETTLED':
        'TRANSACTION_STATUS_PARTIALLY_SETTLED',
    'TRANSACTION_STATUS_REJECTED': 'TRANSACTION_STATUS_REJECTED',
    'TRANSACTION_STATUS_EXPIRED': 'TRANSACTION_STATUS_EXPIRED',
  };

  @override
  final Iterable<Type> types = const <Type>[SettlementResultStatusEnum];
  @override
  final String wireName = 'SettlementResultStatusEnum';

  @override
  Object serialize(Serializers serializers, SettlementResultStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  SettlementResultStatusEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      SettlementResultStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$SettlementResult extends SettlementResult {
  @override
  final String transactionId;
  @override
  final int sequenceNumber;
  @override
  final int submittedAmountKobo;
  @override
  final int settledAmountKobo;
  @override
  final SettlementResultStatusEnum status;
  @override
  final String? reason;

  factory _$SettlementResult(
          [void Function(SettlementResultBuilder)? updates]) =>
      (SettlementResultBuilder()..update(updates))._build();

  _$SettlementResult._(
      {required this.transactionId,
      required this.sequenceNumber,
      required this.submittedAmountKobo,
      required this.settledAmountKobo,
      required this.status,
      this.reason})
      : super._();
  @override
  SettlementResult rebuild(void Function(SettlementResultBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SettlementResultBuilder toBuilder() =>
      SettlementResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SettlementResult &&
        transactionId == other.transactionId &&
        sequenceNumber == other.sequenceNumber &&
        submittedAmountKobo == other.submittedAmountKobo &&
        settledAmountKobo == other.settledAmountKobo &&
        status == other.status &&
        reason == other.reason;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, transactionId.hashCode);
    _$hash = $jc(_$hash, sequenceNumber.hashCode);
    _$hash = $jc(_$hash, submittedAmountKobo.hashCode);
    _$hash = $jc(_$hash, settledAmountKobo.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, reason.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SettlementResult')
          ..add('transactionId', transactionId)
          ..add('sequenceNumber', sequenceNumber)
          ..add('submittedAmountKobo', submittedAmountKobo)
          ..add('settledAmountKobo', settledAmountKobo)
          ..add('status', status)
          ..add('reason', reason))
        .toString();
  }
}

class SettlementResultBuilder
    implements Builder<SettlementResult, SettlementResultBuilder> {
  _$SettlementResult? _$v;

  String? _transactionId;
  String? get transactionId => _$this._transactionId;
  set transactionId(String? transactionId) =>
      _$this._transactionId = transactionId;

  int? _sequenceNumber;
  int? get sequenceNumber => _$this._sequenceNumber;
  set sequenceNumber(int? sequenceNumber) =>
      _$this._sequenceNumber = sequenceNumber;

  int? _submittedAmountKobo;
  int? get submittedAmountKobo => _$this._submittedAmountKobo;
  set submittedAmountKobo(int? submittedAmountKobo) =>
      _$this._submittedAmountKobo = submittedAmountKobo;

  int? _settledAmountKobo;
  int? get settledAmountKobo => _$this._settledAmountKobo;
  set settledAmountKobo(int? settledAmountKobo) =>
      _$this._settledAmountKobo = settledAmountKobo;

  SettlementResultStatusEnum? _status;
  SettlementResultStatusEnum? get status => _$this._status;
  set status(SettlementResultStatusEnum? status) => _$this._status = status;

  String? _reason;
  String? get reason => _$this._reason;
  set reason(String? reason) => _$this._reason = reason;

  SettlementResultBuilder() {
    SettlementResult._defaults(this);
  }

  SettlementResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _transactionId = $v.transactionId;
      _sequenceNumber = $v.sequenceNumber;
      _submittedAmountKobo = $v.submittedAmountKobo;
      _settledAmountKobo = $v.settledAmountKobo;
      _status = $v.status;
      _reason = $v.reason;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SettlementResult other) {
    _$v = other as _$SettlementResult;
  }

  @override
  void update(void Function(SettlementResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SettlementResult build() => _build();

  _$SettlementResult _build() {
    final _$result = _$v ??
        _$SettlementResult._(
          transactionId: BuiltValueNullFieldError.checkNotNull(
              transactionId, r'SettlementResult', 'transactionId'),
          sequenceNumber: BuiltValueNullFieldError.checkNotNull(
              sequenceNumber, r'SettlementResult', 'sequenceNumber'),
          submittedAmountKobo: BuiltValueNullFieldError.checkNotNull(
              submittedAmountKobo, r'SettlementResult', 'submittedAmountKobo'),
          settledAmountKobo: BuiltValueNullFieldError.checkNotNull(
              settledAmountKobo, r'SettlementResult', 'settledAmountKobo'),
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'SettlementResult', 'status'),
          reason: reason,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
