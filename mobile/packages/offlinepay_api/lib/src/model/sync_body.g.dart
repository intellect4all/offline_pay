// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SyncBody extends SyncBody {
  @override
  final DateTime? since;
  @override
  final BuiltList<String>? disputedTransactionIds;
  @override
  final bool? finalize;

  factory _$SyncBody([void Function(SyncBodyBuilder)? updates]) =>
      (SyncBodyBuilder()..update(updates))._build();

  _$SyncBody._({this.since, this.disputedTransactionIds, this.finalize})
      : super._();
  @override
  SyncBody rebuild(void Function(SyncBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SyncBodyBuilder toBuilder() => SyncBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SyncBody &&
        since == other.since &&
        disputedTransactionIds == other.disputedTransactionIds &&
        finalize == other.finalize;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, since.hashCode);
    _$hash = $jc(_$hash, disputedTransactionIds.hashCode);
    _$hash = $jc(_$hash, finalize.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SyncBody')
          ..add('since', since)
          ..add('disputedTransactionIds', disputedTransactionIds)
          ..add('finalize', finalize))
        .toString();
  }
}

class SyncBodyBuilder implements Builder<SyncBody, SyncBodyBuilder> {
  _$SyncBody? _$v;

  DateTime? _since;
  DateTime? get since => _$this._since;
  set since(DateTime? since) => _$this._since = since;

  ListBuilder<String>? _disputedTransactionIds;
  ListBuilder<String> get disputedTransactionIds =>
      _$this._disputedTransactionIds ??= ListBuilder<String>();
  set disputedTransactionIds(ListBuilder<String>? disputedTransactionIds) =>
      _$this._disputedTransactionIds = disputedTransactionIds;

  bool? _finalize;
  bool? get finalize => _$this._finalize;
  set finalize(bool? finalize) => _$this._finalize = finalize;

  SyncBodyBuilder() {
    SyncBody._defaults(this);
  }

  SyncBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _since = $v.since;
      _disputedTransactionIds = $v.disputedTransactionIds?.toBuilder();
      _finalize = $v.finalize;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SyncBody other) {
    _$v = other as _$SyncBody;
  }

  @override
  void update(void Function(SyncBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SyncBody build() => _build();

  _$SyncBody _build() {
    _$SyncBody _$result;
    try {
      _$result = _$v ??
          _$SyncBody._(
            since: since,
            disputedTransactionIds: _disputedTransactionIds?.build(),
            finalize: finalize,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'disputedTransactionIds';
        _disputedTransactionIds?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'SyncBody', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
