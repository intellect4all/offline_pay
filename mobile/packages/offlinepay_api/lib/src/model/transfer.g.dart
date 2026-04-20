// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const TransferStatusEnum _$transferStatusEnum_ACCEPTED =
    const TransferStatusEnum._('ACCEPTED');
const TransferStatusEnum _$transferStatusEnum_PROCESSING =
    const TransferStatusEnum._('PROCESSING');
const TransferStatusEnum _$transferStatusEnum_SETTLED =
    const TransferStatusEnum._('SETTLED');
const TransferStatusEnum _$transferStatusEnum_FAILED =
    const TransferStatusEnum._('FAILED');

TransferStatusEnum _$transferStatusEnumValueOf(String name) {
  switch (name) {
    case 'ACCEPTED':
      return _$transferStatusEnum_ACCEPTED;
    case 'PROCESSING':
      return _$transferStatusEnum_PROCESSING;
    case 'SETTLED':
      return _$transferStatusEnum_SETTLED;
    case 'FAILED':
      return _$transferStatusEnum_FAILED;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<TransferStatusEnum> _$transferStatusEnumValues =
    BuiltSet<TransferStatusEnum>(const <TransferStatusEnum>[
  _$transferStatusEnum_ACCEPTED,
  _$transferStatusEnum_PROCESSING,
  _$transferStatusEnum_SETTLED,
  _$transferStatusEnum_FAILED,
]);

Serializer<TransferStatusEnum> _$transferStatusEnumSerializer =
    _$TransferStatusEnumSerializer();

class _$TransferStatusEnumSerializer
    implements PrimitiveSerializer<TransferStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ACCEPTED': 'ACCEPTED',
    'PROCESSING': 'PROCESSING',
    'SETTLED': 'SETTLED',
    'FAILED': 'FAILED',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ACCEPTED': 'ACCEPTED',
    'PROCESSING': 'PROCESSING',
    'SETTLED': 'SETTLED',
    'FAILED': 'FAILED',
  };

  @override
  final Iterable<Type> types = const <Type>[TransferStatusEnum];
  @override
  final String wireName = 'TransferStatusEnum';

  @override
  Object serialize(Serializers serializers, TransferStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  TransferStatusEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      TransferStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Transfer extends Transfer {
  @override
  final String id;
  @override
  final String senderUserId;
  @override
  final String receiverUserId;
  @override
  final String? senderDisplayName;
  @override
  final String? receiverDisplayName;
  @override
  final String receiverAccountNumber;
  @override
  final int amountKobo;
  @override
  final TransferStatusEnum status;
  @override
  final String reference;
  @override
  final String? failureReason;
  @override
  final DateTime createdAt;
  @override
  final DateTime? settledAt;

  factory _$Transfer([void Function(TransferBuilder)? updates]) =>
      (TransferBuilder()..update(updates))._build();

  _$Transfer._(
      {required this.id,
      required this.senderUserId,
      required this.receiverUserId,
      this.senderDisplayName,
      this.receiverDisplayName,
      required this.receiverAccountNumber,
      required this.amountKobo,
      required this.status,
      required this.reference,
      this.failureReason,
      required this.createdAt,
      this.settledAt})
      : super._();
  @override
  Transfer rebuild(void Function(TransferBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TransferBuilder toBuilder() => TransferBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Transfer &&
        id == other.id &&
        senderUserId == other.senderUserId &&
        receiverUserId == other.receiverUserId &&
        senderDisplayName == other.senderDisplayName &&
        receiverDisplayName == other.receiverDisplayName &&
        receiverAccountNumber == other.receiverAccountNumber &&
        amountKobo == other.amountKobo &&
        status == other.status &&
        reference == other.reference &&
        failureReason == other.failureReason &&
        createdAt == other.createdAt &&
        settledAt == other.settledAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, senderUserId.hashCode);
    _$hash = $jc(_$hash, receiverUserId.hashCode);
    _$hash = $jc(_$hash, senderDisplayName.hashCode);
    _$hash = $jc(_$hash, receiverDisplayName.hashCode);
    _$hash = $jc(_$hash, receiverAccountNumber.hashCode);
    _$hash = $jc(_$hash, amountKobo.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, reference.hashCode);
    _$hash = $jc(_$hash, failureReason.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, settledAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Transfer')
          ..add('id', id)
          ..add('senderUserId', senderUserId)
          ..add('receiverUserId', receiverUserId)
          ..add('senderDisplayName', senderDisplayName)
          ..add('receiverDisplayName', receiverDisplayName)
          ..add('receiverAccountNumber', receiverAccountNumber)
          ..add('amountKobo', amountKobo)
          ..add('status', status)
          ..add('reference', reference)
          ..add('failureReason', failureReason)
          ..add('createdAt', createdAt)
          ..add('settledAt', settledAt))
        .toString();
  }
}

class TransferBuilder implements Builder<Transfer, TransferBuilder> {
  _$Transfer? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _senderUserId;
  String? get senderUserId => _$this._senderUserId;
  set senderUserId(String? senderUserId) => _$this._senderUserId = senderUserId;

  String? _receiverUserId;
  String? get receiverUserId => _$this._receiverUserId;
  set receiverUserId(String? receiverUserId) =>
      _$this._receiverUserId = receiverUserId;

  String? _senderDisplayName;
  String? get senderDisplayName => _$this._senderDisplayName;
  set senderDisplayName(String? senderDisplayName) =>
      _$this._senderDisplayName = senderDisplayName;

  String? _receiverDisplayName;
  String? get receiverDisplayName => _$this._receiverDisplayName;
  set receiverDisplayName(String? receiverDisplayName) =>
      _$this._receiverDisplayName = receiverDisplayName;

  String? _receiverAccountNumber;
  String? get receiverAccountNumber => _$this._receiverAccountNumber;
  set receiverAccountNumber(String? receiverAccountNumber) =>
      _$this._receiverAccountNumber = receiverAccountNumber;

  int? _amountKobo;
  int? get amountKobo => _$this._amountKobo;
  set amountKobo(int? amountKobo) => _$this._amountKobo = amountKobo;

  TransferStatusEnum? _status;
  TransferStatusEnum? get status => _$this._status;
  set status(TransferStatusEnum? status) => _$this._status = status;

  String? _reference;
  String? get reference => _$this._reference;
  set reference(String? reference) => _$this._reference = reference;

  String? _failureReason;
  String? get failureReason => _$this._failureReason;
  set failureReason(String? failureReason) =>
      _$this._failureReason = failureReason;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _settledAt;
  DateTime? get settledAt => _$this._settledAt;
  set settledAt(DateTime? settledAt) => _$this._settledAt = settledAt;

  TransferBuilder() {
    Transfer._defaults(this);
  }

  TransferBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _senderUserId = $v.senderUserId;
      _receiverUserId = $v.receiverUserId;
      _senderDisplayName = $v.senderDisplayName;
      _receiverDisplayName = $v.receiverDisplayName;
      _receiverAccountNumber = $v.receiverAccountNumber;
      _amountKobo = $v.amountKobo;
      _status = $v.status;
      _reference = $v.reference;
      _failureReason = $v.failureReason;
      _createdAt = $v.createdAt;
      _settledAt = $v.settledAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Transfer other) {
    _$v = other as _$Transfer;
  }

  @override
  void update(void Function(TransferBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Transfer build() => _build();

  _$Transfer _build() {
    final _$result = _$v ??
        _$Transfer._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'Transfer', 'id'),
          senderUserId: BuiltValueNullFieldError.checkNotNull(
              senderUserId, r'Transfer', 'senderUserId'),
          receiverUserId: BuiltValueNullFieldError.checkNotNull(
              receiverUserId, r'Transfer', 'receiverUserId'),
          senderDisplayName: senderDisplayName,
          receiverDisplayName: receiverDisplayName,
          receiverAccountNumber: BuiltValueNullFieldError.checkNotNull(
              receiverAccountNumber, r'Transfer', 'receiverAccountNumber'),
          amountKobo: BuiltValueNullFieldError.checkNotNull(
              amountKobo, r'Transfer', 'amountKobo'),
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'Transfer', 'status'),
          reference: BuiltValueNullFieldError.checkNotNull(
              reference, r'Transfer', 'reference'),
          failureReason: failureReason,
          createdAt: BuiltValueNullFieldError.checkNotNull(
              createdAt, r'Transfer', 'createdAt'),
          settledAt: settledAt,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
