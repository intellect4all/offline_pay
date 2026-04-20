// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'signup_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SignupBody extends SignupBody {
  @override
  final String phone;
  @override
  final String password;
  @override
  final String firstName;
  @override
  final String lastName;
  @override
  final String email;

  factory _$SignupBody([void Function(SignupBodyBuilder)? updates]) =>
      (SignupBodyBuilder()..update(updates))._build();

  _$SignupBody._(
      {required this.phone,
      required this.password,
      required this.firstName,
      required this.lastName,
      required this.email})
      : super._();
  @override
  SignupBody rebuild(void Function(SignupBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SignupBodyBuilder toBuilder() => SignupBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SignupBody &&
        phone == other.phone &&
        password == other.password &&
        firstName == other.firstName &&
        lastName == other.lastName &&
        email == other.email;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, phone.hashCode);
    _$hash = $jc(_$hash, password.hashCode);
    _$hash = $jc(_$hash, firstName.hashCode);
    _$hash = $jc(_$hash, lastName.hashCode);
    _$hash = $jc(_$hash, email.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SignupBody')
          ..add('phone', phone)
          ..add('password', password)
          ..add('firstName', firstName)
          ..add('lastName', lastName)
          ..add('email', email))
        .toString();
  }
}

class SignupBodyBuilder implements Builder<SignupBody, SignupBodyBuilder> {
  _$SignupBody? _$v;

  String? _phone;
  String? get phone => _$this._phone;
  set phone(String? phone) => _$this._phone = phone;

  String? _password;
  String? get password => _$this._password;
  set password(String? password) => _$this._password = password;

  String? _firstName;
  String? get firstName => _$this._firstName;
  set firstName(String? firstName) => _$this._firstName = firstName;

  String? _lastName;
  String? get lastName => _$this._lastName;
  set lastName(String? lastName) => _$this._lastName = lastName;

  String? _email;
  String? get email => _$this._email;
  set email(String? email) => _$this._email = email;

  SignupBodyBuilder() {
    SignupBody._defaults(this);
  }

  SignupBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _phone = $v.phone;
      _password = $v.password;
      _firstName = $v.firstName;
      _lastName = $v.lastName;
      _email = $v.email;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SignupBody other) {
    _$v = other as _$SignupBody;
  }

  @override
  void update(void Function(SignupBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SignupBody build() => _build();

  _$SignupBody _build() {
    final _$result = _$v ??
        _$SignupBody._(
          phone: BuiltValueNullFieldError.checkNotNull(
              phone, r'SignupBody', 'phone'),
          password: BuiltValueNullFieldError.checkNotNull(
              password, r'SignupBody', 'password'),
          firstName: BuiltValueNullFieldError.checkNotNull(
              firstName, r'SignupBody', 'firstName'),
          lastName: BuiltValueNullFieldError.checkNotNull(
              lastName, r'SignupBody', 'lastName'),
          email: BuiltValueNullFieldError.checkNotNull(
              email, r'SignupBody', 'email'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
