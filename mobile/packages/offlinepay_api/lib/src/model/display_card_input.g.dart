// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_card_input.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DisplayCardInput extends DisplayCardInput {
  @override
  final String userId;
  @override
  final String displayName;
  @override
  final String accountNumber;
  @override
  final DateTime issuedAt;
  @override
  final String bankKeyId;
  @override
  final String serverSignature;

  factory _$DisplayCardInput(
          [void Function(DisplayCardInputBuilder)? updates]) =>
      (DisplayCardInputBuilder()..update(updates))._build();

  _$DisplayCardInput._(
      {required this.userId,
      required this.displayName,
      required this.accountNumber,
      required this.issuedAt,
      required this.bankKeyId,
      required this.serverSignature})
      : super._();
  @override
  DisplayCardInput rebuild(void Function(DisplayCardInputBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DisplayCardInputBuilder toBuilder() =>
      DisplayCardInputBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DisplayCardInput &&
        userId == other.userId &&
        displayName == other.displayName &&
        accountNumber == other.accountNumber &&
        issuedAt == other.issuedAt &&
        bankKeyId == other.bankKeyId &&
        serverSignature == other.serverSignature;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, accountNumber.hashCode);
    _$hash = $jc(_$hash, issuedAt.hashCode);
    _$hash = $jc(_$hash, bankKeyId.hashCode);
    _$hash = $jc(_$hash, serverSignature.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DisplayCardInput')
          ..add('userId', userId)
          ..add('displayName', displayName)
          ..add('accountNumber', accountNumber)
          ..add('issuedAt', issuedAt)
          ..add('bankKeyId', bankKeyId)
          ..add('serverSignature', serverSignature))
        .toString();
  }
}

class DisplayCardInputBuilder
    implements Builder<DisplayCardInput, DisplayCardInputBuilder> {
  _$DisplayCardInput? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  String? _accountNumber;
  String? get accountNumber => _$this._accountNumber;
  set accountNumber(String? accountNumber) =>
      _$this._accountNumber = accountNumber;

  DateTime? _issuedAt;
  DateTime? get issuedAt => _$this._issuedAt;
  set issuedAt(DateTime? issuedAt) => _$this._issuedAt = issuedAt;

  String? _bankKeyId;
  String? get bankKeyId => _$this._bankKeyId;
  set bankKeyId(String? bankKeyId) => _$this._bankKeyId = bankKeyId;

  String? _serverSignature;
  String? get serverSignature => _$this._serverSignature;
  set serverSignature(String? serverSignature) =>
      _$this._serverSignature = serverSignature;

  DisplayCardInputBuilder() {
    DisplayCardInput._defaults(this);
  }

  DisplayCardInputBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _displayName = $v.displayName;
      _accountNumber = $v.accountNumber;
      _issuedAt = $v.issuedAt;
      _bankKeyId = $v.bankKeyId;
      _serverSignature = $v.serverSignature;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DisplayCardInput other) {
    _$v = other as _$DisplayCardInput;
  }

  @override
  void update(void Function(DisplayCardInputBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DisplayCardInput build() => _build();

  _$DisplayCardInput _build() {
    final _$result = _$v ??
        _$DisplayCardInput._(
          userId: BuiltValueNullFieldError.checkNotNull(
              userId, r'DisplayCardInput', 'userId'),
          displayName: BuiltValueNullFieldError.checkNotNull(
              displayName, r'DisplayCardInput', 'displayName'),
          accountNumber: BuiltValueNullFieldError.checkNotNull(
              accountNumber, r'DisplayCardInput', 'accountNumber'),
          issuedAt: BuiltValueNullFieldError.checkNotNull(
              issuedAt, r'DisplayCardInput', 'issuedAt'),
          bankKeyId: BuiltValueNullFieldError.checkNotNull(
              bankKeyId, r'DisplayCardInput', 'bankKeyId'),
          serverSignature: BuiltValueNullFieldError.checkNotNull(
              serverSignature, r'DisplayCardInput', 'serverSignature'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
