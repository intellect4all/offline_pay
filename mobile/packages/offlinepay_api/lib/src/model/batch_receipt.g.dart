// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'batch_receipt.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const BatchReceiptStatusEnum
    _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_UNSPECIFIED =
    const BatchReceiptStatusEnum._('SETTLEMENT_BATCH_STATUS_UNSPECIFIED');
const BatchReceiptStatusEnum
    _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_RECEIVED =
    const BatchReceiptStatusEnum._('SETTLEMENT_BATCH_STATUS_RECEIVED');
const BatchReceiptStatusEnum
    _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_PROCESSING =
    const BatchReceiptStatusEnum._('SETTLEMENT_BATCH_STATUS_PROCESSING');
const BatchReceiptStatusEnum
    _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_COMPLETED =
    const BatchReceiptStatusEnum._('SETTLEMENT_BATCH_STATUS_COMPLETED');
const BatchReceiptStatusEnum
    _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_FAILED =
    const BatchReceiptStatusEnum._('SETTLEMENT_BATCH_STATUS_FAILED');

BatchReceiptStatusEnum _$batchReceiptStatusEnumValueOf(String name) {
  switch (name) {
    case 'SETTLEMENT_BATCH_STATUS_UNSPECIFIED':
      return _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_UNSPECIFIED;
    case 'SETTLEMENT_BATCH_STATUS_RECEIVED':
      return _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_RECEIVED;
    case 'SETTLEMENT_BATCH_STATUS_PROCESSING':
      return _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_PROCESSING;
    case 'SETTLEMENT_BATCH_STATUS_COMPLETED':
      return _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_COMPLETED;
    case 'SETTLEMENT_BATCH_STATUS_FAILED':
      return _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_FAILED;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<BatchReceiptStatusEnum> _$batchReceiptStatusEnumValues =
    BuiltSet<BatchReceiptStatusEnum>(const <BatchReceiptStatusEnum>[
  _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_UNSPECIFIED,
  _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_RECEIVED,
  _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_PROCESSING,
  _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_COMPLETED,
  _$batchReceiptStatusEnum_SETTLEMENT_BATCH_STATUS_FAILED,
]);

Serializer<BatchReceiptStatusEnum> _$batchReceiptStatusEnumSerializer =
    _$BatchReceiptStatusEnumSerializer();

class _$BatchReceiptStatusEnumSerializer
    implements PrimitiveSerializer<BatchReceiptStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'SETTLEMENT_BATCH_STATUS_UNSPECIFIED':
        'SETTLEMENT_BATCH_STATUS_UNSPECIFIED',
    'SETTLEMENT_BATCH_STATUS_RECEIVED': 'SETTLEMENT_BATCH_STATUS_RECEIVED',
    'SETTLEMENT_BATCH_STATUS_PROCESSING': 'SETTLEMENT_BATCH_STATUS_PROCESSING',
    'SETTLEMENT_BATCH_STATUS_COMPLETED': 'SETTLEMENT_BATCH_STATUS_COMPLETED',
    'SETTLEMENT_BATCH_STATUS_FAILED': 'SETTLEMENT_BATCH_STATUS_FAILED',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'SETTLEMENT_BATCH_STATUS_UNSPECIFIED':
        'SETTLEMENT_BATCH_STATUS_UNSPECIFIED',
    'SETTLEMENT_BATCH_STATUS_RECEIVED': 'SETTLEMENT_BATCH_STATUS_RECEIVED',
    'SETTLEMENT_BATCH_STATUS_PROCESSING': 'SETTLEMENT_BATCH_STATUS_PROCESSING',
    'SETTLEMENT_BATCH_STATUS_COMPLETED': 'SETTLEMENT_BATCH_STATUS_COMPLETED',
    'SETTLEMENT_BATCH_STATUS_FAILED': 'SETTLEMENT_BATCH_STATUS_FAILED',
  };

  @override
  final Iterable<Type> types = const <Type>[BatchReceiptStatusEnum];
  @override
  final String wireName = 'BatchReceiptStatusEnum';

  @override
  Object serialize(Serializers serializers, BatchReceiptStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  BatchReceiptStatusEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      BatchReceiptStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$BatchReceipt extends BatchReceipt {
  @override
  final String batchId;
  @override
  final String receiverUserId;
  @override
  final int totalSubmitted;
  @override
  final int totalSettled;
  @override
  final int totalPartial;
  @override
  final int totalRejected;
  @override
  final int totalAmountKobo;
  @override
  final BatchReceiptStatusEnum status;
  @override
  final DateTime submittedAt;
  @override
  final DateTime? processedAt;
  @override
  final BuiltList<SettlementResult> results;

  factory _$BatchReceipt([void Function(BatchReceiptBuilder)? updates]) =>
      (BatchReceiptBuilder()..update(updates))._build();

  _$BatchReceipt._(
      {required this.batchId,
      required this.receiverUserId,
      required this.totalSubmitted,
      required this.totalSettled,
      required this.totalPartial,
      required this.totalRejected,
      required this.totalAmountKobo,
      required this.status,
      required this.submittedAt,
      this.processedAt,
      required this.results})
      : super._();
  @override
  BatchReceipt rebuild(void Function(BatchReceiptBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  BatchReceiptBuilder toBuilder() => BatchReceiptBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BatchReceipt &&
        batchId == other.batchId &&
        receiverUserId == other.receiverUserId &&
        totalSubmitted == other.totalSubmitted &&
        totalSettled == other.totalSettled &&
        totalPartial == other.totalPartial &&
        totalRejected == other.totalRejected &&
        totalAmountKobo == other.totalAmountKobo &&
        status == other.status &&
        submittedAt == other.submittedAt &&
        processedAt == other.processedAt &&
        results == other.results;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, batchId.hashCode);
    _$hash = $jc(_$hash, receiverUserId.hashCode);
    _$hash = $jc(_$hash, totalSubmitted.hashCode);
    _$hash = $jc(_$hash, totalSettled.hashCode);
    _$hash = $jc(_$hash, totalPartial.hashCode);
    _$hash = $jc(_$hash, totalRejected.hashCode);
    _$hash = $jc(_$hash, totalAmountKobo.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, submittedAt.hashCode);
    _$hash = $jc(_$hash, processedAt.hashCode);
    _$hash = $jc(_$hash, results.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'BatchReceipt')
          ..add('batchId', batchId)
          ..add('receiverUserId', receiverUserId)
          ..add('totalSubmitted', totalSubmitted)
          ..add('totalSettled', totalSettled)
          ..add('totalPartial', totalPartial)
          ..add('totalRejected', totalRejected)
          ..add('totalAmountKobo', totalAmountKobo)
          ..add('status', status)
          ..add('submittedAt', submittedAt)
          ..add('processedAt', processedAt)
          ..add('results', results))
        .toString();
  }
}

class BatchReceiptBuilder
    implements Builder<BatchReceipt, BatchReceiptBuilder> {
  _$BatchReceipt? _$v;

  String? _batchId;
  String? get batchId => _$this._batchId;
  set batchId(String? batchId) => _$this._batchId = batchId;

  String? _receiverUserId;
  String? get receiverUserId => _$this._receiverUserId;
  set receiverUserId(String? receiverUserId) =>
      _$this._receiverUserId = receiverUserId;

  int? _totalSubmitted;
  int? get totalSubmitted => _$this._totalSubmitted;
  set totalSubmitted(int? totalSubmitted) =>
      _$this._totalSubmitted = totalSubmitted;

  int? _totalSettled;
  int? get totalSettled => _$this._totalSettled;
  set totalSettled(int? totalSettled) => _$this._totalSettled = totalSettled;

  int? _totalPartial;
  int? get totalPartial => _$this._totalPartial;
  set totalPartial(int? totalPartial) => _$this._totalPartial = totalPartial;

  int? _totalRejected;
  int? get totalRejected => _$this._totalRejected;
  set totalRejected(int? totalRejected) =>
      _$this._totalRejected = totalRejected;

  int? _totalAmountKobo;
  int? get totalAmountKobo => _$this._totalAmountKobo;
  set totalAmountKobo(int? totalAmountKobo) =>
      _$this._totalAmountKobo = totalAmountKobo;

  BatchReceiptStatusEnum? _status;
  BatchReceiptStatusEnum? get status => _$this._status;
  set status(BatchReceiptStatusEnum? status) => _$this._status = status;

  DateTime? _submittedAt;
  DateTime? get submittedAt => _$this._submittedAt;
  set submittedAt(DateTime? submittedAt) => _$this._submittedAt = submittedAt;

  DateTime? _processedAt;
  DateTime? get processedAt => _$this._processedAt;
  set processedAt(DateTime? processedAt) => _$this._processedAt = processedAt;

  ListBuilder<SettlementResult>? _results;
  ListBuilder<SettlementResult> get results =>
      _$this._results ??= ListBuilder<SettlementResult>();
  set results(ListBuilder<SettlementResult>? results) =>
      _$this._results = results;

  BatchReceiptBuilder() {
    BatchReceipt._defaults(this);
  }

  BatchReceiptBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _batchId = $v.batchId;
      _receiverUserId = $v.receiverUserId;
      _totalSubmitted = $v.totalSubmitted;
      _totalSettled = $v.totalSettled;
      _totalPartial = $v.totalPartial;
      _totalRejected = $v.totalRejected;
      _totalAmountKobo = $v.totalAmountKobo;
      _status = $v.status;
      _submittedAt = $v.submittedAt;
      _processedAt = $v.processedAt;
      _results = $v.results.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(BatchReceipt other) {
    _$v = other as _$BatchReceipt;
  }

  @override
  void update(void Function(BatchReceiptBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BatchReceipt build() => _build();

  _$BatchReceipt _build() {
    _$BatchReceipt _$result;
    try {
      _$result = _$v ??
          _$BatchReceipt._(
            batchId: BuiltValueNullFieldError.checkNotNull(
                batchId, r'BatchReceipt', 'batchId'),
            receiverUserId: BuiltValueNullFieldError.checkNotNull(
                receiverUserId, r'BatchReceipt', 'receiverUserId'),
            totalSubmitted: BuiltValueNullFieldError.checkNotNull(
                totalSubmitted, r'BatchReceipt', 'totalSubmitted'),
            totalSettled: BuiltValueNullFieldError.checkNotNull(
                totalSettled, r'BatchReceipt', 'totalSettled'),
            totalPartial: BuiltValueNullFieldError.checkNotNull(
                totalPartial, r'BatchReceipt', 'totalPartial'),
            totalRejected: BuiltValueNullFieldError.checkNotNull(
                totalRejected, r'BatchReceipt', 'totalRejected'),
            totalAmountKobo: BuiltValueNullFieldError.checkNotNull(
                totalAmountKobo, r'BatchReceipt', 'totalAmountKobo'),
            status: BuiltValueNullFieldError.checkNotNull(
                status, r'BatchReceipt', 'status'),
            submittedAt: BuiltValueNullFieldError.checkNotNull(
                submittedAt, r'BatchReceipt', 'submittedAt'),
            processedAt: processedAt,
            results: results.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'results';
        results.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'BatchReceipt', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
