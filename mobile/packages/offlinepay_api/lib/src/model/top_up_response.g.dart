// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'top_up_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$TopUpResponse extends TopUpResponse {
  @override
  final int newBalanceKobo;

  factory _$TopUpResponse([void Function(TopUpResponseBuilder)? updates]) =>
      (TopUpResponseBuilder()..update(updates))._build();

  _$TopUpResponse._({required this.newBalanceKobo}) : super._();
  @override
  TopUpResponse rebuild(void Function(TopUpResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TopUpResponseBuilder toBuilder() => TopUpResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TopUpResponse && newBalanceKobo == other.newBalanceKobo;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, newBalanceKobo.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'TopUpResponse')
          ..add('newBalanceKobo', newBalanceKobo))
        .toString();
  }
}

class TopUpResponseBuilder
    implements Builder<TopUpResponse, TopUpResponseBuilder> {
  _$TopUpResponse? _$v;

  int? _newBalanceKobo;
  int? get newBalanceKobo => _$this._newBalanceKobo;
  set newBalanceKobo(int? newBalanceKobo) =>
      _$this._newBalanceKobo = newBalanceKobo;

  TopUpResponseBuilder() {
    TopUpResponse._defaults(this);
  }

  TopUpResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _newBalanceKobo = $v.newBalanceKobo;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(TopUpResponse other) {
    _$v = other as _$TopUpResponse;
  }

  @override
  void update(void Function(TopUpResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  TopUpResponse build() => _build();

  _$TopUpResponse _build() {
    final _$result = _$v ??
        _$TopUpResponse._(
          newBalanceKobo: BuiltValueNullFieldError.checkNotNull(
              newBalanceKobo, r'TopUpResponse', 'newBalanceKobo'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
