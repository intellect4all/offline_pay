// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncResponse extends SyncResponse {
  @override
  final BuiltList<SyncedTransaction> payerSide;
  @override
  final BuiltList<SyncedTransaction> receiverSide;
  @override
  final DateTime syncedAt;
  @override
  final int finalizedCount;
  @override
  final bool? finalizePending;

  factory _$SyncResponse([void Function(SyncResponseBuilder)? updates]) =>
      (SyncResponseBuilder()..update(updates))._build();

  _$SyncResponse._(
      {required this.payerSide,
      required this.receiverSide,
      required this.syncedAt,
      required this.finalizedCount,
      this.finalizePending})
      : super._();
  @override
  SyncResponse rebuild(void Function(SyncResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncResponseBuilder toBuilder() => SyncResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncResponse &&
        payerSide == other.payerSide &&
        receiverSide == other.receiverSide &&
        syncedAt == other.syncedAt &&
        finalizedCount == other.finalizedCount &&
        finalizePending == other.finalizePending;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, payerSide.hashCode);
    _$hash = $jc(_$hash, receiverSide.hashCode);
    _$hash = $jc(_$hash, syncedAt.hashCode);
    _$hash = $jc(_$hash, finalizedCount.hashCode);
    _$hash = $jc(_$hash, finalizePending.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncResponse')
          ..add('payerSide', payerSide)
          ..add('receiverSide', receiverSide)
          ..add('syncedAt', syncedAt)
          ..add('finalizedCount', finalizedCount)
          ..add('finalizePending', finalizePending))
        .toString();
  }
}

class SyncResponseBuilder
    implements Builder<SyncResponse, SyncResponseBuilder> {
  _$SyncResponse? _$v;

  ListBuilder<SyncedTransaction>? _payerSide;
  ListBuilder<SyncedTransaction> get payerSide =>
      _$this._payerSide ??= ListBuilder<SyncedTransaction>();
  set payerSide(ListBuilder<SyncedTransaction>? payerSide) =>
      _$this._payerSide = payerSide;

  ListBuilder<SyncedTransaction>? _receiverSide;
  ListBuilder<SyncedTransaction> get receiverSide =>
      _$this._receiverSide ??= ListBuilder<SyncedTransaction>();
  set receiverSide(ListBuilder<SyncedTransaction>? receiverSide) =>
      _$this._receiverSide = receiverSide;

  DateTime? _syncedAt;
  DateTime? get syncedAt => _$this._syncedAt;
  set syncedAt(DateTime? syncedAt) => _$this._syncedAt = syncedAt;

  int? _finalizedCount;
  int? get finalizedCount => _$this._finalizedCount;
  set finalizedCount(int? finalizedCount) =>
      _$this._finalizedCount = finalizedCount;

  bool? _finalizePending;
  bool? get finalizePending => _$this._finalizePending;
  set finalizePending(bool? finalizePending) =>
      _$this._finalizePending = finalizePending;

  SyncResponseBuilder() {
    SyncResponse._defaults(this);
  }

  SyncResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _payerSide = $v.payerSide.toBuilder();
      _receiverSide = $v.receiverSide.toBuilder();
      _syncedAt = $v.syncedAt;
      _finalizedCount = $v.finalizedCount;
      _finalizePending = $v.finalizePending;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncResponse other) {
    _$v = other as _$SyncResponse;
  }

  @override
  void update(void Function(SyncResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncResponse build() => _build();

  _$SyncResponse _build() {
    _$SyncResponse _$result;
    try {
      _$result = _$v ??
          _$SyncResponse._(
            payerSide: payerSide.build(),
            receiverSide: receiverSide.build(),
            syncedAt: BuiltValueNullFieldError.checkNotNull(
                syncedAt, r'SyncResponse', 'syncedAt'),
            finalizedCount: BuiltValueNullFieldError.checkNotNull(
                finalizedCount, r'SyncResponse', 'finalizedCount'),
            finalizePending: finalizePending,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'payerSide';
        payerSide.build();
        _$failedField = 'receiverSide';
        receiverSide.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'SyncResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
