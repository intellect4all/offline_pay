// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Me extends Me {
  @override
  final String userId;
  @override
  final String phone;
  @override
  final String accountNumber;
  @override
  final String kycTier;
  @override
  final String firstName;
  @override
  final String lastName;
  @override
  final String email;
  @override
  final bool emailVerified;
  @override
  final DisplayCardInput? displayCard;

  factory _$Me([void Function(MeBuilder)? updates]) =>
      (MeBuilder()..update(updates))._build();

  _$Me._(
      {required this.userId,
      required this.phone,
      required this.accountNumber,
      required this.kycTier,
      required this.firstName,
      required this.lastName,
      required this.email,
      required this.emailVerified,
      this.displayCard})
      : super._();
  @override
  Me rebuild(void Function(MeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MeBuilder toBuilder() => MeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Me &&
        userId == other.userId &&
        phone == other.phone &&
        accountNumber == other.accountNumber &&
        kycTier == other.kycTier &&
        firstName == other.firstName &&
        lastName == other.lastName &&
        email == other.email &&
        emailVerified == other.emailVerified &&
        displayCard == other.displayCard;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, phone.hashCode);
    _$hash = $jc(_$hash, accountNumber.hashCode);
    _$hash = $jc(_$hash, kycTier.hashCode);
    _$hash = $jc(_$hash, firstName.hashCode);
    _$hash = $jc(_$hash, lastName.hashCode);
    _$hash = $jc(_$hash, email.hashCode);
    _$hash = $jc(_$hash, emailVerified.hashCode);
    _$hash = $jc(_$hash, displayCard.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Me')
          ..add('userId', userId)
          ..add('phone', phone)
          ..add('accountNumber', accountNumber)
          ..add('kycTier', kycTier)
          ..add('firstName', firstName)
          ..add('lastName', lastName)
          ..add('email', email)
          ..add('emailVerified', emailVerified)
          ..add('displayCard', displayCard))
        .toString();
  }
}

class MeBuilder implements Builder<Me, MeBuilder> {
  _$Me? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  String? _phone;
  String? get phone => _$this._phone;
  set phone(String? phone) => _$this._phone = phone;

  String? _accountNumber;
  String? get accountNumber => _$this._accountNumber;
  set accountNumber(String? accountNumber) =>
      _$this._accountNumber = accountNumber;

  String? _kycTier;
  String? get kycTier => _$this._kycTier;
  set kycTier(String? kycTier) => _$this._kycTier = kycTier;

  String? _firstName;
  String? get firstName => _$this._firstName;
  set firstName(String? firstName) => _$this._firstName = firstName;

  String? _lastName;
  String? get lastName => _$this._lastName;
  set lastName(String? lastName) => _$this._lastName = lastName;

  String? _email;
  String? get email => _$this._email;
  set email(String? email) => _$this._email = email;

  bool? _emailVerified;
  bool? get emailVerified => _$this._emailVerified;
  set emailVerified(bool? emailVerified) =>
      _$this._emailVerified = emailVerified;

  DisplayCardInputBuilder? _displayCard;
  DisplayCardInputBuilder get displayCard =>
      _$this._displayCard ??= DisplayCardInputBuilder();
  set displayCard(DisplayCardInputBuilder? displayCard) =>
      _$this._displayCard = displayCard;

  MeBuilder() {
    Me._defaults(this);
  }

  MeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _phone = $v.phone;
      _accountNumber = $v.accountNumber;
      _kycTier = $v.kycTier;
      _firstName = $v.firstName;
      _lastName = $v.lastName;
      _email = $v.email;
      _emailVerified = $v.emailVerified;
      _displayCard = $v.displayCard?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Me other) {
    _$v = other as _$Me;
  }

  @override
  void update(void Function(MeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Me build() => _build();

  _$Me _build() {
    _$Me _$result;
    try {
      _$result = _$v ??
          _$Me._(
            userId:
                BuiltValueNullFieldError.checkNotNull(userId, r'Me', 'userId'),
            phone: BuiltValueNullFieldError.checkNotNull(phone, r'Me', 'phone'),
            accountNumber: BuiltValueNullFieldError.checkNotNull(
                accountNumber, r'Me', 'accountNumber'),
            kycTier: BuiltValueNullFieldError.checkNotNull(
                kycTier, r'Me', 'kycTier'),
            firstName: BuiltValueNullFieldError.checkNotNull(
                firstName, r'Me', 'firstName'),
            lastName: BuiltValueNullFieldError.checkNotNull(
                lastName, r'Me', 'lastName'),
            email: BuiltValueNullFieldError.checkNotNull(email, r'Me', 'email'),
            emailVerified: BuiltValueNullFieldError.checkNotNull(
                emailVerified, r'Me', 'emailVerified'),
            displayCard: _displayCard?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'displayCard';
        _displayCard?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'Me', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
