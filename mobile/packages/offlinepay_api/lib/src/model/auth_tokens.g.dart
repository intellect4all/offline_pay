// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_tokens.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AuthTokens extends AuthTokens {
  @override
  final String userId;
  @override
  final String accountNumber;
  @override
  final String accessToken;
  @override
  final String refreshToken;
  @override
  final DateTime accessExpiresAt;
  @override
  final DateTime refreshExpiresAt;
  @override
  final DisplayCardInput? displayCard;

  factory _$AuthTokens([void Function(AuthTokensBuilder)? updates]) =>
      (AuthTokensBuilder()..update(updates))._build();

  _$AuthTokens._(
      {required this.userId,
      required this.accountNumber,
      required this.accessToken,
      required this.refreshToken,
      required this.accessExpiresAt,
      required this.refreshExpiresAt,
      this.displayCard})
      : super._();
  @override
  AuthTokens rebuild(void Function(AuthTokensBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AuthTokensBuilder toBuilder() => AuthTokensBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AuthTokens &&
        userId == other.userId &&
        accountNumber == other.accountNumber &&
        accessToken == other.accessToken &&
        refreshToken == other.refreshToken &&
        accessExpiresAt == other.accessExpiresAt &&
        refreshExpiresAt == other.refreshExpiresAt &&
        displayCard == other.displayCard;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, accountNumber.hashCode);
    _$hash = $jc(_$hash, accessToken.hashCode);
    _$hash = $jc(_$hash, refreshToken.hashCode);
    _$hash = $jc(_$hash, accessExpiresAt.hashCode);
    _$hash = $jc(_$hash, refreshExpiresAt.hashCode);
    _$hash = $jc(_$hash, displayCard.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AuthTokens')
          ..add('userId', userId)
          ..add('accountNumber', accountNumber)
          ..add('accessToken', accessToken)
          ..add('refreshToken', refreshToken)
          ..add('accessExpiresAt', accessExpiresAt)
          ..add('refreshExpiresAt', refreshExpiresAt)
          ..add('displayCard', displayCard))
        .toString();
  }
}

class AuthTokensBuilder implements Builder<AuthTokens, AuthTokensBuilder> {
  _$AuthTokens? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  String? _accountNumber;
  String? get accountNumber => _$this._accountNumber;
  set accountNumber(String? accountNumber) =>
      _$this._accountNumber = accountNumber;

  String? _accessToken;
  String? get accessToken => _$this._accessToken;
  set accessToken(String? accessToken) => _$this._accessToken = accessToken;

  String? _refreshToken;
  String? get refreshToken => _$this._refreshToken;
  set refreshToken(String? refreshToken) => _$this._refreshToken = refreshToken;

  DateTime? _accessExpiresAt;
  DateTime? get accessExpiresAt => _$this._accessExpiresAt;
  set accessExpiresAt(DateTime? accessExpiresAt) =>
      _$this._accessExpiresAt = accessExpiresAt;

  DateTime? _refreshExpiresAt;
  DateTime? get refreshExpiresAt => _$this._refreshExpiresAt;
  set refreshExpiresAt(DateTime? refreshExpiresAt) =>
      _$this._refreshExpiresAt = refreshExpiresAt;

  DisplayCardInputBuilder? _displayCard;
  DisplayCardInputBuilder get displayCard =>
      _$this._displayCard ??= DisplayCardInputBuilder();
  set displayCard(DisplayCardInputBuilder? displayCard) =>
      _$this._displayCard = displayCard;

  AuthTokensBuilder() {
    AuthTokens._defaults(this);
  }

  AuthTokensBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _accountNumber = $v.accountNumber;
      _accessToken = $v.accessToken;
      _refreshToken = $v.refreshToken;
      _accessExpiresAt = $v.accessExpiresAt;
      _refreshExpiresAt = $v.refreshExpiresAt;
      _displayCard = $v.displayCard?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AuthTokens other) {
    _$v = other as _$AuthTokens;
  }

  @override
  void update(void Function(AuthTokensBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AuthTokens build() => _build();

  _$AuthTokens _build() {
    _$AuthTokens _$result;
    try {
      _$result = _$v ??
          _$AuthTokens._(
            userId: BuiltValueNullFieldError.checkNotNull(
                userId, r'AuthTokens', 'userId'),
            accountNumber: BuiltValueNullFieldError.checkNotNull(
                accountNumber, r'AuthTokens', 'accountNumber'),
            accessToken: BuiltValueNullFieldError.checkNotNull(
                accessToken, r'AuthTokens', 'accessToken'),
            refreshToken: BuiltValueNullFieldError.checkNotNull(
                refreshToken, r'AuthTokens', 'refreshToken'),
            accessExpiresAt: BuiltValueNullFieldError.checkNotNull(
                accessExpiresAt, r'AuthTokens', 'accessExpiresAt'),
            refreshExpiresAt: BuiltValueNullFieldError.checkNotNull(
                refreshExpiresAt, r'AuthTokens', 'refreshExpiresAt'),
            displayCard: _displayCard?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'displayCard';
        _displayCard?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'AuthTokens', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
