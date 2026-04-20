// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fund_offline_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$FundOfflineResponse extends FundOfflineResponse {
  @override
  final CeilingToken ceiling;
  @override
  final String lienId;

  factory _$FundOfflineResponse(
          [void Function(FundOfflineResponseBuilder)? updates]) =>
      (FundOfflineResponseBuilder()..update(updates))._build();

  _$FundOfflineResponse._({required this.ceiling, required this.lienId})
      : super._();
  @override
  FundOfflineResponse rebuild(
          void Function(FundOfflineResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  FundOfflineResponseBuilder toBuilder() =>
      FundOfflineResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is FundOfflineResponse &&
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
    return (newBuiltValueToStringHelper(r'FundOfflineResponse')
          ..add('ceiling', ceiling)
          ..add('lienId', lienId))
        .toString();
  }
}

class FundOfflineResponseBuilder
    implements Builder<FundOfflineResponse, FundOfflineResponseBuilder> {
  _$FundOfflineResponse? _$v;

  CeilingTokenBuilder? _ceiling;
  CeilingTokenBuilder get ceiling => _$this._ceiling ??= CeilingTokenBuilder();
  set ceiling(CeilingTokenBuilder? ceiling) => _$this._ceiling = ceiling;

  String? _lienId;
  String? get lienId => _$this._lienId;
  set lienId(String? lienId) => _$this._lienId = lienId;

  FundOfflineResponseBuilder() {
    FundOfflineResponse._defaults(this);
  }

  FundOfflineResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _ceiling = $v.ceiling.toBuilder();
      _lienId = $v.lienId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(FundOfflineResponse other) {
    _$v = other as _$FundOfflineResponse;
  }

  @override
  void update(void Function(FundOfflineResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  FundOfflineResponse build() => _build();

  _$FundOfflineResponse _build() {
    _$FundOfflineResponse _$result;
    try {
      _$result = _$v ??
          _$FundOfflineResponse._(
            ceiling: ceiling.build(),
            lienId: BuiltValueNullFieldError.checkNotNull(
                lienId, r'FundOfflineResponse', 'lienId'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'ceiling';
        ceiling.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'FundOfflineResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
