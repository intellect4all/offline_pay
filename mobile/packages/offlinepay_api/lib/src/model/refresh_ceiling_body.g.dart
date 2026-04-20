// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refresh_ceiling_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RefreshCeilingBody extends RefreshCeilingBody {
  @override
  final int newAmountKobo;
  @override
  final int ttlSeconds;
  @override
  final String payerPublicKey;

  factory _$RefreshCeilingBody(
          [void Function(RefreshCeilingBodyBuilder)? updates]) =>
      (RefreshCeilingBodyBuilder()..update(updates))._build();

  _$RefreshCeilingBody._(
      {required this.newAmountKobo,
      required this.ttlSeconds,
      required this.payerPublicKey})
      : super._();
  @override
  RefreshCeilingBody rebuild(
          void Function(RefreshCeilingBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RefreshCeilingBodyBuilder toBuilder() =>
      RefreshCeilingBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RefreshCeilingBody &&
        newAmountKobo == other.newAmountKobo &&
        ttlSeconds == other.ttlSeconds &&
        payerPublicKey == other.payerPublicKey;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, newAmountKobo.hashCode);
    _$hash = $jc(_$hash, ttlSeconds.hashCode);
    _$hash = $jc(_$hash, payerPublicKey.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RefreshCeilingBody')
          ..add('newAmountKobo', newAmountKobo)
          ..add('ttlSeconds', ttlSeconds)
          ..add('payerPublicKey', payerPublicKey))
        .toString();
  }
}

class RefreshCeilingBodyBuilder
    implements Builder<RefreshCeilingBody, RefreshCeilingBodyBuilder> {
  _$RefreshCeilingBody? _$v;

  int? _newAmountKobo;
  int? get newAmountKobo => _$this._newAmountKobo;
  set newAmountKobo(int? newAmountKobo) =>
      _$this._newAmountKobo = newAmountKobo;

  int? _ttlSeconds;
  int? get ttlSeconds => _$this._ttlSeconds;
  set ttlSeconds(int? ttlSeconds) => _$this._ttlSeconds = ttlSeconds;

  String? _payerPublicKey;
  String? get payerPublicKey => _$this._payerPublicKey;
  set payerPublicKey(String? payerPublicKey) =>
      _$this._payerPublicKey = payerPublicKey;

  RefreshCeilingBodyBuilder() {
    RefreshCeilingBody._defaults(this);
  }

  RefreshCeilingBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _newAmountKobo = $v.newAmountKobo;
      _ttlSeconds = $v.ttlSeconds;
      _payerPublicKey = $v.payerPublicKey;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RefreshCeilingBody other) {
    _$v = other as _$RefreshCeilingBody;
  }

  @override
  void update(void Function(RefreshCeilingBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RefreshCeilingBody build() => _build();

  _$RefreshCeilingBody _build() {
    final _$result = _$v ??
        _$RefreshCeilingBody._(
          newAmountKobo: BuiltValueNullFieldError.checkNotNull(
              newAmountKobo, r'RefreshCeilingBody', 'newAmountKobo'),
          ttlSeconds: BuiltValueNullFieldError.checkNotNull(
              ttlSeconds, r'RefreshCeilingBody', 'ttlSeconds'),
          payerPublicKey: BuiltValueNullFieldError.checkNotNull(
              payerPublicKey, r'RefreshCeilingBody', 'payerPublicKey'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
