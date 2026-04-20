// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refresh_ceiling_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RefreshCeilingResponse extends RefreshCeilingResponse {
  @override
  final CeilingToken ceiling;
  @override
  final String lienId;

  factory _$RefreshCeilingResponse(
          [void Function(RefreshCeilingResponseBuilder)? updates]) =>
      (RefreshCeilingResponseBuilder()..update(updates))._build();

  _$RefreshCeilingResponse._({required this.ceiling, required this.lienId})
      : super._();
  @override
  RefreshCeilingResponse rebuild(
          void Function(RefreshCeilingResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RefreshCeilingResponseBuilder toBuilder() =>
      RefreshCeilingResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RefreshCeilingResponse &&
        ceiling == other.ceiling &&
        lienId == other.lienId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, ceiling.hashCode);
    _$hash = $jc(_$hash, lienId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RefreshCeilingResponse')
          ..add('ceiling', ceiling)
          ..add('lienId', lienId))
        .toString();
  }
}

class RefreshCeilingResponseBuilder
    implements Builder<RefreshCeilingResponse, RefreshCeilingResponseBuilder> {
  _$RefreshCeilingResponse? _$v;

  CeilingTokenBuilder? _ceiling;
  CeilingTokenBuilder get ceiling => _$this._ceiling ??= CeilingTokenBuilder();
  set ceiling(CeilingTokenBuilder? ceiling) => _$this._ceiling = ceiling;

  String? _lienId;
  String? get lienId => _$this._lienId;
  set lienId(String? lienId) => _$this._lienId = lienId;

  RefreshCeilingResponseBuilder() {
    RefreshCeilingResponse._defaults(this);
  }

  RefreshCeilingResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _ceiling = $v.ceiling.toBuilder();
      _lienId = $v.lienId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RefreshCeilingResponse other) {
    _$v = other as _$RefreshCeilingResponse;
  }

  @override
  void update(void Function(RefreshCeilingResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RefreshCeilingResponse build() => _build();

  _$RefreshCeilingResponse _build() {
    _$RefreshCeilingResponse _$result;
    try {
      _$result = _$v ??
          _$RefreshCeilingResponse._(
            ceiling: ceiling.build(),
            lienId: BuiltValueNullFieldError.checkNotNull(
                lienId, r'RefreshCeilingResponse', 'lienId'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'ceiling';
        ceiling.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'RefreshCeilingResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
