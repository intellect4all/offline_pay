// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'move_to_main_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$MoveToMainResponse extends MoveToMainResponse {
  @override
  final int releasedKobo;
  @override
  final int newMainBalanceKobo;

  factory _$MoveToMainResponse(
          [void Function(MoveToMainResponseBuilder)? updates]) =>
      (MoveToMainResponseBuilder()..update(updates))._build();

  _$MoveToMainResponse._(
      {required this.releasedKobo, required this.newMainBalanceKobo})
      : super._();
  @override
  MoveToMainResponse rebuild(
          void Function(MoveToMainResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MoveToMainResponseBuilder toBuilder() =>
      MoveToMainResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MoveToMainResponse &&
        releasedKobo == other.releasedKobo &&
        newMainBalanceKobo == other.newMainBalanceKobo;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, releasedKobo.hashCode);
    _$hash = $jc(_$hash, newMainBalanceKobo.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MoveToMainResponse')
          ..add('releasedKobo', releasedKobo)
          ..add('newMainBalanceKobo', newMainBalanceKobo))
        .toString();
  }
}

class MoveToMainResponseBuilder
    implements Builder<MoveToMainResponse, MoveToMainResponseBuilder> {
  _$MoveToMainResponse? _$v;

  int? _releasedKobo;
  int? get releasedKobo => _$this._releasedKobo;
  set releasedKobo(int? releasedKobo) => _$this._releasedKobo = releasedKobo;

  int? _newMainBalanceKobo;
  int? get newMainBalanceKobo => _$this._newMainBalanceKobo;
  set newMainBalanceKobo(int? newMainBalanceKobo) =>
      _$this._newMainBalanceKobo = newMainBalanceKobo;

  MoveToMainResponseBuilder() {
    MoveToMainResponse._defaults(this);
  }

  MoveToMainResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _releasedKobo = $v.releasedKobo;
      _newMainBalanceKobo = $v.newMainBalanceKobo;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MoveToMainResponse other) {
    _$v = other as _$MoveToMainResponse;
  }

  @override
  void update(void Function(MoveToMainResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MoveToMainResponse build() => _build();

  _$MoveToMainResponse _build() {
    final _$result = _$v ??
        _$MoveToMainResponse._(
          releasedKobo: BuiltValueNullFieldError.checkNotNull(
              releasedKobo, r'MoveToMainResponse', 'releasedKobo'),
          newMainBalanceKobo: BuiltValueNullFieldError.checkNotNull(
              newMainBalanceKobo, r'MoveToMainResponse', 'newMainBalanceKobo'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
