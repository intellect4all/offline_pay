// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_balance.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AccountBalanceKindEnum _$accountBalanceKindEnum_ACCOUNT_KIND_UNSPECIFIED =
    const AccountBalanceKindEnum._('ACCOUNT_KIND_UNSPECIFIED');
const AccountBalanceKindEnum _$accountBalanceKindEnum_ACCOUNT_KIND_MAIN =
    const AccountBalanceKindEnum._('ACCOUNT_KIND_MAIN');
const AccountBalanceKindEnum _$accountBalanceKindEnum_ACCOUNT_KIND_OFFLINE =
    const AccountBalanceKindEnum._('ACCOUNT_KIND_OFFLINE');
const AccountBalanceKindEnum
    _$accountBalanceKindEnum_ACCOUNT_KIND_LIEN_HOLDING =
    const AccountBalanceKindEnum._('ACCOUNT_KIND_LIEN_HOLDING');
const AccountBalanceKindEnum
    _$accountBalanceKindEnum_ACCOUNT_KIND_RECEIVING_PENDING =
    const AccountBalanceKindEnum._('ACCOUNT_KIND_RECEIVING_PENDING');

AccountBalanceKindEnum _$accountBalanceKindEnumValueOf(String name) {
  switch (name) {
    case 'ACCOUNT_KIND_UNSPECIFIED':
      return _$accountBalanceKindEnum_ACCOUNT_KIND_UNSPECIFIED;
    case 'ACCOUNT_KIND_MAIN':
      return _$accountBalanceKindEnum_ACCOUNT_KIND_MAIN;
    case 'ACCOUNT_KIND_OFFLINE':
      return _$accountBalanceKindEnum_ACCOUNT_KIND_OFFLINE;
    case 'ACCOUNT_KIND_LIEN_HOLDING':
      return _$accountBalanceKindEnum_ACCOUNT_KIND_LIEN_HOLDING;
    case 'ACCOUNT_KIND_RECEIVING_PENDING':
      return _$accountBalanceKindEnum_ACCOUNT_KIND_RECEIVING_PENDING;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AccountBalanceKindEnum> _$accountBalanceKindEnumValues =
    BuiltSet<AccountBalanceKindEnum>(const <AccountBalanceKindEnum>[
  _$accountBalanceKindEnum_ACCOUNT_KIND_UNSPECIFIED,
  _$accountBalanceKindEnum_ACCOUNT_KIND_MAIN,
  _$accountBalanceKindEnum_ACCOUNT_KIND_OFFLINE,
  _$accountBalanceKindEnum_ACCOUNT_KIND_LIEN_HOLDING,
  _$accountBalanceKindEnum_ACCOUNT_KIND_RECEIVING_PENDING,
]);

Serializer<AccountBalanceKindEnum> _$accountBalanceKindEnumSerializer =
    _$AccountBalanceKindEnumSerializer();

class _$AccountBalanceKindEnumSerializer
    implements PrimitiveSerializer<AccountBalanceKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ACCOUNT_KIND_UNSPECIFIED': 'ACCOUNT_KIND_UNSPECIFIED',
    'ACCOUNT_KIND_MAIN': 'ACCOUNT_KIND_MAIN',
    'ACCOUNT_KIND_OFFLINE': 'ACCOUNT_KIND_OFFLINE',
    'ACCOUNT_KIND_LIEN_HOLDING': 'ACCOUNT_KIND_LIEN_HOLDING',
    'ACCOUNT_KIND_RECEIVING_PENDING': 'ACCOUNT_KIND_RECEIVING_PENDING',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ACCOUNT_KIND_UNSPECIFIED': 'ACCOUNT_KIND_UNSPECIFIED',
    'ACCOUNT_KIND_MAIN': 'ACCOUNT_KIND_MAIN',
    'ACCOUNT_KIND_OFFLINE': 'ACCOUNT_KIND_OFFLINE',
    'ACCOUNT_KIND_LIEN_HOLDING': 'ACCOUNT_KIND_LIEN_HOLDING',
    'ACCOUNT_KIND_RECEIVING_PENDING': 'ACCOUNT_KIND_RECEIVING_PENDING',
  };

  @override
  final Iterable<Type> types = const <Type>[AccountBalanceKindEnum];
  @override
  final String wireName = 'AccountBalanceKindEnum';

  @override
  Object serialize(Serializers serializers, AccountBalanceKindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  AccountBalanceKindEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      AccountBalanceKindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$AccountBalance extends AccountBalance {
  @override
  final AccountBalanceKindEnum kind;
  @override
  final int balanceKobo;
  @override
  final String currency;
  @override
  final DateTime updatedAt;

  factory _$AccountBalance([void Function(AccountBalanceBuilder)? updates]) =>
      (AccountBalanceBuilder()..update(updates))._build();

  _$AccountBalance._(
      {required this.kind,
      required this.balanceKobo,
      required this.currency,
      required this.updatedAt})
      : super._();
  @override
  AccountBalance rebuild(void Function(AccountBalanceBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AccountBalanceBuilder toBuilder() => AccountBalanceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AccountBalance &&
        kind == other.kind &&
        balanceKobo == other.balanceKobo &&
        currency == other.currency &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, balanceKobo.hashCode);
    _$hash = $jc(_$hash, currency.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AccountBalance')
          ..add('kind', kind)
          ..add('balanceKobo', balanceKobo)
          ..add('currency', currency)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class AccountBalanceBuilder
    implements Builder<AccountBalance, AccountBalanceBuilder> {
  _$AccountBalance? _$v;

  AccountBalanceKindEnum? _kind;
  AccountBalanceKindEnum? get kind => _$this._kind;
  set kind(AccountBalanceKindEnum? kind) => _$this._kind = kind;

  int? _balanceKobo;
  int? get balanceKobo => _$this._balanceKobo;
  set balanceKobo(int? balanceKobo) => _$this._balanceKobo = balanceKobo;

  String? _currency;
  String? get currency => _$this._currency;
  set currency(String? currency) => _$this._currency = currency;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  AccountBalanceBuilder() {
    AccountBalance._defaults(this);
  }

  AccountBalanceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _balanceKobo = $v.balanceKobo;
      _currency = $v.currency;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AccountBalance other) {
    _$v = other as _$AccountBalance;
  }

  @override
  void update(void Function(AccountBalanceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AccountBalance build() => _build();

  _$AccountBalance _build() {
    final _$result = _$v ??
        _$AccountBalance._(
          kind: BuiltValueNullFieldError.checkNotNull(
              kind, r'AccountBalance', 'kind'),
          balanceKobo: BuiltValueNullFieldError.checkNotNull(
              balanceKobo, r'AccountBalance', 'balanceKobo'),
          currency: BuiltValueNullFieldError.checkNotNull(
              currency, r'AccountBalance', 'currency'),
          updatedAt: BuiltValueNullFieldError.checkNotNull(
              updatedAt, r'AccountBalance', 'updatedAt'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
