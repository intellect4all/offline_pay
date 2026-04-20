// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deactivate_device_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeactivateDeviceBody extends DeactivateDeviceBody {
  @override
  final String reason;

  factory _$DeactivateDeviceBody(
          [void Function(DeactivateDeviceBodyBuilder)? updates]) =>
      (DeactivateDeviceBodyBuilder()..update(updates))._build();

  _$DeactivateDeviceBody._({required this.reason}) : super._();
  @override
  DeactivateDeviceBody rebuild(
          void Function(DeactivateDeviceBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeactivateDeviceBodyBuilder toBuilder() =>
      DeactivateDeviceBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeactivateDeviceBody && reason == other.reason;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, reason.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeactivateDeviceBody')
          ..add('reason', reason))
        .toString();
  }
}

class DeactivateDeviceBodyBuilder
    implements Builder<DeactivateDeviceBody, DeactivateDeviceBodyBuilder> {
  _$DeactivateDeviceBody? _$v;

  String? _reason;
  String? get reason => _$this._reason;
  set reason(String? reason) => _$this._reason = reason;

  DeactivateDeviceBodyBuilder() {
    DeactivateDeviceBody._defaults(this);
  }

  DeactivateDeviceBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _reason = $v.reason;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeactivateDeviceBody other) {
    _$v = other as _$DeactivateDeviceBody;
  }

  @override
  void update(void Function(DeactivateDeviceBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeactivateDeviceBody build() => _build();

  _$DeactivateDeviceBody _build() {
    final _$result = _$v ??
        _$DeactivateDeviceBody._(
          reason: BuiltValueNullFieldError.checkNotNull(
              reason, r'DeactivateDeviceBody', 'reason'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
