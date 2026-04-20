// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resolved_account.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ResolvedAccount extends ResolvedAccount {
  @override
  final String accountNumber;
  @override
  final String maskedName;

  factory _$ResolvedAccount([void Function(ResolvedAccountBuilder)? updates]) =>
      (ResolvedAccountBuilder()..update(updates))._build();

  _$ResolvedAccount._({required this.accountNumber, required this.maskedName})
      : super._();
  @override
  ResolvedAccount rebuild(void Function(ResolvedAccountBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ResolvedAccountBuilder toBuilder() => ResolvedAccountBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ResolvedAccount &&
        accountNumber == other.accountNumber &&
        maskedName == other.maskedName;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, accountNumber.hashCode);
    _$hash = $jc(_$hash, maskedName.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ResolvedAccount')
          ..add('accountNumber', accountNumber)
          ..add('maskedName', maskedName))
        .toString();
  }
}

class ResolvedAccountBuilder
    implements Builder<ResolvedAccount, ResolvedAccountBuilder> {
  _$ResolvedAccount? _$v;

  String? _accountNumber;
  String? get accountNumber => _$this._accountNumber;
  set accountNumber(String? accountNumber) =>
      _$this._accountNumber = accountNumber;

  String? _maskedName;
  String? get maskedName => _$this._maskedName;
  set maskedName(String? maskedName) => _$this._maskedName = maskedName;

  ResolvedAccountBuilder() {
    ResolvedAccount._defaults(this);
  }

  ResolvedAccountBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _accountNumber = $v.accountNumber;
      _maskedName = $v.maskedName;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ResolvedAccount other) {
    _$v = other as _$ResolvedAccount;
  }

  @override
  void update(void Function(ResolvedAccountBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ResolvedAccount build() => _build();

  _$ResolvedAccount _build() {
    final _$result = _$v ??
        _$ResolvedAccount._(
          accountNumber: BuiltValueNullFieldError.checkNotNull(
              accountNumber, r'ResolvedAccount', 'accountNumber'),
          maskedName: BuiltValueNullFieldError.checkNotNull(
              maskedName, r'ResolvedAccount', 'maskedName'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
