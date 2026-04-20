// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_balances_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetBalancesResponse extends GetBalancesResponse {
  @override
  final BuiltList<AccountBalance> balances;
  @override
  final DateTime asOf;

  factory _$GetBalancesResponse(
          [void Function(GetBalancesResponseBuilder)? updates]) =>
      (GetBalancesResponseBuilder()..update(updates))._build();

  _$GetBalancesResponse._({required this.balances, required this.asOf})
      : super._();
  @override
  GetBalancesResponse rebuild(
          void Function(GetBalancesResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GetBalancesResponseBuilder toBuilder() =>
      GetBalancesResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetBalancesResponse &&
        balances == other.balances &&
        asOf == other.asOf;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, balances.hashCode);
    _$hash = $jc(_$hash, asOf.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GetBalancesResponse')
          ..add('balances', balances)
          ..add('asOf', asOf))
        .toString();
  }
}

class GetBalancesResponseBuilder
    implements Builder<GetBalancesResponse, GetBalancesResponseBuilder> {
  _$GetBalancesResponse? _$v;

  ListBuilder<AccountBalance>? _balances;
  ListBuilder<AccountBalance> get balances =>
      _$this._balances ??= ListBuilder<AccountBalance>();
  set balances(ListBuilder<AccountBalance>? balances) =>
      _$this._balances = balances;

  DateTime? _asOf;
  DateTime? get asOf => _$this._asOf;
  set asOf(DateTime? asOf) => _$this._asOf = asOf;

  GetBalancesResponseBuilder() {
    GetBalancesResponse._defaults(this);
  }

  GetBalancesResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _balances = $v.balances.toBuilder();
      _asOf = $v.asOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetBalancesResponse other) {
    _$v = other as _$GetBalancesResponse;
  }

  @override
  void update(void Function(GetBalancesResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetBalancesResponse build() => _build();

  _$GetBalancesResponse _build() {
    _$GetBalancesResponse _$result;
    try {
      _$result = _$v ??
          _$GetBalancesResponse._(
            balances: balances.build(),
            asOf: BuiltValueNullFieldError.checkNotNull(
                asOf, r'GetBalancesResponse', 'asOf'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'balances';
        balances.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'GetBalancesResponse', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
