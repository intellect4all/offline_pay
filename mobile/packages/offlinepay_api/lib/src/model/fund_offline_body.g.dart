// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fund_offline_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$FundOfflineBody extends FundOfflineBody {
  @override
  final int amountKobo;
  @override
  final int ttlSeconds;
  @override
  final String payerPublicKey;

  factory _$FundOfflineBody([void Function(FundOfflineBodyBuilder)? updates]) =>
      (FundOfflineBodyBuilder()..update(updates))._build();

  _$FundOfflineBody._(
      {required this.amountKobo,
      required this.ttlSeconds,
      required this.payerPublicKey})
      : super._();
  @override
  FundOfflineBody rebuild(void Function(FundOfflineBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  FundOfflineBodyBuilder toBuilder() => FundOfflineBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is FundOfflineBody &&
        amountKobo == other.amountKobo &&
        ttlSeconds == other.ttlSeconds &&
        payerPublicKey == other.payerPublicKey;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, amountKobo.hashCode);
    _$hash = $jc(_$hash, ttlSeconds.hashCode);
    _$hash = $jc(_$hash, payerPublicKey.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'FundOfflineBody')
          ..add('amountKobo', amountKobo)
          ..add('ttlSeconds', ttlSeconds)
          ..add('payerPublicKey', payerPublicKey))
        .toString();
  }
}

class FundOfflineBodyBuilder
    implements Builder<FundOfflineBody, FundOfflineBodyBuilder> {
  _$FundOfflineBody? _$v;

  int? _amountKobo;
  int? get amountKobo => _$this._amountKobo;
  set amountKobo(int? amountKobo) => _$this._amountKobo = amountKobo;

  int? _ttlSeconds;
  int? get ttlSeconds => _$this._ttlSeconds;
  set ttlSeconds(int? ttlSeconds) => _$this._ttlSeconds = ttlSeconds;

  String? _payerPublicKey;
  String? get payerPublicKey => _$this._payerPublicKey;
  set payerPublicKey(String? payerPublicKey) =>
      _$this._payerPublicKey = payerPublicKey;

  FundOfflineBodyBuilder() {
    FundOfflineBody._defaults(this);
  }

  FundOfflineBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _amountKobo = $v.amountKobo;
      _ttlSeconds = $v.ttlSeconds;
      _payerPublicKey = $v.payerPublicKey;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(FundOfflineBody other) {
    _$v = other as _$FundOfflineBody;
  }

  @override
  void update(void Function(FundOfflineBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  FundOfflineBody build() => _build();

  _$FundOfflineBody _build() {
    final _$result = _$v ??
        _$FundOfflineBody._(
          amountKobo: BuiltValueNullFieldError.checkNotNull(
              amountKobo, r'FundOfflineBody', 'amountKobo'),
          ttlSeconds: BuiltValueNullFieldError.checkNotNull(
              ttlSeconds, r'FundOfflineBody', 'ttlSeconds'),
          payerPublicKey: BuiltValueNullFieldError.checkNotNull(
              payerPublicKey, r'FundOfflineBody', 'payerPublicKey'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
