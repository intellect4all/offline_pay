// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'top_up_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$TopUpBody extends TopUpBody {
  @override
  final int amountKobo;

  factory _$TopUpBody([void Function(TopUpBodyBuilder)? updates]) =>
      (TopUpBodyBuilder()..update(updates))._build();

  _$TopUpBody._({required this.amountKobo}) : super._();
  @override
  TopUpBody rebuild(void Function(TopUpBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TopUpBodyBuilder toBuilder() => TopUpBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TopUpBody && amountKobo == other.amountKobo;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, amountKobo.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'TopUpBody')
          ..add('amountKobo', amountKobo))
        .toString();
  }
}

class TopUpBodyBuilder implements Builder<TopUpBody, TopUpBodyBuilder> {
  _$TopUpBody? _$v;

  int? _amountKobo;
  int? get amountKobo => _$this._amountKobo;
  set amountKobo(int? amountKobo) => _$this._amountKobo = amountKobo;

  TopUpBodyBuilder() {
    TopUpBody._defaults(this);
  }

  TopUpBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _amountKobo = $v.amountKobo;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(TopUpBody other) {
    _$v = other as _$TopUpBody;
  }

  @override
  void update(void Function(TopUpBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  TopUpBody build() => _build();

  _$TopUpBody _build() {
    final _$result = _$v ??
        _$TopUpBody._(
          amountKobo: BuiltValueNullFieldError.checkNotNull(
              amountKobo, r'TopUpBody', 'amountKobo'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
