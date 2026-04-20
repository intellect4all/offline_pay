// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'synced_transaction.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const SyncedTransactionStatusEnum
    _$syncedTransactionStatusEnum_TRANSACTION_STATUS_UNSPECIFIED =
    const SyncedTransactionStatusEnum._('TRANSACTION_STATUS_UNSPECIFIED');
const SyncedTransactionStatusEnum
    _$syncedTransactionStatusEnum_TRANSACTION_STATUS_QUEUED =
    const SyncedTransactionStatusEnum._('TRANSACTION_STATUS_QUEUED');
const SyncedTransactionStatusEnum
    _$syncedTransactionStatusEnum_TRANSACTION_STATUS_SUBMITTED =
    const SyncedTransactionStatusEnum._('TRANSACTION_STATUS_SUBMITTED');
const SyncedTransactionStatusEnum
    _$syncedTransactionStatusEnum_TRANSACTION_STATUS_PENDING =
    const SyncedTransactionStatusEnum._('TRANSACTION_STATUS_PENDING');
const SyncedTransactionStatusEnum
    _$syncedTransactionStatusEnum_TRANSACTION_STATUS_SETTLED =
    const SyncedTransactionStatusEnum._('TRANSACTION_STATUS_SETTLED');
const SyncedTransactionStatusEnum
    _$syncedTransactionStatusEnum_TRANSACTION_STATUS_PARTIALLY_SETTLED =
    const SyncedTransactionStatusEnum._('TRANSACTION_STATUS_PARTIALLY_SETTLED');
const SyncedTransactionStatusEnum
    _$syncedTransactionStatusEnum_TRANSACTION_STATUS_REJECTED =
    const SyncedTransactionStatusEnum._('TRANSACTION_STATUS_REJECTED');
const SyncedTransactionStatusEnum
    _$syncedTransactionStatusEnum_TRANSACTION_STATUS_EXPIRED =
    const SyncedTransactionStatusEnum._('TRANSACTION_STATUS_EXPIRED');

SyncedTransactionStatusEnum _$syncedTransactionStatusEnumValueOf(String name) {
  switch (name) {
    case 'TRANSACTION_STATUS_UNSPECIFIED':
      return _$syncedTransactionStatusEnum_TRANSACTION_STATUS_UNSPECIFIED;
    case 'TRANSACTION_STATUS_QUEUED':
      return _$syncedTransactionStatusEnum_TRANSACTION_STATUS_QUEUED;
    case 'TRANSACTION_STATUS_SUBMITTED':
      return _$syncedTransactionStatusEnum_TRANSACTION_STATUS_SUBMITTED;
    case 'TRANSACTION_STATUS_PENDING':
      return _$syncedTransactionStatusEnum_TRANSACTION_STATUS_PENDING;
    case 'TRANSACTION_STATUS_SETTLED':
      return _$syncedTransactionStatusEnum_TRANSACTION_STATUS_SETTLED;
    case 'TRANSACTION_STATUS_PARTIALLY_SETTLED':
      return _$syncedTransactionStatusEnum_TRANSACTION_STATUS_PARTIALLY_SETTLED;
    case 'TRANSACTION_STATUS_REJECTED':
      return _$syncedTransactionStatusEnum_TRANSACTION_STATUS_REJECTED;
    case 'TRANSACTION_STATUS_EXPIRED':
      return _$syncedTransactionStatusEnum_TRANSACTION_STATUS_EXPIRED;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<SyncedTransactionStatusEnum>
    _$syncedTransactionStatusEnumValues =
    BuiltSet<SyncedTransactionStatusEnum>(const <SyncedTransactionStatusEnum>[
  _$syncedTransactionStatusEnum_TRANSACTION_STATUS_UNSPECIFIED,
  _$syncedTransactionStatusEnum_TRANSACTION_STATUS_QUEUED,
  _$syncedTransactionStatusEnum_TRANSACTION_STATUS_SUBMITTED,
  _$syncedTransactionStatusEnum_TRANSACTION_STATUS_PENDING,
  _$syncedTransactionStatusEnum_TRANSACTION_STATUS_SETTLED,
  _$syncedTransactionStatusEnum_TRANSACTION_STATUS_PARTIALLY_SETTLED,
  _$syncedTransactionStatusEnum_TRANSACTION_STATUS_REJECTED,
  _$syncedTransactionStatusEnum_TRANSACTION_STATUS_EXPIRED,
]);

Serializer<SyncedTransactionStatusEnum>
    _$syncedTransactionStatusEnumSerializer =
    _$SyncedTransactionStatusEnumSerializer();

class _$SyncedTransactionStatusEnumSerializer
    implements PrimitiveSerializer<SyncedTransactionStatusEnum> {
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
  final Iterable<Type> types = const <Type>[SyncedTransactionStatusEnum];
  @override
  final String wireName = 'SyncedTransactionStatusEnum';

  @override
  Object serialize(Serializers serializers, SyncedTransactionStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  SyncedTransactionStatusEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      SyncedTransactionStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$SyncedTransaction extends SyncedTransaction {
  @override
  final String transactionId;
  @override
  final String payerId;
  @override
  final String payeeId;
  @override
  final int amountKobo;
  @override
  final int settledAmountKobo;
  @override
  final int sequenceNumber;
  @override
  final String ceilingTokenId;
  @override
  final SyncedTransactionStatusEnum status;
  @override
  final String? rejectionReason;
  @override
  final DateTime? submittedAt;
  @override
  final DateTime? settledAt;

  factory _$SyncedTransaction(
          [void Function(SyncedTransactionBuilder)? updates]) =>
      (SyncedTransactionBuilder()..update(updates))._build();

  _$SyncedTransaction._(
      {required this.transactionId,
      required this.payerId,
      required this.payeeId,
      required this.amountKobo,
      required this.settledAmountKobo,
      required this.sequenceNumber,
      required this.ceilingTokenId,
      required this.status,
      this.rejectionReason,
      this.submittedAt,
      this.settledAt})
      : super._();
  @override
  SyncedTransaction rebuild(void Function(SyncedTransactionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncedTransactionBuilder toBuilder() =>
      SyncedTransactionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncedTransaction &&
        transactionId == other.transactionId &&
        payerId == other.payerId &&
        payeeId == other.payeeId &&
        amountKobo == other.amountKobo &&
        settledAmountKobo == other.settledAmountKobo &&
        sequenceNumber == other.sequenceNumber &&
        ceilingTokenId == other.ceilingTokenId &&
        status == other.status &&
        rejectionReason == other.rejectionReason &&
        submittedAt == other.submittedAt &&
        settledAt == other.settledAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, transactionId.hashCode);
    _$hash = $jc(_$hash, payerId.hashCode);
    _$hash = $jc(_$hash, payeeId.hashCode);
    _$hash = $jc(_$hash, amountKobo.hashCode);
    _$hash = $jc(_$hash, settledAmountKobo.hashCode);
    _$hash = $jc(_$hash, sequenceNumber.hashCode);
    _$hash = $jc(_$hash, ceilingTokenId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, rejectionReason.hashCode);
    _$hash = $jc(_$hash, submittedAt.hashCode);
    _$hash = $jc(_$hash, settledAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncedTransaction')
          ..add('transactionId', transactionId)
          ..add('payerId', payerId)
          ..add('payeeId', payeeId)
          ..add('amountKobo', amountKobo)
          ..add('settledAmountKobo', settledAmountKobo)
          ..add('sequenceNumber', sequenceNumber)
          ..add('ceilingTokenId', ceilingTokenId)
          ..add('status', status)
          ..add('rejectionReason', rejectionReason)
          ..add('submittedAt', submittedAt)
          ..add('settledAt', settledAt))
        .toString();
  }
}

class SyncedTransactionBuilder
    implements Builder<SyncedTransaction, SyncedTransactionBuilder> {
  _$SyncedTransaction? _$v;

  String? _transactionId;
  String? get transactionId => _$this._transactionId;
  set transactionId(String? transactionId) =>
      _$this._transactionId = transactionId;

  String? _payerId;
  String? get payerId => _$this._payerId;
  set payerId(String? payerId) => _$this._payerId = payerId;

  String? _payeeId;
  String? get payeeId => _$this._payeeId;
  set payeeId(String? payeeId) => _$this._payeeId = payeeId;

  int? _amountKobo;
  int? get amountKobo => _$this._amountKobo;
  set amountKobo(int? amountKobo) => _$this._amountKobo = amountKobo;

  int? _settledAmountKobo;
  int? get settledAmountKobo => _$this._settledAmountKobo;
  set settledAmountKobo(int? settledAmountKobo) =>
      _$this._settledAmountKobo = settledAmountKobo;

  int? _sequenceNumber;
  int? get sequenceNumber => _$this._sequenceNumber;
  set sequenceNumber(int? sequenceNumber) =>
      _$this._sequenceNumber = sequenceNumber;

  String? _ceilingTokenId;
  String? get ceilingTokenId => _$this._ceilingTokenId;
  set ceilingTokenId(String? ceilingTokenId) =>
      _$this._ceilingTokenId = ceilingTokenId;

  SyncedTransactionStatusEnum? _status;
  SyncedTransactionStatusEnum? get status => _$this._status;
  set status(SyncedTransactionStatusEnum? status) => _$this._status = status;

  String? _rejectionReason;
  String? get rejectionReason => _$this._rejectionReason;
  set rejectionReason(String? rejectionReason) =>
      _$this._rejectionReason = rejectionReason;

  DateTime? _submittedAt;
  DateTime? get submittedAt => _$this._submittedAt;
  set submittedAt(DateTime? submittedAt) => _$this._submittedAt = submittedAt;

  DateTime? _settledAt;
  DateTime? get settledAt => _$this._settledAt;
  set settledAt(DateTime? settledAt) => _$this._settledAt = settledAt;

  SyncedTransactionBuilder() {
    SyncedTransaction._defaults(this);
  }

  SyncedTransactionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _transactionId = $v.transactionId;
      _payerId = $v.payerId;
      _payeeId = $v.payeeId;
      _amountKobo = $v.amountKobo;
      _settledAmountKobo = $v.settledAmountKobo;
      _sequenceNumber = $v.sequenceNumber;
      _ceilingTokenId = $v.ceilingTokenId;
      _status = $v.status;
      _rejectionReason = $v.rejectionReason;
      _submittedAt = $v.submittedAt;
      _settledAt = $v.settledAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncedTransaction other) {
    _$v = other as _$SyncedTransaction;
  }

  @override
  void update(void Function(SyncedTransactionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncedTransaction build() => _build();

  _$SyncedTransaction _build() {
    final _$result = _$v ??
        _$SyncedTransaction._(
          transactionId: BuiltValueNullFieldError.checkNotNull(
              transactionId, r'SyncedTransaction', 'transactionId'),
          payerId: BuiltValueNullFieldError.checkNotNull(
              payerId, r'SyncedTransaction', 'payerId'),
          payeeId: BuiltValueNullFieldError.checkNotNull(
              payeeId, r'SyncedTransaction', 'payeeId'),
          amountKobo: BuiltValueNullFieldError.checkNotNull(
              amountKobo, r'SyncedTransaction', 'amountKobo'),
          settledAmountKobo: BuiltValueNullFieldError.checkNotNull(
              settledAmountKobo, r'SyncedTransaction', 'settledAmountKobo'),
          sequenceNumber: BuiltValueNullFieldError.checkNotNull(
              sequenceNumber, r'SyncedTransaction', 'sequenceNumber'),
          ceilingTokenId: BuiltValueNullFieldError.checkNotNull(
              ceilingTokenId, r'SyncedTransaction', 'ceilingTokenId'),
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'SyncedTransaction', 'status'),
          rejectionReason: rejectionReason,
          submittedAt: submittedAt,
          settledAt: settledAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
