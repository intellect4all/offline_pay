// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_pin_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SetPinBody extends SetPinBody {
  @override
  final String pin;

  factory _$SetPinBody([void Function(SetPinBodyBuilder)? updates]) =>
      (SetPinBodyBuilder()..update(updates))._build();

  _$SetPinBody._({required this.pin}) : super._();
  @override
  SetPinBody rebuild(void Function(SetPinBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SetPinBodyBuilder toBuilder() => SetPinBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SetPinBody && pin == other.pin;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, pin.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SetPinBody')..add('pin', pin))
        .toString();
  }
}

class SetPinBodyBuilder implements Builder<SetPinBody, SetPinBodyBuilder> {
  _$SetPinBody? _$v;

  String? _pin;
  String? get pin => _$this._pin;
  set pin(String? pin) => _$this._pin = pin;

  SetPinBodyBuilder() {
    SetPinBody._defaults(this);
  }

  SetPinBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _pin = $v.pin;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SetPinBody other) {
    _$v = other as _$SetPinBody;
  }

  @override
  void update(void Function(SetPinBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SetPinBody build() => _build();

  _$SetPinBody _build() {
    final _$result = _$v ??
        _$SetPinBody._(
          pin: BuiltValueNullFieldError.checkNotNull(pin, r'SetPinBody', 'pin'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
